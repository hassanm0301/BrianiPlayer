#!/usr/bin/env python3
"""Build a lock-complete CycloneDX SBOM and local package license inventory.

The tool reads locked identities and installed caches only. It recognizes only
strict canonical MIT, BSD-3-Clause and Apache-2.0 text; it does not assign the Briani
project a license or claim that a cached package tree is corresponding source.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import importlib.util
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from typing import Any

SCHEMA = 1
MAX_NUSPEC_BYTES = 2 * 1024 * 1024
MAX_LICENSE_BYTES = 2 * 1024 * 1024
MAX_PACKAGE_BYTES = 512 * 1024 * 1024
MAX_TREE_FILES = 100_000
MAX_TREE_BYTES = 1024 * 1024 * 1024
MAX_LICENSE_CANDIDATES = 100
MAX_PACKAGE_SCAN_ENTRIES = 20_000
MAX_NUGET_METADATA_TOTAL_BYTES = 64 * 1024 * 1024
PACKAGE_NAME = re.compile(r"^[a-zA-Z0-9_.+-]+$")
LICENSE_NAME = re.compile(r"^(?:license|copying|copyright|notice)(?:$|[._ -])", re.I)
CANONICAL_NAMES = {"license", "license.txt", "license.md", "license.rst", "copying", "copying.txt",
                   "copying.md", "copyright", "notice", "notice.txt", "notice.md"}
EXCLUDED_TREE_DIRS = {".git", ".cxx", ".dart_tool", ".gradle", "build", "ephemeral", "node_modules", "obj", "bin"}

# Narrow matcher for the SPDX MIT canonical text: only the replaceable
# copyright notice and optional heading are removed. SPDX permits matching the
# exact license text with those template fields supplied by the licensor.
SPDX_MIT_BODY = """PERMISSION IS HEREBY GRANTED, FREE OF CHARGE, TO ANY PERSON OBTAINING A COPY OF THIS SOFTWARE AND ASSOCIATED DOCUMENTATION FILES (THE "SOFTWARE"), TO DEAL IN THE SOFTWARE WITHOUT RESTRICTION, INCLUDING WITHOUT LIMITATION ON THE RIGHTS TO USE, COPY, MODIFY, MERGE, PUBLISH, DISTRIBUTE, SUBLICENSE, AND/OR SELL COPIES OF THE SOFTWARE, AND TO PERMIT PERSONS TO WHOM THE SOFTWARE IS FURNISHED TO DO SO, SUBJECT TO THE FOLLOWING CONDITIONS: THE ABOVE COPYRIGHT NOTICE AND THIS PERMISSION NOTICE SHALL BE INCLUDED IN ALL COPIES OR SUBSTANTIAL PORTIONS OF THE SOFTWARE. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."""
SPDX_BSD3_OPENING = ("REDISTRIBUTION AND USE IN SOURCE AND BINARY FORMS, WITH OR WITHOUT MODIFICATION, "
                     "ARE PERMITTED PROVIDED THAT THE FOLLOWING CONDITIONS ARE MET:")
SPDX_BSD3_CONDITION1 = ("REDISTRIBUTIONS OF SOURCE CODE MUST RETAIN THE ABOVE COPYRIGHT NOTICE, "
                        "THIS LIST OF CONDITIONS AND THE FOLLOWING DISCLAIMER.")
SPDX_BSD3_CONDITION2 = ("REDISTRIBUTIONS IN BINARY FORM MUST REPRODUCE THE ABOVE COPYRIGHT NOTICE, "
                        "THIS LIST OF CONDITIONS AND THE FOLLOWING DISCLAIMER IN THE DOCUMENTATION "
                        "AND/OR OTHER MATERIALS PROVIDED WITH THE DISTRIBUTION.")
SPDX_BSD3_DISCLAIMER = ("THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" "
                        "AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE "
                        "IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE "
                        "ARE DISCLAIMED.")
SPDX_APACHE2_TEMPLATE_SHA256 = "af05545a83bab33d44e1cf4cfea0718d298806ec89c3a1d08a65a8cbbb7957f4"
SPDX_BSD3_LIABILITY = ("BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL "
                       "DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; "
                       "LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY "
                       "THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING "
                       "NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF "
                       "ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.")


class InventoryError(ValueError):
    """Malformed lock/cache data or unsafe filesystem path."""


class _NugetRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = urllib.parse.urlparse(newurl)
        if target.scheme != "https" or target.hostname != "api.nuget.org" or target.username or target.password:
            raise InventoryError("NuGet metadata redirect left the official HTTPS host")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_nuget_nuspec(name: str, version: str, max_bytes: int = MAX_NUSPEC_BYTES) -> tuple[str, bytes]:
    if not PACKAGE_NAME.fullmatch(name) or not re.fullmatch(r"[A-Za-z0-9.+_-]+", version):
        raise InventoryError("unsafe NuGet identity for metadata URL")
    lower_name, lower_version = name.lower(), version.lower()
    url = f"https://api.nuget.org/v3-flatcontainer/{lower_name}/{lower_version}/{lower_name}.nuspec"
    opener = urllib.request.build_opener(_NugetRedirectHandler())
    request = urllib.request.Request(url, headers={"User-Agent": "BrianiPlayer-license-inventory/1.0"})
    limit = min(MAX_NUSPEC_BYTES, max(0, max_bytes))
    if limit == 0:
        raise InventoryError("NuGet metadata total byte limit reached")
    try:
        with opener.open(request, timeout=20) as response:
            final = urllib.parse.urlparse(response.geturl())
            if final.scheme != "https" or final.hostname != "api.nuget.org":
                raise InventoryError("NuGet nuspec response left official HTTPS host")
            length = response.headers.get("Content-Length")
            if length and int(length) > limit:
                raise InventoryError("official NuGet nuspec exceeds size limit")
            data = response.read(limit + 1)
            if len(data) > limit:
                raise InventoryError("official NuGet nuspec exceeds size limit")
            if length and len(data) != int(length):
                raise InventoryError("official NuGet nuspec response was truncated")
            return url, data
    except OSError as error:
        raise InventoryError(f"official NuGet nuspec fetch failed: {error}") from error


def _load_audit(root: pathlib.Path):
    audit_path = pathlib.Path(__file__).resolve().with_name("package_audit.py")
    spec = importlib.util.spec_from_file_location("briani_package_audit", audit_path)
    if spec is None or spec.loader is None:
        raise InventoryError("package_audit.py could not be loaded")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _replaceable_copyright_line(line: str) -> bool:
    # SPDX's replaceable copyright fields are commonly a holder and year. Do
    # not remove whole prose lines that happen to begin with that word.
    if len(line) > 512 or not re.match(r"^\s*Copyright\b", line, re.I):
        return False
    if not re.search(r"\b(?:19|20)\d{2}\b", line):
        return False
    legal_prose = r"\b(?:license|permission|redistribution|software|warranty|liability|conditions|disclaimer|must retain|must reproduce|provided by|neither the name)\b"
    return not re.search(legal_prose, line, re.I)


def canonical_spdx_expression(data: bytes) -> str | None:
    """Recognize only strict, single-license MIT and BSD-3-Clause full texts."""
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return None
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [line for line in text.splitlines() if not _replaceable_copyright_line(line)]
    mit_heading = bool(lines and lines[0].strip().casefold() == "mit license")
    if mit_heading:
        lines = lines[1:]
    normalized = " ".join(" ".join(lines).upper().split())
    # SPDX's published MIT matching text marks “on” here as optional.
    normalized = normalized.replace("INCLUDING WITHOUT LIMITATION THE RIGHTS TO",
                                   "INCLUDING WITHOUT LIMITATION ON THE RIGHTS TO")
    if normalized == SPDX_MIT_BODY:
        return "MIT"
    # Apache-2.0 matching text is the official full text with only its one
    # section 4 copyright attribution substituted. Compare a normalized digest
    # against the official Apache, Inc. text copied under dist/licenses/reference.
    apache_lines = [line.strip().upper() for line in text.splitlines() if line.strip()]
    apache_matches: list[int] = []
    for index, line in enumerate(apache_lines):
        template = line == "COPYRIGHT [YYYY] [NAME OF COPYRIGHT OWNER]"
        holder = bool(re.fullmatch(
            r"COPYRIGHT (?:19|20)\d{2}(?:-(?:19|20)\d{2})?(?:,? BY)? "
            r"[A-Z0-9][A-Z0-9 .,&#<>@_()/-]{0,180}", line, re.I))
        if template or holder:
            before = next((x for x in reversed(apache_lines[:index]) if x), "")
            after = next((x for x in apache_lines[index + 1:] if x), "")
            if before.endswith("ARCHIVES.") and after.startswith("LICENSED UNDER THE APACHE LICENSE, VERSION 2.0"):
                apache_matches.append(index)
    if len(apache_matches) == 1:
        apache_lines[apache_matches[0]] = "COPYRIGHT [YYYY] [NAME OF COPYRIGHT OWNER]"
        apache_normalized = " ".join(" ".join(apache_lines).split())
        if apache_normalized.startswith("APACHE LICENSE VERSION 2.0, JANUARY 2004 HTTP://WWW.APACHE.ORG/LICENSES/") and hashlib.sha256(apache_normalized.encode()).hexdigest() == SPDX_APACHE2_TEMPLATE_SHA256:
            return "Apache-2.0"
    start = normalized.find(SPDX_BSD3_OPENING)
    if mit_heading and start >= 0:
        return None
    terminal = "EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
    if start < 0:
        return None
    end_phrase = normalized.rfind(terminal)
    if end_phrase < start:
        return None
    end = end_phrase + len(terminal)
    prefix = normalized[:start].strip()
    prefix_ok = prefix in {"", "BSD 3-CLAUSE LICENSE", "ALL RIGHTS RESERVED.",
                           "BSD 3-CLAUSE LICENSE ALL RIGHTS RESERVED."}
    if prefix.startswith("BSD 3-CLAUSE LICENSE COPYRIGHT"):
        prefix_ok = _replaceable_copyright_line(prefix[len("BSD 3-CLAUSE LICENSE "):])
    elif prefix.startswith("COPYRIGHT"):
        prefix_ok = _replaceable_copyright_line(prefix)
    if not prefix_ok:
        return None
    body = normalized[start:end]
    # The official SPDX matcher permits above/original in conditions 1 and 2.
    body = body.replace("THE ORIGINAL COPYRIGHT NOTICE", "THE ABOVE COPYRIGHT NOTICE")
    clause_pattern = re.compile(
        re.escape(SPDX_BSD3_OPENING) + r"\s*(?:\*\s*)?(?:1[.)]\s*)?" + re.escape(SPDX_BSD3_CONDITION1) +
        r"\s*(?:\*\s*)?(?:2[.)]\s*)?" + re.escape(SPDX_BSD3_CONDITION2) +
        r"\s*(?:\*\s*)?(?:3[.)]\s*)?(?:NEITHER THE NAME OF .{1,180}? NOR THE NAMES OF (?:ITS|THEIR|ANY) CONTRIBUTORS MAY|"
        r"NEITHER THE NAME OF .{1,180}? NOR THE NAMES OF ITS AUTHORS AND CONTRIBUTORS MAY|"
        r"THE NAME OF .{1,180}? MAY NOT) BE USED TO ENDORSE OR PROMOTE PRODUCTS DERIVED FROM THIS SOFTWARE "
        r"WITHOUT (?:SPECIFIC )?PRIOR WRITTEN PERMISSION\.\s*" +
        r"THIS SOFTWARE IS PROVIDED (?:BY )?.{1,180}? \"AS IS\" AND (?:ANY )?EXPRESS(?:ED)? OR IMPLIED "
        r"WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS "
        r"FOR A PARTICULAR PURPOSE ARE DISCLAIMED\.\s*IN NO EVENT SHALL .{1,180}? " +
        re.escape(SPDX_BSD3_LIABILITY), re.S)
    # Replace only the SPDX-permitted `original` notice alternative. The
    # normalized body must end at the canonical BSD-3-Clause terminal sentence.
    if clause_pattern.fullmatch(body) and end == len(normalized):
        return "BSD-3-Clause"
    return None


def hash_file(path: pathlib.Path, max_bytes: int = MAX_PACKAGE_BYTES) -> tuple[str, int]:
    if path.is_symlink() or not path.is_file():
        raise InventoryError(f"expected a regular non-symlink file: {path}")
    size = path.stat().st_size
    if size > max_bytes:
        raise InventoryError(f"file exceeds bounded hash size ({max_bytes} bytes): {path.name}")
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest(), size


def nuget_content_hash(package_path: pathlib.Path, *, dotnet: str | None = None) -> str:
    """Ask the installed NuGet runtime for its signature-normalized package hash.

    Lock-file contentHash is NuGet's unsigned content hash. It intentionally
    excludes package signature data, unlike the raw .nupkg SHA-512 sidecar.
    """
    executable = dotnet or shutil.which("dotnet")
    if not executable:
        raise InventoryError("dotnet CLI unavailable; cannot calculate NuGet package contentHash")
    if package_path.is_symlink() or not package_path.is_file() or package_path.stat().st_size > MAX_PACKAGE_BYTES:
        raise InventoryError("unsafe or oversized NuGet package archive")
    try:
        result = subprocess.run([executable, "nuget", "verify", str(package_path)],
                                check=False, capture_output=True, text=True, timeout=45,
                                env={**os.environ, "DOTNET_CLI_TELEMETRY_OPTOUT": "1"})
    except (OSError, subprocess.TimeoutExpired) as error:
        raise InventoryError(f"NuGet content hash calculation failed: {error}") from error
    if len(result.stdout) + len(result.stderr) > 64 * 1024:
        raise InventoryError("NuGet verifier output exceeds limit")
    if result.returncode != 0:
        raise InventoryError(f"NuGet verifier failed with exit code {result.returncode}")
    matches = re.findall(r"(?m)^Content hash:\s*([A-Za-z0-9+/]{80,90}={0,2})\s*$", result.stdout)
    if len(matches) != 1:
        raise InventoryError("NuGet verifier output did not contain one content hash")
    try:
        decoded = base64.b64decode(matches[0], validate=True)
    except ValueError as error:
        raise InventoryError("NuGet verifier returned malformed content hash") from error
    if len(decoded) != 64:
        raise InventoryError("NuGet verifier returned a non-SHA-512 content hash")
    return base64.b64encode(decoded).decode("ascii")


def safe_child(base: pathlib.Path, relative: str) -> pathlib.Path:
    rel = pathlib.PurePosixPath(relative.replace("\\", "/"))
    if rel.is_absolute() or not rel.parts or any(part in ("", ".", "..") for part in rel.parts):
        raise InventoryError(f"unsafe relative path: {relative!r}")
    target = base
    for part in rel.parts:
        target = target / part
        if target.is_symlink():
            raise InventoryError(f"symlink path refused: {relative}")
    resolved_base = base.resolve(strict=False)
    resolved_target = target.resolve(strict=False)
    if resolved_target != resolved_base and resolved_base not in resolved_target.parents:
        raise InventoryError(f"path escapes base: {relative}")
    return target


def safe_cache_root(path: pathlib.Path, label: str) -> pathlib.Path:
    if path.is_symlink():
        raise InventoryError(f"{label} cache root is a symlink")
    return path.resolve(strict=False)


def write_evidence(root: pathlib.Path, rel: str, data: bytes, *, limit: int = MAX_LICENSE_BYTES) -> dict[str, Any]:
    if len(data) > limit:
        raise InventoryError(f"evidence exceeds {limit} bytes: {rel}")
    target = safe_child(root, rel)
    target.parent.mkdir(parents=True, exist_ok=True)
    # Re-check after creation so no pre-existing symlinked parent is followed.
    target = safe_child(root, rel)
    digest = sha256_bytes(data)
    if target.exists():
        if target.is_symlink() or not target.is_file():
            raise InventoryError(f"unsafe existing evidence target: {rel}")
        current_hash, current_size = hash_file(target, limit)
        if current_hash != digest or current_size != len(data):
            raise InventoryError(f"refusing to replace different evidence file: {rel}")
    else:
        fd, temp_name = tempfile.mkstemp(prefix=".license-", dir=target.parent)
        tmp = pathlib.Path(temp_name)
        try:
            with os.fdopen(fd, "wb") as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            os.replace(tmp, target)
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
    return {"path": rel, "sha256": digest, "sizeBytes": len(data)}


def write_generated(root: pathlib.Path, rel: str, data: bytes, *, limit: int) -> dict[str, Any]:
    """Atomically replace a tool-owned generated index after path validation."""
    if len(data) > limit:
        raise InventoryError(f"generated file exceeds {limit} bytes: {rel}")
    target = safe_child(root, rel)
    target.parent.mkdir(parents=True, exist_ok=True)
    target = safe_child(root, rel)
    if target.exists() and (target.is_symlink() or not target.is_file()):
        raise InventoryError(f"unsafe generated-file target: {rel}")
    fd, temp_name = tempfile.mkstemp(prefix=".inventory-", dir=target.parent)
    tmp = pathlib.Path(temp_name)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
        os.replace(tmp, target)
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    return {"path": rel, "sha256": sha256_bytes(data), "sizeBytes": len(data)}


def read_bounded(path: pathlib.Path, limit: int) -> bytes:
    if path.is_symlink() or not path.is_file():
        raise InventoryError(f"expected regular non-symlink file: {path}")
    if path.stat().st_size > limit:
        raise InventoryError(f"file exceeds {limit} bytes: {path}")
    return path.read_bytes()


def package_tree_hash(package: pathlib.Path) -> tuple[str, int, int]:
    if package.is_symlink() or not package.is_dir():
        raise InventoryError(f"package source directory missing or unsafe: {package}")
    digest = hashlib.sha256()
    total = 0
    count = 0
    for current, dirs, files in os.walk(package, followlinks=False):
        current_path = pathlib.Path(current)
        links = [name for name in dirs if (current_path / name).is_symlink()]
        if links:
            raise InventoryError(f"package source contains symlink directory: {(current_path / sorted(links)[0])}")
        dirs[:] = sorted(name for name in dirs if name not in EXCLUDED_TREE_DIRS)
        for name in sorted(files):
            path = current_path / name
            if path.is_symlink():
                raise InventoryError(f"package source contains symlink file: {path}")
            if not path.is_file():
                continue
            count += 1
            total += path.stat().st_size
            if count > MAX_TREE_FILES or total > MAX_TREE_BYTES:
                raise InventoryError("package source tree exceeds bounded hashing limits")
            rel = path.relative_to(package).as_posix().encode("utf-8")
            file_hash, _ = hash_file(path, MAX_TREE_BYTES)
            digest.update(len(rel).to_bytes(8, "big"))
            digest.update(rel)
            digest.update(bytes.fromhex(file_hash))
    return digest.hexdigest(), count, total


def parse_lock_metadata(lockfiles: list[pathlib.Path], root: pathlib.Path) -> dict[tuple[str, str, str], dict[str, Any]]:
    records: dict[tuple[str, str, str], dict[str, Any]] = {}
    for lock in lockfiles:
        if lock.name == "packages.lock.json":
            try:
                data = json.loads(lock.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as error:
                raise InventoryError(f"invalid NuGet lockfile {lock.relative_to(root)}") from error
            for packages in data.get("dependencies", {}).values():
                if not isinstance(packages, dict):
                    continue
                for name, detail in packages.items():
                    if not isinstance(detail, dict) or not isinstance(detail.get("resolved"), str):
                        continue
                    key = ("nuget", name.lower(), detail["resolved"])
                    record = records.setdefault(key, {"name": name, "lockFiles": [], "contentHashes": set()})
                    if detail.get("contentHash"):
                        record["contentHashes"].add(detail["contentHash"])
                    rel = lock.relative_to(root).as_posix()
                    if rel not in record["lockFiles"]:
                        record["lockFiles"].append(rel)
        else:
            current: str | None = None
            info: dict[str, str] = {}
            def store() -> None:
                if not current or not info.get("version"):
                    return
                key = ("pub", current.lower(), info["version"])
                record = records.setdefault(key, {"name": current, "lockFiles": [], "pubSources": set(), "pubHashes": set(),
                                                  "pubUrls": set(), "pubPaths": set()})
                rel = lock.relative_to(root).as_posix()
                if rel not in record["lockFiles"]:
                    record["lockFiles"].append(rel)
                if info.get("source"):
                    record["pubSources"].add(info["source"])
                if info.get("sha256"):
                    record["pubHashes"].add(info["sha256"])
                if info.get("url"):
                    record["pubUrls"].add(info["url"])
                if info.get("path"):
                    record["pubPaths"].add((lock.parent / info["path"]).resolve(strict=False).as_posix())
            try:
                lines = lock.read_text(encoding="utf-8").splitlines()
            except OSError as error:
                raise InventoryError(f"cannot read pub lockfile {lock.relative_to(root)}") from error
            for line in lines:
                match = re.match(r"^  ([A-Za-z0-9_.+-]+):\s*$", line)
                if match:
                    store()
                    current, info = match.group(1), {}
                    continue
                if not current:
                    continue
                match = re.match(r"^    (source|version):\s*['\"]?([^'\"\s]+)", line)
                if match:
                    info[match.group(1)] = match.group(2)
                    continue
                match = re.match(r"^      (name|sha256|url|path):\s*['\"]?([^'\"]*)['\"]?\s*$", line)
                if match:
                    info[match.group(1)] = match.group(2)
            store()
    for record in records.values():
        for key in ("contentHashes", "pubHashes", "pubUrls", "pubPaths", "pubSources"):
            if key in record:
                record[key] = sorted(record[key])
    return records


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def parse_nuspec(data: bytes, label: str) -> dict[str, Any]:
    if len(data) > MAX_NUSPEC_BYTES:
        raise InventoryError(f"NuGet nuspec exceeds limit: {label}")
    if re.search(br"<!\s*(?:DOCTYPE|ENTITY)\b", data, re.I):
        raise InventoryError(f"DTD/entity declaration refused in nuspec: {label}")
    try:
        root = ET.fromstring(data)
    except ET.ParseError as error:
        raise InventoryError(f"invalid NuGet nuspec: {label}") from error
    metadata = next((child for child in root if local_name(child.tag) == "metadata"), None)
    if metadata is None:
        raise InventoryError(f"NuGet nuspec metadata missing: {label}")
    values: dict[str, Any] = {}
    for child in metadata:
        name = local_name(child.tag)
        if name in {"id", "version", "projectUrl", "licenseUrl", "repository", "license"}:
            if name == "license":
                values["licenseType"] = child.attrib.get("type")
                values["licenseValue"] = (child.text or "").strip()
            elif name == "repository":
                values["repository"] = {**child.attrib}
            else:
                values[name] = (child.text or "").strip()
    return values


def copy_license_tree(package: pathlib.Path, root: pathlib.Path, base_rel: str,
                      blockers: list[str], *, max_license_bytes: int = MAX_LICENSE_BYTES
                      ) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    evidence: list[dict[str, Any]] = []
    notices: list[dict[str, Any]] = []
    candidates: list[tuple[pathlib.Path, str, bool]] = []
    visited = 0
    symlink_seen = False
    for current, dirs, files in os.walk(package, followlinks=False):
        current_path = pathlib.Path(current)
        symlinks = [d for d in dirs if (current_path / d).is_symlink()]
        if symlinks:
            symlink_seen = True
        dirs[:] = sorted(d for d in dirs if not (current_path / d).is_symlink())
        for name in sorted(files):
            visited += 1
            if visited > MAX_PACKAGE_SCAN_ENTRIES:
                blockers.append(f"{base_rel}: package file scan reached {MAX_PACKAGE_SCAN_ENTRIES}-entry limit")
                return evidence, notices
            if not LICENSE_NAME.match(name):
                continue
            path = current_path / name
            rel = path.relative_to(package).as_posix()
            if path.is_symlink():
                symlink_seen = True
                continue
            candidates.append((path, rel, path.parent == package and name.casefold() in CANONICAL_NAMES))
            if len(candidates) >= MAX_LICENSE_CANDIDATES:
                blockers.append(f"{base_rel}: license candidate scan reached {MAX_LICENSE_CANDIDATES}-file limit")
                break
        if len(candidates) >= MAX_LICENSE_CANDIDATES:
            break
    if symlink_seen:
        blockers.append(f"{base_rel}: symlink encountered in package cache scan; skipped")
    root_hashes: set[str] = set()
    for path, rel, is_root_canonical in candidates:
        try:
            data = read_bounded(path, max_license_bytes)
        except InventoryError as error:
            blockers.append(f"{base_rel}: {error}")
            continue
        try:
            data.decode("utf-8-sig", errors="strict")
        except UnicodeDecodeError:
            blockers.append(f"{base_rel}: non-UTF8 license/notice candidate skipped: {rel}")
            continue
        safe_rel = pathlib.PurePosixPath(rel)
        output_rel = (pathlib.PurePosixPath(base_rel) / safe_rel).as_posix()
        ref = write_evidence(root, output_rel, data, limit=max_license_bytes)
        ref["sourceRelativePath"] = rel
        notices.append(ref)
        if is_root_canonical:
            root_hashes.add(ref["sha256"])
            evidence.append(ref)
    # Same bytes under duplicate conventional root names still identify one text.
    if len(root_hashes) > 1:
        evidence = []
    return evidence, notices


def read_zip_license(nupkg: pathlib.Path, member: str, *, max_bytes: int = MAX_LICENSE_BYTES) -> bytes:
    rel = pathlib.PurePosixPath(member.replace("\\", "/"))
    if rel.is_absolute() or not rel.parts or any(part in ("", ".", "..") for part in rel.parts):
        raise InventoryError("unsafe license path declared by NuGet nuspec")
    if nupkg.is_symlink() or not nupkg.is_file() or nupkg.stat().st_size > MAX_PACKAGE_BYTES:
        raise InventoryError("NuGet package archive missing, symlinked, or too large")
    try:
        with zipfile.ZipFile(nupkg) as archive:
            matches = [item for item in archive.infolist() if item.filename == rel.as_posix()]
            if len(matches) != 1:
                raise InventoryError("nuspec-declared license file missing or duplicated in NuGet archive")
            info = matches[0]
            if info.file_size > max_bytes or info.is_dir():
                raise InventoryError("NuGet license member exceeds limit or is not a file")
            unix_mode = (info.external_attr >> 16) & 0xFFFF
            if unix_mode & 0o170000 == 0o120000:
                raise InventoryError("symlink license member refused in NuGet archive")
            with archive.open(info) as stream:
                data = stream.read(max_bytes + 1)
            if len(data) > max_bytes or len(data) != info.file_size:
                raise InventoryError("NuGet license member exceeds limit or is truncated")
            return data
    except zipfile.BadZipFile as error:
        raise InventoryError("invalid NuGet package archive") from error


def pub_lock_records(lock: pathlib.Path, root: pathlib.Path) -> dict[tuple[str, str, str], dict[str, str]]:
    records: dict[tuple[str, str, str], dict[str, str]] = {}
    current: str | None = None
    info: dict[str, str] = {}
    def store() -> None:
        if current and info.get("version"):
            records[("pub", current.lower(), info["version"])] = dict(info)
    for line in lock.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^  ([A-Za-z0-9_.+-]+):\s*$", line)
        if match:
            store()
            current, info = match.group(1), {}
            continue
        if not current:
            continue
        match = re.match(r"^    (source|version):\s*['\"]?([^'\"\s]+)", line)
        if match:
            info[match.group(1)] = match.group(2)
        match = re.match(r"^      (name|sha256|url|path):\s*['\"]?([^'\"]*)['\"]?\s*$", line)
        if match:
            info[match.group(1)] = match.group(2)
    store()
    return records


def package_config_roots(root: pathlib.Path) -> dict[str, pathlib.Path]:
    result: dict[str, pathlib.Path] = {}
    for config in (root / "client/.dart_tool/package_config.json", root / "client/packages/briani_api/.dart_tool/package_config.json"):
        if config.is_symlink() or not config.is_file():
            continue
        try:
            doc = json.loads(read_bounded(config, 8 * 1024 * 1024))
        except (json.JSONDecodeError, InventoryError):
            continue
        for package in doc.get("packages", []):
            name, uri = package.get("name"), package.get("rootUri")
            if not isinstance(name, str) or not isinstance(uri, str):
                continue
            parsed = urllib.parse.urlparse(uri)
            if parsed.scheme == "file":
                path = pathlib.Path(urllib.parse.unquote(parsed.path))
            elif parsed.scheme == "":
                path = (config.parent / urllib.parse.unquote(uri)).resolve(strict=False)
            else:
                continue
            result[name.lower()] = path
    return result


def flutter_revision(root: pathlib.Path) -> tuple[str | None, str | None]:
    try:
        doc = json.loads((root / "toolchain.lock.json").read_text(encoding="utf-8"))
        flutter = doc.get("flutter", {})
        return flutter.get("version"), flutter.get("frameworkRevision")
    except (OSError, json.JSONDecodeError, AttributeError):
        return None, None


def build_inventory(root: pathlib.Path, nuget_cache: pathlib.Path, pub_cache: pathlib.Path,
                    output: pathlib.Path, *, max_license_bytes: int = MAX_LICENSE_BYTES,
                    fetch_nuget_metadata: bool = False,
                    nuget_fetcher=fetch_nuget_nuspec) -> dict[str, Any]:
    if max_license_bytes <= 0 or max_license_bytes > MAX_LICENSE_BYTES:
        raise InventoryError(f"max-license-bytes must be between 1 and {MAX_LICENSE_BYTES}")
    audit = _load_audit(root)
    lockfiles = audit.discover_lockfiles(root)
    locked = audit.locked_components(root, lockfiles)
    lock_metadata = parse_lock_metadata(lockfiles, root)
    pub_details: dict[tuple[str, str, str], dict[str, str]] = {}
    for lock in lockfiles:
        if lock.name == "pubspec.lock":
            pub_details.update(pub_lock_records(lock, root))
    package_roots = package_config_roots(root)
    flutter_version, flutter_revision_sha = flutter_revision(root)
    blockers: list[str] = []
    fetched_nuspec_bytes = 0
    components: list[dict[str, Any]] = []
    bom_components: list[dict[str, Any]] = []
    nuget_base = safe_cache_root(nuget_cache, "NuGet")
    pub_base = safe_cache_root(pub_cache, "pub")

    for ecosystem, norm_name, version in sorted(locked):
        meta = lock_metadata.get((ecosystem, norm_name, version), {})
        name = str(meta.get("name", norm_name))
        if not PACKAGE_NAME.fullmatch(name):
            blockers.append(f"{ecosystem}:{norm_name}@{version}: unsafe package identity")
            name = norm_name
        purl = f"pkg:{ecosystem}/{norm_name}@{version}"
        expression: str | None = None
        license_status = "unknown"
        license_evidence: dict[str, Any] | None = None
        notices: dict[str, Any] | None = None
        evidence_files: list[dict[str, Any]] = []
        notice_files: list[dict[str, Any]] = []
        source_url: str | None = None
        source_kind: str | None = None
        source_path: str | None = None
        source_sha256: str | None = None
        package_sha256: str | None = None
        package_sha512: str | None = None
        package_content_hash: str | None = None
        package_size: int | None = None
        license_url: str | None = None
        metadata_ref: dict[str, Any] | None = None
        observed_license_expression: str | None = None
        upstream_nuspec_ref: dict[str, Any] | None = None
        nuget_metadata_url: str | None = None
        archive_lock_hash: str | None = None
        cache_recorded_hash: str | None = None
        content_hash_matches_lock: bool | None = None

        key = f"{norm_name}-{version}"
        if ecosystem == "nuget":
            pkg_dir = safe_child(nuget_base, f"{norm_name}/{version}")
            if pkg_dir.is_symlink() or not pkg_dir.is_dir():
                blockers.append(f"{purl}: NuGet cache directory missing")
                source_url = f"https://www.nuget.org/packages/{urllib.parse.quote(name, safe='.-_~')}/{urllib.parse.quote(version, safe='.-_~')}"
            else:
                try:
                    nuspecs = sorted(pkg_dir.glob("*.nuspec"))
                    if len(nuspecs) != 1 or nuspecs[0].is_symlink():
                        raise InventoryError("NuGet cache must have exactly one regular nuspec")
                    nuspec_bytes = read_bounded(nuspecs[0], MAX_NUSPEC_BYTES)
                    nuspec = parse_nuspec(nuspec_bytes, purl)
                    if nuspec.get("id", "").lower() != norm_name or nuspec.get("version") != version:
                        raise InventoryError("NuGet nuspec identity/version differs from lock")
                    metadata_ref = write_evidence(root, f"dist/licenses/metadata/nuget/{norm_name}-{version}.cache.nuspec",
                                                  nuspec_bytes, limit=MAX_NUSPEC_BYTES)
                    evidence_files.append(metadata_ref)
                    selected_nuspec = nuspec
                    selected_metadata_ref = metadata_ref
                    local_expr = str(nuspec.get("licenseValue")) if nuspec.get("licenseType") == "expression" and nuspec.get("licenseValue") else None
                    observed_license_expression = local_expr
                    if fetch_nuget_metadata:
                        try:
                            if fetched_nuspec_bytes >= MAX_NUGET_METADATA_TOTAL_BYTES:
                                raise InventoryError("official NuGet nuspec collection reached the 64 MiB total limit")
                            nuget_metadata_url, upstream_bytes = nuget_fetcher(
                                name, version, MAX_NUGET_METADATA_TOTAL_BYTES - fetched_nuspec_bytes)
                            fetched_nuspec_bytes += len(upstream_bytes)
                            if fetched_nuspec_bytes > MAX_NUGET_METADATA_TOTAL_BYTES:
                                raise InventoryError("official NuGet nuspec collection exceeded 64 MiB total limit")
                            upstream_nuspec = parse_nuspec(upstream_bytes, purl)
                            if upstream_nuspec.get("id", "").lower() != norm_name or upstream_nuspec.get("version") != version:
                                raise InventoryError("official NuGet nuspec identity/version differs from lock")
                            upstream_nuspec_ref = write_evidence(
                                root, f"dist/licenses/metadata/nuget/{norm_name}-{version}.upstream.nuspec",
                                upstream_bytes, limit=MAX_NUSPEC_BYTES)
                            selected_nuspec = upstream_nuspec
                            selected_metadata_ref = upstream_nuspec_ref
                        except (OSError, InventoryError) as error:
                            blockers.append(f"{purl}: official nuspec unavailable: {error}")
                    if selected_nuspec.get("licenseType") == "file" and selected_nuspec.get("licenseValue"):
                        try:
                            archive = safe_child(pkg_dir, f"{norm_name}.{version}.nupkg")
                            content = read_zip_license(archive, str(selected_nuspec["licenseValue"]), max_bytes=max_license_bytes)
                            ref = write_evidence(root, f"dist/licenses/nuget/{key}/declared-license-{pathlib.PurePosixPath(str(selected_nuspec['licenseValue'])).name}",
                                                 content, limit=max_license_bytes)
                            notice_files.append(ref)
                            if selected_metadata_ref:
                                license_evidence = selected_metadata_ref
                        except InventoryError as error:
                            blockers.append(f"{purl}: {error}")
                    elif selected_nuspec.get("licenseType") == "expression" and selected_nuspec.get("licenseValue"):
                        observed_license_expression = str(selected_nuspec["licenseValue"])
                        license_url = selected_nuspec.get("licenseUrl") if isinstance(selected_nuspec.get("licenseUrl"), str) else None
                        if fetch_nuget_metadata:
                            expression = observed_license_expression
                            license_status = "verified_official_nuget_nuspec_spdx_expression"
                            license_evidence = selected_metadata_ref
                    elif license_url is None:
                        license_url = selected_nuspec.get("licenseUrl") if isinstance(selected_nuspec.get("licenseUrl"), str) else None
                    source_url = f"https://www.nuget.org/packages/{urllib.parse.quote(name, safe='.-_~')}/{urllib.parse.quote(version, safe='.-_~')}"
                    source_kind = "nuget-package-cache"
                    source_path = str(pkg_dir)
                    package_path = safe_child(pkg_dir, f"{norm_name}.{version}.nupkg")
                    package_sha256, package_size = hash_file(package_path)
                    digest = hashlib.sha512()
                    with package_path.open("rb") as stream:
                        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                            digest.update(chunk)
                    package_sha512 = base64.b64encode(digest.digest()).decode("ascii")
                    package_content_hash = nuget_content_hash(package_path)
                    expected_hashes = meta.get("contentHashes", [])
                    archive_lock_hash = expected_hashes[0] if len(expected_hashes) == 1 else None
                    if len(expected_hashes) != 1:
                        blockers.append(f"{purl}: lock contentHash missing or inconsistent")
                    elif package_content_hash != expected_hashes[0]:
                        content_hash_matches_lock = False
                        blockers.append(f"{purl}: NuGet runtime contentHash does not match lock contentHash")
                    else:
                        content_hash_matches_lock = True
                        if expression is None and local_expr:
                            expression = local_expr
                            license_status = "verified_locked_nuspec_spdx_expression"
                            license_evidence = selected_metadata_ref
                    metadata_sidecar = safe_child(pkg_dir, ".nupkg.metadata")
                    if metadata_sidecar.is_file() and not metadata_sidecar.is_symlink():
                        cache_record = json.loads(read_bounded(metadata_sidecar, 4096))
                        cache_recorded_hash = cache_record.get("contentHash")
                        if archive_lock_hash and cache_recorded_hash != archive_lock_hash:
                            blockers.append(f"{purl}: .nupkg.metadata contentHash differs from lock")
                    else:
                        blockers.append(f"{purl}: .nupkg.metadata missing")
                    sidecar = safe_child(pkg_dir, f"{norm_name}.{version}.nupkg.sha512")
                    if sidecar.is_file() and not sidecar.is_symlink():
                        cache_hash = read_bounded(sidecar, 1024).decode("ascii", "strict").strip()
                        if package_sha512 != cache_hash:
                            blockers.append(f"{purl}: NuGet cache sidecar SHA-512 mismatch")
                    else:
                        blockers.append(f"{purl}: NuGet cache .nupkg.sha512 missing")
                    license_evidence_files, local_notices = copy_license_tree(
                        pkg_dir, root, f"dist/licenses/nuget/{key}", blockers,
                        max_license_bytes=max_license_bytes)
                    notice_files.extend(local_notices)
                    if license_evidence is None and len(license_evidence_files) == 1:
                        license_evidence = license_evidence_files[0]
                        license_status = "canonical_text_only"
                    if not notice_files:
                        # The exact nuspec is evidence of declared metadata, but not a notice text.
                        notices = None
                except (OSError, InventoryError, UnicodeError, zipfile.BadZipFile) as error:
                    blockers.append(f"{purl}: {error}")
                    if source_url is None:
                        source_url = f"https://www.nuget.org/packages/{urllib.parse.quote(name, safe='.-_~')}/{urllib.parse.quote(version, safe='.-_~')}"
        elif ecosystem == "pub":
            detail = pub_details.get((ecosystem, norm_name, version), {})
            pub_source = detail.get("source")
            lock_hash = detail.get("sha256")
            if pub_source == "hosted":
                host_url = detail.get("url", "https://pub.dev").rstrip("/")
                parsed = urllib.parse.urlparse(host_url)
                if parsed.scheme != "https" or not parsed.hostname:
                    blockers.append(f"{purl}: pub lock contains invalid hosted source URL")
                else:
                    source_url = f"{host_url}/packages/{urllib.parse.quote(name, safe='-_.')}/versions/{urllib.parse.quote(version, safe='-_.+')}"
                    source_kind = "pub-hosted-package"
                    archive_digest = lock_hash
                    if not isinstance(archive_digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", archive_digest):
                        blockers.append(f"{purl}: pub lock SHA-256 missing or malformed")
                    else:
                        source_sha256 = archive_digest.lower()
                    host = parsed.hostname.lower()
                    if not re.fullmatch(r"[a-z0-9.-]+", host):
                        blockers.append(f"{purl}: invalid pub host path")
                        package_dir = None
                    else:
                        package_dir = safe_child(pub_base, f"hosted/{host}/{norm_name}-{version}")
                    cache_hash_rel = f"hosted-hashes/{host}/{norm_name}-{version}.sha256"
                    cache_hash_path = safe_child(pub_base, cache_hash_rel)
                    if not cache_hash_path.is_file() or cache_hash_path.is_symlink():
                        blockers.append(f"{purl}: pub cache hash metadata missing")
                    elif source_sha256:
                        try:
                            cache_hash = read_bounded(cache_hash_path, 256).decode("ascii", "strict").strip().lower()
                            if cache_hash != source_sha256:
                                blockers.append(f"{purl}: pub cache hash metadata differs from lock SHA-256")
                        except (InventoryError, UnicodeError) as error:
                            blockers.append(f"{purl}: invalid pub cache hash metadata: {error}")
                    if package_dir is not None and package_dir.is_dir() and not package_dir.is_symlink():
                        source_path = str(package_dir)
                        try:
                            source_tree, _, _ = package_tree_hash(package_dir)
                            package_sha256 = source_tree
                            evidence, notice_files = copy_license_tree(package_dir, root, f"dist/licenses/pub/{key}", blockers,
                                                                       max_license_bytes=max_license_bytes)
                            if len(evidence) == 1:
                                license_evidence = evidence[0]
                                license_status = "canonical_text_only"
                            elif len(evidence) > 1:
                                hashes = {item["sha256"] for item in evidence}
                                if len(hashes) == 1:
                                    license_evidence = evidence[0]
                                    license_status = "canonical_text_only_duplicate_names_same_text"
                                else:
                                    blockers.append(f"{purl}: multiple differing top-level license texts; expression unresolved")
                            if not notice_files:
                                blockers.append(f"{purl}: cached hosted package has no local license/notice text")
                        except (OSError, InventoryError) as error:
                            blockers.append(f"{purl}: {error}")
                    else:
                        blockers.append(f"{purl}: pub hosted package cache directory missing")
            elif pub_source == "path":
                paths = meta.get("pubPaths", [])
                source_url = None
                source_kind = "workspace-path"
                if len(paths) != 1:
                    blockers.append(f"{purl}: path source location missing or inconsistent in locks")
                else:
                    package_dir = pathlib.Path(paths[0])
                    try:
                        package_dir.relative_to(root)
                        source_path = package_dir.relative_to(root).as_posix()
                        pubspec = read_bounded(safe_child(package_dir, "pubspec.yaml"), MAX_NUSPEC_BYTES)
                        version_match = re.search(rb"(?m)^version:\s*['\"]?([^'\"\s]+)", pubspec)
                        if version_match and version_match.group(1).decode() != version:
                            blockers.append(f"{purl}: local pubspec version differs from lock")
                        repo_match = re.search(rb"(?m)^(?:repository|homepage):\s*['\"]?(https://[^'\"\s]+)", pubspec)
                        if repo_match:
                            source_url = repo_match.group(1).decode("utf-8")
                        package_sha256, _, _ = package_tree_hash(package_dir)
                        evidence, notice_files = copy_license_tree(package_dir, root, f"dist/licenses/pub/{key}", blockers,
                                                                   max_license_bytes=max_license_bytes)
                        if len(evidence) == 1:
                            license_evidence = evidence[0]
                            license_status = "canonical_text_only"
                        elif len(evidence) > 1:
                            hashes = {item["sha256"] for item in evidence}
                            if len(hashes) == 1:
                                license_evidence = evidence[0]
                                license_status = "canonical_text_only_duplicate_names_same_text"
                            else:
                                blockers.append(f"{purl}: multiple differing top-level license texts; expression unresolved")
                    except (ValueError, OSError, InventoryError) as error:
                        blockers.append(f"{purl}: local source package unavailable/unsafe: {error}")
            elif pub_source == "sdk":
                package_root = package_roots.get(norm_name)
                source_kind = "flutter-sdk"
                source_url = f"https://github.com/flutter/flutter/tree/{flutter_revision_sha}" if flutter_revision_sha else None
                if source_url is None:
                    blockers.append(f"{purl}: Flutter SDK revision missing from toolchain.lock.json")
                if package_root and package_root.is_dir() and not package_root.is_symlink():
                    try:
                        source_path = package_root.as_posix()
                        package_sha256, _, _ = package_tree_hash(package_root)
                        evidence, notice_files = copy_license_tree(package_root, root, f"dist/licenses/sdk/{key}", blockers,
                                                                   max_license_bytes=max_license_bytes)
                        if len(evidence) == 1:
                            license_evidence = evidence[0]
                            license_status = "canonical_text_only"
                        elif len(evidence) > 1 and len({x["sha256"] for x in evidence}) == 1:
                            license_evidence = evidence[0]
                            license_status = "canonical_text_only_duplicate_names_same_text"
                    except (OSError, InventoryError) as error:
                        blockers.append(f"{purl}: {error}")
                else:
                    blockers.append(f"{purl}: Flutter SDK package source path unavailable")
            else:
                blockers.append(f"{purl}: unsupported pub source kind {pub_source!r}")

        if expression is None and ecosystem == "pub" and license_evidence:
            try:
                evidence_path = safe_child(root, license_evidence["path"])
                if evidence_path.stat().st_size <= MAX_LICENSE_BYTES:
                    expression = canonical_spdx_expression(evidence_path.read_bytes())
                    if expression:
                        license_status = "verified_spdx_canonical_text_expression"
            except (OSError, InventoryError):
                pass
        if expression is None:
            license_status = "unknown" if license_status == "unknown" else license_status
            blockers.append(f"{purl}: SPDX license expression unavailable; SBOM records NOASSERTION")
        if not evidence_files and license_evidence:
            evidence_files.append(license_evidence)
        if notices is None and notice_files:
            notices = notice_files[0]
        if license_evidence is None and evidence_files:
            license_evidence = evidence_files[0]

        component = {
            "ecosystem": ecosystem, "name": norm_name, "version": version, "purl": purl,
            "licenseExpression": expression, "observedNuspecLicenseExpression": observed_license_expression,
            "licenseStatus": license_status,
            "licenseEvidence": license_evidence, "notices": notices,
            "correspondingSource": None, "sourceUrl": source_url, "sourceKind": source_kind,
            "sourcePath": source_path, "sourceTreeSha256": package_sha256,
            "sourceArchiveSha256": source_sha256, "packageSha256": package_sha256 if ecosystem == "nuget" else None,
            "packageSizeBytes": package_size, "packageSha512": package_sha512,
            "nugetContentHash": package_content_hash,
            "packageLockContentHash": archive_lock_hash, "cacheRecordedContentHash": cache_recorded_hash,
            "packageContentHashMatchesLock": content_hash_matches_lock,
            "officialNugetNuspecUrl": nuget_metadata_url,
            "officialNugetNuspecEvidence": upstream_nuspec_ref,
            "licenseUrlMetadata": license_url, "metadataEvidence": metadata_ref,
            "lockFiles": sorted(meta.get("lockFiles", [])), "noticeFiles": notice_files,
        }
        components.append(component)
        license_record: dict[str, Any]
        if expression:
            license_record = {"expression": expression}
        else:
            license_record = {"license": {"name": "NOASSERTION"}}
        bom_component: dict[str, Any] = {
            "type": "library", "name": norm_name, "version": version, "purl": purl,
            "licenses": [license_record],
            "properties": [
                {"name": "briani:ecosystem", "value": ecosystem},
                {"name": "briani:licenseStatus", "value": license_status},
                {"name": "briani:sourceKind", "value": source_kind or "unknown"},
            ],
        }
        if source_url and source_url.startswith("https://"):
            bom_component["externalReferences"] = [{"type": "website", "url": source_url}]
        if ecosystem == "nuget" and package_sha256 and package_sha512:
            bom_component["hashes"] = [
                {"alg": "SHA-256", "content": package_sha256},
                {"alg": "SHA-512", "content": base64.b64decode(package_sha512).hex()},
            ]
        elif ecosystem == "pub" and source_sha256:
            bom_component["hashes"] = [{"alg": "SHA-256", "content": source_sha256}]
        elif source_path and package_sha256:
            bom_component["hashes"] = [{"alg": "SHA-256", "content": package_sha256}]
        bom_components.append(bom_component)

    # Package identities are unique by the exact keys used by package_audit.
    if len({(c["ecosystem"], c["name"].lower(), c["version"]) for c in components}) != len(locked):
        blockers.append("inventory component identity set differs from locked package identities")
    locks_record = [{"path": path.relative_to(root).as_posix(), "sha256": hash_file(path)[0]} for path in lockfiles]
    sbom = {
        "bomFormat": "CycloneDX", "specVersion": "1.6", "version": 1,
        "metadata": {
            "timestamp": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
            "component": {"type": "application", "name": "Briani Player"},
            "tools": {"components": [{"type": "application", "name": "Briani license inventory", "version": "1"}]},
        },
        "components": bom_components,
    }
    try:
        output_rel = output.relative_to(root)
    except ValueError as error:
        raise InventoryError("output directory must stay inside repository root") from error
    safe_child(root, output_rel.as_posix())
    if output.exists() and (output.is_symlink() or not output.is_dir()):
        raise InventoryError("output directory must be a real directory")
    if output != root and root not in output.resolve(strict=False).parents:
        raise InventoryError("output directory must stay inside repository root")
    output.mkdir(parents=True, exist_ok=True)
    if output.is_symlink():
        raise InventoryError("output directory is a symlink")
    sbom_rel = "dist/sbom.json"
    sbom_bytes = (json.dumps(sbom, indent=2, sort_keys=True) + "\n").encode("utf-8")
    sbom_ref = write_generated(root, sbom_rel, sbom_bytes, limit=256 * 1024 * 1024)
    inventory = {
        "schemaVersion": SCHEMA, "status": "blocked" if blockers else "complete", "lockedPackageCount": len(locked),
        "lockfiles": locks_record, "sbom": sbom_ref, "components": components,
        "blockers": sorted(set(blockers)),
        "policy": {
            "spdxFromNuGetNuspecExpressionOnly": True,
            "pubCanonicalSpdxTextMatcher": ["MIT", "BSD-3-Clause", "Apache-2.0"],
            "missingSbomLicense": "NOASSERTION",
            "correspondingSourceArchiveClaimed": False,
            "ownerProjectLicenseGrant": "not provided",
        },
    }
    inventory_bytes = (json.dumps(inventory, indent=2, sort_keys=True) + "\n").encode("utf-8")
    write_generated(root, "dist/licenses/inventory.json", inventory_bytes, limit=64 * 1024 * 1024)
    readme = (
        "# Dependency license inventory\n\n"
        f"This generated inventory covers {len(locked)} identities from {len(lockfiles)} lockfiles. "
        "Expressions are copied from NuGet nuspec SPDX metadata or recognized only when a complete pub license file matches canonical SPDX MIT, BSD-3-Clause or Apache-2.0 text. Other pub/local text remains evidence without an inferred expression. Unknown expressions are emitted as NOASSERTION and listed as blockers. No owner project license grant is asserted.\n\n"
        "See `inventory.json` and `../sbom.json` for hashes, source URLs, lock identities and item-level evidence.\n"
    ).encode()
    write_generated(root, "dist/licenses/README.md", readme, limit=1024 * 1024)
    return inventory


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path.cwd())
    parser.add_argument("--nuget-cache", type=pathlib.Path,
                        default=pathlib.Path(os.environ.get("NUGET_PACKAGES", pathlib.Path.home() / ".nuget/packages")))
    parser.add_argument("--pub-cache", type=pathlib.Path,
                        default=pathlib.Path(os.environ.get("PUB_CACHE", pathlib.Path.home() / ".pub-cache")))
    parser.add_argument("--max-license-bytes", type=int, default=MAX_LICENSE_BYTES)
    parser.add_argument("--fetch-nuget-metadata", action="store_true",
                        help="fetch version-specific nuspec files from api.nuget.org (network required, total capped at 64 MiB)")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    try:
        result = build_inventory(root, args.nuget_cache, args.pub_cache, root / "dist/licenses",
                                 max_license_bytes=args.max_license_bytes,
                                 fetch_nuget_metadata=args.fetch_nuget_metadata)
    except (InventoryError, OSError) as error:
        print(json.dumps({"status": "error", "error": str(error)}, indent=2), file=sys.stderr)
        return 2
    counts: dict[str, int] = {}
    for item in result["components"]:
        status = item["licenseStatus"]
        counts[status] = counts.get(status, 0) + 1
    print(json.dumps({"status": result["status"], "lockedPackageCount": result["lockedPackageCount"],
                      "licenseStatusCounts": counts, "blockerCount": len(result["blockers"]),
                      "sbom": result["sbom"]["path"], "inventory": "dist/licenses/inventory.json"}, indent=2))
    return 0 if result["status"] == "complete" else 3


if __name__ == "__main__":
    sys.exit(main())
