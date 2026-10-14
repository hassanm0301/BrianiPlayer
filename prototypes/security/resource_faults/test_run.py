from __future__ import annotations

import importlib.util
import hashlib
from pathlib import Path
import tempfile
import unittest


RUNNER = Path(__file__).with_name("run.py")
spec = importlib.util.spec_from_file_location("resource_fault_runner", RUNNER)
assert spec and spec.loader
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
qbit_path = Path(__file__).with_name("run_qbittorrent_network_loss.py")
qbit_spec = importlib.util.spec_from_file_location("resource_fault_qbittorrent", qbit_path)
assert qbit_spec and qbit_spec.loader
qbit_runner = importlib.util.module_from_spec(qbit_spec)
qbit_spec.loader.exec_module(qbit_runner)


class OwnershipTests(unittest.TestCase):
    def test_docker_cleanup_requires_every_exact_ownership_label(self) -> None:
        expected = runner.run_id_for("prepare", "a" * 32)
        self.assertTrue(runner.labels_match(expected, expected))
        for key in expected:
            altered = dict(expected)
            altered[key] = "other-run"
            self.assertFalse(runner.labels_match(altered, expected), key)
        self.assertFalse(runner.labels_match({}, expected))

    def test_scratch_cleanup_requires_exact_marker_and_direct_child(self) -> None:
        with tempfile.TemporaryDirectory() as parent_name:
            parent = Path(parent_name)
            owned = parent / ("a" * 32)
            owned.mkdir()
            (owned / ".briani-owner").write_text("resource-faults:" + "a" * 32 + "\n")
            (owned / "fixture.bin").write_bytes(b"generated")
            self.assertFalse(runner.remove_owned_scratch(owned, parent, "resource-faults:" + "b" * 32))
            self.assertTrue((owned / "fixture.bin").is_file())
            self.assertFalse(runner.remove_owned_scratch(owned, parent / "nested", "resource-faults:" + "a" * 32))
            self.assertTrue((owned / "fixture.bin").is_file())
            self.assertTrue(runner.remove_owned_scratch(owned, parent, "resource-faults:" + "a" * 32))
            self.assertFalse(owned.exists())


class TorrentFixtureTests(unittest.TestCase):
    def test_recovery_deadline_covers_locked_libtorrent_reconnect_backoff(self) -> None:
        self.assertEqual(qbit_runner.RECOVERY_PROGRESS_TIMEOUT_SECONDS, 210)
        self.assertEqual(qbit_runner.RECOVERY_TIMEOUT_BASIS["libtorrentMinReconnectSeconds"], 60)
        self.assertFalse(qbit_runner.RECOVERY_TIMEOUT_BASIS["qBittorrentOverridesMinReconnect"])

    def test_v1_metainfo_hash_matches_encoded_info_dictionary(self) -> None:
        payload = bytes(range(251)) * 1100
        metainfo, infohash = qbit_runner.bencode_torrent(payload, b"fault.mp4", piece_size=4096)
        expected_info = {
            b"length": len(payload), b"name": b"fault.mp4", b"piece length": 4096,
            b"pieces": b"".join(hashlib.sha1(payload[i:i + 4096]).digest()
                                 for i in range(0, len(payload), 4096)), b"private": 1
        }
        self.assertEqual(infohash, hashlib.sha1(qbit_runner.encode(expected_info)).hexdigest())
        self.assertIn(qbit_runner.encode(expected_info), metainfo)


if __name__ == "__main__":
    unittest.main()
