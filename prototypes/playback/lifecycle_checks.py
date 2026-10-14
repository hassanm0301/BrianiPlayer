"""Bounded lifecycle and preallocation checks against the isolated M00 swarm."""
from __future__ import annotations

import json
import re
import socket
import subprocess
import time
import urllib.parse
from pathlib import Path

from integration import (ART, GENERATED, Engine, connect, container_ip, gateway_for,
                         http_request, validated_layout, wait_until)
from harness.probe import ApiError

HERE = Path(__file__).resolve().parent


def _assert_test_container() -> str:
    name = "briani-m00-harness-qbittorrent-1"
    record = json.loads(subprocess.check_output(["docker", "inspect", name], text=True))[0]
    labels = record["Config"]["Labels"]
    if labels.get("com.docker.compose.project") != "briani-m00-harness" or labels.get("com.docker.compose.service") != "qbittorrent":
        raise RuntimeError("refusing lifecycle operation outside the dedicated M00 downloader")
    return name


def _request_waiter(url: str, byte_range: str) -> socket.socket:
    parsed = urllib.parse.urlsplit(url)
    conn = socket.create_connection((parsed.hostname, parsed.port), timeout=5)
    conn.settimeout(5)
    conn.sendall((f"GET {parsed.path} HTTP/1.1\r\nHost: 127.0.0.1:18088\r\n"
                  f"Range: {byte_range}\r\nConnection: close\r\n\r\n").encode("ascii"))
    return conn


def _read_http_response(conn: socket.socket) -> tuple[bytes, bytes]:
    wire = bytearray()
    while b"\r\n\r\n" not in wire:
        block = conn.recv(4096)
        if not block:
            break
        wire.extend(block)
    head, separator, body = bytes(wire).partition(b"\r\n\r\n")
    if not separator:
        return head, body
    length = 0
    chunked = False
    for line in head.split(b"\r\n")[1:]:
        if line.lower().startswith(b"content-length:"):
            length = int(line.split(b":", 1)[1].strip())
        if line.lower().startswith(b"transfer-encoding:") and b"chunked" in line.lower():
            chunked = True
    if chunked:
        while b"\r\n0\r\n\r\n" not in body and not body.endswith(b"0\r\n\r\n"):
            block = conn.recv(4096)
            if not block:
                break
            body += block
        decoded = bytearray()
        cursor = 0
        while cursor < len(body):
            boundary = body.find(b"\r\n", cursor)
            if boundary < 0:
                break
            try:
                size = int(body[cursor:boundary].split(b";", 1)[0], 16)
            except ValueError:
                break
            cursor = boundary + 2
            if size == 0:
                break
            decoded.extend(body[cursor:cursor + size])
            cursor += size + 2
        body = bytes(decoded)
    else:
        while len(body) < length:
            block = conn.recv(min(4096, length - len(body)))
            if not block:
                break
            body += block
    return head, body


def _fence_pending(url: str, token: str, byte_range: str, expected_active: int = 1) -> dict:
    """Fence a pre-header wait and require a clean 503 without file bytes."""
    from urllib.request import Request, build_opener, ProxyHandler

    waiter = _request_waiter(url, byte_range)
    try:
        wait_until(lambda: json.loads(http_request("http://127.0.0.1:18088/proof/state")[2])["activeReaders"] == expected_active, 5)
        fence = Request("http://127.0.0.1:18088/proof/fence", data=b"",
                        headers={"X-Proof-Key": token}, method="POST")
        with build_opener(ProxyHandler({})).open(fence, timeout=5) as response:
            fence_status = response.status
            generation = json.loads(response.read()).get("generation")
        waiter.settimeout(8)
        head, body = _read_http_response(waiter)
        status = int(head.split(b" ", 2)[1]) if head else 0
        headers = head.decode("latin1").lower()
        try:
            problem = json.loads(body) if body else {}
        except ValueError:
            problem = {}
        if fence_status != 200 or status != 503 or problem.get("status") != 503:
            raise AssertionError(f"fence waiter result invalid: fence={fence_status}, status={status}, "
                                 f"json_content_type={'application/json' in headers}, "
                                 f"problem_status={problem.get('status')}, problem_code={problem.get('code')}")
        wait_until(lambda: json.loads(http_request("http://127.0.0.1:18088/proof/state")[2])["activeReaders"] == 0, 5)
        return {"fenceStatus": fence_status, "waiterStatus": status, "problemCode": problem.get("code"),
                "invalidatedGeneration": generation, "activeReaderReleased": True}
    finally:
        waiter.close()


def _missing_file_byte(down: Engine, hash_value: str, ti, selected: dict) -> tuple[int, int]:
    pieces = down.get("torrents/pieceStates", hash=hash_value)
    piece = next((p for p, state in enumerate(pieces) if state != 2), None)
    if piece is None:
        raise AssertionError("lifecycle check requires an actually missing piece")
    offset = max(0, piece * ti.piece_length() - selected["torrentOffset"])
    if offset >= selected["length"]:
        raise AssertionError("missing piece does not overlap the selected file")
    return piece, offset


