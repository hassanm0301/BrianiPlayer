#!/usr/bin/env python3
"""Run a bounded authenticated workload against explicitly configured fixture API URLs."""
from __future__ import annotations

import argparse
import errno
import hashlib
import ipaddress
import os
import json
import math
import re
import stat
import statistics
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import parse_qsl, urljoin, urlsplit
import uuid

MAX_DURATION = 1800
MAX_CONFIG_BYTES = 32768
CHUNK_BYTES = 256 * 1024
ORACLE_HASH_BLOCK = 1024 * 1024


class WorkloadError(RuntimeError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def opener_factory():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())


def load_config(path: Path) -> dict:
    fd = None
    try:
        flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
        fd = os.open(path, flags)
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_CONFIG_BYTES:
            raise WorkloadError("fixture config must be a bounded regular file, not a symlink")
        if info.st_mode & 0o077:
            raise WorkloadError("fixture config must have mode 0600 or stricter")
        chunks = []
        remaining = MAX_CONFIG_BYTES + 1
        while remaining:
            part = os.read(fd, min(remaining, 4096))
            if not part: break
            chunks.append(part); remaining -= len(part)
        data = b"".join(chunks)
        if len(data) > MAX_CONFIG_BYTES:
            raise WorkloadError("fixture config exceeds 32 KiB")
        value = json.loads(data.decode("utf-8", errors="strict"))
    except WorkloadError:
        raise
    except OSError as exc:
        if exc.errno == errno.ELOOP:
            raise WorkloadError("fixture config must be a regular file, not a symlink") from None
        raise WorkloadError(f"cannot read fixture config: {exc}") from exc
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise WorkloadError(f"cannot read fixture config: {exc}") from exc
    finally:
        if fd is not None: os.close(fd)
    if not isinstance(value, dict):
        raise WorkloadError("fixture config must be a JSON object")
    return value


def validate_origin(base_url: str) -> str:
    base = urlsplit(base_url)
    host = (base.hostname or "").lower()
    try:
        loopback = ipaddress.ip_address(host).is_loopback
    except ValueError:
        loopback = host == "localhost"
    if base.scheme not in {"http", "https"} or not loopback or base.username or base.password or base.query or base.fragment:
        raise WorkloadError("baseUrl must be an HTTP(S) loopback origin without embedded credentials/query/fragment")
    if base.path not in {"", "/"}:
        raise WorkloadError("baseUrl must be an origin only")
    return f"{base.scheme}://{base.netloc}"


def resolve_url(origin: str, value: str, allow_folder_query: bool = False) -> str:
    if not isinstance(value, str) or not value:
        raise WorkloadError("every workload URL must be explicitly configured")
    result = urljoin(origin + "/", value)
    parsed = urlsplit(result)
    if (parsed.scheme, parsed.netloc) != (urlsplit(origin).scheme, urlsplit(origin).netloc):
        raise WorkloadError("workload URL must remain on the exact configured API origin")
    if parsed.username or parsed.password or parsed.fragment:
        raise WorkloadError("workload URLs cannot embed credentials or fragments")
    if not parsed.path.startswith("/api/v1/") or any(part == ".." for part in parsed.path.split("/")):
        raise WorkloadError("workload URL must use an explicit /api/v1/ path")
    if parsed.query:
        parts = parsed.path.split("/")
        if not allow_folder_query or len(parts) != 6 or parts[1:3] != ["api", "v1"] or parts[3] != "libraries" or parts[5] != "entries":
            raise WorkloadError("only the explicit folder-list API may have query parameters")
        try:
            uuid.UUID(parts[4])
            pairs = parse_qsl(parsed.query, keep_blank_values=True, strict_parsing=True)
            query = dict(pairs)
            if len(pairs) != 2 or len(query) != 2 or set(query) != {"folderId", "limit"}:
                raise ValueError
            uuid.UUID(query["folderId"])
            if not query["limit"].isdigit() or not 1 <= int(query["limit"]) <= 200:
                raise ValueError
        except (ValueError, UnicodeError):
            raise WorkloadError("folder list query must contain one UUID folderId and one limit from 1 to 200") from None
    return result


