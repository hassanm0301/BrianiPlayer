"""Actual ready/server HTTP verification for the isolated Compose installation."""
import json
import time
import urllib.request

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
deadline = time.monotonic() + 30
while time.monotonic() < deadline:
    try:
        with opener.open("http://127.0.0.1:18089/readyz", timeout=2) as r:
            assert r.status == 200 and json.load(r)["status"] == "ready"
        with opener.open("http://127.0.0.1:18089/api/v1/server", timeout=2) as r:
            body = json.load(r)
            assert r.status == 200 and body["apiMajor"] == 1 and body["bootstrapRequired"] is True
        print("PASS: actual Compose HTTP readiness and schema initialization")
        break
    except (OSError, ValueError): time.sleep(.2)
else: raise SystemExit("FAIL: isolated Compose service did not become ready")
