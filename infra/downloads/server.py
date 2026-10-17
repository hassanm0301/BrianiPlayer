#!/usr/bin/env python3
"""Briani Player download page.

Serves one page that links straight to the newest client packages on the
project's GitHub releases. A background thread mirrors those packages into a
local cache after checking them against the size and SHA-256 digest GitHub
publishes, so downloads come from this host. A package that is not mirrored
yet is relayed from GitHub instead, so a link never sends the browser away.

Standard library only. Configuration comes from DOWNLOADS_* environment
variables; see compose.yaml next to this file.
"""
from __future__ import annotations
import base64, hashlib, html, http.client, http.server, json, os, re, signal, sys, threading, time, urllib.error, urllib.parse, urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
USER_AGENT = 'briani-downloads/1'
MIN_CHECK_GAP = 120  # seconds between release checks that page views trigger
CHUNK = 1 << 20
BLOB = re.compile(r'(?:[0-9a-f]{64}|asset-\d+)(?:\.part)?')
DIGEST = re.compile(r'sha256:([0-9a-f]{64})')
HOST = re.compile(r'(?:[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*|\[[0-9A-Fa-f:.]+\])(?::\d{1,5})?')
PLACEHOLDER = re.compile(r'\{\{([a-z0-9_.]+)\}\}')


@dataclass(frozen=True)
class Target:
    key: str  # URL path, card id and the DOWNLOADS_<KEY>_ASSET setting
    default_asset: str
    suffix: str  # end of the downloaded file name
    kind: str


# Android phones, tablets and Android TV share one universal APK. The debug-
# signed local-test build is the installable one; the release APK is unsigned.
TARGETS = (
    Target('tv', 'briani-player-local-test.apk', 'android-tv.apk', 'APK'),
    Target('android', 'briani-player-local-test.apk', 'android.apk', 'APK'),
    Target('linux', 'briani-player-linux-x64.tar.gz', 'linux-x64.tar.gz', 'tar.gz'),
)
TARGET_KEYS = {target.key: target for target in TARGETS}
CONTENT_TYPES = {'.apk': 'application/vnd.android.package-archive', '.gz': 'application/gzip'}


class MirrorError(Exception): pass
class Unsatisfiable(Exception): pass


@dataclass(frozen=True)
class Config:
    repo: str
    api: str
    cache: Path
    port: int
    interval: float
    prereleases: bool
    assets: dict
    server_url: str

    @classmethod
    def from_env(cls, env=os.environ) -> 'Config':
        repo = env.get('DOWNLOADS_REPO', 'hassanm0301/BrianiPlayer')
        if not re.fullmatch(r'[A-Za-z0-9-]+/[A-Za-z0-9._-]+', repo):
            raise SystemExit(f'DOWNLOADS_REPO must look like owner/name, not {repo!r}')
        server_url = env.get('DOWNLOADS_SERVER_URL', '')
        if server_url and urllib.parse.urlsplit(server_url).scheme not in ('http', 'https'):
            raise SystemExit('DOWNLOADS_SERVER_URL must be an http:// or https:// address')
        return cls(
            repo=repo,
            api=env.get('DOWNLOADS_API', 'https://api.github.com').rstrip('/'),
            cache=Path(env.get('DOWNLOADS_CACHE', '/cache')),
            port=int(env.get('DOWNLOADS_PORT', '8089')),
            interval=max(60.0, float(env.get('DOWNLOADS_INTERVAL', '900'))),
            prereleases=env.get('DOWNLOADS_PRERELEASES', '1').lower() not in ('0', 'false', 'no'),
            assets={t.key: env.get(f'DOWNLOADS_{t.key.upper()}_ASSET', t.default_asset) for t in TARGETS},
            server_url=server_url,
        )


