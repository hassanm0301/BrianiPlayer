#!/usr/bin/env python3
"""Run the trackerless M05 metadata/layout test against two owned qBittorrent containers."""
from __future__ import annotations

import hashlib
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
TEMP_PASSWORD = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        detail = (result.stderr or "").strip()[-1000:]
        raise RuntimeError(f"command failed ({result.returncode}): {args[0]} {args[1]}: {detail}")
    return result


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
        raise ValueError("trailing bencode data")
    return value


def make_nonprivate_copies(source: Path, destination: Path, torrent_names: list[str]) -> None:
    destination.mkdir()
    for name in torrent_names:
        decoded = bdecode((source / name).read_bytes())
        if not isinstance(decoded, dict) or not isinstance(decoded.get(b"info"), dict):
            raise ValueError("generated fixture has an invalid bencode shape")
        decoded[b"info"].pop(b"private", None)
        (destination / name).write_bytes(bencode(decoded))


def make_private_test_copies(source: Path, destination: Path) -> None:
    destination.mkdir()
    names = ["fixture-v1.torrent", "fixture-v2.torrent", "fixture-hybrid.torrent"]
    for name in names:
        (destination / name).write_bytes((source / name).read_bytes())
    hybrid_path = destination / "fixture-hybrid.torrent"
    hybrid = bdecode(hybrid_path.read_bytes())
    files = hybrid[b"info"][b"files"]
    seen: set[tuple[bytes, ...]] = set()
    for item in files:
        if b"p" not in item.get(b"attr", b""):
            continue
        path = item.get(b"path.utf-8", item.get(b"path"))
        key = tuple(path)
        if key in seen:
            path[-1] += b"-duplicate-padding"
            item[b"path"] = path
            item.pop(b"path.utf-8", None)
            key = tuple(path)
        seen.add(key)
    hybrid_path.write_bytes(bencode(hybrid))


def make_zero_length_torrent(root: Path) -> Path:
    corpus = root / "zero-corpus"
    corpus.mkdir(parents=True)
    (corpus / "empty.mp4").write_bytes(b"")
    payload = bytes((i * 73 + 19) % 251 for i in range(25_000))
    (corpus / "selected.bin").write_bytes(payload)
    piece_length = 16 * 1024
    pieces = b"".join(hashlib.sha1(payload[i:i + piece_length]).digest() for i in range(0, len(payload), piece_length))
    info = {
        b"files": [
            {b"length": 0, b"path": [b"empty.mp4"]},
            {b"length": len(payload), b"path": [b"selected.bin"]},
        ],
        b"name": b"zero-corpus",
        b"piece length": piece_length,
        b"pieces": pieces,
    }
    path = root / "zero-length-v1.torrent"
    path.write_bytes(bencode({b"info": info}))
    return path


def labels(name: str) -> dict[str, str]:
    info = json.loads(run(["docker", "inspect", name]).stdout)[0]
    return info.get("Config", {}).get("Labels") or info.get("Labels") or {}


def inspect_owned(name: str, expected: dict[str, str]) -> bool:
    try:
        found = labels(name)
        return all(found.get(key) == value for key, value in expected.items())
    except Exception:
        return False


