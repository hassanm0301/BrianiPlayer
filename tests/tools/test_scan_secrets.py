import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "tools/security/scan_secrets.py"
SPEC = importlib.util.spec_from_file_location("scan_secrets", SCRIPT)
scanner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scanner)


class SecretScannerTests(unittest.TestCase):
    def test_private_key_detected(self):
        self.assertEqual(scanner.scan_text("-----BEGIN RSA PRIVATE KEY-----"), [("private-key", 1)])

    def test_provider_tokens_detected(self):
        self.assertEqual(scanner.scan_text("key=AKIA1234567890ABCDEF"), [("aws-access-key", 1)])

    def test_long_credential_assignment_detected(self):
        self.assertEqual(scanner.scan_text('client_secret = "abcdefghijklmnop"'), [("credential-assignment", 1)])

    def test_placeholders_are_not_reported(self):
        self.assertEqual(scanner.scan_text('password="change-me"'), [])
        self.assertEqual(scanner.scan_text('secret="isolated-test-credential"'), [])
        self.assertEqual(scanner.scan_text('password="isolated-real-credential"'), [("credential-assignment", 1)])

    def test_tree_reports_relative_source_line(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "config.env").write_text("ACCESS_TOKEN=abcdefghijklmnop\n", encoding="utf-8")
            found = scanner.scan_tree(root)
            self.assertEqual([(p.name, rule, line) for p, rule, line in found],
                             [("config.env", "credential-assignment", 1)])


if __name__ == "__main__":
    unittest.main()