def resolve(releases: list, assets: dict, prereleases: bool) -> dict:
    """Pick, for each target, the newest eligible release that ships its asset.

    Matches GitHub's own idea of "latest": drafts are skipped and releases are
    ordered by created_at. Pre-releases count unless disabled, because every
    Briani release so far is one."""
    eligible = sorted(
        (r for r in releases if not r.get('draft') and (prereleases or not r.get('prerelease'))),
        key=lambda r: r.get('created_at') or '', reverse=True)
    found = {}
    for key, name in assets.items():
        for release in eligible:
            asset = next((a for a in release.get('assets') or ()
                          if a.get('name') == name and a.get('state', 'uploaded') == 'uploaded'), None)
            if asset:
                found[key] = package(release, asset)
                break
    return found


def package(release: dict, asset: dict) -> dict:
    url = str(asset['browser_download_url'])
    if urllib.parse.urlsplit(url).scheme not in ('https', 'http'):
        raise MirrorError(f'unexpected download address for {asset.get("name")}')
    digest = DIGEST.fullmatch(asset.get('digest') or '')
    tag = str(release['tag_name'])
    return {
        'tag': tag,
        'version': re.sub(r'^v(?=\d)', '', tag),
        'prerelease': bool(release.get('prerelease')),
        'created': release.get('created_at') or '',
        'published': release.get('published_at') or '',
        'notes': str(release.get('html_url') or ''),
        'asset': str(asset['name']),
        'size': int(asset['size']),
        'sha256': digest.group(1) if digest else None,
        'url': url,
        # Cache files are named by content, so the TV and phone targets share
        # one copy, and a name can never point outside the cache directory.
        'blob': digest.group(1) if digest else f'asset-{int(asset["id"])}',
    }


