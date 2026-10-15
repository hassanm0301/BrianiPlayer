#!/usr/bin/env python3
"""Bounded real-image M07 connected Linux desktop proof of early playback through Briani's production API."""
from __future__ import annotations

import argparse
import hashlib
import http.client
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import socket
import signal
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_GENERATOR = ROOT / "prototypes/playback/fixtures/generate.py"
VLC_PROBE = ROOT / "prototypes/playback/production/vlc_probe.py"
QBIT_IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
API_IMAGE = "briani-server:m10"
TEMP_PASSWORD = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)
MIN_PREFIX = 16 * 1024 * 1024
DOWNLOAD_LIMIT = 512 * 1024
UI_DOWNLOAD_LIMIT = 128 * 1024


def docker(*args: str) -> str:
    result = subprocess.run(["docker", *args], check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(f"docker {args[0]} failed ({result.returncode}): {(result.stderr or '')[-800:]}")
    return result.stdout.strip()


def wait_for(label: str, predicate, timeout: float = 120):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(.25)
    raise TimeoutError(f"timed out after {timeout:g}s waiting for {label}")


def labels(resource: str, name: str) -> dict:
    if resource == "network":
        result = json.loads(docker("network", "inspect", name))[0]
        return result.get("Labels") or {}
    result = json.loads(docker("inspect", name))[0]
    return result.get("Config", {}).get("Labels") or {}


def bdecode(data: bytes):
    def read(pos: int):
        marker = data[pos:pos + 1]
        if marker == b"i":
            end = data.index(b"e", pos + 1)
            return int(data[pos + 1:end]), end + 1
        if marker == b"l":
            values, pos = [], pos + 1
            while data[pos:pos + 1] != b"e":
                value, pos = read(pos)
                values.append(value)
            return values, pos + 1
        if marker == b"d":
            values, pos = {}, pos + 1
            while data[pos:pos + 1] != b"e":
                key, pos = read(pos)
                value, pos = read(pos)
                values[key] = value
            return values, pos + 1
        colon = data.index(b":", pos)
        length, start = int(data[pos:colon]), colon + 1
        return data[start:start + length], start + length
    value, end = read(0)
    if end != len(data):
        raise ValueError("trailing bytes in torrent")
    return value


def bencode(value) -> bytes:
    if isinstance(value, int):
        return b"i" + str(value).encode() + b"e"
    if isinstance(value, bytes):
        return str(len(value)).encode() + b":" + value
    if isinstance(value, list):
        return b"l" + b"".join(bencode(item) for item in value) + b"e"
    if isinstance(value, dict):
        return b"d" + b"".join(bencode(k) + bencode(value[k]) for k in sorted(value)) + b"e"
    raise TypeError(type(value).__name__)


def v1_infohash(torrent: Path) -> str:
    info = bdecode(torrent.read_bytes()).get(b"info")
    if not isinstance(info, dict) or b"pieces" not in info:
        raise RuntimeError("generated torrent has no v1 info dictionary")
    return hashlib.sha1(bencode(info)).hexdigest()


class Api:
    def __init__(self, origin: str):
        self.origin = origin.rstrip("/")
        self.token: str | None = None
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def request(self, path: str, body=None, *, method=None, headers=None, raw=None, content_type="application/json"):
        data = raw if raw is not None else (None if body is None else json.dumps(body).encode())
        head = {"Accept": "application/json", "Host": "briani:8088", **(headers or {})}
        if data is not None:
            head.setdefault("Content-Type", content_type)
        if self.token:
            head["Authorization"] = "Bearer " + self.token
        request = urllib.request.Request(self.origin + path, data=data, headers=head, method=method)
        try:
            with self.opener.open(request, timeout=12) as response:
                return response.status, dict(response.headers), response.read()
        except urllib.error.HTTPError as error:
            return error.code, dict(error.headers), error.read()

    def json(self, path: str, body=None, **kwargs):
        status, _, payload = self.request(path, body, **kwargs)
        if not 200 <= status < 300:
            raise RuntimeError(f"API {path} returned {status}: {payload[:300].decode(errors='replace')}")
        return json.loads(payload) if payload else None


class Qbit:
    def __init__(self, origin: str, password: str):
        self.origin, self.password = origin.rstrip("/"), password
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.cookie = ""
        self.login()

    def call(self, path: str, fields=None, *, data=None, content_type="application/x-www-form-urlencoded"):
        fields = fields or {}
        if data is None:
            data = urllib.parse.urlencode(fields).encode() if fields else None
        request = urllib.request.Request(self.origin + "/api/v2/" + path, data=data,
            headers={"Cookie": self.cookie, "Origin": self.origin, "Referer": self.origin + "/",
                     **({"Content-Type": content_type} if data is not None else {})})
        with self.opener.open(request, timeout=10) as response:
            return response.read()

    def login(self):
        data = urllib.parse.urlencode({"username": "admin", "password": self.password}).encode()
        request = urllib.request.Request(self.origin + "/api/v2/auth/login", data=data,
            headers={"Origin": self.origin, "Referer": self.origin + "/"})
        with self.opener.open(request, timeout=8) as response:
            cookie = response.headers.get("Set-Cookie", "")
        if not re.search(r"(?:SID|QBT_SID(?:_[^=;]+)?)=", cookie):
            raise RuntimeError("qBittorrent did not issue a session cookie")
        self.cookie = cookie.split(";", 1)[0]

    def json(self, path: str, fields=None):
        query = "" if not fields else "?" + urllib.parse.urlencode(fields)
        request = urllib.request.Request(self.origin + "/api/v2/" + path + query,
            headers={"Cookie": self.cookie, "Origin": self.origin, "Referer": self.origin + "/"})
        with self.opener.open(request, timeout=10) as response:
            payload = response.read()
        return json.loads(payload) if payload else None

    def add_torrent(self, torrent: Path, save_path: str):
        boundary = "----briani" + uuid.uuid4().hex
        body = bytearray()
        for key, value in (("savepath", save_path), ("paused", "false"), ("sequentialDownload", "true"),
                           ("firstLastPiecePrio", "true"), ("autoTMM", "false")):
            body.extend(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"\r\n\r\n{value}\r\n".encode())
        body.extend(f"--{boundary}\r\nContent-Disposition: form-data; name=\"torrents\"; filename=\"fixture.torrent\"\r\nContent-Type: application/x-bittorrent\r\n\r\n".encode())
        body.extend(torrent.read_bytes())
        body.extend(f"\r\n--{boundary}--\r\n".encode())
        payload = self.call("torrents/add", data=bytes(body), content_type="multipart/form-data; boundary=" + boundary)
        response = payload.strip()
        if response in (b"Ok.", b""):
            return
        try:
            result = json.loads(response)
        except (ValueError, UnicodeDecodeError):
            raise RuntimeError("qBittorrent returned an unrecognized torrent-add response") from None
        if not isinstance(result, dict) or result.get("success_count") != 1 or result.get("failure_count") != 0:
            raise RuntimeError("qBittorrent did not report exactly one accepted torrent")


def container_ip(name: str, network: str) -> str:
    data = json.loads(docker("inspect", name))[0]
    if data["Config"].get("Labels", {}).get("org.briani.run") is None:
        raise RuntimeError("container is missing owned-run label")
    value = data["NetworkSettings"]["Networks"][network]["IPAddress"]
    if not value:
        raise RuntimeError(f"container {name} has no address on private swarm")
    return value


def allocate_api_ip(network: str) -> str:
    """Pick one unused address from this run's private bridge for host Flutter."""
    info = json.loads(docker("network", "inspect", network))[0]
    configs = info.get("IPAM", {}).get("Config", [])
    if len(configs) != 1 or not configs[0].get("Subnet"):
        raise RuntimeError("owned test network has no single IPv4 subnet")
    subnet = ipaddress.ip_network(configs[0]["Subnet"])
    if subnet.version != 4 or subnet.num_addresses < 16:
        raise RuntimeError("owned test network IPv4 subnet is too small")
    occupied = {ipaddress.ip_address(configs[0]["Gateway"])} if configs[0].get("Gateway") else set()
    for row in (info.get("Containers") or {}).values():
        address = row.get("IPv4Address", "").split("/", 1)[0]
        if address:
            occupied.add(ipaddress.ip_address(address))
    for candidate in list(subnet.hosts())[2:]:
        if candidate not in occupied:
            return str(candidate)
    raise RuntimeError("owned test network has no unused API address")


def mpv_processes() -> set[int]:
    found = set()
    for entry in Path("/proc").glob("[0-9]*"):
        try:
            if (entry / "comm").read_text().strip() == "mpv":
                found.add(int(entry.name))
        except (OSError, ValueError):
            continue
    return found


def terminate_new_mpv(baseline: set[int]) -> list[int]:
    owned = mpv_processes() - baseline
    for pid in owned:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline and (mpv_processes() & owned):
        time.sleep(.1)
    for pid in mpv_processes() & owned:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    return sorted(owned)


def terminate_observed_mpv(pids: set[int]) -> list[int]:
    """Reap only mpv processes observed after the isolated UI handoff."""
    live = mpv_processes() & pids
    for pid in live:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline and (mpv_processes() & live):
        time.sleep(.1)
    for pid in mpv_processes() & live:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    return sorted(pids)


def verify_unpublished(name: str):
    data = json.loads(docker("inspect", name))[0]
    for port, bindings in (data.get("NetworkSettings", {}).get("Ports") or {}).items():
        if bindings:
            raise RuntimeError(f"owned test container unexpectedly publishes {port}")


def qbit_ready(ip: str) -> bool:
    try:
        with socket.create_connection((ip, 8080), timeout=1):
            return True
    except OSError:
        return False


def api_files(api: Api, request_id: str):
    status, _, payload = api.request(f"/api/v1/downloads/{request_id}/files")
    if status != 200:
        return None
    value = json.loads(payload)
    return value.get("items", value) if isinstance(value, dict) else value


def multipart_torrent(api: Api, torrent: Path):
    boundary = "----briani" + uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"fixture.torrent\"\r\n"
            "Content-Type: application/x-bittorrent\r\n\r\n").encode() + torrent.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    return api.json("/api/v1/torrent-uploads", raw=body, content_type="multipart/form-data; boundary=" + boundary)


