#!/usr/bin/env python3
"""Prove M05 durable admission/selection across Briani API container restarts.

All containers and network resources created by this runner carry an org.briani
test/run label. It publishes no host ports and refuses to remove unowned resources.
"""
from __future__ import annotations

import hashlib
import json
import os
import argparse
from pathlib import Path
from pathlib import PurePosixPath
import re
import shutil
import socket
import sqlite3
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[3]
QBIT_IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
DEFAULT_FIXTURES = ROOT / "prototypes/playback/fixtures/generated"
FIXTURES = DEFAULT_FIXTURES
TORRENT = FIXTURES / "torrents/Faststart café [test]-v1.torrent"
SOURCE = FIXTURES / "early-play-source/Faststart café [test].mp4"
TEMP_PASSWORD = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)


def docker(*args: str) -> str:
    result = subprocess.run(["docker", *args], check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(f"docker {args[0]} failed ({result.returncode}): {(result.stderr or '')[-1000:]}")
    return result.stdout.strip()


def labels(kind: str, name: str) -> dict[str, str]:
    if kind == "network":
        data = json.loads(docker("network", "inspect", name))[0]
        return data.get("Labels") or {}
    data = json.loads(docker("inspect", name))[0]
    return data.get("Config", {}).get("Labels") or {}


class Api:
    def __init__(self, origin: str):
        self.origin = origin.rstrip("/")
        self.token: str | None = None
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def request(self, path: str, body: object | None = None, *, method: str | None = None,
                headers: dict[str, str] | None = None, raw: bytes | None = None,
                content_type: str = "application/json") -> tuple[int, dict[str, str], bytes]:
        data = raw if raw is not None else (None if body is None else json.dumps(body).encode())
        head = {"Accept": "application/json", **(headers or {})}
        # The production image's AllowedHosts permits the service name, not a raw bridge IP.
        head.setdefault("Host", "briani")
        if data is not None:
            head.setdefault("Content-Type", content_type)
        if self.token:
            head["Authorization"] = "Bearer " + self.token
        req = urllib.request.Request(self.origin + path, data=data, headers=head, method=method)
        try:
            with self.opener.open(req, timeout=12) as response:
                return response.status, dict(response.headers), response.read()
        except urllib.error.HTTPError as error:
            return error.code, dict(error.headers), error.read()

    def json(self, path: str, body: object | None = None, **kw: object) -> object:
        status, _, payload = self.request(path, body, **kw)
        if status < 200 or status >= 300:
            raise RuntimeError(f"API {path} returned {status}: {payload[:500].decode(errors='replace')}")
        return json.loads(payload) if payload else None


class Qbit:
    def __init__(self, origin: str, username: str, password: str):
        self.origin, self.username, self.password = origin.rstrip("/"), username, password
        self.cookie = ""
        self.login()

    def call(self, path: str, fields: dict[str, str] | None = None) -> bytes:
        query = "" if not fields else "?" + urllib.parse.urlencode(fields)
        data = None if not fields else urllib.parse.urlencode(fields).encode()
        url = self.origin + "/api/v2/" + path + (query if path.endswith("/info") else "")
        if path.endswith("/info"):
            data = None
        request = urllib.request.Request(url, data=data,
                                        headers={"Cookie": self.cookie, "Origin": self.origin,
                                                 "Referer": self.origin + "/"} if self.cookie else {})
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=10) as response:
            return response.read()

    def login(self) -> None:
        data = urllib.parse.urlencode({"username": self.username, "password": self.password}).encode()
        request = urllib.request.Request(self.origin + "/api/v2/auth/login", data=data,
                                         headers={"Origin": self.origin, "Referer": self.origin + "/"})
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=8) as response:
            cookie = response.headers.get("Set-Cookie", "")
        sid = re.search(r"(?:SID|QBT_SID(?:_[^=;]+)?)=([^;]+)", cookie)
        if not sid:
            raise RuntimeError("qBittorrent login did not issue a session cookie")
        self.cookie = cookie.split(";", 1)[0]

    def json(self, path: str, fields: dict[str, str] | None = None) -> object:
        payload = self.call(path, fields)
        return json.loads(payload) if payload else None


