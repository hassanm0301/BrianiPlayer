#!/usr/bin/env python3
"""Report exact package versions recorded by repository lock artifacts."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCKS = (
    ("NuGet API", ROOT / "server/src/Briani.Api/packages.lock.json", "nuget"),
    ("NuGet UnitTests", ROOT / "server/tests/Briani.UnitTests/packages.lock.json", "nuget"),
    ("NuGet ContractTests", ROOT / "server/tests/Briani.ContractTests/packages.lock.json", "nuget"),
    ("NuGet IntegrationTests", ROOT / "server/tests/Briani.IntegrationTests/packages.lock.json", "nuget"),
    ("NuGet IdentityTests", ROOT / "server/tests/Briani.IdentityTests/packages.lock.json", "nuget"),
    ("NuGet MediaTests", ROOT / "server/tests/Briani.MediaTests/packages.lock.json", "nuget"),
    ("NuGet DiscoveryTests", ROOT / "server/tests/Briani.DiscoveryTests/packages.lock.json", "nuget"),
    ("NuGet DownloadTests", ROOT / "server/tests/Briani.DownloadTests/packages.lock.json", "nuget"),
    ("NuGet StreamingTests", ROOT / "server/tests/Briani.StreamingTests/packages.lock.json", "nuget"),
    ("Flutter client", ROOT / "client/pubspec.lock", "pub"),
    ("Flutter generated API", ROOT / "client/packages/briani_api/pubspec.lock", "pub"),
)


def read_packages(path: Path, kind: str) -> list[tuple[str, str]]:
    if kind == "nuget":
        data = json.loads(path.read_text(encoding="utf-8"))
        packages = {}
        for framework in data["dependencies"].values():
            for name, info in framework.items():
                if info.get("type") == "Project":
                    continue
                packages[name] = info["resolved"]
        return sorted(packages.items(), key=lambda item: item[0].lower())
    text = path.read_text(encoding="utf-8")
    packages: list[tuple[str, str]] = []
    current: str | None = None
    for line in text.splitlines():
        heading = re.match(r"^  ([^ #][^:]*):\s*$", line)
        version = re.match(r'^    version:\s*["\']?([^"\']+)', line)
        if heading:
            current = heading.group(1)
        elif current and version:
            packages.append((current, version.group(1)))
            current = None
    if not packages:
        raise ValueError(f"No locked packages parsed from {path}")
    return sorted(packages, key=lambda item: item[0].lower())


def main() -> int:
    rows = ["# Dependency inventory", "",
            "Versions below are read directly from committed lock artifacts. This inventory does not assert license approval or vulnerability status.", ""]
    for label, path, kind in LOCKS:
        if not path.is_file():
            print(f"Missing required lock artifact: {path.relative_to(ROOT)}")
            return 2
        packages = read_packages(path, kind)
        rows.extend((f"## {label}", "", f"Source: `{path.relative_to(ROOT)}` ({len(packages)} locked packages)", "",
                     "| Package | Locked version |", "|---|---|") )
        rows.extend(f"| `{name}` | `{version}` |" for name, version in packages)
        rows.append("")
    output = ROOT / "docs/development/dependency-inventory.md"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(rows).rstrip() + "\n", encoding="utf-8")
    print(f"Wrote {output.relative_to(ROOT)} from {len(LOCKS)} committed lock artifacts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