def resolve_stream_url(origin: str, value: str) -> str:
    """Validate only the issued, same-origin stream capability URL shape."""
    if not isinstance(value, str) or not value:
        raise WorkloadError("every stream capability URL must be explicitly configured")
    result = urljoin(origin + "/", value)
    parsed = urlsplit(result)
    if (parsed.scheme, parsed.netloc) != (urlsplit(origin).scheme, urlsplit(origin).netloc):
        raise WorkloadError("stream capability must remain on the exact configured API origin")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise WorkloadError("stream capability cannot embed credentials, query strings or fragments")
    parts = parsed.path.split("/")
    if len(parts) != 4 or parts[0] != "" or parts[1] != "stream" or not re.fullmatch(r"[A-Za-z0-9_-]{43}", parts[2]) or not parts[3]:
        raise WorkloadError("stream URL must be an issued /stream/{43-character-ticket}/{encoded-file-name} capability")
    # Exactly two path components after /stream; reject encoded separators and traversal.
    from urllib.parse import unquote
    try:
        filename = unquote(parts[3], errors="strict")
    except UnicodeError:
        raise WorkloadError("stream capability filename has invalid UTF-8 encoding") from None
    if "/" in filename or "\\" in filename or filename in {".", ".."} or any(ord(c) < 32 for c in filename):
        raise WorkloadError("stream capability filename is not a safe encoded component")
    if re.search(r"%(?![0-9A-Fa-f]{2})", parts[3]):
        raise WorkloadError("stream capability filename has malformed percent encoding")
    return result


def _bearer_headers(item: dict) -> dict[str, str]:
    token = item.get("bearer")
    if token is not None and (not isinstance(token, str) or not token or len(token) > 8192):
        raise WorkloadError("bearer token must be a nonempty bounded string")
    result = {"Accept": "application/json, video/*, */*"}
    if token:
        result["Authorization"] = "Bearer " + token
    return result


def _refresh_token(item: dict, where: str) -> str:
    token = item.get("refreshToken")
    if not isinstance(token, str) or not token or len(token) > 8192:
        raise WorkloadError(f"{where} requires its own bounded refreshToken for the full workload window")
    return token


class OracleFixture:
    """Pinned read-only local fixture descriptor, prehashed before the workload."""
    def __init__(self, path_value: str, expected_size: int, expected_sha256: str):
        self.path = Path(path_value)
        self.fd = None
        try:
            if not self.path.is_absolute():
                raise WorkloadError("oracleFile must be an absolute local fixture path")
            before = self.path.lstat()
            if not stat.S_ISREG(before.st_mode):
                raise WorkloadError("oracleFile must be a regular file, not a symlink")
            flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
            self.fd = os.open(self.path, flags)
            opened = os.fstat(self.fd)
            if not stat.S_ISREG(opened.st_mode) or (before.st_dev, before.st_ino) != (opened.st_dev, opened.st_ino):
                raise WorkloadError("oracleFile identity changed while opening; refusing it")
            if opened.st_size != expected_size:
                raise WorkloadError("oracleFile size does not match configured fixture bytes")
            self.identity = self._identity(opened)
            digest = hashlib.sha256()
            offset = 0
            while offset < expected_size:
                block = os.pread(self.fd, min(ORACLE_HASH_BLOCK, expected_size - offset), offset)
                if not block:
                    raise WorkloadError("oracleFile ended before configured fixture size")
                digest.update(block)
                offset += len(block)
            self._check_current()
            if digest.hexdigest() != expected_sha256.lower():
                raise WorkloadError("oracleFile SHA-256 does not match configured independent hash")
            self.sha256 = digest.hexdigest()
            self.size = expected_size
        except Exception:
            self.close()
            raise

    @staticmethod
    def _identity(info):
        return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)

    def _check_current(self):
        if self.fd is None:
            raise WorkloadError("oracleFile descriptor is closed")
        try:
            current_path = self.path.lstat()
            current_fd = os.fstat(self.fd)
        except OSError:
            raise WorkloadError("oracleFile path or descriptor changed during workload") from None
        if (not stat.S_ISREG(current_path.st_mode) or self._identity(current_path) != self.identity
                or self._identity(current_fd) != self.identity):
            raise WorkloadError("oracleFile identity or content metadata changed during workload")

    def read(self, offset: int, length: int) -> bytes:
        self._check_current()
        try:
            data = os.pread(self.fd, length, offset)
        except OSError:
            raise WorkloadError("oracleFile read failed") from None
        if len(data) != length:
            raise WorkloadError("oracleFile range was shorter than requested")
        return data

    def close(self):
        fd, self.fd = self.fd, None
        if fd is not None:
            try: os.close(fd)
            except OSError: pass


