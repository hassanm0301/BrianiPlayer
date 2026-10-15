#!/usr/bin/env python3
"""Bounded M06 real-engine byte/layout matrix for v1, v2, and hybrid torrents."""
from __future__ import annotations

from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path, PurePosixPath
import queue
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.parse
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[3]
PRODUCTION = Path(__file__).resolve().parent
sys.path.insert(0, str(PRODUCTION))
import run_api_playback as common  # read-only shared setup/API helpers

FIXTURE_MODULE = ROOT / "prototypes/playback/fixtures/generate.py"
FIXTURE_SOURCE = PRODUCTION / "artifacts/d0b1013aa38d42419655d7d8a1056b9a/fixtures/early-play-source/Faststart café [test].mp4"
FALLBACK_SOURCE = ROOT / "prototypes/playback/fixtures/generated/early-play-source/Faststart café [test].mp4"
QBIT_IMAGE = common.QBIT_IMAGE
API_IMAGE = common.API_IMAGE
PREFIX = 16 * 1024 * 1024
RATE_LIMIT = 256 * 1024
TRACKER_KEYS = (b"announce", b"announce-list", b"url-list", b"httpseeds", b"nodes")


def safe_error(error: BaseException) -> str:
    value = re.sub(r"https?://[^\s'\"]+", "[redacted-url]", str(error))
    return re.sub(r"(?i)bearer\s+\S+", "Bearer [redacted]", value)[:800]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def inspect_generated_mp4(path: Path) -> dict:
    result = subprocess.run(["ffprobe", "-v", "error", "-show_entries",
        "format=format_name,duration,size:stream=codec_name,codec_type", "-of", "json", str(path)],
        check=True, capture_output=True, text=True, timeout=20)
    metadata = json.loads(result.stdout)
    duration = float(metadata["format"]["duration"])
    if not 119 <= duration <= 121 or "mp4" not in metadata["format"]["format_name"]:
        raise RuntimeError("layout fixture is not the generated 120-second MP4 baseline")
    if not any(stream.get("codec_type") == "video" and stream.get("codec_name") == "h264"
               for stream in metadata.get("streams", [])):
        raise RuntimeError("layout fixture lacks generated H.264 video")
    return {"durationSeconds": duration, "format": metadata["format"]["format_name"],
            "sizeBytes": int(metadata["format"]["size"]),
            "streams": metadata.get("streams", [])}


def independent_payload(path: Path, length: int, seed: int) -> None:
    block = bytes(((i * 73 + seed * 19) % 251) + 1 for i in range(65536))
    with path.open("wb") as output:
        remaining = length
        while remaining:
            part = block[:min(remaining, len(block))]
            output.write(part)
            remaining -= len(part)


def no_trackers(torrent: Path, destination: Path) -> Path:
    data = common.bdecode(torrent.read_bytes())
    for key in TRACKER_KEYS:
        data.pop(key, None)
    destination.write_bytes(common.bencode(data))
    return destination


def hashes_for(torrent: Path) -> set[str]:
    import libtorrent as lt
    info = lt.torrent_info(torrent.read_bytes()).info_hashes()
    return {str(item) for item in (info.v1, info.v2, info.get_best()) if str(item).strip("0")}


def torrent_name(torrent: Path) -> str:
    value = common.bdecode(torrent.read_bytes())[b"info"][b"name"]
    return value.decode("utf-8")


def expected_files(oracle: dict) -> list[dict]:
    return [dict(item, metadata_index=index) for index, item in enumerate(oracle["files"])
            if not item.get("padding", False)]


def engine_mapping(torrent: Path, oracle: dict, qbit: common.Qbit, torrent_hash: str) -> list[dict]:
    engine_rows = qbit.json("torrents/files", {"hash": torrent_hash})
    expected = oracle["files"]
    mapping = []
    used: set[int] = set()
    for metadata_index, item in enumerate(expected):
        expected_path = item["path"].replace("\\", "/")
        candidates = []
        for row in engine_rows:
            row_path = str(row.get("name", "")).replace("\\", "/")
            if (row.get("size") == item["length"] and
                (row_path == expected_path or row_path.endswith("/" + expected_path))):
                candidates.append(row)
        if item.get("padding", False) and not candidates:
            mapping.append({"metadataIndex": metadata_index, "path": expected_path,
                            "padding": True, "torrentOffset": item["torrent_offset"],
                            "pieceRange": [item["first_piece"], item["last_piece"]],
                            "upstreamIndex": None, "enginePadEntryExposed": False})
            continue
        row = next((entry for entry in candidates if int(entry["index"]) not in used), None)
        if row is None:
            raise RuntimeError(f"engine file map did not match metadata entry {metadata_index}")
        used.add(int(row["index"]))
        actual_range = row.get("piece_range")
        expected_range = [item["first_piece"], item["last_piece"]]
        if actual_range is not None and actual_range != expected_range:
            raise RuntimeError(f"engine piece range differed from native torrent layout at metadata index {metadata_index}")
        mapping.append({"metadataIndex": metadata_index, "path": expected_path,
                        "padding": bool(item.get("padding", False)),
                        "torrentOffset": item["torrent_offset"], "pieceRange": expected_range,
                        "upstreamIndex": int(row["index"]), "enginePadEntryExposed": bool(item.get("padding", False))})
    return mapping


