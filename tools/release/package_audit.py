#!/usr/bin/env python3
"""Inventory and verify a local, unsigned Briani release candidate manifest.

Manifest paths are always relative to --root. Verification never downloads,
builds, signs, or edits candidate artifacts. Exit 0 means all release evidence
is present; exit 3 is an explicit blocked candidate; exit 2 is malformed or
tampered input.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import tarfile
import zipfile
from typing import Any

SCHEMA = 1
SKIP_DIRS = {".git", ".aws", ".codex", ".dart_tool", ".gradle", ".tools", "__pycache__",
             "artifacts", "build", "dist", "ephemeral", "evidence", "node_modules", "obj", "bin"}
SKIP_RELATIVE_DIRS = {"prototypes/playback/harness/state", "prototypes/playback/fixtures/generated"}
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
HEX_COMMIT = re.compile(r"^(?:[0-9a-f]{40}|[0-9a-f]{64})$")
PLACEHOLDER_LICENSES = re.compile(r"\b(?:UNKNOWN|TBD|TODO|NOASSERTION|UNLICENSED|NOT KNOWN)\b", re.I)
ELF_ARCH = {3: "x86", 40: "armv7", 62: "x86_64", 183: "aarch64"}
APK_ABI_ARCH = {"armeabi-v7a": "armv7", "arm64-v8a": "aarch64", "x86": "x86", "x86_64": "x86_64"}


class AuditError(ValueError):
    """Input is malformed, unsafe, or has a mismatched recorded digest."""


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_tree_sha256(root: pathlib.Path) -> str:
    """Hash sorted source-relative names and file digests, excluding generated outputs."""
    digest = hashlib.sha256()
    for current, dirs, files in os.walk(root, followlinks=False):
        symlink_dirs = [d for d in dirs if (pathlib.Path(current) / d).is_symlink()]
        if symlink_dirs:
            rel = (pathlib.Path(current) / sorted(symlink_dirs)[0]).relative_to(root).as_posix()
            raise AuditError(f"source tree contains symlink directory: {rel}")
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS
                         and (pathlib.Path(current) / d).relative_to(root).as_posix() not in SKIP_RELATIVE_DIRS)
        for name in sorted(files):
            path = pathlib.Path(current) / name
            if not path.is_file():
                continue
            if path.is_symlink():
                raise AuditError(f"source tree contains symlink: {path.relative_to(root).as_posix()}")
            rel = path.relative_to(root).as_posix().encode("utf-8")
            file_digest = bytes.fromhex(sha256_file(path))
            # Archives preserve executable semantics; the source identity must too.
            mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
            digest.update(mode.to_bytes(4, "big"))
            digest.update(len(rel).to_bytes(8, "big"))
            digest.update(rel)
            digest.update(file_digest)
    return digest.hexdigest()


def safe_file(root: pathlib.Path, rel: Any, label: str) -> pathlib.Path | None:
    if not isinstance(rel, str) or not rel:
        return None
    candidate = pathlib.PurePosixPath(rel)
    if candidate.is_absolute() or any(part in ("", ".", "..") for part in candidate.parts):
        raise AuditError(f"{label}: unsafe relative path")
    current = root
    for part in candidate.parts:
        current = current / part
        if current.is_symlink():
            raise AuditError(f"{label}: symlink path refused")
    resolved = current.resolve(strict=False)
    if resolved != root and root not in resolved.parents:
        raise AuditError(f"{label}: path escapes root")
    if not current.is_file():
        return None
    return current


def verify_source_archive(root: pathlib.Path, archive: pathlib.Path) -> None:
    """Compare the retained project archive with the exact source files, without extraction."""
    if archive.stat().st_size > 512 * 1024 * 1024:
        raise AuditError("project source archive exceeds size bound")
    expected: dict[str, tuple[int, str]] = {}
    for current, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS
                         and (pathlib.Path(current) / d).relative_to(root).as_posix() not in SKIP_RELATIVE_DIRS)
        for name in sorted(files):
            path = pathlib.Path(current) / name
            if not path.is_file():
                continue
            if path.is_symlink():
                raise AuditError("project source file symlink refused")
            expected[path.relative_to(root).as_posix()] = (0o755 if path.stat().st_mode & 0o111 else 0o644, sha256_file(path))
    observed: dict[str, tuple[int, str]] = {}
    total = 0
    try:
        with tarfile.open(archive, "r:gz") as stream:
            for index, member in enumerate(stream):
                if index >= 250000:
                    raise AuditError("project source archive exceeds member bound")
                if member.isdir() and member.name.rstrip("/") == "briani-player":
                    continue
                parts = pathlib.PurePosixPath(member.name).parts
                if not member.isfile() or len(parts) < 2 or parts[0] != "briani-player" or any(p in {".", "..", ""} for p in parts):
                    raise AuditError("unsafe project source archive member")
                rel = "/".join(parts[1:])
                if rel in observed or rel not in expected:
                    raise AuditError("unexpected or duplicate project source archive member")
                total += member.size
                if member.size < 0 or total > 4 * 1024 * 1024 * 1024:
                    raise AuditError("project source archive exceeds expanded size bound")
                digest = hashlib.sha256()
                data = stream.extractfile(member)
                if data is None:
                    raise AuditError("project source archive member unreadable")
                with data:
                    for chunk in iter(lambda: data.read(1024 * 1024), b""):
                        digest.update(chunk)
                observed[rel] = (member.mode, digest.hexdigest())
    except (tarfile.TarError, EOFError) as error:
        raise AuditError("invalid project source archive") from error
    if observed != expected:
        raise AuditError("project source archive does not match source files and executable modes")


def evidence(root: pathlib.Path, value: Any, label: str, blockers: list[str]) -> pathlib.Path | None:
    if not isinstance(value, dict):
        blockers.append(f"{label}: evidence reference missing")
        return None
    path = safe_file(root, value.get("path"), label)
    if path is None:
        blockers.append(f"{label}: evidence file missing")
        return None
    expected = value.get("sha256")
    if not isinstance(expected, str) or not HEX_SHA256.fullmatch(expected):
        blockers.append(f"{label}: evidence SHA-256 missing or invalid")
    elif sha256_file(path) != expected:
        raise AuditError(f"{label}: evidence SHA-256 mismatch")
    return path


def discover_lockfiles(root: pathlib.Path) -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    for current, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not (pathlib.Path(current) / d).is_symlink()
                         and (pathlib.Path(current) / d).relative_to(root).as_posix() not in SKIP_RELATIVE_DIRS)
        for name in files:
            if name in {"packages.lock.json", "pubspec.lock"}:
                found.append(pathlib.Path(current) / name)
    return sorted(found, key=lambda p: p.relative_to(root).as_posix())


def sbom_components(document: dict[str, Any], blockers: list[str]) -> dict[tuple[str, str, str], str]:
    """Extract package URL identities and declared license expressions from SPDX/CycloneDX."""
    is_cyclone = document.get("bomFormat") == "CycloneDX"
    records = document.get("components") if is_cyclone else document.get("packages")
    if not isinstance(records, list):
        blockers.append("SBOM has no package/component list")
        return {}
    found: dict[tuple[str, str, str], str] = {}
    for record in records:
        if not isinstance(record, dict):
            blockers.append("SBOM contains a malformed package/component record")
            continue
        purls: list[str] = []
        if is_cyclone and isinstance(record.get("purl"), str):
            purls.append(record["purl"])
        elif not is_cyclone:
            for ref in record.get("externalRefs", []):
                if isinstance(ref, dict) and ref.get("referenceType") == "purl" and isinstance(ref.get("referenceLocator"), str):
                    purls.append(ref["referenceLocator"])
        if not purls:
            blockers.append(f"SBOM component lacks a package URL: {record.get('name', '(unnamed)')}")
            continue
        match = re.match(r"^pkg:([^/]+)/([^@?#]+)@([^?#]+)", purls[0], re.I)
        if not match:
            blockers.append(f"SBOM component has an unsupported package URL: {record.get('name', '(unnamed)')}")
            continue
        ecosystem = match.group(1).lower()
        ecosystem = {"dart": "pub", "pub.dev": "pub", "pub": "pub", "nuget": "nuget"}.get(ecosystem, ecosystem)
        name, version = match.group(2).lower(), match.group(3)
        if isinstance(record.get("version"), str) and record["version"] != version:
            blockers.append(f"SBOM name/version differs from package URL: {record.get('name', name)}")
        if is_cyclone:
            license_records = record.get("licenses")
            expression = None
            if isinstance(license_records, list) and len(license_records) == 1 and isinstance(license_records[0], dict):
                license_item = license_records[0]
                expression = license_item.get("expression")
                license_obj = license_item.get("license")
                if expression is None and isinstance(license_obj, dict):
                    expression = license_obj.get("id") or license_obj.get("name")
        else:
            expression = record.get("licenseDeclared")
        if not isinstance(expression, str) or not expression.strip() or PLACEHOLDER_LICENSES.search(expression):
            blockers.append(f"SBOM package lacks an SPDX license expression: {record.get('name', name)}")
            continue
        key = (ecosystem, name, version)
        if key in found:
            blockers.append(f"SBOM contains duplicate package identity: {ecosystem}:{name}@{version}")
        found[key] = expression
    return found


def parse_dotnet_lock(path: pathlib.Path) -> set[tuple[str, str, str]]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise AuditError(f"invalid .NET package lock: {path.name}") from error
    result: set[tuple[str, str, str]] = set()
    dependencies = data.get("dependencies")
    if not isinstance(dependencies, dict):
        raise AuditError(f".NET lock has no dependencies map: {path.name}")
    for framework, packages in dependencies.items():
        if not isinstance(packages, dict):
            continue
        for name, details in packages.items():
            version = details.get("resolved") if isinstance(details, dict) else None
            if isinstance(name, str) and isinstance(version, str):
                result.add(("nuget", name.lower(), version))
    return result


def parse_pub_lock(path: pathlib.Path) -> set[tuple[str, str, str]]:
    result: set[tuple[str, str, str]] = set()
    current: str | None = None
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^  ([A-Za-z0-9_.+-]+):\s*$", line)
        if match:
            current = match.group(1)
            continue
        if current:
            version = re.match(r'^    version:\s*["\']?([^"\'\s]+)', line)
            if version:
                result.add(("pub", current.lower(), version.group(1)))
    if not result:
        raise AuditError(f"pub lock contains no resolved packages: {path.name}")
    return result


def locked_components(root: pathlib.Path, paths: list[pathlib.Path]) -> set[tuple[str, str, str]]:
    output: set[tuple[str, str, str]] = set()
    for path in paths:
        if path.name == "pubspec.lock":
            output |= parse_pub_lock(path)
        else:
            output |= parse_dotnet_lock(path)
    return output


def elf_arch(data: bytes) -> str | None:
    if len(data) < 20 or data[:4] != b"\x7fELF":
        return None
    endian = "little" if data[5] == 1 else "big" if data[5] == 2 else None
    if endian is None:
        raise AuditError("ELF binary has an invalid byte order")
    return ELF_ARCH.get(int.from_bytes(data[18:20], endian))


def file_arch(path: pathlib.Path) -> str | None:
    with path.open("rb") as stream:
        return elf_arch(stream.read(64))


def artifact_native_members(path: pathlib.Path, rel_path: str) -> dict[str, tuple[str, str]]:
    """Return native archive member -> (architecture, SHA-256) for APKs."""
    members: dict[str, tuple[str, str]] = {}
    if path.suffix.lower() != ".apk":
        return members
    try:
        with zipfile.ZipFile(path) as archive:
            for info in archive.infolist():
                match = re.fullmatch(r"lib/([^/]+)/[^/]+\.so", info.filename)
                if not match:
                    continue
                abi = match.group(1)
                if abi not in APK_ABI_ARCH:
                    raise AuditError(f"{rel_path}: unsupported APK native ABI {abi}")
                native_digest = hashlib.sha256()
                with archive.open(info) as member_stream:
                    header = member_stream.read(64)
                    native_digest.update(header)
                    for chunk in iter(lambda: member_stream.read(1024 * 1024), b""):
                        native_digest.update(chunk)
                actual_arch = elf_arch(header)
                expected_arch = APK_ABI_ARCH[abi]
                if actual_arch != expected_arch:
                    raise AuditError(f"{rel_path}:{info.filename}: ELF ABI mismatch")
                if info.filename in members:
                    raise AuditError(f"{rel_path}: duplicate APK native member {info.filename}")
                members[info.filename] = (actual_arch, native_digest.hexdigest())
    except (OSError, zipfile.BadZipFile) as error:
        raise AuditError(f"{rel_path}: invalid APK/ZIP artifact") from error
    return members


def verify_manifest(root: pathlib.Path, manifest_path: pathlib.Path) -> dict[str, Any]:
    if root.is_symlink():
        raise AuditError("root must not be a symlink")
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise AuditError("root must be a real directory")
    if manifest_path.is_absolute():
        if manifest_path.is_symlink():
            raise AuditError("manifest symlink path refused")
        try:
            manifest_rel = manifest_path.resolve(strict=False).relative_to(root).as_posix()
        except ValueError as error:
            raise AuditError("manifest must be inside --root") from error
    else:
        manifest_rel = manifest_path.as_posix()
    manifest_file = safe_file(root, manifest_rel, "manifest")
    if manifest_file is None:
        return {"status": "blocked", "blockers": ["manifest file missing"], "inventory": []}
    try:
        manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise AuditError("manifest is not valid JSON") from error
    if not isinstance(manifest, dict) or manifest.get("schemaVersion") != SCHEMA:
        raise AuditError("unsupported package manifest schema")

    stated_blockers = manifest.get("blockers", [])
    if not isinstance(stated_blockers, list) or any(not isinstance(x, str) or not x.strip() for x in stated_blockers):
        raise AuditError("manifest blockers must be nonempty strings")
    blockers: list[str] = list(stated_blockers)
    commit = manifest.get("sourceCommit")
    commit_valid = isinstance(commit, str) and bool(HEX_COMMIT.fullmatch(commit))
    git_available = False
    git_clean = False
    if commit_valid:
        try:
            git = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], text=True,
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False)
        except OSError:
            git = None
        if git is None or git.returncode:
            git_available = False
        elif git.stdout.strip().lower() != commit.lower():
            git_available = True
            blockers.append("manifest source commit does not match the checked-out source commit")
        else:
            git_available = True
            status = subprocess.run(["git", "-C", str(root), "status", "--porcelain", "--untracked-files=all"],
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False)
            git_clean = status.returncode == 0 and not status.stdout.strip()
    tree_hash = manifest.get("sourceTreeSha256")
    tree_matches = False
    if tree_hash is not None:
        if not isinstance(tree_hash, str) or not HEX_SHA256.fullmatch(tree_hash):
            raise AuditError("sourceTreeSha256 is malformed")
        if source_tree_sha256(root) != tree_hash:
            raise AuditError("source tree SHA-256 mismatch")
        tree_matches = True
    if not tree_matches and (not git_available or not git_clean):
        blockers.append("source identity is unverified: provide a matching Git sourceCommit or sourceTreeSha256")

    expected_locks = discover_lockfiles(root)
    lock_records = manifest.get("lockfiles")
    if not isinstance(lock_records, list):
        lock_records = []
    recorded_lock_paths: set[str] = set()
    for record in lock_records:
        if not isinstance(record, dict):
            blockers.append("lockfile record is malformed")
            continue
        rel = record.get("path")
        path = safe_file(root, rel, "lockfile")
        if path is None:
            blockers.append(f"lockfile missing: {rel or '(path not supplied)'}")
            continue
        rel = path.relative_to(root).as_posix()
        if rel in recorded_lock_paths:
            raise AuditError(f"duplicate lockfile record: {rel}")
        recorded_lock_paths.add(rel)
        expected_hash = record.get("sha256")
        if not isinstance(expected_hash, str) or not HEX_SHA256.fullmatch(expected_hash):
            blockers.append(f"lockfile SHA-256 missing: {rel}")
        elif sha256_file(path) != expected_hash:
            raise AuditError(f"lockfile SHA-256 mismatch: {rel}")
    discovered = {path.relative_to(root).as_posix() for path in expected_locks}
    if discovered != recorded_lock_paths:
        missing = sorted(discovered - recorded_lock_paths)
        extra = sorted(recorded_lock_paths - discovered)
        if missing:
            blockers.append("manifest omits lockfiles: " + ", ".join(missing))
        if extra:
            blockers.append("manifest lists non-discovered lockfiles: " + ", ".join(extra))

    required_components = locked_components(root, expected_locks) if expected_locks else set()
    components = manifest.get("components")
    if not isinstance(components, list):
        components = []
    component_map: dict[tuple[str, str, str], dict[str, Any]] = {}
    for item in components:
        if not isinstance(item, dict):
            blockers.append("SBOM component record is malformed")
            continue
        key = (str(item.get("ecosystem", "")).lower(), str(item.get("name", "")).lower(), str(item.get("version", "")))
        if key in component_map:
            raise AuditError(f"duplicate SBOM component record: {key[0]}:{key[1]}@{key[2]}")
        component_map[key] = item
        license_expr = item.get("licenseExpression")
        if not isinstance(license_expr, str) or not license_expr.strip() or PLACEHOLDER_LICENSES.search(license_expr):
            blockers.append(f"{key[0]}:{key[1]}@{key[2]}: SPDX license expression missing")
        for field in ("licenseEvidence", "notices", "correspondingSource"):
            evidence(root, item.get(field), f"{key[0]}:{key[1]}@{key[2]} {field}", blockers)
    absent_components = sorted(required_components - set(component_map))
    if absent_components:
        blockers.append(f"SBOM omits {len(absent_components)} locked package component(s)")

    project_license = manifest.get("projectLicense")
    if not isinstance(project_license, dict) or project_license.get("status") != "authorized":
        blockers.append("owner project-license grant is not evidenced as authorized")
    else:
        evidence(root, project_license.get("evidence"), "project license grant", blockers)

    sbom = manifest.get("sbom")
    sbom_path = evidence(root, sbom, "SBOM", blockers)
    if sbom_path:
        try:
            sbom_doc = json.loads(sbom_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise AuditError("SBOM must be valid JSON (SPDX JSON or CycloneDX JSON)") from error
        if not isinstance(sbom_doc, dict) or not (sbom_doc.get("spdxVersion") or sbom_doc.get("bomFormat") == "CycloneDX"):
            blockers.append("SBOM format is not identified as SPDX JSON or CycloneDX JSON")
        else:
            sbom_items = sbom_components(sbom_doc, blockers)
            missing_from_sbom = required_components - set(sbom_items)
            if missing_from_sbom:
                blockers.append(f"SBOM document omits {len(missing_from_sbom)} locked package component(s)")
            for key, expression in sbom_items.items():
                declared = component_map.get(key, {}).get("licenseExpression")
                if declared and " ".join(declared.split()).lower() != " ".join(expression.split()).lower():
                    blockers.append(f"SBOM and manifest license expressions differ: {key[0]}:{key[1]}@{key[2]}")

    provenance = evidence(root, manifest.get("provenance"), "build provenance", blockers)
    provenance_doc: dict[str, Any] = {}
    if provenance:
        try:
            provenance_doc = json.loads(provenance.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise AuditError("provenance evidence must be valid JSON") from error
        if commit and provenance_doc.get("sourceCommit") != commit:
            blockers.append("provenance source commit does not match manifest")
        provenance_tree = provenance_doc.get("sourceTreeSha256")
        if provenance_tree is not None and provenance_tree != tree_hash:
            blockers.append("provenance source tree SHA-256 does not match manifest")
        if "sourceArchive" in provenance_doc:
            source_archive = evidence(root, provenance_doc["sourceArchive"], "project source archive", blockers)
            if source_archive:
                verify_source_archive(root, source_archive)

    artifact_records = manifest.get("artifacts")
    if not isinstance(artifact_records, list) or not artifact_records:
        blockers.append("artifact inventory is missing")
        artifact_records = []
    inventory: list[dict[str, Any]] = []
    expected_subjects: set[tuple[str, str]] = set()
    for index, item in enumerate(artifact_records):
        label = f"artifact[{index}]"
        if not isinstance(item, dict):
            blockers.append(f"{label}: record malformed")
            continue
        rel = item.get("path")
        if isinstance(rel, str) and any(existing_path == rel for existing_path, _ in expected_subjects):
            raise AuditError(f"duplicate artifact inventory path: {rel}")
        path = safe_file(root, rel, label)
        if path is None:
            blockers.append(f"{label}: artifact file missing")
            continue
        digest = sha256_file(path)
        size = path.stat().st_size
        if item.get("sha256") != digest:
            raise AuditError(f"{label}: artifact SHA-256 mismatch")
        if item.get("sizeBytes") != size:
            raise AuditError(f"{label}: artifact size mismatch")
        expected_subjects.add((str(rel), digest))
        platform, architecture = item.get("platform"), item.get("architecture")
        if not isinstance(platform, str) or not platform.strip():
            blockers.append(f"{label}: target platform missing")
        if not isinstance(architecture, str) or not architecture.strip():
            blockers.append(f"{label}: target architecture missing")
        evidence(root, item.get("buildEvidence"), f"{label} build evidence", blockers)
        if item.get("verificationStatus") != "passed":
            blockers.append(f"{label}: platform/runtime verification is not passed")
        evidence(root, item.get("verificationEvidence"), f"{label} platform verification", blockers)
        if item.get("signingStatus") != "signed":
            blockers.append(f"{label}: artifact is unsigned or signing status missing")
        evidence(root, item.get("signingEvidence"), f"{label} signing evidence", blockers)

        native_components = item.get("nativeComponents")
        if not isinstance(native_components, list):
            native_components = []
        embedded = artifact_native_members(path, str(rel))
        mapped_members: set[str] = set()
        for native in native_components:
            if not isinstance(native, dict):
                blockers.append(f"{label}: native component record malformed")
                continue
            member = native.get("member")
            component_key = (str(native.get("ecosystem", "")).lower(), str(native.get("name", "")).lower(), str(native.get("version", "")))
            if component_key not in component_map:
                blockers.append(f"{label}: native component missing from locked SBOM inventory")
            if not isinstance(member, str):
                blockers.append(f"{label}: native component member missing")
                continue
            mapped_members.add(member)
            if path.suffix.lower() == ".apk":
                observed = embedded.get(member)
                if observed is None:
                    raise AuditError(f"{label}: native member absent from APK: {member}")
                if native.get("sha256") != observed[1] or native.get("architecture") != observed[0]:
                    raise AuditError(f"{label}: native member hash or architecture mismatch: {member}")
            elif member == "@artifact":
                actual_arch = file_arch(path)
                if actual_arch is None or native.get("sha256") != digest or native.get("architecture") != actual_arch:
                    raise AuditError(f"{label}: native ELF identity mismatch")
            else:
                blockers.append(f"{label}: native member path is unsupported for this artifact type")
            if not isinstance(native.get("sourceUrl"), str) or not native.get("sourceUrl", "").startswith("https://"):
                blockers.append(f"{label}: native source origin missing")
            revision = native.get("sourceRevision")
            if not isinstance(revision, str) or not revision.strip() or PLACEHOLDER_LICENSES.search(revision):
                blockers.append(f"{label}: native source revision/version missing")
            comp = component_map.get(component_key, {})
            if native.get("sourceCorrespondenceStatus") != "verified_binary_source":
                blockers.append(f"{label}: native binary-to-source correspondence is unverified: {member}")
            if not comp.get("licenseExpression") or not comp.get("correspondingSource") or not comp.get("notices"):
                blockers.append(f"{label}: native license/source/notice record incomplete")
        if embedded and set(embedded) != mapped_members:
            blockers.append(f"{label}: native component inventory omits {len(set(embedded) - mapped_members)} embedded shared object(s)")
        if path.suffix.lower() != ".apk" and file_arch(path):
            if not any(isinstance(n, dict) and n.get("member") == "@artifact" for n in native_components):
                blockers.append(f"{label}: ELF artifact lacks native source/license provenance")
        inventory.append({"path": rel, "sizeBytes": size, "sha256": digest, "platform": platform,
                          "architecture": architecture, "kind": item.get("kind")})

    subjects = provenance_doc.get("subjects") if isinstance(provenance_doc, dict) else None
    if not isinstance(subjects, list):
        if artifact_records:
            blockers.append("provenance subject list missing")
    else:
        observed_subjects: set[tuple[str, str]] = set()
        for subject in subjects:
            if isinstance(subject, dict) and isinstance(subject.get("path"), str) and isinstance(subject.get("sha256"), str):
                observed_subjects.add((subject["path"], subject["sha256"]))
        if expected_subjects != observed_subjects:
            blockers.append("provenance subjects do not exactly cover artifact paths and SHA-256 digests")

    status = "blocked" if blockers else "passed"
    return {"schemaVersion": SCHEMA, "status": status, "blockers": blockers, "inventory": inventory}


def scan_inventory(root: pathlib.Path, artifact_args: list[str]) -> dict[str, Any]:
    root = root.resolve(strict=True)
    locks = discover_lockfiles(root)
    artifacts = []
    for rel in artifact_args:
        path = safe_file(root, rel, "artifact")
        if path is None:
            raise AuditError(f"artifact missing: {rel}")
        artifacts.append({"path": path.relative_to(root).as_posix(), "sizeBytes": path.stat().st_size,
                          "sha256": sha256_file(path)})
    clean: bool | None = None
    try:
        commit_result = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False)
        commit = commit_result.stdout.strip() if commit_result.returncode == 0 else None
        if commit:
            status = subprocess.run(["git", "-C", str(root), "status", "--porcelain", "--untracked-files=all"],
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False)
            clean = status.returncode == 0 and not status.stdout.strip()
    except OSError:
        commit = None
    lock_records = [{"path": path.relative_to(root).as_posix(), "sha256": sha256_file(path)} for path in locks]
    packages = [{"ecosystem": eco, "name": name, "version": version}
                for eco, name, version in sorted(locked_components(root, locks))]
    return {"schemaVersion": SCHEMA, "inventoryOnly": True, "sourceCommit": commit, "sourceTreeClean": clean,
            "sourceTreeSha256": source_tree_sha256(root), "artifacts": artifacts,
            "lockfiles": lock_records, "lockedComponents": packages,
            "note": "Inventory only. It does not assert licenses, corresponding source, signing, build provenance, or platform verification."}


def write_json_exclusive(path: pathlib.Path, value: Any) -> None:
    if path.exists() or path.is_symlink():
        raise AuditError("output exists; refusing to overwrite")
    path.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    verify = commands.add_parser("verify", help="verify checksums, lock coverage, SBOM, provenance and release evidence")
    verify.add_argument("--root", type=pathlib.Path, required=True)
    verify.add_argument("--manifest", type=pathlib.Path, default=pathlib.Path("dist/manifest.json"))
    scan = commands.add_parser("inventory", help="write a checksummed inventory draft without licensing/release claims")
    scan.add_argument("--root", type=pathlib.Path, required=True)
    scan.add_argument("--output", type=pathlib.Path, required=True)
    scan.add_argument("--artifact", action="append", default=[])
    args = parser.parse_args(argv)
    try:
        if args.command == "inventory":
            report = scan_inventory(args.root, args.artifact)
            output = args.output if args.output.is_absolute() else args.root / args.output
            write_json_exclusive(output, report)
            print(json.dumps({"status": "inventory_only", "output": str(output),
                              "artifactCount": len(report["artifacts"]), "lockedComponentCount": len(report["lockedComponents"])}))
            return 0
        report = verify_manifest(args.root, args.manifest)
        print(json.dumps(report, indent=2, sort_keys=True))
        return 3 if report["status"] == "blocked" else 0
    except (AuditError, OSError, ValueError) as error:
        print(json.dumps({"status": "invalid", "error": str(error)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
