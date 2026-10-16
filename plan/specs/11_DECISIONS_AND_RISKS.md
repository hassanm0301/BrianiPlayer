# 11 — Final decisions, corrections and contingencies

## Decision register

| ID | Decision |
|---|---|
| D01 | File-oriented media browser, not a full media-center metadata/catalog platform. |
| D02 | Docker-only Linux server; native clients are not Docker applications. |
| D03 | C#/.NET 10 LTS Minimal APIs + EF Core/SQLite. No Go preference from prior user experience. |
| D04 | Flutter clients; native desktop/Android/TV only. Web removed, iOS not added. |
| D05 | Prowlarr only for torrent discovery; Stremio/Torrentio explicitly excluded. |
| D06 | qBittorrent-nox/libtorrent 2.x remains the production engine, locked after proof. |
| D07 | Playback before download completion required; sequential only, no seek scheduling. |
| D08 | Fixed first/last metadata assist allowed, not dynamic piece deadlines. |
| D09 | Embedded media_kit/libmpv; external compatible players as a first-class option. |
| D10 | No server transcoding/remuxing/HLS; clients decode; serialized inspection/thumbnails. |
| D11 | Same-filesystem staging/hard-link import with stable payload; virtual entries when links unavailable. |
| D12 | If direct piece-gated file reads cannot be made safe with the pinned qBittorrent, use a narrow same-engine compatibility bridge, not silent unsafe reads or a second engine. |
| D13 | If required ordinary Android embedded playback cannot be repaired in media_kit, use a small Media3 Android adapter behind the existing interface; desktop stays libmpv. HDR-only differences are documented, not automatic trigger for a rewrite. |
| D14 | Scoped renewable-by-activity playback sessions, no normal login token exposed to external players. |
| D15 | Functionality-first, progressive disclosure, curated customization, no plugin framework. |
| D16 | One active server process/database owner, bounded jobs, generated API client, small modules. |
| D17 | Baseline distribution policy anticipates copyleft/native dependencies; verify exact artifacts and corresponding source before publishing. No assumed “MIT because the Flutter wrapper is MIT.” |
| D18 | Sol high parent, bounded lower-cost workers; evidence-led integration and honest hardware blockers. |

## Corrections to earlier discussion

- Sequential download is not enough on its own to safely expose an incomplete file.
- File progress percentage and allocated size do not identify a contiguous valid byte range.
- A downloaded piece notification and durable/readable data can be different events; pin/test exact implementation.
- First/last-piece priority does not guarantee the whole metadata structure needed by every container.
- With the pinned qBittorrent 5.2.4/libtorrent 2.0.15, a file-priority change can silently drop the first/last boost: libtorrent rebuilds piece priorities when its asynchronous file-priority job finishes, after qBittorrent applied the boost. Briani re-asserts the same fixed assist (an off/on toggle, under the job lock) until the assist pieces arrive, and an MP4/MOV is eligible only once its whole `moov` box is verified (2026-10-16 measurements: `prototypes/downloads/engine/run_piece_order_experiment.py`).
- mpv is not the torrent engine, and no player choice removes the server's availability problem.
- Android TV HDR/hardware decoding and external-player handling are device-specific. Do not characterize one engine as universally best.
- “All popular torrents” is not an achievable coverage promise from one finite provider query. Most seeded is a local result-set ranking.
- Playback URLs must remain usable for later range requests through a long viewing session; a tiny fixed expiry is not sufficient.
- Docker does not eliminate mount permissions, memory/disk bottlenecks or network egress risk.
- Native client builds and physical hardware testing still need their appropriate environments, even with a Docker-only server.

## D12 — Predetermined same-engine fallback

### Trigger

M00 demonstrates a reproducible inability to map layout safely, fetch metadata without unintended payload, or read correct progressive bytes through the pinned stock engine/storage path. First fix the adapter, use the documented stable API correctly, and test a supported stable image. Do not activate this fallback because a fixture is broken or a worker guessed an endpoint.

### Contained implementation

Maintain the smallest audited qBittorrent patch needed, built as the same qBittorrent service on ARM64/amd64. No second swarm, no duplicate downloads, no new production language/runtime beyond the engine's existing native build. Keep patch files/build instructions, matching upstream source and test evidence.

The private authenticated adapter extension may expose:

