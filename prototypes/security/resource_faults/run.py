#!/usr/bin/env python3
"""Run owned, bounded storage and private-network faults against the M10 image.

The runner creates one private Docker network and only containers carrying this
run's exact ownership labels. Its host scratch directory is uniquely named and
has an owner marker. Cleanup targets those exact container IDs/network ID and
the verified scratch root; it never uses prune or changes host networking.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[3]
IMAGE = "briani-server:m10"
EXPECTED_IMAGE = "sha256:95ab935e5834f4dab1390fbea017dbfd4a99a0d5b998b01e7acf808a89fc9b3b"
OWNER = "resource-faults"


def docker(*args: str, timeout: int = 20) -> str:
    env = dict(os.environ)
    env["DOCKER_CONFIG"] = str(ROOT / ".tools/docker-config")
    p = subprocess.run(["docker", *args], text=True, capture_output=True,
                       timeout=timeout, env=env, check=False)
    if p.returncode:
        raise RuntimeError(f"docker {args[0]} failed ({p.returncode}): {(p.stderr or '')[-1200:]}")
    return p.stdout.strip()


def run_id_for(kind: str, run_id: str) -> dict[str, str]:
    return {"org.briani.test": "M10-resource-fault", "org.briani.run": run_id,
            "org.briani.owner": OWNER, "org.briani.kind": kind}


def labels_match(actual: dict[str, str], expected: dict[str, str]) -> bool:
    return all(actual.get(key) == value for key, value in expected.items())


def owned(inspect_id: str, run_id: str, kind: str) -> bool:
    obj = json.loads(docker("inspect", inspect_id))[0]
    labels = obj.get("Config", {}).get("Labels", {})
    return labels_match(labels, run_id_for(kind, run_id))


def remove_owned_scratch(path: Path, parent: Path, expected_marker: str) -> bool:
    """Remove only the exact child directory carrying this run's marker."""
    resolved_parent = parent.resolve()
    resolved_path = path.resolve()
    marker = resolved_path / ".briani-owner"
    if resolved_path.parent != resolved_parent or not marker.is_file():
        return False
    if marker.read_text(encoding="ascii").strip() != expected_marker:
        return False
    shutil.rmtree(resolved_path)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", default=IMAGE)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--scratch-parent", type=Path, default=ROOT / "artifacts/resource-faults")
    parser.add_argument("--probe-publish", type=Path, required=True,
                        help="dotnet publish output for ResourceProbe.csproj")
    parser.add_argument("--skip-network", action="store_true")
    args = parser.parse_args()
    run_id = uuid.uuid4().hex
    short = run_id[:12]
    root = args.scratch_parent.resolve() / run_id
    root.mkdir(parents=True, mode=0o700)
    marker = root / ".briani-owner"
    marker.write_text(f"{OWNER}:{run_id}\n", encoding="ascii")
    marker.chmod(0o600)
    (root / "state").mkdir(mode=0o700)
    (root / "disk-state").mkdir(mode=0o700)
    secret_config = root / "secret-config"
    secret_config.mkdir(mode=0o700)
    (root / "data").mkdir(mode=0o700)
    (root / "probe").mkdir(mode=0o700)
    library = root / "data/library"
    library.mkdir(mode=0o700)
    published = root / "probe"
    probe_publish = args.probe_publish.expanduser().resolve()
    if not probe_publish.is_dir():
        raise RuntimeError(f"probe publish directory does not exist: {probe_publish}")
    for source in probe_publish.iterdir():
        if source.is_file():
            shutil.copy2(source, published / source.name)
        elif source.is_dir():
            shutil.copytree(source, published / source.name, dirs_exist_ok=True)
    network = f"briani-m10-rf-net-{short}"
    containers: dict[str, str] = {}
    container_kinds: dict[str, str] = {}
    network_id: str | None = None
    result: dict[str, object] = {"schema": 1, "runId": run_id, "image": args.image,
                                 "expectedImageId": EXPECTED_IMAGE, "startedUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                 "scenarios": {}, "cleanup": {}}

    def exec_probe(name: str, mode: str, *, timeout: int = 25) -> dict[str, object]:
        cid = containers[name]
        docker("start", cid)
        p = subprocess.run(["docker", "wait", cid], text=True, capture_output=True,
                           timeout=timeout, env={**os.environ, "DOCKER_CONFIG": str(ROOT / ".tools/docker-config")})
        if p.returncode:
            raise RuntimeError(f"docker wait failed: {p.stderr[-1000:]}")
        logs = docker("logs", cid)
        lines = [line for line in logs.splitlines() if line.startswith("{")]
        if not lines:
            raise RuntimeError(f"probe {mode} emitted no JSON: {logs[-1000:]}")
        value = json.loads(lines[-1])
        code = int(p.stdout.strip().splitlines()[-1])
        if code != 0 or value.get("passed") is not True:
            raise RuntimeError(f"probe {mode} failed exit={code}: {value}")
        value["exitCode"] = code
        return value

    try:
        image_id = docker("image", "inspect", args.image, "--format", "{{.Id}}")
        if image_id != EXPECTED_IMAGE:
            raise RuntimeError(f"Unexpected local image digest {image_id}; expected {EXPECTED_IMAGE}")
        probe_files = list(published.glob("*"))
        if not any(p.name == "ResourceProbe.dll" for p in probe_files):
            raise RuntimeError("Build the probe first and pass its publish output in the scratch probe directory")

        # Disk-full uses an actual 8 MiB tmpfs mounted as the library itself.
        # The C# production probe creates and retains its fixture, fills the
        # mount until ENOSPC, checks 507/no durable mutation, then removes only
        # its own filler and proves writes recover with exact hashes.
        tmpfs_cid = docker("create", "--name", f"briani-m10-rf-{short}-diskfull", "--network", "none", "--entrypoint", "dotnet",
                           "--tmpfs", "/data/library:rw,nosuid,nodev,noexec,size=8m,uid=1000,gid=1000,mode=0700",
                           "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                           "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=disk-full",
                           "-v", f"{root / 'disk-state'}:/state", "-v", f"{published}:/probe:ro", args.image,
                           "/probe/ResourceProbe.dll", "disk-full")
        containers[f"disk-full-{short}"] = tmpfs_cid
        container_kinds[f"disk-full-{short}"] = "disk-full"
        docker("start", tmpfs_cid)
        p = subprocess.run(["docker", "wait", tmpfs_cid], text=True, capture_output=True, timeout=35,
                           env={**os.environ, "DOCKER_CONFIG": str(ROOT / ".tools/docker-config")})
        logs = docker("logs", tmpfs_cid)
        lines = [line for line in logs.splitlines() if line.startswith("{")]
        disk_result = json.loads(lines[-1]) if lines else {"passed": False, "raw": logs[-1000:]}
        if p.returncode or int(p.stdout.strip().splitlines()[-1]) != 0 or disk_result.get("passed") is not True:
            raise RuntimeError(f"Disk-full probe failed: {disk_result}")
        disk_result["exitCode"] = int(p.stdout.strip().splitlines()[-1])
        result["scenarios"]["diskFull"] = disk_result

        # Generate a valid key through the production SecretStore on a mutable
        # owned config root, then bind that exact root read-only for the
        # failure case. This tests the kernel mount restriction without chmod,
        # syscall mocks, or a synthetic file-operation failure.
        secret_prepare = f"briani-m10-rf-{short}-secret-prepare"
        containers[secret_prepare] = docker("create", "--name", secret_prepare, "--network", "none", "--entrypoint", "dotnet",
                                           "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                                           "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=secret-prepare",
                                           "-v", f"{secret_config}:/config", "-v", f"{published}:/probe:ro", args.image,
                                           "/probe/ResourceProbe.dll", "secret-prepare")
        container_kinds[secret_prepare] = "secret-prepare"
        secret_baseline = exec_probe(secret_prepare, "secret-prepare")
        result["scenarios"]["secretStoreWritableBaseline"] = secret_baseline
        secret_readonly = f"briani-m10-rf-{short}-secret-readonly"
        containers[secret_readonly] = docker("create", "--name", secret_readonly, "--network", "none", "--entrypoint", "dotnet",
                                            "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                                            "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=secret-readonly",
                                            "-v", f"{secret_config}:/config:ro", "-v", f"{published}:/probe:ro", args.image,
                                            "/probe/ResourceProbe.dll", "secret-readonly")
        container_kinds[secret_readonly] = "secret-readonly"
        secret_denial = exec_probe(secret_readonly, "secret-readonly")
        if secret_baseline["keySha256"] != secret_denial["keySha256Before"]:
            raise RuntimeError("SecretStore read-only test did not retain the generated baseline key")
        result["scenarios"]["secretStoreReadOnly"] = secret_denial

        # Prepare on a fixture-only host directory, then use the same directory
        # as a read-only bind. A second DB/state directory stores the identity.
        prep = f"briani-m10-rf-{short}-prepare"
        containers[prep] = docker("create", "--name", prep, "--network", "none", "--entrypoint", "dotnet",
                                  "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                                  "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=prepare",
                                  "-v", f"{root / 'data'}:/data", "-v", f"{root / 'state'}:/state",
                                  "-v", f"{published}:/probe:ro", args.image,
                                  "/probe/ResourceProbe.dll", "prepare")
        container_kinds[prep] = "prepare"
        result["scenarios"]["prepare"] = exec_probe(prep, "prepare")
        ro = f"briani-m10-rf-{short}-readonly"
        containers[ro] = docker("create", "--name", ro, "--network", "none", "--entrypoint", "dotnet",
                                "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                                "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=readonly",
                                "-v", f"{root / 'data'}:/data", "-v", f"{library}:/data/library:ro",
                                "-v", f"{root / 'state'}:/state", "-v", f"{published}:/probe:ro", args.image,
                                "/probe/ResourceProbe.dll", "readonly")
        container_kinds[ro] = "readonly"
        result["scenarios"]["readOnly"] = exec_probe(ro, "readonly")
        if result["scenarios"]["prepare"]["retainedSha256"] != result["scenarios"]["readOnly"]["retainedSha256"]:
            raise RuntimeError("Read-only phase changed the fixture hash")

        # The missing-mount check runs with a fresh empty data root and an
        # existing DB carrying the prior library identity. Production lookup
        # must report path_unavailable rather than adopting a new root.
        absent = root / "absent-data"
        absent.mkdir(mode=0o700)
        miss = f"briani-m10-rf-{short}-missing"
        containers[miss] = docker("create", "--name", miss, "--network", "none", "--entrypoint", "dotnet",
                                  "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                                  "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=missing",
                                  "-v", f"{absent}:/data", "-v", f"{root / 'state'}:/state",
                                  "-v", f"{published}:/probe:ro", args.image,
                                  "/probe/ResourceProbe.dll", "missing")
        container_kinds[miss] = "missing"
        # Probe currently checks /data/library absence but needs a separate
        # state copy to retain the persisted identity; preserve the DB state.
        result["scenarios"]["missingMount"] = exec_probe(miss, "missing")

        if not args.skip_network:
            network_id = docker("network", "create", "--internal", "--label", "org.briani.test=M10-resource-fault",
                                "--label", f"org.briani.run={run_id}", "--label", f"org.briani.owner={OWNER}",
                                "--label", "org.briani.kind=network", network)
            server = f"briani-m10-rf-{short}-netserver"
            client = f"briani-m10-rf-{short}-netclient"
            containers[server] = docker("create", "--name", server, "--network", network, "--entrypoint", "dotnet",
                                        "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                                        "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=netserver",
                                        "--network-alias", "fixture-server", "-v", f"{published}:/probe:ro", args.image,
                                        "/probe/ResourceProbe.dll", "network-server")
            container_kinds[server] = "netserver"
            containers[client] = docker("create", "--name", client, "--network", network, "--entrypoint", "dotnet",
                                        "--label", "org.briani.test=M10-resource-fault", "--label", f"org.briani.run={run_id}",
                                        "--label", f"org.briani.owner={OWNER}", "--label", "org.briani.kind=netclient",
                                        "-v", f"{published}:/probe:ro", args.image, "/probe/ResourceProbe.dll", "idle")
            container_kinds[client] = "netclient"
            docker("start", containers[server])
            wait_for_log(containers[server], "fixture-listener-ready", 8)
            docker("start", containers[client])
            ip = docker("inspect", "--format", f'{{{{(index .NetworkSettings.Networks "{network}").IPAddress}}}}', containers[server])
            if not ip:
                raise RuntimeError("fixture server has no address on its owned private network")
            result["scenarios"]["networkBaseline"] = docker_run_client(containers[client], ip, False)
            docker("network", "disconnect", network, containers[client])
            result["scenarios"]["networkDisconnected"] = docker_run_client(containers[client], ip, True)
            docker("network", "connect", network, containers[client])
            result["scenarios"]["networkRecovered"] = docker_run_client(containers[client], ip, False)

        result["result"] = "passed"
    except Exception as error:
        result["result"] = "failed"
        result["error"] = f"{type(error).__name__}: {error}"
    finally:
        # Remove only the IDs created by this run, after confirming all labels.
        removed: list[str] = []
        cleanup_errors: list[str] = []
        for name, cid in list(containers.items())[::-1]:
            try:
                if owned(cid, run_id, container_kinds[name]):
                    docker("rm", "--force", cid)
                    removed.append(cid)
                else:
                    cleanup_errors.append(f"refused unowned container {cid}")
            except Exception as error:
                cleanup_errors.append(f"container {cid}: {error}")
        if network_id:
            try:
                obj = json.loads(docker("network", "inspect", network_id))[0]
                labels = obj.get("Labels", {})
                if labels.get("org.briani.run") == run_id and labels.get("org.briani.owner") == OWNER:
                    docker("network", "rm", network_id)
                else:
                    cleanup_errors.append(f"refused unowned network {network_id}")
            except Exception as error:
                cleanup_errors.append(f"network {network_id}: {error}")
        result["cleanup"] = {"removedContainerIds": removed, "networkId": network_id,
                              "errors": cleanup_errors, "scratchRoot": str(root),
                              "ownerMarker": marker.read_text(encoding="ascii").strip() if marker.exists() else None}
        result["finishedUtc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        output = args.output or ROOT / "docs/evidence/M10/resource-fault-latest.json"
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": result.get("result"), "runId": run_id, "output": str(output),
                          "error": result.get("error"), "cleanupErrors": cleanup_errors}))
        # Scratch has generated test data only. Retain it when cleanup failed
        # for diagnosis; otherwise delete only after verifying its owner token.
        if not cleanup_errors:
            remove_owned_scratch(root, args.scratch_parent, f"{OWNER}:{run_id}")
    return 0 if result.get("result") == "passed" and not result["cleanup"]["errors"] else 1


def docker_run_client(container: str, host: str, expected_failure: bool) -> dict[str, object]:
    # Existing container is a deliberately long-lived idle probe. Override it
    # with docker exec, retaining only the owned private-network membership.
    p = subprocess.run(["docker", "exec", container, "dotnet", "/probe/ResourceProbe.dll",
                       "network-client", host, "failure" if expected_failure else "success"],
                      text=True, capture_output=True, timeout=8,
                      env={**os.environ, "DOCKER_CONFIG": str(ROOT / ".tools/docker-config")})
    if p.returncode:
        raise RuntimeError(f"network probe failed ({p.returncode}): {p.stderr[-500:]}")
    value = json.loads(p.stdout.strip().splitlines()[-1])
    if value.get("passed") is not True:
        raise RuntimeError(f"network probe did not meet expectation: {value}")
    value["exitCode"] = p.returncode
    return value


def wait_for_log(container: str, marker: str, timeout: int) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if marker in docker("logs", container):
            return
        time.sleep(.1)
    raise RuntimeError(f"container {container} did not emit readiness marker {marker!r} in {timeout}s")


if __name__ == "__main__":
    raise SystemExit(main())
