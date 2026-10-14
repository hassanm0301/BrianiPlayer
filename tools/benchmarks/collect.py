#!/usr/bin/env python3
"""Bounded, read-only Docker/API benchmark collector for an explicitly isolated Compose stack."""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import os
import platform
import stat
import re
import statistics
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


class CollectionError(RuntimeError):
    pass


def run_docker(args: list[str], runner=subprocess.run):
    try:
        result = runner(["docker", *args], check=True, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError) as exc:
        raise CollectionError(f"Docker command failed: docker {' '.join(args[:2])}: {exc}") from exc
    return result.stdout


def inspect_container_details(project: str, ids: list[str], runner=subprocess.run) -> dict[str, dict[str, str]]:
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}", project):
        raise CollectionError("invalid Compose project name")
    if len(ids) != len(set(ids)) or not ids:
        raise CollectionError("provide unique explicit container IDs")
    for cid in ids:
        if not re.fullmatch(r"[a-fA-F0-9]{12,64}", cid):
            raise CollectionError("container IDs must be explicit hexadecimal Docker IDs")
    raw = run_docker(["inspect", *ids], runner)
    try:
        entries = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise CollectionError("docker inspect returned invalid JSON") from exc
    if len(entries) != len(ids):
        raise CollectionError("inspect did not return every requested container")
    details = {}
    for item in entries:
        labels = item.get("Config", {}).get("Labels") or {}
        actual_project = labels.get("com.docker.compose.project")
        service = labels.get("com.docker.compose.service")
        if (actual_project != project or service not in {"briani", "qbittorrent", "prowlarr", "torrent-egress-guard"}
                or labels.get("org.brianiplayer.fixture") != "true"):
            raise CollectionError(f"container {item.get('Id', '?')[:12]} lacks required fixture Compose labels")
        if item.get("State", {}).get("Status") != "running":
            raise CollectionError(f"container {item.get('Id', '?')[:12]} is not running")
        details[item.get("Id", "")[:12]] = {"name": item.get("Name", "").lstrip("/"), "service": service}
    if not {"briani", "qbittorrent", "prowlarr"}.issubset(x["service"] for x in details.values()):
        raise CollectionError("explicit IDs must cover briani, qbittorrent and prowlarr")
    return details


def verify_containers(project: str, ids: list[str], runner=subprocess.run) -> dict[str, str]:
    return {item["name"]: item["service"] for item in inspect_container_details(project, ids, runner).values()}


def read_hardware(storage: Path) -> dict:
    model = "unknown"
    for candidate in (Path("/proc/device-tree/model"), Path("/sys/firmware/devicetree/base/model")):
        try:
            model = candidate.read_bytes().rstrip(b"\0").decode(errors="replace")
            break
        except OSError:
            pass
    cpu = ""
    try:
        for line in Path("/proc/cpuinfo").read_text(errors="replace").splitlines():
            if line.lower().startswith(("model name", "hardware", "model")):
                cpu = line.split(":", 1)[-1].strip()
                if cpu:
                    break
    except OSError:
        pass
    mem_total = None
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemTotal:"):
                mem_total = int(line.split()[1]) * 1024
    except (OSError, ValueError):
        pass
    temps = []
    for p in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
        try:
            temps.append(int(p.read_text().strip()) / 1000)
        except (OSError, ValueError):
            pass
    interfaces = []
    for iface in Path("/sys/class/net").iterdir() if Path("/sys/class/net").exists() else []:
        if iface.name == "lo":
            continue
        def read_attr(name):
            try: return (iface / name).read_text().strip()
            except OSError: return "unknown"
        speed = read_attr("speed")
        interfaces.append({"name": iface.name, "carrier": read_attr("carrier"),
                           "speedMbps": speed if speed.isdigit() else "unknown"})
    return {"model": model, "cpu": cpu, "architecture": platform.machine(),
            "os": platform.platform(), "kernel": platform.release(), "ramBytes": mem_total,
            "thermalZoneC": temps, "cooling": "operator_record_required",
            "storagePath": str(storage.resolve()), "storageDevice": _device_for(storage),
            "networkInterfaces": interfaces,
            "nativePi5Identified": "Raspberry Pi 5" in model}


