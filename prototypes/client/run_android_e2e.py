#!/usr/bin/env python3
"""Bounded connected Android TV E2E using only emulator-5580 and owned containers."""
from __future__ import annotations

import argparse
import http.client
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import uuid

ROOT = Path(__file__).resolve().parents[2]
M07_PATH = ROOT / "prototypes/client/run_desktop_e2e.py"
QBIT_IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
API_IMAGE = "briani-server:m10"
SERIAL = "emulator-5580"
PACKAGE = "org.brianiplayer.app.devtest"
MIN_PREFIX = 16 * 1024 * 1024
DOWNLOAD_LIMIT = 128 * 1024
TEMP_PASSWORD = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)


def verify_api_image_lock(image_id: str):
    """Require the harness image tag and immutable ID to match repository lock."""
    lock_path = ROOT / "images.lock.json"
    try:
        lock = json.loads(lock_path.read_text(encoding="utf-8"))
        briani = lock["services"]["briani"]
        expected_tag = briani["localTag"]
        expected_id = briani["localImageId"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise RuntimeError(f"Cannot read Briani image identity from {lock_path}") from error
    if expected_tag != API_IMAGE:
        raise RuntimeError(f"Android E2E API image tag {API_IMAGE} does not match lock tag {expected_tag!r}")
    if not isinstance(expected_id, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", expected_id):
        raise RuntimeError(f"Invalid locked Briani image ID in {lock_path}")
    observed_id = image_id.strip()
    if observed_id != expected_id:
        raise RuntimeError(f"M10 API image ID mismatch: expected {expected_id}, observed {observed_id}")
    return expected_id

spec = importlib.util.spec_from_file_location("briani_m07_harness", M07_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("Cannot load read-only M07 fixture and API helpers")
M07 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M07)


def command(args: list[str], *, timeout=30, check=True, input_text=None, capture=True):
    result = subprocess.run(args, check=False, text=True, input=input_text,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.PIPE if capture else subprocess.DEVNULL, timeout=timeout)
    if check and result.returncode:
        detail = (result.stderr or "")[-500:]
        raise RuntimeError(f"{Path(args[0]).name} failed ({result.returncode}): {detail}")
    return result


def adb(*args: str, **kwargs):
    return command(["adb", "-s", SERIAL, *args], **kwargs)


def resumed_activity():
    """Return only the top component name from dumpsys, never the full dump."""
    result = adb("shell", "dumpsys", "activity", "activities", timeout=12, check=False)
    match = re.search(r"topResumedActivity=.*?\s([A-Za-z0-9_.]+/[A-Za-z0-9_.$]+)", result.stdout)
    return match.group(1) if match else "unknown"


def verify_emulator():
    rows = command(["adb", "devices", "-l"]).stdout.splitlines()
    selected = [line for line in rows if line.split()[:1] == [SERIAL]]
    if len(selected) != 1 or " device " not in selected[0]:
        raise RuntimeError(f"Required owned TV emulator {SERIAL} is not the sole selected target")
    details = selected[0]
    if "sdk_google_atv64_x86_64" not in details:
        raise RuntimeError("emulator-5580 is not the expected Android TV x86_64 system image")
    sdk = adb("shell", "getprop", "ro.build.version.sdk").stdout.strip()
    if sdk != "36":
        raise RuntimeError(f"owned Android TV emulator SDK is {sdk}, expected API 36")
    return {"serial": SERIAL, "sdk": int(sdk), "device": details.strip()}


def secret_file(path: Path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(value, stream)
        stream.write("\n")
    path.chmod(0o600)


def sanitize_log(path: Path, secrets: list[str]):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
        text = re.sub(r"(?i)bearer\s+[^\s\"']+", "Bearer [redacted]", text)
        text = re.sub(r"https?://[^\s'\"]+", "[redacted-url]", text)
        text = re.sub(r"/(?:stream|media)/[A-Za-z0-9_-]{43}/", "/stream/<ticket-redacted>/", text)
        for item in secrets:
            if item:
                text = text.replace(item, "[redacted]")
        path.write_text(text, encoding="utf-8")
    except OSError:
        pass


class LoopbackRelay(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = False

    def __init__(self, address, api_ip: str, control_dir: Path):
        self.api_ip = api_ip
        self.control_dir = control_dir
        self.pair_approver = None
        self.pair_replay_check = None
        super().__init__(address, RelayHandler)


class RelayHandler(socketserver.BaseRequestHandler):
    protocol_version = "HTTP/1.1"

    def handle(self):
        # Parse one HTTP/1.x request per socket. Clients reconnect for subsequent
        # requests; streaming bodies are relayed in bounded chunks.
        stream = self.request.makefile("rb")
        try:
            request_line = stream.readline(8192)
            if not request_line:
                return
            parts = request_line.decode("latin-1").strip().split(" ", 2)
            if len(parts) != 3:
                self._response(400, b"")
                return
            method, path, version = parts
            headers = {}
            while True:
                line = stream.readline(16384)
                if line in (b"\r\n", b"\n", b""):
                    break
                name, separator, value = line.decode("latin-1").partition(":")
                if separator:
                    headers[name.strip().lower()] = value.strip()
            length = int(headers.get("content-length", "0") or "0")
            if length < 0 or length > 1024 * 1024:
                self._response(413, b"")
                return
            body = stream.read(length) if length else b""
            if path == "/__m08/pair/approve" and method == "POST":
                self._pair_approve(body)
                return
            if path == "/__m08/pair/consumed" and method == "POST":
                self._pair_consumed(body)
                return
            if path.startswith("/__m08/control/"):
                self._control(method, path, body)
                return
            self._proxy(method, path, version, headers, body)
        except (BrokenPipeError, ConnectionResetError, OSError, ValueError):
            return
        finally:
            stream.close()

    def _response(self, status: int, body: bytes, content_type="application/json"):
        reason = {200: "OK", 204: "No Content", 400: "Bad Request", 404: "Not Found", 413: "Payload Too Large", 500: "Internal Server Error"}.get(status, "Error")
        header = (f"HTTP/1.1 {status} {reason}\r\nConnection: close\r\nContent-Length: {len(body)}\r\n"
                  f"Content-Type: {content_type}\r\n\r\n").encode("ascii")
        self.request.sendall(header)
        if body:
            self.request.sendall(body)

    def _control(self, method: str, path: str, body: bytes):
        parts = urllib.parse.urlsplit(path).path.strip("/").split("/")
        if len(parts) != 4 or parts[:2] != ["__m08", "control"]:
            self._response(404, b"{}")
            return
        action, name = parts[2], parts[3]
        if not re.fullmatch(r"[a-z0-9-]{1,48}", name):
            self._response(400, b"{}")
            return
        target = self.server.control_dir / f"{action}-{name}.json"
        if action == "mark" and method == "POST":
            if len(body) > 4096:
                self._response(413, b"{}")
                return
            try:
                value = json.loads(body or b"{}")
            except ValueError:
                self._response(400, b"{}")
                return
            target.write_text(json.dumps(value, separators=(",", ":")), encoding="utf-8")
            self._response(204, b"")
        elif action == "response" and method == "GET":
            if not target.is_file():
                self._response(404, b"{}")
            else:
                self._response(200, target.read_bytes())
        else:
            self._response(404, b"{}")

    def _pair_code(self, body: bytes):
        try:
            value = json.loads(body)
        except (ValueError, UnicodeDecodeError):
            self._response(400, b'{"error":"invalid_pair_request"}')
            return None
        code = value.get("userCode") if isinstance(value, dict) and set(value) == {"userCode"} else None
        if not isinstance(code, str) or not re.fullmatch(r"[A-Z2-9]{8}", code):
            self._response(400, b'{"error":"invalid_pair_request"}')
            return None
        return code

    def _pair_approve(self, body: bytes):
        code = self._pair_code(body)
        if code is None:
            return
        try:
            safe = self.server.pair_approver(code)
        except PairingFixtureFailure as error:
            # Never return or persist request data or API response bodies.
            self._response(409, json.dumps({"error": "pairing_approval_failed", "stage": error.stage}).encode())
            return
        except Exception:
            self._response(409, b'{"error":"pairing_approval_failed","stage":"fixture-internal"}')
            return
        self._response(200, json.dumps(safe, separators=(",", ":")).encode())

    def _pair_consumed(self, body: bytes):
        code = self._pair_code(body)
        if code is None:
            return
        try:
            consumed = bool(self.server.pair_replay_check(code))
        except Exception:
            self._response(409, b'{"error":"pairing_state_check_failed"}')
            return
        self._response(200 if consumed else 409, b'{"consumed":true}' if consumed else b'{"consumed":false}')

    def _proxy(self, method: str, path: str, version: str, headers: dict, body: bytes):
        connection = http.client.HTTPConnection(self.server.api_ip, 8088, timeout=None)
        forward = {name: value for name, value in headers.items()
                   if name not in {"host", "connection", "proxy-connection", "keep-alive", "transfer-encoding"}}
        # Preserve the authenticated profile's canonical loopback authority so
        # issued playback URLs satisfy the production same-origin check.
        forward["Host"] = f"127.0.0.1:{self.server.server_address[1]}"
        try:
            connection.putrequest(method, path, skip_host=True, skip_accept_encoding=True)
            for name, value in forward.items():
                connection.putheader(name, value)
            connection.putheader("Connection", "close")
            connection.endheaders(body or None)
            response = connection.getresponse()
            excluded = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade"}
            copied = [(name, value) for name, value in response.getheaders() if name.lower() not in excluded]
            header = f"HTTP/1.1 {response.status} {response.reason}\r\n".encode("latin-1")
            self.request.sendall(header)
            for name, value in copied:
                self.request.sendall(f"{name}: {value}\r\n".encode("latin-1"))
            self.request.sendall(b"Connection: close\r\n\r\n")
            while True:
                chunk = response.read(65536)
                if not chunk:
                    break
                self.request.sendall(chunk)
        except (BrokenPipeError, ConnectionResetError, OSError, http.client.HTTPException):
            try:
                self._response(500, b"{\"error\":\"isolated relay failed\"}")
            except OSError:
                pass
        finally:
            connection.close()


class PairingFixtureFailure(Exception):
    """Secret-free diagnostic stage for the fixture-only approval bridge."""
    def __init__(self, stage: str):
        super().__init__(stage)
        self.stage = stage


def open_relay(api_ip: str, control_dir: Path):
    relay = LoopbackRelay(("127.0.0.1", 0), api_ip, control_dir)
    port = relay.server_address[1]
    thread = threading.Thread(target=relay.serve_forever, name="m08-loopback-relay", daemon=True)
    thread.start()
    return relay, thread, port


def screenshot_pixels(path: Path):
    from PIL import Image
    image = Image.open(path).convert("RGB")
    width, height = image.size
    if width < 640 or height < 360:
        raise RuntimeError("Android TV screenshot is unexpectedly small")
    left, right = width // 10, width * 9 // 10
    top, bottom = height // 10, height * 8 // 10
    red = green = blue = saturated = sampled = 0
    pixels = image.load()
    for y in range(top, bottom, 2):
        for x in range(left, right, 2):
            r, g, b = pixels[x, y]
            hi, lo = max(r, g, b), min(r, g, b)
            sampled += 1
            if hi > 96 and hi - lo > 60:
                saturated += 1
            if r > g + 40 and r > b + 40:
                red += 1
            if g > r + 40 and g > b + 40:
                green += 1
            if b > r + 40 and b > g + 40:
                blue += 1
    return {"width": width, "height": height, "sampledPixels": sampled,
        "saturatedPixels": saturated, "redPixels": red, "greenPixels": green, "bluePixels": blue}


def capture_render(run_dir: Path):
    path = run_dir / "android-tv-render.png"
    with path.open("wb") as output:
        proc = subprocess.Popen(["adb", "-s", SERIAL, "exec-out", "screencap", "-p"], stdout=output, stderr=subprocess.PIPE)
        _, stderr = proc.communicate(timeout=10)
    if proc.returncode:
        raise RuntimeError("emulator screencap failed")
    metrics = screenshot_pixels(path)
    if metrics["saturatedPixels"] < 1000 or min(metrics[key] for key in ("redPixels", "greenPixels", "bluePixels")) < 100:
        raise RuntimeError("actual emulator screenshot has no substantial rendered video color bars")
    metrics["capture"] = str(path)
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, default=ROOT / "docs/evidence/M08/artifacts")
    parser.add_argument("--timeout", type=int, default=480)
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("--diagnostic-back", action="store_true",
        help="Bounded connected route/Back/Downloads focus diagnostic; stops after focus is reached")
    parser.add_argument("--pairing-only", action="store_true",
        help="Run the connected TV device-code pairing workflow against the owned fixture account")
    args = parser.parse_args()
    if not 60 <= args.timeout <= 600:
        parser.error("--timeout must be between 60 and 600 seconds")
    run_id = uuid.uuid4().hex
    run_short = run_id[:10]
    run_dir = args.artifacts.expanduser().resolve() / run_id
    run_dir.mkdir(parents=True, mode=0o700)
    run_dir.chmod(0o700)
    result_path = run_dir / "result.json"
    api_state, data, seed_config, seed_data, down_config = [run_dir / name for name in
        ("api-state", "server-data", "seed-config", "seed-data", "down-config")]
    for path in (api_state, data, seed_config, seed_data, down_config):
        path.mkdir(mode=0o700)
        path.chmod(0o700)
    (data / "library").mkdir()
    (run_dir / "control").mkdir(mode=0o700)
    network = "briani-m08-tv-" + run_short
    names = {"api": "briani-m08-api-" + run_short, "seed": "briani-m08-seed-" + run_short,
        "down": "briani-m08-down-" + run_short}
    owner_labels = {"org.briani.test": "M08", "org.briani.run": run_id}
    created = []
    network_created = False
    reverse_port = None
    relay = None
    relay_thread = None
    flutter_process = None
    private_app_config = None
    admin_password = None
    qbit_passwords = []
    pair_password = None
    pairing_config = {}
    control_dir = run_dir / "control"
    api = down = None
    request_id = None
    torrent_hash = None
    report = {"result": "failed", "milestone": "M08", "runId": run_id,
        "artifacts": str(run_dir)}
    try:
        device = verify_emulator()
        if args.preflight_only:
            image_id = M07.docker("image", "inspect", "--format", "{{.Id}}", API_IMAGE)
            verify_api_image_lock(image_id)
            report.update(result="preflight_passed", device=device, apiImageId=image_id,
                qBittorrentImage=QBIT_IMAGE)
            result_path.write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps({"result": report["result"], "artifact": str(result_path)}))
            return 0
        required = ["docker", "flutter", "adb", "ffmpeg", "ffprobe"]
        missing = [name for name in required if shutil.which(name) is None]
        if missing:
            raise RuntimeError("missing required executable(s): " + ", ".join(missing))
        image_id = M07.docker("image", "inspect", "--format", "{{.Id}}", API_IMAGE)
        verify_api_image_lock(image_id)
        command(["docker", "network", "create", "--internal", "--label", "org.briani.test=M08",
            "--label", f"org.briani.run={run_id}", network])
        network_created = True
        fixtures = run_dir / "fixtures"
        gen_log = run_dir / "fixture-generator.log"
        with gen_log.open("w", encoding="utf-8") as output:
            subprocess.run([sys.executable, str(M07.FIXTURE_GENERATOR), "--out", str(fixtures),
                "--duration", "2", "--early-play-duration", "120", "--torrent-modes", "v1"],
                stdout=output, stderr=subprocess.STDOUT, check=True, timeout=600)
        source = fixtures / "early-play-source" / "Faststart café [test].mp4"
        torrent_source = fixtures / "torrents" / "Faststart café [test]-v1.torrent"
        if source.stat().st_size <= MIN_PREFIX:
            raise RuntimeError("generated progressive fixture does not exceed the 16 MiB gate")
        torrent = M07.bdecode(torrent_source.read_bytes())
        for key in (b"announce", b"announce-list", b"url-list", b"httpseeds", b"nodes"):
            torrent.pop(key, None)
        torrent_path = run_dir / "synthetic-tv-fixture.torrent"
        torrent_path.write_bytes(M07.bencode(torrent))
        (run_dir / "source-oracle.json").write_text(json.dumps({"name": source.name,
            "sizeBytes": source.stat().st_size, "sha256": M07.hashlib.sha256(source.read_bytes()).hexdigest()}, indent=2) + "\n")
        root_name = torrent[b"info"][b"name"].decode("utf-8")
        (seed_data / root_name).mkdir()
        shutil.copyfile(source, seed_data / root_name / source.name)

        def start_qbit(role: str, config_path: Path, payload: Path):
            name = names[role]
            command(["docker", "run", "--detach", "--name", name, "--network", network,
                "--label", "org.briani.test=M08", "--label", f"org.briani.run={run_id}",
                "--label", f"org.briani.role={role}", "-e", f"PUID={os.getuid()}", "-e", f"PGID={os.getgid()}",
                "-e", "WEBUI_PORT=8080", "-e", "TORRENTING_PORT=6881", "-v", f"{config_path}:/config",
                "-v", f"{payload}:/data", QBIT_IMAGE])
            created.append(name)
            password = None
            for _ in range(60):
                found = TEMP_PASSWORD.search(M07.docker("logs", name))
                if found:
                    password = found.group(1)
                if password:
                    break
                time.sleep(1)
            if not password:
                raise RuntimeError(f"owned {role} qBittorrent did not issue its temporary credential")
            qbit_passwords.append(password)
            ip = M07.container_ip(name, network)
            M07.wait_for(role + " qBittorrent", lambda: M07.qbit_ready(ip), 30)
            return M07.Qbit(f"http://{ip}:8080", password), ip

        seed, seed_ip = start_qbit("seed", seed_config, seed_data)
        down, down_ip = start_qbit("down", down_config, data)
        private_settings = {"dht": False, "pex": False, "lsd": False, "upnp": False, "web_ui_upnp": False}
        for engine in (seed, down):
            engine.call("app/setPreferences", {"json": json.dumps(private_settings)})
            if any(engine.json("app/preferences").get(key) is not False for key in private_settings):
                raise RuntimeError("qBittorrent private discovery/forwarding settings did not stick")
        seed.add_torrent(torrent_path, "/data")
        torrent_hash = M07.v1_infohash(torrent_path)
        seed_hash = M07.wait_for("owned seed torrent", lambda: next((row["hash"] for row in seed.json("torrents/info")
            if row.get("hash", "").lower() == torrent_hash), None), 25)
        seed.call("torrents/start", {"hashes": seed_hash})
        M07.wait_for("generated legal source seeding", lambda: (rows[0] if (rows := seed.json("torrents/info", {"hashes": seed_hash})) and rows[0].get("progress") == 1 else None), 60)

        api_host_ip = M07.allocate_api_ip(network)
        api_name = names["api"]
        command(["docker", "run", "--detach", "--name", api_name, "--network", network,
            "--network-alias", "briani", "--ip", api_host_ip, "--label", "org.briani.test=M08",
            "--label", f"org.briani.run={run_id}", "--label", "org.briani.role=api", "--read-only",
            "--cap-drop=ALL", "--security-opt=no-new-privileges", "--pids-limit=256", "--memory=1g", "--cpus=2",
            "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m", "-e", "ASPNETCORE_URLS=http://0.0.0.0:8088",
            "-e", "AllowedHosts=localhost;127.0.0.1;briani", "-v", f"{data}:/data", "-v", f"{api_state}:/config", API_IMAGE])
        created.append(api_name)
        for name in created:
            if any(M07.labels("container", name).get(key) != value for key, value in owner_labels.items()):
                raise RuntimeError("created container lacks exact M08 run ownership labels")
            M07.verify_unpublished(name)
        net_info = json.loads(M07.docker("network", "inspect", network))[0]
        if not net_info.get("Internal") or any((net_info.get("Labels") or {}).get(k) != v for k, v in owner_labels.items()):
            raise RuntimeError("owned swarm is not an isolated internal network")
        api_ip = M07.container_ip(api_name, network)
        api = M07.Api(f"http://{api_ip}:8088")
        M07.wait_for("M09 API readiness", lambda: M07._api_ready(api), 150)
        bootstrap = (api_state / "bootstrap.code").read_text(encoding="utf-8").strip()
        admin_password = uuid.uuid4().hex + "Aa1!"
        auth = api.json("/api/v1/bootstrap", {"code": bootstrap, "username": "m08-tv-admin",
            "displayName": "M08 TV E2E", "password": admin_password})
        api.token = auth["accessToken"]
        root = api.json("/api/v1/admin/storage")[0]
        library_name = "M08 TV generated playback"
        library = api.json("/api/v1/libraries", {"name": library_name, "description": "",
            "storageRootId": root["id"], "relativePath": "library", "readOnly": False})
        if args.pairing_only:
            pair_username = "m08pair" + run_short
            pair_password = uuid.uuid4().hex + "Aa1!"
            pair_actor = api.json("/api/v1/admin/users", {"username": pair_username,
                "displayName": "M08 Pairing Actor", "password": pair_password, "role": "member"})
            (data / "pair-visible").mkdir()
            (data / "pair-restricted").mkdir()
            visible_library = api.json("/api/v1/libraries", {"name": "M08 Pairing Visible",
                "description": "", "storageRootId": root["id"], "relativePath": "pair-visible", "readOnly": False})
            hidden_library = api.json("/api/v1/libraries", {"name": "M08 Pairing Restricted",
                "description": "", "storageRootId": root["id"], "relativePath": "pair-restricted", "readOnly": False})
            api.json(f"/api/v1/libraries/{visible_library['id']}/grants", {"version": visible_library["version"],
                "grants": [{"userId": pair_actor["id"], "read": True, "download": False, "manage": False}]}, method="PUT")
            companion = M07.Api(api.origin)
            companion_auth = companion.json("/api/v1/auth/login", {"username": pair_username,
                "password": pair_password, "deviceName": "M08 companion fixture"})
            companion.token = companion_auth["accessToken"]
            # Check the real fixture member's inspect/approve path before the
            # Android build. The one-off human code stays in process memory.
            status, _, probe_payload = companion.request("/api/v1/auth/device-code",
                {"deviceName": "M08 pairing fixture probe"}, method="POST")
            if status != 201:
                raise RuntimeError(f"pairing fixture probe failed at create-http-{status}")
            probe_code = json.loads(probe_payload).get("userCode")
            if not isinstance(probe_code, str) or not re.fullmatch(r"[A-Z2-9]{8}", probe_code):
                raise RuntimeError("pairing fixture probe returned an invalid device code")
            status, _, probe_preview = companion.request("/api/v1/auth/device-code/inspect",
                {"userCode": probe_code}, method="POST")
            if status != 200:
                raise RuntimeError(f"pairing fixture probe failed at inspect-http-{status}")
            preview = json.loads(probe_preview)
            if preview.get("deviceName") != "M08 pairing fixture probe" or set(preview) != {"deviceName", "expiresAt"}:
                raise RuntimeError("pairing fixture probe returned an unexpected safe preview")
            status, _, _ = companion.request("/api/v1/auth/device-code/approve",
                {"userCode": probe_code}, method="POST")
            if status != 204:
                raise RuntimeError(f"pairing fixture probe failed at approve-http-{status}")
            pairing_config = {"pairUsername": pair_username, "pairVisibleLibraryId": visible_library["id"],
                "pairHiddenLibraryId": hidden_library["id"], "pairVisibleLibraryName": "M08 Pairing Visible",
                "pairHiddenLibraryName": "M08 Pairing Restricted"}
        linked = api.json("/api/v1/admin/integrations/qbittorrent", {
            "baseUrl": f"http://{names['down']}:8080/", "version": 1,
            "username": "admin", "secret": qbit_passwords[1]}, method="PUT")
        if not linked.get("credentialConfigured"):
            raise RuntimeError("M09 server did not persist the isolated qBittorrent credential")
        uploaded = M07.multipart_torrent(api, torrent_path)
        request = api.json("/api/v1/downloads", {"libraryId": library["id"],
            "source": {"kind": "torrentUpload", "value": str(uploaded["id"])}})
        request_id = request["id"]
        files = M07.wait_for("generated torrent metadata", lambda: M07.api_files(api, request_id), 90)
        media_file = next((row for row in files if row.get("kind") == "video" and
            row.get("name") == source.name and row.get("sizeBytes") == source.stat().st_size), None)
        if media_file is None:
            raise RuntimeError("production API metadata did not expose the generated MP4")
        download = api.json(f"/api/v1/downloads/{request_id}")
        if download.get("state") not in ("metadataPending", "awaitingSelection"):
            raise RuntimeError("generated TV request should remain pending until UI file-selection consent")

        relay, relay_thread, reverse_port = open_relay(api_ip, control_dir)
        if args.pairing_only:
            def approve_pair(code: str):
                status, _, payload = companion.request("/api/v1/auth/device-code/inspect", {"userCode": code}, method="POST")
                if status != 200:
                    raise PairingFixtureFailure(f"inspect-http-{status}")
                preview = json.loads(payload)
                if preview.get("deviceName") != "Briani TV" or set(preview) != {"deviceName", "expiresAt"}:
                    raise PairingFixtureFailure("preview-shape")
                status, _, _ = companion.request("/api/v1/auth/device-code/approve", {"userCode": code}, method="POST")
                if status != 204:
                    raise PairingFixtureFailure(f"approve-http-{status}")
                return {"approved": True, "previewSafe": True}
            def pair_consumed(code: str):
                status, _, _ = companion.request("/api/v1/auth/device-code/inspect", {"userCode": code}, method="POST")
                return status == 404
            relay.pair_approver = approve_pair
            relay.pair_replay_check = pair_consumed
        adb("reverse", f"tcp:{reverse_port}", f"tcp:{reverse_port}")
        reverse_installed = True
        profile_label = "M08 TV " + run_short
        config = {"runShort": run_short, "origin": f"http://127.0.0.1:{reverse_port}",
            "username": "m08-tv-admin", "password": admin_password, "profileLabel": profile_label,
            "downloadName": download.get("name") or "Torrent metadata pending", "fileName": source.name,
            "libraryName": library_name, "requestId": request_id, "fileId": media_file["id"],
            **pairing_config}
        host_config = run_dir / "android-e2e.json"
        secret_file(host_config, config)
        private_app_config = f"/data/user/0/{PACKAGE}/files/briani-m08-e2e-{run_short}.json"

        build_log = run_dir / "android-debug-build.log"
        with build_log.open("w", encoding="utf-8") as output:
            build = subprocess.run(["flutter", "build", "apk", "--debug"], cwd=ROOT / "client",
                stdout=output, stderr=subprocess.STDOUT, timeout=240)
        if build.returncode:
            raise RuntimeError(f"Flutter Android debug build failed; see {build_log}")
        apk = ROOT / "client/build/app/outputs/flutter-apk/app-debug.apk"
        adb("install", "-r", str(apk), timeout=90)
        adb("shell", "run-as", PACKAGE, "mkdir", "-p", "files")
        payload = host_config.read_bytes()
        staged_config = subprocess.run(["adb", "-s", SERIAL, "shell",
            f"run-as {PACKAGE} sh -c 'umask 077; cat > files/briani-m08-e2e-{run_short}.json; chmod 600 files/briani-m08-e2e-{run_short}.json'"],
            input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        if staged_config.returncode:
            raise RuntimeError("cannot stage protected config directly into app-private storage")
        host_config.unlink(missing_ok=True)

        flutter_log = run_dir / "flutter-android-e2e.log"
        integration_test = "integration_test/android_pairing_test.dart" if args.pairing_only else "integration_test/android_e2e_test.dart"
        flutter_args = ["flutter", "test", integration_test, "-d", SERIAL,
            f"--dart-define=BRIANI_E2E_FILE={private_app_config}"]
        if args.diagnostic_back:
            flutter_args.append("--dart-define=BRIANI_BACK_DIAGNOSTIC=true")
        with flutter_log.open("w", encoding="utf-8") as output:
            flutter_process = subprocess.Popen(flutter_args, cwd=ROOT / "client", stdout=output,
                stderr=subprocess.STDOUT, env={k: v for k, v in os.environ.items()
                    if k.lower() not in ("http_proxy", "https_proxy", "all_proxy")})
            peer_added = False
            paused = resumed = False
            imported_written = False
            screenshot_done = False
            back_tracks_done = back_player_done = False
            deadline = time.monotonic() + args.timeout
            first_frame = None
            back_requested_at = None
            back_snapshots = []
            while flutter_process.poll() is None and time.monotonic() < deadline:
                if control_dir.joinpath("mark-selection-submitted.json").is_file() and not peer_added:
                    rows = down.json("torrents/info")
                    row = next((item for item in rows if item.get("hash", "").lower() == torrent_hash), None)
                    if row:
                        down.call("torrents/setDownloadLimit", {"hashes": row["hash"], "limit": str(DOWNLOAD_LIMIT)})
                        down.call("torrents/addPeers", {"hashes": row["hash"], "peers": f"{seed_ip}:6881"})
                        peer_added = True
                if control_dir.joinpath("mark-first-frame.json").is_file() and not paused:
                    first_frame = json.loads(control_dir.joinpath("mark-first-frame.json").read_text())
                    rows = down.json("torrents/info", {"hashes": torrent_hash})
                    if not rows or rows[0].get("progress", 1) >= 1:
                        raise RuntimeError("Android TV decoded first frame after torrent completion")
                    first_frame["engineProgressAtFirstFrame"] = rows[0].get("progress")
                    (run_dir / "native-first-frame.json").write_text(json.dumps(first_frame, indent=2) + "\n")
                    M07.download_action(api, request_id, "pause")
                    paused_row = M07.wait_for("qBittorrent to stop for native starvation",
                        lambda: (found[0] if (found := down.json("torrents/info", {"hashes": torrent_hash})) and
                            found[0].get("state", "").startswith("stopped") else None), 20)
                    if paused_row.get("progress", 1) >= 1:
                        raise RuntimeError("Android torrent completed before its cache starvation could be induced")
                    (control_dir / "response-buffer-pause.json").write_text(json.dumps({"stopped": True}))
                    paused = True
                if control_dir.joinpath("mark-buffer-paused.json").is_file() and not resumed:
                    proof = json.loads(control_dir.joinpath("mark-buffer-paused.json").read_text())
                    if proof.get("pausedForCache") is not True:
                        raise RuntimeError("Android native player did not confirm paused-for-cache")
                    M07.download_action(api, request_id, "resume")
                    rows = down.json("torrents/info", {"hashes": torrent_hash})
                    if rows:
                        down.call("torrents/setDownloadLimit", {"hashes": torrent_hash, "limit": str(5 * 1024 * 1024)})
                        down.call("torrents/addPeers", {"hashes": torrent_hash, "peers": f"{seed_ip}:6881"})
                    resumed_row = M07.wait_for("resumed Android torrent", lambda: (found[0] if (found := down.json("torrents/info", {"hashes": torrent_hash})) and
                        found[0].get("state", "") and not found[0].get("state", "").startswith(("stopped", "paused")) else None), 35)
                    (control_dir / "response-buffer-resume.json").write_text(json.dumps({"state": resumed_row.get("state")}))
                    resumed = True
                if control_dir.joinpath("mark-render-request.json").is_file() and not screenshot_done:
                    pixels = capture_render(run_dir)
                    (run_dir / "render-analysis.json").write_text(json.dumps(pixels, indent=2) + "\n")
                    (control_dir / "response-render-result.json").write_text(json.dumps({"captured": True, **pixels}))
                    screenshot_done = True
                if control_dir.joinpath("mark-back-library-request.json").is_file() and not control_dir.joinpath("response-back-library-request.json").exists():
                    if args.diagnostic_back:
                        route_state = json.loads(control_dir.joinpath("mark-back-library-before.json").read_text())
                        back_snapshots.append({"stage": "immediately-before", "resumedActivity": resumed_activity()})
                    adb("shell", "input", "keyevent", "KEYCODE_BACK")
                    (control_dir / "response-back-library-request.json").write_text(json.dumps({"keyEvent": "KEYCODE_BACK"}))
                    back_requested_at = time.monotonic()
                    if args.diagnostic_back:
                        for stage, delay in (("1s-after", 1), ("5s-after", 4)):
                            time.sleep(delay)
                            back_snapshots.append({"stage": stage, "resumedActivity": resumed_activity()})
                        (run_dir / "back-diagnostic.json").write_text(json.dumps({
                            "routeBeforeBack": route_state,
                            "activitySnapshots": back_snapshots,
                        }, indent=2) + "\n")
                if args.diagnostic_back and back_requested_at is not None:
                    if control_dir.joinpath("mark-downloads-focused.json").is_file():
                        pass
                    elif time.monotonic() - back_requested_at > 45:
                        if flutter_process.poll() is None:
                            flutter_process.terminate()
                            try:
                                flutter_process.wait(timeout=8)
                            except subprocess.TimeoutExpired:
                                flutter_process.kill(); flutter_process.wait()
                        raise TimeoutError("Back diagnostic timed out before the library-return or Downloads-focus marker")
                if control_dir.joinpath("mark-back-tracks-request.json").is_file() and not back_tracks_done:
                    adb("shell", "input", "keyevent", "KEYCODE_BACK")
                    (control_dir / "response-back-tracks-request.json").write_text(json.dumps({"keyEvent": "KEYCODE_BACK"}))
                    back_tracks_done = True
                if control_dir.joinpath("mark-player-back-request.json").is_file() and not back_player_done:
                    adb("shell", "input", "keyevent", "KEYCODE_BACK")
                    (control_dir / "response-player-back-sent.json").write_text(json.dumps({"keyEvent": "KEYCODE_BACK"}))
                    back_player_done = True
                if paused and resumed and not imported_written:
                    rows = M07.api_files(api, request_id) or []
                    imported = next((row for row in rows if row.get("id") == media_file["id"] and
                        row.get("playbackState") == "complete" and row.get("importedMediaId")), None)
                    if imported:
                        (control_dir / "response-import-ready.json").write_text(json.dumps({
                            "fileName": imported["name"], "playbackState": imported["playbackState"],
                            "importedMediaId": imported["importedMediaId"]}))
                        imported_written = True
                time.sleep(.2)
            if flutter_process.poll() is None:
                flutter_process.terminate()
                try:
                    flutter_process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    flutter_process.kill(); flutter_process.wait()
                raise TimeoutError(f"Android TV Flutter integration exceeded {args.timeout}s")
        if flutter_process.returncode:
            raise RuntimeError(f"Android TV Flutter integration failed; see {flutter_log}")
        if args.pairing_only:
            checkpoints = sorted(path.name.removeprefix("mark-").removesuffix(".json")
                for path in control_dir.glob("mark-*.json")
                if re.fullmatch(r"mark-[a-z0-9-]{1,48}\.json", path.name))
            expected = {"pairing-code-visible", "pairing-approved", "pairing-library-access", "pairing-code-consumed"}
            if not expected.issubset(checkpoints):
                raise RuntimeError("TV pairing run missed one or more safe checkpoints")
            report.update(result="passed", scenario="connected-tv-device-code-pairing", device=device,
                apiImage=API_IMAGE, apiImageId=image_id, command=f"flutter test {integration_test} -d emulator-5580",
                flutterExitCode=flutter_process.returncode, debugApk=str(apk),
                debugApkSha256=M07.hashlib.sha256(apk.read_bytes()).hexdigest(),
                checkpoints=checkpoints, pairedMemberLibraryProof=json.loads((control_dir / "mark-pairing-library-access.json").read_text()),
                consumedCodeCheck=json.loads((control_dir / "mark-pairing-code-consumed.json").read_text()))
            result_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            sanitize_log(flutter_log, [admin_password, pair_password, *qbit_passwords])
            print(json.dumps({"result": "passed", "scenario": "connected-tv-device-code-pairing", "runId": run_id, "evidence": str(result_path)}))
            return 0
        if args.diagnostic_back:
            report.update(result="diagnostic-complete", device=device,
                command="python3 prototypes/client/run_android_e2e.py --diagnostic-back --timeout 90",
                backDiagnostic=json.loads((run_dir / "back-diagnostic.json").read_text()),
                observedCheckpoints=sorted(path.name.removeprefix("mark-").removesuffix(".json")
                    for path in control_dir.glob("mark-*.json")
                    if re.fullmatch(r"mark-[a-z0-9-]{1,48}\.json", path.name)),
                flutterExitCode=flutter_process.returncode, flutterLog=str(flutter_log))
            result_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            sanitize_log(flutter_log, [admin_password, *qbit_passwords])
            print(json.dumps({"result": "diagnostic-complete", "runId": run_id, "evidence": str(result_path)}))
            return 0
        sanitize_log(flutter_log, [admin_password, *qbit_passwords])
        if not peer_added or not paused or not resumed or not screenshot_done or not imported_written:
            raise RuntimeError("Android TV runner did not complete all swarm, screenshot and import checkpoints")
        report.update(result="passed", device=device, apiImage=API_IMAGE, apiImageId=image_id,
            qBittorrentImage=QBIT_IMAGE, qBittorrentVersion=seed.call("app/version").decode("utf-8", "replace"),
            isolatedInternalNetwork=True, externalTrackerOrPeer=False, publishedPorts=[],
            command="flutter test integration_test/android_e2e_test.dart -d emulator-5580 --dart-define=BRIANI_E2E_FILE=<app-private-path>",
            flutterExitCode=flutter_process.returncode, debugApk=str(apk), debugApkSha256=M07.hashlib.sha256(apk.read_bytes()).hexdigest(),
            firstFrame=first_frame, nativeBufferPauseAndResume={
                "pausedForCache": True,
                "proof": json.loads((control_dir / "mark-buffer-paused.json").read_text()),
                "resumeProof": json.loads((control_dir / "mark-buffer-resumed.json").read_text())},
            renderedPixels=json.loads((run_dir / "render-analysis.json").read_text()),
            importedMedia=json.loads((control_dir / "response-import-ready.json").read_text()),
            importedMediaBrowsedInUi=(control_dir / "mark-completed-import-browsed.json").is_file(),
            realDpadEvents=json.loads((control_dir / "mark-tracks-panel-opened.json").read_text()).get("hardwareKeys", []),
            realBackEvents=["KEYCODE_BACK"], screenshot=str(run_dir / "android-tv-render.png"),
            flutterLog=str(flutter_log), buildLog=str(build_log))
        activation_diagnostic = control_dir / "mark-download-request-activated.json"
        if activation_diagnostic.is_file():
            report["downloadRequestActivationDiagnostic"] = json.loads(activation_diagnostic.read_text(encoding="utf-8"))
        result_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "passed", "runId": run_id, "evidence": str(result_path)}))
        return 0
    except Exception as error:
        if flutter_process is not None and flutter_process.poll() is None:
            flutter_process.terminate()
            try:
                flutter_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                flutter_process.kill(); flutter_process.wait()
        message = str(error)
        message = re.sub(r"https?://[^\s]+", "[redacted-url]", message)
        for secret in [admin_password, *qbit_passwords]:
            if secret:
                message = message.replace(secret, "[redacted]")
        report.update(result="failed", failure=type(error).__name__, detail=message)
        if control_dir.is_dir():
            report["observedCheckpoints"] = sorted(
                path.name.removeprefix("mark-").removesuffix(".json")
                for path in control_dir.glob("mark-*.json")
                if re.fullmatch(r"mark-[a-z0-9-]{1,48}\.json", path.name)
            )
        diagnostic_path = run_dir / "back-diagnostic.json"
        if diagnostic_path.is_file():
            report["backDiagnostic"] = json.loads(diagnostic_path.read_text(encoding="utf-8"))
        activation_diagnostic = control_dir / "mark-download-request-activated.json"
        if activation_diagnostic.is_file():
            report["downloadRequestActivationDiagnostic"] = json.loads(activation_diagnostic.read_text(encoding="utf-8"))
        result_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if flutter_log := run_dir / "flutter-android-e2e.log":
            sanitize_log(flutter_log, [admin_password, *qbit_passwords])
        print(json.dumps({"result": "failed", "runId": run_id, "failure": report["failure"], "evidence": str(result_path)}))
        return 1
    finally:
        if flutter_process is not None and flutter_process.poll() is None:
            flutter_process.terminate()
        if private_app_config:
            adb("shell", "run-as", PACKAGE, "rm", "-f", private_app_config, check=False)
        if reverse_port is not None:
            adb("reverse", "--remove", f"tcp:{reverse_port}", check=False)
        if relay is not None:
            relay.shutdown()
            relay.server_close()
        for name in reversed(created):
            try:
                if all(M07.labels("container", name).get(k) == v for k, v in owner_labels.items()):
                    M07.docker("rm", "--force", name)
            except Exception:
                pass
        if network_created:
            try:
                if all(M07.labels("network", network).get(k) == v for k, v in owner_labels.items()):
                    M07.docker("network", "rm", network)
            except Exception:
                pass
        for path in (api_state, data, seed_config, seed_data, down_config, run_dir / "fixtures"):
            shutil.rmtree(path, ignore_errors=True)
        (run_dir / "android-e2e.json").unlink(missing_ok=True)
        sanitize_log(run_dir / "flutter-android-e2e.log", [admin_password, *qbit_passwords])


if __name__ == "__main__":
    raise SystemExit(main())
