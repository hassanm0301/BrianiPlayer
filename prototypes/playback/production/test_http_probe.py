import importlib.util
from pathlib import Path
import threading
import time
import unittest
from unittest.mock import patch
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

spec = importlib.util.spec_from_file_location("production_playback", Path(__file__).with_name("run_api_playback.py"))
proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proof)


class GapOracle(unittest.TestCase):
    def run_server(self, mode):
        hosts = []
        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            def log_message(self, *args): pass
            def do_GET(self):
                hosts.extend(self.headers.get_all("Host"))
                self.send_response(206)
                self.send_header("Content-Length", "4")
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(b"ab")
                self.wfile.flush()
                if mode == "wait": time.sleep(1)
                elif mode == "zeros": self.wfile.write(b"\0\0"); self.wfile.flush()
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            url = f"http://127.0.0.1:{server.server_port}/stream/generated/file.mp4"
            if mode == "wait":
                result = proof.raw_range_until_gap(url, 0, 3, 2)
                self.assertTrue(result["waited"])
                self.assertEqual(2, result["bytesBeforeGap"])
            else:
                with self.assertRaises(RuntimeError): proof.raw_range_until_gap(url, 0, 3, 2)
            self.assertEqual(["briani"], hosts)
        finally:
            server.shutdown(); server.server_close(); thread.join(2)

    def test_missing_data_waits_with_exactly_one_host_header(self): self.run_server("wait")
    def test_success_shaped_early_eof_is_a_failed_proof(self): self.run_server("eof")
    def test_fabricated_zero_bytes_are_a_failed_proof(self): self.run_server("zeros")


class CachePauseOracle(unittest.TestCase):
    def observe(self, paused, position):
        elapsed = [0.0]
        def command(connection, reader, args, request_id):
            if args[0] == "set_property": return None
            return paused(elapsed[0]) if args[1] == "paused-for-cache" else position(elapsed[0])
        def sleep(seconds): elapsed[0] += seconds
        with patch.object(proof, "_mpv_command", command), patch.object(proof.time, "monotonic", lambda: elapsed[0]), patch.object(proof.time, "sleep", sleep):
            return proof.wait_cache_pause(None, None, timeout=3)

    def test_transient_cache_pause_does_not_prove_buffering(self):
        with self.assertRaises(TimeoutError):
            self.observe(lambda t: int(t * 10) % 2 == 0, lambda t: 5)

    def test_advancing_playback_does_not_prove_stable_buffering(self):
        with self.assertRaises(TimeoutError):
            self.observe(lambda t: True, lambda t: t)

    def test_continuous_stable_cache_pause_is_observed(self):
        result = self.observe(lambda t: True, lambda t: 5)
        self.assertGreaterEqual(result["stableSeconds"], 1)
        self.assertEqual(5, result["positionAtPause"])

if __name__ == "__main__": unittest.main()
