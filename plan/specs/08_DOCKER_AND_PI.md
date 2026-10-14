# 08 — Docker deployment, Pi 5 and operations

## Supported server environment

Production server deployment supports Docker Engine + Compose on 64-bit Linux ARM64 and amd64. Raspberry Pi 5 runs a supported 64-bit Raspberry Pi OS/Debian-derived distribution, active cooling under sustained loads, stable power and wired Ethernet where practical. No 32-bit image, Docker Desktop server guarantee, native service installer, Kubernetes chart or multi-node clustering.

Docker's Raspberry Pi guidance distinguishes 64-bit installation from its deprecated 32-bit path. LinuxServer documents ARM64/amd64 images for Prowlarr and qBittorrent. Media/state stored in mounts avoids container writable-layer I/O. These facts do not prove application benchmarks. Sources S13–S16.

The Docker-only requirement concerns the **server runtime**. Flutter desktop/Android clients, SDKs, emulators and platform signing tools are not Dockerized end-user applications. Windows/macOS client builds require appropriate host runners.

## Compose services

`briani`: application, SQLite, probes/thumbnails and streaming gateway. `/config` read/write; `/data` read/write for managed libraries; secrets read-only. Expose port 8088 internally; external binding explicitly chosen.

`qbittorrent`: dedicated managed torrent service. Separate `/config`; shared `/data` with identical absolute paths. Authenticated Web API accessible over service DNS. Stable tested libtorrent 2 image, pinned digest. Optional peer transport port 6881 TCP+UDP or configured equivalent; never confuse with its API port.

`prowlarr`: own `/config`, no `/data`; outbound indexer access. API private. Optional localhost-only administration port 9696 for the administrator. Briani does not configure qBittorrent as a Prowlarr download client; Briani itself resolves and controls downloads.

Optional Compose profiles: `test` (fixture indexer and isolated seeder), `proxy` (TLS reverse proxy), `maintenance` (one-shot backup/restore tools). No profile changes the product requirement to use Docker. Do not combine all three production daemons inside one giant container.

## Required generated deployment artifacts

M01/M09 produce `compose.yaml`, `.env.example`, restrictive `secrets/` creation script, tested bootstrap command, health checks, directory/permissions check, pinned `images.lock.json`, image build files and a README. The plan deliberately does not invent a public Briani image name/digest before one is built.

Use Compose variables for image refs, host state/data directories, UID/GID, timezone, API bind and peer port. Require critical paths/secrets explicitly instead of dangerous silent defaults. The installer validates 64-bit architecture, mounted disk availability, write permissions, root overlaps, available bytes, service DNS, secret lengths and a compatible database location.

Bind one complete library filesystem tree into the same `/data/...` location in both relevant containers. Downloads/staging and visible hard links must share a filesystem. Store SQLite/state on local SSD storage, not SMB/NFS. MicroSD may host the OS; it is not the default download/database target. SSD/NVMe is the reference setup, with ext4 preferred for predictable local-file semantics. Other filesystems must pass the storage matrix; hard-link absence uses virtual entries rather than automatic copying.

## Initial performance targets — not measured claims

Reference system: Pi 5, 4 GiB RAM, 64-bit OS, active cooling, USB 3 SSD or NVMe, wired Gigabit LAN, no other heavy service. An 8 GiB model provides more headroom but does not remove I/O/network constraints. Media decoding runs on a different client.

| Measure | Acceptance target |
|---|---|
| Idle combined working set | Aim <= 900 MiB for Briani + qBittorrent + Prowlarr; report container RSS/working set separately from reclaimable page cache. |
| Loaded combined working set | Aim <= 1.8 GiB under reference test; no swap thrashing or unbounded growth. |
| Briani process | Aim <= 250 MiB idle and <= 512 MiB under the reference workload. |
| Completed-file throughput | >= 40 MiB/s on an independently verified >=80 MiB/s storage/network path; report cold/warm cache separately. |
| Concurrent media workload | Two 25 Mbit/s completed streams plus one 15 Mbit/s torrent download for 30 minutes without server-caused corruption/timeouts. |
| Progressive playback | One 15 Mbit/s fixture video, controlled available download rate >=25 Mbit/s, no starvation after startup except intentional fault phases. |
| Control API latency | Warm p95 <250 ms for cached lists/basic control operations at five concurrent users; external search excluded. |
| Library browser | 10,000 indexed items; paginated UI, no full-tree load per screen. |
| Idle control CPU | Target <10% of one CPU core for Briani background coordination with no scans/searches. Report exact measurement definition. |
| Reader cancellation | Release waiting reader within 2 seconds of client disconnect. |
| Memory soak | No monotonic retained-memory growth >10% after repeated stabilized playback sessions; use heap/working-set evidence, not one snapshot. |

