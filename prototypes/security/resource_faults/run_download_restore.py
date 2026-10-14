#!/usr/bin/env python3
"""Exercise a production download request through isolated full-stack restore."""
from __future__ import annotations

import hashlib
import http.cookiejar
import importlib.util
import ipaddress
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[3]
QBIT_IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
SIMULATION_SUBNETS = ("11.86.221.0/29", "12.189.214.0/29", "13.117.239.0/29")
FIXTURE_BYTES = 8 * 1024 * 1024
FIXTURE_NAME = "M10-restore-generated.mp4"
OWNER = "resource-faults"
spec = importlib.util.spec_from_file_location("m09_integrated_drill", ROOT / "tools/operations/drill.py")
drill = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(drill)
life_spec = importlib.util.spec_from_file_location("m05_lifecycle_helpers", ROOT / "prototypes/downloads/lifecycle/run_api_restart.py")
life = importlib.util.module_from_spec(life_spec)
assert life_spec and life_spec.loader
life_spec.loader.exec_module(life)


def _bounded_run_readonly(argv: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(argv, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, check=False, timeout=240)
    except subprocess.TimeoutExpired as error:
        raise drill.DrillError(f"{Path(argv[0]).name} command timed out at the 240-second bound") from error
    except OSError as error:
        raise drill.DrillError(f"cannot run {Path(argv[0]).name}: {type(error).__name__}") from error


def _bounded_ops_run(argv, *, cwd: Path, env=None, capture=False):
    try:
        result = subprocess.run(list(map(str, argv)), cwd=cwd, env=env, text=True,
                                stdout=subprocess.PIPE if capture else None,
                                stderr=subprocess.PIPE if capture else None, check=False, timeout=240)
    except subprocess.TimeoutExpired as error:
        raise drill.ops.OpsError(f"command timed out at the 240-second bound: {Path(argv[0]).name}") from error
    except OSError as error:
        raise drill.ops.OpsError(f"cannot run {Path(argv[0]).name}: {type(error).__name__}") from error
    if result.returncode:
        if capture:
            raise drill.ops.OpsError(f"command failed ({result.returncode}): {Path(argv[0]).name}")
        raise drill.ops.OpsError(f"command failed ({result.returncode}): {Path(argv[0]).name}")
    return result


drill.run_readonly = _bounded_run_readonly
drill.ops.run = _bounded_ops_run


def docker(*args: str, timeout: int = 45) -> str:
    env = {**os.environ, "DOCKER_CONFIG": str(ROOT / ".tools/docker-config")}
    result = subprocess.run(["docker", *args], cwd=ROOT, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if result.returncode:
        raise drill.DrillError(f"Docker {args[0]} failed ({result.returncode})")
    return result.stdout.strip()


def wait(label: str, action, timeout: float = 60, interval: float = .5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = action()
        if value:
            return value
        time.sleep(interval)
    raise drill.DrillError(f"timed out waiting for {label}")


def _file_row(files: object, file_id: str) -> dict | None:
    if not isinstance(files, list):
        return None
    return next((row for row in files if isinstance(row, dict) and row.get("id") == file_id), None)


def partial_file_progress(files: object, file_id: str, size_bytes: int) -> list[dict] | None:
    row = _file_row(files, file_id)
    count = row.get("downloadedBytes", 0) if row else 0
    return files if isinstance(files, list) and count >= 524288 and count < size_bytes * .8 else None


def completed_file(files: object, file_id: str, size_bytes: int) -> list[dict] | None:
    row = _file_row(files, file_id)
    return files if isinstance(files, list) and row and row.get("downloadedBytes", 0) == size_bytes else None


def seed_password_from_startup(value: object, expected_container_id: str) -> str:
    if (not isinstance(value, tuple) or len(value) != 2 or
            value[0] != expected_container_id or not isinstance(value[1], str) or not value[1]):
        raise drill.DrillError("seed startup credential did not match the exact owned container ID")
    return value[1]


def validate_seed_record(record: dict, expected_id: str, run_id: str,
                         seed_config: Path, seed_data: Path) -> None:
    expected_labels = {"org.briani.test": "M10-download-restore", "org.briani.owner": OWNER,
                       "org.briani.run": run_id, "org.briani.kind": "fixture-seeder"}
    labels = record.get("Config", {}).get("Labels") or {}
    if any(labels.get(key) != value for key, value in expected_labels.items()):
        raise drill.DrillError("seed container is missing this run's exact ownership labels")
    if record.get("Id") != expected_id or record.get("Config", {}).get("Image") != QBIT_IMAGE:
        raise drill.DrillError("seed container identity or pinned image changed")
    mounts = {(str(Path(item.get("Source", "")).resolve()), item.get("Destination"))
              for item in record.get("Mounts", []) if item.get("Type") == "bind"}
    expected_mounts = {(str(seed_config.resolve()), "/config"), (str(seed_data.resolve()), "/data")}
    if mounts != expected_mounts:
        raise drill.DrillError("seed container bind mounts do not match this run's owned fixture roots")


def validate_pre_restore_fixture_endpoints(endpoints: set[str], seed_id: str, source_guard_id: str) -> bool:
    """Allow only the seeder and optionally the stopped source guard on our fixture network."""
    if endpoints == {seed_id}:
        return False
    if endpoints == {seed_id, source_guard_id}:
        return True
    raise drill.DrillError(
        "refusing fixture-network move; observed endpoint IDs do not match this run "
        f"(observed={sorted(endpoints)}, expected seed={seed_id} and optional source guard={source_guard_id})")


class QbitSession:
    def __init__(self, origin: str, username: str, password: str, *, service_host: bool = False):
        self.origin = origin.rstrip("/")
        self.username = username
        self.password = password
        self.service_host = service_host
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPCookieProcessor(self.jar))
        self.login()

    def headers(self) -> dict[str, str]:
        host = "qbittorrent:8080" if self.service_host else urllib.parse.urlsplit(self.origin).netloc
        return {"Host": host, "Origin": "http://qbittorrent:8080" if self.service_host else self.origin,
                "Referer": ("http://qbittorrent:8080/" if self.service_host else self.origin + "/")}

    def request(self, path: str, fields: dict[str, str] | None = None, *, raw: bytes | None = None,
                content_type: str | None = None, method: str = "POST") -> bytes:
        query = ""
        data = raw
        headers = self.headers()
        if fields is not None and method == "GET":
            query = "?" + urllib.parse.urlencode(fields)
        elif fields is not None:
            data = urllib.parse.urlencode(fields).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        if content_type:
            headers["Content-Type"] = content_type
        url = self.origin + "/api/v2/" + path + query
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=12) as response:
                return response.read(1_000_000)
        except (OSError, urllib.error.URLError, TimeoutError) as error:
            raise drill.DrillError(f"qBittorrent {path} failed ({type(error).__name__})") from error

    def call(self, path: str, fields: dict[str, str] | None = None) -> bytes:
        get_routes = ("/info", "app/version", "app/preferences", "transfer/downloadLimit", "transfer/uploadLimit")
        return self.request(path, fields, method="GET" if path.endswith(get_routes) else "POST")

    def json(self, path: str, fields: dict[str, str] | None = None):
        payload = self.call(path, fields)
        return json.loads(payload) if payload else None

    def get_json(self, path: str):
        payload = self.request(path, method="GET")
        return json.loads(payload) if payload else None

    def login(self) -> None:
        self.request("auth/login", {"username": self.username, "password": self.password})
        if not any(cookie.name == "SID" or cookie.name.startswith("QBT_SID") for cookie in self.jar):
            raise drill.DrillError("qBittorrent did not create an authenticated session")
        self.call("app/version")

    def add_torrent(self, metainfo: bytes, save_path: str, *, paused: bool = True) -> None:
        boundary = "----briani" + uuid.uuid4().hex
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"savepath\"\r\n\r\n{save_path}\r\n"
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"paused\"\r\n\r\n{'true' if paused else 'false'}\r\n"
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"torrents\"; filename=\"fixture.torrent\"\r\n"
                "Content-Type: application/x-bittorrent\r\n\r\n").encode() + metainfo + f"\r\n--{boundary}--\r\n".encode()
        self.request("torrents/add", raw=body, content_type=f"multipart/form-data; boundary={boundary}")