class Mirror:
    """Tracks the newest packages and keeps verified copies of them on disk."""

    def __init__(self, config: Config, opener=urllib.request.urlopen):
        self.config, self.open = config, opener
        self.lock = threading.Lock()
        self.wake = threading.Event()
        self.packages: dict = {}
        self.checked: float | None = None
        self.attempted = 0.0
        self.error: str | None = None
        self.etag: str | None = None
        self.load_state()

    def snapshot(self):
        with self.lock:
            return dict(self.packages), self.checked, self.error

    def local_path(self, package: dict) -> Path | None:
        path = self.config.cache / package['blob']
        try:
            return path if path.stat().st_size == package['size'] else None
        except OSError:
            return None

    def request_check(self):
        if time.time() - self.attempted >= MIN_CHECK_GAP:
            self.wake.set()

    def load_state(self):
        try:
            state = json.loads((self.config.cache / 'state.json').read_text())
            packages = {k: v for k, v in state['packages'].items()
                        if k in TARGET_KEYS and BLOB.fullmatch(v['blob']) and not v['blob'].endswith('.part')}
            self.packages, self.checked = packages, state.get('checked')
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            pass

    def save_state(self):
        with self.lock:
            state = {'packages': self.packages, 'checked': self.checked}
        temporary = self.config.cache / 'state.json.tmp'
        temporary.write_text(json.dumps(state, indent=1))
        os.replace(temporary, self.config.cache / 'state.json')

    def check(self) -> bool:
        """Fetch the release list. Returns False when GitHub reports no change."""
        self.attempted = time.time()
        url = f'{self.config.api}/repos/{self.config.repo}/releases?per_page=30'
        request = urllib.request.Request(url, headers={'Accept': 'application/vnd.github+json', 'User-Agent': USER_AGENT})
        if self.etag:
            request.add_header('If-None-Match', self.etag)
        try:
            with self.open(request, timeout=20) as response:
                releases, etag = json.load(response), response.headers.get('ETag')
        except urllib.error.HTTPError as error:
            if error.code != 304:
                raise MirrorError(f'GitHub answered {error.code} for the release list') from None
            with self.lock:
                self.checked, self.error = time.time(), None
            return False
        if not isinstance(releases, list):
            raise MirrorError('GitHub returned an unexpected release list')
        packages = resolve(releases, self.config.assets, self.config.prereleases)
        with self.lock:
            self.packages, self.etag, self.checked, self.error = packages, etag, time.time(), None
        self.save_state()
        return True

    def mirror(self):
        packages, _, _ = self.snapshot()
        wanted = {p['blob']: p for p in packages.values()}
        failures = []
        for package in wanted.values():
            if not self.local_path(package):
                try:
                    self.fetch(package)
                except (OSError, MirrorError, http.client.HTTPException) as error:
                    failures.append(f'{package["asset"]} {package["tag"]}: {error}')
        self.prune(set(wanted))
        if failures:
            raise MirrorError('; '.join(failures))

    def fetch(self, package: dict):
        partial = self.config.cache / (package['blob'] + '.part')
        digest, size = hashlib.sha256(), 0
        log(f'mirroring {package["asset"]} from {package["tag"]} ({package["size"]} bytes)')
        try:
            request = urllib.request.Request(package['url'], headers={'User-Agent': USER_AGENT})
            with self.open(request, timeout=60) as response, open(partial, 'wb') as output:
                while chunk := response.read(CHUNK):
                    size += len(chunk)
                    if size > package['size']:
                        raise MirrorError('download is larger than GitHub reports')
                    digest.update(chunk)
                    output.write(chunk)
                output.flush()
                os.fsync(output.fileno())
            if size != package['size']:
                raise MirrorError(f'got {size} of {package["size"]} bytes')
            if package['sha256'] and digest.hexdigest() != package['sha256']:
                raise MirrorError('SHA-256 does not match the digest GitHub publishes')
            os.replace(partial, self.config.cache / package['blob'])
            log(f'mirrored {package["asset"]} from {package["tag"]}')
        finally:
            partial.unlink(missing_ok=True)

    def prune(self, keep: set):
        # Only names this service creates; a file being served stays readable
        # after unlinking, so a replaced release never cuts a download short.
        for path in self.config.cache.iterdir():
            if BLOB.fullmatch(path.name) and path.name not in keep and path.is_file():
                path.unlink(missing_ok=True)

    def run(self):
        while True:
            self.wake.clear()  # a page view during a long mirror run asks again
            try:
                self.check()
                self.mirror()
                delay = self.config.interval
            except Exception as error:  # keep serving what is known; retry soon
                log(f'release sync failed: {error}')
                with self.lock:
                    self.error = str(error)
                delay = min(self.config.interval, 60)
            self.wake.wait(delay)
            time.sleep(max(0.0, MIN_CHECK_GAP - (time.time() - self.attempted)))


def parse_range(header: str | None, size: int):
    """Return an inclusive (start, end) for one byte range, or None to send
    the whole file. Raises Unsatisfiable for a range past the end."""
    match = re.fullmatch(r'bytes=(\d*)-(\d*)', (header or '').strip())
    if not match or match.groups() == ('', ''):
        return None  # absent, malformed or multi-range: send everything
    first, last = match.groups()
    if not first:
        if int(last) == 0 or size == 0:
            raise Unsatisfiable
        return max(0, size - int(last)), size - 1
    start = int(first)
    if last and int(last) < start:
        return None
    if start >= size:
        raise Unsatisfiable
    return start, min(int(last), size - 1) if last else size - 1


def human_size(size: int) -> str:
    megabytes = size / 1_000_000
    return f'{megabytes:.0f} MB' if megabytes >= 100 else f'{megabytes:.1f} MB'


def release_date(stamp: str) -> str:
    try:
        moment = datetime.fromisoformat(stamp.replace('Z', '+00:00'))
    except ValueError:
        return ''
    return f'{moment.day} {moment:%b %Y}'


def download_name(target: Target, package: dict) -> str:
    version = re.sub(r'[^0-9A-Za-z._-]', '', package['version']) or 'latest'
    return f'briani-player-{version}-{target.suffix}'


