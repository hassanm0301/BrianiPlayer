#!/usr/bin/env python3
"""Assemble a private, deterministic candidate manifest from bounded input descriptors."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import pathlib
import re
import sys
import tarfile
import tempfile
from typing import Any

try:
    from . import package_audit as _package_audit
except ImportError:  # Direct script invocation from the repository.
    import package_audit as _package_audit
SKIP_DIRS = _package_audit.SKIP_DIRS
SKIP_RELATIVE_DIRS = getattr(_package_audit, "SKIP_RELATIVE_DIRS", set())
AuditError = _package_audit.AuditError
safe_file = _package_audit.safe_file
sha256_file = _package_audit.sha256_file
source_tree_sha256 = _package_audit.source_tree_sha256

INPUT_SCHEMA = 1
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
OUTPUTS = ("dist/manifest.json", "dist/provenance.json", "dist/SHA256SUMS",
           "dist/sources/briani-player-source.tar.gz", "dist/client/briani-player-linux-x64.tar.gz",
           "dist/briani-operations.tar.gz")
CHECKSUM_HEADER = "# BrianiPlayer candidate checksum index v1"
MAX_SOURCE_ARCHIVE_FILES = 500_000
MAX_SOURCE_ARCHIVE_BYTES = 8 * 1024 * 1024 * 1024
MAX_OPERATIONS_ARCHIVE_FILES = 100_000
MAX_OPERATIONS_ARCHIVE_BYTES = 2 * 1024 * 1024 * 1024


class CandidateError(ValueError):
    pass


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def relative_path(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value:
        raise CandidateError(f"{label}: path missing")
    p = pathlib.PurePosixPath(value)
    if p.is_absolute() or any(part in ("", ".", "..") for part in p.parts):
        raise CandidateError(f"{label}: unsafe relative path")
    return p.as_posix()


def evidence_ref(root: pathlib.Path, value: Any, label: str, blockers: list[str]) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        blockers.append(f"{label}: evidence reference missing")
        return None
    rel = relative_path(value.get("path"), label)
    path = safe_file(root, rel, label)
    if path is None:
        blockers.append(f"{label}: evidence file missing: {rel}")
        return {"path": rel, "sha256": value.get("sha256")}
    digest = sha256_file(path)
    expected = value.get("sha256")
    if expected is not None and expected != digest:
        raise CandidateError(f"{label}: evidence SHA-256 mismatch")
    return {"path": rel, "sha256": digest}


def _safe_tree_files(root: pathlib.Path) -> list[pathlib.Path]:
    if root.is_symlink() or not root.is_dir():
        raise CandidateError("archive source must be a real directory")
    paths: list[pathlib.Path] = []
    total_bytes = 0
    for current, dirs, files in os.walk(root, followlinks=False):
        current_path = pathlib.Path(current)
        links = [name for name in dirs if (current_path / name).is_symlink()]
        if links:
            raise CandidateError(f"source tree contains symlink directory: {(current_path / sorted(links)[0]).relative_to(root)}")
        dirs[:] = sorted(name for name in dirs
                         if name not in SKIP_DIRS and
                         (current_path / name).relative_to(root).as_posix() not in SKIP_RELATIVE_DIRS)
        for name in sorted(files):
            path = current_path / name
            if path.is_symlink():
                raise CandidateError(f"source tree contains symlink: {path.relative_to(root)}")
            if path.is_file():
                paths.append(path)
                total_bytes += path.stat().st_size
                if len(paths) > MAX_SOURCE_ARCHIVE_FILES or total_bytes > MAX_SOURCE_ARCHIVE_BYTES:
                    raise CandidateError("source archive exceeds bounded file-count or byte limit")
    return paths


def _add_tar_file(archive: tarfile.TarFile, source: pathlib.Path, name: str) -> None:
    info = tarfile.TarInfo(name)
    mode = source.stat().st_mode
    info.size = source.stat().st_size
    info.mode = 0o755 if mode & 0o111 else 0o644
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    info.mtime = 0
    info.type = tarfile.REGTYPE
    with source.open("rb") as stream:
        archive.addfile(info, stream)


def deterministic_tree_tar(root: pathlib.Path, destination: pathlib.Path, archive_root: str) -> str:
    files = _safe_tree_files(root)
    temp_path = _temp_sibling(destination)
    try:
        with temp_path.open("wb") as raw:
            with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as zipped:
                with tarfile.open(fileobj=zipped, mode="w", format=tarfile.PAX_FORMAT) as tar:
                    root_info = tarfile.TarInfo(archive_root.rstrip("/") + "/")
                    root_info.type = tarfile.DIRTYPE
                    root_info.mode = 0o755
                    root_info.uid = root_info.gid = root_info.mtime = 0
                    root_info.uname = root_info.gname = ""
                    tar.addfile(root_info)
                    for source in files:
                        rel = source.relative_to(root).as_posix()
                        _add_tar_file(tar, source, f"{archive_root.rstrip('/')}/{rel}")
            raw.flush()
            os.fsync(raw.fileno())
        _install_generated(destination, temp_path)
        return sha256_file(destination)
    finally:
        temp_path.unlink(missing_ok=True)


def deterministic_files_tar(root: pathlib.Path, files: list[str], destination: pathlib.Path,
                            archive_root: str = "briani-operations") -> str:
    if not files:
        raise CandidateError("operations bundle must list at least one file")
    resolved: list[tuple[str, pathlib.Path]] = []
    seen: set[str] = set()
    total_bytes = 0
    for rel in files:
        rel = relative_path(rel, "operations file")
        if rel in seen:
            raise CandidateError(f"duplicate operations input file: {rel}")
        seen.add(rel)
        path = safe_file(root, rel, "operations file")
        if path is None:
            raise CandidateError(f"operations file missing: {rel}")
        total_bytes += path.stat().st_size
        if len(resolved) >= MAX_OPERATIONS_ARCHIVE_FILES or total_bytes > MAX_OPERATIONS_ARCHIVE_BYTES:
            raise CandidateError("operations archive exceeds bounded file-count or byte limit")
        resolved.append((rel, path))
    temp_path = _temp_sibling(destination)
    try:
        with temp_path.open("wb") as raw:
            with gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as zipped:
                with tarfile.open(fileobj=zipped, mode="w", format=tarfile.PAX_FORMAT) as tar:
                    info = tarfile.TarInfo(archive_root.rstrip("/") + "/")
                    info.type = tarfile.DIRTYPE
                    info.mode = 0o755
                    info.uid = info.gid = info.mtime = 0
                    info.uname = info.gname = ""
                    tar.addfile(info)
                    for rel, path in sorted(resolved):
                        _add_tar_file(tar, path, f"{archive_root.rstrip('/')}/{rel}")
            raw.flush()
            os.fsync(raw.fileno())
        _install_generated(destination, temp_path)
        return sha256_file(destination)
    finally:
        temp_path.unlink(missing_ok=True)


def _temp_sibling(destination: pathlib.Path) -> pathlib.Path:
    if destination.parent.is_symlink() or destination.is_symlink():
        raise CandidateError(f"refusing symlink output: {destination}")
    fd, name = tempfile.mkstemp(prefix="." + destination.name + ".", dir=destination.parent)
    os.close(fd)
    return pathlib.Path(name)


def _checked_output_path(root: pathlib.Path, rel: str, allowed: set[str] | None = None) -> pathlib.Path:
    rel = relative_path(rel, "generated output")
    if allowed is not None and rel not in allowed:
        raise CandidateError(f"generated output is not allowlisted: {rel}")
    current = root
    parts = pathlib.PurePosixPath(rel).parts
    for part in parts[:-1]:
        current = current / part
        if current.is_symlink():
            raise CandidateError(f"generated output ancestor is a symlink: {current.relative_to(root)}")
        if current.exists() and not current.is_dir():
            raise CandidateError(f"generated output ancestor is not a directory: {current.relative_to(root)}")
        if not current.exists():
            current.mkdir()
    destination = current / parts[-1]
    if destination.is_symlink():
        raise CandidateError(f"generated output is a symlink: {destination.relative_to(root)}")
    return destination


def _repository_root_without_symlinks(value: pathlib.Path) -> pathlib.Path:
    absolute = pathlib.Path(os.path.abspath(value))
    current = pathlib.Path(absolute.anchor)
    for part in absolute.parts[1:]:
        current = current / part
        if current.is_symlink():
            raise CandidateError(f"repository root has symlinked ancestor: {current}")
    if not current.is_dir():
        raise CandidateError("root must be a real directory")
    return current


def _safe_source_directory(root: pathlib.Path, rel: str) -> pathlib.Path:
    rel = relative_path(rel, "source directory")
    current = root
    for part in pathlib.PurePosixPath(rel).parts:
        current = current / part
        if current.is_symlink():
            raise CandidateError(f"source directory ancestor is a symlink: {current.relative_to(root)}")
    if not current.is_dir():
        raise CandidateError(f"source directory missing: {rel}")
    return current


def _previously_owned(root: pathlib.Path, destination: pathlib.Path) -> bool:
    sums = root / "dist/SHA256SUMS"
    if sums.is_symlink() or not sums.is_file():
        return False
    rel = destination.relative_to(root).as_posix()
    try:
        for line in sums.read_text(encoding="utf-8").splitlines():
            if line.startswith("# BrianiPlayer candidate checksum index v1"):
                continue
            match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
            if match and match.group(2) == rel:
                return match.group(1) == sha256_file(destination)
    except (OSError, UnicodeError):
        return False
    return False


def _checksum_index_owned(root: pathlib.Path) -> bool:
    sums = root / "dist/SHA256SUMS"
    manifest_path = root / "dist/manifest.json"
    provenance_path = root / "dist/provenance.json"
    if any(path.is_symlink() or not path.is_file() for path in (sums, manifest_path, provenance_path)):
        return False
    try:
        lines = sums.read_text(encoding="utf-8").splitlines()
        if not lines or lines[0] != "# BrianiPlayer candidate checksum index v1":
            return False
        entries: dict[str, str] = {}
        for line in lines[1:]:
            match = re.fullmatch(r"([0-9a-f]{64})  (dist/.+)", line)
            if not match:
                return False
            rel = match.group(2)
            parts = pathlib.PurePosixPath(rel).parts
            if (rel in entries or any(part in ("", ".", "..") for part in parts)
                    or any(ord(character) < 32 or ord(character) == 127 for character in rel)):
                return False
            entries[rel] = match.group(1)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        provenance = json.loads(provenance_path.read_text(encoding="utf-8"))
        manifest_ref = manifest.get("provenance", {})
        if manifest_ref.get("path") != "dist/provenance.json" or manifest_ref.get("sha256") != sha256_file(provenance_path):
            return False
        if entries.get("dist/manifest.json") != sha256_file(manifest_path):
            return False
        if entries.get("dist/provenance.json") != sha256_file(provenance_path):
            return False
        source_ref = provenance.get("sourceArchive", {})
        source_rel = source_ref.get("path")
        source_path = safe_file(root, source_rel, "prior source archive")
        if source_path is None or entries.get(source_rel) != sha256_file(source_path):
            return False
        dist_root = root / "dist"
        actual_paths = {p.relative_to(root).as_posix() for p in dist_root.rglob("*")
                        if p.is_file() and not p.is_symlink() and
                        p.relative_to(root).as_posix() not in {"dist/SHA256SUMS", "dist/candidate-inputs.json"}}
        if set(entries) != actual_paths:
            return False
        expected_artifacts = {x.get("path") for x in manifest.get("artifacts", []) if isinstance(x, dict)}
        # Every listed checksum must either still match or name a recorded output/artifact.
        for rel, digest in entries.items():
            path = safe_file(root, rel, "prior checksum item")
            if path is None:
                return False
            if sha256_file(path) != digest and rel not in expected_artifacts and rel not in OUTPUTS:
                return False
        return True
    except (OSError, UnicodeError, ValueError, AttributeError, json.JSONDecodeError):
        return False


def _install_generated(destination: pathlib.Path, temporary: pathlib.Path) -> None:
    if destination.exists() or destination.is_symlink():
        if destination.is_symlink() or not destination.is_file():
            raise CandidateError(f"refusing to overwrite non-file output: {destination}")
        old = destination.read_bytes()
        new = temporary.read_bytes()
        if old == new:
            return
        # The caller's previous checksum manifest must establish ownership before replacing.
        root = next((parent.parent for parent in destination.parents if parent.name == "dist"), None)
        if root is None:
            raise CandidateError(f"generated output is outside dist: {destination}")
        if not _previously_owned(root, destination):
            raise CandidateError(f"refusing to replace unexpected artifact: {destination}")
    os.replace(temporary, destination)


def _evidence_file(root: pathlib.Path, rel: str) -> dict[str, Any]:
    path = safe_file(root, rel, "candidate artifact")
    if path is None:
        raise CandidateError(f"candidate artifact missing: {rel}")
    return {"path": rel, "sha256": sha256_file(path), "sizeBytes": path.stat().st_size}


def _component_inventory(root: pathlib.Path, blockers: list[str]) -> tuple[list[dict[str, Any]], dict[tuple[str, str, str], dict[str, Any]]]:
    inv_path = root / "dist/licenses/inventory.json"
    src_path = root / "dist/sources/packages/manifest.json"
    for path in (inv_path, src_path):
        if path.is_symlink() or not path.is_file():
            raise CandidateError(f"required package inventory missing or unsafe: {path.relative_to(root)}")
    inv = json.loads(inv_path.read_text(encoding="utf-8"))
    src = json.loads(src_path.read_text(encoding="utf-8"))
    sources: dict[tuple[str, str, str], dict[str, Any]] = {}
    for item in src.get("packages", []):
        key = ("pub", str(item.get("name", "")).lower(), str(item.get("version", "")))
        sources[key] = item
    nuget_path = root / "dist/sources/packages/nuget-repository-pins.json"
    if nuget_path.is_file() and not nuget_path.is_symlink():
        pins = json.loads(nuget_path.read_text(encoding="utf-8"))
        for pin in pins.get("repositories", []):
            key = ("nuget", str(pin.get("package", "")).lower(), str(pin.get("version", "")))
            source = pin.get("sourceArchiveEvidence")
            if source:
                sources[key] = {"correspondingSource": {
                    "kind": "publisher_declared_repository_commit_archive",
                    "archivePath": source.get("sourceArchive"), "archiveSha256": source.get("archiveSha256"),
                    "commit": source.get("commit"), "repositoryUrl": source.get("repositoryUrl"),
                    "correspondenceNote": "publisher-declared immutable repository commit; package correspondence is not proven"}}
    components: list[dict[str, Any]] = []
    mapping: dict[tuple[str, str, str], dict[str, Any]] = {}
    for item in inv.get("components", []):
        eco, name, version = item.get("ecosystem"), item.get("name"), item.get("version")
        key = (str(eco).lower(), str(name).lower(), str(version))
        source_item = sources.get(key, {})
        corr = item.get("correspondingSource") or source_item.get("correspondingSource")
        if not corr and key[0] == "pub":
            hosted = source_item.get("hostedArchiveEvidence")
            if isinstance(hosted, dict) and hosted.get("sourceArchive"):
                corr = {"kind": "official_pub_archive_sha256_verified_against_lock",
                        "archivePath": hosted["sourceArchive"], "archiveSha256": hosted.get("archiveSha256"),
                        "correspondenceNote": "official archive hash matches pubspec.lock; not build/binary correspondence proof"}
            elif source_item.get("sourceArchive"):
                corr = {"kind": "resolved_local_source_tree_archive",
                        "archivePath": source_item["sourceArchive"], "archiveSha256": source_item.get("archiveSha256"),
                        "sourceTreeSha256": source_item.get("sourceTreeSha256"),
                        "correspondenceNote": "resolved workspace/SDK/vendor source snapshot; upstream archive and binary correspondence not claimed"}
        if corr:
            archive_path = corr.get("archivePath")
            if archive_path:
                file_ref = _evidence_file(root, archive_path)
                expected = corr.get("archiveSha256")
                if expected and file_ref["sha256"] != expected:
                    raise CandidateError(f"source archive hash mismatch for {key}")
                corr = dict(corr)
                corr["path"] = archive_path
                corr["sha256"] = file_ref["sha256"]
        license_evidence = item.get("licenseEvidence")
        if license_evidence:
            license_evidence = evidence_ref(root, license_evidence, f"{key} license", blockers)
        else:
            blockers.append(f"{key[0]}:{key[1]}@{key[2]}: license evidence missing")
        notices = item.get("notices")
        notice_refs = []
        for notice in item.get("noticeFiles", []):
            ref = notice.get("evidence") or notice
            if isinstance(ref, dict) and ref.get("path") and ref.get("sha256"):
                verified = evidence_ref(root, ref, f"{key} notice", blockers)
                if verified:
                    notice_refs.append(verified)
        if len(notice_refs) == 1:
            notices = notice_refs[0]
        elif len(notice_refs) > 1:
            merged_rel = (f"dist/notices/candidate/{key[0]}-{key[1]}-{key[2]}-combined.txt")
            merged_path = _checked_output_path(root, merged_rel)
            sections = []
            for ref in notice_refs:
                content_path = safe_file(root, ref["path"], f"{key} notice")
                if content_path is None or content_path.stat().st_size > 16 * 1024 * 1024:
                    raise CandidateError(f"notice source missing or too large for {key}")
                content = content_path.read_bytes()
                if b"\x00" in content:
                    raise CandidateError(f"notice source is not text for {key}")
                sections.append(b"===== " + ref["path"].encode("utf-8") + b" =====\n" + content.rstrip() + b"\n")
            merged_data = b"\n".join(sections)
            _write_generated(merged_path, merged_data, root)
            notices = {"path": merged_rel, "sha256": hashlib.sha256(merged_data).hexdigest()}
        elif notices and isinstance(notices, dict) and notices.get("path") and notices.get("sha256"):
            pass
        else:
            notices = None
            blockers.append(f"{key[0]}:{key[1]}@{key[2]}: notice evidence missing")
        record = {"ecosystem": key[0], "name": key[1], "version": key[2],
                  "licenseExpression": item.get("licenseExpression"),
                  "licenseEvidence": license_evidence, "notices": notices,
                  "correspondingSource": corr}
        if not record["licenseExpression"]:
            blockers.append(f"{key[0]}:{key[1]}@{key[2]}: license expression unresolved")
        if not corr:
            blockers.append(f"{key[0]}:{key[1]}@{key[2]}: corresponding source unavailable")
        components.append(record)
        mapping[key] = record
    for blocker in inv.get("blockers", []):
        blockers.append(f"license inventory: {blocker}")
    for blocker in src.get("nugetRepositorySourceBlockers", []):
        blockers.append(f"source inventory: {blocker}")
    return components, mapping


def assemble(root: pathlib.Path, input_path: pathlib.Path) -> dict[str, Any]:
    root = _repository_root_without_symlinks(root)
    if input_path.is_absolute():
        try:
            input_rel_name = input_path.relative_to(root).as_posix()
        except ValueError as error:
            raise CandidateError("candidate inputs must be inside repository root") from error
    else:
        input_rel_name = relative_path(input_path.as_posix(), "candidate inputs")
    input_rel = safe_file(root, input_rel_name, "candidate inputs")
    if input_rel is None:
        raise CandidateError("candidate inputs file missing")
    checksum_owned = _checksum_index_owned(root)
    checksum_path = root / "dist/SHA256SUMS"
    if (checksum_path.exists() or checksum_path.is_symlink()) and not checksum_owned:
        raise CandidateError("existing checksum index ownership cannot be verified; refusing all candidate writes")
    inputs = json.loads(input_rel.read_text(encoding="utf-8"))
    if not isinstance(inputs, dict) or inputs.get("schemaVersion") != INPUT_SCHEMA:
        raise CandidateError("unsupported candidate-inputs schema")

    stated_blockers = inputs.get("blockers", [])
    if not isinstance(stated_blockers, list) or any(not isinstance(x, str) or not x.strip() for x in stated_blockers):
        raise CandidateError("candidate blockers must be nonempty strings")
    blockers: list[str] = list(stated_blockers)
    source_hash = source_tree_sha256(root)
    commit = inputs.get("sourceCommit")
    if commit is not None and not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", str(commit)):
        raise CandidateError("sourceCommit must be null or a full Git commit hash")
    stated_hash = inputs.get("sourceTreeSha256")
    if stated_hash is not None and stated_hash != source_hash:
        raise CandidateError("candidate input sourceTreeSha256 does not match current source")

    source_tar = _checked_output_path(root, "dist/sources/briani-player-source.tar.gz", {"dist/sources/briani-player-source.tar.gz"})
    source_tar_hash = deterministic_tree_tar(root, source_tar, "briani-player")
    bundles = inputs.get("bundles", [])
    artifact_descriptors = inputs.get("artifacts", [])
    if not isinstance(artifact_descriptors, list):
        raise CandidateError("artifacts must be a list")
    # Bundles produce artifact files and may include their audit evidence descriptor.
    generated_bundle_artifacts: list[dict[str, Any]] = []
    for bundle in bundles:
        if not isinstance(bundle, dict):
            raise CandidateError("bundle descriptor malformed")
        kind = bundle.get("kind")
        out_rel = relative_path(bundle.get("path"), "bundle")
        if kind == "linux" and bundle.get("sourceDirectory"):
            output = _checked_output_path(root, out_rel, {"dist/client/briani-player-linux-x64.tar.gz"})
            source_dir_rel = relative_path(bundle["sourceDirectory"], "Linux bundle source")
            source_dir = _safe_source_directory(root, source_dir_rel)
            deterministic_tree_tar(source_dir, output, "briani-player-linux-x64")
        elif kind == "operations" and isinstance(bundle.get("files"), list):
            output = _checked_output_path(root, out_rel, {"dist/briani-operations.tar.gz"})
            deterministic_files_tar(root, bundle["files"], output)
        elif bundle.get("sourceArchive"):
            expected_output = {"linux": "dist/client/briani-player-linux-x64.tar.gz",
                               "operations": "dist/briani-operations.tar.gz"}.get(kind)
            if expected_output is None:
                raise CandidateError(f"unsupported prebuilt bundle kind: {kind}")
            if out_rel != expected_output:
                raise CandidateError(f"{kind} bundle path must be {expected_output}")
            source_archive = relative_path(bundle["sourceArchive"], "prebuilt bundle")
            output = _checked_output_path(root, out_rel,
                                          {"dist/client/briani-player-linux-x64.tar.gz", "dist/briani-operations.tar.gz"})
            source_file = _evidence_file(root, source_archive)
            expected = bundle.get("sha256")
            if expected and expected != source_file["sha256"]:
                raise CandidateError("prebuilt bundle hash differs from descriptor")
            if out_rel != source_archive:
                raise CandidateError("prebuilt bundle path must equal output path")
        else:
            raise CandidateError(f"unsupported bundle descriptor kind: {kind}")
        if isinstance(bundle.get("artifact"), dict):
            generated_bundle_artifacts.append({**bundle["artifact"], "path": out_rel})
    descriptors = artifact_descriptors + generated_bundle_artifacts

    lock_records = []
    for record in inputs.get("lockfiles", []):
        if not isinstance(record, dict):
            raise CandidateError("lockfile descriptor malformed")
        path = _evidence_file(root, relative_path(record.get("path"), "lockfile"))
        if record.get("sha256") and record["sha256"] != path["sha256"]:
            raise CandidateError(f"lockfile digest mismatch: {path['path']}")
        lock_records.append({"path": path["path"], "sha256": path["sha256"]})
    if not lock_records:
        # Preserve all discovered lockfiles as evidence, using package audit discovery.
        try:
            from . import package_audit
        except ImportError:
            import package_audit
        lock_records = [{"path": p.relative_to(root).as_posix(), "sha256": sha256_file(p)}
                        for p in package_audit.discover_lockfiles(root)]

    sbom_ref = inputs.get("sbom") or {"path": "dist/sbom.json"}
    sbom_evidence = evidence_ref(root, sbom_ref, "SBOM", blockers)
    if sbom_evidence is None:
        sbom_evidence = {"path": "dist/sbom.json", "sha256": "0" * 64}
    artifact_records: list[dict[str, Any]] = []
    provenance_subjects: list[dict[str, str]] = []
    for index, descriptor in enumerate(descriptors):
        if not isinstance(descriptor, dict):
            raise CandidateError(f"artifact descriptor {index} malformed")
        rel = relative_path(descriptor.get("path"), f"artifact[{index}]")
        actual = _evidence_file(root, rel)
        if descriptor.get("sha256") is not None and descriptor["sha256"] != actual["sha256"]:
            raise CandidateError(f"artifact[{index}] SHA-256 differs from candidate descriptor")
        if descriptor.get("sizeBytes") is not None and descriptor["sizeBytes"] != actual["sizeBytes"]:
            raise CandidateError(f"artifact[{index}] size differs from candidate descriptor")
        build_evidence = evidence_ref(root, descriptor.get("buildEvidence"), f"artifact[{index}] build", blockers)
        verification_evidence = evidence_ref(root, descriptor.get("verificationEvidence"), f"artifact[{index}] verification", blockers)
        signing_evidence = evidence_ref(root, descriptor.get("signingEvidence"), f"artifact[{index}] signing", blockers)
        item = {"path": rel, "sha256": actual["sha256"], "sizeBytes": actual["sizeBytes"],
                "platform": descriptor.get("platform"), "architecture": descriptor.get("architecture"),
                "kind": descriptor.get("kind"), "buildEvidence": build_evidence,
                "verificationStatus": descriptor.get("verificationStatus"),
                "verificationEvidence": verification_evidence,
                "signingStatus": descriptor.get("signingStatus"), "signingEvidence": signing_evidence,
                "nativeComponents": descriptor.get("nativeComponents", [])}
        if not isinstance(item["nativeComponents"], list):
            raise CandidateError(f"artifact[{index}] nativeComponents must be a list")
        artifact_records.append(item)
        provenance_subjects.append({"path": rel, "sha256": actual["sha256"]})

    components, component_map = _component_inventory(root, blockers)
    native_correspondence_blockers = []
    for artifact in artifact_records:
        for native in artifact["nativeComponents"]:
            if not isinstance(native, dict):
                blockers.append(f"{artifact['path']}: malformed native component descriptor")
                continue
            key = (str(native.get("ecosystem", "")).lower(), str(native.get("name", "")).lower(), str(native.get("version", "")))
            component = component_map.get(key)
            if not component:
                blockers.append(f"{artifact['path']}: native component missing from dependency inventory: {key}")
                continue
            if not component.get("correspondingSource"):
                native_correspondence_blockers.append(f"{artifact['path']}: native source correspondence unresolved for {key}")
            if not component.get("licenseExpression"):
                native_correspondence_blockers.append(f"{artifact['path']}: native license unresolved for {key}")
            if native.get("sourceCorrespondenceStatus") != "verified_binary_source":
                native_correspondence_blockers.append(
                    f"{artifact['path']}: native binary-to-source correspondence unverified for {key}")
    blockers.extend(native_correspondence_blockers)

    project_license = inputs.get("projectLicense")
    if not isinstance(project_license, dict) or project_license.get("status") != "authorized":
        project_license = {"status": "unasserted", "evidence": None}
        blockers.append("owner project-license grant is unasserted")
    elif project_license.get("evidence"):
        project_license["evidence"] = evidence_ref(root, project_license["evidence"], "project license", blockers)

    provenance = {"schemaVersion": 1, "sourceCommit": commit, "sourceTreeSha256": source_hash,
                  "sourceArchive": {"path": "dist/sources/briani-player-source.tar.gz", "sha256": source_tar_hash},
                  "candidateInputs": {"path": input_rel.relative_to(root).as_posix(), "sha256": sha256_file(input_rel)},
                  "subjects": sorted(provenance_subjects, key=lambda x: x["path"]),
                  "statement": "Private candidate assembly. Artifact hashes are observed; source commit may be absent and package/native correspondence is only as stated per component."}
    provenance_bytes = json_bytes(provenance)
    _write_generated(_checked_output_path(root, "dist/provenance.json", {"dist/provenance.json"}), provenance_bytes, root)
    provenance_ref = {"path": "dist/provenance.json", "sha256": hashlib.sha256(provenance_bytes).hexdigest()}
    manifest = {"schemaVersion": 1, "sourceCommit": commit, "sourceTreeSha256": source_hash,
                "lockfiles": sorted(lock_records, key=lambda x: x["path"]),
                "sbom": sbom_evidence, "projectLicense": project_license,
                "components": components, "artifacts": artifact_records,
                "provenance": provenance_ref, "status": "blocked", "blockers": sorted(set(blockers))}
    manifest_bytes = json_bytes(manifest)
    _write_generated(_checked_output_path(root, "dist/manifest.json", {"dist/manifest.json"}), manifest_bytes, root)

    sum_lines = []
    dist_root = root / "dist"
    all_dist_paths = list(dist_root.rglob("*"))
    symlinks = [path for path in all_dist_paths if path.is_symlink()]
    if symlinks:
        raise CandidateError(f"dist contains symlink: {min(symlinks).relative_to(root).as_posix()}")
    for path in sorted((p for p in all_dist_paths if p.is_file()),
                       key=lambda p: p.relative_to(root).as_posix()):
        rel = path.relative_to(root).as_posix()
        if rel in {"dist/SHA256SUMS", "dist/candidate-inputs.json"}:
            continue
        sum_lines.append(f"{sha256_file(path)}  {rel}")
    checksum_bytes = (CHECKSUM_HEADER + "\n" + "\n".join(sum_lines) + "\n").encode("utf-8")
    _write_generated(_checked_output_path(root, "dist/SHA256SUMS", {"dist/SHA256SUMS"}),
                     checksum_bytes, root, allow_overwrite=checksum_owned)
    return manifest


def _write_generated(path: pathlib.Path, data: bytes, root: pathlib.Path,
                     allow_overwrite: bool = False) -> None:
    rel = path.relative_to(root).as_posix()
    if rel not in OUTPUTS and not rel.startswith("dist/notices/candidate/"):
        raise CandidateError(f"generated output is not allowlisted: {rel}")
    _checked_output_path(root, rel, {rel})
    temp = _temp_sibling(path)
    try:
        with temp.open("wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        if path.exists() or path.is_symlink():
            if path.is_symlink() or not path.is_file():
                raise CandidateError(f"refusing to overwrite generated output: {path}")
            if path.read_bytes() != data and not (allow_overwrite or _previously_owned(root, path)):
                raise CandidateError(f"refusing to replace unexpected output: {path}")
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--inputs", type=pathlib.Path, default=pathlib.Path("dist/candidate-inputs.json"))
    args = parser.parse_args(argv)
    try:
        manifest = assemble(args.root, args.inputs)
        print(json.dumps({"status": manifest["status"], "artifactCount": len(manifest["artifacts"]),
                          "componentCount": len(manifest["components"]), "blockerCount": len(manifest["blockers"])}))
        return 3 if manifest["blockers"] else 0
    except (CandidateError, AuditError, OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "invalid", "error": str(error)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
