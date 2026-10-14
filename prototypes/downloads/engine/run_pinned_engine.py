#!/usr/bin/env python3
"""Run the M05 adapter smoke test against a new, isolated locked qBittorrent container."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
IMAGE = "lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed"
TEMP_PASSWORD = re.compile(r"temporary password is provided for this session:\s*(\S+)", re.I)


def run(args: list[str], *, capture: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, check=False, text=True, stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.PIPE if capture else None)
    if result.returncode:
        detail = (result.stderr or "").strip()[-1000:]
        raise RuntimeError(f"command failed ({result.returncode}): {args[0]} {args[1]}: {detail}")
    return result


def inspect_labels(name: str, expected: dict[str, str]) -> bool:
    value = json.loads(run(["docker", "inspect", name]).stdout)[0]
    found = value.get("Config", {}).get("Labels") or value.get("Labels") or {}
    return all(found.get(k) == v for k, v in expected.items())


def wait_host_api(host: str) -> str:
    deadline = time.monotonic() + 20
    last = "unreachable"
    while time.monotonic() < deadline:
        try:
            with socket.create_connection((host, 8080), timeout=1) as stream:
                stream.sendall(f"GET /api/v2/app/version HTTP/1.1\r\nHost: {host}:8080\r\nConnection: close\r\n\r\n".encode())
                last = stream.recv(256).split(b"\r\n", 1)[0].decode("ascii", "replace")
                if last.startswith("HTTP/"):
                    return last
        except OSError:
            pass
        time.sleep(.2)
    return last


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=Path("/tmp") / f"briani-m05-qbit-{uuid.uuid4().hex[:12]}.log")
    parser.add_argument("--fixture-root", type=Path, default=Path(os.environ.get("BRIANI_DOWNLOAD_FIXTURE_ROOT", ROOT / "prototypes/playback/fixtures/generated")))
    parser.add_argument("--single-torrent", type=Path, default=Path(os.environ["BRIANI_DOWNLOAD_SINGLE_TORRENT"]) if os.environ.get("BRIANI_DOWNLOAD_SINGLE_TORRENT") else None)
    args = parser.parse_args()

    run_id = uuid.uuid4().hex
    network = f"briani-m05-{run_id[:12]}"
    container = f"briani-m05-qbit-{run_id[:12]}"
    labels = {"org.briani.test": "M05", "org.briani.run": run_id}
    state = Path(tempfile.mkdtemp(prefix=f"briani-m05-{run_id[:8]}-"))
    (state / "config").mkdir()
    (state / "config").chmod(0o700)
    data = state / "data"
    data.mkdir()
    library = str(uuid.uuid4())
    (data / library / ".briani" / "staging").mkdir(parents=True)
    fixture_root = args.fixture_root.resolve()
    if args.single_torrent is not None:
        fixture = args.single_torrent.expanduser()
        if not fixture.is_absolute() and not fixture.is_file():
            fixture = fixture_root / fixture
    else:
        fixture = ROOT / "prototypes/playback/artifacts/metadata-consent.torrent"
        alternate = fixture_root / "early-play/torrents/Fast-start-v1.torrent"
        if not fixture.is_file() and alternate.is_file():
            fixture = alternate
    if not fixture.is_file() or fixture.stat().st_size > 16 * 1024 * 1024:
        output = {"result": "failed", "failure": "FixtureMissingOrOversized",
                  "fixtureRoot": str(fixture_root), "fixture": str(fixture),
                  "log": str(args.log)}
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.log.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "failed", "failure": output["failure"], "log": str(args.log)}))
        return 1
    fixture = fixture.resolve()

    output: dict[str, object] = {"runId": run_id, "image": IMAGE, "networkIsolation": "internal Docker bridge", "fixtureRoot": str(fixture_root), "fixture": str(fixture.resolve()), "result": "running"}
    try:
        run(["docker", "network", "create", "--internal", "--label", "org.briani.test=M05",
             "--label", f"org.briani.run={run_id}", network])
        run(["docker", "run", "--detach", "--name", container, "--network", network,
             "--label", "org.briani.test=M05", "--label", f"org.briani.run={run_id}",
             "-e", f"PUID={os.getuid()}", "-e", f"PGID={os.getgid()}", "-e", "WEBUI_PORT=8080", "-e", "TORRENTING_PORT=6881",
             "-v", f"{state / 'config'}:/config", "-v", f"{data}:/data", IMAGE])

        password = None
        ready = False
        for _ in range(60):
            log_result = run(["docker", "logs", container])
            logs = log_result.stdout + log_result.stderr
            match = TEMP_PASSWORD.search(logs)
            if match:
                password = match.group(1)
            ready = "Connection to localhost (::1) 8080 port [tcp/http-alt] succeeded!" in logs
            if password and ready:
                break
            time.sleep(1)
        if not password or not ready:
            info = json.loads(run(["docker", "inspect", container]).stdout)[0]
            log_result = run(["docker", "logs", container])
            safe_lines = [line for line in (log_result.stdout + log_result.stderr).splitlines()
                          if "password" not in line.casefold() and "secret" not in line.casefold()]
            detail = {"state": info.get("State", {}).get("Status"), "exitCode": info.get("State", {}).get("ExitCode"),
                      "ports": info.get("NetworkSettings", {}).get("Ports"), "error": info.get("State", {}).get("Error"), "startupLines": safe_lines[-12:]}
            raise RuntimeError("fixture qBittorrent startup incomplete: " + json.dumps(detail, sort_keys=True))
        network_info = json.loads(run(["docker", "inspect", container]).stdout)[0]
        bridge_ip = network_info.get("NetworkSettings", {}).get("Networks", {}).get(network, {}).get("IPAddress")
        if not bridge_ip:
            raise RuntimeError("owned qBittorrent container did not receive an address on its isolated bridge")
        http_status = wait_host_api(bridge_ip)
        if not http_status.startswith("HTTP/"):
            raise RuntimeError("host could not reach the isolated qBittorrent Web API over its Docker bridge")

        env = os.environ.copy()
        env.update({"BRIANI_M05_QBIT_URL": f"http://{bridge_ip}:8080", "BRIANI_M05_QBIT_USERNAME": "admin",
                    "BRIANI_M05_QBIT_PASSWORD": password, "BRIANI_M05_TORRENT": str(fixture),
                    "BRIANI_M05_LIBRARY_ID": library, "BRIANI_M05_DATA_ROOT": "/data"})
        test = subprocess.run(["dotnet", "test", str(ROOT / "server/tests/Briani.DownloadTests/DownloadTests.csproj"),
                               "--no-build", "--no-restore", "--filter", "FullyQualifiedName~PinnedEngineLiveSmokeWhenConfigured"],
                              cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        output["command"] = "dotnet test Briani.DownloadTests --no-build --filter PinnedEngineLiveSmokeWhenConfigured"
        output["httpPreflight"] = http_status
        output["exitCode"] = test.returncode
        output["result"] = "passed" if test.returncode == 0 else "failed"
        output["testOutput"] = test.stdout.replace(password, "<redacted>")
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.log.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": output["result"], "exitCode": test.returncode, "log": str(args.log), "network": network}))
        return test.returncode
    except Exception as error:
        output["result"] = "failed"
        output["failure"] = type(error).__name__
        safe_error = TEMP_PASSWORD.sub("temporary password is provided for this session: <redacted>", str(error))
        safe_error = re.sub(r"/tmp/briani-m05-[^\s:]+", "<temporary-test-directory>", safe_error)
        output["detail"] = safe_error[:1000]
        args.log.parent.mkdir(parents=True, exist_ok=True)
        args.log.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "failed", "failure": type(error).__name__, "log": str(args.log)}))
        return 1
    finally:
        # Remove only resources that still carry this run's exact ownership labels.
        try:
            if inspect_labels(container, labels):
                run(["docker", "rm", "--force", container])
        except Exception:
            pass
        try:
            if inspect_labels(network, labels):
                run(["docker", "network", "rm", network])
        except Exception:
            pass
        shutil.rmtree(state, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