def inline_hashes(template: str) -> str:
    """CSP sources that allow exactly the page's own inline style and script."""
    def sources(tag):
        bodies = re.findall(rf'<{tag}>(.*?)</{tag}>', template, re.S)
        digests = (base64.b64encode(hashlib.sha256(body.encode()).digest()).decode() for body in bodies)
        return ' '.join(f"'sha256-{digest}'" for digest in digests) or "'none'"
    return f'style-src {sources("style")}; script-src {sources("script")}'


def render(template: str, packages: dict, host: str | None, checked: float | None, server_url: str) -> str:
    esc = lambda value: html.escape(str(value), quote=True)
    origin = host if host and HOST.fullmatch(host) else None
    values = {
        'origin': esc(origin or ''),
        'shortlinks.hidden': '' if origin else ' hidden',
        'server.url': esc(server_url),
        'server.hidden': '' if server_url else ' hidden',
        'checked.iso': esc(datetime.fromtimestamp(checked, timezone.utc).isoformat(timespec='seconds')) if checked else '',
        'checked.text': esc(f'{datetime.fromtimestamp(checked, timezone.utc):%d %b %Y, %H:%M} UTC') if checked else 'not yet',
        'qr.android': qr_svg(f'http://{origin}/android') if origin else '',
    }
    newest = max(packages.values(), key=lambda p: p['created'], default=None)
    if newest:
        channel = 'Pre-release' if newest['prerelease'] else 'Stable'
        values.update({
            'release.label': esc(' · '.join(filter(None, (f'v{newest["version"]}', channel, release_date(newest['published']))))),
            'release.tag': esc(newest['tag']),
            'release.notes': esc(newest['notes']),
            'release.hidden': '',
        })
    else:
        values.update({'release.label': 'Looking for the latest release…', 'release.tag': '',
                       'release.notes': '', 'release.hidden': ' hidden'})
    rows = []
    for target in TARGETS:
        package = packages.get(target.key)
        prefix = target.key + '.'
        if package:
            name = download_name(target, package)
            values.update({prefix + 'ready': 'true', prefix + 'version': esc('v' + package['version']),
                           prefix + 'size': esc(human_size(package['size'])), prefix + 'file': esc(name)})
            if target.key != 'tv':  # the TV and phone rows would repeat the same APK
                rows.append(f'<tr><td>{esc(name)}</td><td><code>{esc(package["sha256"] or "Not published")}</code></td>'
                            + (f'<td><button class="copy" type="button" data-copy="{esc(package["sha256"])}" aria-label="Copy SHA-256 of {esc(name)}"></button></td>' if package['sha256'] else '<td></td>')
                            + '</tr>')
        else:
            values.update({prefix + 'ready': 'false', prefix + 'version': 'Not published',
                           prefix + 'size': '—', prefix + 'file': ''})
    values['checksums'] = '\n'.join(rows) or '<tr><td colspan="3">No packages yet.</td></tr>'
    return PLACEHOLDER.sub(lambda match: values[match.group(1)], template)


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = 'BrianiDownloads'
    timeout = 120

    def version_string(self): return self.server_version

    def do_GET(self): self.route(body=True)
    def do_HEAD(self): self.route(body=False)

    def route(self, body: bool):
        path = urllib.parse.urlsplit(self.path).path
        path = path.rstrip('/') or '/'
        mirror: Mirror = self.server.mirror
        if path == '/':
            mirror.request_check()
            return self.page(body)
        if path == '/healthz':
            return self.health(body)
        if path.lstrip('/') in TARGET_KEYS:
            mirror.request_check()
            return self.download(TARGET_KEYS[path.lstrip('/')], body)
        self.text(404, 'Not found.\n', body)

    def common_headers(self):
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')

    def text(self, status: int, message: str, body: bool, headers=()):
        data = message.encode()
        self.send_response(status)
        self.send_header('Content-Type', 'text/plain; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        for name, value in headers:
            self.send_header(name, value)
        self.common_headers()
        self.end_headers()
        if body:
            self.wfile.write(data)

    def page(self, body: bool):
        packages, checked, _ = self.server.mirror.snapshot()
        data = render(self.server.template, packages, self.headers.get('Host'), checked,
                      self.server.mirror.config.server_url).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Content-Security-Policy', "default-src 'none'; img-src data:; base-uri 'none'; "
                         "form-action 'none'; frame-ancestors 'none'; " + self.server.inline_sources)
        self.common_headers()
        self.end_headers()
        if body:
            self.wfile.write(data)

    def health(self, body: bool):
        mirror: Mirror = self.server.mirror
        packages, checked, error = mirror.snapshot()
        report = {'checked': checked, 'error': error, 'packages': {
            key: {'tag': p['tag'], 'asset': p['asset'], 'mirrored': mirror.local_path(p) is not None}
            for key, p in packages.items()}}
        data = json.dumps(report).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.common_headers()
        self.end_headers()
        if body:
            self.wfile.write(data)

    def download(self, target: Target, body: bool):
        packages, _, _ = self.server.mirror.snapshot()
        package = packages.get(target.key)
        if not package:
            return self.text(503, 'This package has not been published in a release yet. Try again later.\n',
                             body, [('Retry-After', '120')])
        name = download_name(target, package)
        path = self.server.mirror.local_path(package)
        if path:
            self.send_local(path, package, name, body)
        else:
            self.relay(package, name, body)

    def package_headers(self, package: dict, name: str):
        extension = '.apk' if name.endswith('.apk') else Path(name).suffix
        self.send_header('Content-Type', CONTENT_TYPES.get(extension, 'application/octet-stream'))
        self.send_header('Content-Disposition', f'attachment; filename="{name}"')
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Cache-Control', 'no-cache')
        if package['sha256']:
            self.send_header('ETag', f'"{package["sha256"]}"')
        self.common_headers()

    def wanted_range(self, package: dict):
        validator = self.headers.get('If-Range')
        if validator and validator.strip() != f'"{package["sha256"]}"':
            return None
        return parse_range(self.headers.get('Range'), package['size'])

    def send_local(self, path: Path, package: dict, name: str, body: bool):
        size = package['size']
        try:
            span = self.wanted_range(package)
        except Unsatisfiable:
            return self.text(416, 'Requested range is past the end of the file.\n', body,
                             [('Content-Range', f'bytes */{size}')])
        start, end = span or (0, size - 1)
        with open(path, 'rb') as source:
            self.send_response(206 if span else 200)
            self.package_headers(package, name)
            self.send_header('Content-Length', str(end - start + 1))
            if span:
                self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
            self.end_headers()
            if body and size:
                try:
                    self.connection.sendfile(source, start, end - start + 1)
                except (BrokenPipeError, ConnectionResetError, TimeoutError):
                    pass

    def relay(self, package: dict, name: str, body: bool):
        if not body:
            self.send_response(200)
            self.package_headers(package, name)
            self.send_header('Content-Length', str(package['size']))
            return self.end_headers()
        headers = {'User-Agent': USER_AGENT}
        span = (self.headers.get('Range') or '').strip()
        if re.fullmatch(r'bytes=\d*-\d*', span) and span != 'bytes=-':
            headers['Range'] = span
        try:
            upstream = self.server.mirror.open(urllib.request.Request(package['url'], headers=headers), timeout=30)
        except urllib.error.HTTPError as error:
            if error.code == 416:
                return self.text(416, 'Requested range is past the end of the file.\n', body,
                                 [('Content-Range', f'bytes */{package["size"]}')])
            return self.text(502, f'GitHub answered {error.code}. Try again shortly.\n', body)
        except (OSError, urllib.error.URLError):
            return self.text(502, 'GitHub could not be reached. Try again shortly.\n', body)
        with upstream:
            self.send_response(upstream.status)
            self.package_headers(package, name)
            for header in ('Content-Length', 'Content-Range'):
                if upstream.headers.get(header):
                    self.send_header(header, upstream.headers[header])
            self.end_headers()
            try:
                while chunk := upstream.read(CHUNK):
                    self.wfile.write(chunk)
            except (BrokenPipeError, ConnectionResetError, TimeoutError):
                pass


