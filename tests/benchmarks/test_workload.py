import importlib.util
import json
import os
import tempfile
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("workload", ROOT / "tools/benchmarks/workload.py")
workload = importlib.util.module_from_spec(spec)
spec.loader.exec_module(workload)


BODY = b"fixture-bytes-for-range-oracle"


class FakeResponse:
    def __init__(self, status, body, headers): self.status=status; self.body=body; self.headers=headers; self.closed=False
    def read(self, size=-1):
        if size < 0: size=len(self.body)
        part, self.body = self.body[:size], self.body[size:]
        return part
    def close(self): self.closed=True


class FakeOpener:
    def __init__(self, payload=BODY, error=None): self.payload=payload; self.error=error; self.calls=[]
    def open(self, req, timeout=15):
        self.calls.append((req.full_url, dict(req.header_items())))
        if self.error: raise self.error
        range_value = req.get_header("Range")
        if range_value:
            start, end = map(int, range_value.removeprefix("bytes=").split("-"))
            data = self.payload[start:end+1]
            return FakeResponse(206, data, {"Content-Range":f"bytes {start}-{end}/{len(self.payload)}"})
        return FakeResponse(200, b"{}", {})


class JsonOpener:
    def __init__(self, payload, status=200): self.payload=payload; self.status=status; self.calls=[]
    def open(self, req, timeout=15):
        self.calls.append(req)
        return FakeResponse(self.status, json.dumps(self.payload).encode(), {"Content-Type":"application/json"})