- `GET /api/v2/briani/layout?hash=...`: immutable engine-native file IDs, exact offsets/sizes/piece ranges, padding flags and generation. Use the engine's torrent metadata rather than reinterpreting it inconsistently.
- `GET /api/v2/briani/piece?hash=...&index=...`: return one verified piece through libtorrent's own asynchronous read mechanism, or an explicit not-ready/error response. Never read missing raw file regions or call a priority/deadline setter. Range/file slicing and user authorization stay in Briani Server.
- Only if metadata selection is otherwise impossible, a bounded metadata-only request using the engine's supported native metadata flow, without starting payload transfer.

Extension endpoints remain on the private authenticated qBittorrent API. Validate indexes and lifecycle, bound concurrent reads and allocations, cancel abandoned requests, correlate native completion/error alerts, and invalidate generations on maintenance/reload. Do not block the Qt event loop while waiting for alerts. Do not retain a native alert buffer after its documented lifetime; copy/own it safely. Add independent native/HTTP tests and ensure no unauthenticated/public piece endpoint exists.

This fallback adds maintenance burden, which is why stock qBittorrent plus a proven read path is preferred. It is preauthorized as a design contingency within the plan, not proof that a working patch already exists. Record activation in an ADR and rerun all M00 gates. If correctness remains unresolved, mark the playback gate failed and keep independent modules progressing; do not delete the required feature to call the release complete.

## D13 — Android playback fallback

First test pinned native binaries, Android surfaces, hardware decoding and lifecycle. Reproduce on a real target; an emulator-only codec limitation is not evidence all TVs fail. For a required baseline format that remains broken, implement `Media3PlaybackAdapter` only on Android through a minimal native channel with the same state/control interface, native surface, audio focus and track reporting. Do not introduce Compose Multiplatform or a second whole UI codebase.

Keep media_kit on desktop. Document unsupported advanced subtitle/HDR cases accurately, retain external playback, rerun progressive-range tests against both engines and update the compatibility matrix. No server transcoding is introduced as a hidden fix.

## Risk register and response

| Risk | Detection | Required response |
|---|---|---|
| Incomplete-file corruption | Byte oracle, sparse-file and restart/recheck tests | Hard gate; correct map/read lifecycle or D12. |
| Container metadata delays | Faststart/tail-MP4/MKV fixture matrix | Show metadata wait; fixed assist only; no false instant-start promise. |
| Swarm slower than video | Controlled starvation test | Buffer/resume; show state; no uptime promise. |
| One slow peer holds the next sequential piece (head-of-line) | Fast + slow seeder experiment: the contiguous edge stalled 15–21 s while later pieces kept arriving; on a real swarm, 2.5 min at 84% downloaded | Open, owner decision needed. A stop/start nudge was measured worse (66–123 s stalls) and is rejected. Remaining options change D08 or need D12: engine piece timeouts/deadlines, or accept buffering. |
| Multi-file selection/padding | v1/v2/hybrid fixture offsets | Exact map and cross-check; fail closed. |
| ARM native dependency gaps | Native image/player smoke | Pin compatible builds; report platform blocker, never substitute emulated benchmark. |
| Prowlarr outage/changes | Version/contract tests, health | Cached partial results and retry; upstream-only provider support. |
| TV focus or renderer problems | D-pad end-to-end and physical TV | Fix native integration/UX; D13 only for baseline playback. |
| Hard-link unsupported | Installer/import filesystem test | Virtual managed entries, no silent copy. |
| Seeding data removed | Import/removal/restart tests | Separate visible link and payload ownership; journal lifecycle. |
| Disk full/host power loss | Admission tests and kill/restart | Pause writes safely, retain durable intents, recheck uncertain data; no auto-delete. |
| Secrets in URLs/logs | Automated canary/redaction tests | Hash scoped tickets, redact at every layer, revoke exposure. |
| Token-cost explosion | Per-milestone delegation/evidence review | Small worker contexts, no duplicate repo scans, no unnecessary subagents. |
| Unavailable hardware/keys | Environment doctor | Truthful blocked verification; continue unrelated code, no fake release claim. |
| Copyleft/license mismatch | Per-binary manifest/SBOM review | Ship compatible source/notices or change offending build before distribution. |

## Remaining “decisions” are implementation mechanics

Patch versions, actual artifact checksums, native package build flags, runner identities, compiler fixes and measurements are filled in by the milestones. No user brainstorming is needed to decide whether core functionality exists. Credentials, physical access and release authorization cannot be fabricated by a plan; lack of access is reported distinctly from incomplete coding.