# --- QR code: byte mode, error correction level M, versions 1-6 -------------
# Enough for any short download address (up to 106 bytes), and small: these
# versions have no version-information blocks and a single alignment pattern.
QR_VERSIONS = {1: (10, 16, 1), 2: (16, 28, 1), 3: (26, 44, 1), 4: (18, 32, 2), 5: (24, 43, 2), 6: (16, 27, 4)}
GF_EXP, GF_LOG = [0] * 512, [0] * 256
_value = 1
for _power in range(255):
    GF_EXP[_power], GF_LOG[_value] = _value, _power
    _value = _value << 1 ^ (0x11d if _value & 0x80 else 0)
for _power in range(255, 512):
    GF_EXP[_power] = GF_EXP[_power - 255]


def gf_multiply(a: int, b: int) -> int:
    return GF_EXP[GF_LOG[a] + GF_LOG[b]] if a and b else 0


def reed_solomon(data: list, count: int) -> list:
    generator = [1]
    for power in range(count):
        generator = [a ^ gf_multiply(b, GF_EXP[power]) for a, b in zip(generator + [0], [0] + generator)]
    remainder = list(data) + [0] * count
    for index in range(len(data)):
        factor = remainder[index]
        if factor:
            for offset, coefficient in enumerate(generator):
                remainder[index + offset] ^= gf_multiply(coefficient, factor)
    return remainder[len(data):]


