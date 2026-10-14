#!/usr/bin/env python3
"""Run a pinned Prowlarr compatibility check on a labeled internal network."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "prototypes/discovery/fixture_indexer.py"
CHECK = ROOT / "prototypes/discovery/check_pinned_prowlarr.py"
IMAGE = "lscr.io/linuxserver/prowlarr@sha256:f9151e5bc1025c6d0a630d503210cdcb6bb55a7cc098562609d96a408d838902"
LABEL = "com.briani.m04.prowlarr-compat"


def docker(*args):
    result = subprocess.run(["docker", *args], check=True, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return result.stdout.strip()


def request_json(url, key, timeout=3):
    request = urllib.request.Request(url, headers={"X-Api-Key": key, "Accept": "application/json"})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(request, timeout=timeout) as response:
        return json.loads(response.read())


def main():
    if not shutil.which("docker"):
        raise SystemExit("Docker CLI is required")
    run_id = uuid.uuid4().hex
    name = "briani-m04-prowlarr-" + run_id[:10]
    network = "briani-m04-net-" + run_id[:10]
    temp_root = Path(tempfile.mkdtemp(prefix="briani-m04-prowlarr-"))
    config = temp_root / "config"
    config.mkdir()
    fixture_log_path = temp_root / "fixture.log"
    docker_label = f"{LABEL}={run_id}"
    container_created = False
    network_created = False
    fixture = None
    result = None
    error = None
    cleanup_verified = True
    stage = "setup"
    key = ""
    commands = []
    try:
        docker("network", "create", "--internal", "--label", docker_label, network)
        network_created = True
        commands.append("docker network create --internal --label com.briani.m04.prowlarr-compat=<run-id>")
        network_info = json.loads(docker("network", "inspect", network))[0]
        gateway = network_info["IPAM"]["Config"][0]["Gateway"]
        with socket.socket() as port_probe:
            port_probe.bind((gateway, 0))
            fixture_port = port_probe.getsockname()[1]
        fixture_env = dict(os.environ, FIXTURE_BIND=gateway, FIXTURE_PORT=str(fixture_port))
        commands.append("python3 prototypes/discovery/fixture_indexer.py (bound to the dedicated bridge gateway)")
        with fixture_log_path.open("w", encoding="utf-8") as fixture_log:
            fixture = subprocess.Popen([sys.executable, str(FIXTURE)], env=fixture_env,
                                       stdout=fixture_log, stderr=subprocess.STDOUT)
            stage = "start_pinned_prowlarr"
            docker("run", "--pull=never", "--detach", "--name", name,
                   "--label", docker_label, "--network", network,
                   "--volume", f"{config}:/config", IMAGE)
            container_created = True
            commands.append("docker run --pull=never --network <dedicated-internal-network> --volume <throwaway-config>:/config <locked-image>")

            address = ""
            stage = "wait_for_pinned_prowlarr"
            deadline = time.monotonic() + 180
            while time.monotonic() < deadline:
                if fixture.poll() is not None:
                    raise RuntimeError("fixture indexer failed to start")
                config_path = config / "config.xml"
                if config_path.exists():
                    key = ET.parse(config_path).getroot().findtext("ApiKey") or ""
                    if key:
                        try:
                            address = docker("inspect", "--format", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", name)
                            base = f"http://{address}:9696"
                            request_json(base + "/api/v1/system/status", key)
                            break
                        except (subprocess.CalledProcessError, OSError, TimeoutError, ValueError):
                            pass
                time.sleep(1)
            else:
                raise RuntimeError("Prowlarr did not become ready")

            env = dict(os.environ,
                       PROWLARR_URL=base,
                       PROWLARR_CONFIG_XML=str(config / "config.xml"),
                       PROWLARR_FIXTURE_BASE_URL=f"http://{gateway}:{fixture_port}")
            stage = "fixture_compatibility_check"
            checked = subprocess.run([sys.executable, str(CHECK)], env=env, check=True,
                                     text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
            result = json.loads(checked.stdout)
            result["lockedImage"] = IMAGE
            result["compatibilityCommands"] = commands
            result["fixtureBind"] = f"{gateway}:{fixture_port}"
            result["failureDetailsRedacted"] = True
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or "").strip().splitlines()
        tail = detail[-1][:200] if detail else "no diagnostic output"
        if key:
            tail = tail.replace(key, "[redacted]")
        error = f"{stage} failed (exit {exc.returncode}): {tail}"
    except Exception as exc:  # report only safe stage/type, never URL or credential data
        error = f"{stage} failed ({type(exc).__name__})"
    finally:
        if fixture is not None:
            fixture.terminate()
            try:
                fixture.wait(timeout=5)
            except subprocess.TimeoutExpired:
                fixture.kill()
                fixture.wait()
        if container_created:
            labels = json.loads(docker("inspect", "--format", "{{json .Config.Labels}}", name))
            if labels.get(LABEL) != run_id:
                error = "RuntimeError: container label verification failed; container left untouched"
                cleanup_verified = False
            else:
                docker("rm", "--force", name)
        if network_created:
            network_info = json.loads(docker("network", "inspect", network))[0]
            if network_info.get("Labels", {}).get(LABEL) != run_id:
                error = "RuntimeError: network label verification failed; network left untouched"
                cleanup_verified = False
            else:
                docker("network", "rm", network)

    artifact_dir = ROOT / "docs/evidence/M04"
    artifact_dir.mkdir(parents=True, exist_ok=True)
    artifact = {"result": result, "error": error, "resourcesRemoved": cleanup_verified}
    (artifact_dir / "prowlarr-compatibility.json").write_text(json.dumps(artifact, indent=2) + "\n")
    fixture_lines = fixture_log_path.read_text(encoding="utf-8").splitlines() if fixture_log_path.exists() else []
    log = ["Pinned Prowlarr compatibility run", f"Image: {IMAGE}",
           "Command: python3 prototypes/discovery/run.py", "Network: dedicated internal Docker bridge",
           "No ports were published; fixture bound only to this bridge gateway.",
           "Prowlarr container and bridge removed after run-specific label verification.",
           "Fixture logs omit query parameters.", "Fixture observations:"] + fixture_lines
    if error:
        log.append("Compatibility outcome: " + error)
    (artifact_dir / "prowlarr-compatibility.log").write_text("\n".join(log) + "\n")
    if cleanup_verified:
        shutil.rmtree(temp_root, ignore_errors=True)
    print(json.dumps(artifact, indent=2))
    return 1 if error else 0


if __name__ == "__main__":
    raise SystemExit(main())
