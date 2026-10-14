#!/usr/bin/env python3
"""Create deterministic archives of locked Dart package source trees.

This packages locally resolved Dart source trees and pinned NuGet publisher
repository archives for review. It does not assert package-to-repository source
correspondence or licensing.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import importlib.util
import json
import os
import pathlib
import re
import sys
import tarfile
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import tempfile
from typing import Any

MAX_PACKAGE_FILES = 100_000
MAX_PACKAGE_BYTES = 512 * 1024 * 1024
MAX_TOTAL_SOURCE_BYTES = 2 * 1024 * 1024 * 1024
MAX_TOTAL_ARCHIVE_BYTES = 2 * 1024 * 1024 * 1024
MAX_PUB_ARCHIVE_BYTES = 64 * 1024 * 1024
MAX_PUB_ARCHIVE_TREE_BYTES = 1024 * 1024 * 1024
MAX_PUB_ARCHIVE_MEMBERS = 100_000
MAX_NUGET_REPO_ARCHIVE_BYTES = 512 * 1024 * 1024
MAX_NUGET_REPO_TOTAL_BYTES = 2 * 1024 * 1024 * 1024
MAX_NUGET_REPO_TREE_BYTES = 4 * 1024 * 1024 * 1024
MAX_NUGET_REPO_TOTAL_TREE_BYTES = 8 * 1024 * 1024 * 1024
MAX_NUGET_REPO_FILES = 250_000
SKIP_DIRS = {".git", ".cxx", ".dart_tool", ".gradle", "build", "ephemeral", "node_modules", "obj", "bin"}
PACKAGE_NAME = re.compile(r"^[a-zA-Z0-9_.+-]+$")


class ArchiveError(ValueError):
    pass


def load_tool(root: pathlib.Path):
    audit_path = pathlib.Path(__file__).resolve().with_name("package_audit.py")
    spec = importlib.util.spec_from_file_location("source_package_audit", audit_path)
    if not spec or not spec.loader:
        raise ArchiveError("package_audit.py unavailable")
    audit = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = audit
    spec.loader.exec_module(audit)
    inventory_path = pathlib.Path(__file__).resolve().with_name("license_inventory.py")
    spec = importlib.util.spec_from_file_location("source_license_inventory", inventory_path)
    if not spec or not spec.loader:
        raise ArchiveError("license_inventory.py unavailable")
    inventory = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = inventory
    spec.loader.exec_module(inventory)
    return audit, inventory


def sha256_file(path: pathlib.Path, max_bytes: int) -> tuple[str, int]:
    if path.is_symlink() or not path.is_file():
        raise ArchiveError(f"expected regular non-symlink file: {path}")
    size = path.stat().st_size
    if size > max_bytes:
        raise ArchiveError(f"file exceeds size limit: {path.name}")
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest(), size


def collect_files(source: pathlib.Path) -> tuple[list[tuple[pathlib.Path, str]], str, int]:
    if source.is_symlink() or not source.is_dir():
        raise ArchiveError(f"package source missing or unsafe: {source}")
    entries: list[tuple[pathlib.Path, str]] = []
    digest = hashlib.sha256()
    total = 0
    for current, dirs, files in os.walk(source, topdown=True, followlinks=False):
        current_path = pathlib.Path(current)
        links = sorted(name for name in dirs if (current_path / name).is_symlink())
        if links:
            raise ArchiveError(f"symlink directory refused: {current_path / links[0]}")
        dirs[:] = sorted(name for name in dirs if name not in SKIP_DIRS)
        for name in sorted(files):
            path = current_path / name
            if path.is_symlink():
                raise ArchiveError(f"symlink file refused: {path}")
            if not path.is_file():
                continue
            rel = path.relative_to(source).as_posix()
            relpath = pathlib.PurePosixPath(rel)
            if relpath.is_absolute() or any(part in ("", ".", "..") for part in relpath.parts):
                raise ArchiveError(f"unsafe source member path: {rel}")
            size = path.stat().st_size
            total += size
            if len(entries) >= MAX_PACKAGE_FILES or total > MAX_PACKAGE_BYTES:
                raise ArchiveError("package source exceeds file-count or uncompressed-byte limit")
            file_hash, _ = sha256_file(path, MAX_PACKAGE_BYTES)
            encoded = rel.encode("utf-8")
            digest.update(len(encoded).to_bytes(8, "big"))
            digest.update(encoded)
            digest.update(bytes.fromhex(file_hash))
            entries.append((path, rel))
    entries.sort(key=lambda pair: pair[1])
    if not entries:
        raise ArchiveError("package source tree is empty after output exclusions")
    return entries, digest.hexdigest(), total


def archive_tree(source: pathlib.Path, destination: pathlib.Path, package_label: str) -> dict[str, Any]:
    entries, tree_hash, total_bytes = collect_files(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.parent.is_symlink() or destination.is_symlink():
        raise ArchiveError("symlink output path refused")
    fd, temp_name = tempfile.mkstemp(prefix=".package-source-", dir=destination.parent)
    temp_path = pathlib.Path(temp_name)
    try:
        with os.fdopen(fd, "wb") as raw:
            with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as zipped:
                with tarfile.open(fileobj=zipped, mode="w", format=tarfile.PAX_FORMAT) as archive:
                    root_name = package_label.strip("/")
                    root_info = tarfile.TarInfo(root_name + "/")
                    root_info.type = tarfile.DIRTYPE
                    root_info.mode = 0o755
                    root_info.uid = root_info.gid = 0
                    root_info.uname = root_info.gname = ""
                    root_info.mtime = 0
                    archive.addfile(root_info)
                    for path, rel in entries:
                        info = tarfile.TarInfo(f"{root_name}/{rel}")
                        info.size = path.stat().st_size
                        mode = path.stat().st_mode
                        info.mode = 0o755 if mode & 0o111 else 0o644
                        info.uid = info.gid = 0
                        info.uname = info.gname = ""
                        info.mtime = 0
                        info.type = tarfile.REGTYPE
                        with path.open("rb") as stream:
                            archive.addfile(info, stream)
            raw.flush()
            os.fsync(raw.fileno())
        archive_hash, archive_bytes = sha256_file(temp_path, MAX_PACKAGE_BYTES + 16 * 1024 * 1024)
        if destination.exists():
            existing_hash, existing_size = sha256_file(destination, MAX_PACKAGE_BYTES + 16 * 1024 * 1024)
            if existing_hash != archive_hash or existing_size != archive_bytes:
                raise ArchiveError(f"refusing to replace different source archive: {destination}")
            temp_path.unlink()
        else:
            os.replace(temp_path, destination)
        return {"archiveSha256": archive_hash, "archiveSizeBytes": archive_bytes,
                "sourceTreeSha256": tree_hash, "sourceTreeSizeBytes": total_bytes,
                "includedFileCount": len(entries)}
    except Exception:
        temp_path.unlink(missing_ok=True)
        raise


class _PubRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlparse(newurl)
        if parsed.scheme != "https" or parsed.hostname != "pub.dev" or parsed.username or parsed.password:
            raise ArchiveError("pub.dev archive redirect left the official HTTPS host")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _pub_archive_files(path: pathlib.Path) -> tuple[dict[str, str], int, int]:
    files: dict[str, str] = {}
    total = count = 0
    try:
        with tarfile.open(path, mode="r|gz") as archive:
            for member in archive:
                relpath = pathlib.PurePosixPath(member.name)
                if relpath.is_absolute() or any(part in ("", ".", "..") for part in relpath.parts):
                    raise ArchiveError("unsafe pub archive member path")
                if member.isdir():
                    continue
                if member.issym() or member.islnk() or not member.isfile():
                    raise ArchiveError("unsupported link or special member in pub archive")
                if any(part in SKIP_DIRS for part in relpath.parts):
                    continue
                if member.name in files:
                    raise ArchiveError("duplicate file path in pub archive")
                count += 1
                total += member.size
                if count > MAX_PUB_ARCHIVE_MEMBERS or total > MAX_PUB_ARCHIVE_TREE_BYTES:
                    raise ArchiveError("pub archive exceeds member-count or uncompressed-byte limit")
                stream = archive.extractfile(member)
                if stream is None:
                    raise ArchiveError("could not read regular pub archive member")
                digest = hashlib.sha256()
                size = 0
                with stream:
                    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                        size += len(chunk)
                        if size > member.size:
                            raise ArchiveError("pub archive member exceeded declared size")
                        digest.update(chunk)
                if size != member.size:
                    raise ArchiveError("pub archive member was truncated")
                files[member.name] = digest.hexdigest()
    except (tarfile.TarError, OSError) as error:
        raise ArchiveError(f"invalid pub source archive: {error}") from error
    if not files:
        raise ArchiveError("pub source archive contains no regular source files")
    return files, count, total


def fetch_pub_source_archive(name: str, version: str, lock_sha256: str, destination: pathlib.Path,
                             byte_budget: int) -> dict[str, Any]:
    if not PACKAGE_NAME.fullmatch(name) or not re.fullmatch(r"[A-Za-z0-9.+_-]+", version):
        raise ArchiveError("unsafe pub archive identity")
    if not re.fullmatch(r"[0-9a-f]{64}", lock_sha256):
        raise ArchiveError("pub archive requires a valid locked SHA-256")
    limit = min(MAX_PUB_ARCHIVE_BYTES, max(0, byte_budget))
    if not limit:
        raise ArchiveError("aggregate source archive byte limit reached")
    quoted_name = urllib.parse.quote(name, safe="-_.")
    quoted_version = urllib.parse.quote(version, safe="-._")
    url = f"https://pub.dev/api/archives/{quoted_name}-{quoted_version}.tar.gz"
    request = urllib.request.Request(url, headers={"User-Agent": "BrianiPlayer-source-audit/1.0"})
    opener = urllib.request.build_opener(_PubRedirectHandler())
    fd, temp_name = tempfile.mkstemp(prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent)
    temp = pathlib.Path(temp_name)
    digest = hashlib.sha256()
    size = 0
    try:
        with os.fdopen(fd, "wb") as output, opener.open(request, timeout=30) as response:
            final = urllib.parse.urlparse(response.geturl())
            if response.status != 200 or final.scheme != "https" or final.hostname != "pub.dev" or response.geturl() != url:
                raise ArchiveError("pub.dev response was not the exact pinned official HTTPS archive URL")
            length = response.headers.get("Content-Length")
            if length and int(length) > limit:
                raise ArchiveError("pub archive exceeds configured compressed-byte limit")
            while True:
                chunk = response.read(min(1024 * 1024, limit - size + 1))
                if not chunk:
                    break
                size += len(chunk)
                if size > limit:
                    raise ArchiveError("pub archive exceeds configured compressed-byte limit")
                digest.update(chunk)
                output.write(chunk)
            if length and size != int(length):
                raise ArchiveError("pub archive response was truncated")
            output.flush()
            os.fsync(output.fileno())
        if digest.hexdigest() != lock_sha256:
            raise ArchiveError("official pub archive SHA-256 differs from pubspec.lock")
        with temp.open("rb") as check:
            if check.read(2) != b"\x1f\x8b":
                raise ArchiveError("pub archive response is not gzip data")
        files, member_count, uncompressed = _pub_archive_files(temp)
        if destination.is_symlink():
            raise ArchiveError("pub source archive destination is a symlink")
        if destination.exists():
            existing_sha, existing_size = sha256_file(destination, MAX_PUB_ARCHIVE_BYTES)
            if existing_sha != lock_sha256 or existing_size != size:
                raise ArchiveError("refusing to replace differing hosted pub source archive")
            temp.unlink()
        else:
            os.replace(temp, destination)
        return {"sourceArchive": destination.relative_to(destination.parents[4]).as_posix(),
                "sourceUrl": url, "archiveSha256": digest.hexdigest(), "archiveSizeBytes": size,
                "archiveTreeFileCount": member_count, "archiveTreeSizeBytes": uncompressed,
                "archiveFiles": files}
    except Exception:
        temp.unlink(missing_ok=True)
        raise


def collect_pub_hosted_archives(root: pathlib.Path, locked: list[tuple[str, str, str]],
                                records: dict[tuple[str, str, str], dict[str, Any]], output: pathlib.Path,
                                budget: int) -> tuple[dict[str, dict[str, Any]], list[str], int]:
    archives: dict[str, dict[str, Any]] = {}
    blockers: list[str] = []
    total_bytes = 0
    archive_dir = output / "pub-hosted"
    archive_dir.mkdir(parents=True, exist_ok=True)
    if archive_dir.is_symlink():
        raise ArchiveError("pub source archive directory is a symlink")
    inventory_path = root / "dist/licenses/inventory.json"
    license_components: dict[str, dict[str, Any]] = {}
    if inventory_path.is_file() and not inventory_path.is_symlink():
        try:
            license_components = {c["purl"]: c for c in json.loads(inventory_path.read_text(encoding="utf-8")).get("components", [])}
        except (OSError, json.JSONDecodeError):
            license_components = {}
    for ecosystem, name, version in locked:
        if ecosystem != "pub":
            continue
        detail = records.get((ecosystem, name.lower(), version), {})
        if detail.get("source") != "hosted":
            continue
        purl = f"pkg:pub/{name}@{version}"
        host = urllib.parse.urlparse(detail.get("url", "https://pub.dev"))
        if host.scheme != "https" or host.hostname != "pub.dev" or host.username or host.password or host.path not in ("", "/"):
            blockers.append(f"{purl}: hosted lock URL is not official pub.dev")
            continue
        lock_sha = detail.get("sha256")
        destination = archive_dir / f"{name.lower()}-{version}.tar.gz"
        if not lock_sha:
            blockers.append(f"{purl}: original pub archive SHA-256 missing from lock")
            continue
        if destination.is_file() and not destination.is_symlink():
            try:
                archive_sha, archive_size = sha256_file(destination, MAX_PUB_ARCHIVE_BYTES)
                if archive_sha != lock_sha:
                    raise ArchiveError("existing hosted archive differs from locked SHA-256")
                files, member_count, uncompressed = _pub_archive_files(destination)
                evidence = {"sourceArchive": destination.relative_to(destination.parents[4]).as_posix(),
                            "sourceUrl": f"https://pub.dev/api/archives/{urllib.parse.quote(name, safe='-_.')}-{urllib.parse.quote(version, safe='-._')}.tar.gz",
                            "archiveSha256": archive_sha, "archiveSizeBytes": archive_size,
                            "archiveTreeFileCount": member_count, "archiveTreeSizeBytes": uncompressed,
                            "archiveFiles": files}
            except (ArchiveError, OSError) as error:
                blockers.append(f"{purl}: {error}")
                continue
        else:
            remaining = budget - total_bytes
            if remaining <= 0:
                blockers.append(f"{purl}: aggregate hosted pub archive byte limit reached")
                continue
            try:
                evidence = fetch_pub_source_archive(name, version, lock_sha, destination, remaining)
            except (ArchiveError, OSError, TimeoutError, urllib.error.URLError, ValueError) as error:
                blockers.append(f"{purl}: {error}")
                continue
        total_bytes += evidence["archiveSizeBytes"]
        component = license_components.get(purl, {})
        cache_root = pathlib.Path(component["sourcePath"]) if component.get("sourcePath") else None
        cache_files: dict[str, str] = {}
        try:
            if cache_root is not None:
                cache_files = {rel: sha256_file(path, MAX_PACKAGE_BYTES)[0]
                               for path, rel in collect_files(cache_root)[0]}
        except (ArchiveError, OSError) as error:
            blockers.append(f"{purl}: cached tree could not be compared with locked archive: {error}")
        same_tree = bool(cache_files) and cache_files == evidence["archiveFiles"]
        evidence_without_files = {k: v for k, v in evidence.items() if k != "archiveFiles"}
        evidence_without_files["cacheTreeMatchesLockedArchive"] = same_tree
        evidence_without_files["sourceCorrespondence"] = "exact archive SHA-256 matches pub lock; tree comparison is cache evidence only"
        archives[purl] = evidence_without_files
        if len(archives) % 25 == 0:
            print(f"verified {len(archives)} locked pub source archives so far", file=sys.stderr, flush=True)
        if cache_files and not same_tree:
            blockers.append(f"{purl}: resolved cache tree differs from official locked source archive")
    return archives, blockers, total_bytes


def source_origin(kind: str, name: str, version: str, details: dict[str, str],
                  root: pathlib.Path, package_root: pathlib.Path, pub_cache: pathlib.Path,
                  flutter_revision: str | None) -> tuple[str | None, str | None]:
    if kind == "hosted":
        host = details.get("url", "https://pub.dev").rstrip("/")
        return (f"{host}/packages/{name}/versions/{version}",
                package_root.relative_to(pub_cache).as_posix() if pub_cache in package_root.parents else None)
    if kind == "sdk":
        origin = f"https://github.com/flutter/flutter/tree/{flutter_revision}" if flutter_revision else None
        return origin, None
    if kind == "path":
        try:
            return None, package_root.relative_to(root).as_posix()
        except ValueError:
            return None, None
    return None, None


def collect_nuget_repository_pins(root: pathlib.Path) -> dict[str, Any]:
    """Record immutable upstream repository commits from official cached nuspecs.

    These refs identify publisher-declared repositories only; they do not claim
    that a repository tree is the corresponding source for a binary package.
    """
    metadata = root / "dist/licenses/metadata/nuget"
    records: list[dict[str, Any]] = []
    files = sorted(metadata.glob("*.upstream.nuspec")) if metadata.is_dir() else []
    if len(files) > 1000:
        raise ArchiveError("NuGet nuspec metadata file-count limit exceeded")
    for nuspec in files:
        if nuspec.is_symlink() or not nuspec.is_file() or nuspec.stat().st_size > 2 * 1024 * 1024:
            raise ArchiveError(f"unsafe or oversized upstream nuspec: {nuspec.name}")
        try:
            package = ET.fromstring(nuspec.read_bytes())
        except (ET.ParseError, OSError) as error:
            raise ArchiveError(f"invalid upstream nuspec: {nuspec.name}") from error
        metadata_node = next((node for node in package if node.tag.endswith("metadata")), None)
        if metadata_node is None:
            continue
        by_local_name = {node.tag.rsplit("}", 1)[-1]: node for node in metadata_node}
        identity = (by_local_name.get("id").text or "").strip() if by_local_name.get("id") is not None else ""
        version = (by_local_name.get("version").text or "").strip() if by_local_name.get("version") is not None else ""
        repository = by_local_name.get("repository")
        if repository is None:
            continue
        url = repository.attrib.get("url", "").strip().rstrip("/")
        commit = repository.attrib.get("commit", "").strip().lower()
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or parsed.hostname != "github.com" or parsed.username or parsed.password or parsed.query or parsed.fragment:
            continue
        if not re.fullmatch(r"/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?", parsed.path) or not re.fullmatch(r"[0-9a-f]{40}", commit):
            continue
        sha, size = sha256_file(nuspec, 2 * 1024 * 1024)
        records.append({"package": identity, "version": version, "repositoryUrl": url,
                        "commit": commit, "declaredBy": "official NuGet flat-container nuspec",
                        "nuspecPath": nuspec.relative_to(root).as_posix(),
                        "nuspecSha256": sha, "nuspecSizeBytes": size,
                        "sourceArchive": None,
                        "correspondence": "publisher-declared repository commit only; not verified as corresponding package source"})
    records.sort(key=lambda r: (r["package"].lower(), r["version"], r["repositoryUrl"], r["commit"]))
    return {"schemaVersion": 1, "repositoryCommitCount": len(records),
            "sourceArchiveCount": 0,
            "policy": "references are immutable upstream pins from official nuspec metadata; no source correspondence is asserted",
            "repositories": records}


class _CodeloadRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlparse(newurl)
        if parsed.scheme != "https" or parsed.hostname != "codeload.github.com" or parsed.username or parsed.password:
            raise ArchiveError("GitHub source archive redirect left the allowlisted HTTPS host")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _validate_github_tarball(path: pathlib.Path, uncompressed_limit: int = MAX_NUGET_REPO_TREE_BYTES) -> tuple[int, int]:
    total = count = 0
    limit = min(MAX_NUGET_REPO_TREE_BYTES, max(0, uncompressed_limit))
    try:
        with tarfile.open(path, mode="r:gz") as archive:
            for member in archive:
                count += 1
                if count > MAX_NUGET_REPO_FILES:
                    raise ArchiveError("upstream repository archive exceeds member-count limit")
                name = pathlib.PurePosixPath(member.name)
                if name.is_absolute() or any(part in ("", ".", "..") for part in name.parts):
                    raise ArchiveError("unsafe upstream repository archive member path")
                if member.issym() or member.islnk():
                    link = pathlib.PurePosixPath(member.linkname)
                    if link.is_absolute():
                        raise ArchiveError("absolute link in upstream repository archive")
                    combined = (name.parent / link) if member.issym() else link
                    depth = 0
                    for part in combined.parts:
                        if part == "..":
                            depth -= 1
                        elif part not in ("", "."):
                            depth += 1
                        if depth < 0:
                            raise ArchiveError("escaping link in upstream repository archive")
                elif not (member.isfile() or member.isdir()):
                    raise ArchiveError("unsupported special file in upstream repository archive")
                if member.isfile():
                    total += member.size
                    if total > limit:
                        raise ArchiveError("upstream repository archive exceeds uncompressed-byte limit")
    except (tarfile.TarError, OSError) as error:
        raise ArchiveError(f"invalid upstream GitHub source tarball: {error}") from error
    return count, total


def fetch_github_source_archive(repository_url: str, commit: str, destination: pathlib.Path,
                                byte_limit: int, tree_byte_limit: int = MAX_NUGET_REPO_TREE_BYTES) -> dict[str, Any]:
    parsed = urllib.parse.urlparse(repository_url)
    if parsed.scheme != "https" or parsed.hostname != "github.com" or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ArchiveError("repository URL is not an allowlisted GitHub HTTPS URL")
    pieces = [part for part in parsed.path.strip("/").split("/") if part]
    if len(pieces) != 2 or not re.fullmatch(r"[A-Za-z0-9_.-]+", pieces[0]) or not re.fullmatch(r"[A-Za-z0-9_.-]+(?:\.git)?", pieces[1]):
        raise ArchiveError("unsafe repository path for source archive URL")
    repo = pieces[1].removesuffix(".git")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ArchiveError("source archive requires a full immutable commit SHA")
    limit = min(MAX_NUGET_REPO_ARCHIVE_BYTES, max(0, byte_limit))
    if not limit:
        raise ArchiveError("aggregate source archive byte limit reached")
    url = f"https://codeload.github.com/{pieces[0]}/{repo}/tar.gz/{commit}"
    request = urllib.request.Request(url, headers={"User-Agent": "BrianiPlayer-source-audit/1.0"})
    opener = urllib.request.build_opener(_CodeloadRedirectHandler())
    fd, temp_name = tempfile.mkstemp(prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent)
    temp = pathlib.Path(temp_name)
    digest = hashlib.sha256()
    size = 0
    try:
        with os.fdopen(fd, "wb") as output, opener.open(request, timeout=30) as response:
            final = urllib.parse.urlparse(response.geturl())
            if response.status != 200 or final.scheme != "https" or final.hostname != "codeload.github.com" or response.geturl() != url:
                raise ArchiveError("GitHub codeload response was not the exact pinned allowlisted HTTPS URL")
            length = response.headers.get("Content-Length")
            if length and int(length) > limit:
                raise ArchiveError("GitHub codeload archive exceeds configured compressed-byte limit")
            while True:
                chunk = response.read(min(1024 * 1024, limit - size + 1))
                if not chunk:
                    break
                size += len(chunk)
                if size > limit:
                    raise ArchiveError("GitHub codeload archive exceeds configured compressed-byte limit")
                digest.update(chunk)
                output.write(chunk)
            if length and size != int(length):
                raise ArchiveError("GitHub codeload archive response was truncated")
            output.flush()
            os.fsync(output.fileno())
        with temp.open("rb") as check:
            if size < 2 or check.read(2) != b"\x1f\x8b":
                raise ArchiveError("GitHub codeload response is not a gzip archive")
        members, uncompressed = _validate_github_tarball(temp, tree_byte_limit)
        if destination.is_symlink():
            raise ArchiveError("source archive destination is a symlink")
        if destination.exists():
            existing_sha, existing_size = sha256_file(destination, MAX_NUGET_REPO_ARCHIVE_BYTES)
            if existing_sha != digest.hexdigest() or existing_size != size:
                raise ArchiveError("refusing to replace different source archive for immutable commit")
            temp.unlink()
        else:
            os.replace(temp, destination)
        return {"sourceArchive": destination.relative_to(destination.parents[4]).as_posix(),
                "archiveSha256": digest.hexdigest(), "archiveSizeBytes": size,
                "uncompressedBytes": uncompressed, "tarMemberCount": members, "sourceUrl": url}
    except Exception:
        temp.unlink(missing_ok=True)
        raise


def fetch_nuget_repository_archives(pins: dict[str, Any], output: pathlib.Path,
                                    compressed_budget: int = MAX_NUGET_REPO_TOTAL_BYTES) -> tuple[dict[tuple[str, str], dict[str, Any]], list[str]]:
    repos = sorted({(r["repositoryUrl"], r["commit"]) for r in pins["repositories"]})
    results: dict[tuple[str, str], dict[str, Any]] = {}
    blockers: list[str] = []
    total = total_uncompressed = 0
    prior: dict[tuple[str, str], dict[str, Any]] = {}
    prior_path = output / "nuget-repository-pins.json"
    if prior_path.is_file() and not prior_path.is_symlink() and prior_path.stat().st_size <= 16 * 1024 * 1024:
        try:
            old_pins = json.loads(prior_path.read_text(encoding="utf-8"))
            prior = {(r.get("repositoryUrl"), r.get("commit")): r.get("sourceArchiveEvidence")
                     for r in old_pins.get("repositories", []) if isinstance(r, dict)}
        except (OSError, json.JSONDecodeError):
            prior = {}
    archive_dir = output / "nuget-repositories"
    archive_dir.mkdir(parents=True, exist_ok=True)
    if archive_dir.is_symlink():
        raise ArchiveError("NuGet repository archive directory is a symlink")
    for url, commit in repos:
        parsed = urllib.parse.urlparse(url)
        pieces = parsed.path.strip("/").removesuffix(".git").split("/")
        label = "-".join(pieces)
        destination = archive_dir / f"{label}-{commit}.tar.gz"
        remaining = min(MAX_NUGET_REPO_TOTAL_BYTES, compressed_budget) - total
        old_evidence = prior.get((url, commit))
        if isinstance(old_evidence, dict):
            expected_rel = destination.relative_to(output.parents[2]).as_posix()
            if old_evidence.get("sourceArchive") == expected_rel and destination.is_file() and not destination.is_symlink():
                try:
                    archive_sha, archive_size = sha256_file(destination, MAX_NUGET_REPO_ARCHIVE_BYTES)
                    if archive_sha == old_evidence.get("archiveSha256") and archive_size == old_evidence.get("archiveSizeBytes"):
                        member_count, uncompressed = _validate_github_tarball(
                            destination, MAX_NUGET_REPO_TOTAL_TREE_BYTES - total_uncompressed)
                        results[(url, commit)] = {**old_evidence, "sourceUrl": old_evidence.get("sourceUrl"),
                            "tarMemberCount": member_count, "uncompressedBytes": uncompressed,
                            "repositoryUrl": url, "commit": commit}
                        total += archive_size
                        total_uncompressed += uncompressed
                        continue
                except (ArchiveError, OSError):
                    pass
        remaining_tree = MAX_NUGET_REPO_TOTAL_TREE_BYTES - total_uncompressed
        if remaining <= 0 or remaining_tree <= 0:
            blockers.append(f"{url}@{commit}: aggregate repository archive byte limit reached")
            continue
        try:
            result = fetch_github_source_archive(url, commit, destination, remaining, remaining_tree)
            total += result["archiveSizeBytes"]
            total_uncompressed += result["uncompressedBytes"]
            if total > MAX_NUGET_REPO_TOTAL_BYTES:
                raise ArchiveError("aggregate repository archive byte limit exceeded")
            result.update({"repositoryUrl": url, "commit": commit})
            results[(url, commit)] = result
        except (ArchiveError, OSError, TimeoutError, urllib.error.URLError, ValueError) as error:
            blockers.append(f"{url}@{commit}: {error}")
    return results, blockers


def build(root: pathlib.Path, pub_cache: pathlib.Path, output: pathlib.Path) -> dict[str, Any]:
    audit, inventory_tool = load_tool(root)
    locks = audit.discover_lockfiles(root)
    locked = sorted((c for c in audit.locked_components(root, locks) if c[0] == "pub"),
                    key=lambda c: (c[1].lower(), c[2]))
    records = {}
    for lock in locks:
        if lock.name == "pubspec.lock":
            records.update(inventory_tool.pub_lock_records(lock, root))
    roots = inventory_tool.package_config_roots(root)
    _, flutter_revision = inventory_tool.flutter_revision(root)
    try:
        license_inventory = json.loads((root / "dist/licenses/inventory.json").read_text(encoding="utf-8"))
        existing_components = {c["purl"]: c for c in license_inventory.get("components", [])}
    except (OSError, json.JSONDecodeError):
        existing_components = {}
    output_root = output.resolve(strict=False)
    if output_root != root and root not in output_root.parents:
        raise ArchiveError("output directory must be inside repository root")
    base = output_root
    base.mkdir(parents=True, exist_ok=True)
    if base.is_symlink():
        raise ArchiveError("source output directory is a symlink")
    items: list[dict[str, Any]] = []
    blockers: list[str] = []
    total_source = total_archives = 0
    for ecosystem, name, version in locked:
        if not PACKAGE_NAME.fullmatch(name) or not re.fullmatch(r"[A-Za-z0-9.+_-]+", version):
            raise ArchiveError("unsafe locked package identity")
        key = (ecosystem, name.lower(), version)
        detail = records.get(key, {})
        kind = detail.get("source")
        purl = f"pkg:pub/{name}@{version}"
        # package_config can resolve a different version when the workspace's
        # active graph differs from a lockfile being inventoried. For hosted
        # packages, use the exact versioned pub-cache directory discovered by
        # the license inventory rather than archiving that unrelated root.
        package_root = roots.get(name.lower())
        inventory_source = existing_components.get(purl, {}).get("sourcePath")
        if kind == "hosted" and inventory_source:
            package_root = pathlib.Path(inventory_source)
        entry: dict[str, Any] = {"purl": purl, "name": name, "version": version,
                                 "sourceKind": kind, "lockFiles": existing_components.get(purl, {}).get("lockFiles", []),
                                 "lockedOriginalArchiveSha256": detail.get("sha256"),
                                 "sourceUrl": None, "sourceRelativePath": None,
                                 "sourceTreeSha256": None, "sourceArchive": None}
        try:
            if not package_root:
                raise ArchiveError("package_config source root unavailable")
            if package_root.is_symlink() or not package_root.is_dir():
                raise ArchiveError("resolved package source root missing or symlinked")
            source_url, relative = source_origin(kind or "", name, version, detail, root,
                                                 package_root, pub_cache, flutter_revision)
            entry["sourceUrl"] = source_url
            entry["sourceRelativePath"] = relative
            existing_tree_hash = existing_components.get(purl, {}).get("sourceTreeSha256")
            rel_archive = f"dist/sources/packages/{name.lower()}-{version}.tar.gz"
            destination = root / rel_archive
            try:
                packed = archive_tree(package_root, destination, f"{name}-{version}")
            except ArchiveError as error:
                if not destination.is_file() or "refusing to replace different source archive" not in str(error):
                    raise
                prior_sha, prior_size = sha256_file(destination, MAX_PACKAGE_BYTES + 16 * 1024 * 1024)
                source_tree_hash = collect_files(package_root)[1]
                versioned_rel = f"dist/sources/packages/{name.lower()}-{version}-{source_tree_hash[:12]}.tar.gz"
                versioned_dest = root / versioned_rel
                packed = archive_tree(package_root, versioned_dest, f"{name}-{version}")
                entry["retainedPreviousArchive"] = {"path": rel_archive, "archiveSha256": prior_sha,
                    "archiveSizeBytes": prior_size, "note": "preserved previous generated artifact; it contained excluded .cxx build fingerprints"}
                rel_archive = versioned_rel
                destination = versioned_dest
            total_source += packed["sourceTreeSizeBytes"]
            total_archives += packed["archiveSizeBytes"]
            if total_source > MAX_TOTAL_SOURCE_BYTES or total_archives > MAX_TOTAL_ARCHIVE_BYTES:
                destination.unlink(missing_ok=True)
                raise ArchiveError("total package source input or archive size exceeds configured cap")
            if existing_tree_hash and existing_tree_hash != packed["sourceTreeSha256"]:
                blockers.append(f"{purl}: source tree hash differs from license inventory")
            entry.update(packed)
            entry["licenseInventorySourceTreeSha256"] = existing_tree_hash
            entry["sourceArchive"] = rel_archive
            if kind == "hosted":
                host = detail.get("url", "https://pub.dev").rstrip("/")
                safe_host = re.sub(r"[^a-zA-Z0-9_.-]", "_", host)
                sidecar = pub_cache / "hosted-hashes" / safe_host / f"{name}-{version}.sha256"
                if sidecar.is_file() and not sidecar.is_symlink():
                    entry["hostedCacheRecordedArchiveSha256"] = sidecar.read_text(encoding="ascii").strip()
                    if detail.get("sha256") and entry["hostedCacheRecordedArchiveSha256"] != detail["sha256"]:
                        blockers.append(f"{purl}: pub cache archive sidecar differs from lock")
                else:
                    entry["hostedCacheRecordedArchiveSha256"] = None
            items.append(entry)
        except (OSError, ArchiveError, ValueError) as error:
            entry["error"] = str(error)
            blockers.append(f"{purl}: {error}")
            items.append(entry)
    pub_hosted_archives, pub_hosted_blockers, pub_hosted_bytes = collect_pub_hosted_archives(
        root, locked, records, base, MAX_TOTAL_ARCHIVE_BYTES - total_archives)
    total_archives += pub_hosted_bytes
    item_by_purl = {item["purl"]: item for item in items}
    for item in items:
        if item["purl"] in pub_hosted_archives:
            item["hostedArchiveEvidence"] = pub_hosted_archives[item["purl"]]
    blockers.extend(pub_hosted_blockers)
    pins = collect_nuget_repository_pins(root)
    repo_sources, repo_fetch_blockers = fetch_nuget_repository_archives(
        pins, base, MAX_TOTAL_ARCHIVE_BYTES - total_archives)
    for repo_record in pins["repositories"]:
        repo_key = (repo_record["repositoryUrl"], repo_record["commit"])
        repo_record["sourceArchiveEvidence"] = repo_sources.get(repo_key)
    pins["sourceArchiveCount"] = len(repo_sources)
    pins["sourceArchiveBlockers"] = repo_fetch_blockers
    pins["unresolvedPackageCount"] = sum(
        not repo_record.get("sourceArchiveEvidence") for repo_record in pins["repositories"])
    nuget_source_blockers: list[str] = list(repo_fetch_blockers)
    pub_source_blockers: list[str] = list(pub_hosted_blockers)
    pin_by_identity = {(r["package"].lower(), r["version"]): r for r in pins["repositories"]}
    license_inventory_path = root / "dist/licenses/inventory.json"
    sbom_path = root / "dist/sbom.json"
    if license_inventory_path.is_file() and not license_inventory_path.is_symlink():
        license_data = json.loads(license_inventory_path.read_text(encoding="utf-8"))
        for component in license_data.get("components", []):
            if component.get("ecosystem") == "pub":
                purl = component.get("purl", "")
                evidence = pub_hosted_archives.get(purl)
                if evidence:
                    component["correspondingSource"] = {
                        "kind": "official_pub_archive_sha256_verified_against_lock",
                        "archivePath": evidence["sourceArchive"],
                        "archiveSha256": evidence["archiveSha256"],
                        "archiveSizeBytes": evidence["archiveSizeBytes"],
                        "cacheTreeMatchesLockedArchive": evidence["cacheTreeMatchesLockedArchive"],
                        "correspondenceNote": "official archive hash matches pubspec.lock; this is not build/binary correspondence proof"}
                else:
                    item = item_by_purl.get(purl, {})
                    source_kind = component.get("sourceKind")
                    if source_kind in {"sdk", "path"} and item.get("sourceArchive"):
                        component["correspondingSource"] = {
                            "kind": "resolved_local_package_tree_archive",
                            "archivePath": item["sourceArchive"],
                            "archiveSha256": item.get("archiveSha256"),
                            "sourceTreeSha256": item.get("sourceTreeSha256"),
                            "sourceKind": source_kind, "sourceUrl": item.get("sourceUrl"),
                            "correspondenceNote": "captured SDK/workspace/vendor tree only; no upstream archive or build correspondence is asserted"}
                    elif source_kind == "hosted":
                        pub_source_blockers.append(f"{purl}: verified original pub archive unavailable")
                continue
            if component.get("ecosystem") != "nuget":
                continue
            identity = (component.get("name", "").lower(), component.get("version", ""))
            pin = pin_by_identity.get(identity)
            evidence = repo_sources.get((pin["repositoryUrl"], pin["commit"])) if pin else None
            if evidence:
                component["correspondingSource"] = {
                    "kind": "publisher_declared_repository_commit_archive",
                    "repositoryUrl": pin["repositoryUrl"], "commit": pin["commit"],
                    "archivePath": evidence["sourceArchive"],
                    "archiveSha256": evidence["archiveSha256"],
                    "archiveSizeBytes": evidence["archiveSizeBytes"],
                    "correspondenceNote": "declared by the official version-specific nuspec; not a reproducible-build or package-file correspondence proof"}
            else:
                reason = "no immutable repository commit in official nuspec" if not pin else "declared repository source archive unavailable"
                nuget_source_blockers.append(f"pkg:nuget/{component.get('name')}@{component.get('version')}: {reason}")
        source_blockers = sorted(set(nuget_source_blockers + pub_source_blockers))
        license_data["sourceBlockers"] = source_blockers
        tmp_inventory = license_inventory_path.with_suffix(".json.tmp")
        tmp_inventory.write_text(json.dumps(license_data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(tmp_inventory, license_inventory_path)
    if sbom_path.is_file() and not sbom_path.is_symlink():
        sbom_data = json.loads(sbom_path.read_text(encoding="utf-8"))
        for component in sbom_data.get("components", []):
            purl = component.get("purl", "")
            if purl.startswith("pkg:nuget/"):
                match = re.fullmatch(r"pkg:nuget/([^@]+)@([^?]+)", purl)
                if not match:
                    continue
                pin = pin_by_identity.get((match.group(1).lower(), match.group(2)))
                evidence = repo_sources.get((pin["repositoryUrl"], pin["commit"])) if pin else None
                repository = pin["repositoryUrl"] if pin else "unavailable"
                commit = pin["commit"] if pin else "unavailable"
            elif purl.startswith("pkg:pub/"):
                evidence = pub_hosted_archives.get(purl)
                pub_item = item_by_purl.get(purl, {})
                if evidence:
                    repository = "https://pub.dev"
                    archive_path = evidence["sourceArchive"]
                else:
                    repository = pub_item.get("sourceUrl") or "local resolved package tree"
                    archive_path = pub_item.get("sourceArchive")
                    evidence = {"sourceArchive": archive_path} if archive_path else None
                commit = "unavailable"
            else:
                continue
            properties = component.setdefault("properties", [])
            source_property_names = {"briani:declaredSourceArchive", "briani:declaredSourceRepository",
                                     "briani:declaredSourceCommit", "briani:sourceCorrespondence"}
            properties[:] = [p for p in properties if p.get("name") not in source_property_names]
            properties.append({"name": "briani:declaredSourceArchive",
                               "value": evidence["sourceArchive"] if evidence else "unavailable"})
            properties.append({"name": "briani:declaredSourceRepository", "value": repository})
            properties.append({"name": "briani:declaredSourceCommit", "value": commit})
            properties.append({"name": "briani:sourceCorrespondence",
                               "value": ("pub lock archive SHA-256 verified" if purl.startswith("pkg:pub/") else
                                         "publisher-declared repository commit; not build correspondence") if evidence else "unavailable"})
        tmp_sbom = sbom_path.with_suffix(".json.tmp")
        tmp_sbom.write_text(json.dumps(sbom_data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(tmp_sbom, sbom_path)
    pins_path = base / "nuget-repository-pins.json"
    pins_bytes = (json.dumps(pins, indent=2, sort_keys=True) + "\n").encode()
    if pins_path.is_symlink():
        raise ArchiveError("NuGet pin manifest output symlink refused")
    pins_temp = pins_path.with_suffix(".json.tmp")
    pins_temp.write_bytes(pins_bytes)
    os.replace(pins_temp, pins_path)
    source_blockers = sorted(set(nuget_source_blockers + pub_source_blockers))
    all_blocked = bool(blockers or source_blockers)
    manifest = {"schemaVersion": 1, "status": "blocked" if all_blocked else "complete",
                "lockedPubPackageCount": len(locked), "archivedSourceCount": sum(bool(i.get("sourceArchive")) for i in items),
                "totalUncompressedBytes": total_source, "totalArchiveBytes": total_archives,
                "exclusions": sorted(SKIP_DIRS), "deterministicTar": {"format": "tar.gz", "mtime": 0,
                "uid": 0, "gid": 0, "ownerNames": "", "fileModes": "0644 or 0755"},
                "sourceClaimPolicy": "resolved package tree or publisher-declared immutable repository commit; archives are not represented as proven corresponding source",
                "blockers": blockers, "sourceBlockers": source_blockers,
                "pubHostedArchiveBlockers": sorted(set(pub_source_blockers)),
                "nugetRepositorySourceBlockers": sorted(set(nuget_source_blockers)),
                "pubHostedArchiveCount": len(pub_hosted_archives), "pubHostedArchiveBytes": pub_hosted_bytes,
                "nugetRepositorySourceArchiveCount": len(repo_sources), "packages": items}
    manifest_path = base / "manifest.json"
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    temp = manifest_path.with_suffix(".json.tmp")
    if temp.is_symlink() or manifest_path.is_symlink():
        raise ArchiveError("manifest output symlink refused")
    temp.write_bytes(manifest_bytes)
    os.replace(temp, manifest_path)
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path.cwd())
    parser.add_argument("--pub-cache", type=pathlib.Path,
                        default=pathlib.Path(os.environ.get("PUB_CACHE", pathlib.Path.home() / ".pub-cache")))
    args = parser.parse_args(argv)
    try:
        result = build(args.root.resolve(), args.pub_cache.resolve(), args.root / "dist/sources/packages")
    except (ArchiveError, OSError) as error:
        print(json.dumps({"status": "error", "error": str(error)}), file=sys.stderr)
        return 2
    source_blockers = result.get("sourceBlockers", [])
    print(json.dumps({"status": result["status"], "lockedPubPackageCount": result["lockedPubPackageCount"],
                      "archivedSourceCount": result["archivedSourceCount"],
                      "nugetRepositorySourceArchiveCount": result.get("nugetRepositorySourceArchiveCount", 0),
                      "blockerCount": len(result["blockers"]) + len(source_blockers),
                      "pubSourceBlockerCount": len(result["blockers"]),
                      "pubHostedArchiveCount": result.get("pubHostedArchiveCount", 0),
                      "pubHostedArchiveBlockerCount": len(result.get("pubHostedArchiveBlockers", [])),
                      "nugetRepositorySourceBlockerCount": len(result.get("nugetRepositorySourceBlockers", [])),
                      "manifest": "dist/sources/packages/manifest.json"}, indent=2))
    return 0 if result["status"] == "complete" else 3


if __name__ == "__main__":
    raise SystemExit(main())