def _connect_when_ready(service: str, seconds: int = 45):
    last_error = None

    def connect_once():
        nonlocal last_error
        try:
            return connect(service)
        except (ApiError, OSError) as exc:
            last_error = type(exc).__name__
            if service == "qbittorrent":
                # The isolated image prints a session-only password on each
                # fresh boot. Consume it in memory, never include it in logs.
                name = _assert_test_container()
                log_result = subprocess.run(["docker", "logs", name], check=True, capture_output=True, text=True)
                logs = log_result.stdout + log_result.stderr
                matches = re.findall(r"temporary password is provided for this session:\s*(\S+)", logs, re.I)
                if matches:
                    creds_path = HERE / "harness/state/credentials.json"
                    creds = json.loads(creds_path.read_text())
                    try:
                        engine = Engine("http://" + container_ip(service) + ":8080", creds["username"], matches[-1])
                        return engine, {"username": creds["username"], "password": matches[-1]}
                    except (ApiError, OSError) as fresh_error:
                        last_error = type(fresh_error).__name__
            return None

    result = wait_until(connect_once, seconds)
    if not result:
        raise TimeoutError(f"dedicated {service} API did not return after container restart ({last_error})")
    return result


def run() -> dict:
    down, creds = connect("qbittorrent")
    seed, _ = connect("seeder")
    # Tail v2 is intentionally separate from the already-owned faststart jobs.
    torrent = GENERATED / "torrents" / "Tail metadata-v2.torrent"
    if not torrent.is_file():
        # Fixture names are derived from manifest; no regeneration is allowed here.
        raise RuntimeError("existing generated faststart v1 fixture is missing")
    import libtorrent as lt
    ti = lt.torrent_info(str(torrent))
    identity = ti.info_hashes()
    hash_value = str(identity.v2)[:40] if identity.has_v2() else str(identity.v1)
    info = down.get("torrents/info", hashes=hash_value)
    save_path = "/downloads/lifecycle-prealloc"
    if info:
        if info[0].get("save_path") != save_path:
            raise RuntimeError("unique lifecycle fixture hash is owned by another save path; refusing to delete it")
        down.post("torrents/delete", hashes=hash_value, deleteFiles="true")
        wait_until(lambda: not down.get("torrents/info", hashes=hash_value), 10)
    if not seed.get("torrents/info", hashes=hash_value):
        seed.add(torrent, "/downloads/early-play-source", stopped=False)
    wait_until(lambda: seed.get("torrents/info", hashes=hash_value) and
               seed.get("torrents/info", hashes=hash_value)[0]["progress"] == 1, 30)

    preferences = down.get("app/preferences")
    old_preallocate = preferences.get("preallocate_all")
    if not isinstance(old_preallocate, bool):
        raise RuntimeError("qBittorrent did not expose boolean preallocate_all preference")
    test_container = _assert_test_container()
    result = {"engine": down._text("app.version", "/api/v2/app/version"),
              "preallocationPreferenceRestored": False}
    try:
        down.post("app/setPreferences", json=json.dumps({"preallocate_all": True}))
        if down.get("app/preferences").get("preallocate_all") is not True:
            raise AssertionError("preallocate_all did not become true")
        down.add(torrent, save_path, stopped=True, rate=128 * 1024)
        entries = wait_until(lambda: down.get("torrents/files", hash=hash_value), 15)
        ti, files = validated_layout(torrent, entries)
        selected = files[0]
        down.post("torrents/filePrio", hash=hash_value, id=entries[0]["index"], priority=1)
        root = HERE / "harness/state/data/lifecycle-prealloc"
        media_path = root / selected["path"]
        down.post("torrents/start", hashes=hash_value)
        down.post("torrents/addPeers", hashes=hash_value, peers=container_ip("seeder") + ":6881")
        wait_until(lambda: media_path.is_file(), 15)
        wait_until(lambda: down.get("torrents/info", hashes=hash_value)[0]["progress"] < 1, 10)
        stat = media_path.stat()
        allocated = stat.st_blocks * 512
        logical = selected["length"]
        if allocated < logical:
            raise AssertionError(f"preallocated backing storage too small: {allocated} < {logical}")
        prealloc_observed = {"logicalBytes": logical, "allocatedBytes": allocated,
                             "progress": down.get("torrents/info", hashes=hash_value)[0]["progress"]}
        down.post("torrents/stop", hashes=hash_value)
        wait_until(lambda: down.get("torrents/info", hashes=hash_value)[0]["state"].startswith("stopped"), 10)
        missing, start = _missing_file_byte(down, hash_value, ti, selected)
        with gateway_for(down, creds, ti, files, selected, root, save_path) as (url, cfg):
            # The unavailable range has no HTTP response headers until a real piece arrives.
            sock = _request_waiter(url, f"bytes={start}-{start}")
            try:
                sock.settimeout(.35)
                try:
                    leaked = sock.recv(1)
                    raise AssertionError(f"preallocated gap emitted {len(leaked)} bytes/response before availability")
                except TimeoutError:
                    pass
            finally:
                sock.close()
            # Cancel the pending request to leave the listener clear before the explicit fence test.
            wait_until(lambda: json.loads(http_request("http://127.0.0.1:18088/proof/state")[2])["activeReaders"] == 0, 5)
            result["preallocation"] = {**prealloc_observed, "missingPiece": missing,
                                       "missingRangeNoResponse": True}
            result["preheaderFence"] = _fence_pending(url, cfg["token"], f"bytes={start}-{start}")
        # Each managed lifecycle operation gets a fresh proof host after the prior
        # explicit fence has invalidated that host's generation.
        with gateway_for(down, creds, ti, files, selected, root, save_path) as (url, cfg):
            selection_piece, selection_byte = _missing_file_byte(down, hash_value, ti, selected)
            result["selectionFence"] = _fence_pending(url, cfg["token"], f"bytes={selection_byte}-{selection_byte}")
        down.post("torrents/filePrio", hash=hash_value, id=entries[0]["index"], priority=0)
        wait_until(lambda: down.get("torrents/files", hash=hash_value)[0]["priority"] == 0, 5)
        with gateway_for(down, creds, ti, files, selected, root, save_path) as (url, _cfg):
            status, _, body = http_request(url, range_value="bytes=0-0", timeout=5)
            result["fileSelectionChange"] = {"reportedPriority": 0, "responseStatus": status,
                                               "failClosed": status == 503,
                                               "problemCode": json.loads(body).get("code") if status == 503 else None}
            if status != 503:
                raise AssertionError("selection change did not fail closed")
        down.post("torrents/filePrio", hash=hash_value, id=entries[0]["index"], priority=1)
        wait_until(lambda: down.get("torrents/files", hash=hash_value)[0]["priority"] == 1, 5)
        with gateway_for(down, creds, ti, files, selected, root, save_path) as (url, cfg):
            recheck_piece, recheck_byte = _missing_file_byte(down, hash_value, ti, selected)
            result["recheckFence"] = _fence_pending(url, cfg["token"], f"bytes={recheck_byte}-{recheck_byte}")
            down.post("torrents/recheck", hashes=hash_value)
            status_recheck, _, _ = http_request(url, range_value="bytes=0-0", timeout=5)
            result["recheck"] = {"requested": True, "missingPieceBeforeRequest": recheck_piece,
                                  "responseStatus": status_recheck, "failClosed": status_recheck == 503}
            if status_recheck != 503:
                raise AssertionError("recheck did not preserve the invalidated old generation")
        # Exercise engine transport failure with an old-generation waiter. The test
        # downloader's Compose labels are verified immediately before restart.
        down, creds = connect("qbittorrent")
        down.post("torrents/stop", hashes=hash_value)
        wait_until(lambda: down.get("torrents/info", hashes=hash_value)[0]["state"].startswith("stopped"), 30)
        entries = down.get("torrents/files", hash=hash_value)
        ti, files = validated_layout(torrent, entries)
        selected = files[0]
        with gateway_for(down, creds, ti, files, selected, root, save_path) as (url, _cfg):
            restart_piece, restart_byte = _missing_file_byte(down, hash_value, ti, selected)
            restart_waiter = _request_waiter(url, f"bytes={restart_byte}-{restart_byte}")
            try:
                wait_until(lambda: json.loads(http_request("http://127.0.0.1:18088/proof/state")[2])["activeReaders"] == 1, 5)
                if _assert_test_container() != test_container:
                    raise RuntimeError("test downloader identity changed")
                subprocess.run(["docker", "restart", test_container], check=True, timeout=30,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                restart_waiter.settimeout(12)
                head, body = _read_http_response(restart_waiter)
                status_restart = int(head.split(b" ", 2)[1]) if head else 0
                problem = json.loads(body) if body else {}
                if status_restart != 503 or problem.get("status") != 503:
                    raise AssertionError(f"restart waiter was not safely fenced: status={status_restart}, problem_json={bool(problem)}")
                result["containerRestart"] = {"engineRestarted": True, "waiterStatus": status_restart,
                                              "missingPieceBeforeRestart": restart_piece,
                                              "problemCode": problem.get("code")}
                down, _ = _connect_when_ready("qbittorrent")
                wait_until(lambda: down.get("torrents/info", hashes=hash_value), 20)
            finally:
                restart_waiter.close()
        result["preallocationPreferenceRestored"] = True
    finally:
        down, _ = _connect_when_ready("qbittorrent")
        down.post("app/setPreferences", json=json.dumps({"preallocate_all": old_preallocate}))
        if down.get("app/preferences").get("preallocate_all") is not old_preallocate:
            raise AssertionError("failed to restore test engine preallocation preference")
    return result


if __name__ == "__main__":
    ART.mkdir(exist_ok=True)
    output = run()
    target = ART / "lifecycle-result.json"
    target.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps(output, indent=2, sort_keys=True))
