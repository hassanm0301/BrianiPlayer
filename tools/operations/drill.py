#!/usr/bin/env python3
"""Run a disposable, secret-safe M09 Docker integration/restore drill."""
from __future__ import annotations

import argparse
import hashlib
import http.cookiejar
import importlib.util
import json
import os
import pathlib
import re
import secrets
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[2]
CLI = ROOT / "tools/operations/briani.py"
PORTS = (8088, 18080, 19696)
SERVICES = ("briani", "qbittorrent", "prowlarr")
LOG_PATH: pathlib.Path | None = None

spec = importlib.util.spec_from_file_location("briani_operations_for_drill", CLI)
ops = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(ops)


class DrillError(RuntimeError):
    pass


class ProwlarrTransientError(DrillError):
    """Prowlarr has not finished starting or its listener is temporarily unavailable."""


def compose_project_name(project: pathlib.Path) -> str:
    resolved = project.resolve()
    slug = re.sub(r"[^a-z0-9_-]+", "-", resolved.name.lower()).strip("-") or "deployment"
    suffix = hashlib.sha256(str(resolved).encode()).hexdigest()[:10]
    return f"briani-{slug[:24]}-{suffix}"


def check_ports_available(ports: tuple[int, ...] = PORTS) -> None:
    occupied: list[int] = []
    sockets: list[socket.socket] = []
    try:
        for port in ports:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sockets.append(sock)
            try:
                sock.bind(("127.0.0.1", port))
            except OSError:
                occupied.append(port)
        if occupied:
            raise DrillError("required loopback port(s) already occupied: " + ",".join(map(str, occupied)))
    finally:
        for sock in sockets:
            sock.close()