def public_subnet() -> str:
    pools = SIMULATION_SUBNETS
    records = docker("network", "ls", "-q").splitlines()
    used: list[ipaddress.IPv4Network] = []
    if records:
        for item in json.loads(docker("network", "inspect", *records)):
            for config in item.get("IPAM", {}).get("Config") or []:
                try:
                    used.append(ipaddress.ip_network(config["Subnet"], strict=False))
                except (KeyError, ValueError):
                    continue
    routes = subprocess.run(["ip", "-4", "route", "show"], text=True, capture_output=True, timeout=5)
    if routes.returncode:
        raise drill.DrillError("cannot verify host IPv4 routes before choosing the isolated fixture subnet")
    for line in routes.stdout.splitlines():
        token = line.split()[0]
        try:
            used.append(ipaddress.ip_network(token, strict=False))
        except ValueError:
            continue
    for cidr in pools:
        candidate = ipaddress.ip_network(cidr)
        if not any(candidate.overlaps(existing) for existing in used):
            return str(candidate)
    raise drill.DrillError("no unused public-address simulation subnet is available")


def make_generated_fixture(path: Path) -> tuple[bytes, bytes, str]:
    payload = bytes((index * 73 + 19) % 251 for index in range(FIXTURE_BYTES))
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.write_bytes(payload)
    piece_length = 262144
    pieces = b"".join(hashlib.sha1(payload[offset:offset + piece_length]).digest()
                     for offset in range(0, len(payload), piece_length))
    info = {b"length": len(payload), b"name": FIXTURE_NAME.encode(), b"piece length": piece_length,
            b"pieces": pieces, b"private": 1}
    return life.bencode({b"info": info}), payload, hashlib.sha1(life.bencode(info)).hexdigest()


def api_request(origin: str, method: str, path: str, *, token: str | None = None,
                body: object | None = None, raw: bytes | None = None, content_type: str | None = None,
                idempotency_key: str | None = None) -> tuple[int, dict[str, str], bytes]:
    data = raw if raw is not None else (None if body is None else json.dumps(body, separators=(",", ":")).encode())
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    if idempotency_key:
        headers["Idempotency-Key"] = idempotency_key
    if data is not None:
        headers["Content-Type"] = content_type or "application/json"
    req = urllib.request.Request(origin + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=12) as response:
            return response.status, dict(response.headers), response.read(2_000_000)
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers), error.read(64_000)
    except (OSError, TimeoutError) as error:
        raise drill.DrillError(f"Briani {method} {path} transport failed ({type(error).__name__})") from error


def parse_json(response: tuple[int, dict[str, str], bytes], expected: int, label: str):
    status, _, body = response
    if status != expected:
        raise drill.DrillError(f"{label}: unexpected HTTP {status}")
    return json.loads(body) if body else None


