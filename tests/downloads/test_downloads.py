from __future__ import annotations
import hashlib, http.server, importlib.util, json, re, shutil, subprocess, sys, tempfile, threading, unittest, urllib.error, urllib.request
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('briani_downloads', ROOT / 'infra/downloads/server.py')
downloads = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = downloads
spec.loader.exec_module(downloads)

APK, LINUX = b'apk-bytes-' * 5000, b'linux-bundle-' * 3000


def asset(name, data, ident, base, digest=True):
    entry = {'id': ident, 'name': name, 'size': len(data), 'state': 'uploaded',
             'browser_download_url': f'{base}/dl/{ident}/{name}'}
    if digest:
        entry['digest'] = 'sha256:' + hashlib.sha256(data).hexdigest()
    return entry


class FakeGitHub:
    """Serves a release list (with ETag support) and asset bytes, honouring Range."""

    def __init__(self):
        self.releases, self.blobs, self.requests = [], {}, []
        owner = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args): pass

            def do_GET(self):
                owner.requests.append((self.path, dict(self.headers)))
                if self.path.startswith('/repos/'):
                    body = json.dumps(owner.releases).encode()
                    etag = '"' + hashlib.sha256(body).hexdigest() + '"'
                    if self.headers.get('If-None-Match') == etag:
                        self.send_response(304)
                        return self.end_headers()
                    self.send_response(200)
                    self.send_header('ETag', etag)
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    return self.wfile.write(body)
                data = owner.blobs.get(self.path)
                if data is None:
                    self.send_response(404)
                    return self.end_headers()
                span = re.fullmatch(r'bytes=(\d+)-(\d*)', self.headers.get('Range') or '')
                if span:
                    start = int(span.group(1))
                    end = int(span.group(2)) if span.group(2) else len(data) - 1
                    self.send_response(206)
                    self.send_header('Content-Range', f'bytes {start}-{end}/{len(data)}')
                    data = data[start:end + 1]
                else:
                    self.send_response(200)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)

        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.base = f'http://127.0.0.1:{self.server.server_port}'
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def publish(self, tag, created, files, prerelease=True, draft=False, digest=True):
        assets = []
        for name, data in files:
            ident = len(self.blobs) + 1
            entry = asset(name, data, ident, self.base, digest)
            self.blobs[f'/dl/{ident}/{name}'] = data
            assets.append(entry)
        self.releases.insert(0, {'tag_name': tag, 'name': f'Briani Player {tag}', 'draft': draft,
                                 'prerelease': prerelease, 'created_at': created,
                                 'published_at': created, 'html_url': f'{self.base}/releases/{tag}',
                                 'assets': assets})

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class DownloadPageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cache = Path(self.tmp.name)
        self.github = FakeGitHub()
        self.addCleanup(self.github.close)
        for quiet in (patch.object(downloads.Handler, 'log_message', lambda *args: None),
                      patch.object(downloads, 'log', lambda message: None)):
            quiet.start()
            self.addCleanup(quiet.stop)
        self.addCleanup(self.tmp.cleanup)
        self.config = downloads.Config.from_env({
            'DOWNLOADS_API': self.github.base, 'DOWNLOADS_REPO': 'owner/repo',
            'DOWNLOADS_CACHE': str(self.cache), 'DOWNLOADS_PORT': '0',
            'DOWNLOADS_SERVER_URL': 'http://192.168.1.50:8088'})

    def start(self, mirror):
        server = downloads.serve(self.config, mirror, '127.0.0.1')
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return f'http://127.0.0.1:{server.server_port}'

    def get(self, url, method='GET', headers=None):
        request = urllib.request.Request(url, method=method, headers=headers or {})
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                return response.status, response.headers, response.read()
        except urllib.error.HTTPError as error:
            with error:
                return error.code, error.headers, error.read()

    def publish_v12(self, **options):
        self.github.publish('v1.2.0', '2026-10-16T14:48:06Z',
                            [('briani-player-local-test.apk', APK), ('briani-player-unsigned.apk', b'unsigned'),
                             ('briani-player-linux-x64.tar.gz', LINUX)], **options)

    def test_resolve_takes_the_newest_release_that_ships_each_package(self):
        base = self.github.base
        releases = [
            {'tag_name': 'v2.0.0', 'draft': True, 'created_at': '2026-12-01T00:00:00Z',
             'assets': [asset('briani-player-linux-x64.tar.gz', b'draft', 9, base)]},
            {'tag_name': 'v1.3.0', 'prerelease': False, 'created_at': '2026-11-01T00:00:00Z',
             'assets': [asset('briani-player-local-test.apk', b'new apk', 5, base)]},
            {'tag_name': 'v1.2.0', 'prerelease': True, 'created_at': '2026-10-16T00:00:00Z',
             'assets': [asset('briani-player-local-test.apk', b'apk', 1, base),
                        asset('briani-player-linux-x64.tar.gz', b'linux', 2, base)]},
            {'tag_name': 'v1.2.1', 'prerelease': True, 'created_at': '2026-10-20T00:00:00Z',
             'assets': [asset('briani-player-linux-x64.tar.gz', b'pre linux', 7, base)]},
        ]
        found = downloads.resolve(releases, self.config.assets, prereleases=True)
        self.assertEqual({k: v['tag'] for k, v in found.items()}, {'tv': 'v1.3.0', 'android': 'v1.3.0', 'linux': 'v1.2.1'})
        self.assertEqual(found['tv']['blob'], found['android']['blob'])
        stable = downloads.resolve(releases, self.config.assets, prereleases=False)
        self.assertEqual({k: v['tag'] for k, v in stable.items()}, {'tv': 'v1.3.0', 'android': 'v1.3.0'})

    def test_sizes_read_like_a_download_page(self):
        self.assertEqual(downloads.human_size(238810925), '239 MB')
        self.assertEqual(downloads.human_size(11694591), '11.7 MB')

    def test_byte_ranges(self):
        parse = downloads.parse_range
        self.assertIsNone(parse(None, 100))
        self.assertEqual(parse('bytes=0-9', 100), (0, 9))
        self.assertEqual(parse('bytes=90-', 100), (90, 99))
        self.assertEqual(parse('bytes=-10', 100), (90, 99))
        self.assertEqual(parse('bytes=-500', 100), (0, 99))
        self.assertEqual(parse('bytes=50-5000', 100), (50, 99))
        for ignored in ('bytes=9-1', 'bytes=0-1,5-9', 'items=0-1', 'bytes=-'):
            self.assertIsNone(parse(ignored, 100), ignored)
        for unsatisfiable in ('bytes=100-', 'bytes=-0'):
            with self.assertRaises(downloads.Unsatisfiable):
                parse(unsatisfiable, 100)

    def test_mirrored_packages_are_served_from_the_cache_with_ranges(self):
        self.publish_v12()
        mirror = downloads.Mirror(self.config)
        self.assertTrue(mirror.check())
        mirror.mirror()
        digest = hashlib.sha256(APK).hexdigest()
        self.assertEqual((self.cache / digest).read_bytes(), APK)
        self.assertEqual(sorted(p.name for p in self.cache.iterdir()),
                         sorted([digest, hashlib.sha256(LINUX).hexdigest(), 'state.json']))
        base = self.start(mirror)
        fetched = len(self.github.requests)

        status, headers, body = self.get(base + '/tv')
        self.assertEqual((status, body), (200, APK))
        self.assertEqual(headers['Content-Type'], 'application/vnd.android.package-archive')
        self.assertEqual(headers['Content-Disposition'], 'attachment; filename="briani-player-1.2.0-android-tv.apk"')
        self.assertEqual(headers['ETag'], f'"{digest}"')
        status, headers, body = self.get(base + '/android', headers={'Range': 'bytes=10-19'})
        self.assertEqual((status, body, headers['Content-Range']), (206, APK[10:20], f'bytes 10-19/{len(APK)}'))
        self.assertIn('android.apk', headers['Content-Disposition'])
        status, headers, _ = self.get(base + '/android', headers={'Range': f'bytes={len(APK)}-'})
        self.assertEqual((status, headers['Content-Range']), (416, f'bytes */{len(APK)}'))
        status, _, body = self.get(base + '/android', headers={'Range': 'bytes=0-9', 'If-Range': '"stale"'})
        self.assertEqual((status, body), (200, APK))
        status, headers, body = self.get(base + '/linux', method='HEAD')
        self.assertEqual((status, body, headers['Content-Length']), (200, b'', str(len(LINUX))))
        self.assertEqual(headers['Content-Type'], 'application/gzip')
        self.assertEqual(self.get(base + '/linux/')[2], LINUX)
        self.assertEqual(len(self.github.requests), fetched, 'cached downloads must not touch GitHub')

        for missing in ('/etc/passwd', '/../state.json', '/' + digest, '/download/tv'):
            self.assertEqual(self.get(base + missing)[0], 404, missing)
        status, _, body = self.get(base + '/healthz')
        report = json.loads(body)
        self.assertEqual(report['packages']['linux'], {'tag': 'v1.2.0', 'asset': 'briani-player-linux-x64.tar.gz', 'mirrored': True})

    def test_page_lists_each_package_and_allows_only_its_own_inline_code(self):
        self.publish_v12()
        mirror = downloads.Mirror(self.config)
        mirror.check()
        base = self.start(mirror)
        status, headers, body = self.get(base + '/')
        page = body.decode()
        self.assertEqual(status, 200)
        self.assertNotIn('{{', page)
        self.assertIn('v1.2.0 · Pre-release · 16 Oct 2026', page)
        self.assertIn('href="/tv" download="briani-player-1.2.0-android-tv.apk"', page)
        self.assertIn('href="/linux" download="briani-player-1.2.0-linux-x64.tar.gz"', page)
        self.assertIn(hashlib.sha256(LINUX).hexdigest(), page)
        self.assertIn('http://192.168.1.50:8088', page)
        self.assertIn(f'<code>127.0.0.1:{base.rsplit(":", 1)[1]}/tv</code>', page)
        self.assertIn('class="qr-code"', page)
        policy = headers['Content-Security-Policy']
        self.assertIn("default-src 'none'", policy)
        for tag, kind in (('style', 'style-src'), ('script', 'script-src')):
            inline = re.search(rf'<{tag}>(.*?)</{tag}>', page, re.S).group(1)
            self.assertNotIn('{{', inline)
            self.assertIn(kind + " 'sha256-", policy)
            self.assertIn(downloads.inline_hashes(f'<{tag}>{inline}</{tag}>').split(kind + ' ')[1].split(';')[0], policy)

    def test_hostile_host_header_is_not_reflected(self):
        template = (ROOT / 'infra/downloads/page.html').read_text()
        page = downloads.render(template, {}, '"><script>alert(1)</script>', None, '')
        self.assertNotIn('alert(1)', page)
        self.assertNotIn('{{', page)
        self.assertIn('data-ready="false"', page)
        self.assertIn('Looking for the latest release', page)

    def test_unmirrored_package_is_relayed_without_sending_the_browser_to_github(self):
        self.publish_v12()
        mirror = downloads.Mirror(self.config)
        mirror.check()  # listed, not mirrored yet
        base = self.start(mirror)
        status, headers, body = self.get(base + '/linux')
        self.assertEqual((status, body), (200, LINUX))
        self.assertEqual(headers['Content-Disposition'], 'attachment; filename="briani-player-1.2.0-linux-x64.tar.gz"')
        status, headers, body = self.get(base + '/linux', headers={'Range': 'bytes=5-9'})
        self.assertEqual((status, body, headers['Content-Range']), (206, LINUX[5:10], f'bytes 5-9/{len(LINUX)}'))
        status, headers, body = self.get(base + '/tv', method='HEAD')
        self.assertEqual((status, headers['Content-Length']), (200, str(len(APK))))

    def test_corrupt_download_is_never_cached(self):
        self.publish_v12()
        apk_path = next(path for path in self.github.blobs if path.endswith('local-test.apk'))
        self.github.blobs[apk_path] = b'X' * len(APK)  # right size, wrong bytes
        mirror = downloads.Mirror(self.config)
        mirror.check()
        with self.assertRaisesRegex(downloads.MirrorError, 'SHA-256'):
            mirror.mirror()
        names = [p.name for p in self.cache.iterdir()]
        self.assertNotIn(hashlib.sha256(APK).hexdigest(), names)
        self.assertFalse([n for n in names if n.endswith('.part')])
        self.assertIn(hashlib.sha256(LINUX).hexdigest(), names, 'the other package still mirrors')

    def test_new_release_replaces_old_copies_and_state_survives_restart(self):
        self.publish_v12()
        mirror = downloads.Mirror(self.config)
        mirror.check()
        mirror.mirror()
        self.assertFalse(mirror.check(), 'unchanged list is answered with 304')
        newer_apk = b'newer apk' * 100
        self.github.publish('v1.3.0', '2026-11-01T00:00:00Z', [('briani-player-local-test.apk', newer_apk)])
        self.assertTrue(mirror.check())
        mirror.mirror()
        names = sorted(p.name for p in self.cache.iterdir())
        self.assertEqual(names, sorted([hashlib.sha256(newer_apk).hexdigest(), hashlib.sha256(LINUX).hexdigest(), 'state.json']))

        self.github.close()  # GitHub unreachable: a restarted service still serves its cache
        restarted = downloads.Mirror(self.config)
        base = self.start(restarted)
        status, headers, body = self.get(base + '/tv')
        self.assertEqual((status, body), (200, newer_apk))
        self.assertIn('1.3.0-android-tv.apk', headers['Content-Disposition'])
        self.assertEqual(self.get(base + '/linux')[2], LINUX)

    def test_package_without_any_release_answers_unavailable(self):
        mirror = downloads.Mirror(self.config)
        mirror.check()
        base = self.start(mirror)
        status, headers, _ = self.get(base + '/android')
        self.assertEqual((status, headers['Retry-After']), (503, '120'))

    def test_qr_codes_cover_short_and_long_addresses(self):
        self.assertIsNone(downloads.qr_matrix('x' * 107))
        sizes = {len(downloads.qr_matrix('x' * n)) for n in (1, 20, 40, 60, 80, 106)}
        self.assertEqual(sizes, {21, 25, 29, 33, 37, 41})

    @unittest.skipUnless(shutil.which('zbarimg') and shutil.which('rsvg-convert'), 'needs zbarimg and rsvg-convert')
    def test_qr_codes_decode(self):
        for text in ('http://192.168.1.50:8089/android', 'http://briani-downloads.home.arpa:8089/android', 'y' * 106):
            svg = downloads.qr_svg(text).replace('<svg ', '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" ', 1)
            image = subprocess.run(['rsvg-convert'], input=svg.encode(), capture_output=True, check=True).stdout
            png = self.cache / 'qr.png'
            png.write_bytes(image)
            decoded = subprocess.run(['zbarimg', '-q', '--raw', str(png)], capture_output=True, text=True)
            self.assertEqual(decoded.stdout.rstrip('\n'), text)


if __name__ == '__main__':
    unittest.main()
