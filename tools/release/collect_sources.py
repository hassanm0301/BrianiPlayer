#!/usr/bin/env python3
"""Collect bounded, hash-inventoried native source archives and notices.

Archives are retained as downloaded; this tool never extracts an archive. The
manifest distinguishes immutable upstream source identity from proof that a
source archive corresponds to a particular shipped binary.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import sys
import tempfile
import urllib.error
import urllib.request
from typing import BinaryIO, Callable

SCHEMA = 1
ANDROID_BUILDER_COMMIT = "fe8c3ac1a91c09aa6fb1deccbc833f1bafa54768"
ANDROID_MPV_COMMIT = "78d43740f52db817d98bcf24fb30a76ab6fa13ff"
FFMPEG_902_SHA256 = "8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e"
DEPENDENCY_COMMITS = {
    "libass": "e8ad72accd3a84268275a9385beb701c9284e5b3",
    "harfbuzz": "a321c4fee56b15247c10f9aa3db7e7ccb3b8173b",
    "fribidi": "6428d8469e536bcbb6e12c7b79ba6659371c435a",
    "freetype": "de8b92dd7ec634e9e2b25ef534c54a3537555c11",
    "mbedtls": "1873d3bfc2da771672bd8e7e8f41f57e0af77f33",
    "dav1d": "676a864a11af2c0522e1f992e770589543894686",
    "libxml2": "f507d167f1755b7eaea09fb1a44d29aab828b6d1",
    "ffmpeg-6.0": "ea3d24bbe3c58b171e55fe2151fc7ffaca3ab3d2",
    "ffmpeg-9.0.2": "946fcce07b6dcd0331c8cc609192aeff5e1924f8",
}
ALLOWED_HOSTS = {"github.com", "codeload.github.com", "raw.githubusercontent.com",
                 "objects.githubusercontent.com", "ffmpeg.org", "www.ffmpeg.org", "code.videolan.org"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def sources() -> list[dict[str, object]]:
    """Pinned Android default-flavor and server FFmpeg inputs.

    Version-tagged Android dependencies are identified by depinfo.sh. Their
    archive digests are recorded when fetched, but the mutable tag names and
    unknown binary build correspondence remain explicit limitations.
    """
    rows: list[dict[str, object]] = [
        {"id": "android-builder", "name": "media-kit libmpv Android builder", "version": ANDROID_BUILDER_COMMIT,
         "url": f"https://codeload.github.com/media-kit/libmpv-android-video-build/tar.gz/{ANDROID_BUILDER_COMMIT}",
         "path": "dist/sources/android/libmpv-android-video-build-fe8c3ac.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": ANDROID_BUILDER_COMMIT, "identity": "immutable commit archive"},
        {"id": "android-builder-license", "name": "Android builder license", "version": ANDROID_BUILDER_COMMIT,
         "url": f"https://raw.githubusercontent.com/media-kit/libmpv-android-video-build/{ANDROID_BUILDER_COMMIT}/LICENSE",
         "path": "dist/notices/android-builder-LICENSE", "kind": "license", "expectedSha256": None,
         "sourceRevision": ANDROID_BUILDER_COMMIT, "identity": "immutable commit raw file"},
        {"id": "android-builder-depinfo", "name": "Android builder dependency declarations", "version": ANDROID_BUILDER_COMMIT,
         "url": f"https://raw.githubusercontent.com/media-kit/libmpv-android-video-build/{ANDROID_BUILDER_COMMIT}/buildscripts/include/depinfo.sh",
         "path": "dist/sources/android/depinfo.sh", "kind": "build-metadata", "expectedSha256": None,
         "sourceRevision": ANDROID_BUILDER_COMMIT, "identity": "immutable commit raw file"},
        {"id": "android-mpv", "name": "mpv", "version": ANDROID_MPV_COMMIT,
         "url": f"https://codeload.github.com/mpv-player/mpv/tar.gz/{ANDROID_MPV_COMMIT}",
         "path": "dist/sources/android/mpv-78d43740.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": ANDROID_MPV_COMMIT, "identity": "immutable commit archive"},
        {"id": "android-mpv-copyright", "name": "mpv copyright and license notices", "version": ANDROID_MPV_COMMIT,
         "url": f"https://raw.githubusercontent.com/mpv-player/mpv/{ANDROID_MPV_COMMIT}/Copyright",
         "path": "dist/notices/mpv-Copyright", "kind": "license", "expectedSha256": None,
         "sourceRevision": ANDROID_MPV_COMMIT, "identity": "immutable commit raw file"},
        {"id": "android-ffmpeg", "name": "FFmpeg Android dependency", "version": "6.0",
         "url": "https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz", "path": "dist/sources/android/ffmpeg-6.0.tar.xz",
         "kind": "source-archive", "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["ffmpeg-6.0"],
         "identity": "official 6.0 release archive; version tag resolution recorded; downloaded-byte digest recorded, upstream sidecar SHA-256 unavailable"},
        {"id": "android-ffmpeg-license", "name": "FFmpeg 6.0 license text", "version": "6.0",
         "url": f"https://raw.githubusercontent.com/FFmpeg/FFmpeg/{DEPENDENCY_COMMITS['ffmpeg-6.0']}/LICENSE.md",
         "path": "dist/notices/ffmpeg-6.0-LICENSE.md", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["ffmpeg-6.0"], "identity": "n6.0 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "android-ffmpeg-lgpl", "name": "FFmpeg 6.0 LGPLv2.1 text", "version": "6.0",
         "url": f"https://raw.githubusercontent.com/FFmpeg/FFmpeg/{DEPENDENCY_COMMITS['ffmpeg-6.0']}/COPYING.LGPLv2.1",
         "path": "dist/notices/ffmpeg-6.0-COPYING.LGPLv2.1", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["ffmpeg-6.0"], "identity": "n6.0 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "android-libass", "name": "libass", "version": "0.17.1",
         "url": f"https://codeload.github.com/libass/libass/tar.gz/{DEPENDENCY_COMMITS['libass']}",
         "path": f"dist/sources/android/libass-0.17.1-{DEPENDENCY_COMMITS['libass'][:8]}.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["libass"],
         "identity": "version tag 0.17.1 resolved by upstream GitHub API to immutable commit; digest recorded on fetch"},
        {"id": "android-libass-license", "name": "libass upstream license text", "version": "0.17.1",
         "url": f"https://raw.githubusercontent.com/libass/libass/{DEPENDENCY_COMMITS['libass']}/COPYING",
         "path": "dist/notices/libass-COPYING", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["libass"], "identity": "0.17.1 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "android-harfbuzz", "name": "HarfBuzz", "version": "7.2.0",
         "url": f"https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/{DEPENDENCY_COMMITS['harfbuzz']}",
         "path": f"dist/sources/android/harfbuzz-7.2.0-{DEPENDENCY_COMMITS['harfbuzz'][:8]}.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["harfbuzz"],
         "identity": "version tag 7.2.0 resolved by upstream GitHub API to immutable commit; digest recorded on fetch"},
        {"id": "android-harfbuzz-license", "name": "HarfBuzz upstream license text", "version": "7.2.0",
         "url": f"https://raw.githubusercontent.com/harfbuzz/harfbuzz/{DEPENDENCY_COMMITS['harfbuzz']}/COPYING",
         "path": "dist/notices/harfbuzz-COPYING", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["harfbuzz"], "identity": "7.2.0 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "android-fribidi", "name": "FriBidi", "version": "1.0.12",
         "url": f"https://codeload.github.com/fribidi/fribidi/tar.gz/{DEPENDENCY_COMMITS['fribidi']}",
         "path": f"dist/sources/android/fribidi-1.0.12-{DEPENDENCY_COMMITS['fribidi'][:8]}.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["fribidi"],
         "identity": "version tag v1.0.12 resolved by upstream GitHub API to immutable commit; digest recorded on fetch"},
        {"id": "android-fribidi-license", "name": "FriBidi upstream license text", "version": "1.0.12",
         "url": f"https://raw.githubusercontent.com/fribidi/fribidi/{DEPENDENCY_COMMITS['fribidi']}/COPYING",
         "path": "dist/notices/fribidi-COPYING", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["fribidi"], "identity": "v1.0.12 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "android-freetype", "name": "FreeType", "version": "2-13-0",
         "url": f"https://codeload.github.com/freetype/freetype/tar.gz/{DEPENDENCY_COMMITS['freetype']}",
         "path": f"dist/sources/android/freetype-2-13-0-{DEPENDENCY_COMMITS['freetype'][:8]}.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["freetype"],
         "identity": "version tag VER-2-13-0 resolved by upstream GitHub API to immutable commit; digest recorded on fetch"},
        {"id": "android-freetype-license", "name": "FreeType upstream license text", "version": "2-13-0",
         "url": f"https://raw.githubusercontent.com/freetype/freetype/{DEPENDENCY_COMMITS['freetype']}/LICENSE.TXT",
         "path": "dist/notices/freetype-LICENSE.TXT", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["freetype"], "identity": "VER-2-13-0 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "android-mbedtls", "name": "mbedTLS", "version": "3.4.0",
         "url": f"https://codeload.github.com/Mbed-TLS/mbedtls/tar.gz/{DEPENDENCY_COMMITS['mbedtls']}",
         "path": f"dist/sources/android/mbedtls-3.4.0-{DEPENDENCY_COMMITS['mbedtls'][:8]}.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["mbedtls"],
         "identity": "version tag v3.4.0 resolved by upstream GitHub API to immutable commit; digest recorded on fetch"},
        {"id": "android-mbedtls-license", "name": "mbedTLS upstream license text", "version": "3.4.0",
         "url": f"https://raw.githubusercontent.com/Mbed-TLS/mbedtls/{DEPENDENCY_COMMITS['mbedtls']}/LICENSE",
         "path": "dist/notices/mbedtls-LICENSE", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["mbedtls"], "identity": "v3.4.0 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "android-dav1d", "name": "dav1d", "version": "1.2.0",
         "url": f"https://code.videolan.org/videolan/dav1d/-/archive/{DEPENDENCY_COMMITS['dav1d']}/dav1d-{DEPENDENCY_COMMITS['dav1d']}.tar.gz",
         "path": f"dist/sources/android/dav1d-1.2.0-{DEPENDENCY_COMMITS['dav1d'][:8]}.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["dav1d"],
         "identity": "version tag 1.2.0 resolved by upstream GitLab API to immutable commit; digest recorded on fetch"},
        {"id": "android-dav1d-license", "name": "dav1d upstream license text", "version": "1.2.0",
         "url": f"https://code.videolan.org/videolan/dav1d/-/raw/{DEPENDENCY_COMMITS['dav1d']}/COPYING",
         "path": "dist/notices/dav1d-COPYING", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["dav1d"], "identity": "1.2.0 tag resolved by upstream GitLab API to immutable commit"},
        {"id": "android-libxml2", "name": "libxml2", "version": "2.10.3",
         "url": f"https://codeload.github.com/GNOME/libxml2/tar.gz/{DEPENDENCY_COMMITS['libxml2']}",
         "path": f"dist/sources/android/libxml2-2.10.3-{DEPENDENCY_COMMITS['libxml2'][:8]}.tar.gz", "kind": "source-archive",
         "expectedSha256": None, "sourceRevision": DEPENDENCY_COMMITS["libxml2"],
         "identity": "version tag v2.10.3 resolved by upstream GitHub API to immutable commit; digest recorded on fetch"},
        {"id": "android-libxml2-license", "name": "libxml2 upstream copyright notice", "version": "2.10.3",
         "url": f"https://raw.githubusercontent.com/GNOME/libxml2/{DEPENDENCY_COMMITS['libxml2']}/Copyright",
         "path": "dist/notices/libxml2-Copyright", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["libxml2"], "identity": "v2.10.3 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "server-ffmpeg", "name": "FFmpeg server", "version": "9.0.2",
         "url": "https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz", "path": "dist/sources/server/ffmpeg-9.0.2.tar.xz",
         "kind": "source-archive", "expectedSha256": FFMPEG_902_SHA256, "sourceRevision": DEPENDENCY_COMMITS["ffmpeg-9.0.2"],
         "identity": "Dockerfile source URL and pinned SHA-256; n9.0.2 tag resolved by upstream GitHub API"},
        {"id": "server-ffmpeg-license", "name": "FFmpeg server license text", "version": "9.0.2",
         "url": f"https://raw.githubusercontent.com/FFmpeg/FFmpeg/{DEPENDENCY_COMMITS['ffmpeg-9.0.2']}/LICENSE.md",
         "path": "dist/notices/ffmpeg-9.0.2-LICENSE.md", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["ffmpeg-9.0.2"], "identity": "n9.0.2 tag resolved by upstream GitHub API to immutable commit"},
        {"id": "server-ffmpeg-lgpl", "name": "FFmpeg LGPLv2.1 text", "version": "9.0.2",
         "url": f"https://raw.githubusercontent.com/FFmpeg/FFmpeg/{DEPENDENCY_COMMITS['ffmpeg-9.0.2']}/COPYING.LGPLv2.1",
         "path": "dist/notices/ffmpeg-COPYING.LGPLv2.1", "kind": "license", "expectedSha256": None,
         "sourceRevision": DEPENDENCY_COMMITS["ffmpeg-9.0.2"], "identity": "n9.0.2 tag resolved by upstream GitHub API to immutable commit"},
    ]
    return rows


def safe_destination(root: pathlib.Path, relative: str) -> pathlib.Path:
    rel = pathlib.PurePosixPath(relative)
    if rel.is_absolute() or not rel.parts or any(p in ("", ".", "..") for p in rel.parts):
        raise ValueError(f"unsafe destination path: {relative!r}")
    target = root
    for part in rel.parts:
        target = target / part
        if target.is_symlink():
            raise ValueError(f"symlink destination refused: {relative}")
    if root.resolve() not in (target.parent.resolve(), *target.parent.resolve().parents):
        raise ValueError(f"destination escapes output root: {relative}")
    return target


def _open(url: str) -> BinaryIO:
    request = urllib.request.Request(url, headers={"User-Agent": "BrianiPlayer-source-collector/1.0"})
    opener = urllib.request.build_opener(_SafeRedirectHandler())
    return opener.open(request, timeout=30)


class _SafeRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        from urllib.parse import urlparse
        target = urlparse(newurl)
        if target.scheme != "https" or target.hostname not in ALLOWED_HOSTS or target.username or target.password:
            raise ValueError("redirect left HTTPS source host allowlist")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class ByteBudget:
    def __init__(self, limit: int):
        self.limit = limit
        self.used = 0

    @property
    def remaining(self) -> int:
        return self.limit - self.used

    def consume(self, count: int) -> None:
        if count > self.remaining:
            raise ValueError(f"total byte limit reached ({self.limit})")
        self.used += count


def download_one(root: pathlib.Path, item: dict[str, object], *, max_bytes: int,
                 opener: Callable[[str], BinaryIO] = _open,
                 budget: ByteBudget | None = None) -> dict[str, object]:
    url = str(item["url"])
    # urlparse lives in urllib.parse, kept local to avoid accepting non-HTTPS schemes.
    from urllib.parse import urlparse
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in ALLOWED_HOSTS or parsed.username or parsed.password:
        raise ValueError(f"source URL is outside HTTPS allowlist: {url}")
    destination = safe_destination(root, str(item["path"]))
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.parent.is_symlink():
        raise ValueError(f"symlink destination directory refused: {item['path']}")
    fd, temp_name = tempfile.mkstemp(prefix=".source-", dir=destination.parent)
    temp = pathlib.Path(temp_name)
    digest = hashlib.sha256()
    size = 0
    try:
        with os.fdopen(fd, "wb") as output, opener(url) as response:
            final = urlparse(response.geturl())
            if final.scheme != "https" or final.hostname not in ALLOWED_HOSTS:
                raise ValueError("redirect left HTTPS source host allowlist")
            length = response.headers.get("Content-Length")
            if length and int(length) > max_bytes:
                raise ValueError(f"source exceeds per-file byte limit ({max_bytes})")
            if length and budget and int(length) > budget.remaining:
                raise ValueError(f"source exceeds total byte limit ({budget.limit})")
            while True:
                if size == max_bytes or (budget is not None and budget.remaining == 0):
                    if length and size == int(length):
                        break
                    raise ValueError("source reached byte limit before end of response")
                capacity = min(1024 * 1024, max_bytes - size)
                if budget is not None:
                    capacity = min(capacity, budget.remaining)
                chunk = response.read(capacity)
                if not chunk:
                    break
                size += len(chunk)
                if size > max_bytes:
                    raise ValueError(f"source exceeds per-file byte limit ({max_bytes})")
                if budget is not None:
                    budget.consume(len(chunk))
                digest.update(chunk)
                output.write(chunk)
            if length and size != int(length):
                raise ValueError(f"truncated response: expected {length} bytes, received {size}")
            output.flush()
            os.fsync(output.fileno())
        actual = digest.hexdigest()
        expected = item.get("expectedSha256")
        if expected is not None and (not isinstance(expected, str) or not SHA256.fullmatch(expected) or actual != expected):
            raise ValueError(f"SHA-256 mismatch: expected {expected}, got {actual}")
        if destination.exists():
            if not destination.is_file() or destination.is_symlink() or destination.stat().st_size != size:
                raise ValueError(f"refusing to replace existing destination: {item['path']}")
            old_digest = hashlib.sha256()
            with destination.open("rb") as old_file:
                for old_chunk in iter(lambda: old_file.read(1024 * 1024), b""):
                    old_digest.update(old_chunk)
            old = old_digest.hexdigest()
            if old != actual:
                raise ValueError(f"refusing to replace existing destination with different bytes: {item['path']}")
            temp.unlink()
        else:
            os.replace(temp, destination)
        return {**item, "status": "collected", "sizeBytes": size, "sha256": actual,
                "path": pathlib.Path(str(item["path"])).as_posix()}
    except Exception:
        temp.unlink(missing_ok=True)
        raise


def write_json(path: pathlib.Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path.cwd(), help="repository root")
    parser.add_argument("--max-file-bytes", type=int, default=512 * 1024 * 1024)
    parser.add_argument("--max-total-bytes", type=int, default=2 * 1024 * 1024 * 1024)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    if args.max_file_bytes <= 0 or args.max_total_bytes <= 0:
        parser.error("byte limits must be positive")
    results: list[dict[str, object]] = []
    blockers: list[str] = [
        "Android APK libmpv binary-to-source/build correspondence is not established by these source pins.",
        "Android native dependency license/notice completeness is not established until exact binary build configuration is recovered.",
        "Server FFmpeg source is paired to Dockerfile SHA/configuration intent; a final installed image/build record was not independently examined by this collector.",
        "Owner public-license authorization is absent; this inventory does not grant a project license or authorize publication.",
    ]
    budget = ByteBudget(args.max_total_bytes)
    for item in sources():
        remaining = budget.remaining
        if remaining <= 0:
            result = {**item, "status": "not-attempted", "error": "total byte limit reached"}
        else:
            bytes_before = budget.used
            try:
                result = download_one(root, item, max_bytes=args.max_file_bytes, budget=budget)
            except (OSError, ValueError, urllib.error.URLError, TimeoutError) as error:
                result = {**item, "status": "missing", "error": f"{type(error).__name__}: {error}",
                          "bytesConsumed": budget.used - bytes_before}
                blockers.append(f"{item['id']}: source/notices unavailable: {error}")
        results.append(result)
    status = "collected_with_blockers" if blockers else "collected"
    manifest = {"schemaVersion": SCHEMA, "status": status, "sourceTreeCommit": None,
                "inventoryKind": "downloaded-source-and-notice-files; not binary correspondence proof",
                "totalBytes": budget.used, "limits": {"maxFileBytes": args.max_file_bytes, "maxTotalBytes": args.max_total_bytes},
                "items": results, "blockers": blockers}
    write_json(root / "dist/sources/manifest.json", manifest)
    print(json.dumps({"status": status, "collected": sum(x.get("status") == "collected" for x in results),
                      "missing": sum(x.get("status") != "collected" for x in results), "totalBytes": budget.used,
                      "manifest": "dist/sources/manifest.json", "blockers": blockers}, indent=2))
    return 0 if all(x.get("status") == "collected" for x in results) and not blockers else 3


if __name__ == "__main__":
    sys.exit(main())
