#!/usr/bin/env python3
"""Apply one bounded stop/start fault to explicit fixture Compose containers."""
from __future__ import annotations
import argparse
import json
import re
import subprocess
import sys


def main(argv=None, runner=subprocess.run):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project", required=True)
    p.add_argument("--container-id", action="append", required=True)
    p.add_argument("--action", required=True, choices=("stop", "start"))
    args = p.parse_args(argv)
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}", args.project):
        print("invalid project", file=sys.stderr); return 2
    if not args.container_id or len(set(args.container_id)) != len(args.container_id) or any(not re.fullmatch(r"[a-fA-F0-9]{12,64}", x) for x in args.container_id):
        print("explicit unique full container IDs required", file=sys.stderr); return 2
    try:
        inspected = runner(["docker", "inspect", *args.container_id], check=True, capture_output=True, text=True, timeout=20)
        entries = json.loads(inspected.stdout)
        if len(entries) != len(args.container_id):
            raise ValueError("inspect result mismatch")
        for item in entries:
            labels = item.get("Config", {}).get("Labels") or {}
            if (labels.get("com.docker.compose.project") != args.project
                    or labels.get("org.brianiplayer.fixture") != "true"
                    or labels.get("com.docker.compose.service") not in {"briani", "qbittorrent", "prowlarr"}):
                raise ValueError("container lacks fixture Compose ownership labels")
            current = item.get("State", {}).get("Status")
            if args.action == "stop" and current != "running":
                raise ValueError("stop target is not running")
            if args.action == "start" and current not in {"exited", "created"}:
                raise ValueError("start target is not an exited fixture container")
        # One bounded Docker action; no name discovery, kill, rm or host mutation.
        runner(["docker", args.action, *args.container_id], check=True, capture_output=True, text=True, timeout=30)
        print(f"fixture fault applied: {args.action} to {len(entries)} explicit container(s)")
        return 0
    except (OSError, subprocess.SubprocessError, ValueError, json.JSONDecodeError) as exc:
        print(f"blocked_environment: {exc}", file=sys.stderr); return 3


if __name__ == "__main__":
    raise SystemExit(main())