def bdecode(data: bytes) -> object:
    def read(pos: int) -> tuple[object, int]:
        marker = data[pos:pos + 1]
        if marker == b"i":
            end = data.index(b"e", pos + 1)
            return int(data[pos + 1:end]), end + 1
        if marker == b"l":
            values = []
            pos += 1
            while data[pos:pos + 1] != b"e":
                value, pos = read(pos)
                values.append(value)
            return values, pos + 1
        if marker == b"d":
            values = {}
            pos += 1
            while data[pos:pos + 1] != b"e":
                key, pos = read(pos)
                value, pos = read(pos)
                values[key] = value
            return values, pos + 1
        colon = data.index(b":", pos)
        length = int(data[pos:colon])
        start = colon + 1
        return data[start:start + length], start + length
    value, end = read(0)
    if end != len(data):
        raise ValueError("trailing torrent bytes")
    return value


def bencode(value: object) -> bytes:
    if isinstance(value, int):
        return b"i" + str(value).encode("ascii") + b"e"
    if isinstance(value, bytes):
        return str(len(value)).encode("ascii") + b":" + value
    if isinstance(value, list):
        return b"l" + b"".join(bencode(item) for item in value) + b"e"
    if isinstance(value, dict):
        return b"d" + b"".join(bencode(key) + bencode(value[key]) for key in sorted(value)) + b"e"
    raise TypeError(type(value).__name__)


