#!/usr/bin/env python3
"""Pinned OpenAPI + Dart serializer generation; no manual generated-code edits."""
from pathlib import Path
import argparse
import hashlib
import shutil
import subprocess
import tempfile
import re

ROOT = Path(__file__).resolve().parents[2]
JAR = ROOT / ".tools/openapi/openapi-generator-cli-7.26.0.jar"
SHA256 = "1760050094997b9cc790cc1350be095f15da8c08a996b184d3eadc4ccda5e35e"
TARGET = ROOT / "client/packages/briani_api"


def generate(destination: Path):
    if not JAR.is_file() or hashlib.sha256(JAR.read_bytes()).hexdigest() != SHA256:
        raise RuntimeError("Missing or mismatched pinned generator; see toolchain.lock.json")
    subprocess.run(["java", "-jar", str(JAR), "validate", "-i", str(ROOT / "contracts/openapi.yaml")], check=True)
    subprocess.run(["java", "-jar", str(JAR), "generate", "-i", str(ROOT / "contracts/openapi.yaml"),
                    "-g", "dart-dio", "-o", str(destination), "-c", str(Path(__file__).with_name("generator-config.json")),
                    "--global-property", "apiTests=false,modelTests=false,apiDocs=false,modelDocs=false"], check=True)
    # The upstream templates have harmless unused private serializers/imports.
    # Apply a narrow deterministic generated-lint preamble; compilation errors
    # and semantic/analyzer diagnostics retain their normal severity.
    for path in (destination / "lib").rglob("*.dart"):
        content = path.read_text()
        existing = set()
        for line in re.findall(r"(?m)^// ignore_for_file: (.*)$", content):
            existing.update(x.strip() for x in line.split(","))
        missing = [x for x in ("unused_import", "unused_field", "unused_element_parameter") if x not in existing]
        path.write_text(("// ignore_for_file: " + ", ".join(missing) + "\n" if missing else "") + content)
    lock = TARGET / "pubspec.lock"
    if destination != TARGET and lock.exists():
        shutil.copyfile(lock, destination / "pubspec.lock")
    args = ["dart", "pub", "get"]
    if (destination / "pubspec.lock").exists(): args += ["--enforce-lockfile"]
    subprocess.run(args, cwd=destination, check=True)
    subprocess.run(["dart", "run", "build_runner", "build"], cwd=destination, check=True)
    subprocess.run(["dart", "analyze"], cwd=destination, check=True)


def tracked(destination):
    return {str(p.relative_to(destination)): p.read_bytes() for p in (destination / "lib").rglob("*.dart")}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.check:
        with tempfile.TemporaryDirectory(prefix="briani-contract-") as folder:
            generated = Path(folder)
            generate(generated)
            before, after = tracked(TARGET), tracked(generated)
            if before != after:
                changed = sorted(k for k in set(before) | set(after) if before.get(k) != after.get(k))
                raise SystemExit("Generated contract drift: " + ", ".join(changed))
            print("PASS: deterministic API and serializer regeneration")
    else:
        generate(TARGET)
