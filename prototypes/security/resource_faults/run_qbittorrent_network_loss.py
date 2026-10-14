#!/usr/bin/env python3
"""Exercise loss/recovery of a real pinned qBittorrent peer transfer locally."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[3]
IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
IMAGE_ID = "sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
SOURCE = ROOT / "prototypes/playback/fixtures/generated/early-play-source/Faststart café [test].mp4"
OWNER = "resource-faults"
RECOVERY_PROGRESS_TIMEOUT_SECONDS = 210
RECOVERY_TIMEOUT_BASIS = {
    "libtorrentSource": "https://raw.githubusercontent.com/arvidn/libtorrent/v2.0.15/src/settings_pack.cpp",
    "libtorrentMinReconnectSeconds": 60,
    "libtorrentPeerTimeoutSeconds": 120,
    "qBittorrentSource": "https://github.com/qbittorrent/qBittorrent/blob/release-5.2.4/src/base/bittorrent/sessionimpl.cpp",
    "qBittorrentOverridesMinReconnect": False,
    "boundedRetryBudget": "3 reconnect backoff intervals (60 seconds each) + 15 seconds connect/API margin",
}
TEMP_PASSWORD = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)


def docker(*args: str, timeout: int = 30) -> str:
    env = {**os.environ, "DOCKER_CONFIG": str(ROOT / ".tools/docker-config")}
    p = subprocess.run(["docker", *args], text=True, capture_output=True, timeout=timeout, env=env)
    if p.returncode:
        raise RuntimeError(f"docker {args[0]} failed ({p.returncode}): {(p.stderr or '')[-1200:]}")
    return p.stdout.strip()


def encode(value: object) -> bytes:
    if isinstance(value, int):
        return b"i" + str(value).encode("ascii") + b"e"
    if isinstance(value, bytes):
        return str(len(value)).encode("ascii") + b":" + value
    if isinstance(value, list):
        return b"l" + b"".join(encode(item) for item in value) + b"e"
    if isinstance(value, dict):
        return b"d" + b"".join(encode(key) + encode(value[key]) for key in sorted(value)) + b"e"
    raise TypeError(type(value).__name__)


class QBit:
    def __init__(self, origin: str, username: str, password: str):
        self.origin = origin.rstrip("/")
        self.cookie = ""
        form = urllib.parse.urlencode({"username": username, "password": password}).encode()
        request = urllib.request.Request(self.origin + "/api/v2/auth/login", data=form,
                                         headers={"Origin": self.origin, "Referer": self.origin + "/"})
        with self.open(request, timeout=8) as response:
            cookie = response.headers.get("Set-Cookie", "")
        match = re.search(r"(?:SID|QBT_SID(?:_[^=;]+)?)=([^;]+)", cookie)
        if not match:
            raise RuntimeError("qBittorrent authentication returned no session cookie")
        self.cookie = cookie.split(";", 1)[0]

    @staticmethod
    def open(request: urllib.request.Request, timeout: int = 8):
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        return opener.open(request, timeout=timeout)

    def call(self, path: str, fields: dict[str, str] | None = None, *, body: bytes | None = None,
             content_type: str = "application/x-www-form-urlencoded", via_exec: str | None = None) -> bytes:
        if via_exec is not None:
            return self.local_call(path, fields, via_exec)
        data = body if body is not None else (urllib.parse.urlencode(fields).encode() if fields is not None else None)
        url = self.origin + "/api/v2/" + path
        if path.endswith("/info") and fields:
            url += "?" + urllib.parse.urlencode(fields)
            data = None
        headers = {"Cookie": self.cookie}
        if data is not None:
            headers["Content-Type"] = content_type
        request = urllib.request.Request(url, data=data, headers=headers)
        try:
            with self.open(request) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            detail = error.read(300).decode("utf-8", "replace")
            raise RuntimeError(f"qBittorrent API /api/v2/{path} returned HTTP {error.code}: {detail}") from error

    def json(self, path: str, fields: dict[str, str] | None = None, *, via_exec: str | None = None) -> object:
        payload = self.call(path, fields, via_exec=via_exec)
        return json.loads(payload) if payload else None

    def local_call(self, path: str, fields: dict[str, str] | None, container_id: str) -> bytes:
        query = "" if not fields else "?" + urllib.parse.urlencode(fields)
        env = {**os.environ, "DOCKER_CONFIG": str(ROOT / ".tools/docker-config")}
        p = subprocess.run(["docker", "exec", "--env", f"BRIANI_QBIT_COOKIE={self.cookie}",
                            "--env", f"BRIANI_QBIT_PATH={path}{query}", container_id, "sh", "-c",
                            'curl --silent --show-error --fail --max-time 5 -H "Cookie: $BRIANI_QBIT_COOKIE" '
                            '"http://127.0.0.1:8080/api/v2/$BRIANI_QBIT_PATH"'],
                           text=False, capture_output=True, timeout=8, env=env)
        if p.returncode:
            raise RuntimeError(f"in-container qBittorrent status read failed ({p.returncode}): {p.stderr[-400:].decode(errors='replace')}")
        return p.stdout


def bencode_torrent(payload: bytes, name: bytes, piece_size: int = 262144) -> tuple[bytes, str]:
    pieces = b"".join(hashlib.sha1(payload[offset:offset + piece_size]).digest()
                      for offset in range(0, len(payload), piece_size))
    info = {b"length": len(payload), b"name": name, b"piece length": piece_size,
            b"pieces": pieces, b"private": 1}
    encoded_info = encode(info)
    return encode({b"info": info}), hashlib.sha1(encoded_info).hexdigest()


def labels(kind: str, run_id: str) -> dict[str, str]:
    return {"org.briani.test": "M10-resource-fault", "org.briani.run": run_id,
            "org.briani.owner": OWNER, "org.briani.kind": kind}


def container_labels(container_id: str) -> dict[str, str]:
    value = json.loads(docker("inspect", container_id))[0]
    return value.get("Config", {}).get("Labels", {})


def network_labels(network_id: str) -> dict[str, str]:
    return (json.loads(docker("network", "inspect", network_id))[0].get("Labels") or {})


def assert_labels(actual: dict[str, str], expected: dict[str, str], label: str) -> None:
    if any(actual.get(key) != value for key, value in expected.items()):
        raise RuntimeError(f"ownership label check failed for {label}")


def start_qbit(name: str, kind: str, network: str, state: Path, data: Path,
               run_id: str) -> tuple[str, str, str]:
    config = state / f"{kind}-config"
    config.mkdir(mode=0o700)
    docker("run", "--detach", "--name", name, "--network", network,
           "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
           "--label", f"org.briani.owner={OWNER}", "--label", f"org.briani.kind={kind}",
           "-e", f"PUID={os.getuid()}", "-e", f"PGID={os.getgid()}", "-e", "WEBUI_PORT=8080",
           "-e", "TORRENTING_PORT=6881", "-v", f"{config}:/config", "-v", f"{data}:/data", IMAGE)
    cid = docker("inspect", "--format", "{{.Id}}", name)
    assert_labels(container_labels(cid), labels(kind, run_id), name)
    password: str | None = None
    deadline = time.monotonic() + 70
    while time.monotonic() < deadline:
        logs = docker("logs", cid)
        match = TEMP_PASSWORD.search(logs)
        if match:
            password = match.group(1)
        if password and "Connection to localhost (::1) 8080 port [tcp/http-alt] succeeded!" in logs:
            break
        time.sleep(.5)
    if not password:
        raise RuntimeError(f"{kind} qBittorrent did not emit a temporary password before timeout")
    details = json.loads(docker("inspect", cid))[0]
    address = details.get("NetworkSettings", {}).get("Networks", {}).get(network, {}).get("IPAddress")
    if not address:
        raise RuntimeError(f"{kind} qBittorrent received no address on the owned network")
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        try:
            QBit(f"http://{address}:8080", "admin", password)
            return cid, address, password
        except (OSError, urllib.error.URLError):
            time.sleep(.25)
    raise RuntimeError(f"{kind} qBittorrent API did not become ready")


def torrent_add(qbit: QBit, metainfo: bytes, infohash: str, path: str, paused: bool) -> None:
    boundary = "----briani" + uuid.uuid4().hex
    fields = [("savepath", path), ("paused", "true" if paused else "false"), ("sequentialDownload", "true")]
    body = bytearray()
    for key, value in fields:
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"\r\n\r\n{value}\r\n").encode()
    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"torrents\"; filename=\"fixture.torrent\"\r\n"
             "Content-Type: application/x-bittorrent\r\n\r\n").encode()
    body += metainfo + f"\r\n--{boundary}--\r\n".encode()
    response = qbit.call("torrents/add", body=bytes(body), content_type=f"multipart/form-data; boundary={boundary}")
    try:
        outcome = json.loads(response)
    except json.JSONDecodeError:
        outcome = None
    if not (isinstance(outcome, dict) and outcome.get("success_count") == 1 and
            outcome.get("failure_count") == 0 and outcome.get("added_torrent_ids") == [infohash]):
        raise RuntimeError(f"qBittorrent rejected generated private fixture metainfo: {response[:160]!r}")


def torrent_row(qbit: QBit, infohash: str, *, via_exec: str | None = None) -> dict[str, object] | None:
    values = qbit.json("torrents/info", {"hashes": infohash}, via_exec=via_exec)
    return values[0] if isinstance(values, list) and values else None


def wait_until(label: str, predicate, timeout: int, interval: float = .25):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        last = predicate()
        if last:
            return last
        time.sleep(interval)
    raise RuntimeError(f"timed out waiting for {label}; last observation={last!r}")


def normalized(row: dict[str, object]) -> dict[str, object]:
    return {key: row.get(key) for key in ("hash", "name", "state", "size", "progress", "downloaded",
                                           "amount_left", "dlspeed", "upspeed", "num_seeds", "num_leechs",
                                           "up_limit", "down_limit", "pieces_have", "pieces_num")}


def capture_native_retry_diagnostics(downloader: QBit, infohash: str,
                                     container_ids: dict[str, str]) -> dict[str, object]:
    diagnostic: dict[str, object] = {}
    try:
        row = torrent_row(downloader, infohash)
        diagnostic["downloaderTorrent"] = normalized(row) if row else None
    except Exception as error:
        diagnostic["torrentReadError"] = str(error)[:500]
    try:
        diagnostic["peerState"] = downloader.json(f"sync/torrentPeers?hash={infohash}")
    except Exception as error:
        diagnostic["peerReadError"] = str(error)[:500]
    for kind, cid in container_ids.items():
        try:
            # LinuxServer's qBittorrent image stores the actual libtorrent log
            # below /config; capture only its tail and scrub temporary secrets.
            command = ("find /config/qBittorrent -type f -path '*/logs/*' -name '*.log' "
                       "-print -exec tail -n 160 {} \\;")
            p = subprocess.run(["docker", "exec", cid, "sh", "-c", command], text=True,
                               capture_output=True, timeout=12,
                               env={**os.environ, "DOCKER_CONFIG": str(ROOT / ".tools/docker-config")})
            diagnostic[f"{kind}NativeLogs"] = TEMP_PASSWORD.sub("<redacted>", p.stdout[-16000:])
            if p.returncode:
                diagnostic[f"{kind}NativeLogReadError"] = p.stderr[-500:]
        except Exception as error:
            diagnostic[f"{kind}NativeLogReadError"] = str(error)[:500]
    return diagnostic


def reconnect_qbit_after_restart(address: str, container_id: str, previous_password: str,
                                 timeout: int = 35) -> tuple[QBit, str]:
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            logs = docker("logs", container_id)
            candidates = list(reversed(TEMP_PASSWORD.findall(logs))) + [previous_password]
            seen: set[str] = set()
            for password in candidates:
                if password in seen:
                    continue
                seen.add(password)
                try:
                    return QBit(f"http://{address}:8080", "admin", password), password
                except (OSError, urllib.error.URLError, RuntimeError) as error:
                    last_error = error
        except Exception as error:
            last_error = error
        time.sleep(.5)
    raise RuntimeError(f"qBittorrent API did not reauthenticate after owned-container restart: {last_error}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/M10/qbittorrent-network-loss.json")
    parser.add_argument("--scratch-parent", type=Path, default=ROOT / "artifacts/resource-faults")
    parser.add_argument("--fixture", type=Path, default=SOURCE)
    parser.add_argument("--seed-upload-limit", type=int, default=131072, help="seed cap in bytes/second")
    parser.add_argument("--recovery", choices=("unassisted", "restart-downloader"), default="unassisted",
                        help="recovery strategy after the owned downloader is reattached")
    args = parser.parse_args()

    run_id = uuid.uuid4().hex
    short = run_id[:12]
    network_name = f"briani-m10-qbit-net-{short}"
    seed_name = f"briani-m10-qbit-seed-{short}"
    down_name = f"briani-m10-qbit-down-{short}"
    root = args.scratch_parent.resolve() / run_id
    root.mkdir(parents=True, mode=0o700)
    marker = root / ".briani-owner"
    marker.write_text(f"{OWNER}:{run_id}\n", encoding="ascii")
    marker.chmod(0o600)
    config = root / "config"
    seed_data = root / "seed-data"
    down_data = root / "down-data"
    for path in (config, seed_data, down_data):
        path.mkdir(mode=0o700)
    network_id: str | None = None
    containers: dict[str, tuple[str, str]] = {}
    result: dict[str, object] = {"schema": 1, "runId": run_id, "result": "running", "image": IMAGE,
                                 "expectedImageId": IMAGE_ID, "startedUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                 "recoveryMode": args.recovery, "observations": []}
    phase = "starting"
    try:
        phase = "verify pinned qBittorrent image"
        image_id = docker("image", "inspect", IMAGE, "--format", "{{.Id}}")
        if image_id != IMAGE_ID:
            raise RuntimeError(f"local qBittorrent image ID differs from images.lock.json: {image_id}")
        fixture = args.fixture.expanduser().resolve()
        if not fixture.is_file() or fixture.stat().st_size > 64 * 1024 * 1024:
            raise RuntimeError(f"missing or oversized generated-media fixture: {fixture}")
        payload = fixture.read_bytes()
        expected_sha256 = hashlib.sha256(payload).hexdigest()
        filename = "Fault recovery generated.mp4"
        metainfo, infohash = bencode_torrent(payload, filename.encode())
        (root / "fixture.torrent").write_bytes(metainfo)
        seed_file = seed_data / filename
        shutil.copyfile(fixture, seed_file)
        seed_hash = hashlib.sha256(seed_file.read_bytes()).hexdigest()
        if seed_hash != expected_sha256:
            raise RuntimeError("staged seed fixture differs from the generated source")

        network_id = docker("network", "create", "--internal", "--label", "org.briani.test=M10-resource-fault",
                            "--label", f"org.briani.run={run_id}", "--label", f"org.briani.owner={OWNER}",
                            "--label", "org.briani.kind=network", network_name)
        assert_labels(network_labels(network_id), labels("network", run_id), network_name)
        phase = "start qBittorrent seeder and downloader"
        with ThreadPoolExecutor(max_workers=2) as pool:
            seed_future = pool.submit(start_qbit, seed_name, "qbit-seeder", network_name, config, seed_data, run_id)
            down_future = pool.submit(start_qbit, down_name, "qbit-downloader", network_name, config, down_data, run_id)
            seed_cid, seed_ip, seed_password = seed_future.result()
            containers[seed_name] = (seed_cid, "qbit-seeder")
            down_cid, down_ip, down_password = down_future.result()
            containers[down_name] = (down_cid, "qbit-downloader")
        phase = "authenticate qBittorrent APIs"
        seeder = QBit(f"http://{seed_ip}:8080", "admin", seed_password)
        downloader = QBit(f"http://{down_ip}:8080", "admin", down_password)

        phase = "add generated private torrent to seeder"
        torrent_add(seeder, metainfo, infohash, "/data", paused=False)
        phase = "verify seeder payload"
        seeded = wait_until("seed content hash check", lambda: (row if (row := torrent_row(seeder, infohash)) and
                          float(row.get("progress", 0)) >= 1 and int(row.get("size", -1)) == len(payload) else None), 60)
        phase = "set and inspect seeder upload cap"
        seeder.call("torrents/setUploadLimit", {"hashes": infohash, "limit": str(args.seed_upload_limit)})
        seed_limit_row = torrent_row(seeder, infohash)
        seed_limit = seed_limit_row.get("up_limit") if seed_limit_row else None

        phase = "add paused receiver torrent"
        torrent_add(downloader, metainfo, infohash, "/data", paused=True)
        phase = "set receiver limit and connect explicit peer"
        downloader.call("torrents/setDownloadLimit", {"hashes": infohash, "limit": "262144"})
        downloader.call("torrents/addPeers", {"hashes": infohash, "peers": f"{seed_ip}:6881"})
        # The pinned v2.15.1 API rejects the older `torrents/resume` route;
        # the existing lifecycle helper uses `torrents/start` for this image.
        downloader.call("torrents/start", {"hashes": infohash})
        phase = "observe incomplete transfer"
        initial = wait_until("incomplete payload transfer", lambda: (row if (row := torrent_row(downloader, infohash)) and
                            0 < int(row.get("downloaded", 0)) < len(payload) and float(row.get("progress", 0)) < 1 else None), 45)
        if int(initial.get("num_seeds", 0)) < 1:
            raise RuntimeError(f"transfer advanced without an observed connected seed: {normalized(initial)}")
        result["fixture"] = {"source": str(fixture.relative_to(ROOT)) if fixture.is_relative_to(ROOT) else fixture.name,
                              "sizeBytes": len(payload), "sha256": expected_sha256, "torrentInfoHash": infohash,
                              "torrentSha256": hashlib.sha256(metainfo).hexdigest(), "pieceLength": 262144,
                              "sourceProvenance": "generated synthetic media"}
        result["imageObservedId"] = image_id
        result["qbitSeedUploadLimitRequested"] = args.seed_upload_limit
        result["qbitSeedUploadLimitReported"] = seed_limit
        result["seedBefore"] = normalized(seeded)
        result["downloaderBeforeDisconnect"] = normalized(initial)
        result["observations"].append({"phase": "before-disconnect", **normalized(initial)})
        result["seedAddress"] = seed_ip
        result["downloaderAddressBeforeDisconnect"] = down_ip

        phase = "disconnect downloader from owned internal network"
        docker("network", "disconnect", network_name, down_cid)
        disconnected = True
        outage_rows: list[dict[str, object]] = []
        stable_count = 0
        prior_downloaded = int(initial.get("downloaded", 0))
        deadline = time.monotonic() + 9
        while time.monotonic() < deadline:
            row = torrent_row(downloader, infohash, via_exec=down_cid)
            if not row:
                raise RuntimeError("downloader torrent metadata disappeared while network was disconnected")
            current_bytes = int(row.get("downloaded", 0))
            if current_bytes >= len(payload) or float(row.get("progress", 0)) >= 1:
                raise RuntimeError("payload completed after disconnect; outage phase never observed a stall")
            if current_bytes == prior_downloaded:
                stable_count += 1
            else:
                stable_count = 0
                prior_downloaded = current_bytes
            outage_rows.append(normalized(row))
            if len(outage_rows) > 12:
                outage_rows.pop(0)
            if stable_count >= 4:
                break
            time.sleep(.5)
        if stable_count < 4:
            raise RuntimeError(f"qBittorrent bytes did not stabilize during isolated network loss: {outage_rows[-4:]}")
        result["disconnectedContainerId"] = down_cid
        result["outageObservations"] = outage_rows
        result["outageDurationSeconds"] = round(time.monotonic() - (deadline - 9), 3)
        result["observations"].append({"phase": "network-disconnected-stable", **outage_rows[-1]})

        phase = "reconnect downloader and resume exact torrent"
        docker("network", "connect", "--ip", down_ip, network_name, down_cid)
        disconnected = False
        recovered_ip = json.loads(docker("inspect", down_cid))[0].get("NetworkSettings", {}).get("Networks", {}).get(network_name, {}).get("IPAddress")
        if recovered_ip != down_ip:
            raise RuntimeError(f"downloader address changed on reconnect: {down_ip} -> {recovered_ip}")
        restart_diagnostic: dict[str, object] | None = None
        if args.recovery == "restart-downloader":
            down_file = down_data / filename
            if not down_file.is_file() or down_file.stat().st_size != len(payload):
                raise RuntimeError("downloaded partial file was not retained at its expected size before restart")
            partial_sha_before_restart = hashlib.sha256(down_file.read_bytes()).hexdigest()
            torrent_before_restart = torrent_row(downloader, infohash)
            if not torrent_before_restart or torrent_before_restart.get("hash") != infohash:
                raise RuntimeError("exact torrent metadata was absent before controlled downloader restart")
            restart_started = time.monotonic()
            docker("restart", "--time", "10", down_cid)
            assert_labels(container_labels(down_cid), labels("qbit-downloader", run_id), down_name)
            restarted_details = json.loads(docker("inspect", down_cid))[0]
            restarted_ip = restarted_details.get("NetworkSettings", {}).get("Networks", {}).get(network_name, {}).get("IPAddress")
            if restarted_ip != down_ip:
                raise RuntimeError(f"owned downloader restart changed its internal address: {down_ip} -> {restarted_ip}")
            downloader, down_password = reconnect_qbit_after_restart(down_ip, down_cid, down_password)
            retained = wait_until("exact torrent metadata after downloader restart",
                                  lambda: (row if (row := torrent_row(downloader, infohash)) and
                                           row.get("hash") == infohash and int(row.get("size", -1)) == len(payload) else None),
                                  45, .5)
            partial_sha_after_restart = hashlib.sha256(down_file.read_bytes()).hexdigest()
            if partial_sha_after_restart != partial_sha_before_restart:
                raise RuntimeError("downloader restart changed retained partial payload bytes")
            restart_diagnostic = {
                "containerId": down_cid,
                "gracefulDockerRestartSeconds": 10,
                "elapsedSeconds": round(time.monotonic() - restart_started, 3),
                "addressBefore": down_ip,
                "addressAfter": restarted_ip,
                "torrentBefore": normalized(torrent_before_restart),
                "torrentAfter": normalized(retained),
                "progressMetadataRegressed": float(retained.get("progress", 0)) + 0.000001 < float(outage_rows[-1]["progress"]),
                "progressMetadataMayResetDuringAvailabilityRecheck": True,
                "pieceStateBefore": {key: torrent_before_restart.get(key) for key in ("pieces_have", "pieces_num")},
                "pieceStateAfter": {key: retained.get(key) for key in ("pieces_have", "pieces_num")},
                "partialFileBytesRetained": down_file.stat().st_size,
                "partialFileSha256Before": partial_sha_before_restart,
                "partialFileSha256After": partial_sha_after_restart,
                "apiReauthenticated": True,
                "exactTorrentRetained": True,
            }
            result["controlledRecoveryRestart"] = restart_diagnostic

        # Re-add only the known private fixture peer and apply bounded recovery
        # controls after optional receiver restart and fresh API authentication.
        downloader.call("torrents/addPeers", {"hashes": infohash, "peers": f"{seed_ip}:6881"})
        start_response = downloader.call("torrents/start", {"hashes": infohash})
        seeder.call("torrents/setUploadLimit", {"hashes": infohash, "limit": "8388608"})
        download_limit_clear_response = downloader.call("torrents/setDownloadLimit", {"hashes": infohash, "limit": "0"})
        result["reconnectControls"] = {"startResponse": start_response.decode("utf-8", "replace"),
                                        "receiverLimitClearResponse": download_limit_clear_response.decode("utf-8", "replace"),
                                        "seederUploadLimitReported": (torrent_row(seeder, infohash) or {}).get("up_limit")}
        if restart_diagnostic is not None:
            result["controlledRecoveryRestart"] = restart_diagnostic
        result["recoveryProgressTimeoutSeconds"] = RECOVERY_PROGRESS_TIMEOUT_SECONDS
        result["recoveryProgressTimeoutBasis"] = RECOVERY_TIMEOUT_BASIS
        recovery_started = time.monotonic()
        result["recoveryProgressStartedUtc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        recovery_rows: list[dict[str, object]] = []

        def observe_recovery():
            row = torrent_row(downloader, infohash)
            if row:
                recovery_rows.append(normalized(row))
                if len(recovery_rows) > 16:
                    recovery_rows.pop(0)
            return row if row and int(row.get("num_seeds", 0)) > 0 and \
                int(row.get("downloaded", 0)) > int(outage_rows[-1]["downloaded"]) and int(row.get("dlspeed", 0)) > 0 else None

        phase = "verify payload progress resumed after reconnect"
        try:
            wait_until("qBittorrent payload progress after reconnect", observe_recovery,
                       RECOVERY_PROGRESS_TIMEOUT_SECONDS, .5)
        finally:
            result["recoveryProgressElapsedSeconds"] = round(time.monotonic() - recovery_started, 3)
            result["recoveryProgressObservations"] = recovery_rows
        phase = "wait for recovered transfer completion"
        completed = wait_until("complete qBittorrent transfer", lambda: (row if (row := torrent_row(downloader, infohash)) and
                            float(row.get("progress", 0)) >= 1 and int(row.get("amount_left", 0)) == 0 else None), 120, .5)
        phase = "verify downloaded bytes and retained seeder metadata"
        down_file = down_data / filename
        if not down_file.is_file() or down_file.stat().st_size != len(payload):
            raise RuntimeError("completed downloader file has a missing or incorrect length")
        completed_sha256 = hashlib.sha256(down_file.read_bytes()).hexdigest()
        if completed_sha256 != expected_sha256:
            raise RuntimeError("completed downloader payload differs from the independent source SHA-256")
        retained_seed = torrent_row(seeder, infohash)
        if not retained_seed or retained_seed.get("hash") != infohash or int(retained_seed.get("size", -1)) != len(payload):
            raise RuntimeError("source seeder metadata did not remain registered with the same torrent identity")
        seed_state = str(retained_seed.get("state", ""))
        if seed_state not in ("uploading", "stalledUP", "queuedUP", "forcedUP"):
            raise RuntimeError(f"source seeder did not remain in a seeding state: {seed_state}")
        seed_after_sha = hashlib.sha256(seed_file.read_bytes()).hexdigest()
        if seed_after_sha != expected_sha256:
            raise RuntimeError("source seeder payload changed during network-loss recovery")
        result["downloaderAfterRecovery"] = normalized(completed)
        result["recoveredPayloadSha256"] = completed_sha256
        result["retainedSeedMetadata"] = normalized(retained_seed)
        result["retainedSeedPayloadSha256"] = seed_after_sha
        result["qBittorrentClientVersion"] = seeder.call("app/version").decode("utf-8", "replace").strip()
        if not result["qBittorrentClientVersion"]:
            raise RuntimeError("locked qBittorrent app/version endpoint returned an empty value")
        result["result"] = "passed"
    except Exception as error:
        result["result"] = "failed"
        result["phase"] = phase
        result["error"] = f"{type(error).__name__}: {TEMP_PASSWORD.sub('<redacted>', str(error))[:1200]}"
        if phase == "verify payload progress resumed after reconnect" and "downloader" in locals():
            native_containers = {}
            if "down_cid" in locals():
                native_containers["downloader"] = down_cid
            if "seed_cid" in locals():
                native_containers["seeder"] = seed_cid
            result["nativeRetryDiagnostics"] = capture_native_retry_diagnostics(
                downloader, infohash, native_containers)
    finally:
        removed: list[str] = []
        cleanup_errors: list[str] = []
        try:
            # A startup worker may have created a container before its future
            # returned; discover only this run's exact label set for cleanup.
            discovered = docker("ps", "--all", "--quiet", "--filter", f"label=org.briani.run={run_id}").splitlines()
            for short_id in discovered:
                cid = docker("inspect", "--format", "{{.Id}}", short_id)
                found = container_labels(cid)
                if (found.get("org.briani.test") == "M10-resource-fault" and
                        found.get("org.briani.owner") == OWNER and
                        found.get("org.briani.kind") in ("qbit-seeder", "qbit-downloader")):
                    containers.setdefault(cid, (cid, found["org.briani.kind"]))
                else:
                    cleanup_errors.append(f"refused run-matching but unexpected container {cid}")
        except Exception as error:
            cleanup_errors.append(f"owned-container discovery: {error}")
        cleaned_ids: set[str] = set()
        for name, (cid, kind) in list(containers.items())[::-1]:
            if cid in cleaned_ids:
                continue
            cleaned_ids.add(cid)
            try:
                assert_labels(container_labels(cid), labels(kind, run_id), name)
                docker("rm", "--force", cid)
                removed.append(cid)
            except Exception as error:
                cleanup_errors.append(f"container {cid}: {error}")
        if network_id:
            try:
                assert_labels(network_labels(network_id), labels("network", run_id), network_name)
                docker("network", "rm", network_id)
            except Exception as error:
                cleanup_errors.append(f"network {network_id}: {error}")
        result["cleanup"] = {"removedContainerIds": removed, "networkId": network_id,
                              "errors": cleanup_errors, "scratchRoot": str(root),
                              "ownerMarker": marker.read_text(encoding="ascii").strip() if marker.exists() else None}
        result["finishedUtc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        output = args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": result.get("result"), "runId": run_id, "output": str(output),
                          "error": result.get("error"), "cleanupErrors": cleanup_errors}))
        if not cleanup_errors and marker.exists() and marker.read_text(encoding="ascii").strip() == f"{OWNER}:{run_id}":
            shutil.rmtree(root)
    return 0 if result.get("result") == "passed" and not result["cleanup"]["errors"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
