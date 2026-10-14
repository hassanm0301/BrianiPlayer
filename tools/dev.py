#!/usr/bin/env python3
"""Provider-neutral, evidence-producing development task runner."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Callable, Sequence

ROOT = Path(__file__).resolve().parents[1]
LOG_ROOT = ROOT / "artifacts" / "dev"
DOTNET_HOME = ROOT / ".tools" / "dotnet-home"
SYSTEM_DOTNET = shutil.which("dotnet")
LOCAL_DOTNET = ROOT / ".tools" / "dotnet" / "dotnet"
DOTNET = SYSTEM_DOTNET or (str(LOCAL_DOTNET) if LOCAL_DOTNET.exists() else "dotnet")
PYTHON = sys.executable


class Runner:
    def __init__(self, log_dir: Path | None = None, execute: Callable = subprocess.run):
        stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
        self.log_dir = log_dir or LOG_ROOT / stamp
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.execute = execute
        self.sequence = 0
        self.results: list[dict] = []

    def run(self, argv: Sequence[str], *, name: str | None = None, cwd: Path = ROOT,
            env: dict[str, str] | None = None, required: bool = True) -> int:
        args = [str(x) for x in argv]
        label = name or f"{self.sequence + 1:02d}-{Path(args[0]).name}"
        self.sequence += 1
        out_path, err_path = self.log_dir / f"{label}.stdout.log", self.log_dir / f"{label}.stderr.log"
        command = {"argv": args, "cwd": str(cwd), "startedUtc": dt.datetime.now(dt.timezone.utc).isoformat()}
        try:
            result = self.execute(args, cwd=str(cwd), env=env, text=True, capture_output=True, check=False)
            stdout, stderr, code = result.stdout or "", result.stderr or "", int(result.returncode)
        except FileNotFoundError as e:
            stdout, stderr, code = "", f"unavailable executable: {e}", 127
        except OSError as e:
            stdout, stderr, code = "", f"could not execute: {e}", 126
        out_path.write_text(stdout, encoding="utf-8")
        err_path.write_text(stderr, encoding="utf-8")
        def log_name(path: Path) -> str:
            try:
                return str(path.relative_to(ROOT))
            except ValueError:
                return str(path)
        command.update(exitCode=code, stdoutLog=log_name(out_path), stderrLog=log_name(err_path))
        self.results.append(command)
        print(f"[{code}] {' '.join(args)}")
        if stdout:
            print(stdout, end="" if stdout.endswith("\n") else "\n")
        if stderr:
            print(stderr, file=sys.stderr, end="" if stderr.endswith("\n") else "\n")
        return code

    def record(self, command: list[str], code: int, reason: str) -> int:
        self.sequence += 1
        lowered = reason.lower()
        state = ("passed" if code == 0 else "not_run" if "not_run" in lowered else
                 "blocked_environment" if "blocked_environment" in lowered or "unavailable" in lowered else "failed")
        if code == 0 and "(optional)" in lowered:
            state = "not_applicable"
        self.results.append({"argv": command, "exitCode": code, "status": state, "reason": reason})
        print(f"[{code}] {reason}")
        return code

    def finish(self, task: str, code: int) -> int:
        payload = {"task": task, "finishedUtc": dt.datetime.now(dt.timezone.utc).isoformat(),
                   "platform": platform.platform(), "exitCode": code, "commands": self.results}
        (self.log_dir / "run.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        try:
            location = self.log_dir.relative_to(ROOT)
        except ValueError:
            location = self.log_dir
        print(f"Evidence: {location}")
        print(f"Task exit status: {code}")
        return code


def command_exists(exe: str) -> bool:
    return Path(exe).is_file() if os.path.sep in exe else shutil.which(exe) is not None


def doctor(r: Runner) -> int:
    failures = 0
    print(f"Host: {platform.platform()} ({platform.machine()})")
    print(f"Python: {sys.version.split()[0]} at {sys.executable}")
    print(f"Output directory writable: {os.access(r.log_dir, os.W_OK)} ({r.log_dir})")
    try:
        disk = shutil.disk_usage(ROOT)
        print(f"Workspace storage: total={disk.total} free={disk.free} bytes")
    except OSError as e:
        print(f"Workspace storage unavailable: {e}")
    checks = [("dotnet", [DOTNET, "--version"], True), ("flutter", ["flutter", "--version"], True),
              ("dotnet-info", [DOTNET, "--info"], True),
              ("flutter-doctor", ["flutter", "doctor", "-v"], True),
              ("docker-compose", ["docker", "compose", "version"], True),
              ("docker-access", ["docker", "info", "--format", "{{.ServerVersion}}"], True),
              ("adb", ["adb", "version"], False)]
    for label, argv, required in checks:
        if not command_exists(argv[0]):
            code = r.record(argv, 127 if required else 0, f"{label} unavailable" + (" (required)" if required else " (optional)"))
            failures |= int(required and code != 0)
            continue
        env = os.environ.copy()
        if label.startswith("dotnet"):
            env["DOTNET_CLI_HOME"] = str(DOTNET_HOME)
            env["DOTNET_SKIP_FIRST_TIME_EXPERIENCE"] = "1"
        code = r.run(argv, name="doctor-" + label.replace(" ", "-"), env=env)
        if code == 0 and label in {"dotnet", "flutter"}:
            last = r.results[-1]
            stdout = (ROOT / last["stdoutLog"]).read_text(encoding="utf-8", errors="replace")
            expected = "10.0.112" if label == "dotnet" else "3.47.6"
            if expected not in stdout:
                last["exitCode"] = 2
                last["diagnostic"] = f"expected {label} {expected}; output did not report that version"
                print(f"[2] {last['diagnostic']}")
                code = 2
        failures |= int(required and code != 0)
    for path in (Path("/dev/kvm"), ROOT / ".tools", Path("/tmp")):
        print(f"{path}: {'available' if path.exists() else 'unavailable'}")
    return failures


def existing_projects(paths: Sequence[Path]) -> list[Path]:
    return [p for p in paths if p.exists()]


def dotnet_env() -> dict[str, str]:
    env = os.environ.copy()
    env["DOTNET_CLI_HOME"] = str(DOTNET_HOME)
    env["DOTNET_SKIP_FIRST_TIME_EXPERIENCE"] = "1"
    env["NUGET_PACKAGES"] = str(ROOT / ".tools" / "nuget")
    return env


def build(r: Runner) -> int:
    solutions = existing_projects([ROOT / "server" / "Briani.sln", ROOT / "Briani.sln"])
    projects = [] if solutions else existing_projects([ROOT / "prototypes" / "playback" / "gateway" / "Gateway.csproj"])
    targets = solutions or projects
    if not targets:
        return r.record([DOTNET, "build"], 2, "No server solution or buildable project found; build suite is not_run")
    rc = 0
    for target in targets:
        rc |= int(r.run([DOTNET, "build", str(target), "--nologo"], name="build-" + target.stem, env=dotnet_env()))
    return rc


def _suite_paths(suite: str) -> list[Path]:
    expected = {"unit": "UnitTests.csproj", "contract": "ContractTests.csproj", "integration": "IntegrationTests.csproj", "identity": "IdentityTests.csproj", "media": "MediaTests.csproj", "discovery": "DiscoveryTests.csproj", "downloads": "DownloadTests.csproj", "streaming": "Briani.StreamingTests.csproj", "preferences": "PreferencesTests.csproj", "operations": "OperationsTests.csproj"}
    server_projects = sorted((ROOT / "server").rglob(expected[suite])) if (ROOT / "server").is_dir() else []
    if suite == "unit":
        return server_projects + existing_projects([ROOT / "prototypes" / "playback" / "tests" / "ReaderTests.csproj"])
    if suite in {"integration", "identity", "media", "discovery", "downloads", "streaming", "preferences", "operations"}:
        return server_projects
    if suite == "contract":
        return server_projects
    return []


def test_suite(r: Runner, suite: str) -> int:
    if suite == "desktop-e2e":
        return r.run([PYTHON, str(ROOT / "prototypes/client/run_desktop_e2e.py"),
                      "--artifacts", str(ROOT / "docs/evidence/M07/artifacts")], name="test-desktop-e2e")
    if suite == "tv-navigation":
        return r.run([shutil.which("flutter") or "flutter", "test", "--no-pub", "test/tv_remote_navigation_test.dart"],
                     name="test-tv-navigation", cwd=ROOT / "client")
    if suite == "android-e2e":
        device = os.environ.get("BRIANI_ANDROID_DEVICE")
        if not device:
            return r.record(["flutter", "test", "--device"], 3,
                            "blocked_verification: set BRIANI_ANDROID_DEVICE to the explicit authorized Android test device")
        return r.run([shutil.which("flutter") or "flutter", "test", "--no-pub",
                      "integration_test/android_security_test.dart", "-d", device, "--no-uninstall"], name="test-android-native", cwd=ROOT / "client")
    paths = _suite_paths(suite)
    if not paths:
        return r.record([DOTNET, "test", f"--suite={suite}"], 2, f"{suite} suite has no test project; status=not_run")
    rc = 0
    for target in paths:
        if target.name == "ReaderTests.csproj":
            argv = [DOTNET, "run", "--project", str(target)]
        else:
            argv = [DOTNET, "test", str(target), "--nologo"]
            if suite == "downloads": argv += ["--filter", "Category!=EngineIntegration"]
        rc |= int(r.run(argv,
                        name=f"test-{suite}-{target.stem}", env=dotnet_env()))
    if suite == "integration" and rc == 0:
        rc |= int(download_engine_integration(r))
    if suite == "operations":
        rc |= int(r.run([PYTHON,"-m","unittest","discover","-s","tests/operations"],name="test-operations-cli"))
    if suite == "preferences":
        rc |= int(r.run([shutil.which("flutter") or "flutter","test","--no-pub","test/preferences_screens_test.dart","test/feature_preferences_test.dart"],name="test-preferences-client",cwd=ROOT/"client"))
    if suite == "unit":
        rc |= int(r.run([PYTHON, "-m", "unittest", "discover", "-s", "tests/tools"], name="test-unit-tools"))
        rc |= int(r.run([PYTHON, "tools/security/scan_secrets.py"], name="secret-scan"))
        rc |= int(r.run([PYTHON, "tools/dependencies/inventory.py"], name="dependency-inventory"))
        pytests = [ROOT / "prototypes" / "playback" / "fixtures" / "test_generate.py",
                   ROOT / "prototypes" / "playback" / "harness" / "test_probe.py"]
        available = [p for p in pytests if p.exists()]
        for i, test_file in enumerate(available, 1):
            rc |= int(r.run([PYTHON, "-m", "unittest", "discover", "-s", str(test_file.parent),
                             "-p", test_file.name], name=f"test-unit-python-{i}", cwd=test_file.parent))
    if suite == "contract":
        validator = ROOT / "plan" / "tools" / "validate_plan.py"
        if validator.exists():
            rc |= int(r.run([PYTHON, str(validator)], name="test-contract-plan-validator"))
        generator = ROOT / "tools/contracts/generate.py"
        if generator.exists(): rc |= int(r.run([PYTHON, str(generator), "--check"], name="test-contract-generation"))
    return rc


def download_engine_integration(r: Runner) -> int:
    fixture_root = ROOT / "prototypes/playback/fixtures/generated"
    required = fixture_root / "torrents/Faststart café [test]-v1.torrent"
    if not required.is_file():
        fixture_root = r.log_dir / "generated-fixtures"
        code = r.run([PYTHON, "prototypes/playback/fixtures/generate.py", "--out", str(fixture_root),
                      "--duration", "3", "--early-play-duration", "90"], name="integration-generated-fixtures")
        if code: return code
    env = dotnet_env()
    env["BRIANI_DOWNLOAD_FIXTURE_ROOT"] = str(fixture_root)
    env["BRIANI_DOWNLOAD_SINGLE_TORRENT"] = str(fixture_root / "torrents/Faststart café [test]-v1.torrent")
    code = r.run([DOTNET, "build", "server/tests/Briani.DownloadTests/DownloadTests.csproj", "--nologo"],
                 name="integration-download-build", env=env)
    if code: return code
    for label, script in (("pinned-engine", "engine/run_pinned_engine.py"),
                          ("metadata-layout", "engine/run_local_peer_transfer.py"),
                          ("api-restart-import", "lifecycle/run_api_restart.py")):
        argv = [PYTHON, "prototypes/downloads/" + script, "--fixture-root", str(fixture_root),
                "--log", str(r.log_dir / (label + ".json"))]
        if label == "api-restart-import":
            argv += ["--image", "briani-server:dev"]
        code = r.run(argv, name="integration-" + label, env=env)
        if code: return code
    return 0


def client(r: Runner, task: str, platform_name: str | None) -> int:
    flutter = shutil.which("flutter")
    if not flutter:
        return r.record(["flutter", task], 127, "Flutter SDK unavailable; client task is blocked")
    root = ROOT / "client"
    pubspec = root / "pubspec.yaml"
    if not pubspec.exists() or not (root / "pubspec.lock").exists():
        return r.record([flutter, task], 2, "client pubspec or committed pubspec.lock missing; client task is not_run")
    commands: list[list[str]]
    if task == "analyze":
        commands = [[flutter, "analyze", "--no-pub"]]
    elif task == "test":
        tests = list((root / "test").glob("*_test.dart"))
        if not tests:
            return r.record([flutter, "test"], 2, "Flutter test suite is empty; status=not_run")
        commands = [[flutter, "test", "--no-pub"]]
    else:
        flags = {"linux": "linux", "windows": "windows", "macos": "macos", "android": "apk"}
        if platform_name not in flags:
            return r.record([flutter, "build", str(platform_name)], 2, f"Unsupported client platform: {platform_name}")
        commands = [[flutter, "build", flags[platform_name], "--debug"]]
    code = r.run([flutter, "pub", "get", "--enforce-lockfile"], name="client-dependencies", cwd=root)
    if code:
        return code
    for i, argv in enumerate(commands):
        code |= int(r.run(argv, name=f"client-{task}-{i+1}", cwd=root))
    return code


def compose_smoke(r: Runner) -> int:
    docker = shutil.which("docker")
    manifest = ROOT / "infra/compose/compose.test.yaml"
    if not docker:
        return r.record(["docker", "compose", "-f", str(manifest), "up"], 127, "Docker CLI unavailable; Compose smoke blocked")
    if not manifest.exists():
        return r.record([docker, "compose", "-f", str(manifest), "up"], 2, "Isolated compose.test.yaml missing; smoke not_run")
    project = "briani-smoke-" + dt.datetime.now(dt.timezone.utc).strftime("%H%M%S")
    base = [docker, "--config", str(ROOT / ".tools/docker-config"), "compose", "-p", project, "-f", str(manifest)]
    rc = r.run(base + ["config", "--quiet"], name="compose-config")
    if rc:
        return rc
    rc = r.run(base + ["up", "-d", "--wait"], name="compose-up")
    if rc:
        r.run(base + ["down", "--volumes", "--remove-orphans"], name="compose-cleanup")
        return rc
    ps = r.run(base + ["ps"], name="compose-ps")
    probe = r.run([PYTHON, str(ROOT / "tools/compose_probe.py")], name="compose-http")
    down = r.run(base + ["down", "--volumes", "--remove-orphans"], name="compose-down")
    return int(bool(ps or probe or down))


def pi_benchmark(r: Runner) -> int:
    configured = os.environ.get("BRIANI_BENCHMARK_CONFIG")
    if not configured:
        return r.record(["benchmark", "--profile", "pi5"], 3,
                        "blocked_environment: set BRIANI_BENCHMARK_CONFIG to an explicit isolated native Pi stack configuration")
    try:
        path = Path(configured)
        if not path.is_absolute() or path.is_symlink() or path.stat().st_size > 16384:
            raise ValueError("benchmark config must be a bounded absolute regular file")
        config = json.loads(path.read_text())
        allowed = {"schemaVersion", "project", "containerIds", "apiUrl", "credentialsFile", "storage", "durationSeconds", "apiSamples", "fixtureUrl", "fixtureSha256"}
        if not isinstance(config, dict) or set(config) - allowed or config.get("schemaVersion") != 1:
            raise ValueError("unsupported benchmark configuration")
        required = {"project", "containerIds", "apiUrl", "storage", "durationSeconds"}
        if required - config.keys() or not isinstance(config["containerIds"], list) or not all(isinstance(x, str) for x in config["containerIds"]):
            raise ValueError("missing explicit stack/measurement inputs")
        argv = [PYTHON, str(ROOT / "tools/benchmarks/collect.py"), "--project", config["project"],
                "--api-url", config["apiUrl"], "--storage-path", config["storage"],
                "--duration", str(config["durationSeconds"]), "--api-samples", str(config.get("apiSamples", 25)),
                "--output", str(r.log_dir / "pi5-benchmark.json")]
        for identity in config["containerIds"]:
            argv += ["--container-id", identity]
        for field, flag in (("credentialsFile", "--credentials"), ("fixtureUrl", "--fixture-url"), ("fixtureSha256", "--fixture-sha256")):
            if config.get(field): argv += [flag, config[field]]
    except (OSError, ValueError, TypeError, KeyError) as error:
        return r.record(["benchmark", "--profile", "pi5"], 2, f"invalid benchmark configuration: {error}")
    return r.run(argv, name="native-pi5-collector")


def release_verify(r: Runner) -> int:
    artifact_check = r.run([PYTHON, str(ROOT / 'tools/release/package_audit.py'), 'verify',
                            '--root', str(ROOT), '--manifest', 'dist/manifest.json'], name='release-artifact-audit')
    if artifact_check not in (0, 3):
        return artifact_check
    status_path = ROOT / "plan" / "evidence" / "status.json"
    try:
        status = json.loads(status_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        return r.record(["release", "--task", "verify"], 2, f"release evidence unavailable or invalid: {e}")
    blockers = []
    for milestone in status.get("milestones", []):
        if milestone.get("id") in {f"M{i:02}" for i in range(12)} and milestone.get("state") != "complete":
            blockers.append(f"{milestone.get('id')}={milestone.get('state', 'unknown')}")
    if status.get("releaseStatus") != "complete":
        blockers.append(f"releaseStatus={status.get('releaseStatus', 'missing')}")
    if blockers:
        return r.record(["release", "--task", "verify"], 3, "release verification blocked: " + ", ".join(blockers))
    if artifact_check:
        return r.record(["release", "--task", "verify"], 3, "release artifact evidence remains blocked")
    return r.record(["release", "--task", "verify"], 0, "Artifact hashes, dependency/native provenance and required milestone evidence verified")


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest="group", required=True)
    subs.add_parser("doctor")
    subs.add_parser("build")
    test = subs.add_parser("test"); test.add_argument("--suite", choices=("unit", "contract", "integration", "identity", "media", "discovery", "downloads", "streaming", "preferences", "operations", "desktop-e2e", "android-e2e", "tv-navigation"), required=True)
    c = subs.add_parser("client"); c.add_argument("--task", choices=("analyze", "test", "build"), required=True); c.add_argument("--platform")
    comp = subs.add_parser("compose"); comp.add_argument("--task", choices=("smoke",), required=True)
    bench = subs.add_parser("benchmark"); bench.add_argument("--profile", choices=("pi5",), required=True)
    rel = subs.add_parser("release"); rel.add_argument("--task", choices=("verify",), required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = make_parser().parse_args(argv)
    runner = Runner()
    if args.group == "doctor": code = doctor(runner)
    elif args.group == "build": code = build(runner)
    elif args.group == "test": code = test_suite(runner, args.suite)
    elif args.group == "client": code = client(runner, args.task, args.platform)
    elif args.group == "compose": code = compose_smoke(runner)
    elif args.group == "benchmark": code = pi_benchmark(runner)
    else: code = release_verify(runner)
    return runner.finish(" ".join(sys.argv[1:] if argv is None else argv), code)


if __name__ == "__main__":
    raise SystemExit(main())