def wait_for(label: str, predicate, timeout: int = 90):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(.35)
    raise RuntimeError(f"timed out waiting for {label}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture-root", type=Path, default=Path(os.environ.get("BRIANI_DOWNLOAD_FIXTURE_ROOT", DEFAULT_FIXTURES)))
    parser.add_argument("--log", type=Path, default=None, help="optional copy of the final result JSON")
    parser.add_argument("--torrent", type=Path, default=None)
    parser.add_argument("--source", type=Path, default=None)
    parser.add_argument("--image", default="briani-server:m10")
    parser.add_argument("--fault-matrix", action="store_true", help="require the separately compiled BRIANI_FAULT_TEST image")
    args = parser.parse_args()
    global FIXTURES, TORRENT, SOURCE
    FIXTURES = args.fixture_root.expanduser().resolve()
    torrent_candidates = [FIXTURES / "torrents/Faststart café [test]-v1.torrent",
                         FIXTURES / "early-play/torrents/Fast-start-v1.torrent",
                         FIXTURES / "torrents/Fast-start-v1.torrent"]
    source_candidates = [FIXTURES / "early-play-source/Faststart café [test].mp4",
                         FIXTURES / "early-play/source/Fast-start.mp4",
                         FIXTURES / "early-play/source/Faststart café [test].mp4"]
    TORRENT = (args.torrent.expanduser() if args.torrent else next((x for x in torrent_candidates if x.is_file()), torrent_candidates[0]))
    SOURCE = (args.source.expanduser() if args.source else next((x for x in source_candidates if x.is_file()), source_candidates[0]))
    if not TORRENT.is_absolute():
        TORRENT = FIXTURES / TORRENT
    if not SOURCE.is_absolute():
        SOURCE = FIXTURES / SOURCE
    if not TORRENT.is_file() or not SOURCE.is_file():
        run_id = uuid.uuid4().hex
        run_dir = ROOT / "artifacts/download-lifecycle" / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        failure = {"result": "failed", "failure": "FixtureMissing", "runId": run_id,
                   "fixtureRoot": str(FIXTURES), "torrentPath": str(TORRENT), "sourcePath": str(SOURCE)}
        output_path = args.log or (run_dir / "result.json")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(failure, indent=2) + "\n")
        print(json.dumps({"result": "failed", "failure": "FixtureMissing", "log": str(output_path)}))
        return 1
    run_id = uuid.uuid4().hex
    short = run_id[:12]
    network = f"briani-m05-api-{short}"
    api_name = f"briani-m05-api-{short}"
    seeder_name = f"briani-m05-seeder-{short}"
    downloader_name = f"briani-m05-downloader-{short}"
    run_dir = ROOT / "artifacts/download-lifecycle" / run_id
    state, data, seed_config, seed_data, download_config = [run_dir / x for x in
        ("state", "data", "seed-config", "seed-data", "downloader-config")]
    for path in (state, data, seed_config, seed_data, download_config):
        path.mkdir(parents=True, exist_ok=True)
    state.chmod(0o700)
    seed_config.chmod(0o700)
    download_config.chmod(0o700)
    library_dir = data / "library"
    library_dir.mkdir()
    labels_common = {"org.briani.test": "M05", "org.briani.run": run_id}
    network_created = False
    container_names: list[str] = []
    administrator_password = uuid.uuid4().hex + "aA1!"
    api: Api | None = None
    crash_evidence = []

    def arm_boundary(name: str):
        (state / 'fault-test-boundary').write_text(name)
        (state / 'fault-test-boundary').chmod(0o600)

    def crash_boundary(name: str):
        nonlocal api, api_origin
        marker = state / 'fault-test-reached'
        wait_for('exact OS-kill boundary '+name, marker.is_file, timeout=300)
        observation = json.loads(marker.read_text())
        if observation.get('boundary') != name: raise RuntimeError('fault boundary marker mismatch')
        identity=json.loads(docker('inspect',api_name))[0]
        if identity['Config'].get('Labels',{}).get('org.briani.run') != run_id:raise RuntimeError('crash target ownership mismatch')
        docker('kill','--signal','KILL',identity['Id'])
        exit_code=int(docker('inspect','--format','{{.State.ExitCode}}',identity['Id']))
        if exit_code != 137:raise RuntimeError('fault process did not die from SIGKILL')
        docker('rm',identity['Id']);container_names.remove(api_name)
        (state/'fault-test-boundary').unlink();marker.unlink()
        api,api_origin=api_start()
        auth=api.json('/api/v1/auth/login',{'username':'m05-admin','password':administrator_password,'deviceName':'Exact-boundary recovery'})
        api.token=auth['accessToken']
        crash_evidence.append({'boundary':name,'signal':'SIGKILL','exitCode':exit_code,'markerProcessId':observation['processId']})

    def create_qbit(name: str, role: str, config: Path, payload: Path) -> tuple[str, str]:
        config.mkdir(exist_ok=True)
        docker("run", "--detach", "--name", name, "--network", network,
               "--label", "org.briani.test=M05", "--label", f"org.briani.run={run_id}", "--label", f"org.briani.role={role}",
               "-e", f"PUID={os.getuid()}", "-e", f"PGID={os.getgid()}", "-e", "WEBUI_PORT=8080", "-e", "TORRENTING_PORT=6881",
               "-v", f"{config}:/config", "-v", f"{payload}:/data", QBIT_IMAGE)
        container_names.append(name)
        password = None
        for _ in range(60):
            logs = docker("logs", name)
            match = TEMP_PASSWORD.search(logs)
            if match:
                password = match.group(1)
            if password and "8080" in logs:
                break
            time.sleep(1)
        if password is None:
            raise RuntimeError(f"owned {role} qBittorrent did not expose its one-time initial password")
        network_info = json.loads(docker("inspect", name))[0]["NetworkSettings"]["Networks"][network]
        address = network_info.get("IPAddress")
        if not address:
            raise RuntimeError(f"owned {role} qBittorrent has no private bridge address")
        wait_for(f"{role} qBittorrent API", lambda: _qbit_ready(address))
        return address, password

    def api_start() -> tuple[Api, str]:
        docker("run", "--detach", "--name", api_name, "--network", network,
               "--label", "org.briani.test=M05", "--label", f"org.briani.run={run_id}", "--label", "org.briani.role=api",
               "--read-only", "--cap-drop=ALL", "--security-opt=no-new-privileges", "--pids-limit=256", "--memory=1g", "--cpus=2",
               "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m", "-e", "ASPNETCORE_URLS=http://0.0.0.0:8088",
               "-v", f"{data}:/data", "-v", f"{state}:/config", args.image)
        container_names.append(api_name)
        address = json.loads(docker("inspect", api_name))[0]["NetworkSettings"]["Networks"][network]["IPAddress"]
        base = f"http://{address}:8088"
        client = Api(base)
        try:
            status, _, body = client.request("/readyz")
            first_probe = f"HTTP {status}: {body[:300]!r}"
            if status == 200:
                return client, base
            if status not in (404, 503):
                raise RuntimeError(f"initial API readiness probe returned {first_probe}")
        except OSError as error:
            first_probe = f"socket {type(error).__name__}: {error}"
        try:
            wait_for("Briani ready", lambda: _api_ready(client), timeout=150)
        except Exception as error:
            details = re.sub(r"(?im)^.*(?:bootstrap|password|secret|token|credential).*$", "[redacted startup diagnostic]",
                             docker("logs", api_name))[-4000:]
            state_info = docker("inspect", "--format", "{{json .State}}", api_name)
            addresses = docker("inspect", "--format", "{{json .NetworkSettings.Networks}}", api_name)
            listeners = docker("exec", api_name, "sh", "-c", "cat /proc/net/tcp /proc/net/tcp6")[-4000:]
            helper_tools = docker("exec", seeder_name, "sh", "-c", "command -v curl; command -v wget")
            raise RuntimeError(f"Briani container readiness failed; firstProbe={first_probe}; state={state_info}; addresses={addresses}; helperTools={helper_tools}; tcpTables={listeners}; sanitized logs:\n{details}") from error
        return client, base

    try:
        docker("network", "create", "--internal", "--label", "org.briani.test=M05", "--label", f"org.briani.run={run_id}", network)
        network_created = True
        parsed = bdecode(TORRENT.read_bytes())
        if not isinstance(parsed, dict) or not isinstance(parsed.get(b"info"), dict):
            raise RuntimeError("checked-in generated metainfo did not have a valid root/info dictionary")
        for key in (b"announce", b"announce-list", b"url-list", b"httpseeds", b"nodes"):
            parsed.pop(key, None)
        prepared_torrent = run_dir / TORRENT.name
        prepared_torrent.write_bytes(bencode(parsed))
        root_name = parsed[b"info"][b"name"].decode("utf-8")
        seed_root = seed_data / root_name
        seed_root.mkdir()
        shutil.copyfile(SOURCE, seed_root / SOURCE.name)
        (seed_root / SOURCE.name).chmod(0o644)
        network_labels = labels("network", network)
        if network_labels.get("org.briani.run") != run_id or network_labels.get("org.briani.test") != "M05":
            raise RuntimeError("test network labels did not verify")
        seed_ip, seed_pw = create_qbit(seeder_name, "seeder", seed_config, seed_data)
        down_ip, down_pw = create_qbit(downloader_name, "downloader", download_config, data)
        seed_qb = Qbit(f"http://{seed_ip}:8080", "admin", seed_pw)
        down_qb = Qbit(f"http://{down_ip}:8080", "admin", down_pw)
        # The seeder gets the generated metainfo copied into its watched input via URL-free upload.
        boundary = "----briani" + uuid.uuid4().hex
        torrent_bytes = prepared_torrent.read_bytes()
        part = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"savepath\"\r\n\r\n/data\r\n"
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"paused\"\r\n\r\nfalse\r\n"
                f"--{boundary}\r\nContent-Disposition: form-data; name=\"torrents\"; filename=\"fixture.torrent\"\r\n"
                "Content-Type: application/x-bittorrent\r\n\r\n").encode() + torrent_bytes + f"\r\n--{boundary}--\r\n".encode()
        req = urllib.request.Request(f"http://{seed_ip}:8080/api/v2/torrents/add", data=part,
                                     headers={"Content-Type": f"multipart/form-data; boundary={boundary}", "Cookie": seed_qb.cookie})
        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(req, timeout=15) as response:
            if response.status != 200:
                raise RuntimeError("seeder rejected the generated fixture torrent")
        # Resolve the real infohash from the seeder's returned torrent list, never infer it from a name.
        seed_rows = wait_for("seed torrent registration", lambda: (rows if len(rows := seed_qb.json("torrents/info")) == 1 else None))
        seed_row = seed_rows[0]
        torrent_hash = seed_row["hash"]
        seed_qb.call("torrents/start", {"hashes": torrent_hash})
        api, api_origin = api_start()
        bootstrap_code = (state / "bootstrap.code").read_text().strip()
        auth = api.json("/api/v1/bootstrap", {"code": bootstrap_code, "username": "m05-admin", "displayName": "M05 API Proof", "password": administrator_password, "confirmPassword": administrator_password})
        api.token = auth["accessToken"]
        roots = api.json("/api/v1/admin/storage")
        root_id = roots[0]["id"]
        library = api.json("/api/v1/libraries", {"name": "Lifecycle generated fixture", "description": "", "storageRootId": root_id, "relativePath": "library", "readOnly": False})
        connection = api.json("/api/v1/admin/integrations/qbittorrent", {"baseUrl": f"http://{downloader_name}:8080/", "version": 1, "username": "admin", "secret": down_pw}, method="PUT")
        if not connection.get("credentialConfigured"):
            raise RuntimeError("API did not confirm a persisted private qBittorrent credential")
        # Upload is an authorized production route; the imported source is the checked-in synthetic fixture.
        boundary = "----briani" + uuid.uuid4().hex
        part = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"fixture.torrent\"\r\n"
                "Content-Type: application/x-bittorrent\r\n\r\n").encode() + prepared_torrent.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
        upload = api.json("/api/v1/torrent-uploads", raw=part, content_type=f"multipart/form-data; boundary={boundary}")
        if args.fault_matrix:arm_boundary('download:after_add')
        created = api.json("/api/v1/downloads", {"libraryId": library["id"], "source": {"kind": "torrentUpload", "value": str(upload["id"])}})
        request_id = created["id"]
        if args.fault_matrix:crash_boundary('download:after_add')
        file_rows = wait_for("download metadata", lambda: _files(api, request_id), timeout=150)
        media = next((f for f in file_rows if f.get("kind") == "video" and f.get("sizeBytes") == SOURCE.stat().st_size), None)
        if media is None:
            raise RuntimeError("production metadata did not expose the generated MP4 by size and media kind")
        before_selection = down_qb.json("torrents/info", {"hashes": torrent_hash})
        if not before_selection or int(before_selection[0].get("downloaded", 0)) != 0 or any(int(f.get("downloadedBytes", 0)) != 0 for f in file_rows):
            raise RuntimeError("payload bytes were transferred before the user selected a file")
        initial = api.json(f"/api/v1/downloads/{request_id}")
        download_id = initial["id"]
        if download_id != request_id:
            raise RuntimeError("request ID changed between admission and query")
        # Restart after add/metadata is durably represented by the returned stable request ID.
        docker("kill", api_name)
        docker("rm", api_name)
        container_names.remove(api_name)
        api, api_origin = api_start()
        login = api.json("/api/v1/auth/login", {"username": "m05-admin", "password": administrator_password, "deviceName": "M05 restart harness"})
        api.token = login["accessToken"]
        recovered = api.json(f"/api/v1/downloads/{request_id}")
        if recovered["id"] != download_id:
            raise RuntimeError("download request identity did not survive the first API restart")
        page = api.json("/api/v1/downloads?pageSize=200")
        matching = [x for x in page["items"] if x["id"] == request_id]
        if len(matching) != 1:
            raise RuntimeError("restart recovery produced a missing or duplicate download request")
        files = _files(api, request_id)
        selected_file = next((f for f in files if f["id"] == media["id"]), None)
        if selected_file is None:
            raise RuntimeError("metadata file ID did not survive API restart")
        if args.fault_matrix:arm_boundary('import:link_applied')
        selection = {"files": [{"fileId": f["id"], "selected": f["id"] == selected_file["id"], "priority": "normal"} for f in files],
                     "autoStart": True, "version": recovered["version"]}
        status, response_headers, response_body = api.request(f"/api/v1/downloads/{request_id}/selection", selection,
                                                               method="PUT", headers={"Content-Type": "application/json"})
        if status != 202:
            raise RuntimeError(f"production selection did not return HTTP 202: {status} {response_body[:500]!r}")
        operation_location = response_headers.get("Location")
        operation_id = operation_location.rsplit("/", 1)[-1] if operation_location else None
        # Crash immediately after accepted selection to exercise durable operation recovery.
        docker("kill", api_name)
        docker("rm", api_name)
        container_names.remove(api_name)
        api, api_origin = api_start()
        login = api.json("/api/v1/auth/login", {"username": "m05-admin", "password": administrator_password, "deviceName": "M05 selection recovery"})
        api.token = login["accessToken"]
        recovered = api.json(f"/api/v1/downloads/{request_id}")
        if recovered["id"] != download_id:
            raise RuntimeError("download ID changed after accepted selection restart")
        if operation_id:
            operation = wait_for("selection operation recovery", lambda: _operation_completed(api, operation_id), timeout=180)
            if operation.get("state") != "completed":
                raise RuntimeError("selection operation reached a failed state after process restart")
        else:
            wait_for("selection recovery", lambda: _download_selected(api, request_id), timeout=120)
        # The only peer is the sibling seeder on this internal Docker bridge.
        down_qb.call("torrents/addPeers", {"hashes": torrent_hash, "peers": f"{seed_ip}:6881"})
        if args.fault_matrix:crash_boundary('import:link_applied')
        final_files = wait_for("selected media transfer and hard-link import",
            lambda: _imported_file(api, request_id, selected_file["id"]), timeout=300)
        thumbnail = wait_for("imported media thumbnail", lambda: _thumbnail(api, final_files["importedMediaId"]), timeout=180)
        thumb_headers, thumb_bytes = thumbnail
        if thumb_headers.get("Content-Type", "").split(";", 1)[0].lower() != "image/jpeg" or len(thumb_bytes) > 524288 or not thumb_bytes.startswith(b"\xff\xd8") or not thumb_bytes.endswith(b"\xff\xd9"):
            raise RuntimeError("authorized imported thumbnail response was not a bounded JPEG")
        job_id_prefix = recovered["generation"].split(":", 1)[0][:8]
        relative = PurePosixPath(final_files["relativePath"])
        if relative.is_absolute() or ".." in relative.parts:
            raise RuntimeError("API returned an unsafe download-relative file name")
        selected_path = library_dir / "Downloads" / f"{recovered['name']}--{job_id_prefix}" / Path(*relative.parts)
        if not selected_path.is_file() or selected_path.stat().st_size != SOURCE.stat().st_size:
            raise RuntimeError("imported visible file is absent or has an unexpected length")
        if hashlib.sha256(selected_path.read_bytes()).hexdigest() != hashlib.sha256(SOURCE.read_bytes()).hexdigest():
            raise RuntimeError("imported visible file does not match the generated source hash")
        torrent_rows = down_qb.json("torrents/info", {"hashes": torrent_hash})
        if not torrent_rows:
            raise RuntimeError("torrent disappeared from the engine after selection restart")
        engine_row = torrent_rows[0]
        if engine_row.get("state") not in ("uploading", "stalledUP", "queuedUP", "forcedUP"):
            raise RuntimeError(f"completed download is not retained in an engine seeding state: {engine_row.get('state')!r}")
        content_path = PurePosixPath(engine_row.get("content_path") or "")
        if content_path.is_absolute():
            try:
                content_path = content_path.relative_to("/data")
            except ValueError as error:
                raise RuntimeError("engine returned a payload path outside the shared /data mount") from error
        engine_path = data.joinpath(*content_path.parts)
        if engine_path.is_dir():
            engine_path /= SOURCE.name
        try:
            source_stat, imported_stat = engine_path.stat(), selected_path.stat()
        except OSError as error:
            raise RuntimeError("engine payload path was not visible under the shared data mount") from error
        if (source_stat.st_dev, source_stat.st_ino) != (imported_stat.st_dev, imported_stat.st_ino):
            raise RuntimeError("visible import is not a hard link to the still-seeding engine payload")
        seed_rows = seed_qb.json("torrents/info", {"hashes": torrent_hash})
        if not seed_rows:
            raise RuntimeError("isolated source seeder no longer has the fixture torrent")
        if args.fault_matrix:
            arm_boundary('download:engine_removed')
            current=api.json(f'/api/v1/downloads/{request_id}')
            removal=api.json(f'/api/v1/downloads/{request_id}/actions',{'action':'remove','deleteData':False,'version':current['version']})
            crash_boundary('download:engine_removed')
            removed=wait_for('removal reconciled',lambda:_operation_completed(api,removal['id']),timeout=120)
            if removed['state']!='completed':raise RuntimeError('durable removal operation failed after crash')
            if api.json(f'/api/v1/downloads/{request_id}')['state']!='removed':raise RuntimeError('removed request did not report its tombstone after crash')
            with sqlite3.connect('file:'+str(state/'briani.db')+'?mode=ro',uri=True) as db:
                persisted=db.execute('SELECT State, RemovedAt FROM download_requests WHERE lower(Id)=?',(request_id.lower(),)).fetchone()
            if persisted is None or persisted[0]!='removed' or persisted[1] is None:raise RuntimeError('durable request retirement was not persisted')
            if down_qb.json('torrents/info',{'hashes':torrent_hash}):raise RuntimeError('removed engine job survived recovery')
            if hashlib.sha256(selected_path.read_bytes()).hexdigest()!=hashlib.sha256(SOURCE.read_bytes()).hexdigest():raise RuntimeError('crash removal changed retained imported bytes')
        report = {"passed": True, "runId": run_id, "network": network, "fixtureRoot": str(FIXTURES), "containerImageId": docker("inspect", "--format", "{{.Image}}", api_name),
                  "apiRestarts": 2+len(crash_evidence), "exactBoundaryCrashes":crash_evidence, "retainedAfterRemoval":bool(crash_evidence), "requestId": request_id, "selectionOperationId": operation_id,
                  "torrentHash": torrent_hash, "fixture": str(TORRENT.relative_to(ROOT)), "trackerlessTorrentSha256": hashlib.sha256(prepared_torrent.read_bytes()).hexdigest(),
                  "fixtureSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "sizeBytes": SOURCE.stat().st_size,
                  "selectedFileId": selected_file["id"], "selectedComplete": final_files["playbackState"],
                  "thumbnailBytes": len(thumb_bytes), "thumbnailMimeType": thumb_headers.get("Content-Type"),
                  "hardLinkSameDeviceInode": True, "visibleSha256Matches": True,
                  "engineState": engine_row.get("state"), "seedStillRegistered": True,
                  "qBittorrentVersion": seed_qb.call("app/version").decode("utf-8", "replace"), "externalTrackerOrPeer": False,
                  "networkPublishedPorts": json.loads(docker("inspect", "--format", "{{json .NetworkSettings.Ports}}", api_name))}
        (run_dir / "result.json").write_text(json.dumps(report, indent=2) + "\n")
        if args.log:
            args.log.parent.mkdir(parents=True, exist_ok=True)
            args.log.write_text(json.dumps(report, indent=2) + "\n")
        print("PASS production API admission/selection restart recovery, selected bytes, hard-link identity, and retained isolated seed")
        print(f"Evidence: {run_dir.relative_to(ROOT)}")
        return 0
    except Exception as error:
        failure = {"result": "failed", "failure": type(error).__name__, "runId": run_id, "fixtureRoot": str(FIXTURES)}
        (run_dir / "result.json").write_text(json.dumps(failure, indent=2) + "\n")
        if args.log:
            args.log.parent.mkdir(parents=True, exist_ok=True)
            args.log.write_text(json.dumps(failure, indent=2) + "\n")
        raise
    finally:
        expected = {"org.briani.test": "M05", "org.briani.run": run_id}
        for name in reversed(container_names):
            try:
                if all(labels("container", name).get(k) == v for k, v in expected.items()):
                    docker("rm", "--force", name)
            except Exception:
                pass
        if network_created:
            try:
                if all(labels("network", network).get(k) == v for k, v in expected.items()):
                    docker("network", "rm", network)
            except Exception:
                pass


