# Pi deployment — 15 October 2026

Status: **staged; blocked_verification**. The user authorized SSH and a Compose deployment to `hassan@192.168.100.186`, then requested media on both `hassan_drive` and `family_drive`. This renews access for this deployment; it does not authorize benchmarks or kernel replacement. The user has not approved a kernel change and requested an explanation of that option.

## Work performed

- Connected using the existing SSH identity and known host key. Host: Debian 13, ARM64, kernel `6.18.50+rpt-rpi-2712`, Docker 29.8.1, Compose v5.5.1, Python 3.13.5.
- Copied a private deployment package to `/home/hassan/briani/package-20261015`. Verified both ARM64 archives against `dist/SHA256SUMS`, verified all nine transferred payload files against the new package manifest, and loaded the two images. The loaded runtime config IDs match the accepted ARM64 records in `images.lock.json`.
- Used the current operations/Compose source snapshot, adding an identical Family bind to Briani and qBittorrent in the deployment copy only. Retained the locked server image; the subsequent uncommitted server optimizations are not included in that image. The package manifest records this bundle independently of the older release archive.
- Created the protected Compose project at `/home/hassan/briani/ops`, identity `briani-ops-ae2b50f79f`, for UID/GID 1000:1000 and planned binding `192.168.100.186:8088`.
- Created new dedicated folders only. State: `/mnt/hassan_drive/briani/state`; Hassan media: `/mnt/hassan_drive/briani/media/Hassan`; Family media: `/mnt/family_drive/briani/media`. Containers receive the primary media root as `/data` and the second disk as `/data/Family`; Hassan is `/data/Hassan`. New directories are owner-only, with inherited ACLs removed on the new Briani parent directories. Existing media/torrent folders were untouched.
- Added a package-scoped `docker` wrapper invoking existing `sudo -n /usr/bin/docker` access. The operations tool still runs as hassan. No Docker group membership, socket mode, sudo policy, or global PATH was changed. The `briani` launcher checks both mounted disks before operations.
- Left a handoff at `/home/hassan/briani/README.txt`. Removed only the verified transfer tar; the extracted package and image archives remain.

## Verification and commands

Commands below ran on the Pi unless labeled local. The launcher appends `--project /home/hassan/briani/ops`.

| Check | Command / action | Exit | Evidence |
|---|---|---:|---|
| Local operations regressions | `python3 -m unittest discover -s tests/operations -v` | 0; 30 passed | `operations-tests.log` |
| Archive checksums | Python SHA-256 comparison with `dist/SHA256SUMS` | 0 | `package-manifest.json` records both archive hashes |
| Transfer verification and image load | Verify manifest; `sudo -n docker image load -i` each ARM64 archive | 0 | `preflight.json` records loaded config IDs/architecture |
| Deployment init | `package-20261015/briani init --state /mnt/hassan_drive/briani/state --data /mnt/hassan_drive/briani/media --bind 192.168.100.186 --hosts 'localhost;127.0.0.1;briani;raspberrypi;192.168.100.186' --uid 1000 --gid 1000 --image briani-server:m10-arm64 --local-image` | 0 | `init.log` |
| Required preflight | `/home/hassan/briani/package-20261015/briani doctor` | **2** | `doctor.log` |
| Compose rendering | `sudo -n docker compose --project-directory /home/hassan/briani/ops config --format json` | 0 | `compose-config.log` |
| Bind assertions | Check both services' primary/Family sources, `create_host_path: false`, LAN bind, and absence of upstream published ports | 0 | Rendered config above |
| Container inventory | `sudo -n docker compose --project-directory /home/hassan/briani/ops ps --all --format json` | 0; empty | `compose-ps.log` |
| Host capability/config and final service inventory | Read-only syscall/config/Docker queries | 0 | `preflight.json` |

## Blocking findings

1. `/boot/config-6.18.50+rpt-rpi-2712` has `# CONFIG_SECURITY_LANDLOCK is not set` and `CONFIG_LSM=""`. Both Landlock ABI and ERRATA syscalls return `-1`, errno 38 (`ENOSYS`). This is compiled-out support, not simply a missing boot flag. All ten installed kernel config files also omit Landlock. The installed and locally advertised candidate `linux-image-rpi-2712` package is `1:6.18.50-1+rpt1`; package indexes were not refreshed.
2. Docker reports `MemoryLimit=false`. The active controllers are `cpuset cpu io pids`, and the active command line contains `cgroup_disable=memory`. The kernel was built with `CONFIG_MEMCG=y`, but memory control is disabled at boot.

The repository operations preflight and the server sandbox both require these capabilities. No checks were disabled. No Briani/qBittorrent/Prowlarr/guard containers were started. No credentials, administrator, libraries, or indexers were created. Existing Filestash containers were running at the final check. Kernel, boot settings, other services, and router configuration were not modified.

Linux's [Landlock documentation](https://docs.kernel.org/userspace-api/landlock.html) requires build-time `CONFIG_SECURITY_LANDLOCK=y` and boot enablement. The Raspberry Pi maintainers [document the downstream `cgroup_enable=memory` setting](https://github.com/raspberrypi/linux/issues/6980); it still requires actual verification after reboot. A compatible kernel must also satisfy Briani's ABI >=2 and ERRATA bit 4 checks; a version string or build option alone is insufficient proof.

## Independent review and continuation

Read-only reviewer: GPT-6 Sol/medium. It confirmed the host blockers, the non-root operations identity requirement, package freshness distinction, and the two-drive path design. Per-library staging/import and free-space checks use the destination library's filesystem; both containers must receive the same nested bind. The launcher adds the second mount check absent from the stock doctor. Neither the reviewer nor the parent claims runtime verification of this layout on the Pi.

Kernel replacement/reboot needs a separately reviewed change and user authorization because it affects the whole host. No candidate replacement kernel has been built, selected, or installed. If the host later passes `doctor`, continue `qbit-bootstrap` → `up` → `capture-prowlarr-key`, then check `/healthz` and `/readyz`, claim the administrator interactively, and create separate Hassan/Family libraries. Do not run plain Compose to bypass the blocked preflight. Both media trees remain excluded from configuration-only backups.

M09's earlier implementation results remain intact. This deployment does not pass T27/native clean installation, the Pi benchmark gates, or any release certification gate. Full-stack drills and client tests were not rerun against this blocked host.