class DownloadRestoreDrill(drill.IntegratedDrill):
    def __init__(self, root: Path, *, run_id: str, retain_on_failure: bool = False):
        super().__init__(root, keep=False, retain_on_failure=retain_on_failure)
        self.run_id = run_id
        self.seed_name = f"briani-m10-restore-seed-{self.run_id[:10]}"
        self.network_name = f"briani-m10-restore-{self.run_id[:10]}"
        self.seed_id = ""
        self.guard_id = ""
        self.network_id = ""
        self.network_attached = False
        self.guard_ids: set[str] = set()
        self.network_subnet = ""
        self.seed_ip = ""
        self.seed_password = ""
        self.metainfo = b""
        self.infohash = ""
        self.torrent_root = ""
        self.fixture_media = root / "generated-fixture" / FIXTURE_NAME
        self.fixture_payload = b""
        self.request_id = ""
        self.request_key = ""
        self.upload_id = ""
        self.member_token = ""
        self.source_payload_path: Path | None = None
        self.payload_relative: Path | None = None
        self.key_hash = ""
        self.source_progress = 0
        self.partial_payload_sha256 = ""
        self.partial_payload_inode = 0
        self.seed_data = root / "fixture-seed-data"
        self.seed_config = root / "fixture-seed-config"
        self.qbit_source: QbitSession | None = None
        self.removed_fixture_container_ids: list[str] = []
        self.removed_fixture_network_id = ""
        self.cleanup_report: dict = {}
        self.recheck_state_observed = False
        self.recheck_completion_observed = False
        self.metadata_diagnostics: dict = {}

    def cli(self, label: str, args: list[str], expected: int = 0) -> subprocess.CompletedProcess[str]:
        try:
            result = subprocess.run([sys.executable, str(drill.CLI), *args], cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=240)
        except subprocess.TimeoutExpired as error:
            raise drill.DrillError(f"{label}: CLI exceeded the 240-second bound") from error
        except OSError as error:
            raise drill.DrillError(f"{label}: CLI could not run ({type(error).__name__})") from error
        drill.log_line(f"cli {label}: exit {result.returncode} (expected {expected})")
        if result.returncode != expected:
            raise drill.DrillError(f"{label}: CLI returned unexpected exit {result.returncode}")
        return result

    def cleanup(self) -> None:
        if self.root.exists() or self.root.is_symlink():
            marker = self.root / "owner.marker"
            if (self.root.is_symlink() or self.root.resolve().parent != Path("/tmp") or
                    not marker.is_file() or marker.is_symlink() or
                    marker.read_text(encoding="ascii") != f"{OWNER}:{self.run_id}\n"):
                raise drill.DrillError("refusing cleanup without this run's exact scratch-root owner marker")
        super().cleanup()

    def find_guard(self, project: Path) -> str:
        name = self.project_names[project]
        records = drill.inspect_json("container", drill.docker_ids("container", name))
        found = [record for record in records if (drill.resource_labels(record).get("com.docker.compose.service") == "torrent-egress-guard")]
        if len(found) != 1 or not drill.is_owned_container(found[0], name, self.root):
            raise drill.DrillError("could not verify the exact owned qBittorrent namespace guard")
        return found[0]["Id"]

    def own_network_and_seed(self) -> None:
        self.network_subnet = public_subnet()
        network_label = ["--label", "org.briani.test=M10-download-restore", "--label", f"org.briani.owner={OWNER}", "--label", f"org.briani.run={self.run_id}"]
        self.network_id = docker("network", "create", "--internal", "--subnet", self.network_subnet, *network_label, self.network_name)
        network = json.loads(docker("network", "inspect", self.network_name))[0]
        expected_labels = {"org.briani.test": "M10-download-restore", "org.briani.owner": OWNER, "org.briani.run": self.run_id}
        if network.get("Labels") != expected_labels or not network.get("Internal"):
            raise drill.DrillError("created fixture network was not the exact internal owned network")
        if network["Id"] != self.network_id:
            raise drill.DrillError("created fixture network ID changed during inspection")
        subnet = ipaddress.ip_network(self.network_subnet)
        self.seed_ip = str(subnet.network_address + 3)
        guard_ip = str(subnet.network_address + 2)
        self.guard_id = self.find_guard(self.source)
        self.guard_ids.add(self.guard_id)
        docker("network", "connect", "--ip", guard_ip, self.network_id, self.guard_id)
        self.network_attached = True
        self.seed_data.mkdir(mode=0o700)
        self.seed_config.mkdir(mode=0o700)
        self.torrent_root = self.torrent_root or ""
        self.metainfo, self.fixture_payload, self.infohash = make_generated_fixture(self.fixture_media)
        self.torrent_root = FIXTURE_NAME
        shutil.copyfile(self.fixture_media, self.seed_data / self.fixture_media.name)
        os.chmod(self.seed_data / self.fixture_media.name, 0o600)
        self.seed_id = docker("run", "--detach", "--name", self.seed_name, "--network", self.network_id, "--ip", self.seed_ip,
               "--label", "org.briani.test=M10-download-restore", "--label", f"org.briani.owner={OWNER}",
               "--label", f"org.briani.run={self.run_id}", "--label", "org.briani.kind=fixture-seeder",
               "--env", f"PUID={os.getuid()}", "--env", f"PGID={os.getgid()}", "--env", "WEBUI_PORT=8080",
               "--env", "TORRENTING_PORT=6881", "--mount", f"type=bind,source={self.seed_config},target=/config",
               "--mount", f"type=bind,source={self.seed_data},target=/data", QBIT_IMAGE)
        startup = wait("seed container startup credential", self._seed_ready, 75)
        self.seed_password = seed_password_from_startup(startup, self.seed_id)
        self.seed_qbit = QbitSession(f"http://{self.seed_ip}:8080", "admin", self.seed_password)
        self.seed_qbit.call("app/setPreferences", {"json": json.dumps({"dht": False, "pex": False, "lsd": False,
            "upnp": False, "web_ui_upnp": False, "max_connec": 12, "max_connec_per_torrent": 8})})
        self.seed_qbit.add_torrent(self.metainfo, "/data", paused=False)
        seed_row = wait("fixture torrent seed registration", lambda: self._torrent_row(self.seed_qbit, self.infohash), 45)
        if seed_row.get("hash") != self.infohash or int(seed_row.get("size", -1)) != self.fixture_media.stat().st_size:
            raise drill.DrillError("seed engine did not register the exact generated private fixture")
        self.seed_qbit.call("torrents/start", {"hashes": self.infohash})
        seed_row = wait("complete fixture seed", lambda: (
            value if (value := self._torrent_row(self.seed_qbit, self.infohash))
            and int(value.get("amount_left", 1)) == 0 and float(value.get("progress", 0)) == 1.0
            and not str(value.get("state", "")).startswith("paused") else None), 45)
        self.qbit_source = QbitSession("http://127.0.0.1:18080", "admin", self._qbit_secret, service_host=True)
        self.qbit_source.call("app/setPreferences", {"json": json.dumps({"dht": False, "pex": False, "lsd": False,
            "upnp": False, "web_ui_upnp": False})})

    def _seed_ready(self):
        logs = docker("logs", self.seed_name)
        match = drill.re.search(r"temporary password is provided for this session:\s*(\S+)", logs, drill.re.I)
        if not match or "8080" not in logs:
            return None
        record = json.loads(docker("inspect", self.seed_name))[0]
        validate_seed_record(record, self.seed_id, self.run_id, self.seed_config, self.seed_data)
        return record["Id"], match.group(1)

    @staticmethod
    def _torrent_row(client: QbitSession, infohash: str):
        rows = client.json("torrents/info", {"hashes": infohash})
        return rows[0] if isinstance(rows, list) and rows else None

    def add_peer(self, client: QbitSession) -> None:
        client.call("torrents/addPeers", {"hashes": self.infohash, "peers": f"{self.seed_ip}:6881"})

    def capture_metadata_diagnostics(self) -> dict:
        def capture(action):
            try:
                return action()
            except (drill.DrillError, urllib.error.URLError, json.JSONDecodeError) as error:
                return {"readError": type(error).__name__}
        return {
            "request": capture(lambda: self.api_json("GET", f"/api/v1/downloads/{self.request_id}", token=self.member_token)),
            "files": capture(lambda: self.api_json("GET", f"/api/v1/downloads/{self.request_id}/files", token=self.member_token)),
            "sourceTorrent": capture(lambda: self._torrent_row(self.qbit_source, self.infohash)),
            "sourcePeers": capture(lambda: self.qbit_source.get_json(f"sync/torrentPeers?hash={self.infohash}")),
            "seedTorrent": capture(lambda: self._torrent_row(self.seed_qbit, self.infohash)),
            "seedPeers": capture(lambda: self.seed_qbit.get_json(f"sync/torrentPeers?hash={self.infohash}")),
        }

    def api_json(self, method: str, path: str, *, token: str, body: object | None = None,
                 raw: bytes | None = None, content_type: str | None = None,
                 key: str | None = None, expected: int = 200):
        response = api_request(self.api_client.origin, method, path, token=token, body=body, raw=raw,
                               content_type=content_type, idempotency_key=key)
        return parse_json(response, expected, method + " " + path)

    def upload_metainfo(self) -> str:
        boundary = "----briani" + uuid.uuid4().hex
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"generated-private.torrent\"\r\n"
                "Content-Type: application/x-bittorrent\r\n\r\n").encode() + self.metainfo + f"\r\n--{boundary}--\r\n".encode()
        uploaded = self.api_json("POST", "/api/v1/torrent-uploads", token=self.member_token, raw=body,
                                 content_type=f"multipart/form-data; boundary={boundary}", expected=201)
        return uploaded["id"]

    def submit_selection(self) -> tuple[list[dict], dict]:
        row = wait("managed torrent upload admission", lambda: self._torrent_row(self.qbit_source, self.infohash), 60)
        if not row or row.get("hash") != self.infohash:
            raise drill.DrillError("managed engine did not admit the exact uploaded private torrent infohash")
        self.add_peer(self.qbit_source)
        try:
            files = wait("production download file metadata", lambda: (
                result if isinstance(result := self.api_json("GET", f"/api/v1/downloads/{self.request_id}/files", token=self.member_token), list)
                and any(file.get("kind") == "video" for file in result) else None), 90)
        except drill.DrillError as error:
            self.metadata_diagnostics = self.capture_metadata_diagnostics()
            raise drill.DrillError(f"production file metadata unavailable; snapshot={json.dumps(self.metadata_diagnostics, separators=(',', ':'))}") from error
        media = next((file for file in files if file.get("kind") == "video" and file.get("sizeBytes") == self.fixture_media.stat().st_size), None)
        if not media:
            raise drill.DrillError("production download metadata did not identify the generated MP4")
        self.add_peer(self.qbit_source)
        settings = self.qbit_source.json("app/preferences")
        if settings.get("dht") or settings.get("pex") or settings.get("lsd"):
            raise drill.DrillError("managed qBittorrent discovery remained enabled in isolated fixture test")
        # A temporary per-torrent seed cap proves the request stays incomplete long enough to pause.
        self.seed_qbit.call("torrents/setUploadLimit", {"hashes": self.infohash, "limit": "262144"})
        self.qbit_source.call("transfer/setDownloadLimit", {"limit": "0"})
        current = self.api_json("GET", f"/api/v1/downloads/{self.request_id}", token=self.member_token)
        selection = {"files": [{"fileId": file["id"], "selected": file["id"] == media["id"], "priority": "normal"} for file in files],
                     "autoStart": True, "version": current["version"]}
        response = api_request(self.api_client.origin, "PUT", f"/api/v1/downloads/{self.request_id}/selection",
                               token=self.member_token, body=selection)
        if response[0] != 202:
            raise drill.DrillError(f"download selection returned HTTP {response[0]}")
        location = response[1].get("Location")
        if location:
            op_id = location.rsplit("/", 1)[-1]
            operation = wait("selection operation", lambda: (
                op if (op := self.api_json("GET", "/api/v1/operations/" + op_id,
                    token=self.member_token)).get("state") in ("completed", "failed") else None), 90)
            if operation.get("state") != "completed":
                raise drill.DrillError("production selection operation did not complete")
        self.add_peer(self.qbit_source)
        row = wait("managed torrent row", lambda: self._torrent_row(self.qbit_source, self.infohash), 45)
        if not row or row.get("hash") != self.infohash:
            raise drill.DrillError("managed engine did not retain the exact fixture torrent")
        # Wait for a small, verified partial prefix, far below the synthetic fixture's full size.
        progress = wait("partial payload bytes", lambda: partial_file_progress(
            self.api_json("GET", f"/api/v1/downloads/{self.request_id}/files", token=self.member_token),
            media["id"], media["sizeBytes"]))
        file_view = next(item for item in progress if item["id"] == media["id"])
        current = self.api_json("GET", f"/api/v1/downloads/{self.request_id}", token=self.member_token)
        paused_op = self.api_json("POST", f"/api/v1/downloads/{self.request_id}/actions", token=self.member_token,
            body={"action": "pause", "version": current["version"]}, expected=202)
        pause_result = wait("download pause operation", lambda: (op if (op := self.api_json("GET", f"/api/v1/operations/{paused_op['id']}", token=self.member_token)).get("state") in ("completed", "failed") else None), 60)
        if pause_result.get("state") != "completed":
            raise drill.DrillError("production pause operation failed")
        after_pause = wait("paused request state", lambda: (
            value if (value := self.api_json("GET", f"/api/v1/downloads/{self.request_id}", token=self.member_token)).get("state") == "paused" else None), 45)
        seed_row = self._torrent_row(self.seed_qbit, self.infohash)
        if not seed_row or seed_row.get("hash") != self.infohash:
            raise drill.DrillError("generated seed disappeared while pausing the managed download")
        qbit_row = self._torrent_row(self.qbit_source, self.infohash)
        engine_downloaded = int((qbit_row or {}).get("downloaded", 0))
        engine_left = int((qbit_row or {}).get("amount_left", media["sizeBytes"]))
        if engine_downloaded <= 0 or engine_downloaded >= media["sizeBytes"] or engine_left <= 0:
            raise drill.DrillError("paused qBittorrent engine did not retain an incomplete transfer")
        content = PurePosixPath(str((qbit_row or {}).get("content_path") or ""))
        if not content.is_absolute():
            raise drill.DrillError("engine returned no absolute managed payload path")
        try:
            content_rel = content.relative_to("/data")
        except ValueError as error:
            raise drill.DrillError("managed payload path escaped its /data mount") from error
        source = self.source_data.joinpath(*content_rel.parts)
        if source.is_dir():
            rel = PurePosixPath(media["relativePath"])
            if rel.is_absolute() or ".." in rel.parts:
                raise drill.DrillError("download metadata returned an unsafe media relative path")
            source = source.joinpath(*rel.parts)
        if not source.is_file() or source.stat().st_size != media["sizeBytes"]:
            raise drill.DrillError("paused partial payload is not present at the engine-owned managed path")
        self.qbit_source.call("transfer/setDownloadLimit", {"limit": "23456"})
        if int(self.qbit_source.call("transfer/downloadLimit").decode().strip()) != drill.qbit_limit_readback(23456):
            raise drill.DrillError("temporary source transfer cap was not restored before backup")
        self.source_payload_path = source
        self.payload_relative = source.relative_to(self.source_data)
        self.source_progress = int(file_view["downloadedBytes"])
        self.partial_payload_sha256 = hashlib.sha256(source.read_bytes()).hexdigest()
        self.partial_payload_inode = source.stat().st_ino
        return files, {"media": media, "downloadedBytes": self.source_progress, "request": after_pause,
                       "engineDownloaded": engine_downloaded, "engineAmountLeft": engine_left,
                       "payloadSha256": self.partial_payload_sha256, "payloadInode": self.partial_payload_inode}

    def partial_restore(self, transfer: dict) -> dict:
        if not self.source_payload_path or not self.payload_relative:
            raise drill.DrillError("source media path missing before backup")
        self.cli("backup", ["backup", "--project", str(self.source), "--output", str(self.backup)])
        manifest = drill.ops.verify_backup(self.backup, deployment=True)
        if manifest.get("mediaIncluded") is not False:
            raise drill.DrillError("configuration backup unexpectedly claims media was included")
        self.stop_project(self.source, "stop source before restore")
        if (self.source_payload_path.stat().st_ino != self.partial_payload_inode or
                hashlib.sha256(self.source_payload_path.read_bytes()).hexdigest() != self.partial_payload_sha256):
            raise drill.DrillError("retained source media inode or bytes changed after stopping the source project")
        if self.partial_payload_sha256 == hashlib.sha256(self.fixture_payload).hexdigest():
            raise drill.DrillError("pause did not preserve a genuinely partial fixture")
        self.restore_data = self.source_data
        self.cli("restore", ["restore", "--backup", str(self.backup), "--project", str(self.restore),
                             "--state", str(self.restore_state), "--data", str(self.restore_data), "--allow-existing-data"])
        key_path = self.restore_state / "briani/secret.key"
        self.key_hash = hashlib.sha256(key_path.read_bytes()).hexdigest()
        self.cli("doctor-restore", ["doctor", "--project", str(self.restore)])
        self._active_project = self.restore
        self.cli("up-restore", ["up", "--project", str(self.restore)])
        restored_payload = self.restore_data / self.payload_relative
        if (restored_payload.stat().st_ino != self.partial_payload_inode or
                hashlib.sha256(restored_payload.read_bytes()).hexdigest() != self.partial_payload_sha256):
            raise drill.DrillError("retained media inode or bytes changed during configuration restore startup")
        self.verify_identity_state(self.restore, self.restore_data, self.restore_state, "restore")
        self.verify_managed_qbit(self.restore)
        restored_guard = self.find_guard(self.restore)
        self.guard_ids.add(restored_guard)
        if restored_guard != self.guard_id:
            old_guard = json.loads(docker("inspect", self.guard_id))[0]
            if not drill.is_owned_container(old_guard, self.project_names[self.source], self.root):
                raise drill.DrillError("refusing to disconnect a network endpoint not owned by the source drill")
            old_network = json.loads(docker("network", "inspect", self.network_id))[0]
            expected_labels = {"org.briani.test": "M10-download-restore", "org.briani.owner": OWNER,
                               "org.briani.run": self.run_id}
            endpoints = set((old_network.get("Containers") or {}).keys())
            if old_network.get("Labels") != expected_labels:
                raise drill.DrillError("refusing to move the fixture network with changed ownership labels")
            old_guard_attached = validate_pre_restore_fixture_endpoints(endpoints, self.seed_id, self.guard_id)
            if old_guard_attached:
                docker("network", "disconnect", self.network_id, self.guard_id)
            remaining = json.loads(docker("network", "inspect", self.network_id))[0].get("Containers") or {}
            if self.guard_id in remaining or set(remaining) != {self.seed_id}:
                raise drill.DrillError("old source guard did not disconnect cleanly from the owned fixture network")
            docker("network", "connect", "--ip", str(ipaddress.ip_network(self.network_subnet).network_address + 2),
                   self.network_id, restored_guard)
            self.guard_id = restored_guard
        self.api_client = drill.HttpApi("http://127.0.0.1:8088")
        self.member_token = self.login(self.creds["memberUsername"], self.creds["memberPassword"], "restored member login")
        saved = self.api_json("GET", f"/api/v1/downloads/{self.request_id}", token=self.member_token)
        if saved.get("id") != self.request_id or saved.get("state") != "paused" or saved.get("ownerId") != self.member_id:
            raise drill.DrillError("restored request identity or paused state was not preserved")
        listed = self.api_json("GET", "/api/v1/downloads?limit=200", token=self.member_token)
        matches = [row for row in listed.get("items", []) if row.get("id") == self.request_id]
        if len(matches) != 1:
            raise drill.DrillError("restored member request list did not contain exactly one request")
        original_key = self.api_json("POST", "/api/v1/downloads", token=self.member_token,
            body={"libraryId": self.library_id, "source": {"kind": "torrentUpload", "value": self.upload_id}},
            key=self.request_key, expected=202)
        if original_key.get("id") != self.request_id:
            raise drill.DrillError("restored idempotency key did not resolve to the same download request")
        restored_files = self.api_json("GET", f"/api/v1/downloads/{self.request_id}/files", token=self.member_token)
        media = next((row for row in restored_files if row.get("kind") == "video" and row.get("sizeBytes") == self.fixture_media.stat().st_size), None)
        if not media:
            raise drill.DrillError("restored request lost its selected video file metadata")
        self.qbit_source = QbitSession("http://127.0.0.1:18080", "admin", self._qbit_secret, service_host=True)
        row = wait("restored qBittorrent torrent identity", lambda: self._torrent_row(self.qbit_source, self.infohash), 60)
        if not row or row.get("hash") != self.infohash:
            raise drill.DrillError("restored qBittorrent did not retain the exact torrent identity")
        # Force the restored engine to re-evaluate only the user-owned torrent/payload.
        self.qbit_source.call("torrents/recheck", {"hashes": self.infohash})
        try:
            wait("restored torrent checking state", lambda: (r if (r := self._torrent_row(self.qbit_source, self.infohash))
                and str(r.get("state", "")).startswith("checking") else None), 10, .2)
        except drill.DrillError:
            pass
        else:
            self.recheck_state_observed = True
            wait("restored torrent recheck completion", lambda: (r if (r := self._torrent_row(self.qbit_source, self.infohash))
                and not str(r.get("state", "")).startswith("checking") else None), 90, .2)
            self.recheck_completion_observed = True
        # qBittorrent may complete the small check between polls. Retained inode/hash
        # and eventual full-source SHA remain the acceptance evidence; do not claim a
        # recheck transition that this probe did not observe.
        self.add_peer(self.qbit_source)
        self.qbit_source.call("torrents/setDownloadLimit", {"hashes": self.infohash, "limit": "0"})
        self.seed_qbit.call("torrents/setUploadLimit", {"hashes": self.infohash, "limit": "1048576"})
        current = self.api_json("GET", f"/api/v1/downloads/{self.request_id}", token=self.member_token)
        # Temporarily remove the inherited global cap for this bounded local transfer,
        # then restore the backed-up desired qBittorrent setting before finishing.
        self.qbit_source.call("transfer/setDownloadLimit", {"limit": "0"})
        resumed = self.api_json("POST", f"/api/v1/downloads/{self.request_id}/actions", token=self.member_token,
            body={"action": "resume", "version": current["version"]}, expected=202)
        resume_result = wait("restored resume operation", lambda: (op if (op := self.api_json("GET", f"/api/v1/operations/{resumed['id']}", token=self.member_token)).get("state") in ("completed", "failed") else None), 90)
        if resume_result.get("state") != "completed":
            raise drill.DrillError("restored resume operation did not complete")
        completion = wait("restored transfer completion", lambda: completed_file(
            self.api_json("GET", f"/api/v1/downloads/{self.request_id}/files", token=self.member_token),
            media["id"], media["sizeBytes"]), 210, .5)
        target = self.restore_data / self.payload_relative
        payload_hash = hashlib.sha256(target.read_bytes()).hexdigest()
        expected_hash = hashlib.sha256(self.fixture_payload).hexdigest()
        if target.stat().st_size != self.fixture_media.stat().st_size or payload_hash != expected_hash:
            raise drill.DrillError("restored download did not complete with the independent generated source bytes")
        self.qbit_source.call("transfer/setDownloadLimit", {"limit": "23456"})
        if int(self.qbit_source.call("transfer/downloadLimit").decode().strip()) != drill.qbit_limit_readback(23456):
            raise drill.DrillError("temporary transfer rate limit was not restored to its persisted admin setting")
        restored_key = hashlib.sha256((self.restore_state / "briani/secret.key").read_bytes()).hexdigest()
        source_key = hashlib.sha256((self.source_state / "briani/secret.key").read_bytes()).hexdigest()
        if restored_key != source_key:
            raise drill.DrillError("SecretStore key changed across full-stack restore")
        return {"requestId": self.request_id, "requestOwnerMemberId": self.member_id,
                "torrentJobId": saved["generation"].split(":", 1)[0], "sourceKind": "torrentUpload",
                "idempotencyKeyReturnedSameRequest": True, "grantRetained": True,
                "sourceProgressBeforeBackup": self.source_progress, "payloadFileSha256AtPause": self.partial_payload_sha256,
                "payloadInodeAtPause": self.partial_payload_inode,
                "payloadRestoredSeparately": False, "mediaRetained": True,
                "restoreMode": "configuration_over_retained_media",
                "recheckRequested": True, "recheckCheckingStateObserved": self.recheck_state_observed,
                "recheckCompletionObserved": self.recheck_completion_observed,
                "resumedToBytes": int(completion[0].get("downloadedBytes", 0)), "sourceSha256": expected_hash,
                "restoredSha256": payload_hash, "secretKeySha256": restored_key,
                "qBittorrentTorrentHash": self.infohash, "fixtureSeedIp": self.seed_ip,
                "publicAddressSimulationSubnet": self.network_subnet, "networkInternal": True}

    def backup_restore_rollback(self) -> None:
        raise drill.DrillError("use partial_restore after production request and pause")

    def cleanup_fixture(self) -> None:
        if self.seed_id:
            record = json.loads(docker("inspect", self.seed_id))[0]
            validate_seed_record(record, self.seed_id, self.run_id, self.seed_config, self.seed_data)
            docker("rm", "--force", self.seed_id)
            self.removed_fixture_container_ids.append(self.seed_id)
            self.seed_id = ""
        if self.network_id:
            network = json.loads(docker("network", "inspect", self.network_id))[0]
            if network.get("Labels") != {"org.briani.test": "M10-download-restore", "org.briani.owner": OWNER,
                                         "org.briani.run": self.run_id}:
                raise drill.DrillError("refusing to remove fixture network with unexpected ownership labels")
            for container_id in list((network.get("Containers") or {}).keys()):
                if container_id not in self.guard_ids:
                    raise drill.DrillError("fixture network is attached to an unexpected container")
                record = json.loads(docker("inspect", container_id))[0]
                project = drill.resource_labels(record).get("com.docker.compose.project")
                if not project or not drill.is_owned_container(record, project, self.root):
                    raise drill.DrillError("fixture network guard endpoint is not an owned drill container")
                docker("network", "disconnect", self.network_id, container_id)
            network = json.loads(docker("network", "inspect", self.network_id))[0]
            endpoints = network.get("Containers") or {}
            if endpoints:
                raise drill.DrillError("refusing to remove fixture network while it has attached containers")
            docker("network", "rm", self.network_id)
            self.removed_fixture_network_id = self.network_id
            self.network_id = ""

    def verified_cleanup(self) -> dict:
        project_resources: dict[str, dict[str, list[str]]] = {}
        for name in self.project_names.values():
            project_resources[name] = {kind: drill.docker_ids(kind, name)
                                       for kind in ("container", "network", "volume")}
        if any(ids for kinds in project_resources.values() for ids in kinds.values()):
            raise drill.DrillError("owned Compose project resources remain after cleanup")
        if self.seed_id or self.network_id:
            raise drill.DrillError("fixture resource handles remain after cleanup")
        for container_id in self.removed_fixture_container_ids:
            result = drill.run_readonly(["docker", "container", "inspect", container_id])
            if result.returncode == 0:
                raise drill.DrillError("exact fixture container ID remains after cleanup")
        if self.removed_fixture_network_id:
            result = drill.run_readonly(["docker", "network", "inspect", self.removed_fixture_network_id])
            if result.returncode == 0:
                raise drill.DrillError("exact fixture network ID remains after cleanup")
        if self.root.exists() or self.root.is_symlink():
            raise drill.DrillError("unique marked scratch root remains after cleanup")
        return {"composeProjectsChecked": project_resources,
                "fixtureContainerIdsRemoved": self.removed_fixture_container_ids,
                "fixtureNetworkIdRemoved": self.removed_fixture_network_id,
                "scratchRootRemoved": str(self.root), "verified": True}

    def run(self) -> dict:
        self.preflight()
        self.root.mkdir(mode=0o700)
        marker = self.root / "owner.marker"
        marker.write_text(f"{OWNER}:{self.run_id}\n", encoding="ascii")
        os.chmod(marker, 0o600)
        try:
            self.start_source()
            self.bootstrap_and_admin()
            self.create_library_grant()
            qbit_secret, prowlarr_secret = self.check_integrations()
            self._qbit_secret, self._prowlarr_secret = qbit_secret, prowlarr_secret
            self.update_admin_settings()
            self.update_user_preferences()
            self._active_project = self.source
            self.own_network_and_seed()
            self.member_token = self.login(self.creds["memberUsername"], self.creds["memberPassword"], "source member login")
            self.request_key = "m10-restore-" + self.run_id
            self.upload_id = self.upload_metainfo()
            created = self.api_json("POST", "/api/v1/downloads", token=self.member_token,
                body={"libraryId": self.library_id, "source": {"kind": "torrentUpload", "value": self.upload_id}},
                key=self.request_key, expected=202)
            self.request_id = created["id"]
            files, transfer = self.submit_selection()
            before = {"partialTransfer": transfer, "requestId": self.request_id,
                      "memberId": self.member_id, "requestIdempotencyKey": self.request_key,
                      "libraryId": self.library_id, "secretKeySha256": hashlib.sha256((self.source_state / "briani/secret.key").read_bytes()).hexdigest(),
                      "fileMetadataCount": len(files), "torrentInfoHash": self.infohash,
                      "sourceKind": "torrentUpload", "sourceUploadId": self.upload_id,
                      "magnetMetadataExchangeDiagnosticRun": "download-restore-diagnostic.json"}
            restored = self.partial_restore(transfer)
            self.failed = False
            return {"runId": self.run_id, "result": "passed", "image": self.server_image,
                    "qBittorrentImage": QBIT_IMAGE, "source": before, "restore": restored,
                    "cleanup": {"fixtureContainerIdsRemoved": self.removed_fixture_container_ids,
                                "fixtureNetworkIdRemoved": self.removed_fixture_network_id,
                                "scratchRoot": str(self.root), "ownerMarker": f"{OWNER}:{self.run_id}"}}
        except BaseException:
            self.failed = True
            raise
        finally:
            try:
                self.cleanup_fixture()
            finally:
                if not (self.failed and self.retain_on_failure):
                    before: dict[str, dict[str, list[str]]] = {}
                    for name in self.project_names.values():
                        before[name] = {kind: drill.docker_ids(kind, name)
                                        for kind in ("container", "network", "volume")}
                    self.cleanup()
                    self.cleanup_report = {"composeProjectResourceIdsBeforeCleanup": before,
                                           **self.verified_cleanup()}


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--retain-on-failure", action="store_true")
    args = parser.parse_args()
    if not args.output.is_absolute() or args.output.exists() or args.output.is_symlink():
        print(json.dumps({"result": "failed", "error": "output path must be new and absolute"}))
        return 2
    run_id = uuid.uuid4().hex[:16]
    root = Path("/tmp") / f"briani-m10-download-restore-{run_id}"
    result: dict = {"runId": run_id, "result": "failed", "startedUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    instance = DownloadRestoreDrill(root, run_id=run_id, retain_on_failure=args.retain_on_failure)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    os.environ["DOCKER_CONFIG"] = str(ROOT / ".tools/docker-config")
    drill.LOG_PATH = args.output.with_suffix(".log")
    if drill.LOG_PATH.exists() or drill.LOG_PATH.is_symlink():
        print(json.dumps({"result": "failed", "error": "evidence log path already exists"}))
        return 2
    log_fd = os.open(drill.LOG_PATH, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    os.close(log_fd)
    try:
        passed = instance.run()
        result.update(passed)
    except Exception as error:
        result["error"] = f"{type(error).__name__}: {str(error)[:1000]}"
        result["detail"] = "failure artifacts are retained only with --retain-on-failure; Docker cleanup is exact-label scoped"
        if instance.metadata_diagnostics:
            result["metadataDiagnostics"] = instance.metadata_diagnostics
    finally:
        if instance.cleanup_report:
            result["cleanupVerification"] = instance.cleanup_report
            if isinstance(result.get("cleanup"), dict):
                result["cleanup"].update({
                    "fixtureContainerIdsRemoved": instance.cleanup_report.get("fixtureContainerIdsRemoved", []),
                    "fixtureNetworkIdRemoved": instance.cleanup_report.get("fixtureNetworkIdRemoved", ""),
                    "verified": instance.cleanup_report.get("verified", False)})
        result["finishedUtc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"result": result.get("result"), "runId": result.get("runId"), "output": str(args.output), "error": result.get("error")}))
    return 0 if result.get("result") == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