def run_readonly(argv: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(argv, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, check=False)
    except OSError as error:
        raise DrillError(f"cannot run {pathlib.Path(argv[0]).name}: {type(error).__name__}") from error


def inspect_json(object_type: str, ids: list[str]) -> list[dict[str, Any]]:
    if not ids:
        return []
    result = run_readonly(["docker", object_type, "inspect", *ids])
    if result.returncode:
        raise DrillError(f"docker {object_type} inspect failed ({result.returncode})")
    try:
        value = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise DrillError(f"docker {object_type} inspect returned invalid JSON") from error
    if not isinstance(value, list):
        raise DrillError(f"docker {object_type} inspect returned an invalid result")
    return value


def docker_ids(kind: str, project_name: str) -> list[str]:
    args = ["docker", kind, "ls", "-q", "--filter", f"label=com.docker.compose.project={project_name}"]
    if kind == "container":
        args.insert(3, "-a")
    result = run_readonly(args)
    if result.returncode:
        raise DrillError(f"docker {kind} inventory failed ({result.returncode})")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def resource_labels(record: dict[str, Any]) -> dict[str, str]:
    return (record.get("Config", {}).get("Labels") or record.get("Labels") or {})


def mount_sources(record: dict[str, Any]) -> list[pathlib.Path]:
    return [pathlib.Path(mount["Source"]).resolve() for mount in record.get("Mounts", []) if mount.get("Source")]


def is_owned_container(record: dict[str, Any], project_name: str, root: pathlib.Path) -> bool:
    labels = resource_labels(record)
    sources = mount_sources(record)
    resolved_root = root.resolve()
    guard = labels.get("com.docker.compose.service") == "torrent-egress-guard"
    if guard and not sources:
        locked=json.loads((ROOT/"images.lock.json").read_text())["services"]["torrent-egress-guard"]
        return labels.get("com.docker.compose.project") == project_name and record.get("Image")==locked.get("localImageId")
    return (labels.get("com.docker.compose.project") == project_name and bool(sources)
            and all(source == resolved_root or resolved_root in source.parents for source in sources))


def log_line(message: str) -> None:
    print(message, flush=True)
    if LOG_PATH is not None:
        fd = os.open(LOG_PATH, os.O_WRONLY | os.O_APPEND | os.O_NOFOLLOW)
        with os.fdopen(fd, "a", encoding="utf-8") as output:
            output.write(message + "\n")
            output.flush()


class HttpApi:
    def __init__(self, origin: str):
        self.origin = origin.rstrip("/")

    def request(self, method: str, path: str, body: Any = None, token: str | None = None,
                expected: tuple[int, ...] = (200,), label: str | None = None) -> Any:
        data = None if body is None else json.dumps(body, separators=(",", ":")).encode()
        headers = {"Accept": "application/json"}
        if data is not None:
            headers["Content-Type"] = "application/json"
        if token:
            headers["Authorization"] = "Bearer " + token
        request = urllib.request.Request(self.origin + path, data=data, headers=headers, method=method)
        status = 0
        payload = b""
        try:
            with urllib.request.urlopen(request, timeout=6) as response:
                status, payload = response.status, response.read(2_000_000)
        except urllib.error.HTTPError as error:
            status, payload = error.code, error.read(64_000)
        except (OSError, TimeoutError) as error:
            raise DrillError(f"{label or method + ' ' + path}: transport failed ({type(error).__name__})") from error
        if status not in expected:
            # Never include a response body: auth, validation, and upstream details may be sensitive.
            raise DrillError(f"{label or method + ' ' + path}: unexpected HTTP {status}")
        log_line(f"api {label or method + ' ' + path}: HTTP {status}")
        if not payload:
            return None
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            return payload.decode("utf-8", "replace").strip()


def qbit_preferences(password_path: pathlib.Path) -> tuple[dict[str, Any], dict[str, str]]:
    password = password_path.read_text(encoding="utf-8").strip()
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    transport = "http://127.0.0.1:18080"
    origin = "http://qbittorrent:8080"
    headers = {"Host": "qbittorrent:8080", "Origin": origin, "Referer": origin + "/"}

    def request(path: str, data: bytes | None = None) -> str:
        req = urllib.request.Request(transport + path, data=data, headers=headers, method="POST" if data is not None else "GET")
        try:
            with opener.open(req, timeout=6) as response:
                return response.read(1_000_000).decode("utf-8", "replace").strip()
        except (OSError, urllib.error.URLError, TimeoutError) as error:
            raise DrillError(f"qBittorrent {path}: request failed ({type(error).__name__})") from error

    login = urllib.parse.urlencode({"username": "admin", "password": password}).encode()
    request("/api/v2/auth/login", login)
    cookie_names = [cookie.name for cookie in jar]
    if not any(name == "SID" or name.startswith("QBT_SID") for name in cookie_names):
        raise DrillError("qBittorrent login did not issue an authenticated session cookie")
    raw = request("/api/v2/app/preferences")
    try:
        preferences = json.loads(raw)
    except json.JSONDecodeError as error:
        raise DrillError("qBittorrent preferences endpoint returned invalid JSON") from error
    if not isinstance(preferences, dict):
        raise DrillError("qBittorrent preferences endpoint returned an invalid object")
    return preferences, {"Origin": origin, "Host": "qbittorrent:8080"}


def qbit_limit_readback(requested_bytes_per_second: int) -> int:
    """qBittorrent's transfer-limit API reports whole KiB/s steps."""
    return requested_bytes_per_second // 1024 * 1024


def wait_until(label: str, action, timeout: float = 75, interval: float = 1.0):
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            value = action()
            if value:
                log_line(f"ready {label}: observed")
                return value
        except Exception as error:  # bounded polling; only the final safe label is surfaced.
            last_error = error
        time.sleep(interval)
    if last_error:
        raise DrillError(f"timed out waiting for {label} ({type(last_error).__name__})")
    raise DrillError(f"timed out waiting for {label}")


class IntegratedDrill:
    def __init__(self, root: pathlib.Path, keep: bool = False, retain_on_failure: bool = False):
        self.root = root
        self.keep = keep
        self.retain_on_failure = retain_on_failure
        self.failed = False
        self.source = root / "source-project"
        self.source_data = root / "source-data"
        self.source_state = root / "source-state"
        self.backup = root / "backup"
        self.restore = root / "restore-project"
        self.restore_data = root / "restore-data"
        self.restore_state = root / "restore-state"
        self.rollback = root / "rollback-project"
        self.rollback_data = root / "rollback-data"
        self.rollback_state = root / "rollback-state"
        self.projects = [self.source, self.restore, self.rollback]
        self.api_client = HttpApi("http://127.0.0.1:8088")
        self.project_names = {project: compose_project_name(project) for project in self.projects}
        self.creds: dict[str, str] = {}
        self.member_id = ""
        self.library_id = ""
        self.library_relative = ""
        self.expected_settings: dict[str, int] = {}

    def preflight(self) -> None:
        check_ports_available()
        info = run_readonly(["docker", "info", "--format", "{{.ServerVersion}} {{.OSType}}"])
        if info.returncode:
            raise DrillError(f"Docker daemon unavailable ({info.returncode})")
        locked = json.loads((ROOT / "images.lock.json").read_text())["services"]["briani"]
        self.server_image = locked["localTag"]
        image = run_readonly(["docker", "image", "inspect", "--format={{.Id}}", self.server_image])
        if image.returncode or image.stdout.strip() != locked["localImageId"]:
            raise DrillError("locked local server image ID is missing or mismatched")
        ops.validate_image_lock(self.server_image, local=True, allow_history=False)
        for name in self.project_names.values():
            if any(docker_ids(kind, name) for kind in ("container", "network", "volume")):
                raise DrillError("generated Compose project name already has Docker resources")
        log_line(f"preflight Docker={info.stdout.strip()} image={self.server_image} exact-id ports=free projects=unique")

    def cli(self, label: str, args: list[str], expected: int = 0) -> subprocess.CompletedProcess[str]:
        try:
            result = subprocess.run([sys.executable, str(CLI), *args], cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        except OSError as error:
            raise DrillError(f"{label}: CLI could not run ({type(error).__name__})") from error
        log_line(f"cli {label}: exit {result.returncode} (expected {expected})")
        if result.returncode != expected:
            # CLI diagnostics are deliberately omitted from preserved drill logs.
            raise DrillError(f"{label}: unexpected CLI exit {result.returncode}")
        return result

    def headers(self, token: str | None) -> dict[str, str]:
        return {"Authorization": "Bearer " + token} if token else {}

    def start_source(self) -> None:
        image = self.server_image
        self.cli("init", ["init", "--project", str(self.source), "--data", str(self.source_data),
                           "--state", str(self.source_state), "--bind", "127.0.0.1", "--uid", str(os.getuid()),
                           "--gid", str(os.getgid()), "--image", image, "--local-image"])
        ops.compose(self.source, ["config", "--quiet"], capture=True)
        self.cli("doctor-source", ["doctor", "--project", str(self.source)])
        self.cli("qbit-bootstrap", ["qbit-bootstrap", "--project", str(self.source)])
        secret = self.source_state / "secrets/qbittorrent-webui-password"
        self.assert_private_secret(secret)
        self.cli("up-source", ["up", "--project", str(self.source)])
        wait_until("Briani source health", lambda: self.health())

    def health(self) -> bool:
        try:
            value = self.api_client.request("GET", "/healthz", expected=(200,), label="healthz")
            return isinstance(value, dict) and value.get("status") == "alive"
        except DrillError:
            return False

    @staticmethod
    def assert_private_secret(path: pathlib.Path) -> str:
        if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
            raise DrillError("expected secret file is absent or not private")
        value = path.read_text(encoding="utf-8").strip()
        if not value:
            raise DrillError("expected secret file is empty")
        return value

    def bootstrap_and_admin(self) -> None:
        bootstrap_path = self.source_state / "briani/bootstrap.code"
        code = self.assert_private_secret(bootstrap_path)
        prefix = secrets.token_hex(4)
        admin_password = secrets.token_urlsafe(32)
        admin_username = "drilladmin" + prefix
        tokens = self.api_client.request("POST", "/api/v1/bootstrap", {
            "code": code, "username": admin_username, "displayName": "M09 Isolated Drill", "password": admin_password
        }, expected=(201,), label="claim bootstrap")
        if not isinstance(tokens, dict) or not tokens.get("accessToken"):
            raise DrillError("bootstrap response omitted authentication tokens")
        self.creds = {"adminUsername": admin_username, "adminPassword": admin_password,
                      "adminToken": tokens["accessToken"], "memberUsername": "drillmember" + prefix,
                      "memberPassword": secrets.token_urlsafe(32)}
        log_line("bootstrap token claimed over HTTP; token and generated account password withheld")
        created = self.api_client.request("POST", "/api/v1/admin/users", {
            "username": self.creds["memberUsername"], "displayName": "M09 Drill Member",
            "password": self.creds["memberPassword"], "role": "member"
        }, token=self.creds["adminToken"], expected=(201,), label="create drill member")
        self.member_id = created["id"]

    def login(self, username: str, password: str, label: str) -> str:
        result = self.api_client.request("POST", "/api/v1/auth/login", {
            "username": username, "password": password, "deviceName": "M09 isolated drill"
        }, expected=(200,), label=label)
        if not isinstance(result, dict) or not result.get("accessToken"):
            raise DrillError(f"{label}: login response omitted access token")
        return result["accessToken"]

    def create_library_grant(self) -> None:
        roots = self.api_client.request("GET", "/api/v1/admin/storage", token=self.creds["adminToken"], label="list storage roots")
        if not isinstance(roots, list) or not roots:
            raise DrillError("storage API returned no mounted data root")
        self.library_relative = "m09-ops-" + secrets.token_hex(5)
        (self.source_data / self.library_relative).mkdir(mode=0o700)
        created = self.api_client.request("POST", "/api/v1/libraries", {
            "name": "M09 isolated operations drill", "description": "Generated empty test directory",
            "storageRootId": roots[0]["id"], "relativePath": self.library_relative, "readOnly": False
        }, token=self.creds["adminToken"], expected=(201,), label="create drill library")
        self.library_id = created["id"]
        grants = self.api_client.request("PUT", f"/api/v1/libraries/{self.library_id}/grants", {
            "version": created["version"], "grants": [{"userId": self.member_id,
                "read": True, "download": True, "manage": False, "quotaBytes": None}]
        }, token=self.creds["adminToken"], label="grant drill library")
        if not any(grant.get("userId") == self.member_id and grant.get("download") for grant in grants.get("grants", [])):
            raise DrillError("library grant response did not preserve the member download grant")

    def check_integrations(self) -> tuple[str, str]:
        # Open only the isolated admin overlay ports; Compose binds both to loopback.
        ops.compose(self.source, ["up", "-d", "qbittorrent", "prowlarr"], admin=True, capture=True)
        wait_until("Prowlarr private config", lambda: (self.source_state / "prowlarr/config.xml").is_file())
        self.cli("capture-prowlarr-key", ["capture-prowlarr-key", "--project", str(self.source)])
        qbit_secret = self.assert_private_secret(self.source_state / "secrets/qbittorrent-webui-password")
        prowlarr_secret = self.assert_private_secret(self.source_state / "secrets/prowlarr-api-key")
        self.inspect_upstream_auth_config(prowlarr_secret)
        p_status = self.wait_p_api_ready(prowlarr_secret)
        if not isinstance(p_status, dict) or not isinstance(p_status.get("version"), str):
            raise DrillError("isolated Prowlarr system status did not return a version")
        indexers = self.raw_p_get("/api/v1/indexer", prowlarr_secret)
        if not isinstance(indexers, list) or indexers:
            raise DrillError("isolated Prowlarr is not empty; refusing to run a real-indexer drill")
        log_line("loopback Prowlarr API key verified; no indexers are configured")
        self.wait_qbit_ready(self.source)
        integrations = self.api_client.request("GET", "/api/v1/admin/integrations", token=self.creds["adminToken"], label="read mounted integration fallback")
        by_kind = {item["kind"]: item for item in integrations}
        if not all(by_kind.get(kind, {}).get("credentialConfigured") is True for kind in ("prowlarr", "qbittorrent")):
            raise DrillError("read-only mounted integration fallback did not report configured credentials")
        log_line("integration GET confirms read-only mounted credentials configured; no API save has occurred")
        for kind in ("prowlarr", "qbittorrent"):
            result = self.api_client.request("POST", f"/api/v1/admin/integrations/{kind}/test", None,
                token=self.creds["adminToken"], label=f"test {kind} mounted credential")
            if result.get("state") != "healthy":
                safe_state = result.get("state") if result.get("state") in {"healthy", "unavailable"} else "unknown"
                safe_detail = result.get("detail") if result.get("detail") in {
                    "credentials_missing", "credentials_rejected", "dependency_unavailable", "invalid_response"
                } else "unspecified"
                raise DrillError(f"mounted {kind} credential health was not healthy: state={safe_state} detail={safe_detail}")

        for kind, base, secret, username in (
                ("prowlarr", "http://prowlarr:9696/", prowlarr_secret, None),
                ("qbittorrent", "http://qbittorrent:8080/", qbit_secret, "admin")):
            before = by_kind[kind]["version"]
            saved = self.api_client.request("PUT", f"/api/v1/admin/integrations/{kind}", {
                "baseUrl": base, "version": before, "username": username, "secret": secret
            }, token=self.creds["adminToken"], label=f"persist encrypted {kind} integration")
            serialized = json.dumps(saved)
            if secret in serialized or "encryptedSecret" in serialized:
                raise DrillError(f"{kind} integration API response exposed a credential")
        self.assert_encrypted_credentials(self.source_state / "briani/briani.db", qbit_secret, prowlarr_secret)
        return qbit_secret, prowlarr_secret

    def wait_qbit_ready(self, project: pathlib.Path) -> None:
        secret = pathlib.Path(ops.parse_env(project / ".env")["BRIANI_STATE"]) / "secrets/qbittorrent-webui-password"
        def ready():
            try:
                preferences, _ = qbit_preferences(secret)
                return isinstance(preferences, dict)
            except DrillError:
                return False
        wait_until("recreated qBittorrent authenticated readiness", ready, timeout=120)

    def raw_p_get(self, path: str, key: str) -> Any:
        req = urllib.request.Request("http://127.0.0.1:19696" + path, headers={"X-Api-Key": key})
        try:
            with urllib.request.urlopen(req, timeout=8) as response:
                return json.loads(response.read(1_000_000))
        except urllib.error.HTTPError as error:
            # Preserve only status and header names. Never read/log upstream bodies or header values.
            names = ",".join(sorted(str(name) for name in error.headers.keys())) if error.headers else "none"
            if error.code in {408, 425, 429, 500, 502, 503, 504}:
                raise ProwlarrTransientError(f"isolated Prowlarr check HTTP {error.code}; response-header-names={names}") from error
            raise DrillError(f"isolated Prowlarr check HTTP {error.code}; response-header-names={names}") from error
        except (ConnectionError, TimeoutError) as error:
            raise ProwlarrTransientError(f"isolated Prowlarr transport not ready ({type(error).__name__})") from error
        except (OSError, urllib.error.URLError, json.JSONDecodeError) as error:
            raise ProwlarrTransientError(f"isolated Prowlarr transport not ready ({type(error).__name__})") from error

    def wait_p_api_ready(self, key: str, timeout: float = 120, interval: float = 1.0) -> dict[str, Any]:
        deadline = time.monotonic() + timeout
        last_error: ProwlarrTransientError | None = None
        while time.monotonic() < deadline:
            try:
                status = self.raw_p_get("/api/v1/system/status", key)
                if isinstance(status, dict) and isinstance(status.get("version"), str):
                    log_line("Prowlarr API readiness: authenticated system/status returned version")
                    return status
                last_error = ProwlarrTransientError("Prowlarr system/status response not ready")
            except ProwlarrTransientError as error:
                last_error = error
            except DrillError:
                # Authentication and other permanent HTTP failures are never readiness successes.
                raise
            time.sleep(interval)
        detail = f" ({type(last_error).__name__})" if last_error else ""
        raise DrillError(f"timed out waiting for authenticated Prowlarr API readiness after {timeout:g}s{detail}")

    def inspect_upstream_auth_config(self, mounted_prowlarr_key: str) -> None:
        config = self.source_state / "prowlarr/config.xml"
        qbit_config = self.source_state / "qbittorrent/qBittorrent/qBittorrent.conf"
        try:
            root = ET.parse(config).getroot()
            configured_key = root.findtext("ApiKey")
        except (OSError, ET.ParseError):
            configured_key = None
        qbit_fields: set[str] = set()
        try:
            for line in qbit_config.read_text(encoding="utf-8", errors="replace").splitlines():
                if "=" in line:
                    qbit_fields.add(line.split("=", 1)[0].strip())
        except OSError:
            pass
        log_line(f"private upstream config inspection: Prowlarr ApiKey matches mounted key={bool(configured_key and secrets.compare_digest(configured_key, mounted_prowlarr_key))}; qBittorrent config present={qbit_config.is_file()}; WebUI auth fields present={bool(qbit_fields & {'WebUI\\Username', 'WebUI\\Password_PBKDF2', 'WebUI\\Password_ha1'})}")

    @staticmethod
    def assert_encrypted_credentials(database: pathlib.Path, *secrets_to_check: str) -> None:
        uri = "file:" + urllib.parse.quote(str(database)) + "?mode=ro"
        try:
            with sqlite3.connect(uri, uri=True, timeout=5) as connection:
                rows = dict(connection.execute("SELECT Key, ValueJson FROM Settings WHERE Key IN ('integration.prowlarr','integration.qbittorrent')"))
        except sqlite3.Error as error:
            raise DrillError(f"cannot inspect integration persistence ({type(error).__name__})") from error
        if set(rows) != {"integration.prowlarr", "integration.qbittorrent"}:
            raise DrillError("encrypted integration records are missing from SQLite")
        for value in rows.values():
            record = json.loads(value)
            encrypted = record.get("encryptedSecret")
            if not encrypted or any(secret in value for secret in secrets_to_check):
                raise DrillError("integration secret was not encrypted at rest")

    def update_admin_settings(self) -> None:
        self._active_project = self.source
        current = self.api_client.request("GET", "/api/v1/admin/settings", token=self.creds["adminToken"], label="read admin settings")
        changes = {"version": current["version"], "globalConnections": 113, "connectionsPerTorrent": 17,
                   "activeDownloads": 3, "activeSeeds": 2, "downloadLimitBytesPerSecond": 23456,
                   "uploadLimitBytesPerSecond": 12345}
        updated = self.api_client.request("PUT", "/api/v1/admin/settings", changes,
            token=self.creds["adminToken"], label="persist qBittorrent desired settings")
        self.expected_settings = {"max_connec": 113, "max_connec_per_torrent": 17,
                                  "max_active_downloads": 3, "max_active_uploads": 2}
        if updated.get("downloadLimitBytesPerSecond") != 23456 or updated.get("uploadLimitBytesPerSecond") != 12345:
            raise DrillError("admin settings API did not persist requested transfer limits")
        ops.compose(self.source, ["up", "-d", "qbittorrent"], admin=True, capture=True)
        wait_until("durable qBittorrent configuration job", self.verify_qbit_settings, timeout=90)
        log_line("qBittorrent worker preferences and transfer limits match persisted admin settings")

    def verify_qbit_settings(self) -> bool:
        project = self._active_project
        prefs, _ = qbit_preferences(pathlib.Path(ops.parse_env(project / ".env")["BRIANI_STATE"]) / "secrets/qbittorrent-webui-password")
        if any(prefs.get(key) != value for key, value in self.expected_settings.items()):
            return False
        desired = {"/api/v2/transfer/downloadLimit": qbit_limit_readback(23456),
                   "/api/v2/transfer/uploadLimit": qbit_limit_readback(12345)}
        for path, value in desired.items():
            if self.qbit_plain(path) != value:
                return False
        return True

    def qbit_plain(self, path: str) -> int:
        req = urllib.request.Request("http://127.0.0.1:18080" + path,
            headers={"Host": "qbittorrent:8080", "Origin": "http://qbittorrent:8080", "Referer": "http://qbittorrent:8080/"})
        # qbit_preferences just authenticated via a per-call cookie jar, so authenticate again here.
        jar = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        env = ops.parse_env(self._active_project / ".env")
        pwd = (pathlib.Path(env["BRIANI_STATE"]) / "secrets/qbittorrent-webui-password").read_text().strip()
        login_req = urllib.request.Request("http://127.0.0.1:18080/api/v2/auth/login",
            data=urllib.parse.urlencode({"username": "admin", "password": pwd}).encode(),
            headers={"Host":"qbittorrent:8080","Origin":"http://qbittorrent:8080","Referer":"http://qbittorrent:8080/"})
        try:
            with opener.open(login_req, timeout=6): pass
            with opener.open(req, timeout=6) as response: return int(response.read(128).decode().strip())
        except (OSError, ValueError, urllib.error.URLError) as error:
            raise DrillError(f"qBittorrent limit check failed ({type(error).__name__})") from error

    def update_user_preferences(self) -> None:
        prefs = self.api_client.request("GET", "/api/v1/me/preferences", token=self.creds["adminToken"], label="read default user preferences")
        if prefs.get("theme") != "system" or prefs.get("discoveryViews") != []:
            raise DrillError("fresh user preference defaults differ from contract")
        views = [{"mode":"latest","sort":"publishedAt","order":"desc","providerIds":[],"categories":[]}]
        self.api_client.request("GET", "/api/v1/discovery/providers", token=self.creds["adminToken"], label="read discovery providers")
        changed = self.api_client.request("PUT", "/api/v1/me/preferences", {
            "version": prefs["version"], "theme":"dark", "defaultPlaybackSpeed":1.25, "discoveryViews":views
        }, token=self.creds["adminToken"], label="save user discovery preferences")
        if changed.get("theme") != "dark" or changed.get("discoveryViews") != views:
            raise DrillError("user preferences did not persist selected view")

    def verify_identity_state(self, project: pathlib.Path, data: pathlib.Path, state: pathlib.Path,
                              label: str) -> None:
        self._active_project = project
        # Re-create the empty directory with the same relative library root; no media is copied.
        (data / self.library_relative).mkdir(parents=True, exist_ok=True, mode=0o700)
        ops.compose(project, ["up", "-d", "qbittorrent", "prowlarr"], admin=True, capture=True)
        prowlarr_secret = self.assert_private_secret(state / "secrets/prowlarr-api-key")
        self.wait_p_api_ready(prowlarr_secret)
        self.api_client = HttpApi("http://127.0.0.1:8088")
        wait_until(label + " readiness", lambda: self.health())
        admin_token = self.login(self.creds["adminUsername"], self.creds["adminPassword"], label + " admin login")
        member_token = self.login(self.creds["memberUsername"], self.creds["memberPassword"], label + " member login")
        users = self.api_client.request("GET", "/api/v1/admin/users", token=admin_token, label=label + " users")
        if not any(item.get("id") == self.member_id for item in users):
            raise DrillError(label + " missing persisted member account")
        grants = self.api_client.request("GET", f"/api/v1/libraries/{self.library_id}/grants", token=admin_token, label=label + " library grant")
        if not any(grant.get("userId") == self.member_id and grant.get("read") and grant.get("download") for grant in grants.get("grants", [])):
            raise DrillError(label + " missing persisted library grant")
        member_libraries = self.api_client.request("GET", "/api/v1/libraries", token=member_token, label=label + " member library access")
        if not any(item.get("id") == self.library_id for item in member_libraries):
            raise DrillError(label + " member does not retain granted library access")
        self.api_client.request("GET", "/api/v1/admin/users", token=member_token,
            expected=(403,), label=label + " member admin denial")
        integrations = self.api_client.request("GET", "/api/v1/admin/integrations", token=admin_token, label=label + " encrypted integrations")
        if not all(item.get("credentialConfigured") is True for item in integrations):
            raise DrillError(label + " integration credentials were not restored")
        for kind in ("prowlarr", "qbittorrent"):
            health = self.api_client.request("POST", f"/api/v1/admin/integrations/{kind}/test", {},
                token=admin_token, label=label + " integration " + kind)
            if health.get("state") != "healthy":
                raise DrillError(label + " integration " + kind + " is not healthy")
        self.assert_encrypted_credentials(state / "briani/briani.db",
            self._qbit_secret, self._prowlarr_secret)
        self.wait_qbit_ready(project)
        settings = self.api_client.request("GET", "/api/v1/admin/settings", token=admin_token, label=label + " admin settings")
        if settings.get("globalConnections") != 113 or settings.get("downloadLimitBytesPerSecond") != 23456:
            raise DrillError(label + " admin settings were not restored")
        prefs = self.api_client.request("GET", "/api/v1/me/preferences", token=admin_token, label=label + " preferences persisted")
        if prefs.get("theme") != "dark" or not prefs.get("discoveryViews"):
            raise DrillError(label + " discovery preferences were not restored")

    def backup_restore_rollback(self) -> None:
        self.cli("backup", ["backup", "--project", str(self.source), "--output", str(self.backup)])
        ops.verify_backup(self.backup, deployment=True)
        manifest = json.loads((self.backup / "manifest.json").read_text())
        log_line(f"backup files={len(manifest.get('files', []))} mediaIncluded={manifest.get('mediaIncluded')}")
        compatibility = self.root / "unsafe-compatibility.json"
        values = ops.parse_env(self.source / ".env")
        target = "registry.invalid/briani@sha256:" + "0" * 64
        compatibility.write_text(json.dumps({"fromImage": values["BRIANI_IMAGE"], "toImage": target, "compatible": True}))
        before = (self.source / ".env").read_bytes()
        failed = self.cli("upgrade rejects unpinned target", ["upgrade", "--project", str(self.source), "--backup", str(self.backup),
            "--image", target, "--compatibility-file", str(compatibility)], expected=2)
        if (self.source / ".env").read_bytes() != before or not any(message in failed.stderr for message in ("does not match", "must match the audited digest")):
            raise DrillError("failed upgrade altered deployment metadata or did not reject unaudited target")
        self.stop_project(self.source, "stop source before restore")
        for label, project, state, data in (("restore", self.restore, self.restore_state, self.restore_data),
                                             ("rollback", self.rollback, self.rollback_state, self.rollback_data)):
            self.cli(label, [label, "--backup", str(self.backup), "--project", str(project), "--state", str(state), "--data", str(data)])
            self._active_project = project
            self.cli("doctor-" + label, ["doctor", "--project", str(project)])
            self.cli("up-" + label, ["up", "--project", str(project)])
            self.verify_identity_state(project, data, state, label)
            self.verify_managed_qbit(project)
            if label == "rollback":
                self.reset_preferences()
            self.stop_project(project, "stop " + label + " before next project")

    def stop_project(self, project: pathlib.Path, label: str) -> None:
        name = self.project_names[project]
        ids = docker_ids("container", name)
        records = inspect_json("container", ids)
        if any(not is_owned_container(record, name, self.root) for record in records):
            raise DrillError(label + ": refusing to stop a container without matching project labels and drill-owned mounts")
        for container_id in ids:
            result = run_readonly(["docker", "stop", container_id])
            if result.returncode:
                raise DrillError(label + ": exact container stop failed")
        log_line(f"cleanup {label}: stopped {len(ids)} exact project-owned container(s)")

    def verify_managed_qbit(self, project: pathlib.Path) -> None:
        self._active_project = project
        self.expected_settings = {"max_connec":113,"max_connec_per_torrent":17,"max_active_downloads":3,"max_active_uploads":2}
        ops.compose(project, ["up", "-d", "qbittorrent"], admin=True, capture=True)
        wait_until("restored qBittorrent preferences", self.verify_qbit_settings, timeout=90)

    def reset_preferences(self) -> None:
        token = self.login(self.creds["adminUsername"], self.creds["adminPassword"], "rollback admin login for reset")
        prefs = self.api_client.request("GET", "/api/v1/me/preferences", token=token, label="read saved discovery views before reset")
        reset = self.api_client.request("POST", "/api/v1/me/preferences/reset", {"version": prefs["version"]},
            token=token, expected=(200,), label="reset user preferences")
        if reset.get("theme") != "system" or reset.get("discoveryViews") != []:
            raise DrillError("preference reset did not restore defaults")
        persisted = self.api_client.request("GET", "/api/v1/me/preferences", token=token, label="read preferences after reset")
        if persisted.get("theme") != "system" or persisted.get("discoveryViews") != []:
            raise DrillError("preference defaults did not persist after reset")

    def cleanup(self) -> None:
        all_containers: dict[str, dict[str, Any]] = {}
        for project in self.projects:
            name = self.project_names[project]
            ids = docker_ids("container", name)
            records = inspect_json("container", ids)
            for record in records:
                container_id = record.get("Id", "")
                if not is_owned_container(record, name, self.root):
                    raise DrillError("cleanup refused a container whose ownership labels or bind mounts did not match this drill")
                all_containers[container_id] = record
        for container_id, record in all_containers.items():
            if record.get("State", {}).get("Running"):
                result = run_readonly(["docker", "stop", container_id])
                if result.returncode:
                    raise DrillError("cleanup could not stop an exact owned container")
            result = run_readonly(["docker", "rm", container_id])
            if result.returncode:
                raise DrillError("cleanup could not remove an exact owned container")
        removed_containers = set(all_containers)
        for project_name in self.project_names.values():
            for network_id in docker_ids("network", project_name):
                record = inspect_json("network", [network_id])[0]
                if resource_labels(record).get("com.docker.compose.project") != project_name:
                    raise DrillError("cleanup refused a network with an unexpected Compose project label")
                endpoints = record.get("Containers") or {}
                if any(endpoint_id not in removed_containers for endpoint_id in endpoints):
                    raise DrillError("cleanup refused a network attached to a non-drill container")
                result = run_readonly(["docker", "network", "rm", network_id])
                if result.returncode:
                    raise DrillError("cleanup could not remove an exact empty owned network")
            for volume_id in docker_ids("volume", project_name):
                record = inspect_json("volume", [volume_id])[0]
                if resource_labels(record).get("com.docker.compose.project") != project_name:
                    raise DrillError("cleanup refused a volume with an unexpected Compose project label")
                result = run_readonly(["docker", "volume", "rm", volume_id])
                if result.returncode:
                    raise DrillError("cleanup could not remove an exact owned volume")
        if not self.keep:
            if not self.root.is_dir() or self.root.is_symlink() or self.root.parent != pathlib.Path("/tmp"):
                raise DrillError("cleanup refused to remove an unexpected drill root")
            shutil.rmtree(self.root)
            log_line("cleanup drill-owned state/data/backup/project files: removed")
        else:
            log_line(f"cleanup resources removed; protected drill files retained at {self.root}")

    def run(self) -> None:
        self.preflight()
        self.root.mkdir(mode=0o700)
        try:
            self.start_source()
            self.bootstrap_and_admin()
            self.create_library_grant()
            qbit, prowlarr = self.check_integrations()
            self._qbit_secret, self._prowlarr_secret = qbit, prowlarr
            self.update_admin_settings()
            self.update_user_preferences()
            self._active_project = self.source
            self.backup_restore_rollback()
            log_line("DRILL_RESULT=PASS")
        except BaseException:
            self.failed = True
            if self.retain_on_failure:
                log_line(f"DRILL_RESOURCES_RETAINED root={self.root} projects={','.join(self.project_names.values())}")
            raise
        finally:
            if not (self.failed and self.retain_on_failure):
                self.cleanup()


def main(argv: list[str] | None = None) -> int:
    global LOG_PATH
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", action="store_true", help="retain private generated state after exact container/network cleanup")
    parser.add_argument("--retain-on-failure", action="store_true", help="retain isolated state and exact project resources on failure for diagnosis")
    parser.add_argument("--log-file", type=pathlib.Path, help="write the sanitized command/status log to a new mode-0600 file")
    args = parser.parse_args(argv)
    if args.log_file is not None:
        target = args.log_file.expanduser()
        if not target.is_absolute() or target.exists() or target.is_symlink() or not target.parent.is_dir():
            print("DRILL_RESULT=FAIL reason=invalid-log-path", file=sys.stderr)
            return 2
        try:
            fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            os.close(fd)
        except OSError:
            print("DRILL_RESULT=FAIL reason=log-path-unavailable", file=sys.stderr)
            return 2
        LOG_PATH = target
    ident = secrets.token_hex(8)
    root = pathlib.Path(tempfile.gettempdir()) / f"briani-m09-integrated-{ident}"
    drill = IntegratedDrill(root, keep=args.keep, retain_on_failure=args.retain_on_failure)
    try:
        drill.run()
        return 0
    except (DrillError, ops.OpsError, OSError, ValueError, KeyError, sqlite3.Error) as error:
        log_line(f"DRILL_RESULT=FAIL reason={type(error).__name__}: {str(error)[:240]}")
        try:
            if root.exists() and not (drill.failed and drill.retain_on_failure):
                drill.cleanup()
        except Exception as cleanup_error:
            log_line(f"DRILL_CLEANUP=REVIEW_REQUIRED reason={type(cleanup_error).__name__}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
