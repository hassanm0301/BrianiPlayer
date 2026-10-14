#!/usr/bin/env python3
"""Reproducible isolated playback proof. Empty/missing/failed gates are nonzero."""
from pathlib import Path
import argparse
import datetime
import json
import os
import platform
import shutil
import subprocess
import sys
import uuid
import traceback

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ART = HERE / "artifacts"


def command(argv, name, cwd=ROOT, run_id=None):
    ART.mkdir(exist_ok=True)
    env = dict(os.environ, DOTNET_CLI_HOME=str(ROOT / ".tools/dotnet-home"), NUGET_PACKAGES=str(ROOT / ".tools/nuget"))
    with (ART / (name + ".log")).open("w") as output:
        process = subprocess.run(argv, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT)
    event = {"argv": argv, "cwd": str(cwd), "exitCode": process.returncode,
             "log": str(ART / (name + ".log")), "atUtc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    if run_id:
        event["runId"] = run_id
    with (ART / "commands.jsonl").open("a") as log: log.write(json.dumps(event) + "\n")
    print(name, "exit", process.returncode, flush=True)
    return process.returncode


def doctor():
    failures, results = 0, {}
    for tool, args in {"dotnet": ["--info"], "docker": ["version"], "ffmpeg": ["-version"],
                       "ffprobe": ["-version"], "mpv": ["--version"]}.items():
        if not shutil.which(tool):
            failures += 1; results[tool] = {"state": "blocked_environment", "reason": "not installed"}; continue
        code = command([tool, *args], "doctor-" + tool)
        results[tool] = {"exitCode": code}; failures += code != 0
    code = command(["docker", "compose", "version"], "doctor-compose"); failures += code != 0
    code = command([sys.executable, "-c", "import libtorrent; print(libtorrent.__version__)"], "doctor-fixture-binding")
    failures += code != 0
    report = {"platform": platform.platform(), "architecture": platform.machine(), "storageFreeBytes": shutil.disk_usage(ROOT).free,
              "tools": results, "pi5Available": False, "exitCode": int(bool(failures))}
    (ART / "doctor.json").write_text(json.dumps(report, indent=2) + "\n")
    return report["exitCode"]


def unit():
    codes = [command(["dotnet", "run", "--project", str(HERE / "tests/ReaderTests.csproj")], "reader-unit")]
    for module in ("fixtures", "harness"):
        codes.append(command([sys.executable, "-m", "unittest", "discover", "-s", str(HERE / module), "-p", "test_*.py", "-v"],
                             module + "-unit", cwd=HERE / module))
    return int(any(codes))


def engine(run_id):
    from integration import run_single, metadata_only, multifile, set_result_dir
    result_dir = ART / "runs" / run_id
    set_result_dir(result_dir)
    failures = 0
    for name, kind, mode in [("Faststart café [test]-v1.torrent", "faststart", "v1"),
                             ("Tracks 演示-v1.torrent", "mkv", "v1"),
                             ("Faststart café [test]-v2.torrent", "faststart", "v2"),
                             ("Faststart café [test]-hybrid.torrent", "faststart", "hybrid"),
                             ("Tail metadata-v1.torrent", "tail", "v1")]:
        try:
            print(json.dumps(run_single(HERE / "fixtures/generated/torrents" / name, kind, mode, reset=True,
                                        run_id=run_id)), flush=True)
        except Exception as error:
            failures += 1
            # Never emit HTTP exceptions containing a ticket-bearing URL.
            print(f"FAILED {kind}/{mode}: {type(error).__name__} at line {traceback.extract_tb(error.__traceback__)[-1].lineno}", flush=True)
            (result_dir / f"{kind}-{mode}-failure.json").write_text(json.dumps({"runId": run_id, "state": "failed", "exceptionType": type(error).__name__}))
    for name, operation in [("metadata-only", metadata_only), ("multifile", multifile)]:
        try:
            result = operation(run_id=run_id)
            (result_dir / (name + "-result.json")).write_text(json.dumps(result, indent=2) + "\n")
            print(name, "passed", flush=True)
        except Exception as error:
            failures += 1; print(name, "FAILED", type(error).__name__, flush=True)
            (result_dir / f"{name}-failure.json").write_text(json.dumps({"runId": run_id, "state": "failed", "exceptionType": type(error).__name__}))
    return int(bool(failures))


def report():
    run_path = ART / "current-run.json"
    run = json.loads(run_path.read_text()) if run_path.exists() else {}
    run_id = run.get("runId")
    result_dir = ROOT / run["resultDirectory"] if run.get("resultDirectory") else None
    results = ({p.name: json.loads(p.read_text()) for p in result_dir.glob("*-result.json")}
               if result_dir and result_dir.is_dir() else {})
    required = {f"{kind}-{mode}-result.json" for kind, mode in
                [("faststart", "v1"), ("faststart", "v2"), ("faststart", "hybrid"), ("mkv", "v1"), ("tail", "v1")]}
    required |= {"metadata-only-result.json", "multifile-result.json"}
    missing = sorted(required - results.keys())
    if not run_id or run.get("task") != "verify" or run.get("exitCode") != 0:
        missing.append("current-successful-verify-run")
    invocation = run.get("invocation", [])
    if (len(invocation) < 2 or Path(invocation[0]).name != "run.py" or invocation[1] != "verify"):
        missing.append("verify-command-validation")
    if run.get("suite") in ("all", "engine") and not any(
            item.get("runId") == run_id and item.get("exitCode") == 0 and
            item.get("argv", [None])[1:2] == ["build"] for item in run.get("commandResults", [])):
        missing.append("current-run-gateway-build")
    if run_id:
        missing.extend(f"stale:{name}" for name, result in results.items() if result.get("runId") != run_id)
    summary = {"runId": run_id, "verifyInvocation": run.get("invocation"), "verifyExitCode": run.get("exitCode"),
               "results": results, "missingGates": sorted(missing), "hardware": "blocked_verification: native Pi5 not exercised",
               "unitResultsAreNotEngineProof": True, "releaseCertified": False}
    (ART / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"missingGates": missing, "summary": str(ART / "summary.json")}, indent=2))
    return int(bool(missing))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("task", choices=["doctor", "fixtures", "verify", "report"])
    parser.add_argument("--suite", choices=["unit", "engine", "all"], default="all")
    args = parser.parse_args()
    ART.mkdir(exist_ok=True)
    if args.task == "doctor": status = doctor()
    elif args.task == "fixtures": status = command([sys.executable, str(HERE / "fixtures/generate.py")], "fixtures-generate")
    elif args.task == "report": status = report()
    else:
        run_id = uuid.uuid4().hex
        manifest = {"runId": run_id, "task": "verify", "suite": args.suite,
                    "invocation": list(sys.argv), "resultDirectory": str((ART / "runs" / run_id).relative_to(ROOT)),
                    "startedUtc": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        (ART / "summary.json").unlink(missing_ok=True)
        (ART / "current-run.json").write_text(json.dumps(manifest, indent=2) + "\n")
        (ART / "runs" / run_id).mkdir(parents=True, exist_ok=True)
        codes = []
        if args.suite in ("all", "unit"): codes.append(unit())
        if args.suite in ("all", "engine"):
            codes.append(command(["dotnet", "build", str(HERE / "gateway/Gateway.csproj")], "gateway-build", run_id=run_id))
            if codes[-1] == 0: codes.append(engine(run_id))
        status = int(any(codes))
        command_log = ART / "commands.jsonl"
        if command_log.exists():
            manifest["commandResults"] = [json.loads(line) for line in command_log.read_text().splitlines()
                                           if line.strip() and json.loads(line).get("runId") == run_id]
        manifest.update(exitCode=status, finishedUtc=datetime.datetime.now(datetime.timezone.utc).isoformat())
        (ART / "current-run.json").write_text(json.dumps(manifest, indent=2) + "\n")
    raise SystemExit(status)