def _device_for(path: Path) -> str:
    try:
        resolved = path.resolve()
        lines = Path("/proc/mounts").read_text().splitlines()
        matches = []
        for line in lines:
            fields = line.split()
            mount = Path(fields[1].replace("\\040", " "))
            if str(resolved) == str(mount) or str(resolved).startswith(str(mount).rstrip("/") + "/"):
                matches.append((len(str(mount)), fields[0], fields[1], fields[2]))
        if matches:
            _, device, mount, fs = max(matches)
            return f"{device} mounted at {mount} ({fs})"
    except OSError:
        pass
    return "unknown"


def load_credentials(path: Path | None) -> dict[str, str]:
    if path is None:
        return {}
    try:
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_size > 16384:
            raise CollectionError("credential file must be a bounded regular file, not a symlink")
        mode = info.st_mode & 0o777
        if mode & 0o077:
            raise CollectionError("credential file must have mode 0600 or stricter")
        value = json.loads(path.read_text())
    except CollectionError:
        raise
    except (OSError, json.JSONDecodeError) as exc:
        raise CollectionError(f"cannot read credential file: {exc}") from exc
    if not isinstance(value, dict) or any(not isinstance(k, str) or not isinstance(v, str) for k, v in value.items()):
        raise CollectionError("credential file must be a JSON string-to-string object")
    return value


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, url):
        return None


def _opener():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

def request(url: str, headers: dict[str, str], timeout: float = 5) -> tuple[int, bytes]:
    req = urllib.request.Request(url, headers=headers)
    try:
        with _opener().open(req, timeout=timeout) as response:
            return response.status, response.read(1048577)
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(4096)
    except (OSError, TimeoutError) as exc:
        raise CollectionError(f"fixture API request failed for {url}: {exc}") from exc


def stream_fixture(url: str, headers: dict[str, str], timeout: float = 60, limit: int = 8 * 1024**3) -> tuple[int, int, str, float]:
    req = urllib.request.Request(url, headers=headers)
    started = time.monotonic()
    digest = hashlib.sha256()
    size = 0
    try:
        with _opener().open(req, timeout=timeout) as response:
            while True:
                block = response.read(1024 * 1024)
                if not block:
                    return response.status, size, digest.hexdigest(), time.monotonic() - started
                size += len(block)
                if size > limit:
                    raise CollectionError("fixture response exceeded the 8 GiB collector cap")
                digest.update(block)
    except urllib.error.HTTPError as exc:
        return exc.code, 0, "", time.monotonic() - started
    except (OSError, TimeoutError) as exc:
        raise CollectionError(f"fixture transfer failed for {url}: {exc}") from exc


def percentile95(values: list[float]) -> float:
    if not values:
        raise CollectionError("no latency samples collected")
    return sorted(values)[min(len(values) - 1, int(0.95 * len(values)))]


def _stats(ids: list[str], runner=subprocess.run) -> dict[str, dict[str, float]]:
    raw = run_docker(["stats", "--no-stream", "--format", "{{json .}}", *ids], runner)
    parsed = {}
    for line in raw.splitlines():
        try:
            row = json.loads(line)
            name = row.get("Name")
            cpu = float(row["CPUPerc"].rstrip("%"))
            mem = row["MemUsage"].split(" / ", 1)[0].strip()
            multiplier = {"b": 1, "kib": 1024, "mib": 1024**2, "gib": 1024**3}
            match = re.fullmatch(r"([0-9.]+)\s*(B|KiB|MiB|GiB)", mem, re.I)
            if not match:
                raise ValueError("unrecognized memory unit")
            rss = float(match.group(1)) * multiplier[match.group(2).lower()]
            parsed[name] = {"cpuPercent": cpu, "memoryBytes": rss}
        except (ValueError, KeyError, json.JSONDecodeError) as exc:
            raise CollectionError(f"cannot parse Docker stats line: {exc}") from exc
    if len(parsed) != len(ids):
        raise CollectionError("Docker stats did not return all explicit container IDs")
    return parsed


