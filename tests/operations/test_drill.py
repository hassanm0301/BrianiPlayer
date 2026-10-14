from __future__ import annotations

import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("briani_m09_drill", ROOT / "tools/operations/drill.py")
drill = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(drill)


class DrillSafetyTests(unittest.TestCase):
    def test_project_names_are_stable_and_distinct_for_restore_roots(self):
        self.assertEqual(drill.compose_project_name(pathlib.Path("/tmp/source")),
                         drill.compose_project_name(pathlib.Path("/tmp/source")))
        self.assertNotEqual(drill.compose_project_name(pathlib.Path("/tmp/source")),
                            drill.compose_project_name(pathlib.Path("/tmp/restore")))

    def test_qbittorrent_limit_readback_uses_whole_kib_steps(self):
        self.assertEqual(drill.qbit_limit_readback(12345), 12288)
        self.assertEqual(drill.qbit_limit_readback(23456), 22528)

    def test_preflight_refuses_a_busy_loopback_port_before_any_drill_mutation(self):
        class OccupiedSocket:
            def bind(self, _address):
                raise OSError("occupied")
            def close(self):
                pass
        with patch.object(drill.socket, "socket", return_value=OccupiedSocket()):
            with self.assertRaisesRegex(drill.DrillError, "already occupied"):
                drill.check_ports_available((8088,))

    def test_container_cleanup_ownership_requires_exact_label_and_only_drill_mounts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            own = {"Config": {"Labels": {"com.docker.compose.project": "project-a"}},
                   "Mounts": [{"Source": str(root / "state")}]}
            other_project = {"Config": {"Labels": {"com.docker.compose.project": "project-b"}},
                             "Mounts": [{"Source": str(root / "state")}]}
            outside_mount = {"Config": {"Labels": {"com.docker.compose.project": "project-a"}},
                             "Mounts": [{"Source": "/srv/media"}]}
            self.assertTrue(drill.is_owned_container(own, "project-a", root))
            self.assertFalse(drill.is_owned_container(other_project, "project-a", root))
            self.assertFalse(drill.is_owned_container(outside_mount, "project-a", root))

    def test_http_error_body_never_appears_in_safe_drill_error(self):
        with patch.object(drill.urllib.request, "urlopen",
                          side_effect=drill.urllib.error.HTTPError("http://local", 500, "error", {}, None)):
            api = drill.HttpApi("http://127.0.0.1")
            with self.assertRaises(drill.DrillError) as raised:
                api.request("GET", "/private", expected=(200,), label="safe probe")
        # The mocked HTTPError's body is intentionally unread and must not enter diagnostics.
        if hasattr(raised.exception, "close"):
            raised.exception.close()
        self.assertNotIn("secret", str(raised.exception).lower())

    def test_prowlarr_diagnostic_reports_only_status_and_header_names(self):
        headers = {"X-Api-Key": "sensitive-value", "Server": "Prowlarr"}
        error = drill.urllib.error.HTTPError("http://local", 401, "error", headers, None)
        with patch.object(drill.urllib.request, "urlopen", side_effect=error):
            worker = drill.IntegratedDrill(pathlib.Path("/tmp/unused"), retain_on_failure=True)
            with self.assertRaises(drill.DrillError) as raised:
                worker.raw_p_get("/api/v1/system/status", "another-secret")
        self.assertIn("HTTP 401", str(raised.exception))
        self.assertIn("Server,X-Api-Key", str(raised.exception))
        self.assertNotIn("sensitive-value", str(raised.exception))
        self.assertNotIn("another-secret", str(raised.exception))

    def test_prowlarr_readiness_retries_transient_startup_but_not_auth_failure(self):
        worker = drill.IntegratedDrill(pathlib.Path("/tmp/unused"))
        with patch.object(worker, "raw_p_get", side_effect=[
                drill.ProwlarrTransientError("connection reset"), {"version": "2.6.5"}]), \
                patch.object(drill.time, "sleep"):
            status = worker.wait_p_api_ready("private", timeout=1, interval=0)
        self.assertEqual(status["version"], "2.6.5")

        with patch.object(worker, "raw_p_get", side_effect=drill.DrillError("HTTP 401")) as probe:
            with self.assertRaisesRegex(drill.DrillError, "401"):
                worker.wait_p_api_ready("private", timeout=1)
        probe.assert_called_once()


if __name__ == "__main__":
    unittest.main()
