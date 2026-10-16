#!/usr/bin/env python3
"""Measure qBittorrent piece order for Briani's sequential + first/last-piece flow.

Bounded experiment on an internal Docker bridge with generated, non-copyrighted
data and the locked qBittorrent image: one rate-limited seeder, one downloader.
For each variant it records when the selected video's last piece completes
relative to how much of the video has arrived. A working tail assist finishes
the last piece while the video is still mostly missing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
TEMP_PASSWORD = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)
LAYOUTS = {
    "simple": (256 * 1024, [("movie/a.en.srt", 2048), ("movie/clip.mp4", 48 * 1024 * 1024), ("movie/poster.jpg", 40 * 1024)], 1),
    # Sintel's shape: 128 KiB pieces, subtitles before and after the video, poster last.
    "sintel": (128 * 1024, [*[(f"movie/clip.{l}.srt", 1500 + i) for i, l in enumerate(["de", "en", "es", "fr", "it"])],
                            ("movie/clip.mp4", 48 * 1024 * 1024 + 12345),
                            *[(f"movie/clip.{l}.srt", 1530 + i) for i, l in enumerate(["nl", "pl", "pt", "ru"])],
                            ("movie/poster.jpg", 46115)], 5),
}
PIECE, FILES, VIDEO_INDEX = LAYOUTS["simple"]
SELECT_ALL, DOWNLOAD_LIMIT = False, 0
NUDGE_AFTER = 10.0


def run(*args: str, timeout: int = 60) -> str:
    p = subprocess.run(list(args), text=True, capture_output=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(f"{args[0]} {args[1]} failed ({p.returncode}): {(p.stderr or '')[-800:]}")
    return p.stdout.strip()


def bencode(value: object) -> bytes:
    if isinstance(value, int):
        return b"i" + str(value).encode() + b"e"
    if isinstance(value, bytes):
        return str(len(value)).encode() + b":" + value
    if isinstance(value, list):
        return b"l" + b"".join(bencode(v) for v in value) + b"e"
    if isinstance(value, dict):
        return b"d" + b"".join(bencode(k) + bencode(value[k]) for k in sorted(value)) + b"e"
    raise TypeError(type(value).__name__)


class QBit:
    def __init__(self, origin: str, password: str):
        self.origin = origin.rstrip("/")
        form = urllib.parse.urlencode({"username": "admin", "password": password}).encode()
        request = urllib.request.Request(self.origin + "/api/v2/auth/login", data=form,
                                         headers={"Origin": self.origin, "Referer": self.origin + "/"})
        with self._open(request) as response:
            cookie = response.headers.get("Set-Cookie", "")
        if not re.search(r"(?:SID|QBT_SID(?:_[^=;]+)?)=", cookie):
            raise RuntimeError("qBittorrent login returned no session cookie")
        self.cookie = cookie.split(";", 1)[0]

    @staticmethod
    def _open(request: urllib.request.Request):
        return urllib.request.build_opener(urllib.request.ProxyHandler({})).open(request, timeout=10)

    def post(self, path: str, fields: dict[str, str] | None = None, files: dict[str, bytes] | None = None) -> bytes:
        headers = {"Cookie": self.cookie}
        if files:
            boundary = uuid.uuid4().hex
            parts = []
            for key, value in (fields or {}).items():
                parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
            for key, value in files.items():
                parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"; filename="{key}.torrent"\r\n'
                             f'Content-Type: application/x-bittorrent\r\n\r\n'.encode() + value + b"\r\n")
            data = b"".join(parts) + f"--{boundary}--\r\n".encode()
            headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        else:
            data = urllib.parse.urlencode(fields or {}).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        try:
            with self._open(urllib.request.Request(f"{self.origin}/api/v2/{path}", data=data, headers=headers)) as r:
                return r.read()
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"/api/v2/{path} -> HTTP {error.code}: {error.read(200)!r}") from error

    def get(self, path: str, **query: str) -> object:
        url = f"{self.origin}/api/v2/{path}" + ("?" + urllib.parse.urlencode(query) if query else "")
        with self._open(urllib.request.Request(url, headers={"Cookie": self.cookie})) as r:
            body = r.read()
        return json.loads(body) if body else None


def make_fixture(root: Path) -> tuple[bytes, str, list[tuple[int, int]]]:
    """Writes random payload files and returns (torrent, infohash, video piece range)."""
    payload = bytearray()
    entries = []
    for rel, size in FILES:
        data = os.urandom(size)
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        payload += data
        entries.append({b"length": size, b"path": [p.encode() for p in rel.split("/")[1:]]})
    pieces = b"".join(hashlib.sha1(payload[o:o + PIECE]).digest() for o in range(0, len(payload), PIECE))
    info = {b"files": entries, b"name": b"movie", b"piece length": PIECE, b"pieces": pieces}
    start = sum(size for _, size in FILES[:VIDEO_INDEX])
    end = start + FILES[VIDEO_INDEX][1] - 1
    return bencode({b"info": info}), hashlib.sha1(bencode(info)).hexdigest(), [(start // PIECE, end // PIECE)]


def start_container(name: str, network: str, data: Path, config: Path, run_id: str) -> tuple[str, str]:
    config.mkdir(mode=0o700)
    run("docker", "run", "--detach", "--name", name, "--network", network,
        "--label", "org.briani.test=piece-order", "--label", f"org.briani.run={run_id}",
        "-e", f"PUID={os.getuid()}", "-e", f"PGID={os.getgid()}", "-e", "WEBUI_PORT=8080", "-e", "TORRENTING_PORT=6881",
        "-v", f"{config}:/config", "-v", f"{data}:/data", IMAGE)
    password = None
    for _ in range(90):
        logs = run("docker", "logs", name) + subprocess.run(["docker", "logs", name], capture_output=True, text=True).stderr
        match = TEMP_PASSWORD.search(logs)
        password = match.group(1) if match else password
        if password and "8080 port [tcp/http-alt] succeeded!" in logs:
            break
        time.sleep(1)
    else:
        raise RuntimeError(f"{name} did not become ready")
    address = json.loads(run("docker", "inspect", name))[0]["NetworkSettings"]["Networks"][network]["IPAddress"]
    for _ in range(30):
        try:
            socket.create_connection((address, 8080), timeout=2).close()
            break
        except OSError:
            time.sleep(1)
    return address, password


def wait(predicate, timeout: float, label: str, every: float = 0.25):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(every)
    raise TimeoutError(label)


def torrent(q: QBit, infohash: str) -> dict:
    rows = q.get("torrents/info", hashes=infohash)
    return rows[0] if rows else {}


VARIANTS = {
    # Briani's production order: magnet, metadata stop, all files 0, then selection groups.
    "briani-magnet": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="none"),
    "retoggle-after-prio": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="twice"),
    "retoggle-after-delay": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="twice", delay=2.0),
    "flp-on-after-delay": dict(source="magnet", sequential=True, add_flp=False, zero_stage=True, toggle="on", delay=2.0),
    "torrent-file": dict(source="file", sequential=True, add_flp=True, zero_stage=True, toggle="none"),
    "baseline-seq-no-prio": dict(source="file", sequential=True, add_flp=True, zero_stage=False, toggle="none"),
    "baseline-noseq-no-prio": dict(source="file", sequential=False, add_flp=True, zero_stage=False, toggle="none"),
    "flp-without-sequential": dict(source="magnet", sequential=False, add_flp=True, zero_stage=True, toggle="none"),
    "retoggle-while-running": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="none", running_toggle=True),
    # Fix candidate: re-send the unchanged file priorities until the tail arrives.
    "briani-magnet-reapply": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="none", reapply=True),
    # Fix candidate: re-apply first/last with an off/on toggle (prioritize_pieces only) until the tail arrives.
    "briani-magnet-retoggle": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="none", retoggle=True),
    # Head-of-line blocking: measure stalls of the contiguous edge, optionally nudging with stop/start.
    "hol-baseline": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="none", retoggle=True),
    "hol-nudge": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="none", retoggle=True, nudge=True),
    # Candidate fix: sequential off until the first/last assist pieces exist, then sequential on.
    "assist-phase-then-sequential": dict(source="magnet", sequential=True, add_flp=True, zero_stage=True, toggle="none", assist_phase=True),
}


def run_variant(name: str, q: QBit, seed_ip: str, infohash: str, metainfo: bytes,
                video: tuple[int, int], data_root: Path) -> dict:
    opts = VARIANTS[name]
    savepath = f"/data/{name}"
    (data_root / name).mkdir()
    magnet = f"magnet:?xt=urn:btih:{infohash}&dn=movie"
    common = {"savepath": savepath, "autoTMM": "false", "sequentialDownload": str(opts["sequential"]).lower(),
              "firstLastPiecePrio": str(opts["add_flp"]).lower()}
    if opts["source"] == "file":
        q.post("torrents/add", {**common, "stopped": "true"}, files={"torrents": metainfo})
        wait(lambda: torrent(q, infohash), 30, "torrent row")
    else:
        q.post("torrents/add", {**common, "urls": magnet, "stopCondition": "MetadataReceived", "stopped": "false"})
        wait(lambda: torrent(q, infohash), 30, "magnet row")
        q.post("torrents/addPeers", {"hashes": infohash, "peers": seed_ip})
        wait(lambda: torrent(q, infohash).get("has_metadata") or torrent(q, infohash).get("total_size", -1) > 0, 90, "metadata")
    if opts["zero_stage"]:
        # Briani: stop, every file to priority 0 (metadata stage).
        q.post("torrents/stop", {"hashes": infohash})
        every = "|".join(str(i) for i in range(len(FILES)))
        q.post("torrents/filePrio", {"hash": infohash, "id": every, "priority": "0"})
        # Briani selection: stop, priority groups (unselected 0, then selected 1).
        q.post("torrents/stop", {"hashes": infohash})
        if SELECT_ALL:
            q.post("torrents/filePrio", {"hash": infohash, "id": every, "priority": "1"})
        else:
            others = "|".join(str(i) for i in range(len(FILES)) if i != VIDEO_INDEX)
            q.post("torrents/filePrio", {"hash": infohash, "id": others, "priority": "0"})
            q.post("torrents/filePrio", {"hash": infohash, "id": str(VIDEO_INDEX), "priority": "1"})
    time.sleep(opts.get("delay", 0))
    if opts["toggle"] in ("twice", "on"):
        q.post("torrents/toggleFirstLastPiecePrio", {"hashes": infohash})
    if opts["toggle"] == "twice":
        q.post("torrents/toggleFirstLastPiecePrio", {"hashes": infohash})
    row = torrent(q, infohash)
    flags = {"seq_dl": row.get("seq_dl"), "f_l_piece_prio": row.get("f_l_piece_prio")}
    if opts.get("assist_phase") and row.get("seq_dl"):
        q.post("torrents/toggleSequentialDownload", {"hashes": infohash})
    q.post("torrents/start", {"hashes": infohash})
    q.post("torrents/addPeers", {"hashes": infohash, "peers": seed_ip})
    if DOWNLOAD_LIMIT:
        q.post("torrents/setDownloadLimit", {"hashes": infohash, "limit": str(DOWNLOAD_LIMIT)})
    first, last = video
    count = last - first + 1
    assist = max(1, -(-int(FILES[VIDEO_INDEX][1] * 0.01) // PIECE))  # qBittorrent's first/last span
    sequential_on_at = None
    if opts.get("running_toggle"):
        time.sleep(2)
        q.post("torrents/toggleFirstLastPiecePrio", {"hashes": infohash})
        q.post("torrents/toggleFirstLastPiecePrio", {"hashes": infohash})
    tail = max(1, -(-int(FILES[VIDEO_INDEX][1] * 0.01) // PIECE))  # the last 1%
    timeline = []
    t0 = time.monotonic()
    result = {"variant": name, "flagsBeforeStart": flags}
    while time.monotonic() - t0 < 400:
        states = q.get("torrents/pieceStates", hash=infohash) or []
        video_states = states[first:last + 1]
        if len(video_states) != count:
            time.sleep(0.25)
            continue
        if "initial" not in result:
            result["initial"] = {"done": sum(1 for s in video_states if s == 2),
                                 "tailDone": all(s == 2 for s in video_states[-tail:])}
        done = sum(1 for s in video_states if s == 2)
        contiguous = next((i for i, s in enumerate(video_states) if s != 2), count)
        tail_done = all(s == 2 for s in video_states[-tail:])
        if opts.get("retoggle") and not all(x == 2 for x in video_states[:assist] + video_states[-assist:]) \
                and time.monotonic() - result.get("_lastReapply", -99) >= 3:
            result["_lastReapply"] = time.monotonic()
            result["retoggled"] = result.get("retoggled", 0) + 1
            q.post("torrents/toggleFirstLastPiecePrio", {"hashes": infohash})
            q.post("torrents/toggleFirstLastPiecePrio", {"hashes": infohash})
            result["flagAfterRetoggle"] = torrent(q, infohash).get("f_l_piece_prio")
        stall = result.setdefault("_stall", {"edge": -1, "since": 0.0, "max": 0.0})
        now_t = time.monotonic() - t0
        if contiguous != stall["edge"]:
            stall["edge"], stall["since"] = contiguous, now_t
        else:
            stall["max"] = max(stall["max"], now_t - stall["since"])
            if opts.get("nudge") and contiguous < count and now_t - stall["since"] >= NUDGE_AFTER and done - contiguous >= 8 \
                    and now_t - result.get("_lastNudge", -99) >= 15:
                result["_lastNudge"] = now_t
                result["nudges"] = result.get("nudges", 0) + 1
                q.post("torrents/stop", {"hashes": infohash})
                wait(lambda: str(torrent(q, infohash).get("state", "")).startswith("stopped"), 15, "stop")
                q.post("torrents/start", {"hashes": infohash})
                q.post("torrents/addPeers", {"hashes": infohash, "peers": seed_ip})
        if opts.get("reapply") and not tail_done and time.monotonic() - result.get("_lastReapply", -99) >= 3:
            result["_lastReapply"] = time.monotonic()
            result["reapplied"] = result.get("reapplied", 0) + 1
            if SELECT_ALL:
                q.post("torrents/filePrio", {"hash": infohash, "id": "|".join(str(i) for i in range(len(FILES))), "priority": "1"})
            else:
                q.post("torrents/filePrio", {"hash": infohash, "id": str(VIDEO_INDEX), "priority": "1"})
        if opts.get("assist_phase") and sequential_on_at is None and \
                all(s == 2 for s in video_states[:assist] + video_states[-assist:]):
            q.post("torrents/toggleSequentialDownload", {"hashes": infohash})
            sequential_on_at = round(time.monotonic() - t0, 2)
            result["sequentialOnAt"] = {"seconds": sequential_on_at, "done": done, "contiguous": contiguous}
        timeline.append({"t": round(time.monotonic() - t0, 2), "done": done, "contiguous": contiguous, "tailDone": tail_done,
                         "tailStates": "".join(str(x) for x in video_states[-tail:])})
        if tail_done and "tailCompleteAtFraction" not in result:
            result["tailCompleteAtFraction"] = round(done / count, 3)
            result["tailCompleteAtSeconds"] = timeline[-1]["t"]
        if done == count:
            break
        time.sleep(0.25)
    result.pop("_lastReapply", None)
    result.pop("_lastNudge", None)
    stall = result.pop("_stall", None)
    if stall:
        result["maxEdgeStallSeconds"] = round(stall["max"], 1)
    result["videoPieces"] = count
    result["tailPieces"] = tail
    result["completedSeconds"] = timeline[-1]["t"] if timeline else None
    result["samples"] = [s for i, s in enumerate(timeline) if i % 8 == 0 or s is timeline[-1]]
    q.post("torrents/delete", {"hashes": infohash, "deleteFiles": "true"})
    wait(lambda: not torrent(q, infohash), 30, "delete")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variants", default=",".join(VARIANTS))
    parser.add_argument("--seed-rate", type=int, default=1_500_000, help="seeder upload limit, bytes/s")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--layout", choices=sorted(LAYOUTS), default="simple")
    parser.add_argument("--seeders", type=int, default=1)
    parser.add_argument("--select-all", action="store_true")
    parser.add_argument("--download-limit", type=int, default=0, help="per-torrent limit applied right after start")
    parser.add_argument("--slow-seed-rate", type=int, default=0, help="upload limit for the last seeder only")
    parser.add_argument("--nudge-after", type=float, default=10.0, help="edge stall seconds before a stop/start nudge")
    args = parser.parse_args()
    global PIECE, FILES, VIDEO_INDEX, SELECT_ALL, DOWNLOAD_LIMIT
    PIECE, FILES, VIDEO_INDEX = LAYOUTS[args.layout]
    SELECT_ALL, DOWNLOAD_LIMIT = args.select_all, args.download_limit
    global NUDGE_AFTER
    NUDGE_AFTER = args.nudge_after
    output_args = vars(args).copy()
    run_id = uuid.uuid4().hex[:12]
    network = f"briani-pieceorder-{run_id}"
    names = {**{f"seed{i}": f"briani-po-seed{i}-{run_id}" for i in range(args.seeders)}, "down": f"briani-po-down-{run_id}"}
    state = Path(tempfile.mkdtemp(prefix="briani-pieceorder-"))
    state.chmod(0o700)
    seed_data, down_data = state / "seed", state / "down"
    seed_data.mkdir()
    down_data.mkdir()
    output: dict[str, object] = {"image": IMAGE, "pieceLength": PIECE, "files": FILES, "seedRate": args.seed_rate}
    try:
        metainfo, infohash, video = make_fixture(seed_data / "payload")
        output["infohash"] = infohash
        run("docker", "network", "create", "--internal", "--label", "org.briani.test=piece-order",
            "--label", f"org.briani.run={run_id}", network)
        seeds, seed_ips = [], []
        for i in range(args.seeders):
            ip, pw = start_container(names[f"seed{i}"], network, seed_data, state / f"seed{i}-config", run_id)
            seeds.append(QBit(f"http://{ip}:8080", pw))
            seed_ips.append(f"{ip}:6881")
        down_ip, down_pw = start_container(names["down"], network, down_data, state / "down-config", run_id)
        down = QBit(f"http://{down_ip}:8080", down_pw)
        output["args"] = {k: str(v) for k, v in output_args.items()}
        for q in (*seeds, down):
            q.post("app/setPreferences", {"json": json.dumps({"dht": False, "pex": False, "lsd": False, "upnp": False})})
        for i, seed in enumerate(seeds):
            rate = args.slow_seed_rate if args.slow_seed_rate and i == len(seeds) - 1 else args.seed_rate
            seed.post("app/setPreferences", {"json": json.dumps({"up_limit": rate})})
            seed.post("torrents/add", {"savepath": "/data/payload", "autoTMM": "false", "skip_checking": "true", "stopped": "false"},
                      files={"torrents": metainfo})
            wait(lambda: torrent(seed, infohash).get("state") in ("uploading", "stalledUP", "queuedUP", "forcedUP"), 60, "seeder ready")
        seed_ip = "|".join(seed_ips)
        results = []
        for variant in args.variants.split(","):
            results.append(run_variant(variant, down, seed_ip, infohash, metainfo, video[0], down_data))
            print(json.dumps({k: v for k, v in results[-1].items() if k != "samples"}), flush=True)
        output["results"] = results
        output["result"] = "completed"
        return 0
    except Exception as error:  # noqa: BLE001
        output["result"] = "failed"
        output["detail"] = TEMP_PASSWORD.sub("<redacted>", str(error))[:1000]
        print(json.dumps({"result": "failed", "detail": output["detail"]}))
        return 1
    finally:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(output, indent=1) + "\n", encoding="utf-8")
        for name in names.values():
            subprocess.run(["docker", "rm", "--force", name], capture_output=True)
        subprocess.run(["docker", "network", "rm", network], capture_output=True)
        shutil.rmtree(state, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