def qr_matrix(text: str) -> list | None:
    data = text.encode()
    version = next((v for v, (_, per, blocks) in QR_VERSIONS.items() if len(data) <= per * blocks - 2), None)
    if version is None:
        return None
    ec_count, per_block, block_count = QR_VERSIONS[version]
    capacity = per_block * block_count * 8
    bits = '0100' + f'{len(data):08b}' + ''.join(f'{byte:08b}' for byte in data)
    bits += '0' * min(4, capacity - len(bits))
    bits += '0' * (-len(bits) % 8)
    codewords = [int(bits[i:i + 8], 2) for i in range(0, len(bits), 8)]
    codewords += [(0xEC, 0x11)[i % 2] for i in range(per_block * block_count - len(codewords))]
    blocks = [codewords[i * per_block:(i + 1) * per_block] for i in range(block_count)]
    corrections = [reed_solomon(block, ec_count) for block in blocks]
    stream = [block[i] for i in range(per_block) for block in blocks]
    stream += [block[i] for i in range(ec_count) for block in corrections]
    bits = ''.join(f'{codeword:08b}' for codeword in stream) + '0' * (7 if version > 1 else 0)

    size = 17 + 4 * version
    grid = [[False] * size for _ in range(size)]
    reserved = [[False] * size for _ in range(size)]

    def put(row, col, dark):
        grid[row][col], reserved[row][col] = dark, True

    for top, left in ((0, 0), (0, size - 7), (size - 7, 0)):
        for r in range(-1, 8):
            for c in range(-1, 8):
                if 0 <= top + r < size and 0 <= left + c < size:
                    ring = max(abs(r - 3), abs(c - 3))
                    put(top + r, left + c, ring != 2 and ring != 4)
    for i in range(8, size - 8):
        put(6, i, i % 2 == 0)
        put(i, 6, i % 2 == 0)
    if version > 1:
        center = size - 7
        for r in range(-2, 3):
            for c in range(-2, 3):
                put(center + r, center + c, max(abs(r), abs(c)) != 1)
    for i in range(9):  # format areas, filled in after masking
        reserved[8][i] = reserved[i][8] = True
    for i in range(8):
        reserved[8][size - 1 - i] = reserved[size - 1 - i][8] = True

    index, upward, col = 0, True, size - 1
    while col > 0:
        if col == 6:
            col -= 1
        for step in range(size):
            row = size - 1 - step if upward else step
            for c in (col, col - 1):
                if not reserved[row][c]:
                    grid[row][c] = index < len(bits) and bits[index] == '1'
                    index += 1
        upward, col = not upward, col - 2

    masks = (lambda r, c: (r + c) % 2 == 0, lambda r, c: r % 2 == 0, lambda r, c: c % 3 == 0,
             lambda r, c: (r + c) % 3 == 0, lambda r, c: (r // 2 + c // 3) % 2 == 0,
             lambda r, c: r * c % 2 + r * c % 3 == 0, lambda r, c: (r * c % 2 + r * c % 3) % 2 == 0,
             lambda r, c: ((r + c) % 2 + r * c % 3) % 2 == 0)

    def finished(mask):
        modules = [[grid[r][c] ^ (not reserved[r][c] and masks[mask](r, c)) for c in range(size)] for r in range(size)]
        format_data = mask  # level M is 00
        remainder = format_data
        for _ in range(10):
            remainder = remainder << 1 ^ (remainder >> 9) * 0x537
        word = (format_data << 10 | remainder) ^ 0x5412
        bit = lambda i: bool(word >> i & 1)
        for i in range(6):
            modules[i][8] = bit(i)
        modules[7][8], modules[8][8], modules[8][7] = bit(6), bit(7), bit(8)
        for i in range(9, 15):
            modules[8][14 - i] = bit(i)
        for i in range(8):
            modules[8][size - 1 - i] = bit(i)
        for i in range(8, 15):
            modules[size - 15 + i][8] = bit(i)
        modules[size - 8][8] = True
        return modules

    return min((finished(mask) for mask in range(8)), key=qr_penalty)


def qr_penalty(modules: list) -> int:
    size, score = len(modules), 0
    lines = modules + [list(column) for column in zip(*modules)]
    for line in lines:
        run = 1
        for i in range(1, size + 1):
            if i < size and line[i] == line[i - 1]:
                run += 1
            else:
                score += run - 2 if run >= 5 else 0
                run = 1
        text = ''.join('1' if m else '0' for m in line)
        score += 40 * (text.count('10111010000') + text.count('00001011101'))
    for r in range(size - 1):
        for c in range(size - 1):
            if modules[r][c] == modules[r][c + 1] == modules[r + 1][c] == modules[r + 1][c + 1]:
                score += 3
    dark = sum(map(sum, modules))
    score += 10 * (abs(dark * 20 - size * size * 10) // (size * size))
    return score


def qr_svg(text: str) -> str:
    modules = qr_matrix(text)
    if not modules:
        return ''
    quiet, size = 4, len(modules)
    path = ''.join(f'M{c + quiet} {r + quiet}h1v1h-1z' for r, row in enumerate(modules) for c, dark in enumerate(row) if dark)
    return (f'<svg class="qr-code" viewBox="0 0 {size + 2 * quiet} {size + 2 * quiet}" role="img" '
            f'aria-label="QR code for {html.escape(text, quote=True)}" shape-rendering="crispEdges">'
            f'<rect width="100%" height="100%" fill="#fff"/><path fill="#0b1626" d="{path}"/></svg>')


def log(message: str):
    print(f'{datetime.now(timezone.utc):%Y-%m-%dT%H:%M:%SZ} {message}', file=sys.stderr, flush=True)


def serve(config: Config, mirror: Mirror | None = None, address: str = '') -> http.server.ThreadingHTTPServer:
    template = (HERE / 'page.html').read_text()
    server = http.server.ThreadingHTTPServer((address, config.port), Handler)
    server.daemon_threads = True
    server.mirror = mirror or Mirror(config)
    server.template, server.inline_sources = template, inline_hashes(template)
    return server


def main():
    config = Config.from_env()
    config.cache.mkdir(parents=True, exist_ok=True)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))  # PID 1 has no default handler
    server = serve(config)
    threading.Thread(target=server.mirror.run, name='mirror', daemon=True).start()
    log(f'serving downloads for {config.repo} on port {config.port}')
    server.serve_forever()


if __name__ == '__main__':
    main()
