# 13 — Requirements traceability and discussion history

This table is the implementation coverage contract. During M10/M11, add actual code paths and evidence links beside these planning references. Every test starts `not_run`; this document does not establish that any feature exists.

| Requirement | Principal specifications | Implementation milestone | Acceptance tests |
|---|---|---|---|
| R01 Docker-only ARM64/amd64 server | 02, 08, 10 | M01, M09, M11 | T25, T27, T30 |
| R02 desktop/mobile/TV clients | 06, 10 | M07, M08, M11 | T20, T22, T23, T27, T30 |
| R03 users/server profiles/grants | 03, 06, 07 | M02, M07, M08 | T15, T18, T31 |
| R04 directory libraries | 02, 03, 07 | M02, M03 | T14, T16, T25 |
| R05 file-oriented media browsing | 03, 06 | M03, M07 | T15, T16, T23, T29 |
| R06 photos | 03, 06, 07 | M03, M07, M08 | T24 |
| R07 embedded playback | 05, 06 | M00, M06, M07, M08 | T01–T09, T19, T23 |
| R08 external players | 05, 06, 07 | M06, M07, M08 | T19, T20, T23 |
| R09 latest/most seeded/search | 04, 06 | M04, M07 | T21, T28 |
| R10 torrent fields/freshness | 04, 12 | M04, M07 | T21, T28 |
| R11 torrent sources/file selection | 04, 07 | M04, M05, M07 | T10, T11, T16, T17 |
| R12 sequential order | 04, 05 | M00, M05, M06 | T01, T02, T04, T11 |
| R13 play before complete | 05 | M00, M06, M07, M08 | T01, T02, T03, T06 |
| R14 buffering/no seek priority | 05, 06 | M00, M06, M07 | T03, T04, T07, T08, T09 |
| R15 download visibility | 03, 04, 06, 12 | M05, M07 | T09, T10, T13, T29 |
| R16 advanced transfer controls | 04, 06 | M05, M07, M09 | T09, T13, T14, T29, T32 |
| R17 seeding-safe imports | 02, 03, 04 | M03, M05 | T12, T13, T32 |
| R18 restart/reconciliation | 03, 04, 08 | M05, M06, M09, M10 | T09, T10, T25, T32 |
| R19 simple/customizable UX | 06 | M07, M08, M09 | T22, T23, T29 |
| R20 remote-only TV | 06, 10 | M08 | T22, T31 |
| R21 client decoding/no transcode | 02, 05, 06 | M00, M03, M06, M08 | T01, T02, T08, T23, T26 |
| R22 CLI/optional Android Studio | 10 | M01, M08, M11 | T23, T27, T28 |
| R23 efficient agents/milestones | agent protocol, all milestones | M00–M11 | evidence/handoff audit; no token-saving guarantee |
| R24 security/resource limits | 07, 08 | M02, M04, M05, M06, M10 | T14–T20, T31, T32 |
| R25 Pi and real hardware | 08, 09, 10 | M00, M08, M10 | T22, T23, T26, T27 |
| R26 licenses/recovery/locks | 08, 10, 14 | M01, M09, M11 | T25, T28, T30 |

## How the conversation has been resolved

| Earlier topic | Final treatment; do not accidentally reintroduce superseded choices |
|---|---|
| Android TV APK testing on PC | Official TV emulator/ADB with matching ABI; CLI works without Android Studio. Real device remains necessary for hardware behavior. |
| Codex development | Local agents can use local tools with access; cloud runs do not automatically reach the user's emulator/Pi. Sol high coordinates small workers. |
| Web + Android + TV | Web was explicitly removed. Native Linux/Windows/macOS and Android mobile/TV are in scope. |
| “Like Jellyfin” | Server/users/library permissions retained; full catalog/movie scraping/episode intelligence excluded. |
| “Mostly like SFTP” | Folder-oriented UX retained; no SFTP protocol/server, SSH accounts or user-accessible arbitrary filesystem. |
| Reuse open source | Reuse qBittorrent/Prowlarr as API services, libmpv through media_kit on clients, FFprobe/bounded thumbnail tooling. Distinguish embedding from separate processes and obey licenses. |
| Pirate Bay/arbitrary site URLs | No hardcoded tracker/site scraper. Administrators configure supported Prowlarr indexers; direct magnets and bounded `.torrent` uploads supported. |
| Stremio/Torrentio | Explicitly excluded after earlier exploration. Do not add an add-on adapter or metadata provider “for later.” |
| Latest vs popular | Latest is provider-dependent; most seeded ranks the bounded retrieved result set. No universal torrent inventory or fabricated peers. |
| Dropping streaming temporarily | Superseded by explicit critical requirement to play while downloading. Completed-only implementation is unacceptable. |
| Sequential versus seek-aware | Sequential only. Fixed first/last metadata assist allowed; seeking cannot reprioritize missing pieces. Buffer/cancel behavior specified. |
| mpv versus VLC/Media3 | media_kit/libmpv baseline for one shared client; external players supported. Narrow Media3 Android fallback is predefined only for ordinary playback failure. No engine is universally best. |
| External players | First-class Play with/preference/copy URL. Scoped session credentials; progress/subtitle/HDR/timeout behavior not universal across apps. |
| Backend bias/performance/tokens | C# .NET 10 Minimal APIs selected for this workload, not past Go use. Keep native heavy work delegated, architecture small, hot-path performance measured. |
| Raspberry Pi 5 | Native 64-bit Docker images, no video transcode, SSD/NVMe preferred, explicit low-resource defaults, performance gates rather than promises. |
| Docker versus native | Docker-only server; no native installer. Native client and developer toolchains still exist. Upstream private admin web UIs do not constitute a Briani web client. |
| Simple but customizable | Functional primary flow; advanced settings/context menus, curated controls, per-user/per-device scopes. Not a visual Jellyfin clone or all-upstream-settings mirror. |
| No further planning | Decisions, APIs, defaults, milestones and contingencies are defined here. Tests/build errors, genuine credential access and hardware verification still require execution. |

## Coverage rules

No old assistant recommendation outweighs a later explicit user requirement. “Proposed” labels from earlier discussion are resolved by this package's decision register. A compatibility fallback is governed by its concrete trigger, not an invitation to relitigate the stack.

Any change needed during implementation must identify affected R/D/T identifiers, explain the technical evidence and update the canonical contract once. A public release license, secret key, server address or physical test result cannot be invented by an agent; those are ownership/environment inputs rather than a missing product design.
