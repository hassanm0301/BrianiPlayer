# Pi deployment — 16 October 2026

Status: **running; administrator not yet claimed.** This continues `docs/evidence/M09/pi-deployment-20261015/report.md` and `docs/evidence/M10/landlock-free/report.md`. The only remaining blocker there was Docker `MemoryLimit=false`.

## Host change (user-authorized)

The user explicitly authorized a boot-setting change and reboot on 2026-10-16.

- Backed up `/boot/firmware/cmdline.txt` to `/boot/firmware/cmdline.txt.before-briani-20261016`.
- Appended `cgroup_enable=memory` to the single line of `/boot/firmware/cmdline.txt`. The firmware still injects `cgroup_disable=memory` earlier on the command line; the later Raspberry Pi downstream `cgroup_enable=memory` re-enables it.
- Rebooted. Afterwards: controllers `cpuset cpu io memory pids`, Docker `MemoryLimit=true`, both drives mounted, and the existing Filestash containers restarted on their own.
- Kernel unchanged (`6.18.50+rpt-rpi-2712`). Undo: restore the backup file and reboot.

## Deployment

Launcher: `/home/hassan/briani/package-landlock-free-20261015/briani` (appends `--project /home/hassan/briani/ops`).

| Step | Exit | Evidence |
|---|---:|---|
| `briani doctor` | 0 | `host-and-stack.log` |
| `briani qbit-bootstrap` (pulled pinned qBittorrent digest, stored generated password 0600 in state/secrets) | 0 | `qbit-bootstrap.log` |
| `briani up` (pulled pinned Prowlarr digest, started four services) | 0 | console only; final state in `host-and-stack.log` |
| `briani capture-prowlarr-key` (first attempt succeeded; key stored 0600) | 0 | console only |
| `GET http://192.168.100.186:8088/healthz` from LAN workstation | 200 `alive` | `health.log` |
| `GET http://192.168.100.186:8088/readyz` from LAN workstation | 200 `ready` | `health.log` |

Running services: `briani` (image `briani-server:landlock-free-20261015-arm64`, 1 GiB enforced limit, bound to `192.168.100.186:8088`), `prowlarr` (no published port), `qbittorrent` (no published port), and `torrent-egress-guard` (healthy, 32 MiB enforced limit). qBittorrent and Prowlarr have no memory limit in the generated Compose file; this is the existing design, not a change.

The Briani log shows ASP.NET DataProtection ephemeral-key warnings. The server uses its own opaque-token authentication and does not register DataProtection consumers, so no persisted data depends on those keys.

## Not done / limitations

- The administrator has not been claimed. No libraries, indexers or users were created. The user must run `show-bootstrap-token` and claim the administrator from a client within its 30-minute window, or renew the code.
- No client playback, download, backup/restore, Pi benchmark/soak or release certification was run against this deployment. Release gates stay `blocked_verification`.
- No secret value was displayed or copied into this repository.
