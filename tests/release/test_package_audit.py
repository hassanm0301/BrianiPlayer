from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import pathlib
import tempfile
import tarfile
import unittest
import zipfile
from contextlib import redirect_stdout

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("package_audit", ROOT / "tools/release/package_audit.py")
audit = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(audit)


def put(root: pathlib.Path, rel: str, data: bytes | str) -> pathlib.Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data.encode() if isinstance(data, str) else data)
    return path


def ref(root: pathlib.Path, rel: str) -> dict[str, str]:
    path = root / rel
    return {"path": rel, "sha256": audit.sha256_file(path)}


def elf(machine: int) -> bytes:
    value = bytearray(64)
    value[:6] = b"\x7fELF\x02\x01"
    value[18:20] = machine.to_bytes(2, "little")
    return bytes(value)


class PackageAuditTests(unittest.TestCase):
    def test_source_identity_tracks_executable_mode_and_excludes_generated_swarm_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source = put(root, "script.py", "print('source')")
            source.chmod(0o644)
            before = audit.source_tree_sha256(root)
            put(root, "prototypes/playback/harness/state/credentials.json", "private fixture state")
            self.assertEqual(before, audit.source_tree_sha256(root))
            source.chmod(0o755)
            self.assertNotEqual(before, audit.source_tree_sha256(root))

    def test_declared_release_blockers_are_retained_by_audit(self):
        self.manifest["blockers"] = ["native base inventory incomplete"]
        self.write_manifest()
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual("blocked", report["status"])
        self.assertIn("native base inventory incomplete", report["blockers"])

    def test_wrapper_archive_does_not_prove_native_binary_correspondence(self):
        self.manifest["artifacts"][0]["nativeComponents"][0]["sourceCorrespondenceStatus"] = "unverified"
        self.write_manifest()
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual("blocked", report["status"])
        self.assertTrue(any("binary-to-source" in b for b in report["blockers"]))

    def test_project_source_archive_checks_content_modes_and_unsafe_members(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source = put(root, "app.py", "print('source')")
            source.chmod(0o644)
            archive = root / "dist/source.tar.gz"
            archive.parent.mkdir()
            with tarfile.open(archive, "w:gz") as output:
                output.add(source, arcname="briani-player/app.py")
            audit.verify_source_archive(root, archive)
            source.chmod(0o755)
            with self.assertRaisesRegex(audit.AuditError, "executable modes"):
                audit.verify_source_archive(root, archive)
            source.chmod(0o644)
            with tarfile.open(archive, "w:gz") as output:
                output.add(source, arcname="briani-player/../app.py")
            with self.assertRaisesRegex(audit.AuditError, "unsafe"):
                audit.verify_source_archive(root, archive)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.manifest_path = self.root / "dist/manifest.json"
        put(self.root, "client/pubspec.lock", '''packages:
  dep:
    dependency: "direct main"
    description:
      name: dep
    source: hosted
    version: "1.0.0"
''')
        put(self.root, "server/packages.lock.json", json.dumps({"dependencies": {
            "net10.0": {"Lib": {"type": "Direct", "resolved": "2.0.0", "contentHash": "abcd"}}
        }}))
        for rel, data in {
            "evidence/license-grant.txt": "authorized by owner",
            "evidence/build.txt": "actual build record",
            "evidence/platform.txt": "platform runtime test record",
            "evidence/signature.txt": "signature verification record",
            "licenses/pub-license.txt": "MIT text source from package",
            "licenses/net-license.txt": "Apache text source from package",
            "notices/pub.txt": "notice for pub dep",
            "notices/net.txt": "notice for NuGet Lib",
            "sources/pub.tar": b"pub source archive",
            "sources/net.tar": b"nuget source archive",
        }.items():
            put(self.root, rel, data)
        self.apk_path = self.root / "dist/app.apk"
        self.apk_path.parent.mkdir(parents=True)
        with zipfile.ZipFile(self.apk_path, "w") as apk:
            apk.writestr("lib/arm64-v8a/libnative.so", elf(183))
        put(self.root, "dist/sbom.json", json.dumps({"bomFormat": "CycloneDX", "specVersion": "1.6", "components": [
            {"name": "dep", "version": "1.0.0", "purl": "pkg:pub/dep@1.0.0", "licenses": [{"license": {"id": "MIT"}}]},
            {"name": "Lib", "version": "2.0.0", "purl": "pkg:nuget/lib@2.0.0", "licenses": [{"license": {"id": "Apache-2.0"}}]},
        ]}))

        pub_component = {"ecosystem": "pub", "name": "dep", "version": "1.0.0",
                         "licenseExpression": "MIT", "licenseEvidence": ref(self.root, "licenses/pub-license.txt"),
                         "notices": ref(self.root, "notices/pub.txt"),
                         "correspondingSource": ref(self.root, "sources/pub.tar")}
        net_component = {"ecosystem": "nuget", "name": "lib", "version": "2.0.0",
                         "licenseExpression": "Apache-2.0", "licenseEvidence": ref(self.root, "licenses/net-license.txt"),
                         "notices": ref(self.root, "notices/net.txt"),
                         "correspondingSource": ref(self.root, "sources/net.tar")}
        self.components = [pub_component, net_component]
        self.manifest = {
            "schemaVersion": 1, "sourceCommit": None,
            "sourceTreeSha256": audit.source_tree_sha256(self.root),
            "lockfiles": [{"path": rel, "sha256": audit.sha256_file(self.root / rel)}
                          for rel in ("client/pubspec.lock", "server/packages.lock.json")],
            "components": self.components,
            "projectLicense": {"status": "authorized", "evidence": ref(self.root, "evidence/license-grant.txt")},
            "sbom": {**ref(self.root, "dist/sbom.json"), "format": "CycloneDX"},
            "provenance": None,
            "artifacts": [{
                "path": "dist/app.apk", "sha256": audit.sha256_file(self.apk_path), "sizeBytes": self.apk_path.stat().st_size,
                "platform": "android", "architecture": "arm64-v8a", "kind": "apk",
                "buildEvidence": ref(self.root, "evidence/build.txt"),
                "verificationStatus": "passed", "verificationEvidence": ref(self.root, "evidence/platform.txt"),
                "signingStatus": "signed", "signingEvidence": ref(self.root, "evidence/signature.txt"),
                "nativeComponents": [{"member": "lib/arm64-v8a/libnative.so", "ecosystem": "pub", "name": "dep",
                    "version": "1.0.0", "architecture": "aarch64", "sha256": hashlib.sha256(elf(183)).hexdigest(),
                    "sourceUrl": "https://example.invalid/source", "sourceRevision": "v1.0.0", "sourceCorrespondenceStatus": "verified_binary_source"}]
            }]
        }
        put(self.root, "dist/provenance.json", "")
        self._update_provenance()
        self.write_manifest()

    def tearDown(self):
        self.tmp.cleanup()

    def _update_provenance(self):
        self.manifest["provenance"] = {"path": "dist/provenance.json", "sha256": "0" * 64}
        self.manifest["provenance"].pop("sha256")
        provenance = {"sourceCommit": None, "subjects": [{"path": item["path"], "sha256": item["sha256"]}
                                                            for item in self.manifest["artifacts"]]}
        put(self.root, "dist/provenance.json", json.dumps(provenance))
        self.manifest["provenance"] = ref(self.root, "dist/provenance.json")

    def write_manifest(self):
        self._update_provenance()
        self.manifest["sourceTreeSha256"] = audit.source_tree_sha256(self.root)
        put(self.root, "dist/manifest.json", json.dumps(self.manifest))

    def test_valid_signed_candidate_passes_hash_sbom_lock_and_native_checks(self):
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual(report["status"], "passed", report["blockers"])
        self.assertEqual(report["inventory"][0]["sha256"], self.manifest["artifacts"][0]["sha256"])

    def test_unsigned_or_missing_notice_is_blocked(self):
        self.manifest["artifacts"][0]["signingStatus"] = "unsigned"
        self.manifest["components"][0]["notices"] = None
        self.write_manifest()
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual(report["status"], "blocked")
        self.assertTrue(any("unsigned" in reason for reason in report["blockers"]))
        self.assertTrue(any("notices" in reason for reason in report["blockers"]))

    def test_platform_license_and_source_omissions_are_blocked(self):
        self.manifest["artifacts"][0]["verificationEvidence"] = None
        self.manifest["components"][0]["correspondingSource"] = None
        self.manifest["components"][0]["licenseExpression"] = "NOASSERTION"
        self.write_manifest()
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual(report["status"], "blocked")
        self.assertTrue(any("platform verification: evidence reference missing" in reason for reason in report["blockers"]))
        self.assertTrue(any("correspondingSource: evidence reference missing" in reason for reason in report["blockers"]))
        self.assertTrue(any("SPDX license expression missing" in reason for reason in report["blockers"]))

    def test_source_commit_can_be_truthfully_absent_when_exact_tree_hash_matches(self):
        self.assertIsNone(self.manifest["sourceCommit"])
        self.assertTrue(self.manifest["sourceTreeSha256"])
        self.assertEqual(audit.verify_manifest(self.root, self.manifest_path)["status"], "passed")

    def test_source_tree_identity_ignores_generated_build_dist_and_evidence_outputs(self):
        before = audit.source_tree_sha256(self.root)
        put(self.root, "build/generated.bin", b"build")
        put(self.root, "dist/generated.bin", b"dist")
        put(self.root, "docs/evidence/generated.log", b"evidence")
        self.assertEqual(audit.source_tree_sha256(self.root), before)

    def test_source_tree_identity_rejects_symlink_directories(self):
        outside = pathlib.Path(self.tmp.name).parent / (pathlib.Path(self.tmp.name).name + "-outside")
        outside.mkdir()
        try:
            (self.root / "linked-source").symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(audit.AuditError, "symlink directory"):
                audit.source_tree_sha256(self.root)
        finally:
            outside.rmdir()

    def test_provenance_source_tree_must_match_manifest_identity(self):
        put(self.root, "dist/provenance.json", json.dumps({
            "sourceCommit": None, "sourceTreeSha256": "0" * 64,
            "subjects": [{"path": item["path"], "sha256": item["sha256"]}
                         for item in self.manifest["artifacts"]],
        }))
        self.manifest["provenance"] = ref(self.root, "dist/provenance.json")
        put(self.root, "dist/manifest.json", json.dumps(self.manifest))
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual(report["status"], "blocked")
        self.assertTrue(any("provenance source tree SHA-256" in reason for reason in report["blockers"]))

    def test_modified_artifact_is_hard_checksum_failure(self):
        with (self.root / "dist/app.apk").open("ab") as out:
            out.write(b"tamper")
        with self.assertRaisesRegex(audit.AuditError, "artifact SHA-256 mismatch"):
            audit.verify_manifest(self.root, self.manifest_path)

    def test_path_traversal_and_symlink_artifacts_are_refused(self):
        self.manifest["artifacts"][0]["path"] = "../outside.apk"
        self.write_manifest()
        with self.assertRaisesRegex(audit.AuditError, "unsafe relative path"):
            audit.verify_manifest(self.root, self.manifest_path)
        self.manifest["artifacts"][0]["path"] = "dist/link.apk"
        (self.root / "dist/link.apk").symlink_to(self.root / "dist/app.apk")
        self.write_manifest()
        with self.assertRaisesRegex(audit.AuditError, "symlink path refused"):
            audit.verify_manifest(self.root, self.manifest_path)

    def test_manifest_reports_missing_locks_and_components_as_blocked(self):
        self.manifest["lockfiles"].pop()
        self.manifest["components"].pop()
        self.write_manifest()
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual(report["status"], "blocked")
        self.assertTrue(any("omits lockfiles" in reason for reason in report["blockers"]))
        self.assertTrue(any("SBOM omits" in reason for reason in report["blockers"]))

    def test_sbom_document_must_cover_locked_dependency_identities(self):
        put(self.root, "dist/sbom.json", json.dumps({"bomFormat": "CycloneDX", "specVersion": "1.6", "components": []}))
        self.manifest["sbom"] = {**ref(self.root, "dist/sbom.json"), "format": "CycloneDX"}
        self.write_manifest()
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual(report["status"], "blocked")
        self.assertTrue(any("SBOM document omits" in reason for reason in report["blockers"]))

    def test_sbom_license_expression_must_match_manifest_component(self):
        sbom = {"bomFormat": "CycloneDX", "specVersion": "1.6", "components": [
            {"name": "dep", "version": "1.0.0", "purl": "pkg:pub/dep@1.0.0", "licenses": [{"license": {"id": "BSD-3-Clause"}}]},
            {"name": "Lib", "version": "2.0.0", "purl": "pkg:nuget/lib@2.0.0", "licenses": [{"license": {"id": "Apache-2.0"}}]},
        ]}
        put(self.root, "dist/sbom.json", json.dumps(sbom))
        self.manifest["sbom"] = {**ref(self.root, "dist/sbom.json"), "format": "CycloneDX"}
        self.write_manifest()
        report = audit.verify_manifest(self.root, self.manifest_path)
        self.assertEqual(report["status"], "blocked")
        self.assertTrue(any("license expressions differ" in reason for reason in report["blockers"]))

    def test_native_member_architecture_must_match_apk_abi(self):
        self.manifest["artifacts"][0]["nativeComponents"][0]["architecture"] = "x86_64"
        self.write_manifest()
        with self.assertRaisesRegex(audit.AuditError, "native member hash or architecture mismatch"):
            audit.verify_manifest(self.root, self.manifest_path)

    def test_missing_manifest_returns_blocked(self):
        report = audit.verify_manifest(self.root, pathlib.Path("dist/does-not-exist.json"))
        self.assertEqual(report["status"], "blocked")

    def test_inventory_records_actual_lock_coverage_and_tree_without_inventing_commit(self):
        report = audit.scan_inventory(self.root, ["dist/app.apk"])
        self.assertIsNone(report["sourceCommit"])
        self.assertEqual(len(report["lockedComponents"]), 2)
        self.assertEqual(report["artifacts"][0]["sha256"], audit.sha256_file(self.apk_path))

    def test_cli_uses_distinct_blocked_exit_code_for_unsigned_candidate(self):
        self.manifest["artifacts"][0]["signingStatus"] = "unsigned"
        self.write_manifest()
        with redirect_stdout(io.StringIO()):
            exit_code = audit.main(["verify", "--root", str(self.root), "--manifest", "dist/manifest.json"])
        self.assertEqual(exit_code, 3)


if __name__ == "__main__":
    unittest.main()
