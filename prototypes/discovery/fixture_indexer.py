#!/usr/bin/env python3
"""Deterministic local Torznab endpoint for pinned-Prowlarr compatibility checks."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from urllib.parse import parse_qs, urlparse

CAPS = b'''<?xml version="1.0" encoding="UTF-8"?>
<caps><searching><search available="yes" supportedParams="q"/><tv-search available="no"/><movie-search available="no"/><audio-search available="no"/><book-search available="no"/></searching>
<categories><category id="2000" name="Movies"><subcat id="2001" name="fixture"/></category></categories></caps>'''

ITEMS = {
    "latest": [("fixture-latest-guid", "Fixture Latest release", "987654", "17", "3", "2026-01-02T03:04:05Z")],
    "search": [("fixture-search-guid", "Fixture Search release", "123456", "8", "2", "2026-01-01T03:04:05Z")],
}


class Handler(BaseHTTPRequestHandler):
    server_version = "BrianiFixtureIndexer/1"

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path not in ("/api", "/"):
            self.send_error(404)
            return
        params = parse_qs(parsed.query)
        if params.get("t", [""])[0] == "caps":
            self._send(CAPS)
            return
        query = params.get("q", [""])[0].strip()
        if query == "trigger-fixture-failure":
            self.send_error(503, "deterministic fixture failure")
            return
        records = ITEMS["search"] if query else ITEMS["latest"]
        items = []
        for guid, title, size, seeders, leechers, published in records:
            items.append(
                f'<item><title>{title}</title><guid>{guid}</guid>'
                f'<link>magnet:?xt=urn:btih:0123456789012345678901234567890123456789</link>'
                f'<enclosure url="magnet:?xt=urn:btih:0123456789012345678901234567890123456789" length="{size}" type="application/x-bittorrent"/>'
                f'<size>{size}</size><pubDate>{published}</pubDate><category>2000</category>'
                f'<torznab:attr name="seeders" value="{seeders}"/>'
                f'<torznab:attr name="peers" value="{int(seeders) + int(leechers)}"/>'
                f'<torznab:attr name="leechers" value="{leechers}"/>'
                f'<torznab:attr name="infohash" value="0123456789012345678901234567890123456789"/></item>'
            )
        body = (
            '<?xml version="1.0" encoding="UTF-8"?>'
            '<rss version="2.0" xmlns:torznab="http://torznab.com/schemas/2015/feed">'
            '<channel>' + ''.join(items) + '</channel></rss>'
        ).encode()
        self._send(body)

    def _send(self, body):
        self.send_response(200)
        self.send_header("Content-Type", "application/xml; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        # Never log query parameters, which may contain private tracker credentials.
        print(f"fixture-indexer {self.command} {urlparse(self.path).path}", flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer((os.environ.get("FIXTURE_BIND", "127.0.0.1"),
                         int(os.environ.get("FIXTURE_PORT", "18787"))), Handler).serve_forever()