def http_request(url: str, method="GET", range_value=None, extra_headers=None, timeout=120):
    headers = {"Host": "briani", **(extra_headers or {})}
    if range_value:
        headers["Range"] = range_value
    req = urllib.request.Request(url, method=method, headers=headers)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=timeout) as response:
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers), error.read()


def _mpv_command(connection, reader, command, request_id):
    connection.sendall((json.dumps({"command": command, "request_id": request_id}) + "\n").encode())
    while True:
        message = json.loads(reader.readline())
        if message.get("request_id") == request_id:
            if message.get("error") == "property unavailable":
                return None
            if message.get("error") != "success":
                raise RuntimeError("mpv IPC command failed")
            return message.get("data")


def start_mpv(url: str, run_dir: Path):
    ipc_directory = tempfile.TemporaryDirectory(prefix="briani-m07-mpv-")
    ipc = Path(ipc_directory.name) / "mpv.sock"
    ipc.unlink(missing_ok=True)
    log = (run_dir / "mpv.log").open("w")
    env = {k: v for k, v in os.environ.items() if k.lower() not in ("http_proxy", "https_proxy", "all_proxy")}
    process = subprocess.Popen(["mpv", "--no-config", "--idle=yes", "--vo=null", "--ao=null", "--really-quiet",
        "--http-header-fields=Host: briani", "--cache=yes", "--demuxer-max-bytes=67108864", "--input-ipc-server=" + str(ipc)], stdout=log, stderr=log, env=env)
    process.briani_ipc_directory = ipc_directory
    try:
        wait_for("mpv IPC socket", ipc.exists, 10)
        connection = socket.socket(socket.AF_UNIX)
        connection.settimeout(3)
        connection.connect(str(ipc))
        reader = connection.makefile("rb")
        connection.sendall((json.dumps({"command": ["loadfile", url], "request_id": 0}) + "\n").encode())
        return process, connection, reader, log
    except Exception:
        process.terminate()
        process.wait(timeout=5)
        log.close()
        ipc_directory.cleanup()
        raise


def wait_first_frame(engine: Qbit, torrent_hash: str, url: str, run_dir: Path, timeout=90, allow_complete=False):
    process, connection, reader, log = start_mpv(url, run_dir)
    started = time.monotonic()
    try:
        request_id = 1
        while time.monotonic() - started < timeout:
            if process.poll() is not None:
                raise RuntimeError("mpv exited before reporting a first frame")
            position = _mpv_command(connection, reader, ["get_property", "playback-time"], request_id)
            request_id += 1
            video = _mpv_command(connection, reader, ["get_property", "video-params"], request_id)
            request_id += 1
            if isinstance(position, (int, float)) and position > 0 and isinstance(video, dict) and video.get("w", 0) > 0:
                info = engine.json("torrents/info", {"hashes": torrent_hash})[0]
                if info.get("progress", 1) >= 1 and not allow_complete:
                    raise RuntimeError("mpv first frame occurred after torrent completion")
                return process, connection, reader, log, {"playbackTimeSeconds": position,
                    "firstFrameSeconds": time.monotonic() - started, "engineProgressAtFirstFrame": info.get("progress"),
                    "completedBeforeFirstFrame": info.get("progress", 1) >= 1,
                    "decodedVideo": {key: video.get(key) for key in ("w", "h", "pixelformat")}}
            time.sleep(.15)
        raise TimeoutError(f"mpv produced no first frame within {timeout}s")
    except Exception:
        stop_mpv(process, connection, reader, log)
        raise