def validate_config(config: dict) -> dict:
    origin = validate_origin(config.get("baseUrl", ""))
    folder_users = config.get("folderUsers")
    completed = config.get("completedStreams")
    progressive = config.get("progressiveStream")
    if not isinstance(folder_users, list) or len(folder_users) != 5:
        raise WorkloadError("fixture config requires exactly five authenticated folderUsers")
    if not isinstance(completed, list) or len(completed) != 2:
        raise WorkloadError("fixture config requires exactly two completedStreams")
    if not isinstance(progressive, dict):
        raise WorkloadError("progressive fixture input missing; no progressive acceptance can be reported")
    users = []
    for i, item in enumerate(folder_users):
        if not isinstance(item, dict) or not item.get("bearer"):
            raise WorkloadError(f"folderUsers[{i}] requires its own bearer token")
        refresh = _refresh_token(item, f"folderUsers[{i}]")
        users.append({"name": str(item.get("name", f"user-{i+1}"))[:64],
                      "url": resolve_url(origin, item.get("url"), allow_folder_query=True), "headers": _bearer_headers(item),
                      "refreshToken": refresh, "authLock": threading.RLock()})
    if len({item["headers"]["Authorization"] for item in users}) != 5:
        raise WorkloadError("folderUsers must carry five distinct user credentials")
    def stream_item(item: dict, where: str) -> dict:
        if not isinstance(item, dict):
            raise WorkloadError(f"{where} must be an object")
        if not item.get("bearer"):
            raise WorkloadError(f"{where} requires its own bearer token")
        refresh = _refresh_token(item, where)
        session_id = item.get("playbackSessionId")
        if not isinstance(session_id, str) or not re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}", session_id):
            raise WorkloadError(f"{where}.playbackSessionId must be the owning playback session UUID")
        generation = item.get("generation")
        if not isinstance(generation, str) or not generation or len(generation) > 256:
            raise WorkloadError(f"{where}.generation must be the expected playback target generation")
        size = item.get("bytes")
        digest = item.get("sha256")
        rate = item.get("targetMbitPerSecond", 25 if where.startswith("completed") else 15)
        if not isinstance(size, int) or size <= 0 or size > 8 * 1024**3:
            raise WorkloadError(f"{where}.bytes must be 1..8 GiB")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
            raise WorkloadError(f"{where}.sha256 must be an independent 64-digit SHA-256")
        if not isinstance(rate, (int, float)) or not math.isfinite(rate) or rate <= 0 or rate > 100:
            raise WorkloadError(f"{where}.targetMbitPerSecond must be in (0,100]")
        oracle_path = item.get("oracleFile")
        if oracle_path is not None and (not isinstance(oracle_path, str) or not oracle_path or len(oracle_path) > 4096):
            raise WorkloadError(f"{where}.oracleFile must be an absolute local fixture path")
        return {"url": resolve_stream_url(origin, item.get("url")), "bytes": size, "sha256": digest.lower(),
                "targetMbitPerSecond": float(rate), "headers": _bearer_headers(item), "oracleFile": oracle_path,
                "refreshToken": refresh, "playbackSessionId": session_id, "generation": generation,
                "authLock": threading.RLock()}
    completed_streams = [stream_item(item, f"completedStreams[{i}]") for i, item in enumerate(completed)]
    prog = stream_item(progressive, "progressiveStream")
    all_owners = users + completed_streams + [prog]
    if len({item["refreshToken"] for item in all_owners}) != len(all_owners):
        raise WorkloadError("each folder user and stream owner must have a distinct rotating refresh token")
    prog["targetMbitPerSecond"] = float(progressive.get("targetMbitPerSecond", 15))
    status_url = resolve_url(origin, progressive.get("downloadStatusUrl"))
    pointer = progressive.get("downloadRatePointer")
    if not isinstance(pointer, str) or not pointer.startswith("/") or len(pointer) > 256:
        raise WorkloadError("progressiveStream.downloadRatePointer must be an explicit JSON pointer")
    minimum_rate = progressive.get("minimumDownloadBytesPerSecond", 3_125_000)
    if not isinstance(minimum_rate, (int, float)) or minimum_rate <= 0:
        raise WorkloadError("minimum download rate must be positive bytes/second")
    return {"origin": origin, "folderUsers": users, "completedStreams": completed_streams,
            "progressiveStream": prog, "downloadStatusUrl": status_url,
            "downloadRatePointer": pointer, "minimumDownloadBytesPerSecond": float(minimum_rate)}


