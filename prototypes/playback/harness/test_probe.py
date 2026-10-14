import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from probe import QbitProbe


class FixtureHandler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def _send(self, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        status = self.server.login_status if self.path == "/api/v2/auth/login" else 200
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        if self.path == "/api/v2/auth/login":
            self.send_header("Set-Cookie", f"{self.server.cookie_name}=unit-test-session; Path=/")
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if self.path == "/api/v2/auth/login":
            self._send(b"Ok.", "text/plain")
        else:
            self.send_error(404)

    def do_GET(self):
        self.server.seen.append(self.path)
        cookie = self.headers.get("Cookie", "")
        if not (cookie.startswith("SID=") or cookie.startswith("QBT_SID_8080=")):
            self.send_error(403)
            return
        route = urlparse(self.path).path
        responses = {
            "/api/v2/app/version": ("v5.1.3", "text/plain"),
            "/api/v2/app/webapiVersion": ("2.11.3", "text/plain"),
            "/api/v2/app/buildInfo": ({"libtorrent": "2.0.11", "platform": "linux"}, "application/json"),
            "/api/v2/app/preferences": ({"web_ui_username": "admin", "web_ui_password": "", "listen_port": 6881}, "application/json"),
            "/api/v2/torrents/info": ([{"hash": "a" * 40, "name": "fixture", "state": "downloading", "progress": .2,
                                          "size": 100, "downloaded": 20, "amount_left": 80, "seq_dl": True,
                                          "f_l_piece_prio": True}], "application/json"),
            "/api/v2/torrents/files": ([{"index": 0, "name": "fixture.bin", "size": 100, "progress": .2, "priority": 1}], "application/json"),
            "/api/v2/torrents/pieceStates": ([2, 1, 0], "application/json"),
            "/api/v2/torrents/export": (b"d4:infod4:name7:fixtureee", "application/x-bittorrent"),
        }
        if route not in responses:
            self.send_error(404)
            return
        body, content_type = responses[route]
        self._send(body, content_type)


class ProbeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
        cls.server.seen = []
        cls.server.cookie_name = "QBT_SID_8080"
        cls.server.login_status = 204
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_authenticated_observations_and_payload_summaries(self):
        base = f"http://127.0.0.1:{self.server.server_port}"
        report = QbitProbe(base, "unit", "secret").collect("a" * 40)
        self.assertEqual(report["api"]["applicationVersion"], "v5.1.3")
        self.assertEqual(report["api"]["buildInfo"]["libtorrent"], "2.0.11")
        self.assertEqual(report["preferences"]["web_ui_username"], "<redacted>")
        torrent = report["torrents"][0]
        self.assertEqual(torrent["pieceStates"], [2, 1, 0])
        self.assertEqual(torrent["files"][0]["name"], "fixture.bin")
        self.assertEqual(torrent["export"]["bytes"], 25)
        self.assertNotIn("d4:infod4:name", json.dumps(report))
        self.assertEqual(len(report["observations"]), 9)
        self.assertTrue(all(o["outcome"] == "ok" for o in report["observations"]))

    def test_legacy_sid_cookie_remains_supported(self):
        self.server.cookie_name = "SID"
        self.server.login_status = 200
        base = f"http://127.0.0.1:{self.server.server_port}"
        report = QbitProbe(base, "unit", "secret").collect("a" * 40)
        self.assertEqual(report["api"]["applicationVersion"], "v5.1.3")


if __name__ == "__main__":
    unittest.main()