def api_stream_url(api_origin: str, returned_url: str) -> str:
    parts = urllib.parse.urlsplit(returned_url)
    transport = urllib.parse.urlsplit(api_origin)
    return urllib.parse.urlunsplit((transport.scheme, transport.netloc, parts.path, parts.query, ""))


def request_range(url: str, start: int, end: int, timeout: float = 8) -> tuple[int, dict, bytes]:
    parts = urllib.parse.urlsplit(url)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    request = urllib.request.Request(url, headers={"Host": f"briani:{parts.port or 80}",
        "Range": f"bytes={start}-{end}", "Accept-Encoding": "identity"})
    try:
        with opener.open(request, timeout=timeout) as response:
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers), error.read()


def verify_range(url: str, source: Path, start: int, end: int) -> dict:
    status, headers, body = request_range(url, start, end)
    with source.open("rb") as oracle:
        oracle.seek(start)
        expected = oracle.read(end - start + 1)
    if status != 206 or body != expected or int(headers.get("Content-Length", -1)) != len(expected):
        raise RuntimeError(f"range {start}-{end} differed from independent source bytes")
    wanted_range = f"bytes {start}-{end}/{source.stat().st_size}"
    if headers.get("Content-Range") != wanted_range:
        raise RuntimeError("range Content-Range did not describe the exact source interval")
    return {"range": [start, end], "status": status, "byteCount": len(body),
            "sha256": hashlib.sha256(body).hexdigest()}


def verify_ticket_invalidated(status: int, headers: dict, body: bytes, context: str) -> dict:
    """Require an explicit problem response and reject any success-shaped media response."""
    content_type = str(headers.get("Content-Type", "")).split(";", 1)[0].strip().lower()
    if status not in (404, 409):
        raise RuntimeError(f"{context} old playback ticket returned HTTP {status}, expected 404 or 409")
    if content_type != "application/problem+json":
        raise RuntimeError(f"{context} invalid ticket response was not application/problem+json")
    try:
        problem = json.loads(body)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError(f"{context} invalid ticket response was not a JSON problem") from error
    code = problem.get("code") if isinstance(problem, dict) else None
    if code not in ("not_found", "generation_changed"):
        raise RuntimeError(f"{context} invalid ticket problem code was unexpected")
    if problem.get("status") != status:
        raise RuntimeError(f"{context} invalid ticket problem status did not match HTTP status")
    if headers.get("Content-Range") or headers.get("Accept-Ranges"):
        raise RuntimeError(f"{context} invalid ticket response advertised media range data")
    return {"status": status, "problemCode": code, "problemContentType": content_type,
            "problemBodyBytes": len(body), "mediaBodyBytes": 0}


def assert_missing_wait(url: str, offset: int) -> dict:
    parts = urllib.parse.urlsplit(url)
    connection = http.client.HTTPConnection(parts.hostname, parts.port or 80, timeout=1.0)
    connection.putrequest("GET", parts.path + (("?" + parts.query) if parts.query else ""),
                          skip_host=True, skip_accept_encoding=True)
    connection.putheader("Host", f"briani:{parts.port or 80}")
    connection.putheader("Range", f"bytes={offset}-{offset + 1023}")
    connection.putheader("Connection", "close")
    connection.endheaders()
    started = time.monotonic()
    try:
        response = connection.getresponse()
        payload = response.read(1)
        raise RuntimeError(f"missing range returned HTTP {response.status} and {len(payload)} body bytes")
    except (socket.timeout, TimeoutError):
        return {"rangeStart": offset, "waitedForMissingData": True,
                "cancelElapsedSeconds": round(time.monotonic() - started, 3),
                "returnedBodyBytes": 0}
    finally:
        connection.close()


