# Briani Player — repository instructions

The implementation specifications live under `plan/`. This file is intended for the repository root.

## Fixed invariants

- Build a simple, highly configurable media file browser, not a Jellyfin clone.
- Server: C#/.NET 10 LTS, ASP.NET Core Minimal APIs, EF Core/SQLite, Docker Compose only. ARM64 Raspberry Pi 5 and Linux amd64. No native-server installer.
- Clients: Flutter, Linux/Windows/macOS, Android mobile and Android TV. Embedded `media_kit`/libmpv and external-player handoff. No browser client or iOS target.
- Discovery: Prowlarr only. Latest, Most seeded and text search. Name, size, reported seeders and peers/leechers. No Stremio/Torrentio, per-site scrapers, movie catalog providers or Usenet.
- Torrent engine: qBittorrent-nox, sequential downloads. Playback while downloading is mandatory. No seek-driven piece prioritization, no new torrent engine by default.
- Serve only valid available bytes. No sparse-file zeros, invalid early EOF, or plain static-file serving for incomplete data. Mapping includes multifile offsets and padding.
- No server-side transcoding/remuxing, no HLS, no media decoding on the Pi. Bounded FFprobe/thumbnails only.
- Every file, image, thumbnail, subtitle, download action and playback ticket is authorized server-side. Never accept an arbitrary filesystem path from a regular user.
- Advanced features belong in settings/context menus; TV must remain fully usable without a mouse or touch.
- Never guess test results, benchmarks, licenses, package versions, model identifiers or upstream API behavior.

## Work method

Read `plan/00_START_HERE.md`, then the active milestone and only its required specifications. Follow `plan/agents/EXECUTION_PROTOCOL.md`. The parent uses Sol high; routine workers use the configured lower-cost model. Use at most two concurrent implementation workers by default and a separate review pass. Each worker owns explicit paths. One owner edits contracts, migrations and shared manifests.

Implement, test, integrate, and record evidence. Do not substitute another planning document for working code. Do not overwrite another worker's changes, run destructive git commands, broaden permissions, disable security/tests, or download copyrighted test media to make a gate pass. Use generated or appropriately licensed fixtures and an isolated swarm.

On genuine uncertainty, inspect the locked upstream version and run a bounded experiment. The relevant plan contains the escalation path. Preserve requirements and report blockers honestly. Do all independent unblocked work before handing back.

## Completion

Run the milestone's tests plus relevant regression suites. Update `plan/evidence/status.json` and a repository `docs/evidence/Mxx/` handoff with commands, exit codes, artifact locations, limitations and review findings. Missing hardware or signing access means `blocked_verification`, not `complete` for that gate. Do not publish, spend money, change real indexer accounts, forward router ports, or modify production data without the user's authorization.
