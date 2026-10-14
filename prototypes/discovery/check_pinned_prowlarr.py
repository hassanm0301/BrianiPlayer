#!/usr/bin/env python3
"""Register/query the deterministic fixture in a throwaway Prowlarr instance."""
import json
import os
import time
import urllib.parse
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET


base = os.environ.get("PROWLARR_URL", "http://127.0.0.1:19696").rstrip("/")
fixture_base = os.environ.get("PROWLARR_FIXTURE_BASE_URL", "http://host.docker.internal:18787")
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


class ApiHttpError(RuntimeError):
    def __init__(self, status, validation):
        self.code = status
        super().__init__(f"Prowlarr HTTP status {status}; validation fields={validation}")
key = os.environ.get("PROWLARR_API_KEY")
config_path = os.environ.get("PROWLARR_CONFIG_XML")
if not key and config_path:
    key = ET.parse(config_path).getroot().findtext("ApiKey")
if not key:
    raise SystemExit("Set PROWLARR_API_KEY for the isolated local test instance")


def api(path, method="GET", body=None):
    headers = {"X-Api-Key": key, "Accept": "application/json"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with opener.open(req, timeout=15) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        try:
            body = json.loads(error.read())
            fields = sorted({
                str(item.get("propertyName", "")) + ":" + str(item.get("errorCode", ""))
                for item in body if isinstance(item, dict)
            })
        except (json.JSONDecodeError, TypeError):
            fields = []
        suffix = ",".join(fields)[:240]
        raise ApiHttpError(error.code, suffix or "unavailable") from None


status = api("/api/v1/system/status")
schemas = api("/api/v1/indexer/schema")
schema = next(x for x in schemas if x.get("implementation") == "Torznab")
schema["name"] = "Briani deterministic fixture"
schema["enable"] = True
profiles = api("/api/v1/appprofile")
schema["appProfileId"] = profiles[0]["id"]
for field in schema.get("fields", []):
    name = field.get("name", "").lower()
    if name == "baseurl":
        field["value"] = fixture_base
    elif name == "apipath":
        field["value"] = "/api"
    elif name == "apikey":
        field["value"] = ""
created = api("/api/v1/indexer", "POST", schema)
indexer_id = created.get("id")
if not indexer_id:
    raise SystemExit("Prowlarr did not return the fixture indexer identity")

query = urllib.parse.urlencode({"type": "search", "query": "", "indexerIds": indexer_id, "limit": 20})
recent = api("/api/v1/search?" + query)
query = urllib.parse.urlencode({"type": "search", "query": "sample", "indexerIds": indexer_id, "limit": 20})
search = api("/api/v1/search?" + query)
query = urllib.parse.urlencode({"type": "search", "query": "trigger-fixture-failure", "indexerIds": indexer_id, "limit": 20})
failure_status = None
failure_result_count = None
try:
    failure_result_count = len(api("/api/v1/search?" + query))
    failure_status = 200
except ApiHttpError as error:
    failure_status = getattr(error, "code", None)
time.sleep(1)
statuses = api("/api/v1/indexerstatus")
status_fields = sorted(statuses[0].keys()) if statuses else []
status_sample = []
for row in statuses:
    status_sample.append({
        "indexerId": row.get("indexerId"),
        "disabledTill": row.get("disabledTill"),
        "mostRecentFailureType": type(row.get("mostRecentFailure")).__name__,
        "initialFailureType": type(row.get("initialFailure")).__name__,
        "mostRecentFailurePresent": bool(row.get("mostRecentFailure")),
        "initialFailurePresent": bool(row.get("initialFailure")),
    })
if not recent or not search:
    raise SystemExit("Pinned Prowlarr did not return both recent and text fixture results")
if any(item.get("protocol", "").lower() != "torrent" for item in recent + search):
    raise SystemExit("Prowlarr returned a non-torrent result for the torrent fixture")
print(json.dumps({
    "version": status.get("version"),
    "branch": status.get("branch"),
    "fixtureProtocol": created.get("protocol"),
    "supportsSearch": created.get("supportsSearch"),
    "supportsRss": created.get("supportsRss"),
    "capabilityFields": sorted(created.get("capabilities", {}).keys()),
    "recentCount": len(recent),
    "searchCount": len(search),
    "resultFields": sorted(search[0].keys()),
    "recentFields": sorted(recent[0].keys()),
    "fixtureFailureSearchHttpStatus": failure_status,
    "fixtureFailureResultCount": failure_result_count,
    "indexerStatusFields": status_fields,
    "indexerStatusSample": status_sample,
}, indent=2))