def wait_cache_pause(connection, reader, timeout=35):
    # Drain the already verified cache faster; this changes only playback speed,
    # never the engine's sequential schedule or piece priorities.
    _mpv_command(connection, reader, ["set_property", "speed", 8], 51000)
    deadline = time.monotonic() + timeout
    previous = None
    stable_since = None
    request_id = 51001
    while time.monotonic() < deadline:
        paused = _mpv_command(connection, reader, ["get_property", "paused-for-cache"], request_id)
        position = _mpv_command(connection, reader, ["get_property", "playback-time"], request_id + 1)
        request_id += 2
        if paused and isinstance(position, (int, float)):
            if previous is not None and abs(position - previous) < .02:
                stable_since = stable_since or time.monotonic()
                if time.monotonic() - stable_since >= 1:
                    return {"pausedForCache": True, "stableSeconds": time.monotonic() - stable_since,
                            "positionAtPause": position}
            else:
                stable_since = None
            previous = position
        else:
            previous = None
            stable_since = None
        time.sleep(.1)
    raise TimeoutError("mpv did not maintain a stable cache pause while torrent data was unavailable")


def wait_cache_resume(connection, reader, pause_position, timeout=30):
    deadline = time.monotonic() + timeout
    request_id = 52000
    while time.monotonic() < deadline:
        paused = _mpv_command(connection, reader, ["get_property", "paused-for-cache"], request_id)
        position = _mpv_command(connection, reader, ["get_property", "playback-time"], request_id + 1)
        request_id += 2
        if not paused and isinstance(position, (int, float)) and position > pause_position + .1:
            return {"resumed": True, "positionAfterResume": position}
        time.sleep(.1)
    raise TimeoutError("mpv did not resume the same playback after torrent data returned")


