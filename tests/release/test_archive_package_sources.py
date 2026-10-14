from __future__ import annotations

import hashlib
import io
from unittest import mock
import pathlib
import tarfile
import tempfile
import unittest

from tools.release import archive_package_sources as tool


class PackageSourceArchiveTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.source = self.root / "source"
        (self.source / "lib").mkdir(parents=True)
        (self.source / "lib/main.dart").write_text("void main() {}\n")
        (self.source / "LICENSE").write_text("License notice\n")
        (self.source / "build").mkdir()
        (self.source / "build/generated.dart").write_text("generated\n")
        (self.source / ".cxx/Debug/arm64").mkdir(parents=True)
        (self.source / ".cxx/Debug/arm64/fingerprint.bin").write_bytes(b"generated cache")
        (self.source / ".git/config").parent.mkdir(parents=True)
        (self.source / ".git/config").write_text("repository metadata\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_archive_is_deterministic_and_excludes_build_and_git(self):
        first = self.root / "one.tar.gz"
        second = self.root / "two.tar.gz"
        a = tool.archive_tree(self.source, first, "sample-1.0.0")
        b = tool.archive_tree(self.source, second, "sample-1.0.0")
        self.assertEqual(a["archiveSha256"], b["archiveSha256"])
        self.assertEqual(first.read_bytes(), second.read_bytes())
        with tarfile.open(first, "r:gz") as archive:
            members = archive.getmembers()
            names = {member.name for member in members}
            self.assertEqual(names, {"sample-1.0.0", "sample-1.0.0/LICENSE", "sample-1.0.0/lib/main.dart"})
            self.assertTrue(all(member.mtime == 0 and member.uid == 0 and member.gid == 0 for member in members))
        self.assertEqual(a["sourceTreeSha256"], tool.collect_files(self.source)[1])
        self.assertEqual(a["archiveSha256"], hashlib.sha256(first.read_bytes()).hexdigest())

    def test_symlinks_are_rejected_even_under_excluded_directories(self):
        (self.source / "linked").symlink_to(self.source / "lib", target_is_directory=True)
        with self.assertRaises(tool.ArchiveError):
            tool.collect_files(self.source)

    def test_source_byte_bound_is_enforced(self):
        original = tool.MAX_PACKAGE_BYTES
        try:
            tool.MAX_PACKAGE_BYTES = 2
            with self.assertRaises(tool.ArchiveError):
                tool.collect_files(self.source)
        finally:
            tool.MAX_PACKAGE_BYTES = original

    def test_nuget_repository_pin_requires_exact_github_commit(self):
        metadata = self.root / "dist/licenses/metadata/nuget"
        metadata.mkdir(parents=True)
        commit = "a" * 40
        (metadata / "example-1.2.3.upstream.nuspec").write_text(
            f"<package><metadata><id>Example</id><version>1.2.3</version>"
            f"<repository type=\"git\" url=\"https://github.com/org/repo\" commit=\"{commit}\"/>"
            "</metadata></package>")
        pins = tool.collect_nuget_repository_pins(self.root)
        self.assertEqual(pins["repositoryCommitCount"], 1)
        self.assertEqual(pins["repositories"][0]["commit"], commit)
        self.assertIsNone(pins["repositories"][0]["sourceArchive"])
        (metadata / "bad-1.0.0.upstream.nuspec").write_text(
            "<package><metadata><id>Bad</id><version>1.0.0</version>"
            "<repository url=\"https://example.com/repo\" commit=\"" + commit + "\"/>"
            "</metadata></package>")
        self.assertEqual(tool.collect_nuget_repository_pins(self.root)["repositoryCommitCount"], 1)

    def test_codeload_fetch_is_commit_pinned_bounded_and_scans_archive_paths(self):
        tar_bytes = io.BytesIO()
        with tarfile.open(fileobj=tar_bytes, mode="w:gz") as archive:
            payload = b"source"
            info = tarfile.TarInfo("repo-deadbeef/src.txt")
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))
        compressed = tar_bytes.getvalue()

        class Response:
            status = 200
            headers = {}
            def __enter__(self): return self
            def __exit__(self, *_): return None
            def geturl(self): return "https://codeload.github.com/org/repo/tar.gz/" + "a" * 40
            def read(self, size): return self.stream.read(size)
            def __init__(self): self.stream = io.BytesIO(compressed)

        class Opener:
            def open(self, request, timeout):
                self.request = request
                self.timeout = timeout
                return Response()

        opener = Opener()
        dest = self.root / "dist/sources/packages/nuget-repositories/repo.tar.gz"
        dest.parent.mkdir(parents=True)
        with mock.patch.object(tool.urllib.request, "build_opener", return_value=opener):
            result = tool.fetch_github_source_archive("https://github.com/org/repo", "a" * 40, dest, 10000)
        self.assertEqual(result["sourceArchive"], "dist/sources/packages/nuget-repositories/repo.tar.gz")
        self.assertEqual(result["tarMemberCount"], 1)
        self.assertEqual(result["uncompressedBytes"], len(b"source"))
        with self.assertRaises(tool.ArchiveError):
            tool.fetch_github_source_archive("https://evil.example/org/repo", "a" * 40, dest, 10000)
        with self.assertRaises(tool.ArchiveError):
            tool.fetch_github_source_archive("https://github.com/org/repo", "short", dest, 10000)

    def test_pub_archive_fetch_matches_locked_hash_and_scans_without_extracting(self):
        tar_bytes = io.BytesIO()
        with tarfile.open(fileobj=tar_bytes, mode="w:gz") as archive:
            payload = b"licensed source"
            info = tarfile.TarInfo("lib/main.dart")
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))
        compressed = tar_bytes.getvalue()
        lock_hash = hashlib.sha256(compressed).hexdigest()
        url = "https://pub.dev/api/archives/sample-1.0.0.tar.gz"

        class Response:
            status = 200
            headers = {}
            def __enter__(self): return self
            def __exit__(self, *_): return None
            def geturl(self): return url
            def read(self, size): return self.stream.read(size)
            def __init__(self): self.stream = io.BytesIO(compressed)

        class Opener:
            def open(self, request, timeout):
                self.request = request
                self.timeout = timeout
                return Response()

        opener = Opener()
        dest = self.root / "dist/sources/packages/pub-hosted/sample-1.0.0.tar.gz"
        dest.parent.mkdir(parents=True)
        with mock.patch.object(tool.urllib.request, "build_opener", return_value=opener):
            result = tool.fetch_pub_source_archive("sample", "1.0.0", lock_hash, dest, 10000)
        self.assertEqual(result["archiveSha256"], lock_hash)
        self.assertEqual(result["sourceArchive"], "dist/sources/packages/pub-hosted/sample-1.0.0.tar.gz")
        self.assertEqual(result["archiveTreeFileCount"], 1)
        self.assertEqual(result["archiveFiles"], {"lib/main.dart": hashlib.sha256(b"licensed source").hexdigest()})
        with self.assertRaises(tool.ArchiveError):
            tool.fetch_pub_source_archive("sample", "1.0.0", "bad", dest, 10000)

    def test_github_tarball_rejects_unsafe_member_paths(self):
        target = self.root / "unsafe.tar.gz"
        with tarfile.open(target, mode="w:gz") as archive:
            info = tarfile.TarInfo("repo/../../outside")
            info.size = 0
            archive.addfile(info, io.BytesIO())
        with self.assertRaises(tool.ArchiveError):
            tool._validate_github_tarball(target)

    def test_different_existing_archive_is_not_overwritten(self):
        target = self.root / "target.tar.gz"
        target.write_bytes(b"preserve")
        with self.assertRaises(tool.ArchiveError):
            tool.archive_tree(self.source, target, "sample-1.0.0")
        self.assertEqual(target.read_bytes(), b"preserve")


if __name__ == "__main__":
    unittest.main()