def _json_pointer(document, pointer: str):
    current = document
    for token in pointer.lstrip("/").split("/"):
        token = token.replace("~1", "/").replace("~0", "~")
        if isinstance(current, list):
            current = current[int(token)]
        else:
            current = current[token]
    return current


class Load:
    def __init__(self, config: dict, duration: int, low_memory_mib: int | None = None,
                 opener=None, clock=time.monotonic, sleeper=time.sleep):
        if not 1 <= duration <= MAX_DURATION:
            raise WorkloadError("workload duration must be 1..1800 seconds")
        self.config = validate_config(config)
        self.duration = duration
        self.low_memory_bytes = low_memory_mib * 1024**2 if low_memory_mib else None
        self.opener = opener or opener_factory()
        self.clock = clock
        self.sleeper = sleeper
        self.stop_event = threading.Event()
        self.lock = threading.Lock()
        self.responses = set()
        self.errors = []
        self.session_status_counts = {}
        self.refresh_count = 0
        self.latencies: list[float] = []
        self.download_rates: list[float] = []
        self.stream_results = {}
        self.started = 0.0
        self.deadline = 0.0
        self.stop_reason = None
        self.oracles = {}
        try:
            for item in self.config["completedStreams"] + [self.config["progressiveStream"]]:
                if item.get("oracleFile"):
                    oracle = OracleFixture(item["oracleFile"], item["bytes"], item["sha256"])
                    self.oracles[id(item)] = oracle
        except Exception:
            self.close()
            raise

    def close(self):
        opened = list(self.oracles.values())
        self.oracles.clear()
        for oracle in opened: oracle.close()

    def cancel(self, reason: str):
        self.stop_reason = reason
        self.stop_event.set()
        with self.lock:
            responses = list(self.responses)
        for response in responses:
            try: response.close()
            except OSError: pass

    def _register(self, response):
        with self.lock: self.responses.add(response)

    def _unregister(self, response):
        with self.lock: self.responses.discard(response)

    def _read_bounded(self, response, limit: int) -> bytes:
        chunks, size = [], 0
        while True:
            block = response.read(min(64 * 1024, limit + 1 - size))
            if not block: return b"".join(chunks)
            size += len(block)
            if size > limit: raise WorkloadError("fixture API response exceeded its bounded body limit")
            chunks.append(block)

    def _open(self, url, headers, timeout=15, method="GET", data=None):
        req = urllib.request.Request(url, headers=headers, data=data, method=method)
        try:
            response = self.opener.open(req, timeout=timeout)
        except urllib.error.HTTPError as exc:
            if 300 <= exc.code < 400:
                raise WorkloadError(f"redirect rejected (HTTP {exc.code})") from None
            raise WorkloadError(f"API returned HTTP {exc.code}") from None
        except (urllib.error.URLError, OSError, TimeoutError) as exc:
            # Do not include exception text: urllib includes the full URL, which may be a ticket.
            raise WorkloadError(f"API transport error ({type(exc).__name__})") from None
        self._register(response)
        return response

    def _json_call(self, url, headers, method, body=None):
        request_headers = dict(headers)
        request_headers["Accept"] = "application/json"
        data = None
        if body is not None:
            request_headers["Content-Type"] = "application/json"
            data = json.dumps(body, separators=(",", ":")).encode("utf-8")
        response = self._open(url, request_headers, timeout=15, method=method, data=data)
        try:
            if response.status not in (200, 201):
                raise WorkloadError(f"credential maintenance returned HTTP {response.status}")
            payload = self._read_bounded(response, 64 * 1024)
            if not payload:
                return None
            value = json.loads(payload)
            if not isinstance(value, dict):
                raise WorkloadError("credential maintenance response was not an object")
            return value
        except (UnicodeError, json.JSONDecodeError):
            raise WorkloadError("credential maintenance returned invalid JSON") from None
        finally:
            self._unregister(response)
            response.close()

    def _refresh_owner(self, item):
        with item["authLock"]:
            payload = self._json_call(self.config["origin"] + "/api/v1/auth/refresh", {}, "POST",
                                      {"refreshToken": item["refreshToken"]})
            if not isinstance(payload, dict) or not isinstance(payload.get("accessToken"), str) or not payload["accessToken"] or not isinstance(payload.get("refreshToken"), str) or not payload["refreshToken"]:
                raise WorkloadError("auth refresh response omitted accessToken or rotated refreshToken")
            item["headers"]["Authorization"] = "Bearer " + payload["accessToken"]
            item["refreshToken"] = payload["refreshToken"]
            self.refresh_count += 1

    def _check_stream_session(self, item):
        with item["authLock"]:
            path = f"/api/v1/playback/sessions/{item['playbackSessionId']}"
            original_url = item["url"]
            payload = self._json_call(self.config["origin"] + path, item["headers"], "GET")
            if not isinstance(payload, dict) or not isinstance(payload.get("id"), str) or payload["id"].lower() != item["playbackSessionId"].lower():
                raise WorkloadError("playback status response did not match its owning session")
            if payload.get("state") not in {"ready", "waitingForData", "buffering", "complete"}:
                raise WorkloadError("playback session is expired, revoked, unavailable, or not active")
            if payload.get("generation") != item["generation"]:
                raise WorkloadError("playback target generation changed during workload")
            if payload.get("streamUrl") is not None:
                status_url = resolve_stream_url(self.config["origin"], payload.get("streamUrl"))
                if status_url != original_url:
                    raise WorkloadError("playback status changed the issued stream capability")
            self.session_status_counts[item["playbackSessionId"]] = self.session_status_counts.get(item["playbackSessionId"], 0) + 1

    def _credential_maintenance(self):
        owners = self.config["folderUsers"] + self.config["completedStreams"] + [self.config["progressiveStream"]]
        streams = self.config["completedStreams"] + [self.config["progressiveStream"]]
        now = self.clock()
        refresh_due = {id(item): now + 480 for item in owners}
        status_due = {id(item): now + 30 for item in streams}
        while not self.stop_event.is_set() and self.clock() < self.deadline:
            now = self.clock()
            try:
                for item in owners:
                    if now >= refresh_due[id(item)]:
                        self._refresh_owner(item)
                        refresh_due[id(item)] = now + 480
                for item in streams:
                    if now >= status_due[id(item)]:
                        self._check_stream_session(item)
                        status_due[id(item)] = now + 30
            except Exception as exc:
                if not self.stop_event.is_set():
                    self.errors.append(f"credential/session maintenance failed: {str(exc) if isinstance(exc, WorkloadError) else type(exc).__name__}")
                    self.cancel("credential/session maintenance failed closed")
                return
            self.stop_event.wait(min(1.0, max(0, self.deadline - self.clock())))

    def _paced_stream(self, name: str, item: dict):
        size = item["bytes"]
        target_bps = item["targetMbitPerSecond"] * 1_000_000 / 8
        total = 0
        cycles = 0
        errors = []
        verified_ranges = 0
        verified_bytes = 0
        oracle = self.oracles.get(id(item))
        next_tick = self.clock()
        while not self.stop_event.is_set() and self.clock() < self.deadline:
            digest = hashlib.sha256()
            offset = 0
            try:
                while offset < size and not self.stop_event.is_set() and self.clock() < self.deadline:
                    end = min(size, offset + CHUNK_BYTES) - 1
                    with item["authLock"]:
                        headers = dict(item["headers"], Range=f"bytes={offset}-{end}")
                        request_url = item["url"]
                    response = self._open(request_url, headers, timeout=45)
                    try:
                        if response.status != 206:
                            raise WorkloadError(f"{name} returned HTTP {response.status} for byte range")
                        content_range = response.headers.get("Content-Range", "")
                        if content_range != f"bytes {offset}-{end}/{size}":
                            raise WorkloadError(f"{name} returned a mismatched Content-Range")
                        expected = end - offset + 1
                        chunk = response.read(expected + 1)
                        if len(chunk) != expected:
                            raise WorkloadError(f"{name} returned {len(chunk)} bytes for a {expected}-byte range")
                        if oracle is not None:
                            oracle_bytes = oracle.read(offset, expected)
                            if chunk != oracle_bytes:
                                raise WorkloadError(f"{name} independent byte oracle mismatch at offset {offset}")
                            verified_ranges += 1
                            verified_bytes += expected
                        digest.update(chunk)
                    finally:
                        self._unregister(response)
                        response.close()
                    offset += expected
                    total += len(chunk)
                    next_tick += len(chunk) / target_bps
                    while not self.stop_event.is_set() and self.clock() < self.deadline and self.clock() < next_tick:
                        remaining_to_tick = next_tick - self.clock()
                        remaining_window = self.deadline - self.clock()
                        self.sleeper(max(0, min(0.05, remaining_to_tick, remaining_window)))
                if self.stop_event.is_set() or offset < size:
                    break
                actual = digest.hexdigest()
                if actual != item["sha256"]:
                    raise WorkloadError(f"{name} independent SHA-256 mismatch")
                cycles += 1
            except Exception as exc:
                if not self.stop_event.is_set():
                    message = str(exc) if isinstance(exc, WorkloadError) else f"transport error ({type(exc).__name__})"
                    errors.append(message)
                    self.errors.append(f"{name}: {message}")
                break
        elapsed = max(self.clock() - self.started, 1e-9)
        self.stream_results[name] = {"bytesReceived": total, "verifiedCompleteCycles": cycles,
            "targetMbitPerSecond": item["targetMbitPerSecond"],
            "observedAverageMbitPerSecond": total * 8 / elapsed / 1_000_000,
            "oracleSha256": item["sha256"], "errors": errors,
            "oraclePass": (cycles > 0 or (oracle is not None and verified_ranges > 0)) and not errors,
            "independentRangeOracle": oracle is not None,
            "verifiedRanges": verified_ranges, "oracleVerifiedBytes": verified_bytes,
            "oraclePreverified": oracle is not None,
            "rateTargetMet": total * 8 / elapsed / 1_000_000 >= item["targetMbitPerSecond"] * 0.95}

    def _folder_user(self, item):
        index = 0
        while not self.stop_event.is_set() and self.clock() < self.deadline:
            started = self.clock()
            try:
                with item["authLock"]: headers = dict(item["headers"])
                response = self._open(item["url"], headers)
                try:
                    if response.status != 200:
                        raise WorkloadError(f"folder API returned HTTP {response.status}")
                    self._read_bounded(response, 2 * 1024 * 1024)
                finally:
                    self._unregister(response)
                    response.close()
                self.latencies.append((self.clock() - started) * 1000)
            except Exception as exc:
                if not self.stop_event.is_set():
                    detail = str(exc) if isinstance(exc, WorkloadError) else type(exc).__name__
                    self.errors.append(f"folder {item['name']}: {detail}")
            index += 1
            # One request/user/second bounds load while preserving five-user concurrency.
            wake = started + 1.0
            while not self.stop_event.is_set() and self.clock() < min(wake, self.deadline):
                self.sleeper(max(0, min(0.05, min(wake, self.deadline) - self.clock())))

    def _download_monitor(self):
        item = self.config["progressiveStream"]
        while not self.stop_event.is_set() and self.clock() < self.deadline:
            try:
                with item["authLock"]: headers = dict(item["headers"])
                response = self._open(self.config["downloadStatusUrl"], headers)
                try:
                    if response.status != 200: raise WorkloadError(f"download status API returned HTTP {response.status}")
                    payload = json.loads(self._read_bounded(response, 256 * 1024))
                    value = float(_json_pointer(payload, self.config["downloadRatePointer"]))
                    if value < 0 or not math.isfinite(value): raise ValueError("download rate was invalid")
                    self.download_rates.append(value)
                finally:
                    self._unregister(response)
                    response.close()
            except Exception as exc:
                if not self.stop_event.is_set():
                    detail = str(exc) if isinstance(exc, WorkloadError) else type(exc).__name__
                    self.errors.append(f"progressive download monitor: {detail}")
            self.sleeper(max(0, min(5, self.deadline - self.clock())))

    def _memory_guard(self):
        if self.low_memory_bytes is None:
            return None
        try:
            for line in Path("/proc/meminfo").read_text().splitlines():
                if line.startswith("MemAvailable:"):
                    available = int(line.split()[1]) * 1024
                    if available < self.low_memory_bytes:
                        self.cancel("host MemAvailable crossed configured low-memory threshold")
                        return available
                    return available
        except (OSError, ValueError):
            self.errors.append("optional low-memory guard unavailable: /proc/meminfo unreadable")
        return None

    def run(self) -> dict:
        self.started = self.clock()
        self.deadline = self.started + self.duration
        threads = []
        for name, item in [(f"completed-{i+1}", x) for i, x in enumerate(self.config["completedStreams"])] + [("progressive", self.config["progressiveStream"])]:
            thread = threading.Thread(target=self._paced_stream, args=(name, item), daemon=True)
            threads.append(thread)
        for item in self.config["folderUsers"]:
            threads.append(threading.Thread(target=self._folder_user, args=(item,), daemon=True))
        threads.append(threading.Thread(target=self._download_monitor, daemon=True))
        threads.append(threading.Thread(target=self._credential_maintenance, daemon=True))
        for thread in threads: thread.start()
        memory_available = None
        while self.clock() < self.deadline and any(t.is_alive() for t in threads):
            self.sleeper(0.25)
            value = self._memory_guard()
            if value is not None: memory_available = value
            if self.stop_event.is_set(): break
        elapsed = min(self.duration, max(0, self.clock() - self.started))
        self.cancel(self.stop_reason or "duration elapsed")
        for thread in threads: thread.join(timeout=2)
        stream_complete = all(self.stream_results.get(name, {}).get("oraclePass") for name in ("completed-1", "completed-2", "progressive"))
        min_rate = self.config["minimumDownloadBytesPerSecond"]
        rate_met = bool(self.download_rates) and statistics.median(self.download_rates) >= min_rate
        stream_rates_met = len(self.stream_results) == 3 and all(x.get("rateTargetMet", False) for x in self.stream_results.values())
        session_status_complete = all(self.session_status_counts.get(item["playbackSessionId"], 0) > 0
                                      for item in self.config["completedStreams"] + [self.config["progressiveStream"]])
        folder_p95 = percentile95(self.latencies)
        memory_guard_clear = not (self.low_memory_bytes is not None and self.stop_reason and "low-memory" in self.stop_reason)
        full_window = elapsed >= self.duration * 0.95
        result = {"status": "measured", "durationSeconds": elapsed, "stopReason": self.stop_reason,
                "workloadInputsComplete": True, "streams": self.stream_results,
                "fiveUserFolderApi": {"users": len(self.config["folderUsers"]), "requests": len(self.latencies),
                    "medianMs": statistics.median(self.latencies) if self.latencies else None,
                    "p95Ms": folder_p95, "targetP95Ms": 250, "targetMet": folder_p95 is not None and folder_p95 < 250},
                "progressiveDownloadRate": {"samples": len(self.download_rates), "medianBytesPerSecond": statistics.median(self.download_rates) if self.download_rates else None,
                    "minimumBytesPerSecond": min_rate, "targetMet": rate_met},
                "playbackSessionStatus": {"checksBySession": dict(self.session_status_counts),
                    "allThreeSessionsChecked": session_status_complete, "refreshRotations": self.refresh_count},
                "hostMemoryGuard": {"enabled": self.low_memory_bytes is not None, "thresholdBytes": self.low_memory_bytes,
                    "lastAvailableBytes": memory_available, "tripped": not memory_guard_clear},
                "errors": self.errors,
                "acceptanceSignals": {"allThreeByteOraclesPassed": stream_complete,
                    "allStreamRateTargetsMet": stream_rates_met,
                    "folderApiSamplesPresent": bool(self.latencies), "folderApiP95TargetMet": folder_p95 is not None and folder_p95 < 250,
                    "progressiveRateSamplesPresent": bool(self.download_rates),
                    "minimumDownloadRateMet": rate_met,
                    "allThreePlaybackSessionsStatusChecked": session_status_complete,
                    "fullWindowCompleted": full_window, "memoryGuardNotTripped": memory_guard_clear}}
        self.close()
        return result


def percentile95(values):
    if not values: return None
    return sorted(values)[min(len(values) - 1, math.ceil(0.95 * len(values)) - 1)]


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", required=True, type=Path, help="mode-0600 explicit fixture workload JSON")
    p.add_argument("--duration", type=int, default=1800)
    p.add_argument("--low-memory-mib", type=int, help="optional host MemAvailable trip threshold")
    p.add_argument("--output", required=True, type=Path)
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if not 1 <= args.duration <= MAX_DURATION: raise WorkloadError("duration must be 1..1800 seconds")
        if args.low_memory_mib is not None and args.low_memory_mib < 64: raise WorkloadError("low-memory threshold must be at least 64 MiB")
        result = Load(load_config(args.config), args.duration, args.low_memory_mib).run()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        signals = result["acceptanceSignals"]
        ready = all(signals.values()) and not result["errors"]
        print(f"wrote workload evidence to {args.output}; acceptanceSignals={json.dumps(signals, sort_keys=True)}")
        return 0 if ready else 3
    except WorkloadError as exc:
        print(f"blocked_environment: {exc}", file=sys.stderr)
        return 3
    except (OSError, ValueError) as exc:
        print(f"workload_error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__": raise SystemExit(main())
