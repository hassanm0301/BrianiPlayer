#!/usr/bin/env python3
"""Authenticated, read-only qBittorrent Web API capability probe.

Credentials are read from environment variables and never serialized. The only
mutation is the documented login needed to obtain the SID cookie.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import http.cookiejar
import json
import os
import platform
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class Observation:
    operation: str
    path: str
    status: int | None
    outcome: str
    detail: str | None = None


class ApiError(RuntimeError):
    pass


class QbitProbe:
    def __init__(self, base_url: str, username: str, password: str, timeout: float = 8.0):
        self.base = base_url.rstrip("/")
        self.timeout = timeout
        self.jar = http.cookiejar.CookieJar()
        # The harness addresses qBittorrent through loopback or its internal
        # Docker bridge. Never route that private API traffic through an
        # ambient HTTP(S) proxy inherited from the developer environment.
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                                                  urllib.request.HTTPCookieProcessor(self.jar))
        self.observations: list[Observation] = []
        self.opener.addheaders = [("Referer", self.base + "/"), ("User-Agent", "Briani-M00-Capability-Probe/1")]
        self._request("login", "/api/v2/auth/login", method="POST",
                      data=urllib.parse.urlencode({"username": username, "password": password}).encode())
        if not any(c.name == "SID" or c.name.startswith("QBT_SID_") for c in self.jar):
            raise ApiError("login did not return a recognized qBittorrent session cookie")

    def _request(self, operation: str, path: str, *, method: str = "GET", data: bytes | None = None) -> bytes:
        req = urllib.request.Request(self.base + path, data=data, method=method)
        try:
            with self.opener.open(req, timeout=self.timeout) as response:
                raw = response.read(8 * 1024 * 1024 + 1)
                if len(raw) > 8 * 1024 * 1024:
                    raise ApiError(f"{operation}: response exceeded 8 MiB safety bound")
                self.observations.append(Observation(operation, path.split("?", 1)[0], response.status, "ok"))
                return raw
        except urllib.error.HTTPError as exc:
            self.observations.append(Observation(operation, path.split("?", 1)[0], exc.code, "http_error"))
            raise ApiError(f"{operation}: HTTP {exc.code}") from exc
        except (urllib.error.URLError, TimeoutError) as exc:
            reason = str(getattr(exc, "reason", exc))[:240]
            self.observations.append(Observation(operation, path.split("?", 1)[0], None, "transport_error", reason))
            raise ApiError(f"{operation}: {reason}") from exc

    def _text(self, operation: str, path: str) -> str:
        value = self._request(operation, path).decode("utf-8", "replace").strip()
        # qBittorrent API string endpoints are JSON strings in current Web API
        # implementations; tolerate legacy plain-text responses as well.
        try:
            parsed = json.loads(value)
            if isinstance(parsed, str):
                return parsed
        except json.JSONDecodeError:
            pass
        return value

    def _json(self, operation: str, path: str) -> Any:
        return json.loads(self._request(operation, path))

    def collect(self, torrent_hash: str | None = None) -> dict[str, Any]:
        report: dict[str, Any] = {
            "capturedAtUtc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "probe": {"python": platform.python_version(), "platform": platform.platform()},
            "api": {}, "preferences": {}, "torrents": [],
        }
        report["api"]["applicationVersion"] = self._text("app.version", "/api/v2/app/version")
        report["api"]["webApiVersion"] = self._text("app.webapiVersion", "/api/v2/app/webapiVersion")
        report["api"]["buildInfo"] = self._json("app.buildInfo", "/api/v2/app/buildInfo")
        prefs = self._json("app.preferences", "/api/v2/app/preferences")
        # Never persist credentials or free-form configuration values that may contain them.
        sensitive = ("password", "secret", "token", "passkey", "api_key", "username", "bypass_auth_subnet_whitelist")
        report["preferences"] = {k: ("<redacted>" if any(s in k.lower() for s in sensitive) else v)
                                 for k, v in prefs.items()}
        torrents = self._json("torrents.info", "/api/v2/torrents/info")
        chosen = [t for t in torrents if torrent_hash is None or t.get("hash", "").lower() == torrent_hash.lower()]
        for item in chosen:
            h = item.get("hash")
            if not h:
                continue
            rec: dict[str, Any] = {
                "hash": h, "name": item.get("name"), "state": item.get("state"),
                "progress": item.get("progress"), "size": item.get("size"),
                "downloaded": item.get("downloaded"), "amount_left": item.get("amount_left"),
                "seq_dl": item.get("seq_dl"), "f_l_piece_prio": item.get("f_l_piece_prio"),
            }
            query_hash = urllib.parse.urlencode({"hash": h})
            try:
                rec["files"] = self._json("torrents.files", "/api/v2/torrents/files?" + query_hash)
            except (ApiError, ValueError) as exc:
                rec["filesError"] = str(exc)
            try:
                rec["pieceStates"] = self._json("torrents.pieceStates", "/api/v2/torrents/pieceStates?" + query_hash)
            except (ApiError, ValueError) as exc:
                rec["pieceStatesError"] = str(exc)
            try:
                raw = self._request("torrents.export", "/api/v2/torrents/export?" + query_hash)
                rec["export"] = {"available": True, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
                                 "bencodePrefix": raw[:1].decode("ascii", "replace")}
            except ApiError as exc:
                rec["export"] = {"available": False, "error": str(exc)}
            report["torrents"].append(rec)
        if torrent_hash and not chosen:
            raise ApiError("requested torrent hash was not present in torrents/info")
        report["observations"] = [o.__dict__ for o in self.observations]
        return report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--url", default=os.getenv("QB_URL"))
    ap.add_argument("--hash", dest="torrent_hash", help="Inspect one torrent; omit to enumerate all")
    ap.add_argument("--output", type=Path, help="Write JSON report here (default stdout)")
    ap.add_argument("--credentials", type=Path, default=Path(__file__).parent / "state" / "credentials.json",
                    help="Read username/password JSON here when QB_USERNAME/QB_PASSWORD are not set")
    ap.add_argument("--timeout", type=float, default=8.0)
    args = ap.parse_args(argv)
    if not args.url:
        endpoints = Path(__file__).parent / "state" / "endpoints.json"
        if endpoints.is_file():
            try:
                args.url = json.loads(endpoints.read_text(encoding="utf-8"))["qbittorrent"]["apiBase"]
            except (OSError, ValueError, KeyError, TypeError):
                print("endpoint file is unreadable or invalid", file=sys.stderr)
                return 2
        else:
            args.url = "http://127.0.0.1:18081"
    username, password = os.getenv("QB_USERNAME"), os.getenv("QB_PASSWORD")
    if (not username or not password) and args.credentials.is_file():
        try:
            credentials = json.loads(args.credentials.read_text(encoding="utf-8"))
            username = username or credentials.get("username")
            password = password or credentials.get("password")
        except (OSError, ValueError, AttributeError):
            print("credential file is unreadable or invalid", file=sys.stderr)
            return 2
    if not username or not password:
        print("QB_USERNAME and QB_PASSWORD, or a valid credentials JSON file, are required", file=sys.stderr)
        return 2
    try:
        result = QbitProbe(args.url, username, password, args.timeout).collect(args.torrent_hash)
    except (ApiError, ValueError, json.JSONDecodeError) as exc:
        print(f"qBittorrent capability probe failed: {exc}", file=sys.stderr)
        return 1
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