def start_container(name: str, network: str, state: Path, data: Path, run_id: str, role: str) -> tuple[str, str]:
    config = state / f"{role}-config"
    config.mkdir()
    config.chmod(0o700)
    run(["docker", "run", "--detach", "--name", name, "--network", network,
         "--label", "org.briani.test=M05", "--label", f"org.briani.run={run_id}", "--label", f"org.briani.role={role}",
         "-e", f"PUID={os.getuid()}", "-e", f"PGID={os.getgid()}", "-e", "WEBUI_PORT=8080", "-e", "TORRENTING_PORT=6881",
         "-v", f"{config}:/config", "-v", f"{data}:/data", IMAGE])
    password = None
    ready = False
    for _ in range(60):
        logs = run(["docker", "logs", name]).stdout + run(["docker", "logs", name]).stderr
        match = TEMP_PASSWORD.search(logs)
        if match:
            password = match.group(1)
        ready = "Connection to localhost (::1) 8080 port [tcp/http-alt] succeeded!" in logs
        if password and ready:
            break
        time.sleep(1)
    if not password or not ready:
        raise RuntimeError(f"owned {role} qBittorrent startup did not become ready")
    info = json.loads(run(["docker", "inspect", name]).stdout)[0]
    address = info.get("NetworkSettings", {}).get("Networks", {}).get(network, {}).get("IPAddress")
    if not address:
        raise RuntimeError(f"owned {role} qBittorrent has no address on the private test bridge")
    with socket.create_connection((address, 8080), timeout=3) as stream:
        stream.sendall(f"GET /api/v2/app/version HTTP/1.1\r\nHost: {address}:8080\r\nConnection: close\r\n\r\n".encode())
        status = stream.recv(256).split(b"\r\n", 1)[0]
    if status != b"HTTP/1.1 403 Forbidden":
        raise RuntimeError("qBittorrent private Web API unauthenticated preflight did not return 403")
    return address, password


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture-root", type=Path, default=Path(os.environ.get("BRIANI_DOWNLOAD_FIXTURE_ROOT", ROOT / "prototypes/playback/fixtures/generated")))
    parser.add_argument("--log", type=Path, default=Path("/tmp/briani-m05-qbit-local-peer.json"))
    args = parser.parse_args()
    fixture_root = args.fixture_root.expanduser().resolve()
    if not (fixture_root / "corpus").is_dir() or not (fixture_root / "torrents").is_dir():
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.log.write_text(json.dumps({"result": "failed", "failure": "FixtureRootMissing", "fixtureRoot": str(fixture_root), "log": str(args.log)}, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "failed", "failure": "FixtureRootMissing", "log": str(args.log)}))
        return 1
    run_id = uuid.uuid4().hex
    network = f"briani-m05-peer-{run_id[:12]}"
    seeder_name = f"briani-m05-seeder-{run_id[:12]}"
    downloader_name = f"briani-m05-downloader-{run_id[:12]}"
    network_labels = {"org.briani.test": "M05", "org.briani.run": run_id}
    seeder_labels = {**network_labels, "org.briani.role": "seeder"}
    downloader_labels = {**network_labels, "org.briani.role": "downloader"}
    state = Path(tempfile.mkdtemp(prefix=f"briani-m05-peer-{run_id[:8]}-"))
    state.chmod(0o700)
    seed_data = state / "seed-data"
    download_data = state / "download-data"
    seed_data.mkdir()
    download_data.mkdir()
    seed_library, seed_job = str(uuid.uuid4()), uuid.uuid4().hex
    seed_root = seed_data / seed_library / ".briani" / "staging" / seed_job
    seed_root.mkdir(parents=True)
    shutil.copytree(fixture_root / "corpus", seed_root / "corpus")
    zero_torrent = make_zero_length_torrent(seed_root)
    private_root = state / "private-fixtures"
    make_private_test_copies(fixture_root / "torrents", private_root)
    nonprivate_root = state / "nonprivate-fixtures"
    make_nonprivate_copies(private_root, nonprivate_root, ["fixture-v1.torrent", "fixture-v2.torrent", "fixture-hybrid.torrent"])
    zero_meta = bdecode(zero_torrent.read_bytes())
    zero_meta[b"info"].pop(b"private", None)
    (nonprivate_root / "zero-length-v1.torrent").write_bytes(bencode(zero_meta))
    output: dict[str, object] = {"image": IMAGE, "runId": run_id, "networkIsolation": "internal Docker bridge", "result": "running"}
    try:
        run(["docker", "network", "create", "--internal", "--label", "org.briani.test=M05", "--label", f"org.briani.run={run_id}", network])
        seed_ip, seed_password = start_container(seeder_name, network, state, seed_data, run_id, "seeder")
        downloader_ip, downloader_password = start_container(downloader_name, network, state, download_data, run_id, "downloader")
        observations_path = state / "hash-observations.json"
        env = os.environ.copy()
        env.update({
            "BRIANI_M05_SEED_URL": f"http://{seed_ip}:8080/", "BRIANI_M05_SEED_USERNAME": "admin", "BRIANI_M05_SEED_PASSWORD": seed_password,
            "BRIANI_M05_DOWNLOAD_URL": f"http://{downloader_ip}:8080/", "BRIANI_M05_DOWNLOAD_USERNAME": "admin", "BRIANI_M05_DOWNLOAD_PASSWORD": downloader_password,
            "BRIANI_M05_SEED_PEER": seed_ip, "BRIANI_M05_SEED_LIBRARY": seed_library, "BRIANI_M05_SEED_JOB": seed_job,
            "BRIANI_M05_FIXTURE_ROOT": str(fixture_root), "BRIANI_M05_ZERO_TORRENT": str(zero_torrent),
            "BRIANI_M05_NONPRIVATE_FIXTURE_ROOT": str(nonprivate_root),
            "BRIANI_M05_PRIVATE_FIXTURE_ROOT": str(private_root),
            "BRIANI_M05_OBSERVATIONS": str(observations_path),
        })
        test = subprocess.run(["dotnet", "test", str(ROOT / "server/tests/Briani.DownloadTests/DownloadTests.csproj"), "--no-build", "--no-restore",
                               "--filter", "FullyQualifiedName~LocalSeedMetadataMagnetsMapV1V2HybridAndZeroLengthWithoutPayload"],
                              cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        output["command"] = "dotnet test Briani.DownloadTests --no-build --filter LocalSeedMetadataMagnetsMapV1V2HybridAndZeroLengthWithoutPayload"
        output["exitCode"] = test.returncode
        output["result"] = "passed" if test.returncode == 0 else "failed"
        if observations_path.is_file():
            output["hashObservations"] = json.loads(observations_path.read_text(encoding="utf-8"))
        output["testOutput"] = test.stdout.replace(seed_password, "<redacted>").replace(downloader_password, "<redacted>")
        output["testOutput"] = re.sub(r"(?:172\.(?:1[6-9]|2\d|3[01])|10|192\.168)(?:\.\d{1,3}){3}", "<private-ip>", str(output["testOutput"]))
        output["release"] = "qBittorrent 5.2.4 / WebAPI 2.15.1 / libtorrent 2.0.15.0 (adapter-verified in adjacent pinned smoke)"
        output["fixtureRoot"] = str(fixture_root)
        output["log"] = str(args.log)
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.log.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": output["result"], "exitCode": test.returncode, "log": output["log"]}))
        return test.returncode
    except Exception as error:
        output["result"] = "failed"
        output["failure"] = type(error).__name__
        output["detail"] = TEMP_PASSWORD.sub("temporary password is provided for this session: <redacted>", str(error))[:1000]
        output["fixtureRoot"] = str(fixture_root)
        output["log"] = str(args.log)
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.log.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "failed", "failure": type(error).__name__, "log": str(args.log)}))
        return 1
    finally:
        for name, expected in ((seeder_name, seeder_labels), (downloader_name, downloader_labels)):
            if inspect_owned(name, expected):
                run(["docker", "rm", "--force", name])
        if inspect_owned(network, network_labels):
            run(["docker", "network", "rm", network])
        shutil.rmtree(state, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
