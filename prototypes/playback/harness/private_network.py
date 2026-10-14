#!/usr/bin/env python3
"""Disable peer-discovery and port-forwarding features for the private swarm."""
from __future__ import annotations

import argparse
import http.cookiejar
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True)
    parser.add_argument("--credentials", type=Path, required=True)
    args = parser.parse_args()
    try:
        credentials = json.loads(args.credentials.read_text(encoding="utf-8"))
        username, password = credentials["username"], credentials["password"]
    except (OSError, ValueError, KeyError, TypeError):
        print("credential file is unreadable or invalid", file=sys.stderr)
        return 2

    base = args.url.rstrip("/")
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                                         urllib.request.HTTPCookieProcessor(jar))
    opener.addheaders = [("Referer", base + "/")]

    def request(path: str, data: bytes | None = None) -> bytes:
        with opener.open(urllib.request.Request(base + path, data=data), timeout=8) as response:
            return response.read()

    try:
        request("/api/v2/auth/login", urllib.parse.urlencode(
            {"username": username, "password": password}).encode())
        if not any(cookie.name == "SID" or cookie.name.startswith("QBT_SID_") for cookie in jar):
            raise RuntimeError("qBittorrent did not return a recognized session cookie")
        settings = {"dht": False, "pex": False, "lsd": False,
                    "upnp": False, "web_ui_upnp": False}
        request("/api/v2/app/setPreferences", urllib.parse.urlencode(
            {"json": json.dumps(settings)}).encode())
        actual = json.loads(request("/api/v2/app/preferences"))
        mismatches = {key: actual.get(key) for key, expected in settings.items()
                      if actual.get(key) is not expected}
        if mismatches:
            raise RuntimeError("private network preferences did not persist: " +
                               ", ".join(sorted(mismatches)))
    except Exception as exc:
        print(f"unable to enforce private swarm preferences: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    print(json.dumps({"url": base, "preferences": settings}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
