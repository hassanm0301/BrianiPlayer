#!/usr/bin/env python3
"""Assemble the ARM64 helper without executing ARM code or changing the host.

Native amd64 apk installs signature-checked aarch64 packages into an isolated
staging root with package scripts disabled. The final Docker build only copies
files onto the pinned ARM64 Alpine base. Native ARM runtime testing is separate.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DOCKER = ["docker", "--config", str(ROOT / ".tools/docker-config")]


def command(*args: str, capture: bool = False):
    return subprocess.run([*DOCKER, *map(str, args)], check=True,
                          stdout=subprocess.PIPE if capture else None,
                          text=capture, timeout=240)


def main() -> int:
    dockerfile = (ROOT / "infra/images/egress.Dockerfile").read_text()
    base = re.search(r"^FROM (alpine@sha256:[0-9a-f]{64})$", dockerfile, re.M)
    package = re.search(r"^RUN apk add --no-cache (nftables=[0-9A-Za-z.+-]+)$", dockerfile, re.M)
    if not base or not package:
        raise ValueError("review required: helper Dockerfile package/base changed")
    evidence = ROOT / "docs/evidence/M11/arm64-egress-assembly.json"
    with tempfile.TemporaryDirectory(prefix="briani-arm-egress-") as temporary:
        stage = Path(temporary)
        payload = stage / "root"
        payload.mkdir()
        script = (
            'mkdir -p /stage/root/etc/apk/keys; '
            'cp /usr/share/apk/keys/*.pub /stage/root/etc/apk/keys/; '
            'timeout 90 apk --arch aarch64 --root /stage/root --initdb '
            '--repositories-file /etc/apk/repositories '
            '--no-scripts add --no-cache "$BRIANI_PACKAGE"; result=$?; '
            'chown -R "$BRIANI_STAGE_UID:$BRIANI_STAGE_GID" /stage/root; exit "$result"'
        )
        command("run", "--rm", "--name", stage.name, "--label", f"org.briani.release-run={stage.name}",
                "--platform", "linux/amd64", "--read-only",
                "--cap-drop", "ALL", "--cap-add", "CHOWN", "--cap-add", "DAC_OVERRIDE",
                "--security-opt", "no-new-privileges", "--memory", "256m", "--pids-limit", "64",
                "--tmpfs", "/tmp:rw,nosuid,nodev,size=32m", "--mount", f"type=bind,source={stage},target=/stage",
                "-e", f"BRIANI_PACKAGE={package.group(1)}", "-e", f"BRIANI_STAGE_UID={os.getuid()}",
                "-e", f"BRIANI_STAGE_GID={os.getgid()}", base.group(1), "sh", "-c", script)
        nft = payload / "usr/sbin/nft"
        header = nft.read_bytes()[:64]
        if header[:4] != b"\x7fELF" or int.from_bytes(header[18:20], "little") != 183:
            raise ValueError("staged nft is not an ARM64 ELF")
        database = (payload / "lib/apk/db/installed").read_text()
        resolved = []
        for record in database.strip().split("\n\n"):
            fields = dict(line.split(":", 1) for line in record.splitlines() if ":" in line)
            resolved.append({key: fields.get(field) for key, field in
                             (("name", "P"), ("version", "V"), ("architecture", "A"), ("apkChecksum", "C"))})
        for name in ("egress.nft", "guard.sh"):
            shutil.copyfile(ROOT / "infra/network" / name, stage / name)
        (stage / "guard.sh").chmod(0o555)
        (stage / "Dockerfile").write_text(
            f"FROM {base.group(1)}\nCOPY root/ /\nCOPY egress.nft /etc/briani/egress.nft\n"
            'COPY guard.sh /guard.sh\nHEALTHCHECK --interval=5s --timeout=3s --start-period=5s '
            '--retries=3 CMD ["/guard.sh", "verify"]\nENTRYPOINT ["/guard.sh"]\n')
        command("buildx", "build", "--load", "--platform", "linux/arm64", "-t", "briani-egress:m10-arm64", str(stage))
        image = json.loads(command("image", "inspect", "briani-egress:m10-arm64", capture=True).stdout)[0]
        command("image", "save", "-o", str(ROOT / "dist/images/briani-egress-linux-arm64.tar"), "briani-egress:m10-arm64")
        evidence.write_text(json.dumps({"status": "assembled", "nativeRuntimeVerified": False,
            "armCodeExecuted": False, "assembly": "signature-checked apk cross-root; scripts disabled; COPY-only ARM64 build",
            "baseImage": base.group(1), "imageId": image["Id"], "architecture": image["Architecture"],
            "nftSha256": hashlib.sha256(nft.read_bytes()).hexdigest(), "resolvedPackages": resolved,
            "guardSha256": hashlib.sha256((stage / "guard.sh").read_bytes()).hexdigest(),
            "policySha256": hashlib.sha256((stage / "egress.nft").read_bytes()).hexdigest()}, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
