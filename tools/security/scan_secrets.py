#!/usr/bin/env python3
"""Small repository secret scanner with explicit, testable detectors."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKIP_DIRS = {".git", ".dart_tool", "build", "bin", "obj", ".tools", "node_modules", "__pycache__"}
PLACEHOLDERS = {"changeme", "change-me", "example", "placeholder", "your-token", "test-secret", "dummy", "isolated-test-credential"}
RULES = (
    ("private-key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("aws-access-key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("github-token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})\b")),
    ("credential-assignment", re.compile(
        r"(?i)\b(api[_-]?key|access[_-]?token|client[_-]?secret|password|secret)\b"
        r"\s*[:=]\s*(?:['\"]([A-Za-z0-9_./+=-]{16,})['\"]|"
        r"([A-Za-z0-9_+=-]{16,})(?=\s*(?:#|$)))"
    )),
)


def scan_text(text: str) -> list[tuple[str, int]]:
    findings: set[tuple[str, int]] = set()
    for number, line in enumerate(text.splitlines(), 1):
        for name, pattern in RULES:
            for match in pattern.finditer(line):
                value = (match.group(2) or match.group(3)) if name == "credential-assignment" else match.group(0)
                if name == "credential-assignment" and value.lower() in PLACEHOLDERS:
                    continue
                findings.add((name, number))
    return sorted(findings)


def scan_tree(root: Path) -> list[tuple[Path, str, int]]:
    findings = []
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if (not path.is_file() or path.name.endswith(".g.dart")
                or relative.as_posix() == "tests/tools/test_scan_secrets.py"
                or any(part in SKIP_DIRS for part in relative.parts)):
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        findings.extend((path, rule, line) for rule, line in scan_text(content))
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    findings = scan_tree(args.root)
    if findings:
        for path, rule, line in findings:
            print(f"{path.relative_to(args.root)}:{line}: {rule}")
        print(f"Found {len(findings)} potential secret(s)")
        return 1
    print("Secret scan passed: no supported credential patterns found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
