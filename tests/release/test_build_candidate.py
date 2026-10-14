from __future__ import annotations

import hashlib
import json
import pathlib
import tarfile
import tempfile
import unittest

from tools.release import build_candidate as tool


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class CandidateAssemblyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        (self.root / "src").mkdir()
        (self.root / "src/main.txt").write_text("source\n")
        (self.root / "src/run.sh").write_text("#!/bin/sh\n")
        (self.root / "src/run.sh").chmod(0o755)
        (self.root / "src/build").mkdir()
        (self.root / "src/build/generated.txt").write_text("ignored")
        (self.root / "evidence").mkdir()
        for name, content in (("build.txt", "build"), ("verify.txt", "verify"),
                              ("sign.txt", "unsigned"), ("license.txt", "MIT"),
                              ("notice.txt", "Notice"), ("source.txt", "source origin"),
                              ("sbom.json", '{"bomFormat":"CycloneDX"}')):
            (self.root / "evidence" / name).write_text(content)
        (self.root / "dist/licenses").mkdir(parents=True)
        (self.root / "dist/sources/packages").mkdir(parents=True)
        (self.root / "dist/licenses/pub/characters-1.4.1/third_party/Wikipedia").mkdir(parents=True)
        (self.root / "dist/licenses/pub/characters-1.4.1/third_party/Wikipedia/License CC BY-SA 3.0.txt").write_text("fixture notice")
        (self.root / "dist/sbom.json").write_text('{"bomFormat":"CycloneDX"}\n')
        self._write_inventory()
        self.inputs = {
            "schemaVersion": 1,
            "sourceCommit": None,
            "artifacts": [{
                "path": "src/run.sh", "platform": "linux", "architecture": "x86_64", "kind": "binary",
                "buildEvidence": self.ref("build.txt"), "verificationStatus": "passed",
                "verificationEvidence": self.ref("verify.txt"), "signingStatus": "unsigned",
                "signingEvidence": self.ref("sign.txt"),
            }],
            "bundles": [{
                "kind": "linux", "path": "dist/client/briani-player-linux-x64.tar.gz",
                "sourceDirectory": "src", "artifact": {
                    "platform": "linux", "architecture": "x86_64", "kind": "application-bundle",
                    "buildEvidence": self.ref("build.txt"), "verificationStatus": "passed",
                    "verificationEvidence": self.ref("verify.txt"), "signingStatus": "unsigned",
                    "signingEvidence": self.ref("sign.txt"),
                },
            }],
        }
        (self.root / "dist/candidate-inputs.json").write_text(json.dumps(self.inputs))

    def tearDown(self):
        self.tmp.cleanup()

    def ref(self, name: str) -> dict[str, str]:
        path = self.root / "evidence" / name
        return {"path": f"evidence/{name}", "sha256": digest(path)}

    def _write_inventory(self):
        license_ref = self.ref("license.txt")
        notice_ref = self.ref("notice.txt")
        source_ref = self.ref("source.txt")
        component = {
            "ecosystem": "pub", "name": "sample", "version": "1.0.0",
            "licenseExpression": "MIT", "licenseEvidence": license_ref,
            "noticeFiles": [notice_ref],
            "correspondingSource": {"kind": "test", "archivePath": source_ref["path"],
                                    "archiveSha256": source_ref["sha256"]},
        }
        (self.root / "dist/licenses/inventory.json").write_text(json.dumps({
            "schemaVersion": 1, "components": [component], "blockers": [], "sourceBlockers": []
        }))
        (self.root / "dist/sources/packages/manifest.json").write_text(json.dumps({
            "schemaVersion": 1, "packages": [], "nugetRepositorySourceBlockers": []
        }))

    def test_deterministic_source_and_linux_archives_preserve_exec_and_manifest_evidence(self):
        manifest = tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        source_archive = self.root / "dist/sources/briani-player-source.tar.gz"
        linux_archive = self.root / "dist/client/briani-player-linux-x64.tar.gz"
        first_hashes = (digest(source_archive), digest(linux_archive))
        with tarfile.open(linux_archive, "r:gz") as archive:
            self.assertIn("briani-player-linux-x64/run.sh", archive.getnames())
            run = archive.getmember("briani-player-linux-x64/run.sh")
            self.assertEqual(run.mode & 0o777, 0o755)
            self.assertNotIn("briani-player-linux-x64/build/generated.txt", archive.getnames())
        self.assertEqual(manifest["sourceTreeSha256"], tool.source_tree_sha256(self.root))
        self.assertEqual(manifest["sourceCommit"], None)
        self.assertEqual(manifest["artifacts"][1]["sha256"], digest(linux_archive))
        provenance = json.loads((self.root / "dist/provenance.json").read_text())
        expected_subjects = [
            {"path": item["path"], "sha256": item["sha256"]} for item in manifest["artifacts"]
        ]
        self.assertEqual(provenance["subjects"], sorted(expected_subjects, key=lambda x: x["path"]))
        self.assertEqual((self.root / "dist/manifest.json").is_file(), True)
        self.assertEqual((self.root / "dist/SHA256SUMS").is_file(), True)
        sums = (self.root / "dist/SHA256SUMS").read_text().splitlines()
        self.assertEqual(sums[0], tool.CHECKSUM_HEADER)
        sum_paths = {line.split("  ", 1)[1] for line in sums[1:]}
        self.assertIn("dist/manifest.json", sum_paths)
        self.assertIn("dist/provenance.json", sum_paths)
        self.assertNotIn("dist/SHA256SUMS", sum_paths)
        self.assertNotIn("dist/candidate-inputs.json", sum_paths)
        # An identical rerun is safe and retains deterministic bytes.
        tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        self.assertEqual(first_hashes, (digest(source_archive), digest(linux_archive)))

    def test_symlink_in_source_is_rejected(self):
        (self.root / "src/link").symlink_to(self.root / "evidence/build.txt")
        with self.assertRaises((tool.CandidateError, tool.AuditError)):
            tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))

    def test_unexpected_existing_generated_archive_is_not_overwritten(self):
        destination = self.root / "dist/sources/briani-player-source.tar.gz"
        destination.write_bytes(b"unexpected")
        with self.assertRaises((tool.CandidateError, tool.AuditError)):
            tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        self.assertEqual(destination.read_bytes(), b"unexpected")

    def test_wrong_bundle_output_path_is_rejected_before_creating_it(self):
        self.inputs["bundles"][0]["path"] = "dist/server/generated.tar.gz"
        (self.root / "dist/candidate-inputs.json").write_text(json.dumps(self.inputs))
        with self.assertRaises(tool.CandidateError):
            tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        self.assertFalse((self.root / "dist/server").exists())

    def test_symlinked_output_ancestor_is_rejected(self):
        outside = self.root / "outside"
        outside.mkdir()
        client = self.root / "dist/client"
        client.mkdir()
        client.rmdir()
        client.symlink_to(outside, target_is_directory=True)
        with self.assertRaises(tool.CandidateError):
            tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        self.assertEqual(list(outside.iterdir()), [])

    def test_symlinked_source_directory_ancestor_is_rejected(self):
        target = self.root / "outside-source"
        target.mkdir()
        (target / "app.txt").write_text("target")
        link = self.root / "source-link"
        link.symlink_to(target, target_is_directory=True)
        self.inputs["bundles"][0]["sourceDirectory"] = "source-link"
        (self.root / "dist/candidate-inputs.json").write_text(json.dumps(self.inputs))
        with self.assertRaises((tool.CandidateError, tool.AuditError)):
            tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        self.assertFalse((self.root / "dist/client/briani-player-linux-x64.tar.gz").exists())

    def test_repository_root_symlink_is_rejected(self):
        alias = self.root.parent / (self.root.name + "-alias")
        alias.symlink_to(self.root, target_is_directory=True)
        try:
            with self.assertRaises(tool.CandidateError):
                tool.assemble(alias, pathlib.Path("dist/candidate-inputs.json"))
        finally:
            alias.unlink()

    def test_source_identity_includes_normalized_executable_mode(self):
        before = tool.source_tree_sha256(self.root)
        path = self.root / "src/main.txt"
        path.chmod(0o755)
        self.assertNotEqual(before, tool.source_tree_sha256(self.root))

    def test_changed_source_rerun_replaces_only_owned_outputs_and_refreshes_checksums(self):
        first = tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        old_source_hash = first["sourceTreeSha256"]
        (self.root / "src/main.txt").write_text("source changed\n")
        second = tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        self.assertNotEqual(old_source_hash, second["sourceTreeSha256"])
        lines = (self.root / "dist/SHA256SUMS").read_text().splitlines()
        entries = {line.split("  ", 1)[1]: line.split("  ", 1)[0] for line in lines[1:]}
        self.assertEqual(entries["dist/sources/briani-player-source.tar.gz"], digest(
            self.root / "dist/sources/briani-player-source.tar.gz"))
        self.assertEqual(entries["dist/manifest.json"], digest(self.root / "dist/manifest.json"))
        self.assertEqual(entries["dist/provenance.json"], digest(self.root / "dist/provenance.json"))

    def test_checksum_ownership_accepts_safe_paths_with_spaces(self):
        tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        self.assertTrue(tool._checksum_index_owned(self.root))
        sums = (self.root / "dist/SHA256SUMS").read_text()
        self.assertIn("dist/licenses/pub/characters-1.4.1/third_party/Wikipedia/License CC BY-SA 3.0.txt", sums)

    def test_invalid_checksum_ownership_fails_before_any_output_changes(self):
        tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        checksum = self.root / "dist/SHA256SUMS"
        checksum.write_text("unrecognized index\n")
        before = {path.relative_to(self.root).as_posix(): path.read_bytes()
                  for path in (self.root / "dist").rglob("*") if path.is_file()}
        with self.assertRaises(tool.CandidateError):
            tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))
        after = {path.relative_to(self.root).as_posix(): path.read_bytes()
                 for path in (self.root / "dist").rglob("*") if path.is_file()}
        self.assertEqual(before, after)

    def test_descriptor_evidence_hash_mismatch_is_rejected(self):
        self.inputs["artifacts"][0]["buildEvidence"]["sha256"] = "0" * 64
        (self.root / "dist/candidate-inputs.json").write_text(json.dumps(self.inputs))
        with self.assertRaises(tool.CandidateError):
            tool.assemble(self.root, pathlib.Path("dist/candidate-inputs.json"))

    def test_absolute_and_parent_paths_are_rejected(self):
        with self.assertRaises(tool.CandidateError):
            tool.relative_path("../outside", "test")
        with self.assertRaises(tool.CandidateError):
            tool.relative_path("/etc/passwd", "test")


if __name__ == "__main__":
    unittest.main()
