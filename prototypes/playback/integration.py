"""Real-engine proof orchestration; generated fixtures only, private Compose swarm."""
from __future__ import annotations

import hashlib
import http.client
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import time
import urllib.parse
import urllib.request
from contextlib import contextmanager

from harness.probe import QbitProbe

HERE = Path(__file__).resolve().parent
ART = HERE / "artifacts"
GENERATED = HERE / "fixtures/generated"
RESULT_DIR = ART
IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"


def set_result_dir(path: Path) -> None:
    global RESULT_DIR
    RESULT_DIR = path
    RESULT_DIR.mkdir(parents=True, exist_ok=True)


def wait_until(predicate, seconds=30):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(.2)
    raise TimeoutError("bounded proof condition did not occur")


class Engine(QbitProbe):
    def post(self, endpoint, **fields):
        return self._request(endpoint, "/api/v2/" + endpoint, method="POST",
                             data=urllib.parse.urlencode(fields).encode())

    def get(self, endpoint, **fields):
        return self._json(endpoint, "/api/v2/" + endpoint + "?" + urllib.parse.urlencode(fields))

    def add(self, torrent: Path, savepath, stopped=True, rate=0):
        boundary = secrets.token_hex(16)
        body = bytearray()
        fields = {"savepath": savepath, "stopped": str(stopped).lower(), "autoTMM": "false",
                  "sequentialDownload": "true", "firstLastPiecePrio": "true", "dlLimit": str(rate)}
        for k, v in fields.items():
            body.extend(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
        body.extend(f'--{boundary}\r\nContent-Disposition: form-data; name="torrents"; filename="fixture.torrent"\r\nContent-Type: application/x-bittorrent\r\n\r\n'.encode())
        body.extend(torrent.read_bytes())
        body.extend(f"\r\n--{boundary}--\r\n".encode())
        request = urllib.request.Request(self.base + "/api/v2/torrents/add", data=bytes(body),
                                         headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
        with self.opener.open(request, timeout=10) as response:
            raw = response.read().strip()
            if raw not in (b"Ok.", b""):
                observed = json.loads(raw)
                assert observed.get("success_count") == 1 and observed.get("failure_count") == 0, "engine did not accept fixture"


def container_ip(service):
    container = "briani-m00-harness-" + service + "-1"
    data = json.loads(subprocess.check_output(["docker", "inspect", container], text=True))[0]
    assert data["Config"]["Labels"]["com.docker.compose.project"] == "briani-m00-harness"
    assert data["Config"]["Labels"]["com.docker.compose.service"] == service
    return data["NetworkSettings"]["Networks"]["briani-m00-harness_swarm"]["IPAddress"]


def connect(service):
    creds_path = HERE / "harness/state" / ("credentials.json" if service == "qbittorrent" else "seeder-credentials.json")
    creds = json.loads(creds_path.read_text())
    return Engine("http://" + container_ip(service) + ":8080", creds["username"], creds["password"]), creds


def validated_layout(torrent_path: Path, engine_files):
    """Cross-check native metainfo with an independent sum/alignment oracle and API indexes."""
    import libtorrent as lt
    ti = lt.torrent_info(str(torrent_path))
    fs = ti.files()
    offsets, files, cursor = {}, [], 0
    for i in range(fs.num_files()):
        path, size = fs.file_path(i), fs.file_size(i)
        padding = bool(fs.file_flags(i) & fs.flag_pad_file)
        assert fs.file_offset(i) == cursor, "metainfo offset differs from independent including-padding sum"
        if ti.info_hashes().has_v2() and not padding:
            assert cursor % ti.piece_length() == 0, "v2 file not piece aligned"
        offsets[path] = (i, size, cursor, padding)
        cursor += size
    for item in engine_files:
        idx, length, offset, padding = offsets[item["name"]]
        assert not padding and item["size"] == length
        if length:
            expected = [offset // ti.piece_length(), (offset + length - 1) // ti.piece_length()]
            assert item["piece_range"] == expected, (item["name"], item["piece_range"], expected)
        files.append({"id": str(idx), "upstreamIndex": item["index"], "path": item["name"],
                      "length": length, "torrentOffset": offset, "padding": False, "priority": item["priority"]})
    assert len(files) == sum(not x[3] for x in offsets.values()), "engine hidden file mismatch"
    files.sort(key=lambda f: f["torrentOffset"])
    return ti, files


def http_request(url, method="GET", range_value=None, timeout=10):
    req = urllib.request.Request(url, method=method, headers={"Range": range_value} if range_value else {})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=timeout) as response:
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers), error.read()


def gap_and_cancel(url, engine, hash_value, selected, source):
    """Real sparse storage: missing ranges wait, cancellation frees lease, gaps resume exactly."""
    engine.post("torrents/stop", hashes=hash_value)
    wait_until(lambda: engine.get("torrents/info", hashes=hash_value)[0]["state"].startswith("stopped"), 10)
    pieces = engine.get("torrents/pieceStates", hash=hash_value)
    piece_length = 262144
    offset = selected["torrentOffset"]
    first = offset // piece_length
    missing = next((p for p in range(first, len(pieces)) if pieces[p] != 2), None)
    assert missing is not None and missing > first, "fixture must retain an available prefix and missing middle"
    gap_start = missing * piece_length - offset
    end = min(selected["length"] - 1, gap_start + piece_length - 1)
    parsed = urllib.parse.urlsplit(url)
    priorities = [f["priority"] for f in engine.get("torrents/files", hash=hash_value)]
    def open_range(start, last):
        sock = socket.create_connection((parsed.hostname, parsed.port), timeout=5)
        sock.sendall((f"GET {parsed.path} HTTP/1.1\r\nHost: 127.0.0.1:18088\r\nRange: bytes={start}-{last}\r\nConnection: close\r\n\r\n").encode())
        return sock
    far = open_range(gap_start, gap_start + 15)
    wait_until(lambda: json.loads(http_request("http://127.0.0.1:18088/proof/state")[2])["activeReaders"] == 1, 2)
    far.settimeout(.25)
    try:
        data = far.recv(1)
        raise AssertionError("unavailable first byte returned headers/data/EOF: " + str(len(data)))
    except TimeoutError:
        pass
    start_cancel = time.monotonic()
    far.shutdown(socket.SHUT_RDWR); far.close()
    wait_until(lambda: json.loads(http_request("http://127.0.0.1:18088/proof/state")[2])["activeReaders"] == 0, 2)
    cancel_seconds = time.monotonic() - start_cancel
    stream = open_range(0, end)
    try:
        stream.settimeout(5)
        raw = b""
        while b"\r\n\r\n" not in raw: raw += stream.recv(65536)
        headers, body = raw.split(b"\r\n\r\n", 1)
        assert headers.startswith(b"HTTP/1.1 206")
        while len(body) < gap_start:
            chunk = stream.recv(min(65536, gap_start - len(body)))
            assert chunk, "successful early EOF at missing piece"
            body += chunk
        assert len(body) == gap_start, "missing piece emitted while engine stopped"
        stream.settimeout(.25)
        try:
            chunk = stream.recv(1)
            raise AssertionError("gap produced invalid data/EOF: " + str(len(chunk)))
        except TimeoutError:
            pass
        engine.post("torrents/start", hashes=hash_value)
        engine.post("torrents/addPeers", hashes=hash_value, peers=container_ip("seeder") + ":6881")
        stream.settimeout(40)
        while len(body) < end + 1:
            chunk = stream.recv(min(65536, end + 1 - len(body)))
            assert chunk, "early EOF on resumed range"
            body += chunk
        with source.open("rb") as oracle:
            assert body == oracle.read(len(body)), "gap response byte corruption"
        assert [f["priority"] for f in engine.get("torrents/files", hash=hash_value)] == priorities
        assert engine.get("torrents/info", hashes=hash_value)[0]["seq_dl"] is True
        return {"missingPiece": missing, "cancelSeconds": cancel_seconds, "gapBytesCompared": len(body),
                "missingDataWait": True, "resumeByteEquality": True, "prioritiesUnchanged": True}
    finally:
        stream.close()
        engine.post("torrents/start", hashes=hash_value)


def _mpv_command(connection, reader, command, request_id):
    connection.sendall((json.dumps({"command": command, "request_id": request_id}) + "\n").encode())
    while True:
        message = json.loads(reader.readline())
        if message.get("request_id") == request_id:
            if message.get("error") == "property unavailable" and command == ["get_property", "playback-time"]:
                return None
            if message.get("error") != "success":
                raise RuntimeError("mpv IPC command failed: " + str(command[0]))
            return message.get("data")


def _source_track_counts(path: Path) -> dict:
    probe = shutil.which("ffprobe")
    if probe is None:
        raise RuntimeError("ffprobe executable not found for source track expectation")
    result = subprocess.run([probe, "-v", "error", "-show_entries", "stream=codec_type", "-of", "json", str(path)],
                            check=True, capture_output=True, text=True)
    streams = json.loads(result.stdout)["streams"]
    return {kind: sum(1 for stream in streams if stream.get("codec_type") == kind)
            for kind in ("video", "audio", "subtitle")}


def first_frame(url, engine, hash_value, source):
    """Observe packaged mpv playback-time via IPC without logging ticket-bearing URL."""
    ipc = ART / "mpv.sock"
    ipc.unlink(missing_ok=True)
    start = time.monotonic()
    with (ART / "mpv.log").open("w") as log:
        player_env = {k: v for k, v in os.environ.items() if k.lower() not in ("http_proxy", "https_proxy", "all_proxy")}
        process = subprocess.Popen(["mpv", "--no-config", "--idle=yes", "--vo=null", "--ao=null",
                                    "--really-quiet", "--cache=yes", "--demuxer-max-bytes=67108864",
                                    "--input-ipc-server=" + str(ipc)], stdout=log, stderr=log, env=player_env)
        try:
            wait_until(ipc.exists, 10)
            connection = socket.socket(socket.AF_UNIX)
            connection.settimeout(5)
            connection.connect(str(ipc))
            connection.sendall((json.dumps({"command": ["loadfile", url]}) + "\n").encode())
            reader = connection.makefile("rb")
            deadline = time.monotonic() + 90
            position = None
            request_id = 1
            while time.monotonic() < deadline:
                current = _mpv_command(connection, reader, ["get_property", "playback-time"], request_id)
                request_id += 1
                if isinstance(current, (int, float)) and current > 0:
                    position = current
                if position is not None:
                    first_frame_seconds = time.monotonic() - start
                    info = engine.get("torrents/info", hashes=hash_value)[0]
                    assert info["progress"] < 1, "first frame occurred after completion"
                    # Freeze transfer immediately at first frame so track checks
                    # cannot change how much of the synthetic movie is buffered.
                    engine.post("torrents/stop", hashes=hash_value)
                    wait_until(lambda: engine.get("torrents/info", hashes=hash_value)[0]["state"].startswith("stopped"), 10)
                    counts = _source_track_counts(source)
                    observed = {"sourceExpectedCounts": counts, "actualSelectedIds": {}}
                    if counts["audio"] > 1 or counts["subtitle"] > 1:
                        track_deadline = time.monotonic() + 10
                        tracks = []
                        while time.monotonic() < track_deadline:
                            tracks = _mpv_command(connection, reader, ["get_property", "track-list"], request_id)
                            request_id += 1
                            if (sum(t.get("type") == "audio" for t in tracks or []) >= counts["audio"] and
                                    sum(t.get("type") == "sub" for t in tracks or []) >= counts["subtitle"]):
                                break
                            time.sleep(.1)
                        assert sum(t.get("type") == "audio" for t in tracks or []) == counts["audio"], "mpv audio track count differs from source"
                        assert sum(t.get("type") == "sub" for t in tracks or []) == counts["subtitle"], "mpv subtitle track count differs from source"
                        for kind, property_name, expected_count, mpv_kind in (
                                ("audio", "aid", counts["audio"], "audio"),
                                ("subtitle", "sid", counts["subtitle"], "sub")):
                            candidates = [track for track in tracks if track.get("type") == mpv_kind]
                            if expected_count > 1:
                                selected_id = candidates[1]["id"]
                                _mpv_command(connection, reader, ["set_property", property_name, selected_id], request_id)
                                request_id += 1
                                selection_deadline=time.monotonic()+10
                                while time.monotonic()<selection_deadline:
                                    tracks = _mpv_command(connection, reader, ["get_property", "track-list"], request_id)
                                    request_id += 1
                                    selected = [track for track in tracks if track.get("type") == mpv_kind and track.get("selected")]
                                    if len(selected)==1 and selected[0].get("id")==selected_id:break
                                    time.sleep(.05)
                                assert len(selected) == 1 and selected[0].get("id") == selected_id, f"mpv did not select second {kind} track"
                                observed["actualSelectedIds"][kind] = selected[0]["id"]

                    # Stop the torrent while mpv is actively reading. Require a real
                    # cache wait, stable playback position, and advancement after resume.
                    engine.post("torrents/stop", hashes=hash_value)
                    wait_until(lambda: engine.get("torrents/info", hashes=hash_value)[0]["state"].startswith("stopped"), 10)
                    buffer_deadline = time.monotonic() + 15
                    paused_for_cache = False
                    while time.monotonic() < buffer_deadline:
                        paused_for_cache = _mpv_command(connection, reader, ["get_property", "paused-for-cache"], request_id)
                        request_id += 1
                        if paused_for_cache:
                            break
                        time.sleep(.1)
                    assert paused_for_cache, "mpv did not report buffering while the torrent engine was paused"
                    # Require cache-pause to remain asserted while playback time is
                    # unchanged for a continuous second. A short run of equal samples
                    # can catch the decoder between clock updates and falsely report a
                    # settled pause, especially with the v2 fixture's timing.
                    pause_samples = []
                    settle_deadline = time.monotonic() + 5
                    while time.monotonic() < settle_deadline:
                        cache_paused = _mpv_command(connection, reader, ["get_property", "paused-for-cache"], request_id)
                        request_id += 1
                        sample = _mpv_command(connection, reader, ["get_property", "playback-time"], request_id)
                        request_id += 1
                        now = time.monotonic()
                        if cache_paused and isinstance(sample, (int, float)):
                            if pause_samples and abs(sample - pause_samples[-1][1]) >= .02:
                                pause_samples = []
                            pause_samples.append((now, sample))
                            if (now - pause_samples[0][0] >= 1.0
                                    and max(value for _, value in pause_samples) - min(value for _, value in pause_samples) < .02):
                                break
                        else:
                            pause_samples = []
                        time.sleep(.1)
                    assert (len(pause_samples) >= 2 and pause_samples[-1][0] - pause_samples[0][0] >= 1.0
                            and max(value for _, value in pause_samples) - min(value for _, value in pause_samples) < .02), (
                                "mpv playback position did not remain settled during cache wait")
                    pause_position = pause_samples[-1][1]
                    engine.post("torrents/start", hashes=hash_value)
                    engine.post("torrents/addPeers", hashes=hash_value, peers=container_ip("seeder") + ":6881")
                    resume_deadline = time.monotonic() + 25
                    resumed_position = pause_position
                    while time.monotonic() < resume_deadline:
                        resumed_position = _mpv_command(connection, reader, ["get_property", "playback-time"], request_id)
                        request_id += 1
                        if isinstance(resumed_position, (int, float)) and resumed_position > pause_position + .1:
                            break
                        time.sleep(.1)
                    assert isinstance(resumed_position, (int, float)) and resumed_position > pause_position + .1, "mpv did not resume after torrent data became available"
                    observed["bufferResume"] = {"enginePaused": True, "mpvPausedForCache": True,
                                                "stableWhileUnavailable": True, "resumed": True,
                                                "stableSeconds": round(pause_samples[-1][0] - pause_samples[0][0], 3),
                                                "positionAtPause": pause_position, "positionAfterResume": resumed_position}
                    return {"firstFrameSeconds": first_frame_seconds, "positionSeconds": position,
                            "torrentProgress": info["progress"], "downloaded": info["downloaded"], "tracks": observed,
                            "player": subprocess.check_output(["mpv", "--version"], text=True).splitlines()[0],
                            "renderer": "null (decode proof, no screen/display certification)"}
                time.sleep(.1)
            raise TimeoutError("mpv did not begin playback in 90 seconds")
        finally:
            process.terminate()
            try:
                process.wait(5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            ipc.unlink(missing_ok=True)


def run_single(torrent: Path, media_kind="faststart", mode="v1", reset=False, run_id=None):
    ART.mkdir(exist_ok=True)
    down, creds = connect("qbittorrent")
    seed, _ = connect("seeder")
    import libtorrent as lt
    original_info = lt.torrent_info(str(torrent))
    identity = original_info.info_hashes()
    # This is qBittorrent's engine ID, not a generic SHA1 identity. The pinned
    # engine prefers truncated v2 for hybrid and v2; retain full metainfo hashes.
    hash_value = str(identity.v2)[:40] if identity.has_v2() else str(identity.v1)
    # These are dedicated test containers. Reject preexisting fixture rather than delete an unknown job.
    existing = down.get("torrents/info", hashes=hash_value)
    if existing and reset:
        assert existing[0]["save_path"] == "/downloads/" + mode + "-" + media_kind, "refusing to reset unrelated job"
        down.post("torrents/delete", hashes=hash_value, deleteFiles="true")
        wait_until(lambda: not down.get("torrents/info", hashes=hash_value), 10)
        existing = []
    assert not existing, "fixture already present; use explicit scoped fixture reset"
    existing_seed = seed.get("torrents/info", hashes=hash_value)
    if existing_seed:
        assert existing_seed[0]["save_path"] == "/downloads/early-play-source", "unexpected seed ownership"
    else:
        seed.add(torrent, "/downloads/early-play-source", stopped=False)
    wait_until(lambda: seed.get("torrents/info", hashes=hash_value) and
               seed.get("torrents/info", hashes=hash_value)[0]["progress"] == 1, 30)
    down.add(torrent, "/downloads/" + mode + "-" + media_kind, stopped=True, rate=512 * 1024)
    entries = wait_until(lambda: down.get("torrents/files", hash=hash_value), 15)
    info, files = validated_layout(torrent, entries)
    assert len(files) == 1
    selected = files[0]
    assert down.get("torrents/info", hashes=hash_value)[0]["downloaded"] == 0, "payload before selection"
    down.post("torrents/filePrio", hash=hash_value, id=entries[0]["index"], priority=1)
    # preferences must be observed/reconciled by the harness; no blind toggle retries.
    assert down.get("torrents/info", hashes=hash_value)[0]["seq_dl"] is True
    before = down.get("torrents/files", hash=hash_value)
    down.post("torrents/start", hashes=hash_value)
    down.post("torrents/addPeers", hashes=hash_value, peers=container_ip("seeder") + ":6881")
    wait_until(lambda: down.get("torrents/info", hashes=hash_value)[0]["state"] in
               ("downloading", "stalledDL", "stalledUP", "uploading"), 15)
    root = HERE / "harness/state/data" / (mode + "-" + media_kind)
    wait_until(lambda: (root / selected["path"]).is_file(), 15)
    identity = (root / selected["path"]).stat()
    config = {"root": str(root), "qBitUrl": down.base + "/", "qBitUser": creds["username"], "hash": hash_value,
              "generation": 1, "pieceLength": info.piece_length(), "pieceCount": info.num_pieces(),
              "files": files, "targetId": selected["id"], "token": secrets.token_urlsafe(32),
              "identity": {"deviceMajor": os.major(identity.st_dev), "deviceMinor": os.minor(identity.st_dev), "inode": identity.st_ino},
              "savePath": "/downloads/" + mode + "-" + media_kind}
    cfg = ART / "gateway-config.json"
    cfg.write_text(json.dumps(config))
    cfg.chmod(0o600)
    env = dict(os.environ, BRIANI_PROOF_CONFIG=str(cfg), BRIANI_PROOF_QBIT_PASSWORD=creds["password"],
               BRIANI_PROOF_PRIVATE_API="1", DOTNET_CLI_HOME=str(HERE.parents[1] / ".tools/dotnet-home"),
               NUGET_PACKAGES=str(HERE.parents[1] / ".tools/nuget"))
    with (ART / "gateway.log").open("w") as log:
        gateway = subprocess.Popen(["dotnet", "run", "--no-build", "--project", str(HERE / "gateway/Gateway.csproj")],
                                   env=env, stdout=log, stderr=log)
        try:
            wait_until(lambda: _health(), 15)
            url = "http://127.0.0.1:18088/stream/" + config["token"] + "/" + urllib.parse.quote(Path(selected["path"]).name)
            status, headers, body = http_request(url, "HEAD", "bytes=3-7")
            assert status == 200 and int(headers["Content-Length"]) == selected["length"] and not body
            print("proof initial state", json.loads(http_request("http://127.0.0.1:18088/proof/state")[2]), flush=True)
            status, headers, body = http_request(url, range_value="bytes=0-31", timeout=65)
            assert status == 206, f"first byte failed: status={status}, code={json.loads(body).get('code') if status == 503 else 'unexpected'}"
            source = GENERATED / "early-play-source" / selected["path"]
            result = first_frame(url, down, hash_value, source)
            result["gapAndCancellation"] = gap_and_cancel(url, down, hash_value, selected, source)
            # Byte comparisons also exercise backward, suffix, open and multirange fallback.
            for range_value, start, count, status_expected in [
                ("bytes=0-8191", 0, 8192, 206), ("bytes=-4096", selected["length"] - 4096, 4096, 206),
                ("bytes=4096-8191", 4096, 4096, 206), ("bytes=0-1,4-5", 0, selected["length"], 200)]:
                status, headers, body = http_request(url, range_value=range_value, timeout=120)
                with source.open("rb") as oracle:
                    oracle.seek(start)
                    assert body == oracle.read(count), "real-engine response corrupted"
                assert status == status_expected and len(body) == count and int(headers["Content-Length"]) == count
            status, headers, body = http_request(url, range_value=f'bytes={selected["length"]}-')
            assert status == 416 and headers["Content-Range"] == f'bytes */{selected["length"]}'
            after = down.get("torrents/files", hash=hash_value)
            assert [f["priority"] for f in before] == [f["priority"] for f in after], "seek changed priorities"
            assert down.get("torrents/info", hashes=hash_value)[0]["seq_dl"] is True
            result.update({"runId": run_id, "mode": mode, "media": media_kind, "byteComparison": "passed", "headRange": "passed",
                           "priorityUnchanged": True, "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest()})
            (RESULT_DIR / f"{media_kind}-{mode}-result.json").write_text(json.dumps(result, indent=2) + "\n")
            return result
        finally:
            gateway.terminate()
            try: gateway.wait(5)
            except subprocess.TimeoutExpired: gateway.kill(); gateway.wait()
            cfg.unlink(missing_ok=True)


def _health():
    try:
        return http_request("http://127.0.0.1:18088/healthz", timeout=1)[0] == 200
    except (OSError, urllib.error.URLError):
        return False


def metadata_only(run_id=None):
    """Exercise stock stop-on-metadata with explicitly connected isolated peers."""
    import libtorrent as lt
    down, _ = connect('qbittorrent'); seed, _ = connect('seeder')
    # BEP9 metadata exchange is disabled for private torrents by libtorrent.
    # This metadata fixture is non-private while its swarm remains isolated and
    # DHT/PEX/LSD/UPnP/public trackers are all disabled.
    meta = lt.bdecode((GENERATED / 'torrents/Tail metadata-hybrid.torrent').read_bytes())
    meta[b'info'].pop(b'private', None)
    torrent = ART / 'metadata-consent.torrent'; torrent.write_bytes(bytes(lt.bencode(meta)))
    ti = lt.torrent_info(str(torrent)); identity = ti.info_hashes()
    hash_value = str(identity.v2)[:40]
    if not seed.get('torrents/info', hashes=hash_value): seed.add(torrent, '/downloads/early-play-source', stopped=False)
    wait_until(lambda: seed.get('torrents/info', hashes=hash_value) and seed.get('torrents/info', hashes=hash_value)[0]['progress'] == 1, 30)
    existing = down.get('torrents/info', hashes=hash_value)
    if existing:
        assert existing[0]['save_path'] == '/downloads/metadata-consent'
        down.post('torrents/delete',hashes=hash_value,deleteFiles='false')
        wait_until(lambda:not down.get('torrents/info',hashes=hash_value),10)
    for owned in down.get('torrents/info'):
        if owned['save_path'] == '/downloads/metadata-consent' and owned['hash'] != hash_value:
            down.post('torrents/delete', hashes=owned['hash'], deleteFiles='false')
    before = down.get('transfer/info')['dl_info_data']
    paths = {str(p.relative_to(HERE/'harness/state/data')) for p in (HERE/'harness/state/data').rglob('*') if p.is_file()}
    down.post('torrents/add', urls=lt.make_magnet_uri(ti), stopCondition='MetadataReceived', stopped='false',
              autoTMM='false', savepath='/downloads/metadata-consent')
    wait_until(lambda: down.get('torrents/info',hashes=hash_value),10)
    down.post('torrents/addPeers',hashes=hash_value,peers=container_ip('seeder')+':6881')
    wait_until(lambda:down.get('torrents/files',hash=hash_value),120)
    def stopped_without_payload():
        current = down.get('torrents/info',hashes=hash_value)[0]
        assert current['downloaded'] == 0, 'payload began before metadata consent'
        return current if current['state'].startswith('stopped') else None
    observed = wait_until(stopped_without_payload, 15)
    # Observe multiple later snapshots: stopping after metadata must precede payload admission.
    for _ in range(3):
        time.sleep(.25)
        assert down.get('torrents/info',hashes=hash_value)[0]['downloaded']==0
    after = down.get('transfer/info')['dl_info_data']
    current_paths = {str(p.relative_to(HERE/'harness/state/data')) for p in (HERE/'harness/state/data').rglob('*') if p.is_file()}
    assert before == after and paths == current_paths, 'unintended payload during metadata consent'
    files=down.get('torrents/files',hash=hash_value)
    down.post('torrents/delete',hashes=hash_value,deleteFiles='false')
    return {'runId': run_id, 'metadataOnlyApi':'torrents/add stopCondition=MetadataReceived', 'payloadBytesBefore':before,
            'payloadBytesAfter':after, 'downloaded':observed['downloaded'], 'state':observed['state'],
            'payloadFilesUnchanged':True,'fileCount':len(files),
            'fetchMetadataObservation':'POST API exists; trackerless hidden metadata task could not discover explicit peer in this harness; not certified'}


@contextmanager
def gateway_for(down, creds, ti, files, selected, root, save_path):
    wait_until(lambda: (root/selected['path']).is_file(), 30)
    binding = (root/selected['path']).stat()
    identity = ti.info_hashes()
    hash_value = str(identity.v2)[:40] if identity.has_v2() else str(identity.v1)
    config = {'root': str(root), 'qBitUrl': down.base+'/', 'qBitUser': creds['username'], 'hash': hash_value,
              'generation': 1, 'pieceLength': ti.piece_length(), 'pieceCount': ti.num_pieces(), 'files': files,
              'targetId': selected['id'], 'token': secrets.token_urlsafe(32), 'savePath': save_path,
              'identity': {'deviceMajor': os.major(binding.st_dev), 'deviceMinor': os.minor(binding.st_dev), 'inode': binding.st_ino}}
    cfg = ART/'gateway-config.json'; cfg.write_text(json.dumps(config)); cfg.chmod(0o600)
    env = dict(os.environ, BRIANI_PROOF_CONFIG=str(cfg), BRIANI_PROOF_QBIT_PASSWORD=creds['password'],
               BRIANI_PROOF_PRIVATE_API='1', DOTNET_CLI_HOME=str(HERE.parents[1]/'.tools/dotnet-home'), NUGET_PACKAGES=str(HERE.parents[1]/'.tools/nuget'))
    with (ART/'gateway.log').open('w') as log:
        process = subprocess.Popen(['dotnet','run','--no-build','--project',str(HERE/'gateway/Gateway.csproj')],env=env,stdout=log,stderr=log)
        try:
            wait_until(_health,15)
            url='http://127.0.0.1:18088/stream/'+config['token']+'/'+urllib.parse.quote(Path(selected['path']).name)
            yield url, config
        finally:
            process.terminate()
            try: process.wait(5)
            except subprocess.TimeoutExpired: process.kill();process.wait()
            cfg.unlink(missing_ok=True)


def multifile(run_id=None):
    observations=[]
    for mode in ['v1','v2','hybrid']:
        import libtorrent as lt
        down,creds=connect('qbittorrent');seed,_=connect('seeder')
        torrent=GENERATED/f'torrents/fixture-{mode}.torrent'
        ti=lt.torrent_info(str(torrent));identity=ti.info_hashes()
        hash_value=str(identity.v2)[:40] if identity.has_v2() else str(identity.v1)
        save='/downloads/'+mode+'-multifile'
        existing=down.get('torrents/info',hashes=hash_value)
        if existing:
            assert existing[0]['save_path']==save, 'unrelated multifile fixture'
            down.post('torrents/delete',hashes=hash_value,deleteFiles='true')
            wait_until(lambda:not down.get('torrents/info',hashes=hash_value),10)
        if not seed.get('torrents/info',hashes=hash_value):seed.add(torrent,'/downloads',stopped=False)
        wait_until(lambda:seed.get('torrents/info',hashes=hash_value) and seed.get('torrents/info',hashes=hash_value)[0]['progress']==1,30)
        down.add(torrent,save,stopped=True,rate=512*1024)
        entries=wait_until(lambda:down.get('torrents/files',hash=hash_value),15)
        ti,files=validated_layout(torrent,entries)
        selected=next(f for f in files if f['path'].endswith('Tracks 演示.mkv'))
        down.post('torrents/filePrio',hash=hash_value,id='|'.join(str(f['index']) for f in entries),priority=0)
        down.post('torrents/filePrio',hash=hash_value,id=selected['upstreamIndex'],priority=1)
        assert down.get('torrents/info',hashes=hash_value)[0]['downloaded']==0
        for f in files:f['priority']=1 if f['id']==selected['id'] else 0
        observed=down.get('torrents/files',hash=hash_value)
        assert all(f['priority']==(1 if f['index']==selected['upstreamIndex'] else 0) for f in observed)
        if mode=='v1':assert selected['torrentOffset']%ti.piece_length()!=0,'v1 fixture must be nonaligned'
        down.post('torrents/start',hashes=hash_value)
        down.post('torrents/addPeers',hashes=hash_value,peers=container_ip('seeder')+':6881')
        wait_until(lambda:down.get('torrents/info',hashes=hash_value)[0]['state'] in ['downloading','stalledDL','stalledUP','uploading'],15)
        root=HERE/'harness/state/data'/f'{mode}-multifile'
        with gateway_for(down,creds,ti,files,selected,root,save) as (url,cfg):
            code,headers,body=http_request(url,timeout=120)
            expected=(GENERATED/selected['path']).read_bytes()
            assert code==200 and body==expected,'multifile offset/padding byte corruption'
            fence=urllib.request.Request('http://127.0.0.1:18088/proof/fence',data=b'',headers={'X-Proof-Key':cfg['token']},method='POST')
            with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(fence,timeout=5) as response:assert response.status==200
            down.post('torrents/recheck',hashes=hash_value)
            code,_,_=http_request(url,range_value='bytes=0-15',timeout=5)
            assert code==503,'controlled recheck did not synchronously fence generation'
            observations.append({'mode':mode,'torrentOffset':selected['torrentOffset'],'bytesCompared':len(body),
                                 'ignoredFileCount':len(files)-1,'byteEquality':True,'fencedRecheck':True})
    return {'runId': run_id, 'observations':observations}
