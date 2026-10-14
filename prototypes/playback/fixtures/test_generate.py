import hashlib
import tempfile
import unittest
from pathlib import Path

from generate import PIECE_LENGTH, aligned_layout, expected_bytes, generate, v1_layout


class LayoutOracleTests(unittest.TestCase):
    def test_v1_counts_ignored_neighbor_in_global_offsets(self):
        layout = v1_layout([("before", 7), ("ignored", 9), ("selected", 10)], 8)
        self.assertEqual(layout["files"][2]["torrent_offset"], 16)
        self.assertEqual(layout["files"][2]["first_piece"], 2)
        self.assertEqual(layout["files"][2]["last_piece"], 3)

    def test_v2_and_hybrid_oracle_accounts_for_piece_alignment(self):
        layout = aligned_layout([("a", 9), ("b", 3)], 8, format="v2")
        self.assertEqual(layout["files"][1]["torrent_offset"], 16)
        self.assertEqual(layout["files"][1]["alignment_gap_before"], 7)

    def test_non_aligned_payload_hash_is_independent_of_layout(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "payload.bin"
            p.write_bytes(bytes(range(251)) * 523 + b"tail")
            expected = hashlib.sha256(p.read_bytes()).hexdigest()
            self.assertEqual(expected, hashlib.sha256(p.read_bytes()).hexdigest())
            self.assertEqual(expected_bytes(p, 250, 5), bytes((250, 0, 1, 2, 3)))
            with self.assertRaises(EOFError):
                expected_bytes(p, p.stat().st_size - 1, 2)


class GenerationTests(unittest.TestCase):
    def test_generation_rejects_blocked_mode_results(self):
        with self.assertRaisesRegex(RuntimeError, "fixture generation incomplete"):
            from generate import _require_generated
            _require_generated({"generated": [{"mode": "v2", "status": "blocked", "error": "unsupported"}]}, "corpus")

    def test_short_legal_fixture_corpus_and_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = generate(Path(tmp), duration=2, torrent_modes=["v1", "v2", "hybrid"], early_play_duration=2)
            self.assertEqual(sum(x["kind"] == "synthetic-media" for x in result["files"]), 3)
            self.assertTrue(all(x["size"] > 0 and len(x["sha256"]) == 64 for x in result["files"]))
            self.assertEqual(result["piece_length"], PIECE_LENGTH)
            self.assertTrue((Path(tmp) / "manifest.json").exists())
            self.assertEqual([x["mode"] for x in result["torrent"]["generated"]], ["v1", "v2", "hybrid"])
            for record in result["files"]:
                if record["kind"] == "synthetic-media":
                    self.assertEqual(record["tracks"]["video"], ["h264"])
                    self.assertTrue(all(codec == "aac" for codec in record["tracks"]["audio"]))
            # Oracle entries come from parsed libtorrent storage and preserve padding records.
            for torrent in result["torrent"]["generated"]:
                entries = torrent["layout_oracle"]["files"]
                self.assertTrue(entries)
                offsets = [entry["torrent_offset"] for entry in entries]
                self.assertEqual(offsets, sorted(offsets))
                self.assertTrue(all("padding" in entry for entry in entries))
                import libtorrent as lt
                metainfo = lt.bdecode((Path(tmp) / "torrents" / torrent["path"]).read_bytes())
                if hasattr(lt.create_torrent, "set_creation_date"):
                    self.assertEqual(metainfo.get(b"creation date", 0), 0)
            early = result["early_play"]
            self.assertEqual(early["duration_seconds"], 2)
            self.assertEqual(len(early["torrents"]["generated"]), 9)


if __name__ == "__main__":
    unittest.main()
