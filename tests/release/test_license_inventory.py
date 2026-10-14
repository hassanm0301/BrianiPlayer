from __future__ import annotations

import base64
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import tempfile
import unittest
import zipfile
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("license_inventory", ROOT / "tools/release/license_inventory.py")
inventory_tool = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(inventory_tool)


def put(root: pathlib.Path, rel: str, value: bytes | str) -> pathlib.Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value.encode() if isinstance(value, str) else value)
    return path


def nuspec(name: str, version: str, expression: str | None = "MIT") -> bytes:
    license_xml = f'<license type="expression">{expression}</license>' if expression else ""
    return (f'<?xml version="1.0"?><package><metadata><id>{name}</id><version>{version}</version>'
            f'{license_xml}<projectUrl>https://example.invalid/project</projectUrl></metadata></package>').encode()


class LicenseInventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.nuget = self.root / "cache/nuget"
        self.pub = self.root / "cache/pub"
        self.nuget.mkdir(parents=True)
        self.pub.mkdir(parents=True)

        package_bytes = nuspec("Sample.Package", "1.0.0")
        package_dir = self.nuget / "sample.package/1.0.0"
        package_dir.mkdir(parents=True)
        put(package_dir, "sample.package.nuspec", package_bytes)
        put(package_dir, "LICENSE", "Sample NuGet license text\n")
        archive = package_dir / "sample.package.1.0.0.nupkg"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("sample.package.nuspec", package_bytes)
            zf.writestr("LICENSE", "Sample NuGet license text\n")
        digest = hashlib.sha512(archive.read_bytes()).digest()
        self.nuget_hash = base64.b64encode(digest).decode()
        self.original_nuget_content_hash = inventory_tool.nuget_content_hash
        inventory_tool.nuget_content_hash = lambda _path: self.nuget_hash
        put(package_dir, archive.name + ".sha512", self.nuget_hash + "\n")
        put(package_dir, ".nupkg.metadata", json.dumps({"contentHash": self.nuget_hash,
                                                         "source": "https://api.nuget.org/v3/index.json"}))

        pub_dir = self.pub / "hosted/pub.dev/sample_pub-2.3.4"
        put(pub_dir, "pubspec.yaml", "name: sample_pub\nversion: 2.3.4\n")
        put(pub_dir, "LICENSE", "Sample hosted package license text\n")
        pub_hash = "a" * 64
        put(self.pub, "hosted-hashes/pub.dev/sample_pub-2.3.4.sha256", pub_hash + "\n")

        local_dir = self.root / "client/packages/briani_api"
        put(local_dir, "pubspec.yaml", "name: briani_api\nversion: 1.0.0\n")
        put(self.root, "client/pubspec.lock", f'''packages:
  briani_api:
    dependency: "direct main"
    description:
      path: packages/briani_api
      relative: true
    source: path
    version: "1.0.0"
  sample_pub:
    dependency: transitive
    description:
      name: sample_pub
      sha256: "{pub_hash}"
      url: "https://pub.dev"
    source: hosted
    version: "2.3.4"
''')
        put(self.root, "server/packages.lock.json", json.dumps({"dependencies": {
            "net10.0": {"Sample.Package": {"type": "Direct", "resolved": "1.0.0",
                                               "contentHash": self.nuget_hash}}
        }}))

    def tearDown(self):
        inventory_tool.nuget_content_hash = self.original_nuget_content_hash
        self.tmp.cleanup()

    def test_nuget_hash_uses_runtime_content_hash_and_bounds_output(self):
        package = put(self.root, "unused.nupkg", b"package")
        helper = self.original_nuget_content_hash
        result = subprocess.CompletedProcess([], 0, "Verifying package\nContent hash: " + self.nuget_hash + "\n", "")
        with mock.patch.object(inventory_tool.subprocess, "run", return_value=result):
            self.assertEqual(helper(package, dotnet="dotnet"), self.nuget_hash)
        too_large = subprocess.CompletedProcess([], 0, "x" * (64 * 1024 + 1), "")
        with mock.patch.object(inventory_tool.subprocess, "run", return_value=too_large):
            with self.assertRaises(inventory_tool.InventoryError):
                helper(package, dotnet="dotnet")

    def test_canonical_spdx_text_requires_exact_mit_pattern(self):
        canonical = ("MIT License\nCopyright (c) 2025 Example Author\n\n" +
                     inventory_tool.SPDX_MIT_BODY + "\n").encode()
        self.assertEqual(inventory_tool.canonical_spdx_expression(canonical), "MIT")
        self.assertEqual(inventory_tool.canonical_spdx_expression(canonical.replace(
            b"INCLUDING WITHOUT LIMITATION ON THE RIGHTS TO",
            b"INCLUDING WITHOUT LIMITATION THE RIGHTS TO")), "MIT")
        self.assertIsNone(inventory_tool.canonical_spdx_expression(canonical.replace(
            b"FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT",
            b"FITNESS FOR A PARTICULAR PURPOSE AND NON INFRINGEMENT")))
        put(self.pub / "hosted/pub.dev/sample_pub-2.3.4", "LICENSE", canonical)
        result = inventory_tool.build_inventory(self.root, self.nuget, self.pub, self.root / "dist/licenses")
        package = next(x for x in result["components"] if x["purl"] == "pkg:pub/sample_pub@2.3.4")
        self.assertEqual(package["licenseExpression"], "MIT")
        bom = json.loads((self.root / "dist/sbom.json").read_text())
        sbom_package = next(x for x in bom["components"] if x["purl"] == package["purl"])
        self.assertEqual(sbom_package["licenses"], [{"expression": "MIT"}])

    def test_canonical_bsd3_requires_complete_single_license_text(self):
        canonical = ("BSD 3-Clause License\nCopyright (c) 2025 Example Author\n\n" +
                     inventory_tool.SPDX_BSD3_OPENING + "\n* " +
                     inventory_tool.SPDX_BSD3_CONDITION1 + "\n* " +
                     inventory_tool.SPDX_BSD3_CONDITION2 + "\n* Neither the name of Example Author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.\n" +
                     'This software is provided by the copyright holders and contributors "as is" and any express or implied warranties, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose are disclaimed. In no event shall copyright owner or contributors be liable for any direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption) however caused and on any theory of liability, whether in contract, strict liability, or tort (including negligence or otherwise) arising in any way out of the use of this software, even if advised of the possibility of such damage.\n').encode()
        self.assertEqual(inventory_tool.canonical_spdx_expression(canonical), "BSD-3-Clause")
        self.assertIsNone(inventory_tool.canonical_spdx_expression(canonical + b"Additional license text.\n"))
        self.assertIsNone(inventory_tool.canonical_spdx_expression(canonical.replace(
            b"* Neither the name of Example Author", b"* This software")))
        self.assertIsNone(inventory_tool.canonical_spdx_expression(
            b"MIT License\n" + canonical))
        self.assertIsNone(inventory_tool.canonical_spdx_expression(canonical.replace(
            b"Copyright (c) 2025 Example Author", 
            b"Copyright (c) 2025 Example Author; extra text announcing another license")))

    def test_canonical_apache2_requires_full_official_text(self):
        official = pathlib.Path("dist/licenses/reference/Apache-2.0.txt").read_bytes()
        self.assertEqual(inventory_tool.canonical_spdx_expression(official), "Apache-2.0")
        with_holder = official.replace(b"Copyright [yyyy] [name of copyright owner]",
                                       b"Copyright 2025 Example Author")
        self.assertEqual(inventory_tool.canonical_spdx_expression(with_holder), "Apache-2.0")
        self.assertIsNone(inventory_tool.canonical_spdx_expression(with_holder + b"Extra license terms."))
        self.assertIsNone(inventory_tool.canonical_spdx_expression(with_holder.replace(
            b"Copyright 2025 Example Author", b"Copyright 2025 Example Author\nCopyright 2026 Second Author")))

    def test_builds_complete_purls_and_keeps_pub_license_text_unmapped(self):
        result = inventory_tool.build_inventory(self.root, self.nuget, self.pub, self.root / "dist/licenses")
        self.assertEqual(result["lockedPackageCount"], 3)
        components = {(x["ecosystem"], x["name"], x["version"]): x for x in result["components"]}
        nuget = components[("nuget", "sample.package", "1.0.0")]
        self.assertEqual(nuget["purl"], "pkg:nuget/sample.package@1.0.0")
        self.assertEqual(nuget["licenseExpression"], "MIT")
        self.assertEqual(nuget["packageContentHashMatchesLock"], True)
        pub = components[("pub", "sample_pub", "2.3.4")]
        self.assertIsNone(pub["licenseExpression"])
        self.assertEqual(pub["licenseStatus"], "canonical_text_only")
        self.assertEqual(pub["sourceArchiveSha256"], "a" * 64)
        bom = json.loads((self.root / "dist/sbom.json").read_text())
        self.assertEqual(len(bom["components"]), 3)
        pub_bom = next(x for x in bom["components"] if x["purl"] == pub["purl"])
        self.assertEqual(pub_bom["licenses"], [{"license": {"name": "NOASSERTION"}}])
        self.assertTrue((self.root / pub["licenseEvidence"]["path"]).is_file())
        self.assertTrue(any("SPDX license expression unavailable" in item for item in result["blockers"]))

    def test_official_nuspec_fetch_is_identity_checked_and_becomes_license_evidence(self):
        remote = nuspec("Sample.Package", "1.0.0", "Apache-2.0")
        calls = []
        def fetch(name, version, limit):
            url = f"https://api.nuget.org/v3-flatcontainer/{name.lower()}/{version}/{name.lower()}.nuspec"
            calls.append((name, version, limit, url))
            return (url, remote)
        result = inventory_tool.build_inventory(self.root, self.nuget, self.pub, self.root / "dist/licenses",
                                                fetch_nuget_metadata=True, nuget_fetcher=fetch)
        package = next(x for x in result["components"] if x["purl"] == "pkg:nuget/sample.package@1.0.0")
        self.assertEqual(package["licenseExpression"], "Apache-2.0")
        self.assertEqual(package["licenseStatus"], "verified_official_nuget_nuspec_spdx_expression")
        self.assertEqual(package["officialNugetNuspecUrl"], calls[0][3])
        self.assertTrue((self.root / package["officialNugetNuspecEvidence"]["path"]).is_file())
        self.assertEqual(calls[0][2], inventory_tool.MAX_NUGET_METADATA_TOTAL_BYTES)

    def test_lock_hash_mismatch_is_blocked_and_not_reported_as_verified_expression(self):
        put(self.root, "server/packages.lock.json", json.dumps({"dependencies": {
            "net10.0": {"Sample.Package": {"type": "Direct", "resolved": "1.0.0",
                                               "contentHash": base64.b64encode(b"wrong").decode()}}
        }}))
        result = inventory_tool.build_inventory(self.root, self.nuget, self.pub, self.root / "dist/licenses")
        package = next(x for x in result["components"] if x["purl"] == "pkg:nuget/sample.package@1.0.0")
        self.assertIsNone(package["licenseExpression"])
        self.assertEqual(package["observedNuspecLicenseExpression"], "MIT")
        self.assertFalse(package["packageContentHashMatchesLock"])

    def test_rejects_traversal_paths_and_symlink_license_files(self):
        with self.assertRaisesRegex(inventory_tool.InventoryError, "unsafe relative path"):
            inventory_tool.safe_child(self.root, "../outside")
        outside = self.root / "outside.txt"
        outside.write_text("do not copy")
        pub_dir = self.pub / "hosted/pub.dev/sample_pub-2.3.4"
        (pub_dir / "LICENSE").unlink()
        (pub_dir / "LICENSE").symlink_to(outside)
        result = inventory_tool.build_inventory(self.root, self.nuget, self.pub, self.root / "dist/licenses")
        pub = next(x for x in result["components"] if x["purl"] == "pkg:pub/sample_pub@2.3.4")
        self.assertIsNone(pub["licenseEvidence"])
        self.assertTrue(any("symlink" in item and "sample_pub" in item for item in result["blockers"]))
        self.assertFalse(any("outside.txt" in str(path) for path in (self.root / "dist/licenses").rglob("*")))

    def test_license_size_limit_blocks_without_copying_oversized_text(self):
        pub_license = self.pub / "hosted/pub.dev/sample_pub-2.3.4/LICENSE"
        pub_license.write_text("0123456789")
        result = inventory_tool.build_inventory(self.root, self.nuget, self.pub, self.root / "dist/licenses",
                                                max_license_bytes=4)
        pub = next(x for x in result["components"] if x["purl"] == "pkg:pub/sample_pub@2.3.4")
        self.assertIsNone(pub["licenseEvidence"])
        self.assertFalse((self.root / "dist/licenses/pub/sample_pub-2.3.4/LICENSE").exists())
        self.assertTrue(any("exceeds 4 bytes" in item for item in result["blockers"]))


if __name__ == "__main__":
    unittest.main()