class WorkloadTests(unittest.TestCase):
    def setUp(self): self.origin="http://127.0.0.1:8088"

    def config(self, completed=None, progressive=None, folder_users=None):
        origin = self.origin
        def stream_item(index):
            return {"url":"/stream/" + chr(65+index)*43 + "/a.mp4", "bearer":f"stream-token-{index}", "refreshToken":f"refresh-stream-{index}",
                "playbackSessionId":f"00000000-0000-4000-8000-{index+1:012d}", "generation":f"generation-{index}", "bytes":len(BODY),
                "sha256":__import__("hashlib").sha256(BODY).hexdigest()}
        return {"baseUrl":origin,
            "folderUsers":folder_users if folder_users is not None else [
                {"name":f"u{i}","bearer":f"token-{i}","refreshToken":f"refresh-{i}","url":"/api/v1/libraries/lib/entries"} for i in range(5)],
            "completedStreams":completed if completed is not None else [stream_item(0), stream_item(1)],
            "progressiveStream":progressive if progressive is not None else dict(stream_item(2),
                downloadStatusUrl="/api/v1/downloads/job", downloadRatePointer="/downloadSpeed",
                minimumDownloadBytesPerSecond=1)}

    def test_config_requires_progressive_inputs_and_distinct_users(self):
        config = self.config(); del config["progressiveStream"]
        with self.assertRaisesRegex(workload.WorkloadError, "progressive fixture input missing"):
            workload.validate_config(config)
        config = self.config(); config["folderUsers"][1]["bearer"] = config["folderUsers"][0]["bearer"]
        with self.assertRaisesRegex(workload.WorkloadError, "five distinct"):
            workload.validate_config(config)

    def test_stream_lease_and_all_distinct_refresh_inputs_are_mandatory(self):
        config = self.config(); del config["progressiveStream"]["generation"]
        with self.assertRaisesRegex(workload.WorkloadError, "generation"):
            workload.validate_config(config)
        config = self.config(); config["folderUsers"][0]["refreshToken"] = config["folderUsers"][1]["refreshToken"]
        with self.assertRaisesRegex(workload.WorkloadError, "distinct rotating refresh token"):
            workload.validate_config(config)

    def test_config_rejects_cross_origin_url_and_oversized_rate(self):
        config = self.config(); config["completedStreams"][0]["url"] = "http://127.0.0.1:9/api/v1/media/a"
        with self.assertRaisesRegex(workload.WorkloadError, "exact configured API origin"):
            workload.validate_config(config)
        config = self.config(); config["progressiveStream"]["targetMbitPerSecond"] = 101
        with self.assertRaisesRegex(workload.WorkloadError, r"in \(0,100\]"):
            workload.validate_config(config)

    def test_stream_urls_are_exact_capability_paths(self):
        for value in ("/api/v1/media/a", "/stream/short/a.mp4", "/stream/"+"A"*43+"/a%2fb.mp4",
                      "http://127.0.0.1:9/stream/"+"A"*43+"/a.mp4"):
            config = self.config(); config["completedStreams"][0]["url"] = value
            with self.subTest(value=value), self.assertRaises(workload.WorkloadError): workload.validate_config(config)

    def test_folder_list_query_allows_only_uuid_folder_and_bounded_limit(self):
        good = self.config()
        for item in good["folderUsers"]:
            item["url"] = "/api/v1/libraries/00000000-0000-4000-8000-000000000010/entries?folderId=00000000-0000-4000-8000-000000000011&limit=200"
        workload.validate_config(good)
        for query in ("folderId=bad&limit=200", "folderId=00000000-0000-4000-8000-000000000011&limit=201",
                      "folderId=00000000-0000-4000-8000-000000000011&limit=20&admin=true"):
            config = self.config()
            config["folderUsers"][0]["url"] = "/api/v1/libraries/00000000-0000-4000-8000-000000000010/entries?"+query
            with self.subTest(query=query), self.assertRaises(workload.WorkloadError): workload.validate_config(config)

    def test_session_status_checks_generation_without_rotating_ticket_or_posting(self):
        config = workload.validate_config(self.config())
        stream = config["completedStreams"][0]
        response = {"id":stream["playbackSessionId"], "state":"complete", "generation":stream["generation"], "streamUrl":None}
        opener = JsonOpener(response)
        load = workload.Load(self.config(), 1, opener=opener)
        original = stream["url"]
        load._check_stream_session(load.config["completedStreams"][0])
        self.assertEqual(load.config["completedStreams"][0]["url"], original)
        self.assertEqual(opener.calls[0].get_method(), "GET")
        self.assertTrue(opener.calls[0].full_url.endswith("/api/v1/playback/sessions/"+stream["playbackSessionId"]))
        self.assertEqual(load.session_status_counts[stream["playbackSessionId"]], 1)
        load.close()

    def test_session_status_fails_closed_on_generation_or_ticket_change(self):
        config = workload.validate_config(self.config())
        stream = config["completedStreams"][0]
        for change in ({"generation":"other-generation"}, {"streamUrl":"/stream/"+"Z"*43+"/a.mp4"}, {"state":"revoked"}):
            response = {"id":stream["playbackSessionId"], "state":"ready", "generation":stream["generation"], "streamUrl":None}
            response.update(change)
            load = workload.Load(self.config(), 1, opener=JsonOpener(response))
            with self.subTest(change=change), self.assertRaises(workload.WorkloadError): load._check_stream_session(load.config["completedStreams"][0])
            load.close()

    def test_refresh_rotation_updates_only_owning_item(self):
        payload = {"accessToken":"new-access", "refreshToken":"new-refresh"}
        opener = JsonOpener(payload)
        load = workload.Load(self.config(), 1, opener=opener)
        users = load.config["folderUsers"]
        before = users[1]["headers"]["Authorization"]
        owner = users[0]
        load._refresh_owner(owner)
        self.assertEqual(owner["headers"]["Authorization"], "Bearer new-access")
        self.assertEqual(owner["refreshToken"], "new-refresh")
        self.assertEqual(users[1]["headers"]["Authorization"], before)
        self.assertEqual(opener.calls[0].get_method(), "POST")
        self.assertTrue(opener.calls[0].full_url.endswith("/api/v1/auth/refresh"))
        self.assertEqual(json.loads(opener.calls[0].data), {"refreshToken":"refresh-0"})
        load.close()

    def test_fixture_config_must_be_private_nonsymlink(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/"fixture.json"; path.write_text("{}")
            path.chmod(0o644)
            with self.assertRaisesRegex(workload.WorkloadError, "mode 0600"):
                workload.load_config(path)
            path.chmod(0o600)
            link = Path(temp)/"link.json"; link.symlink_to(path)
            with self.assertRaisesRegex(workload.WorkloadError, "not a symlink"):
                workload.load_config(link)

    def test_stream_checks_range_bytes_and_independent_sha256(self):
        config = workload.validate_config(self.config())
        item = config["completedStreams"][0]
        opener = FakeOpener()
        load = workload.Load(self.config(), 2, opener=opener)
        load.started = load.clock(); load.deadline = load.started + .12
        load._paced_stream("fixture", item)
        self.assertGreater(load.stream_results["fixture"]["verifiedCompleteCycles"], 0)
        self.assertTrue(load.stream_results["fixture"]["oraclePass"])
        self.assertTrue(opener.calls)
        load.close()

    def test_oracle_mismatch_is_recorded_as_failure(self):
        config = workload.validate_config(self.config())
        altered = b"X" + BODY[1:]
        load = workload.Load(self.config(), 1, opener=FakeOpener(payload=altered))
        load.started = load.clock(); load.deadline = load.started + .25
        load._paced_stream("fixture", config["completedStreams"][0])
        self.assertFalse(load.stream_results["fixture"]["oraclePass"])
        self.assertIn("SHA-256 mismatch", load.errors[0])
        load.close()

    def test_partial_progressive_ranges_match_local_oracle_before_full_cycle(self):
        import hashlib
        payload = bytes((i % 251 for i in range(1024 * 1024)))
        with tempfile.TemporaryDirectory() as temp:
            oracle_path = Path(temp)/"large-fixture.bin"
            oracle_path.write_bytes(payload)
            oracle_path.chmod(0o600)
            item = {"url":"/stream/" + "B"*43 + "/large.mp4", "bearer":"progressive-token", "refreshToken":"refresh-progressive",
                    "playbackSessionId":"00000000-0000-4000-8000-000000000003", "generation":"generation-2", "bytes":len(payload),
                    "sha256":hashlib.sha256(payload).hexdigest(), "targetMbitPerSecond":1,
                    "oracleFile":str(oracle_path), "downloadStatusUrl":"/api/v1/downloads/job",
                    "downloadRatePointer":"/downloadSpeed", "minimumDownloadBytesPerSecond":1}
            config = self.config(progressive=item)
            opener = FakeOpener(payload=payload)
            load = workload.Load(config, 1, opener=opener)
            progressive = load.config["progressiveStream"]
            load.started = load.clock(); load.deadline = load.started + .05
            load._paced_stream("progressive", progressive)
            result = load.stream_results["progressive"]
            self.assertEqual(result["verifiedCompleteCycles"], 0)
            self.assertGreater(result["verifiedRanges"], 0)
            self.assertGreaterEqual(result["oracleVerifiedBytes"], workload.CHUNK_BYTES)
            self.assertLess(result["oracleVerifiedBytes"], len(payload))
            self.assertTrue(result["independentRangeOracle"])
            self.assertTrue(result["oraclePass"], result)
            load.close()

    def test_oracle_hash_size_symlink_and_replaced_path_fail_closed(self):
        import hashlib
        payload = b"trusted-local-fixture"
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/"fixture.bin"; path.write_bytes(payload); path.chmod(0o600)
            with self.assertRaisesRegex(workload.WorkloadError, "size does not match"):
                workload.OracleFixture(str(path), len(payload)+1, hashlib.sha256(payload).hexdigest())
            with self.assertRaisesRegex(workload.WorkloadError, "SHA-256 does not match"):
                workload.OracleFixture(str(path), len(payload), "0"*64)
            oracle = workload.OracleFixture(str(path), len(payload), hashlib.sha256(payload).hexdigest())
            owned_fd = oracle.fd
            path.unlink()
            path.symlink_to(Path(temp)/"other.bin")
            with self.assertRaisesRegex(workload.WorkloadError, "identity or content metadata changed"):
                oracle.read(0, 2)
            oracle.close()
            with self.assertRaises(OSError): os.fstat(owned_fd)

    def test_corrupt_partial_range_fails_immediately_against_local_oracle(self):
        import hashlib
        payload = bytes((i % 251 for i in range(1024 * 1024)))
        altered = b"X" + payload[1:]
        with tempfile.TemporaryDirectory() as temp:
            oracle_path = Path(temp)/"large-fixture.bin"
            oracle_path.write_bytes(payload); oracle_path.chmod(0o600)
            item = {"url":"/stream/" + "B"*43 + "/large.mp4", "bearer":"progressive-token", "refreshToken":"refresh-progressive",
                    "playbackSessionId":"00000000-0000-4000-8000-000000000003", "generation":"generation-2", "bytes":len(payload),
                    "sha256":hashlib.sha256(payload).hexdigest(), "targetMbitPerSecond":1,
                    "oracleFile":str(oracle_path), "downloadStatusUrl":"/api/v1/downloads/job",
                    "downloadRatePointer":"/downloadSpeed", "minimumDownloadBytesPerSecond":1}
            config = self.config(progressive=item)
            load = workload.Load(config, 1, opener=FakeOpener(payload=altered))
            progressive = load.config["progressiveStream"]
            load.started = load.clock(); load.deadline = load.started + .1
            load._paced_stream("progressive", progressive)
            result = load.stream_results["progressive"]
            self.assertEqual(result["verifiedRanges"], 0)
            self.assertEqual(result["oracleVerifiedBytes"], 0)
            self.assertFalse(result["oraclePass"])
            self.assertIn("byte oracle mismatch at offset 0", result["errors"][0])
            load.close()

    def test_redirect_is_rejected_and_factory_does_not_follow(self):
        import urllib.error
        response = object()
        import io
        error = urllib.error.HTTPError(self.origin + "/api/v1/redirect", 302, "redirect", {}, io.BytesIO())
        error.close()
        opener = FakeOpener(error=error)
        load = workload.Load(self.config(), 1, opener=opener)
        with self.assertRaisesRegex(workload.WorkloadError, "redirect rejected") as caught:
            load._open(self.origin + "/api/v1/redirect?ticket=secret", {"Authorization":"Bearer secret"})
        self.assertNotIn("secret", str(caught.exception))
        self.assertEqual(len(opener.calls), 1)
        self.assertIsNone(workload.NoRedirect().redirect_request(None, None, 302, "redirect", {}, "http://other.invalid/api/v1/x"))

    def test_cancel_closes_only_registered_owned_responses(self):
        load = workload.Load(self.config(), 1)
        response = FakeResponse(200, b"", {})
        load._register(response)
        load.cancel("configured low-memory trip")
        self.assertTrue(load.stop_event.is_set())
        self.assertTrue(response.closed)
        self.assertEqual(load.stop_reason, "configured low-memory trip")

    def test_five_user_latency_p95_calculation(self):
        self.assertEqual(workload.percentile95([10, 20, 30, 40, 50]), 50)
        self.assertIsNone(workload.percentile95([]))

    def test_duration_window_is_bounded(self):
        with self.assertRaisesRegex(workload.WorkloadError, "1..1800"):
            workload.Load(self.config(), 1801)


if __name__ == "__main__": unittest.main()
