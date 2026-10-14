import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / "tools" / "dev.py"
spec = importlib.util.spec_from_file_location("briani_dev", MODULE)
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)


class RunnerTests(unittest.TestCase):
    def test_complete_status_cannot_bypass_blocked_artifact_audit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'plan/evidence').mkdir(parents=True)
            (root/'plan/evidence/status.json').write_text(json.dumps({'milestones':[{'id':f'M{i:02}','state':'complete'} for i in range(12)],'releaseStatus':'complete'}))
            runner=dev.Runner(root/'logs',lambda *_a,**_kw: SimpleNamespace(stdout='blocked native provenance',stderr='',returncode=3))
            with patch.object(dev,'ROOT',root):self.assertEqual(dev.release_verify(runner),3)
            self.assertIn('package_audit.py',runner.results[0]['argv'][1])
    def test_invokes_argument_array_and_records_exact_exit_and_streams(self):
        seen = {}

        def fake_run(argv, **kwargs):
            seen["argv"] = argv
            seen.update(kwargs)
            return SimpleNamespace(stdout="done\n", stderr="warning\n", returncode=7)

        with tempfile.TemporaryDirectory() as tmp:
            runner = dev.Runner(Path(tmp), fake_run)
            code = runner.run(["tool with space", "sub", "--flag", "a b"], name="sample", env={"X": "y"})
            self.assertEqual(code, 7)
            self.assertEqual(seen["argv"], ["tool with space", "sub", "--flag", "a b"])
            self.assertEqual(seen["env"], {"X": "y"})
            self.assertEqual((Path(tmp) / "sample.stdout.log").read_text(), "done\n")
            self.assertEqual((Path(tmp) / "sample.stderr.log").read_text(), "warning\n")
            self.assertEqual(runner.results[0]["exitCode"], 7)

    def test_missing_executable_is_nonzero_and_logged(self):
        def missing(*_args, **_kwargs):
            raise FileNotFoundError("missing")

        with tempfile.TemporaryDirectory() as tmp:
            runner = dev.Runner(Path(tmp), missing)
            self.assertEqual(runner.run(["does-not-exist"]), 127)
            self.assertIn("unavailable executable", (Path(tmp) / "01-does-not-exist.stderr.log").read_text())

    def test_empty_server_suites_fail_as_not_run(self):
        with patch.object(dev, "_suite_paths", return_value=[]):
            with tempfile.TemporaryDirectory() as tmp:
                runner = dev.Runner(Path(tmp))
                self.assertNotEqual(dev.test_suite(runner, "integration"), 0)
                self.assertEqual(runner.results[0]["status"], "not_run")
                self.assertIn("not_run", runner.results[0]["reason"])

    def test_passing_subprocess_status_is_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            runner = dev.Runner(Path(tmp), lambda *_a, **_kw: SimpleNamespace(stdout="", stderr="", returncode=0))
            self.assertEqual(runner.run(["ok"]), 0)
            final = runner.finish("example", 0)
            self.assertEqual(final, 0)
            report = json.loads((Path(tmp) / "run.json").read_text())
            self.assertEqual(report["commands"][0]["exitCode"], 0)


if __name__ == "__main__":
    unittest.main()
