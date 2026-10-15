"""Recorded one-off verification on hassan@192.168.100.186; generated fixtures only."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

base = Path('/home/hassan/briani')
verification = base / 'landlock-free-verification-20261015'
package = base / 'package-landlock-free-20261015'
archive = verification / 'briani-server-arm64-final.tar'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == 'b835466e416b52ea079dc5a0e6222e464e05b43fc7bf5ef08723a093f2639395'
assert hashlib.sha256((verification / 'probe/Briani.Api.dll').read_bytes()).hexdigest() == 'b3029bb1bbfad964d3283ffa7b7068de6092c2352b0b7907383163af6ee761ac'
subprocess.run(['sudo', '-n', 'docker', 'load', '--input', str(archive)], check=True, timeout=120)
actual = subprocess.run(['sudo', '-n', 'docker', 'image', 'inspect', 'briani-server:landlock-free-20261015-arm64', '--format', '{{.Id}} {{.Architecture}}'], check=True, text=True, capture_output=True).stdout.strip()
assert actual == 'sha256:101712497fce90e254adb3b9576bb50582fd6f81a3535b8be43c1bf840d52c64 arm64'
print('PASS image, probe assembly hashes and ARM64 runtime identity', flush=True)

def run_probe(compose, env=None):
    command = ['timeout', '--signal=TERM', '--kill-after=10s', '60s', 'sudo', '-n']
    if env:
        command.append('--preserve-env=BRIANI_PROBE_FIXTURE')
    command += ['docker', 'compose', '-f', str(verification / compose), 'run', '--rm', '--no-deps', 'probe']
    print(json.dumps(command), flush=True)
    result = subprocess.run(command, env=env)
    print('EXIT CODE:', result.returncode, flush=True)
    assert result.returncode == 0

for drive in ('hassan_drive', 'family_drive'):
    mount = Path('/mnt') / drive
    subprocess.run(['mountpoint', '-q', str(mount)], check=True)
    fixture = mount / 'briani/containment-probe-20261015'
    fixture.mkdir(mode=0o700)
    print('DRIVE:', drive, flush=True)
    run_probe('pi-probe.compose.yaml', dict(os.environ, BRIANI_PROBE_FIXTURE=str(fixture)))
    fixture.rmdir()  # Only succeeds if the probe removed its own generated data.

h = Path('/mnt/hassan_drive/briani/mounted-containment-probe-20261015')
f = Path('/mnt/family_drive/briani/mounted-containment-probe-20261015')
h.mkdir(mode=0o700)
f.mkdir(mode=0o700)
for path in (h / 'data', h / 'config', h / 'data/Hassan', h / 'data/Family'):
    path.mkdir(mode=0o700)
run_probe('pi-mounted.compose.yaml')
for path in (h / 'data/Hassan', h / 'data/Family', h / 'data', h / 'config', h, f):
    path.rmdir()
for project in ('briani-containment-probe-20261015', 'briani-mounted-probe-20261015'):
    remaining = subprocess.run(['sudo', '-n', 'docker', 'ps', '-a', '--filter', 'label=com.docker.compose.project=' + project, '--format', '{{.Names}}'], check=True, text=True, capture_output=True)
    assert not remaining.stdout.strip()
print('PASS all generated fixtures and test containers removed', flush=True)

shutil.copy2(archive, package / 'dist/images/briani-server-linux-arm64.tar')
lock_path = package / 'images.lock.json'
lock = json.loads(lock_path.read_text())
lock['services']['briani']['nativeArm64'].update(
    localImageId='sha256:ffa6cea3d8eecada770f882c79cb6f0403932c5eb496f670f091e41ce5724cb1',
    runtimeConfigDigest='sha256:101712497fce90e254adb3b9576bb50582fd6f81a3535b8be43c1bf840d52c64',
    buildEvidence='docs/evidence/M10/landlock-free/image-arm64-build-final.log',
    verificationStatus='native_two_drive_and_nested_bind_containment_passed_full_stack_blocked_memory_controller')
lock_path.write_text(json.dumps(lock, indent=2) + '\n')
manifest_path = package / 'manifest.json'
manifest = json.loads(manifest_path.read_text())
for entry in manifest['files']:
    content = (package / entry['path']).read_bytes()
    entry.update(sha256=hashlib.sha256(content).hexdigest(), bytes=len(content))
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
result = subprocess.run([str(package / 'briani'), 'doctor'], text=True, capture_output=True)
print(result.stdout, result.stderr, 'DOCTOR EXIT CODE:', result.returncode, flush=True)
assert result.returncode == 2 and 'memory' in result.stderr.lower() and 'openat2' not in result.stderr and 'Landlock' not in result.stderr
print('PASS updated preflight rejects production startup for missing memory enforcement only', flush=True)
