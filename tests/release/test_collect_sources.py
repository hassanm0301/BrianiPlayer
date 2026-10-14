from __future__ import annotations

import hashlib
import importlib.util
import io
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("collect_sources", ROOT / "tools/release/collect_sources.py")
collector = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(collector)


class FakeResponse:
    def __init__(self, data: bytes, url: str = "https://ffmpeg.org/test"):
        self.data = io.BytesIO(data)
        self.url = url
        self.headers = {"Content-Length": str(len(data))}

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return None

    def geturl(self):
        return self.url

    def read(self, count: int = -1):
        return self.data.read(count)


class CollectSourcesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def item(self, **overrides):
        value = {"id": "fixture", "url": "https://ffmpeg.org/test", "path": "sources/test.tar",
                 "kind": "source-archive", "expectedSha256": None, "identity": "test"}
        value.update(overrides)
        return value

    def test_collects_hashes_and_writes_only_under_root(self):
        payload = b"primary source archive fixture"
        result = collector.download_one(self.root, self.item(), max_bytes=1024,
                                        opener=lambda _: FakeResponse(payload))
        self.assertEqual(result["status"], "collected")
        self.assertEqual(result["sha256"], hashlib.sha256(payload).hexdigest())
        self.assertEqual((self.root / "sources/test.tar").read_bytes(), payload)

    def test_checks_expected_digest(self):
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            collector.download_one(self.root, self.item(expectedSha256="0" * 64), max_bytes=1024,
                                   opener=lambda _: FakeResponse(b"bytes"))
        self.assertFalse((self.root / "sources/test.tar").exists())

    def test_rejects_unsafe_paths_and_symlink_directories(self):
        with self.assertRaisesRegex(ValueError, "unsafe destination"):
            collector.safe_destination(self.root, "../outside")
        outside = pathlib.Path(self.tmp.name).parent / (pathlib.Path(self.tmp.name).name + "-outside")
        outside.mkdir()
        try:
            (self.root / "sources").symlink_to(outside, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "symlink destination refused"):
                collector.safe_destination(self.root, "sources/payload.tar")
        finally:
            (self.root / "sources").unlink()
            outside.rmdir()

    def test_rejects_unapproved_hosts_and_redirects(self):
        with self.assertRaisesRegex(ValueError, "outside HTTPS allowlist"):
            collector.download_one(self.root, self.item(url="https://attacker.invalid/a"), max_bytes=100,
                                    opener=lambda _: FakeResponse(b"x"))
        with self.assertRaisesRegex(ValueError, "redirect left HTTPS source host allowlist"):
            collector.download_one(self.root, self.item(), max_bytes=100,
                                   opener=lambda _: FakeResponse(b"x", "https://attacker.invalid/a"))

    def test_enforces_byte_limit_before_and_during_transfer(self):
        with self.assertRaisesRegex(ValueError, "per-file byte limit"):
            collector.download_one(self.root, self.item(), max_bytes=3,
                                   opener=lambda _: FakeResponse(b"too large"))
        self.assertFalse((self.root / "sources/test.tar").exists())
        response = FakeResponse(b"123456789")
        response.headers = {}
        with self.assertRaisesRegex(ValueError, "byte limit"):
            collector.download_one(self.root, self.item(), max_bytes=3, opener=lambda _: response)

    def test_total_budget_counts_partial_failed_downloads(self):
        response = FakeResponse(b"123456789")
        response.headers = {}
        budget = collector.ByteBudget(4)
        with self.assertRaisesRegex(ValueError, "byte limit before end"):
            collector.download_one(self.root, self.item(), max_bytes=20, budget=budget,
                                   opener=lambda _: response)
        self.assertEqual(budget.used, 4)

    def test_existing_different_file_is_never_overwritten(self):
        destination = self.root / "sources/test.tar"
        destination.parent.mkdir()
        destination.write_bytes(b"original")
        with self.assertRaisesRegex(ValueError, "refusing to replace existing destination"):
            collector.download_one(self.root, self.item(), max_bytes=1024,
                                   opener=lambda _: FakeResponse(b"replacement"))
        self.assertEqual(destination.read_bytes(), b"original")


if __name__ == "__main__":
    unittest.main()
