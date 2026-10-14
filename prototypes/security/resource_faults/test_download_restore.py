from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from prototypes.security.resource_faults.run_download_restore import (
    FIXTURE_BYTES, FIXTURE_NAME, make_generated_fixture, partial_file_progress, completed_file,
    seed_password_from_startup, validate_seed_record, QBIT_IMAGE, OWNER, SIMULATION_SUBNETS, life, drill,
    validate_pre_restore_fixture_endpoints,
)


class GeneratedRestoreFixtureTests(unittest.TestCase):
    def test_private_trackerless_metainfo_matches_generated_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / FIXTURE_NAME
            metainfo, payload, infohash = make_generated_fixture(path)
            decoded = life.bdecode(metainfo)
            info = decoded[b"info"]
            self.assertEqual(path.read_bytes(), payload)
            self.assertEqual(len(payload), FIXTURE_BYTES)
            self.assertEqual(info[b"length"], FIXTURE_BYTES)
            self.assertEqual(info[b"name"].decode(), FIXTURE_NAME)
            self.assertEqual(info[b"private"], 1)
            self.assertEqual(infohash, hashlib.sha1(life.bencode(info)).hexdigest())
            self.assertEqual(len(info[b"pieces"]), 20 * (FIXTURE_BYTES // info[b"piece length"]))
            self.assertEqual(set(decoded), {b"info"})
            self.assertEqual(hashlib.sha256(payload).hexdigest(), hashlib.sha256(path.read_bytes()).hexdigest())

    def test_download_poll_predicates_bind_the_response_list_and_require_exact_bounds(self):
        file_id = "generated-file"
        partial = [{"id": file_id, "downloadedBytes": 600_000}]
        self.assertIs(partial_file_progress(partial, file_id, 8 * 1024 * 1024), partial)
        self.assertIsNone(partial_file_progress({"items": partial}, file_id, 8 * 1024 * 1024))
        self.assertIsNone(partial_file_progress([{"id": file_id, "downloadedBytes": 8 * 1024 * 1024}], file_id, 8 * 1024 * 1024))
        self.assertIsNone(partial_file_progress([{"id": file_id, "downloadedBytes": 100}], file_id, 8 * 1024 * 1024))
        complete = [{"id": file_id, "downloadedBytes": 8 * 1024 * 1024}]
        self.assertIs(completed_file(complete, file_id, 8 * 1024 * 1024), complete)
        self.assertIsNone(completed_file(partial, file_id, 8 * 1024 * 1024))
        self.assertIsNone(completed_file([{"id": "other", "downloadedBytes": 8 * 1024 * 1024}], file_id, 8 * 1024 * 1024))

    def test_seed_password_is_unpacked_only_for_the_exact_owned_container(self):
        self.assertEqual(seed_password_from_startup(("container-full-id", "secret"), "container-full-id"), "secret")
        for bad in (None, ("other", "secret"), ("container-full-id", ""), ("container-full-id",)):
            with self.subTest(value=bad), self.assertRaises(drill.DrillError):
                seed_password_from_startup(bad, "container-full-id")

    def test_seed_ownership_accepts_image_labels_and_validates_id_image_and_mounts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config, data = root / "config", root / "data"
            config.mkdir()
            data.mkdir()
            record = {"Id": "owned-full-id", "Config": {
                "Image": QBIT_IMAGE,
                "Labels": {"org.briani.test": "M10-download-restore", "org.briani.owner": OWNER,
                    "org.briani.run": "run-1", "org.briani.kind": "fixture-seeder",
                    "org.opencontainers.image.version": "upstream-label"}},
                "Mounts": [{"Type": "bind", "Source": str(config), "Destination": "/config"},
                           {"Type": "bind", "Source": str(data), "Destination": "/data"}]}
            validate_seed_record(record, "owned-full-id", "run-1", config, data)
            for change in ("id", "image", "mount"):
                bad = {**record, "Config": {**record["Config"], "Labels": dict(record["Config"]["Labels"])},
                       "Mounts": [dict(item) for item in record["Mounts"]]}
                if change == "id":
                    bad["Id"] = "other-id"
                elif change == "image":
                    bad["Config"]["Image"] = "untrusted:image"
                else:
                    bad["Mounts"][0]["Source"] = str(root / "other")
                with self.subTest(change=change), self.assertRaises(drill.DrillError):
                    validate_seed_record(bad, "owned-full-id", "run-1", config, data)

    def test_public_simulation_ranges_are_global_and_outside_egress_denials(self):
        import ipaddress

        candidates = SIMULATION_SUBNETS
        denied = tuple(map(ipaddress.ip_network, ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
            "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24")))
        for value in candidates:
            network = ipaddress.ip_network(value)
            self.assertTrue(network.is_global)
            self.assertEqual(network.prefixlen, 29)
            self.assertFalse(any(network.overlaps(item) for item in denied))

    def test_restore_fixture_network_accepts_only_seed_and_optional_stopped_source_guard(self):
        self.assertFalse(validate_pre_restore_fixture_endpoints({"seed"}, "seed", "source-guard"))
        self.assertTrue(validate_pre_restore_fixture_endpoints({"seed", "source-guard"}, "seed", "source-guard"))
        for endpoints in ({"foreign"}, {"seed", "foreign"}, {"seed", "source-guard", "foreign"}, set()):
            with self.subTest(endpoints=endpoints), self.assertRaises(drill.DrillError):
                validate_pre_restore_fixture_endpoints(endpoints, "seed", "source-guard")


if __name__ == "__main__":
    unittest.main()