def _process_rss(ids: list[str], runner=subprocess.run) -> dict[str, int]:
    """Sum host-visible per-process RSS (KiB from docker top); page cache is excluded."""
    result = {}
    for cid in ids:
        raw = run_docker(["top", cid, "-eo", "pid=,rss="], runner)
        total_kib = 0
        count = 0
        for line in raw.splitlines():
            fields = line.split()
            if not fields: continue
            if len(fields) != 2 or not fields[0].isdigit() or not fields[1].isdigit():
                raise CollectionError("cannot parse explicit-container docker top PID/RSS output")
            total_kib += int(fields[1])
            count += 1
        if count == 0:
            raise CollectionError(f"docker top returned no processes for explicit container {cid[:12]}")
        result[cid[:12]] = total_kib * 1024
    return result


def _memory_limit_support(runner=subprocess.run):
    raw = run_docker(["info", "--format", "{{json .}}"], runner)
    try:
        info = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise CollectionError("docker info returned invalid JSON while reading memory-limit support") from exc
    value = info.get("MemoryLimit")
    if isinstance(value, bool): return value
    return None


def collect(args, runner=subprocess.run, clock=time.monotonic, sleeper=time.sleep) -> dict:
    if args.duration < 1 or args.duration > 1800:
        raise CollectionError("sampling duration must be between 1 and 1800 seconds (30 minute maximum)")
    if not args.api_url.startswith("http://") and not args.api_url.startswith("https://"):
        raise CollectionError("API URL must use HTTP(S)")
    from urllib.parse import urlsplit
    api = urlsplit(args.api_url)
    host = (api.hostname or "").lower()
    try:
        is_loopback = ipaddress.ip_address(host).is_loopback
    except ValueError:
        is_loopback = host == "localhost"
    if not is_loopback or api.username or api.password or api.query or api.fragment:
        raise CollectionError("API origin must be loopback without embedded credentials, query or fragment")
    details = inspect_container_details(args.project, args.container_id, runner)
    services = {item["name"]: item["service"] for item in details.values()}
    headers = {"Accept": "application/json"}
    credentials = load_credentials(args.credentials)
    if "bearer" in credentials:
        headers["Authorization"] = "Bearer " + credentials["bearer"]
    for key, value in credentials.items():
        if key.startswith("header:"):
            headers[key[7:]] = value
    api_samples = []
    for _ in range(args.api_samples):
        started = clock()
        status, _ = request(args.api_url.rstrip("/") + args.api_path, headers)
        if status != 200:
            raise CollectionError(f"fixture API returned HTTP {status}")
        api_samples.append((clock() - started) * 1000)
    throughput = None
    if args.fixture_url:
        base = urlsplit(args.api_url)
        fixture = urlsplit(args.fixture_url)
        if (fixture.scheme, fixture.netloc) != (base.scheme, base.netloc) or not fixture.path.startswith("/api/v1/") or fixture.query or fixture.fragment:
            raise CollectionError("fixture URL must be an explicit /api/v1/ endpoint on the API origin")
        if not args.fixture_sha256 or not re.fullmatch(r"[a-fA-F0-9]{64}", args.fixture_sha256):
            raise CollectionError("fixture URL requires an independent expected SHA-256")
        status, size, digest, elapsed = stream_fixture(args.fixture_url, headers)
        if status != 200 or digest.lower() != args.fixture_sha256.lower():
            raise CollectionError("fixture response failed status or independent SHA-256 check")
        throughput = {"bytes": size, "seconds": elapsed, "mibPerSecond": size / max(elapsed, 1e-9) / 1048576, "sha256": digest}
    samples = []
    deadline = clock() + args.duration
    while True:
        stats = _stats(args.container_id, runner)
        rss = _process_rss(args.container_id, runner)
        for cid, item in details.items():
            if item["name"] not in stats:
                raise CollectionError(f"docker stats omitted explicit container {cid}")
            stats[item["name"]]["processRssBytes"] = rss[cid]
        samples.append({"elapsedSeconds": args.duration - max(0, deadline - clock()), "containers": stats})
        remaining = deadline - clock()
        if remaining <= 0:
            break
        sleeper(min(args.interval, remaining))
    all_services = {}
    for sample in samples:
        for cid, values in sample["containers"].items():
            all_services.setdefault(cid, []).append(values)
    container_rollup = {cid: {"service": services[cid], "sampleCount": len(vals),
                              "cpuPercentMedian": statistics.median(x["cpuPercent"] for x in vals),
                              "dockerWorkingSetBytesMedian": statistics.median(x["memoryBytes"] for x in vals),
                              "dockerWorkingSetBytesMax": max(x["memoryBytes"] for x in vals),
                              "processRssBytesMedian": statistics.median(x["processRssBytes"] for x in vals),
                              "processRssBytesMax": max(x["processRssBytes"] for x in vals)}
                       for cid, vals in all_services.items()}
    memory_limit_support = _memory_limit_support(runner)
    return {"status": "measured", "hardware": read_hardware(args.storage_path),
            "composeProject": args.project, "containers": container_rollup,
            "api": {"url": args.api_url, "path": args.api_path, "samples": len(api_samples),
                    "warmLatencyMsMedian": statistics.median(api_samples), "warmLatencyMsP95": percentile95(api_samples)},
            "fixtureThroughput": throughput, "dockerSamples": samples,
            "sampleDurationSeconds": args.duration,
            "dockerMemoryLimitSupport": memory_limit_support,
            "limitations": ["Docker memory reports working-set usage; it does not establish process RSS or separate reclaimable page cache.",
                            "Summed per-process RSS is a Docker-top observation and may double-count shared pages across processes.",
                            "Cooling, storage model/connection and network link/throughput need operator evidence."]}


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project", required=True, help="exact isolated Compose project label")
    p.add_argument("--container-id", action="append", required=True, help="explicit full Docker container ID; repeat for each service")
    p.add_argument("--api-url", required=True, help="fixture workload API origin")
    p.add_argument("--api-path", default="/healthz", help="bounded warm GET path (default /healthz)")
    p.add_argument("--credentials", type=Path, help="JSON secret file mode 0600: bearer and/or header:Name values")
    p.add_argument("--api-samples", type=int, default=25)
    p.add_argument("--fixture-url", help="explicit authorized fixture download endpoint")
    p.add_argument("--fixture-sha256", help="independently known fixture SHA-256")
    p.add_argument("--storage-path", type=Path, default=Path("/"))
    p.add_argument("--duration", type=int, default=1800, help="Docker stats sampling window; maximum 1800s")
    p.add_argument("--interval", type=float, default=5)
    p.add_argument("--output", type=Path, required=True)
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        if args.api_samples < 1 or args.api_samples > 500 or args.interval < 0.2:
            raise CollectionError("api-samples must be 1..500 and interval at least 0.2s")
        result = collect(args)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n")
        print(f"wrote measurements to {args.output}; nativePi5Identified={result['hardware']['nativePi5Identified']}")
        return 0 if result["hardware"]["nativePi5Identified"] else 3
    except CollectionError as exc:
        print(f"blocked_environment: {exc}", file=sys.stderr)
        return 3
    except (OSError, ValueError) as exc:
        print(f"collector_error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