def _qbit_ready(address: str) -> bool:
    try:
        with socket.create_connection((address, 8080), timeout=1):
            return True
    except OSError:
        return False


def _api_ready(api: Api) -> bool:
    try:
        return api.request("/readyz")[0] == 200
    except Exception:
        return False


def _files(api: Api, request_id: str):
    status, _, payload = api.request(f"/api/v1/downloads/{request_id}/files")
    if status != 200:
        return None
    value = json.loads(payload)
    return value.get("items", value) if isinstance(value, dict) else value


def _operation_completed(api: Api, operation_id: str):
    try:
        value = api.json(f"/api/v1/operations/{operation_id}")
        return value if value.get("state") in ("completed", "failed") else None
    except Exception:
        return None


def _download_selected(api: Api, request_id: str):
    try:
        value = api.json(f"/api/v1/downloads/{request_id}")
        return value if value.get("state") not in ("metadataPending", "awaitingSelection") else None
    except Exception:
        return None


def _imported_file(api: Api, request_id: str, file_id: str):
    try:
        files = _files(api, request_id)
        row = next((f for f in files if f["id"] == file_id), None)
        return row if row and row.get("importedMediaId") and row.get("playbackState") == "complete" else None
    except Exception:
        return None


def _thumbnail(api: Api, media_id: str):
    try:
        status, headers, payload = api.request(f"/api/v1/media/{media_id}/thumbnail")
        return (headers, payload) if status == 200 else None
    except Exception:
        return None


if __name__ == "__main__":
    raise SystemExit(main())