def restart_during_missing_read(url: str, source: Path, start: int,
                               restart_container: str) -> dict:
    """Prove an already-started range cannot turn an engine restart into zero bytes."""
    parts = urllib.parse.urlsplit(url)
    connection = http.client.HTTPConnection(parts.hostname, parts.port or 80, timeout=25)
    connection.putrequest("GET", parts.path + (("?" + parts.query) if parts.query else ""),
                          skip_host=True, skip_accept_encoding=True)
    connection.putheader("Host", f"briani:{parts.port or 80}")
    connection.putheader("Range", f"bytes={start}-{start + 65535}")
    connection.putheader("Connection", "keep-alive")
    connection.endheaders()
    response = connection.getresponse()
    if response.status != 206:
        connection.close()
        raise RuntimeError(f"restart reader did not receive partial response headers ({response.status})")
    with source.open("rb") as oracle:
        oracle.seek(start)
        expected_prefix = oracle.read(1024)
    observed_prefix = response.read(len(expected_prefix))
    if len(expected_prefix) != 1024 or observed_prefix != expected_prefix:
        connection.close()
        raise RuntimeError("restart reader's known available prefix differed from source bytes")

    outcome: queue.Queue = queue.Queue(maxsize=1)
    def read_at_gap():
        try:
            outcome.put(("bytes", response.read(1)))
        except BaseException as error:
            outcome.put(("error", type(error).__name__))

    reader = __import__("threading").Thread(target=read_at_gap, daemon=True)
    reader.start()
    time.sleep(0.35)
    if not outcome.empty():
        connection.close()
        kind, payload = outcome.get_nowait()
        if kind == "bytes" and payload:
            raise RuntimeError("missing-range reader received bytes before downloader restart")
        raise RuntimeError("missing-range reader terminated before downloader restart could exercise it")
    completed = subprocess.run(["docker", "restart", "--time", "5", restart_container],
        check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
    if completed.returncode:
        connection.close()
        raise RuntimeError(f"owned downloader restart failed ({completed.returncode}): {safe_error(RuntimeError(completed.stderr[-500:]))}")
    try:
        kind, payload = outcome.get(timeout=12)
    except queue.Empty:
        connection.close()
        reader.join(timeout=1)
        raise RuntimeError("missing-range reader did not terminate promptly after downloader restart")
    finally:
        connection.close()
    reader.join(timeout=1)
    if reader.is_alive():
        raise RuntimeError("missing-range reader remained blocked after downloader restart")
    if kind == "bytes" and payload:
        raise RuntimeError("missing-range reader returned success-shaped data after downloader restart")
    return {"headersStatus": response.status, "knownPrefixBytes": len(observed_prefix),
            "knownPrefixSha256": hashlib.sha256(observed_prefix).hexdigest(),
            "readerTerminatedAfterRestart": True,
            "readerOutcome": "eof" if kind == "bytes" else "connection-error",
            "readerBodyBytesAtGap": len(payload) if kind == "bytes" else 0}


def downloader_media_stat(container: str, save_path: str, relative_path: str) -> dict:
    # Stat through the exact owned downloader's /data mount and this torrent's
    # engine-reported save path; earlier layout cases can contain the same name.
    prefix = "/data/library/.briani/staging/"
    if not save_path.startswith(prefix) or not re.fullmatch(r"[0-9a-f]{32}", save_path[len(prefix):]):
        raise RuntimeError("owned downloader returned an unexpected staging save path")
    relative = PurePosixPath(relative_path)
    if relative.is_absolute() or not relative.parts or any(part in ("", ".", "..") for part in relative.parts):
        raise RuntimeError("selected media path was not a safe relative layout path")
    media_path = save_path.rstrip("/") + "/" + relative.as_posix()
    stat_output = common.docker("exec", container, "stat", "-c", "%s %b", media_path).split()
    if len(stat_output) != 2:
        raise RuntimeError("owned downloader returned an invalid media file stat")
    return {"pathWithinOwnedData": media_path[len("/data/"):],
            "logicalFileLengthBytes": int(stat_output[0]),
            "allocatedBlockBytes": int(stat_output[1]) * 512}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, default=PRODUCTION / "artifacts")
    parser.add_argument("--timeout", type=int, default=120, help="maximum wait for prefix, 1 to 180 seconds")
    parser.add_argument("--preflight-only", action="store_true")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 180:
        parser.error("--timeout must be between 1 and 180 seconds")

    run_id = uuid.uuid4().hex
    run_dir = args.artifacts.expanduser().resolve() / ("layout-" + run_id)
    run_dir.mkdir(parents=True, mode=0o700)
    run_dir.chmod(0o700)
    result_path = run_dir / "result.json"
    if args.preflight_only:
        try:
            common.docker("image", "inspect", API_IMAGE)
            common.docker("image", "inspect", QBIT_IMAGE)
            import libtorrent as lt
            result = {"result": "preflight_passed", "runId": run_id,
                      "apiImage": API_IMAGE, "qbitImage": QBIT_IMAGE,
                      "libtorrentPython": getattr(lt, "__version__", "unknown")}
            result_path.write_text(json.dumps(result, indent=2) + "\n")
            print(json.dumps({"result": result["result"], "artifact": str(result_path)}))
            return 0
        except Exception as error:
            result_path.write_text(json.dumps({"result": "preflight_failed", "runId": run_id,
                "failure": type(error).__name__, "detail": safe_error(error)}, indent=2) + "\n")
            print(json.dumps({"result": "preflight_failed", "artifact": str(result_path)}))
            return 2

    state, data, seed_config, seed_data, down_config = [run_dir / name for name in
        ("state", "data", "seed-config", "seed-data", "down-config")]
    for directory in (state, data, seed_config, seed_data, down_config):
        directory.mkdir(mode=0o700)
        directory.chmod(0o700)
    (data / "library").mkdir()
    short = run_id[:12]
    network = "briani-m06-layout-" + short
    seed_name, down_name, api_name = ("briani-m06-layout-seed-" + short,
        "briani-m06-layout-down-" + short, "briani-m06-layout-api-" + short)
    owned_containers: list[str] = []
    network_created = False
    labels = {"org.briani.test": "M06", "org.briani.run": run_id}
    current_mode = "fixture-setup"
    current_observation: dict = {}
    cases: list[dict] = []
    try:
        common.docker("image", "inspect", API_IMAGE)
        common.docker("image", "inspect", QBIT_IMAGE)
        source_input = FIXTURE_SOURCE if FIXTURE_SOURCE.is_file() else FALLBACK_SOURCE
        if not source_input.is_file():
            generated_root = run_dir / "generated-early-play"
            generated = subprocess.run([sys.executable, str(FIXTURE_MODULE), "--out", str(generated_root),
                "--early-play-duration", "120", "--torrent-modes", "v1"],
                check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
            if generated.returncode:
                raise RuntimeError("fixture generator could not create a fresh 120-second early-play MP4")
            source_input = generated_root / "early-play-source" / "Faststart café [test].mp4"
        if not source_input.is_file() or source_input.stat().st_size <= PREFIX:
            raise RuntimeError("generated 120-second faststart MP4 fixture (>16 MiB) is unavailable")
        fixture_root = run_dir / "fixture-source" / "layout-corpus"
        fixture_root.mkdir(parents=True)
        target = fixture_root / "Faststart café [test].mp4"
        shutil.copyfile(source_input, target)
        media_metadata = inspect_generated_mp4(target)
        independent_payload(fixture_root / "00 ignored Ω.bin", 131071, 11)
        independent_payload(fixture_root / "99 ignored neighbor.bin", 73123, 29)
        (fixture_root / "nested").mkdir()
        independent_payload(fixture_root / "nested" / "雪片.dat", 524301, 47)
        hashes = {path.relative_to(fixture_root).as_posix(): sha256_file(path)
                  for path in fixture_root.rglob("*") if path.is_file()}
        manifest_path = run_dir / "layout-oracle.json"
        spec = __import__("importlib.util").util.spec_from_file_location("layout_fixture_generator", FIXTURE_MODULE)
        generator = __import__("importlib.util").util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        torrent_dir = run_dir / "torrents"
        torrent_dir.mkdir()
        native = generator.make_torrents(fixture_root, ["v1", "v2", "hybrid"], 262144, torrent_dir)
        if any(item.get("status") != "generated" for item in native.get("generated", [])):
            raise RuntimeError("one or more real v1/v2/hybrid metainfo fixtures failed generation")
        oracle_by_mode = {entry["mode"]: entry["layout_oracle"] for entry in native["generated"]}
        sources = {}
        for mode in ("v1", "v2", "hybrid"):
            original = torrent_dir / f"fixture-{mode}.torrent"
            prepared = no_trackers(original, run_dir / f"fixture-{mode}-private.torrent")
            sources[mode] = prepared
        manifest_path.write_text(json.dumps({"fixtureOrigin": "copied generated ffmpeg media; deterministic local neighbors",
            "sourcePath": source_input.name, "mediaMetadata": media_metadata,
            "sourceSha256": hashes[target.name], "sourceBytes": target.stat().st_size,
            "sourceFiles": hashes, "layouts": oracle_by_mode,
            "qBittorrentImage": QBIT_IMAGE, "apiImage": API_IMAGE}, ensure_ascii=False, indent=2) + "\n")

        common.docker("network", "create", "--internal", "--label", "org.briani.test=M06",
                      "--label", f"org.briani.run={run_id}", network)
        network_created = True

        def start_qbit(name: str, role: str, config: Path, payload: Path):
            common.docker("run", "--detach", "--name", name, "--network", network,
                "--label", "org.briani.test=M06", "--label", f"org.briani.run={run_id}",
                "--label", f"org.briani.role={role}", "--pids-limit=128", "--memory=768m", "--cpus=2",
                "-e", f"PUID={os.getuid()}",
                "-e", f"PGID={os.getgid()}", "-e", "WEBUI_PORT=8080", "-e", "TORRENTING_PORT=6881",
                "-v", f"{config}:/config", "-v", f"{payload}:/data", QBIT_IMAGE)
            owned_containers.append(name)
            ip = common.container_ip(name, network)
            password = None
            for _ in range(60):
                log = common.docker("logs", name)
                found = common.TEMP_PASSWORD.search(log)
                if found:
                    password = found.group(1)
                if password and "8080" in log:
                    break
                time.sleep(1)
            if password is None:
                raise RuntimeError(f"owned {role} qBittorrent startup password was not issued")
            common.wait_for(f"{role} qBittorrent", lambda: common.qbit_ready(ip), 30)
            return ip, password

        seed_ip, seed_password = start_qbit(seed_name, "seeder", seed_config, seed_data)
        down_ip, down_password = start_qbit(down_name, "downloader", down_config, data)
        seed = common.Qbit(f"http://{seed_ip}:8080", seed_password)
        down = common.Qbit(f"http://{down_ip}:8080", down_password)
        private = {"dht": False, "pex": False, "lsd": False, "upnp": False, "web_ui_upnp": False}
        for client in (seed, down):
            client.call("app/setPreferences", {"json": json.dumps(private)})
            if any(client.json("app/preferences").get(key) is not False for key in private):
                raise RuntimeError("could not disable qBittorrent discovery and forwarding")

        seeds = {}
        for mode, torrent in sources.items():
            hashes_for_torrent = hashes_for(torrent)
            root = seed_data / torrent_name(torrent)
            if not root.exists():
                shutil.copytree(fixture_root, root)
            seed.add_torrent(torrent, "/data")
            seed_hash = common.wait_for(mode + " owned seed registration", lambda:
                next((row.get("hash") for row in seed.json("torrents/info")
                      if row.get("hash", "").lower() in {h.lower() for h in hashes_for_torrent}), None), 20)
            if seed_hash.lower() not in {h.lower() for h in hashes_for_torrent}:
                raise RuntimeError("seeder torrent hash did not match generated metainfo")
            seed.call("torrents/start", {"hashes": seed_hash})
            common.wait_for(mode + " complete seed", lambda:
                next((row for row in seed.json("torrents/info", {"hashes": seed_hash})
                      if row.get("progress") == 1), None), 60)
            seeds[mode] = seed_hash

        common.docker("run", "--detach", "--name", api_name, "--network", network,
            "--network-alias", "briani", "--label", "org.briani.test=M06", "--label", f"org.briani.run={run_id}",
            "--label", "org.briani.role=api", "--read-only", "--cap-drop=ALL", "--security-opt=no-new-privileges",
            "--pids-limit=256", "--memory=1g", "--cpus=2", "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m",
            "-e", "ASPNETCORE_URLS=http://0.0.0.0:8088", "-v", f"{data}:/data", "-v", f"{state}:/config", API_IMAGE)
        owned_containers.append(api_name)
        network_info = json.loads(common.docker("network", "inspect", network))[0]
        if not network_info.get("Internal") or any((network_info.get("Labels") or {}).get(k) != v for k, v in labels.items()):
            raise RuntimeError("layout swarm ownership labels/internal mode verification failed")
        for name in owned_containers:
            if any(common.labels("container", name).get(key) != value for key, value in labels.items()):
                raise RuntimeError("owned layout container lacks exact run labels")
            common.verify_unpublished(name)
        api_ip = common.container_ip(api_name, network)
        api_origin = f"http://{api_ip}:8088"
        api = common.Api(api_origin)
        common.wait_for("Briani API readiness", lambda: common._api_ready(api), 150)
        bootstrap = (state / "bootstrap.code").read_text().strip()
        password = uuid.uuid4().hex + "Aa1!"
        auth = api.json("/api/v1/bootstrap", {"code": bootstrap, "username": "m06-layout", "displayName": "M06 Layout Matrix", "password": password, "confirmPassword": password})
        api.token = auth["accessToken"]
        storage_id = api.json("/api/v1/admin/storage")[0]["id"]
        library = api.json("/api/v1/libraries", {"name": "M06 layout matrix", "description": "",
            "storageRootId": storage_id, "relativePath": "library", "readOnly": False})
        integration = api.json("/api/v1/admin/integrations/qbittorrent",
            {"baseUrl": f"http://{down_name}:8080/", "version": 1, "username": "admin", "secret": down_password}, method="PUT")
        if not integration.get("credentialConfigured"):
            raise RuntimeError("production API did not configure the owned downloader")

        for mode in ("v1", "v2", "hybrid"):
            current_mode = mode
            current_observation = {"mode": mode, "phase": "metadata"}
            torrent = sources[mode]
            uploaded = common.multipart_torrent(api, torrent)
            created = api.json("/api/v1/downloads", {"libraryId": library["id"],
                "source": {"kind": "torrentUpload", "value": str(uploaded["id"])}})
            request_id = created["id"]
            rows = common.wait_for(mode + " parsed file metadata", lambda: common.api_files(api, request_id), 90)
            expected = expected_files(oracle_by_mode[mode])
            actual_names = [row.get("name", "") for row in rows]
            expected_names = [Path(item["path"]).name for item in expected]
            if Counter(actual_names) != Counter(expected_names) or any(".pad" in name for name in actual_names):
                raise RuntimeError(f"{mode} visible metadata entries did not match non-padding layout entries")
            selected = next((row for row in rows if row.get("name") == target.name and row.get("sizeBytes") == target.stat().st_size), None)
            if selected is None:
                raise RuntimeError(f"{mode} metadata did not map the generated media file")
            summary = api.json(f"/api/v1/downloads/{request_id}")
            selection = {"files": [{"fileId": row["id"], "selected": row["id"] == selected["id"], "priority": "normal"} for row in rows],
                         "autoStart": True, "version": summary["version"]}
            status, response_headers, body = api.request(f"/api/v1/downloads/{request_id}/selection", selection, method="PUT")
            if status != 202:
                raise RuntimeError(f"{mode} file selection was rejected with HTTP {status}")
            operation_id = response_headers.get("Location", "").rsplit("/", 1)[-1]
            common.wait_for(mode + " selection operation", lambda:
                (op if operation_id and (op := common._operation(api, operation_id)) and op.get("state") == "completed"
                 else True if not operation_id and common._download_started(api, request_id) else None), 60)
            expected_hashes = {h.lower() for h in hashes_for(torrent)}
            engine_rows = common.wait_for(mode + " engine registration", lambda:
                next((row for row in down.json("torrents/info") if row.get("hash", "").lower() in expected_hashes), None), 30)
            torrent_hash = engine_rows["hash"]
            mapping = engine_mapping(torrent, oracle_by_mode[mode], down, torrent_hash)
            if not any(item["padding"] for item in mapping) and mode == "hybrid":
                raise RuntimeError("hybrid fixture did not expose native padding entries in its layout oracle")
            down.call("torrents/setDownloadLimit", {"hashes": torrent_hash, "limit": str(RATE_LIMIT)})
            down.call("torrents/addPeers", {"hashes": torrent_hash, "peers": f"{seed_ip}:6881"})
            live = common.wait_for(mode + " verified 16 MiB contiguous prefix",
                lambda: common._ready_file(api, request_id, selected["id"]), args.timeout)
            current_observation = {"mode": mode, "phase": "prefix-ready",
                                   "contiguousBytes": int(live.get("contiguousBytes", 0))}
            if int(live.get("contiguousBytes", 0)) < PREFIX or target.stat().st_size <= PREFIX:
                raise RuntimeError(f"{mode} did not establish the required incomplete media prefix")
            engine_status = down.json("torrents/info", {"hashes": torrent_hash})[0]
            current_observation["engineProgress"] = engine_status.get("progress")
            if engine_status.get("progress", 1) >= 1:
                raise RuntimeError(f"{mode} torrent completed before layout byte checks")
            session = api.json("/api/v1/playback/sessions", {"target": {"kind": "downloadFile", "id": selected["id"]}, "mode": "internal"})
            if session.get("state") not in ("ready", "complete") or not session.get("streamUrl"):
                raise RuntimeError(f"{mode} scoped media session was not ready")
            stream = api_stream_url(api_origin, session["streamUrl"])
            action = api.json(f"/api/v1/downloads/{request_id}/actions", {"action": "pause", "version": api.json(f"/api/v1/downloads/{request_id}")["version"]})
            common.wait_for(mode + " pause operation", lambda: (op if (op := common._operation(api, action["id"])) and op.get("state") == "completed" else None), 25)
            common.wait_for(mode + " stopped downloader", lambda:
                (row if (found := down.json("torrents/info", {"hashes": torrent_hash})) and
                 (row := found[0]).get("state", "").startswith("stopped") else None), 15)
            # The transfer can advance while the API pause operation is being
            # applied. Re-sample after the engine is stopped so the missing
            # interval begins at a current, piece-verified prefix.
            time.sleep(1.0)
            paused_rows = common.api_files(api, request_id) or []
            paused_file = next((row for row in paused_rows if row.get("id") == selected["id"]), None)
            if paused_file is None:
                raise RuntimeError(f"{mode} selected file disappeared from API metadata after pause")
            priorities_before = [(row.get("index"), row.get("priority")) for row in down.json("torrents/files", {"hash": torrent_hash})]
            contiguous = int(paused_file["contiguousBytes"])
            current_observation.update({"phase": "paused", "contiguousBytes": contiguous,
                                        "engineProgress": engine_status.get("progress")})
            mapped_target = next(item for item in mapping if item["path"].endswith(target.name) and not item["padding"])
            file_offset = int(mapped_target["torrentOffset"])
            piece_length = int(oracle_by_mode[mode]["piece_length"])
            boundary = piece_length - (file_offset % piece_length)
            if boundary + 4096 >= contiguous:
                raise RuntimeError(f"{mode} verified prefix did not reach the first target-file piece boundary")
            range_cases = [
                verify_range(stream, target, 1, 16383),
                verify_range(stream, target, boundary - 2048, boundary + 2047),
            ]
            with ThreadPoolExecutor(max_workers=2) as pool:
                pair = list(pool.map(lambda _: verify_range(stream, target, 65539, 131074), range(2)))
            if pair[0]["sha256"] != pair[1]["sha256"]:
                raise RuntimeError(f"{mode} identical concurrent ranges returned different byte hashes")
            range_cases.extend({"case": "concurrent-identical", **item} for item in pair)
            states = down.json("torrents/pieceStates", {"hash": torrent_hash})
            missing_piece = next((piece for piece in range(int(mapped_target["pieceRange"][0]),
                int(mapped_target["pieceRange"][1]) + 1)
                if states[piece] != 2 and (piece + 1) * piece_length > file_offset + contiguous), None)
            if missing_piece is None:
                raise RuntimeError(f"{mode} torrent has no missing piece intersecting the media after its current prefix")
            missing = max(0, missing_piece * piece_length - file_offset)
            current_observation.update({"missingPiece": missing_piece, "missingFileOffset": missing})
            if missing >= target.stat().st_size:
                raise RuntimeError(f"{mode} has no missing media interval after the contiguous prefix")
            cancellation = assert_missing_wait(stream, missing)
            priorities_after = [(row.get("index"), row.get("priority")) for row in down.json("torrents/files", {"hash": torrent_hash})]
            if priorities_before != priorities_after:
                raise RuntimeError(f"{mode} playback range requests changed qBittorrent file priorities")
            paused_engine_status = down.json("torrents/info", {"hashes": torrent_hash})[0]
            physical_stat = downloader_media_stat(down_name, str(paused_engine_status.get("save_path", "")),
                                                  str(selected["relativePath"]))
            storage_snapshot = {**physical_stat,
                "availableContiguousPrefixBytes": contiguous,
                "missingFileOffsetBytes": missing}
            if physical_stat["logicalFileLengthBytes"] != target.stat().st_size:
                raise RuntimeError(f"{mode} preallocated/logical downloader file length differed from media length")
            ticket_recovery = None
            if mode == "v1":
                restart_reader = restart_during_missing_read(stream, target,
                    max(0, contiguous - 1024), down_name)
                common.wait_for("restarted owned qBittorrent HTTP service",
                    lambda: common.qbit_ready(down_ip), 30)
                # The config volume persists this run-owned account. Try it first;
                # only learn a replacement temporary credential from this exact
                # owned container's private log if reauthentication proves needed.
                time.sleep(3)
                def reauthenticate(password_value: str):
                    try:
                        return common.Qbit(f"http://{down_ip}:8080", password_value)
                    except Exception:
                        return None
                down = reauthenticate(down_password)
                if down is None:
                    owned_log = common.docker("logs", down_name)
                    found = list(common.TEMP_PASSWORD.finditer(owned_log))
                    replacement_password = found[-1].group(1) if found else None
                    if not replacement_password or replacement_password == down_password:
                        raise RuntimeError("restarted owned downloader did not accept its saved credential and issued no new recoverable temporary credential")
                    down_password = replacement_password
                    down = reauthenticate(down_password)
                    if down is None:
                        raise RuntimeError("restarted owned downloader rejected its newly issued temporary credential")
                    configured = next((item for item in api.json("/api/v1/admin/integrations")
                                       if item.get("kind") == "qbittorrent"), None)
                    if configured is None:
                        raise RuntimeError("API did not expose the owned downloader integration version")
                    integration = api.json("/api/v1/admin/integrations/qbittorrent",
                        {"baseUrl": f"http://{down_name}:8080/", "version": configured["version"],
                         "username": "admin", "secret": down_password}, method="PUT")
                    if not integration.get("credentialConfigured"):
                        raise RuntimeError("API refused the restarted run-owned downloader credential")
                common.wait_for("restarted qBittorrent torrent reconciliation",
                    lambda: next((row for row in down.json("torrents/info")
                                  if row.get("hash", "").lower() == torrent_hash.lower()), None), 45)
                old_restart_status, old_restart_headers, old_restart_body = request_range(stream, 1, 32, timeout=5)
                restart_invalidation = verify_ticket_invalidated(old_restart_status, old_restart_headers,
                    old_restart_body, "downloader restart")
                current_observation.update({"phase": "restart-invalidated", **restart_reader,
                                            "oldTicket": restart_invalidation})
                fresh_after_restart = api.json("/api/v1/playback/sessions",
                    {"target": {"kind": "downloadFile", "id": selected["id"]}, "mode": "internal"})
                if fresh_after_restart.get("state") not in ("ready", "complete") or not fresh_after_restart.get("streamUrl"):
                    fresh_id = fresh_after_restart.get("id")
                    fresh_after_restart = common.wait_for("fresh playback session after downloader restart", lambda:
                        (view if fresh_id and (view := api.json(f"/api/v1/playback/sessions/{fresh_id}"))
                         and view.get("state") in ("ready", "complete") and view.get("streamUrl") else None), 30)
                if fresh_after_restart.get("generation") == session.get("generation"):
                    raise RuntimeError("fresh playback session retained the pre-restart generation")
                restart_stream = api_stream_url(api_origin, fresh_after_restart["streamUrl"])
                restart_range = verify_range(restart_stream, target, 1, 32)
                restart_priorities = [(row.get("index"), row.get("priority"))
                    for row in down.json("torrents/files", {"hash": torrent_hash})]
                if restart_priorities != priorities_before:
                    raise RuntimeError("downloader restart or playback recovery changed torrent file priorities")
                before_version = api.json(f"/api/v1/downloads/{request_id}")["version"]
                recheck = api.json(f"/api/v1/downloads/{request_id}/actions",
                    {"action": "recheck", "version": before_version})
                old_status, old_headers, old_body = request_range(stream, 1, 32, timeout=5)
                recheck_invalidation = verify_ticket_invalidated(old_status, old_headers, old_body, "recheck")
                common.wait_for("v1 recheck operation", lambda:
                    (operation if (operation := common._operation(api, recheck["id"])) and operation.get("state") == "completed" else None), 90)
                common.wait_for("v1 recheck restored readable prefix", lambda:
                    common._ready_file(api, request_id, selected["id"]), 90)
                fresh = api.json("/api/v1/playback/sessions", {"target": {"kind": "downloadFile", "id": selected["id"]}, "mode": "internal"})
                if fresh.get("state") not in ("ready", "complete") or not fresh.get("streamUrl"):
                    fresh_id = fresh.get("id")
                    fresh = common.wait_for("v1 fresh playback ticket after recheck", lambda:
                        (view if fresh_id and (view := api.json(f"/api/v1/playback/sessions/{fresh_id}"))
                         and view.get("state") in ("ready", "complete") and view.get("streamUrl") else None), 30)
                if fresh.get("generation") == session.get("generation"):
                    raise RuntimeError("fresh playback session retained the pre-recheck generation")
                fresh_stream = api_stream_url(api_origin, fresh["streamUrl"])
                new_ticket_range = verify_range(fresh_stream, target, 1, 32)
                ticket_recovery = {"oldTicket": recheck_invalidation,
                    "generationChanged": True, "freshState": fresh.get("state"),
                    "freshTicketRange": new_ticket_range}
                ticket_recovery["restart"] = {**restart_reader,
                    "oldTicket": restart_invalidation,
                    "generationChanged": True, "freshTicketRange": restart_range,
                    "prioritiesUnchanged": True}
            cases.append({"mode": mode, "torrentHash": torrent_hash,
                "sourceSha256": hashes[target.name], "sourceBytes": target.stat().st_size,
                "fixtureFiles": hashes, "nativeLayout": oracle_by_mode[mode],
                "metadataVisibleFiles": [{"name": row.get("name"), "sizeBytes": row.get("sizeBytes"),
                    "kind": row.get("kind"), "selected": row.get("id") == selected["id"]} for row in rows],
                "metadataToUpstreamMap": mapping, "contiguousBytesAtPause": contiguous,
                "engineProgressAtPause": engine_status.get("progress"), "ranges": range_cases,
                "missingReadCancellation": cancellation, "storageSnapshot": storage_snapshot,
                "prioritiesUnchanged": True})
            if ticket_recovery is not None:
                cases[-1]["recheckTicketRecovery"] = ticket_recovery

        result = {"result": "passed", "runId": run_id, "network": network,
            "apiImage": API_IMAGE, "qBittorrentImage": QBIT_IMAGE,
            "fixtureManifest": str(manifest_path), "cases": cases,
            "limitations": ["No Raspberry Pi hardware measurements in this host run.",
                            "Restart race exercised only on the v1 layout; recheck exercised on the same isolated run."]}
        result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({"result": "passed", "runId": run_id, "artifact": str(result_path)}))
        return 0
    except Exception as error:
        result_path.write_text(json.dumps({"result": "failed", "runId": run_id,
            "failure": type(error).__name__, "detail": safe_error(error),
            "currentObservation": current_observation, "completedCases": cases}, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({"result": "failed", "runId": run_id, "artifact": str(result_path)}))
        return 1
    finally:
        for name in reversed(owned_containers):
            try:
                if all(common.labels("container", name).get(key) == value for key, value in labels.items()):
                    common.docker("rm", "-f", name)
            except Exception:
                pass
        if network_created:
            try:
                observed = common.labels("network", network)
                if all(observed.get(key) == value for key, value in labels.items()):
                    common.docker("network", "rm", network)
            except Exception:
                pass


if __name__ == "__main__":
    raise SystemExit(main())