These are optimization gates, not universal guarantees. When underlying network/storage misses the reference baseline, report environment-limited results rather than downgrading correctness or claiming a server defect without evidence.

## Pi-oriented defaults

Authoritative numeric values are in `contracts/defaults.json`. Two active downloads total, one per user, two active seed jobs, global connection cap 100 and per-torrent 40. Begin with a 2 MiB/s global upload cap to avoid saturating modest uplinks; administrator can change it, with tracker rules respected. No arbitrary low download cap; admission/connection limits protect the host. One metadata fetch/probe/thumbnail worker at a time by default.

Piece polling is shared across viewers, and not stored in SQLite. HTTP uses 256 KiB pooled copy buffers; at most four parallel range requests per session and 16 globally. No server video cache proportional to file size. Cache thumbnails on disk (default 512 MiB LRU) and normalized discovery results; memory is bounded. Pause heavy thumbnail work while playback/download I/O is congested.

Enforce soft budgets/alerts before tight container memory limits. Page cache and native library memory can make overly strict hard caps cause OOM failures. Publish tested `mem_limit` suggestions only after the measured profile; do not confuse a configured cap with proof of fitting within it.

## Startup and health

Apply database migrations once under a lock; reject concurrent server replicas. `/healthz` indicates process liveness. `/readyz` checks database/startup readiness without making completed-file playback fail merely because a discovery provider is down. Administrative health reports upstream versions, latency, storage, queue limits, thumbnail jobs and compatibility-gate status.

Compose startup ordering is convenience, not resilience: clients/HttpClients must tolerate dependencies restarting later. Use `restart: unless-stopped`, graceful cancellation and adequate stop grace (default 60 seconds). In shutdown, stop new commands, cancel readers, finish/checkpoint short database work and let qBittorrent persist resume state.

## Credentials and Prowlarr onboarding

Generate unique qBittorrent credentials and Prowlarr API access, or import them through a protected setup path. Never ship shared default secrets. Some upstream images emit a temporary password; bootstrap scripts must follow the pinned image's documented behavior, replace it once, and prevent exposure in persistent logs. Do not assume an unsupported environment variable sets a password.

Complex source configuration stays in the upstream Prowlarr UI on loopback/SSH tunnel. Briani's native administration offers status, enabled source/category choices and connection tests. It should not reproduce every indexer's configuration schema. Normal users see only enabled provider results.

## Backups and upgrades

Full-stack backup is a host-invoked **Docker maintenance operation**, not giving Briani the Docker socket. The script enters maintenance, stops writing services cleanly, snapshots/copies all state directories plus application keys/lock metadata, and restarts services in a trap/finally path. Media backup is separate and optional due to size. Explain that configuration backup does not protect the video collection.

An in-app “application database snapshot” may use SQLite's backup API, but label it accurately: it is not a full qBittorrent/Prowlarr/keys backup. Encrypt off-host backups with user-managed keys; do not invent credentials or upload destinations.

Upgrade procedure: validate free space and architecture, back up state, pull **pinned** tested images, verify compatibility, migrate, health-check, run a smoke test. No `latest` auto-updates/Watchtower in the reference deployment. Rollback requires restoring a compatible database snapshot if migrations are not backward-compatible; restarting an old binary against a newer schema is not a rollback plan.

Test restore on a separate Compose project with different ports/data roots. Never test destructive restores against the actual library. Retain image digests and migration version with each backup.

## Remote access

Default usage is LAN or existing VPN. Support HTTPS through a tested optional proxy profile; no need for a public domain to use a VPN. For direct internet exposure, TLS, rate limits, authentication, strict trusted-forwarder configuration and documented firewall rules are mandatory. No automatic port forwarding or provider-specific VPN container integration in v1. The external player must reach the same public/LAN URL and trust its certificate.

Docker bridge networking does not automatically isolate a torrent's egress from the host/LAN. Apply and test the security policy in specification 07, allowing only necessary service traffic and explicitly authorized peers; do not disable the firewall to make a fixture pass.

## Pi acceptance and limitations

The Pi does not run mpv for server video playback. High-bitrate delivery is bounded by disk, Ethernet, peer bandwidth and concurrent workload. Probe/thumbnail work is serialized. Hardware-accelerated transcoding, 4K encoding, DRM, tone mapping and AI metadata are absent. Hardware health (temperature/throttling/power warnings), CPU, memory, disk latency and network throughput accompany every performance report.
