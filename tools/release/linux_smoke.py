#!/usr/bin/env python3
"""Launch an existing Linux bundle in a fresh profile under an owned Xvfb.

This is a packaged startup smoke, not playback, audio, or Wayland acceptance.
The SDK and development checkout are absent from the child environment.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


def child(bundle: Path, evidence: Path) -> int:
    executable = bundle / "briani_player"
    result = {"scope": "packaged-startup-Xvfb", "sdkOnPath": False,
              "playbackVerified": False, "systemRuntimeDependencies": "linux-runtime-ldd.log"}
    with tempfile.TemporaryDirectory(prefix="briani-release-home-") as profile:
        env = {"HOME": profile, "XDG_CONFIG_HOME": profile + "/config",
               "XDG_DATA_HOME": profile + "/data", "PATH": "/usr/bin:/bin",
               "DISPLAY": os.environ["DISPLAY"], "LANG": "C.UTF-8"}
        if "XAUTHORITY" in os.environ:
            env["XAUTHORITY"] = os.environ["XAUTHORITY"]
        with (evidence / "linux-packaged-startup.log").open("w") as log:
            process = subprocess.Popen([str(executable)], cwd=bundle, env=env,
                                       stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 20
                window = None
                while time.monotonic() < deadline and process.poll() is None:
                    probe = subprocess.run(["xdotool", "search", "--onlyvisible", "--pid", str(process.pid)],
                                           env=env, capture_output=True, text=True)
                    if probe.returncode == 0 and probe.stdout.strip():
                        window = probe.stdout.splitlines()[0]
                        break
                    time.sleep(0.25)
                if window is None:
                    raise RuntimeError("packaged client did not create a visible window")
                time.sleep(2)
                if process.poll() is not None:
                    raise RuntimeError("packaged client exited during startup")
                screenshot = evidence / "linux-packaged-startup.png"
                subprocess.run(["import", "-window", window, str(screenshot)], env=env,
                               check=True, timeout=10, capture_output=True)
                colors = subprocess.check_output(["magick", "identify", "-format", "%k", str(screenshot)],
                                                 text=True, timeout=10)
                if int(colors) < 32:
                    raise RuntimeError("packaged startup image is blank")
                result.update(status="passed", visibleWindow=True, renderedColors=int(colors),
                              freshProfile=True, screenshot=screenshot.name)
            except (RuntimeError, subprocess.SubprocessError, OSError) as error:
                result.update(status="failed", error=str(error))
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                result["shutdownExitCode"] = process.returncode
    (evidence / "linux-packaged-startup.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0 if result["status"] == "passed" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--inside-xvfb", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    bundle = args.bundle.resolve(strict=True)
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    if not (bundle / "briani_player").is_file():
        parser.error("bundle executable missing")
    if args.inside_xvfb:
        return child(bundle, evidence)
    for command in ("xvfb-run", "xdotool", "import", "magick"):
        if not shutil.which(command):
            parser.error(f"test prerequisite missing: {command}")
    with tempfile.TemporaryDirectory(prefix="briani-release-bundle-") as isolated:
        copy = Path(isolated) / "bundle"
        shutil.copytree(bundle, copy, symlinks=False)
        return subprocess.run(["xvfb-run", "-a", sys.executable, str(Path(__file__).resolve()),
                               "--bundle", str(copy), "--evidence", str(evidence), "--inside-xvfb"],
                              timeout=50).returncode


if __name__ == "__main__":
    raise SystemExit(main())
