import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("collector", ROOT / "tools/benchmarks/collect.py")
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


class FakeRunner:
    def __init__(self, output): self.output = output; self.calls = []
    def __call__(self, cmd, **kwargs):
        self.calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, self.output(cmd), "")


class CollectorTests(unittest.TestCase):
    def test_explicit_ids_and_fixture_labels_required(self):
        def output(cmd):
            ids = cmd[2:]
            return json.dumps([{"Id": x, "Name": "/"+s, "State": {"Status": "running"},
                "Config": {"Labels": {"com.docker.compose.project": "bench", "com.docker.compose.service": s,
                                          "org.brianiplayer.fixture": "true"}}}
                for x, s in zip(ids, ("briani", "qbittorrent", "prowlarr"))])
        runner = FakeRunner(output)
        services = collector.verify_containers("bench", ["a"*64, "b"*64, "c"*64], runner)
        self.assertEqual(set(services.values()), {"briani", "qbittorrent", "prowlarr"})
        self.assertEqual(runner.calls[0][:2], ["docker", "inspect"])
        with self.assertRaises(collector.CollectionError):
            collector.verify_containers("bench", ["not-an-id"], runner)

    def test_bad_project_and_missing_fixture_marker_fail_closed(self):
        with self.assertRaises(collector.CollectionError): collector.verify_containers("../prod", ["a"*64])
        runner = FakeRunner(lambda cmd: json.dumps([{"Id":"a"*64, "Name":"/x", "State":{"Status":"running"},
            "Config":{"Labels":{"com.docker.compose.project":"bench", "com.docker.compose.service":"briani"}}}]))
        with self.assertRaisesRegex(collector.CollectionError, "fixture Compose labels"):
            collector.verify_containers("bench", ["a"*64], runner)

    def test_p95_nearest_rank_and_empty_error(self):
        self.assertEqual(collector.percentile95([1, 2, 3, 4, 5]), 5)
        with self.assertRaises(collector.CollectionError): collector.percentile95([])

    def test_credential_file_requires_private_mode(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "credentials.json"
            path.write_text('{"bearer":"secret"}')
            path.chmod(0o644)
            with self.assertRaisesRegex(collector.CollectionError, "mode 0600"):
                collector.load_credentials(path)
            path.chmod(0o600)
            self.assertEqual(collector.load_credentials(path), {"bearer":"secret"})

    def test_stats_parses_memory_and_rejects_missing_container(self):
        runner = FakeRunner(lambda cmd: json.dumps({"Name":"svc", "CPUPerc":"4.2%", "MemUsage":"12.5MiB / 1GiB"}))
        stats = collector._stats(["a"*64], runner)
        self.assertEqual(stats["svc"]["memoryBytes"], 12.5 * 1024**2)
        runner = FakeRunner(lambda cmd: "")
        with self.assertRaisesRegex(collector.CollectionError, "all explicit"):
            collector._stats(["a"*64], runner)

    def test_process_rss_and_docker_memory_limit_support_are_reported_separately(self):
        calls = []
        def output(cmd):
            calls.append(cmd)
            if cmd[1] == "top": return "123 100\n124 200\n"
            return json.dumps({"MemoryLimit": False})
        runner = FakeRunner(output)
        cid = "a" * 64
        self.assertEqual(collector._process_rss([cid], runner), {cid[:12]: 300 * 1024})
        self.assertEqual(collector._memory_limit_support(runner), False)
        self.assertEqual(calls[0], ["docker", "top", cid, "-eo", "pid=,rss="])
        self.assertEqual(calls[1][:2], ["docker", "info"])

    def test_window_is_bounded_and_fixture_requires_expected_digest(self):
        class Args:
            duration = 1801
        # Invalid duration is detected before Docker is called.
        with self.assertRaisesRegex(collector.CollectionError, "1800 seconds"):
            collector.collect(Args())


if __name__ == "__main__": unittest.main()
