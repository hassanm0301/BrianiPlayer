#!/usr/bin/env python3
"""Build deterministic, synthetic playback fixtures and an independent byte-layout oracle."""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from typing import Iterable


PIECE_LENGTH = 256 * 1024


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def probe_tracks(path: Path) -> dict:
    probe = shutil.which("ffprobe")
    if probe is None:
        raise RuntimeError("ffprobe executable not found")
    result = subprocess.run([probe, "-v", "error", "-show_entries", "stream=codec_type,codec_name",
                            "-of", "json", str(path)], check=True, capture_output=True, text=True)
    streams = json.loads(result.stdout)["streams"]
    tracks = {"video": [s["codec_name"] for s in streams if s["codec_type"] == "video"],
              "audio": [s["codec_name"] for s in streams if s["codec_type"] == "audio"],
              "subtitles": [s["codec_name"] for s in streams if s["codec_type"] == "subtitle"]}
    if tracks["video"] != ["h264"] or any(x != "aac" for x in tracks["audio"]):
        raise ValueError(f"unexpected media codecs in {path.name}: {tracks}")
    return tracks


def expected_bytes(path: Path, offset: int, count: int) -> bytes:
    """Read an oracle slice from the immutable generated source; reject short reads."""
    if offset < 0 or count < 0:
        raise ValueError("offset and count must be non-negative")
    with path.open("rb") as f:
        f.seek(offset)
        data = f.read(count)
    if len(data) != count:
        raise EOFError(f"oracle source ended after {len(data)} of {count} requested bytes")
    return data