def vlc_attempt(network, run_id, session_url, media_run_dir, phase):
    protected_url = media_run_dir / ".vlc-url"
    descriptor = os.open(protected_url, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as output:
        output.write(session_url + "\n")
    try:
        artifacts = media_run_dir / ("vlc-" + phase)
        completed = subprocess.run([sys.executable, str(VLC_PROBE),
            "--network", network, "--run-id", run_id, "--url-file", str(protected_url),
            "--artifacts", str(artifacts)], check=False, timeout=40,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        reports = list(artifacts.glob("*/result.json"))
        if len(reports) != 1:
            raise RuntimeError("VLC probe did not record exactly one current result")
        result = json.loads(reports[0].read_text())
        result["exitCode"] = completed.returncode
        result["phase"] = phase
        return result
    finally:
        protected_url.unlink(missing_ok=True)


def stop_mpv(process, connection, reader, log):
    try:
        _mpv_command(connection, reader, ["quit"], 99999)
    except Exception:
        pass
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    try:
        reader.close()
    except Exception:
        pass
    try:
        connection.close()
    except Exception:
        pass
    log.close()
    if hasattr(process, "briani_ipc_directory"):
        process.briani_ipc_directory.cleanup()
    try:
        log_path = Path(log.name)
        contents = log_path.read_text(encoding="utf-8", errors="replace")
        contents = re.sub(r"https?://[^\s'\"]+", "[redacted-url]", contents)
        log_path.write_text(contents, encoding="utf-8")
    except OSError:
        pass


def raw_range_until_gap(url: str, start: int, end: int, known_prefix: int):
    parsed = urllib.parse.urlsplit(url)
    connection = http.client.HTTPConnection(parsed.hostname, parsed.port or 80, timeout=5)
    connection.putrequest("GET", parsed.path, skip_host=True, skip_accept_encoding=True)
    connection.putheader("Host", "briani")
    connection.putheader("Range", f"bytes={start}-{end}")
    connection.putheader("Connection", "close")
    connection.endheaders()
    transport_socket = connection.sock
    response = connection.getresponse()
    if response.status != 206:
        body = response.read(256)
        connection.close()
        raise RuntimeError(f"gap request returned HTTP {response.status} before body: {body!r}")
    expected_before_gap = known_prefix - start
    body = bytearray()
    while len(body) < expected_before_gap:
        chunk = response.read(min(65536, expected_before_gap - len(body)))
        if not chunk:
            connection.close()
            raise RuntimeError("gap response ended successfully before the unavailable piece")
        body.extend(chunk)
    transport_socket.settimeout(.6)
    try:
        extra = response.read(1)
        connection.close()
        raise RuntimeError(f"unavailable gap returned bytes or EOF instead of waiting ({len(extra)} bytes)")
    except socket.timeout:
        connection.close()
        return {"status": 206, "bytesBeforeGap": len(body), "waited": True}


def exact_http_matrix(url: str, source: Path, total: int):
    cases = []
    status, headers, body = http_request(url, "HEAD", "bytes=5-9")
    assert status == 200 and int(headers["Content-Length"]) == total and body == b"", "HEAD range did not return full metadata without a body"
    cases.append({"case": "head-range", "status": status, "contentLength": total, "bodyBytes": 0})
    for header, start, end, expected_status, label in [
        ("bytes=123-8191", 123, 8191, 206, "closed-range"),
        ("bytes=8192-", 8192, total - 1, 206, "open-range"),
        ("bytes=-4096", total - 4096, total - 1, 206, "suffix-range")]:
        status, headers, body = http_request(url, range_value=header)
        with source.open("rb") as stream:
            stream.seek(start)
            expected = stream.read(end - start + 1)
        assert status == expected_status and body == expected, f"{label} bytes/status differ from generated source"
        assert int(headers["Content-Length"]) == len(expected), f"{label} content length mismatch"
        assert headers.get("Content-Range") == f"bytes {start}-{end}/{total}", f"{label} Content-Range mismatch"
        cases.append({"case": label, "status": status, "bytesCompared": len(body), "sha256": hashlib.sha256(body).hexdigest()})
    for header, label in (("bytes=0-1,4-5", "multi-range-fallback"), (None, "full-get")):
        status, headers, body = http_request(url, range_value=header)
        digest = hashlib.sha256(body).hexdigest()
        expected = hashlib.sha256(source.read_bytes()).hexdigest()
        assert status == 200 and len(body) == total and digest == expected, f"{label} differed from full source oracle"
        assert int(headers["Content-Length"]) == total
        cases.append({"case": label, "status": status, "bytesCompared": len(body), "sha256": digest})
    status, headers, _ = http_request(url, range_value=f"bytes={total}-")
    assert status == 416 and headers.get("Content-Range") == f"bytes */{total}", "unsatisfiable range response mismatch"
    cases.append({"case": "unsatisfiable", "status": status, "contentRange": headers.get("Content-Range")})
    status, headers, body = http_request(url, range_value="bytes=0-31", extra_headers={"If-Range": '"stale-validator"'})
    assert status == 200 and len(body) == total and hashlib.sha256(body).hexdigest() == expected, "If-Range fallback was not a full entity"
    cases.append({"case": "if-range-fallback", "status": status, "bytesCompared": len(body)})
    return cases


def verify_preflight(args):
    missing = [name for name in ("docker", "python3", "ffmpeg", "ffprobe", "mpv", "flutter", "xvfb-run", "import", "magick") if shutil.which(name) is None]
    if missing:
        raise RuntimeError("missing required executable(s): " + ", ".join(missing))
    image_id = docker("image", "inspect", "--format", "{{.Id}}", API_IMAGE)
    locked = json.loads((ROOT / "images.lock.json").read_text())["services"]["briani"]
    if locked.get("localTag") != API_IMAGE or locked.get("localImageId") != image_id:
        raise RuntimeError("Desktop fixture image must match the exact current local image lock")
    return {"executables": "present", "apiImage": API_IMAGE, "qBittorrentImage": QBIT_IMAGE,
            "flutter": subprocess.check_output(["flutter", "--version"], text=True).splitlines()[0]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, default=Path(__file__).parent / "artifacts")
    parser.add_argument("--timeout", type=int, default=120, help="maximum wait for each availability/completion case")
    parser.add_argument("--preflight-only", action="store_true", help="check host tools and local production image, without creating resources")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 120:
        parser.error("--timeout must be between 1 and 120 seconds")

    run_id = uuid.uuid4().hex
    run_dir = args.artifacts.expanduser().resolve() / run_id
    run_dir.mkdir(parents=True, mode=0o700)
    run_dir.chmod(0o700)
    result_path = run_dir / "result.json"
    if args.preflight_only:
        try:
            result = {"result": "preflight_passed", **verify_preflight(args)}
            result_path.write_text(json.dumps(result, indent=2) + "\n")
            print(json.dumps({"result": result["result"], "artifact": str(result_path)}))
            return 0
        except Exception as error:
            result = {"result": "blocked", "failure": type(error).__name__, "detail": str(error)}
            result_path.write_text(json.dumps(result, indent=2) + "\n")
            print(json.dumps({"result": "blocked", "failure": result["failure"], "artifact": str(result_path)}))
            return 2

    state, data, seed_config, seed_data, down_config = [run_dir / value for value in
        ("state", "data", "seed-config", "seed-data", "down-config")]
    for path in (state, data, seed_config, seed_data, down_config):
        path.mkdir(mode=0o700)
        path.chmod(0o700)
    (data / "library").mkdir()
    run_short = run_id[:12]
    network = "briani-m07-play-" + run_short
    seed_name, down_name, api_name = ("briani-m07-seed-" + run_short,
        "briani-m07-down-" + run_short, "briani-m07-api-" + run_short)
    owned_containers: list[str] = []
    network_created = False
    active_player = None
    protected_handoff: Path | None = None
    mpv_before_desktop: set[int] | None = None
    owner_labels = {"org.briani.test": "M07", "org.briani.run": run_id}
    try:
        prereq = verify_preflight(args)
        fixtures = run_dir / "fixtures"
        gen_log = run_dir / "fixture-generator.log"
        with gen_log.open("w") as out:
            subprocess.run([sys.executable, str(FIXTURE_GENERATOR), "--out", str(fixtures), "--duration", "2",
                "--early-play-duration", "120", "--torrent-modes", "v1"], stdout=out, stderr=subprocess.STDOUT, check=True, timeout=600)
        manifest = json.loads((fixtures / "manifest.json").read_text(encoding="utf-8"))
        early_sources = fixtures / "early-play-source"
        media_specs = [("Faststart café [test].mp4", "Faststart café [test]-v1.torrent", "faststart-mp4"),
                       ("Tracks 演示.mkv", "Tracks 演示-v1.torrent", "tracks-mkv"),
                       ("Tail metadata.mp4", "Tail metadata-v1.torrent", "tail-metadata-mp4")]
        sources = []
        for source_name, torrent_name, label in media_specs:
            source, torrent = early_sources / source_name, fixtures / "torrents" / torrent_name
            if not source.is_file() or not torrent.is_file():
                raise RuntimeError(f"generated {label} fixture is missing")
            if source.stat().st_size < MIN_PREFIX:
                raise RuntimeError(f"generated {label} source is only {source.stat().st_size} bytes; must exceed 16 MiB")
            sources.append((source, torrent, label))

        docker("network", "create", "--internal", "--label", "org.briani.test=M07", "--label", f"org.briani.run={run_id}", network)
        network_created = True

        def start_qbit(name: str, role: str, config: Path, payload: Path) -> tuple[str, str]:
            docker("run", "--detach", "--name", name, "--network", network,
                "--label", "org.briani.test=M07", "--label", f"org.briani.run={run_id}", "--label", f"org.briani.role={role}",
                "-e", f"PUID={os.getuid()}", "-e", f"PGID={os.getgid()}", "-e", "WEBUI_PORT=8080", "-e", "TORRENTING_PORT=6881",
                "-v", f"{config}:/config", "-v", f"{payload}:/data", QBIT_IMAGE)
            owned_containers.append(name)
            ip = container_ip(name, network)
            password = None
            for _ in range(60):
                logs = docker("logs", name)
                found = TEMP_PASSWORD.search(logs)
                if found:
                    password = found.group(1)
                if password and "8080" in logs:
                    break
                time.sleep(1)
            if password is None:
                raise RuntimeError(f"owned {role} qBittorrent did not issue its startup password")
            wait_for(role + " qBittorrent", lambda: qbit_ready(ip), 30)
            return ip, password

        seed_ip, seed_password = start_qbit(seed_name, "seeder", seed_config, seed_data)
        down_ip, down_password = start_qbit(down_name, "downloader", down_config, data)
        seed = Qbit(f"http://{seed_ip}:8080", seed_password)
        down = Qbit(f"http://{down_ip}:8080", down_password)
        private_settings = {"dht": False, "pex": False, "lsd": False, "upnp": False, "web_ui_upnp": False}
        for client in (seed, down):
            client.call("app/setPreferences", {"json": json.dumps(private_settings)})
            observed = client.json("app/preferences")
            if any(observed.get(key) is not False for key in private_settings):
                raise RuntimeError("could not disable qBittorrent discovery/forwarding on internal swarm")

        # Prepare trackerless copies and source trees. Generated info dictionaries stay unchanged.
        prepared = []
        for source, torrent, label in sources:
            decoded = bdecode(torrent.read_bytes())
            for key in (b"announce", b"announce-list", b"url-list", b"httpseeds", b"nodes"):
                decoded.pop(key, None)
            prepared_torrent = run_dir / (label + ".torrent")
            prepared_torrent.write_bytes(bencode(decoded))
            root_name = decoded[b"info"][b"name"].decode("utf-8")
            seed_root = seed_data / root_name
            seed_root.mkdir()
            shutil.copyfile(source, seed_root / source.name)
            prepared.append((source, prepared_torrent, label))

        # Pre-register both seed torrents; the only explicit peers added are these owned containers.
        seed_hashes = {}
        for source, torrent, _ in prepared:
            seed.add_torrent(torrent, "/data")
            root_name = bdecode(torrent.read_bytes())[b"info"][b"name"].decode("utf-8")
            expected_hash = v1_infohash(torrent)
            seed_hash = wait_for("owned seed registration and infohash", lambda: next((row["hash"] for row in seed.json("torrents/info") if row.get("hash", "").lower() == expected_hash), None), 20)
            if seed_hash.lower() != expected_hash:
                raise RuntimeError("seeder registered a torrent with an unexpected infohash")
            seed_hashes[root_name] = seed_hash
            seed.call("torrents/start", {"hashes": seed_hash})
            wait_for("owned seed completion", lambda: (rows[0] if (rows := seed.json("torrents/info", {"hashes": seed_hash})) and rows[0].get("progress") == 1 else None), 60)

        # Each API state/data root and every test resource is tied to this run ID.
        api_host_ip = allocate_api_ip(network)
        docker("run", "--detach", "--name", api_name, "--network", network, "--network-alias", "briani", "--ip", api_host_ip,
            "--label", "org.briani.test=M07", "--label", f"org.briani.run={run_id}", "--label", "org.briani.role=api",
            "--read-only", "--cap-drop=ALL", "--security-opt=no-new-privileges", "--pids-limit=256", "--memory=1g", "--cpus=2",
            "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m", "-e", "ASPNETCORE_URLS=http://0.0.0.0:8088",
            "-e", f"AllowedHosts={api_host_ip};briani;localhost",
            "-v", f"{data}:/data", "-v", f"{state}:/config", API_IMAGE)
        owned_containers.append(api_name)
        network_info = json.loads(docker("network", "inspect", network))[0]
        if not network_info.get("Internal") or any((network_info.get("Labels") or {}).get(k) != v for k, v in owner_labels.items()):
            raise RuntimeError("test swarm is not an owned internal Docker network")
        for owned_name in owned_containers:
            if any(labels("container", owned_name).get(k) != v for k, v in owner_labels.items()):
                raise RuntimeError("an integration container lacks exact M07 run ownership labels")
            verify_unpublished(owned_name)
        api_ip = container_ip(api_name, network)
        api_origin = f"http://{api_ip}:8088"
        api = Api(api_origin)
        wait_for("Briani API readiness", lambda: _api_ready(api), 150)
        bootstrap = (state / "bootstrap.code").read_text().strip()
        admin_password = uuid.uuid4().hex + "Aa1!"
        auth = api.json("/api/v1/bootstrap", {"code": bootstrap, "username": "m07-admin", "displayName": "M07 Desktop E2E", "password": admin_password, "confirmPassword": admin_password})
        api.token = auth["accessToken"]
        root_id = api.json("/api/v1/admin/storage")[0]["id"]
        library_name = "M07 generated playback"
        library = api.json("/api/v1/libraries", {"name": library_name, "description": "", "storageRootId": root_id,
            "relativePath": "library", "readOnly": False})
        integration = api.json("/api/v1/admin/integrations/qbittorrent",
            {"baseUrl": f"http://{down_name}:8080/", "version": 1, "username": "admin", "secret": down_password}, method="PUT")
        if not integration.get("credentialConfigured"):
            raise RuntimeError("production API did not persist the private downloader credential")

        # Create real metadata-pending UI work. The desktop owns file selection
        # and start consent; the harness only uploads this generated legal torrent.
        ui_source, ui_torrent, ui_label = prepared[0]
        ui_uploaded = multipart_torrent(api, ui_torrent)
        ui_created = api.json("/api/v1/downloads", {"libraryId": library["id"],
            "source": {"kind": "torrentUpload", "value": str(ui_uploaded["id"])}})
        ui_request_id = ui_created["id"]
        ui_files = wait_for("desktop fixture metadata", lambda: api_files(api, ui_request_id), 90)
        ui_file = next((row for row in ui_files if row.get("kind") == "video" and
            row.get("name") == ui_source.name and row.get("sizeBytes") == ui_source.stat().st_size), None)
        if ui_file is None:
            raise RuntimeError("desktop UI fixture metadata did not expose the generated MP4")
        ui_download = api.json(f"/api/v1/downloads/{ui_request_id}")
        ui_torrent_hash = v1_infohash(ui_torrent)
        first_frame_marker = run_dir / "ui-first-frame.json"
        stage_marker = run_dir / "desktop-stage.txt"
        buffer_request_marker = run_dir / "ui-buffer-request"
        buffer_pause_marker = run_dir / "ui-buffer-paused"
        buffer_marker = run_dir / "ui-buffer-observation.json"
        buffer_resume_marker = run_dir / "ui-buffer-resumed"
        buffer_resume_proof = run_dir / "ui-buffer-resume-proof.json"
        render_proof = run_dir / "ui-native-render.png"
        import_ready_marker = run_dir / "ui-import-ready.json"

        # Exercise the native Linux app against this exact ephemeral API and account.
        # Password and API origin are passed only through a mode-0600 file, never argv/logs.
        handoff = run_dir / "desktop-e2e.json"
        protected_handoff = handoff
        descriptor = os.open(handoff, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump({"origin": api_origin, "username": "m07-admin", "password": admin_password,
                "downloadName": ui_download.get("name") or "Torrent metadata pending",
                "fileName": ui_file["name"], "downloadId": ui_request_id, "libraryName": library_name,
                "firstFrameMarker": str(first_frame_marker), "stageMarker": str(stage_marker),
                "bufferRequestMarker": str(buffer_request_marker), "bufferPauseMarker": str(buffer_pause_marker),
                "bufferMarker": str(buffer_marker), "bufferResumeMarker": str(buffer_resume_marker),
                "bufferResumeProof": str(buffer_resume_proof), "renderProofPath": str(render_proof),
                "importReadyMarker": str(import_ready_marker)}, stream)
        client_dir = ROOT / "client"
        if shutil.which("flutter") is None or shutil.which("xvfb-run") is None:
            raise RuntimeError("Linux desktop E2E blocked: flutter and xvfb-run are required")
        flutter_env = {k: v for k, v in os.environ.items() if k.lower() not in ("http_proxy", "https_proxy", "all_proxy")}
        flutter_env["BRIANI_E2E_FILE"] = str(handoff)
        desktop_log = run_dir / "flutter-desktop-e2e.log"
        mpv_before_desktop = mpv_processes()
        observed_desktop_mpv: set[int] = set()
        with desktop_log.open("w", encoding="utf-8") as output:
            completed = subprocess.Popen(["xvfb-run", "-a", "flutter", "test", "integration_test/desktop_e2e_test.dart", "-d", "linux"],
                cwd=client_dir, env=flutter_env, stdout=output, stderr=subprocess.STDOUT)
            peer_connected = False
            ui_frame = None
            ui_transfer_paused = False
            ui_transfer_resumed = False
            next_import_probe = 0.0
            deadline = time.monotonic() + 420
            while completed.poll() is None and time.monotonic() < deadline:
                observed_desktop_mpv.update(mpv_processes() - mpv_before_desktop)
                if not peer_connected:
                    rows = down.json("torrents/info")
                    torrent_row = next((row for row in rows if row.get("hash", "").lower() == ui_torrent_hash), None)
                    if torrent_row is not None:
                        down.call("torrents/setDownloadLimit", {"hashes": torrent_row["hash"], "limit": str(UI_DOWNLOAD_LIMIT)})
                        down.call("torrents/addPeers", {"hashes": torrent_row["hash"], "peers": f"{seed_ip}:6881"})
                        peer_connected = True
                if ui_frame is None and first_frame_marker.is_file():
                    ui_frame = json.loads(first_frame_marker.read_text(encoding="utf-8"))
                    engine_rows = down.json("torrents/info", {"hashes": ui_torrent_hash})
                    if not engine_rows or engine_rows[0].get("progress", 1) >= 1:
                        raise RuntimeError("desktop native first frame occurred after torrent completion")
                    ui_frame["engineProgressAtFirstFrame"] = engine_rows[0].get("progress")
                    (run_dir / "ui-first-frame-observation.json").write_text(json.dumps(ui_frame, indent=2) + "\n")
                    download_action(api, ui_request_id, "pause")
                    paused = wait_for("desktop API pause to stop the torrent", lambda: (row if (found := down.json("torrents/info", {"hashes": ui_torrent_hash})) and (row := found[0]).get("state", "").startswith("stopped") else None), 20)
                    if paused.get("progress", 1) >= 1:
                        raise RuntimeError("desktop torrent completed before native starvation could be induced")
                    buffer_pause_marker.write_text("stopped", encoding="ascii")
                    ui_transfer_paused = True
                if ui_transfer_paused and not ui_transfer_resumed and buffer_marker.is_file():
                    observation = json.loads(buffer_marker.read_text(encoding="utf-8"))
                    if observation.get("pausedForCache") is not True:
                        raise RuntimeError("embedded player did not report a cache pause")
                    download_action(api, ui_request_id, "resume")
                    down.call("torrents/setDownloadLimit", {"hashes": ui_torrent_hash, "limit": str(5 * 1024 * 1024)})
                    down.call("torrents/addPeers", {"hashes": ui_torrent_hash, "peers": f"{seed_ip}:6881"})
                    resumed_engine = wait_for("desktop resumed torrent", lambda: (row if (found := down.json("torrents/info", {"hashes": ui_torrent_hash})) and (row := found[0]).get("state", "") and not row.get("state", "").startswith(("stopped", "paused")) else None), 30)
                    buffer_resume_marker.write_text(json.dumps({"state": resumed_engine.get("state"),
                        "progress": resumed_engine.get("progress")}), encoding="utf-8")
                    ui_transfer_resumed = True
                if not import_ready_marker.is_file() and time.monotonic() >= next_import_probe:
                    next_import_probe = time.monotonic() + 1
                    if stage_marker.is_file() and stage_marker.read_text(encoding="utf-8") == "external-handoff":
                        rows = api_files(api, ui_request_id) or []
                        imported = next((row for row in rows if row.get("id") == ui_file["id"] and
                            row.get("playbackState") == "complete" and row.get("importedMediaId")), None)
                        if imported is not None:
                            import_ready_marker.write_text(json.dumps({"fileName": ui_file["name"],
                                "playbackState": imported["playbackState"],
                                "importedMediaId": imported["importedMediaId"]}), encoding="utf-8")
                time.sleep(.25)
            if completed.poll() is None:
                completed.terminate()
                try: completed.wait(timeout=5)
                except subprocess.TimeoutExpired: completed.kill(); completed.wait()
                raise TimeoutError("Flutter Linux desktop E2E exceeded its seven-minute case deadline")
        observed_desktop_mpv.update(mpv_processes() - mpv_before_desktop)
        launched_mpv = terminate_observed_mpv(observed_desktop_mpv)
        mpv_before_desktop = None
        if not launched_mpv:
            raise RuntimeError("desktop external handoff did not start an owned mpv process")
        if completed.returncode:
            raise RuntimeError(f"Flutter Linux desktop E2E failed; see {desktop_log}")
        if not first_frame_marker.is_file():
            raise RuntimeError("desktop UI did not record a native decoded first frame")
        if not render_proof.is_file():
            raise RuntimeError("desktop UI did not save an Xvfb render capture")
        dimensions = subprocess.check_output(["magick", "identify", "-format", "%w %h", str(render_proof)], text=True).split()
        if len(dimensions) != 2 or int(dimensions[0]) < 640 or int(dimensions[1]) < 415:
            raise RuntimeError("desktop render capture is too small for the embedded video viewport")
        color_pixels = int(subprocess.check_output(["magick", str(render_proof), "-crop", "510x365+130+50",
            "+repage", "-format", "%k", "info:"], text=True))
        if color_pixels < 1000:
            raise RuntimeError("desktop native render capture has no substantial visible video image")
        render_analysis = {"capture": str(render_proof), "width": int(dimensions[0]),
            "height": int(dimensions[1]), "uniqueColorsInVideoViewport": color_pixels,
            "viewportCrop": "510x365+130+50"}
        (run_dir / "ui-native-render-analysis.json").write_text(json.dumps(render_analysis, indent=2) + "\n")
        handoff.unlink(missing_ok=True)
        if not peer_connected:
            raise RuntimeError("desktop UI did not start the selected request in the isolated downloader")
        if not ui_transfer_paused or not ui_transfer_resumed or not buffer_resume_proof.is_file():
            raise RuntimeError("desktop UI did not verify native buffering and resumed playback")
        if not import_ready_marker.is_file():
            raise RuntimeError("desktop UI did not wait for the selected media's completed import")

        results = []
        results.append({"label": "desktop-ui-faststart-mp4", "sizeBytes": ui_source.stat().st_size,
            "sourceSha256": hashlib.sha256(ui_source.read_bytes()).hexdigest(),
            "torrentHash": ui_torrent_hash, "firstFrame": ui_frame,
            "incompleteAtFirstFrame": True, "progressAtFirstFrame": ui_frame["engineProgressAtFirstFrame"],
            "uiSelectedAndStarted": True, "embeddedNativePlayer": True, "externalHandoff": True,
            "nativeBufferPauseAndResume": json.loads(buffer_resume_proof.read_text(encoding="utf-8")),
            "nativeRenderProof": render_analysis,
            "completedImport": json.loads(import_ready_marker.read_text(encoding="utf-8")),
            "completedImportBrowsedInUi": (stage_marker.read_text(encoding="utf-8") == "completed-import-browsed"),
            "externalProcessesTerminated": len(launched_mpv)})
        for case_index, (source, torrent, label) in enumerate(prepared[1:], start=1):
            uploaded = multipart_torrent(api, torrent)
            created = api.json("/api/v1/downloads", {"libraryId": library["id"], "source": {"kind": "torrentUpload", "value": str(uploaded["id"])}})
            request_id = created["id"]
            file_rows = wait_for(label + " metadata", lambda: api_files(api, request_id), 90)
            selected = next((row for row in file_rows if row.get("kind") == "video" and row.get("name") == source.name and row.get("sizeBytes") == source.stat().st_size), None)
            if selected is None:
                raise RuntimeError(f"production metadata did not expose the generated {label} file")
            download = api.json(f"/api/v1/downloads/{request_id}")
            selection = {"files": [{"fileId": row["id"], "selected": row["id"] == selected["id"], "priority": "normal"} for row in file_rows],
                         "autoStart": True, "version": download["version"]}
            status, response_headers, payload = api.request(f"/api/v1/downloads/{request_id}/selection", selection, method="PUT")
            if status != 202:
                raise RuntimeError(f"selection returned {status}: {payload[:250]!r}")
            operation_id = response_headers.get("Location", "").rsplit("/", 1)[-1]
            wait_for(label + " selected operation", lambda: (op if operation_id and (op := _operation(api, operation_id)) and op.get("state") == "completed" else True if not operation_id and _download_started(api, request_id) else None), 60)

            # Apply a bounded per-torrent rate before connecting the sole owned peer.
            rows = wait_for(label + " engine registration", lambda: (rows if (rows := down.json("torrents/info")) else None), 30)
            expected_hash = v1_infohash(torrent)
            torrent_hash = next((row["hash"] for row in rows if row.get("hash", "").lower() == expected_hash), None)
            if not torrent_hash:
                raise RuntimeError("selected generated torrent with expected infohash is absent from the owned downloader")
            down.call("torrents/setDownloadLimit", {"hashes": torrent_hash, "limit": str(DOWNLOAD_LIMIT)})
            down.call("torrents/addPeers", {"hashes": torrent_hash, "peers": f"{seed_ip}:6881"})
            piece_length = int(bdecode(torrent.read_bytes())[b"info"][b"piece length"])
            live_file = wait_for(label + " 16 MiB verified prefix", lambda: _ready_file(api, request_id, selected["id"]), args.timeout)
            if int(live_file.get("contiguousBytes", 0)) < MIN_PREFIX:
                raise RuntimeError(f"{label} readiness did not reach the required prefix")
            before_session = down.json("torrents/info", {"hashes": torrent_hash})[0]
            if before_session.get("progress", 1) >= 1:
                raise RuntimeError(f"{label} completed before early playback proof could start")

            session = api.json("/api/v1/playback/sessions", {"target": {"kind": "downloadFile", "id": selected["id"]}, "mode": "internal"})
            if session.get("state") not in ("ready", "complete") or not session.get("streamUrl"):
                raise RuntimeError(f"{label} production playback session is not ready: {session.get('state')!r}")
            presentation = urllib.parse.urlsplit(session["streamUrl"])
            transport = urllib.parse.urlsplit(api_origin)
            stream_url = urllib.parse.urlunsplit((transport.scheme, transport.netloc, presentation.path, presentation.query, ""))
            status, head_headers, head_body = http_request(stream_url, "HEAD", "bytes=2-5", timeout=10)
            if status != 200 or int(head_headers.get("Content-Length", -1)) != source.stat().st_size or head_body:
                raise RuntimeError(f"{label} HEAD-with-Range failed production metadata contract")
            media_run_dir = run_dir / label
            media_run_dir.mkdir()
            player, connection, reader, player_log, first_frame = wait_first_frame(
                down, torrent_hash, stream_url, media_run_dir, allow_complete=label == "tail-metadata-mp4")
            active_player = (player, connection, reader, player_log)
            (media_run_dir / "first-frame.json").write_text(json.dumps(first_frame, indent=2)+"\n")
            frame_info = down.json("torrents/info", {"hashes": torrent_hash})[0]
            if frame_info.get("progress", 1) >= 1:
                stop_mpv(player, connection, reader, player_log)
                active_player = None
                if label != "tail-metadata-mp4":
                    raise RuntimeError(f"{label} completed before its first frame")
                matrix = exact_http_matrix(stream_url, source, source.stat().st_size)
                results.append({"label": label, "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                    "sizeBytes": source.stat().st_size, "torrentHash": torrent_hash, "firstFrame": first_frame,
                    "incompleteAtFirstFrame": False, "tailMetadataOutcome": "waited_until_complete",
                    "httpMatrix": matrix})
                continue
            # Stop torrent payload while retaining the actual native player for buffering/resume.
            try:
                summary = api.json(f"/api/v1/downloads/{request_id}")
                operation = api.json(f"/api/v1/downloads/{request_id}/actions", {"action":"pause", "version":summary["version"]})
                wait_for(label+" pause operation", lambda: (_operation(api,operation["id"]) or {}).get("state")=="completed", 20)
                paused = wait_for(label + " stopped engine", lambda: (row if (found := down.json("torrents/info", {"hashes": torrent_hash})) and (row := found[0]).get("state", "").startswith("stopped") else None), 15)
                if paused.get("progress", 1) >= 1:
                    raise RuntimeError(f"{label} engine completed before it could be stopped at first frame")
                buffer_observation = wait_cache_pause(connection, reader)
            except Exception:
                stop_mpv(player, connection, reader, player_log)
                active_player = None
                raise

            piece_states = down.json("torrents/pieceStates", {"hash": torrent_hash})
            missing_piece = next((idx for idx, state in enumerate(piece_states) if idx > 0 and state != 2 and piece_states[idx - 1] == 2), None)
            if missing_piece is None:
                raise RuntimeError(f"{label} paused torrent has no verified prefix followed by a missing piece")
            missing_offset = missing_piece * piece_length
            gap_start = (missing_piece - 1) * piece_length
            gap_end = min(source.stat().st_size - 1, missing_offset + 15)
            priorities_before = [row.get("priority") for row in down.json("torrents/files", {"hash": torrent_hash})]
            vlc_result = None
            gap = raw_range_until_gap(stream_url, gap_start, gap_end, missing_offset)

            # Later range reopen on the same scoped ticket. Reconnect only the owned source peer.
            summary = api.json(f"/api/v1/downloads/{request_id}")
            operation = api.json(f"/api/v1/downloads/{request_id}/actions", {"action":"resume", "version":summary["version"]})
            wait_for(label+" resume operation", lambda: (_operation(api,operation["id"]) or {}).get("state")=="completed", 20)
            down.call("torrents/addPeers", {"hashes": torrent_hash, "peers": f"{seed_ip}:6881"})
            wait_for(label + " missing-piece recovery", lambda: (True if (states := down.json("torrents/pieceStates", {"hash": torrent_hash})) and len(states) > missing_piece and states[missing_piece] == 2 else None), args.timeout)
            resume_end = min(source.stat().st_size - 1, missing_offset + 15)
            status, headers, body = http_request(stream_url, range_value=f"bytes={missing_offset}-{resume_end}", timeout=args.timeout)
            with source.open("rb") as oracle:
                oracle.seek(missing_offset)
                expected = oracle.read(resume_end - missing_offset + 1)
            if status != 206 or body != expected:
                raise RuntimeError(f"{label} same-ticket range reopen after gap did not match generated source")
            if [row.get("priority") for row in down.json("torrents/files", {"hash": torrent_hash})] != priorities_before:
                raise RuntimeError(f"{label} player range changed torrent file priorities")

            buffer_observation.update(wait_cache_resume(connection, reader, buffer_observation["positionAtPause"]))
            stop_mpv(player, connection, reader, player_log)
            active_player = None

            # Finish only after the pre-completion proof, then verify the entire HTTP matrix by byte oracle.
            down.call("torrents/setDownloadLimit", {"hashes": torrent_hash, "limit": "5242880"})
            wait_for(label + " completion for exact range matrix", lambda: (row if (found := down.json("torrents/info", {"hashes": torrent_hash})) and (row := found[0]).get("progress") == 1 else None), args.timeout)
            vlc_completed = None
            matrix = exact_http_matrix(stream_url, source, source.stat().st_size)
            results.append({"label": label, "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "sizeBytes": source.stat().st_size, "torrentHash": torrent_hash, "firstFrame": first_frame,
                "incompleteAtFirstFrame": True, "progressAtFirstFrame": first_frame["engineProgressAtFirstFrame"],
                "contiguousPrefixBytes": live_file.get("contiguousBytes"), "headRangeBeforeCompletion": True,
                "bufferingObserved": True, "bufferResume": buffer_observation, "vlc": vlc_result, "vlcCompletedComparison": vlc_completed, "missingPiece": missing_piece, "missingDataWait": gap,
                "resumeSameTicketBytes": len(body), "prioritiesUnchanged": True, "httpMatrix": matrix})

        report = {"result": "passed", "milestone": "M07", "runId": run_id, "artifacts": str(run_dir),
            "desktopE2E": {"command": "xvfb-run -a flutter test integration_test/desktop_e2e_test.dart -d linux", "exitCode": 0, "audio": "disabled for headless test", "display": "Xvfb"},
            "apiImageId": docker("image", "inspect", "--format", "{{.Id}}", API_IMAGE),
            "qBittorrentImage": QBIT_IMAGE, "qBittorrentVersion": seed.call("app/version").decode("utf-8", "replace"),
            "mpvVersion": subprocess.check_output(["mpv", "--version"], text=True).splitlines()[0],
            "ffmpegVersion": manifest["ffmpeg"], "isolatedInternalNetwork": True, "externalTrackerOrPeer": False,
            "publishedPorts": [], "media": results}
        result_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "passed", "runId": run_id, "evidence": str(result_path), "media": len(results)}))
        return 0
    except Exception as error:
        safe_detail = str(error)
        # A URL/ticket must never be emitted in the report, even when an HTTP library embeds it in an exception.
        safe_detail = re.sub(r"https?://[^\s]+", "[redacted-url]", safe_detail)
        report = {"result": "failed", "milestone": "M07", "runId": run_id,
            "failure": type(error).__name__, "detail": safe_detail, "artifacts": str(run_dir)}
        if stage_marker.is_file():
            report["flutterStage"] = stage_marker.read_text(encoding="utf-8", errors="replace")[:80]
        result_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "failed", "runId": run_id, "failure": report["failure"], "evidence": str(result_path)}))
        return 1
    finally:
        if mpv_before_desktop is not None:
            terminate_new_mpv(mpv_before_desktop)
        if protected_handoff is not None:
            protected_handoff.unlink(missing_ok=True)
        if active_player is not None:
            stop_mpv(*active_player)
        for name in reversed(owned_containers):
            try:
                if all(labels("container", name).get(k) == v for k, v in owner_labels.items()):
                    docker("rm", "--force", name)
            except Exception:
                pass
        if network_created:
            try:
                if all(labels("network", network).get(k) == v for k, v in owner_labels.items()):
                    docker("network", "rm", network)
            except Exception:
                pass
        # Ephemeral server databases, torrent-engine credentials/config, and
        # generated payloads are not evidence artifacts and must not survive.
        for private_path in (state, data, seed_config, seed_data, down_config, run_dir / "fixtures"):
            try:
                shutil.rmtree(private_path)
            except OSError:
                pass
        flutter_log = run_dir / "flutter-desktop-e2e.log"
        if flutter_log.exists():
            try:
                content = flutter_log.read_text(encoding="utf-8", errors="replace")
                content = re.sub(r"(?i)bearer\s+[^\s\"']+", "Bearer [redacted]", content)
                content = re.sub(r"https?://[^\s'\"]+", "[redacted-url]", content)
                flutter_log.write_text(content, encoding="utf-8")
            except OSError:
                pass


def _operation(api: Api, operation_id: str):
    try:
        return api.json(f"/api/v1/operations/{operation_id}")
    except Exception:
        return None


def download_action(api: Api, request_id: str, action: str, timeout: float = 30):
    summary = api.json(f"/api/v1/downloads/{request_id}")
    operation = api.json(f"/api/v1/downloads/{request_id}/actions",
        {"action": action, "version": summary["version"]})
    wait_for(f"desktop {action} operation", lambda: (_operation(api, operation["id"]) or {}).get("state") == "completed", timeout)


def _api_ready(api: Api) -> bool:
    try:
        return api.request("/readyz")[0] == 200
    except Exception:
        return False


def _download_started(api: Api, request_id: str):
    try:
        row = api.json(f"/api/v1/downloads/{request_id}")
        return row if row.get("state") not in ("metadataPending", "awaitingSelection") else None
    except Exception:
        return None


def _ready_file(api: Api, request_id: str, file_id: str):
    try:
        files = api_files(api, request_id) or []
        row = next((item for item in files if item.get("id") == file_id), None)
        return row if row and int(row.get("contiguousBytes", 0)) >= MIN_PREFIX else None
    except Exception:
        return None


if __name__ == "__main__":
    raise SystemExit(main())