def v1_layout(files: Iterable[tuple[str, int]], piece_length: int = PIECE_LENGTH) -> dict:
    """Independent BEP3 concatenated-file oracle, including filtered/ignored entries."""
    offset = 0
    entries = []
    for path, length in files:
        entries.append({"path": path, "length": length, "torrent_offset": offset,
                        "first_piece": offset // piece_length,
                        "last_piece": (offset + length - 1) // piece_length if length else None})
        offset += length
    return {"format": "v1", "piece_length": piece_length, "torrent_length": offset, "files": entries}


def aligned_layout(files: Iterable[tuple[str, int]], piece_length: int = PIECE_LENGTH,
                   *, format: str) -> dict:
    """Per-file piece-aligned address-space oracle for v2/hybrid layouts."""
    offset, entries = 0, []
    for path, length in files:
        aligned = ((offset + piece_length - 1) // piece_length) * piece_length
        entries.append({"path": path, "length": length, "torrent_offset": aligned,
                        "alignment_gap_before": aligned - offset,
                        "first_piece": aligned // piece_length,
                        "last_piece": (aligned + length - 1) // piece_length if length else None})
        offset = aligned + length
    return {"format": format, "piece_length": piece_length, "torrent_length": offset, "files": entries}


def run(args: list[str], log: Path) -> None:
    with log.open("wb") as out:
        subprocess.run(args, stdout=out, stderr=subprocess.STDOUT, check=True)


def make_media(root: Path, duration: int) -> list[Path]:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg executable not found")
    root.mkdir(parents=True, exist_ok=True)
    fast = root / "Faststart café [test].mp4"
    tail = root / "Tail metadata.mp4"
    mkv = root / "Tracks 演示.mkv"
    logs = root.parent / "logs"
    work = root.parent / "work"
    logs.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    common = ["-hide_banner", "-loglevel", "error", "-y", "-threads", "1",
              "-f", "lavfi", "-i", f"testsrc2=size=640x360:rate=24:duration={duration}",
              "-f", "lavfi", "-i", f"sine=frequency=440:sample_rate=48000:duration={duration}"]
    encode = ["-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact",
              "-map_metadata", "-1", "-map_chapters", "-1",
              "-c:v", "libx264", "-preset", "ultrafast", "-crf", "28", "-x264-params",
              "scenecut=0:open-gop=0:keyint=48:min-keyint=48", "-pix_fmt", "yuv420p",
              "-c:a", "aac", "-b:a", "96k"]
    run(["ffmpeg", *common, *encode, "-movflags", "+faststart", str(fast)], logs / "ffmpeg-faststart.log")
    run(["ffmpeg", *common, *encode, str(tail)], logs / "ffmpeg-tail.log")
    subs1 = work / "track-1.srt"
    subs2 = work / "track-2.srt"
    subs1.write_text("1\n00:00:00,000 --> 00:00:04,000\nSynthetic subtitle one.\n", encoding="utf-8")
    subs2.write_text("1\n00:00:00,000 --> 00:00:04,000\nDeuxième piste de sous-titres.\n", encoding="utf-8")
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-threads", "1",
         "-f", "lavfi", "-i", f"testsrc2=size=640x360:rate=24:duration={duration}",
         "-f", "lavfi", "-i", f"sine=frequency=440:sample_rate=48000:duration={duration}",
         "-f", "lavfi", "-i", f"sine=frequency=880:sample_rate=48000:duration={duration}",
         "-i", str(subs1), "-i", str(subs2), "-map", "0:v", "-map", "1:a", "-map", "2:a",
         "-map", "3:s", "-map", "4:s", "-metadata:s:a:0", "language=eng", "-metadata:s:a:1", "language=fra",
         "-metadata:s:s:0", "language=eng", "-metadata:s:s:1", "language=fra",
         "-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact",
         "-map_metadata", "-1", "-map_chapters", "-1", "-c:v", "libx264", "-preset", "ultrafast",
         "-crf", "28", "-x264-params", "scenecut=0:open-gop=0:keyint=48:min-keyint=48",
         "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "96k", "-c:s", "srt", str(mkv)], logs / "ffmpeg-mkv.log")
    return [fast, tail, mkv]


def make_payload(path: Path, length: int, seed: int) -> None:
    # Deterministic non-zero bytes make holes/corruption apparent in oracle comparisons.
    with path.open("wb") as f:
        block = bytes(((i * 73 + seed * 19) % 251) + 1 for i in range(65536))
        left = length
        while left:
            part = block[:min(left, len(block))]
            f.write(part)
            left -= len(part)


def _storage_oracle(storage, piece_length: int, *, format: str) -> dict:
    """Read the authoritative entry order, offsets and padding from libtorrent's parsed torrent storage."""
    entries = []
    for i in range(storage.num_files()):
        flags = storage.file_flags(i)
        is_padding = bool(flags & storage.flag_pad_file)
        offset = storage.file_offset(i)
        length = storage.file_size(i)
        entries.append({"path": storage.file_path(i), "length": length, "torrent_offset": offset,
                        "first_piece": offset // piece_length,
                        "last_piece": (offset + length - 1) // piece_length if length else None,
                        "padding": is_padding})
    return {"format": format, "piece_length": piece_length,
            "torrent_length": storage.total_size(), "files": entries}


def _assert_storage_matches_sources(storage, root: Path) -> None:
    actual = {}
    for i in range(storage.num_files()):
        if storage.file_flags(i) & storage.flag_pad_file:
            continue
        rel = storage.file_path(i)
        if rel.startswith(root.name + "/"):
            rel = rel[len(root.name) + 1:]
        actual[rel] = storage.file_size(i)
    expected = {p.relative_to(root).as_posix(): p.stat().st_size for p in root.rglob("*") if p.is_file()
                and p.suffix not in (".torrent", ".log", ".srt") and "work" not in p.parts}
    if actual != expected:
        raise ValueError(f"torrent storage/source mismatch: torrent={actual!r}, source={expected!r}")


def _require_generated(result: dict, label: str) -> None:
    failed = [item for item in result.get("generated", []) if item.get("status") != "generated"]
    if failed:
        details = "; ".join(f"{item.get('mode', item.get('path', 'fixture'))}: {item.get('error', item.get('status'))}"
                             for item in failed)
        raise RuntimeError(f"{label} fixture generation incomplete: {details}")
    if not result.get("generated"):
        raise RuntimeError(f"{label} fixture generation produced no artifacts")


def _set_reproducible_date(torrent) -> None:
    # libtorrent exposes this in the locked fixture binding; preserve compatibility
    # with a future binding lacking it by checking the method explicitly.
    setter = getattr(torrent, "set_creation_date", None)
    if setter is not None:
        setter(0)


def make_torrents(root: Path, modes: list[str], piece_length: int, destination_dir: Path) -> dict:
    try:
        import libtorrent as lt
    except ImportError as exc:
        raise RuntimeError("Python libtorrent binding is unavailable") from exc
    result = {"binding_version": getattr(lt, "__version__", "unknown"), "generated": []}
    for mode in modes:
        fs = lt.file_storage()
        accept = lambda path: not path.lower().endswith((".torrent", ".log", ".srt"))
        lt.add_files(fs, str(root), accept)
        flags = 0
        if mode == "v1" and hasattr(lt.create_torrent, "v1_only"):
            flags = lt.create_torrent.v1_only
        elif mode == "v2" and hasattr(lt.create_torrent, "v2_only"):
            flags = lt.create_torrent.v2_only
        elif mode not in ("v1", "v2", "hybrid"):
            raise ValueError(f"unknown torrent mode {mode}")
        try:
            ct = lt.create_torrent(fs, piece_length, flags)
            _set_reproducible_date(ct)
            ct.set_priv(True)
            ct.set_creator("Briani synthetic fixture generator")
            lt.set_piece_hashes(ct, str(root.parent))
            metainfo = ct.generate()
            destination = destination_dir / f"fixture-{mode}.torrent"
            encoded = lt.bencode(metainfo)  # Verify and serialize the generated metainfo.
            destination.write_bytes(bytes(encoded))
            info = lt.torrent_info(bytes(encoded))
            storage = info.files()
            _assert_storage_matches_sources(storage, root)
        except Exception as exc:
            result["generated"].append({"mode": mode, "status": "blocked", "error": str(exc)})
            continue
        result["generated"].append({"mode": mode, "status": "generated", "path": destination.name,
                                     "layout_oracle": _storage_oracle(storage, piece_length, format=mode)})
    return result


def make_single_file_torrents(media: list[Path], modes: list[str], piece_length: int, destination_dir: Path) -> dict:
    """Create 90-second early-open fixtures with torrent roots matching each media filename."""
    try:
        import libtorrent as lt
    except ImportError as exc:
        raise RuntimeError("Python libtorrent binding is unavailable") from exc
    generated = []
    for path in media:
        root = path.parent / (path.stem + "-torrent")
        root.mkdir(exist_ok=True)
        source = root / path.name
        shutil.copyfile(path, source)
        for mode in modes:
            flags = getattr(lt.create_torrent, f"{mode}_only", 0) if mode in ("v1", "v2") else 0
            fs = lt.file_storage()
            lt.add_files(fs, str(root))
            ct = lt.create_torrent(fs, piece_length, flags)
            _set_reproducible_date(ct)
            ct.set_priv(True)
            ct.set_creator("Briani synthetic fixture generator")
            lt.set_piece_hashes(ct, str(root.parent))
            encoded = bytes(lt.bencode(ct.generate()))
            destination = destination_dir / f"{path.stem}-{mode}.torrent"
            destination.write_bytes(encoded)
            storage = lt.torrent_info(encoded).files()
            _assert_storage_matches_sources(storage, root)
            generated.append({"media": path.name, "mode": mode, "status": "generated", "path": destination.name,
                              "layout_oracle": _storage_oracle(storage, piece_length, format=mode)})
    return {"generated": generated}


def generate(out: Path, duration: int, torrent_modes: list[str], early_play_duration: int = 90) -> dict:
    corpus = out / "corpus"
    media = make_media(corpus, duration)
    payload_dir = corpus / "payloads"
    payload_dir.mkdir(exist_ok=True)
    # Deliberately non-piece-aligned lengths and Unicode/path-space coverage.
    payload_specs = [("neighbour one.bin", 131071, 1), ("ignored Ω.bin", 73123, 2),
                     ("media/雪片.dat", 524301, 3)]
    payloads = []
    for name, size, seed in payload_specs:
        p = payload_dir / name
        p.parent.mkdir(parents=True, exist_ok=True)
        make_payload(p, size, seed)
        payloads.append(p)
    all_files = media + payloads
    codecs = {p: probe_tracks(p) for p in media}
    records = [{"path": p.relative_to(corpus).as_posix(), "size": p.stat().st_size,
                "sha256": sha256(p), "container": p.suffix.lstrip("."),
                "tracks": codecs.get(p, {}), "kind": "synthetic-media" if p in media else "deterministic-payload",
                "provenance": "Generated locally; no third-party media or copyrighted content."} for p in all_files]
    rels = [(r["path"], r["size"]) for r in records]
    torrent_dir = out / "torrents"
    torrent_dir.mkdir(parents=True, exist_ok=True)
    ffmpeg_version = subprocess.run(["ffmpeg", "-version"], check=True, capture_output=True, text=True).stdout.splitlines()[0]
    early_media = make_media(out / "early-play-source", early_play_duration)
    early_records = [{"path": p.relative_to(out).as_posix(), "size": p.stat().st_size,
                      "sha256": sha256(p), "container": p.suffix.lstrip("."),
                      "tracks": probe_tracks(p),
                      "duration_seconds": early_play_duration,
                      "provenance": "Generated locally; no third-party media or copyrighted content."}
                     for i, p in enumerate(early_media)]
    torrent_result = make_torrents(corpus, torrent_modes, PIECE_LENGTH, torrent_dir)
    _require_generated(torrent_result, "corpus")
    early_torrents = make_single_file_torrents(early_media, torrent_modes, PIECE_LENGTH, torrent_dir)
    _require_generated(early_torrents, "early-play")
    metadata = {"generator": "prototypes/playback/fixtures/generate.py", "duration_seconds": duration,
                "ffmpeg": ffmpeg_version,
                "piece_length": PIECE_LENGTH, "files": records,
                "torrent": torrent_result,
                "early_play": {"duration_seconds": early_play_duration, "files": early_records,
                               "torrents": early_torrents}}
    # The manifest excludes its own hash and is stable for a given FFmpeg build/arguments.
    (out / "manifest.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path(__file__).parent / "generated")
    parser.add_argument("--duration", type=int, default=90)
    parser.add_argument("--early-play-duration", type=int, default=90)
    parser.add_argument("--torrent-modes", nargs="+", choices=["v1", "v2", "hybrid"], default=["v1", "v2", "hybrid"])
    args = parser.parse_args()
    if not 2 <= args.duration <= 120:
        parser.error("duration must be between 2 and 120 seconds")
    if not 2 <= args.early_play_duration <= 120:
        parser.error("early-play-duration must be between 2 and 120 seconds")
    result = generate(args.out.resolve(), args.duration, args.torrent_modes, args.early_play_duration)
    print(json.dumps({"manifest": str((args.out.resolve() / 'manifest.json')), "torrent": result["torrent"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
