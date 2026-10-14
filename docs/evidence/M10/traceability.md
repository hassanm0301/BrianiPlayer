# M10 acceptance reconciliation

Snapshot: 2026-10-13. This reconciles existing evidence and the latest owner-provided run results; no new tests or device actions were performed for this edit. “Implemented” describes code presence. Test states below describe only recorded executions. A pass does not imply platform or hardware certification.

## Requirements R01–R26

| ID | Implementation paths | Evidence / disposition |
|---|---|---|
| R01 | `infra/compose/compose.yaml`, `infra/images/server.Dockerfile`, `tools/operations/` | Implemented Docker deployment. Linux/amd64 build and Compose drills passed. The server image rebuild is underway; actual image/package acceptance remains pending. Pi runtime was explicitly deferred by the user; do not test it. |
| R02 | `client/lib/app/`, `client/lib/core/platform/`, `client/lib/core/playback/` | Desktop and Android/TV flows implemented. Linux desktop playback and external mpv handoff passed (`desktop-final.log`). Android TV full-flow run `5c91008357ea4f10a146055d806dd5ee` and connected pairing passed (`docs/evidence/M08/report.md`, `android-pairing.md`). Windows/macOS and physical Android remain unverified. |
| R03 | `server/src/Briani.Api/Modules/Identity/`, `Modules/Administration/`, client session/profile paths | Identity, grants, sessions, and pairing implemented; server suites and connected TV pairing passed. Full cross-resource authorization matrix remains partial. |
| R04 | `Modules/Libraries/`, `Modules/Media/Operations/`, `Infrastructure/Storage/` | Library and confined storage paths implemented; scan, containment, mutation and mount regressions passed. Disk-full/read-only/missing-mount and cold SecretStore scenarios passed in owned local containers (`resource-faults.json`, `resource-fault-secret-store.json`; run `472c22e64eb540cdbf6c27d463a0f8c5`). SecretStore branch coverage remains 3/4 (75%) in `critical-coverage-final.json`. |
| R05 | `Modules/Libraries/Queries/`, `Modules/Media/MediaEndpoints.cs`, `client/lib/features/libraries/` | File browsing implemented and exercised. 10,000-item performance and full cross-user matrix remain unmeasured. |
| R06 | `Modules/Media/Processing/`, media endpoints, `client/lib/features/photos/` | Photo, EXIF orientation and bounded thumbnail paths implemented; generated-image tests passed. Full device slideshow/zoom and decompression-bomb acceptance remains open. |
| R07 | `Modules/Playback/`, `client/lib/features/playback/`, `client/lib/core/playback/` | Progressive playback implemented. Linux actual-engine MP4/MKV and Android TV rendered full-flow passed; physical platform coverage remains open. |
| R08 | `Modules/Playback/CompletedPlayback.cs`, `client/lib/core/playback/external_player.dart`, Android `MainActivity.kt` | External handoff implemented. Linux actual mpv launch/reap passed. Android external launch and cross-platform handler cases remain unverified. |
| R09 | `Modules/Discovery/Queries/`, `Integrations/Prowlarr/`, discover UI | Latest/Most seeded/Search implemented; local discovery and client ordering suites passed. |
| R10 | Discovery query paths, `contracts/openapi.yaml`, discover UI | Fields/freshness implemented; local normalization, null/negative count, dedup and provider-error coverage passed. No live provider account claim. |
| R11 | `Modules/Discovery/Sources/`, download commands/layout/worker | Source admission and selection implemented; local real-engine metadata/selection tests passed. T17 daemon egress evidence is recorded separately below. |
| R12 | `Integrations/QBittorrent/QBitTorrentClient.cs`, download worker, progressive reader | Sequential mode and fixed metadata assist passed in local qBittorrent runs; Pi behavior is unverified and user-deferred. |
| R13 | progressive playback paths and player UI | Generated incomplete MP4/MKV playback passed on Linux; Android TV rendered-frame full-flow passed. |
| R14 | `ProgressiveReader.cs`, `RangeSpec.cs`, `playback_relay.dart` | Buffering/no-priority behavior and cancellation/framing regressions passed at tested host scope (`progressive-validation-boundaries.log`, `server-integrated-final.log`). |
| R15 | download queries and `client/lib/features/downloads/` | Download visibility and lifecycle implemented; cross-user duplicate-hash acceptance remains partial. |
| R16 | download commands, administration, qBittorrent adapter | Transfer controls implemented; operations backup/restore/rollback drill passed (`operations-drill-final.log`). Full UI/control matrix remains partial. |
| R17 | `DownloadImport.cs`, media operations | Seeding-safe hard-link import passed with real engine; all three exact crash-window scenarios passed (`crash-matrix.json`). |
| R18 | download worker/locks, media operations, preferences operations | Reconciliation and restart paths implemented; API restart/import and operations drills passed. All three named real-process kill boundaries now passed (`crash-matrix.json`). |
| R19 | client preferences/settings/administration | Preferences and settings implemented; server/client suites passed. Full reset/role regression across platforms remains partial. |
| R20 | `client/lib/core/input/`, TV screens and controls | Remote-only Android TV full playback flow and connected pairing passed in the latest emulator runs (`M08/report.md`, `android-pairing.md`). This is emulator evidence; physical remote/device is unverified. |
| R21 | media processing/playback and media_kit adapter | Client decode/no server transcode implemented; Linux and Android TV rendering evidence passed. Pi load and physical codec matrix are unverified. |
| R22 | `tools/dev.py`, operations and client scripts | CLI workflows implemented and used. Windows/macOS build evidence remains unavailable. |
| R23 | `plan/agents/EXECUTION_PROTOCOL.md`, milestone evidence | Milestone/worker process recorded; no token-saving result is claimed. |
| R24 | security, storage, playback, discovery and `infra/network/` | Security controls implemented. M10 egress enforcement passed both the final owned-namespace probe (`egress-final-image.json`) and the four-service Compose operations drill (`../M11/packaged-operations-final.log`). Recorded cases cover tracker, webseed, redirects, DNS rebinding and explicit peers; do not extend that claim to untested protocol/address dimensions. Critical coverage is in `critical-coverage-final.json`; `SecretStore` is 3/4 branches (75%), below target, and its cold read-only run passed. |
| R25 | deployment and native client paths | Blocked verification. Pi testing is expressly prohibited by the user and reserved for the user. Windows/macOS and physical Android are unavailable here. No Pi performance or hardware certification claim. |
| R26 | locks, release audit and operations | Recovery/lock tooling and packaged operations drill passed. A 247-component SBOM plus source/license archives are collected; unresolved SPDX entries, five NuGet source pins, native source correspondence/notices, signing and reproducibility remain release blockers. Actual rebuilt-image acceptance is pending. |

## Named tests T01–T32

| Test | State and evidence |
|---|---|
| T01 | Passed Linux; incomplete generated faststart MP4 and app playback. `desktop-final.log`; M08 full-flow result. |
| T02 | Passed Linux; generated incomplete MKV and tracks. M00/M06 evidence. |
| T03 | Passed Linux; missing-piece response emitted no fabricated bytes, resumed in same player. M06 evidence. |
| T04 | Passed tested host scope; no seek priority change and cancellation/framing suite. `progressive-validation-boundaries.log`. |
| T05 | Passed scoped real-engine layouts with byte oracle. M00/M06 evidence. |
| T06 | Passed scoped sparse/preallocated availability and byte comparison. M06 evidence. |
| T07 | Passed server range suite: HEAD, ranges, malformed/416 and fallback. M06 and progressive validation logs. |
| T08 | Passed Linux; tail-metadata file waited honestly. M00/M06 evidence. |
| T09 | Passed scoped restart/recheck generation fencing. M06 evidence. |
| T10 | Passed component timeout-after-add reconciliation without duplicate add; real upstream-add-before-DB SIGKILL recovery passed separately. `final-acceptance-tests.md`, `crash-matrix.json`. |
| T11 | Passed local engine metadata-only selection. M05 evidence. |
| T12 | Passed real-engine hard-link import; virtual fallback has component coverage, full matrix open. |
| T13 | Passed API/component shared requester control/quota and neutral cross-library hash conflict; real-engine sharing is separate M06 evidence. `final-acceptance-tests.md`. |
| T14 | Passed for local fault cases: ENOSPC (HTTP 507, retained hash), read-only and missing mount (safe denials, no jobs/requests), network disconnect/recovery (matching 32 KiB hash), and cold SecretStore read-only preservation. See `resource-faults.json` and `resource-fault-secret-store.json`. |
| T15 | Passed all eight grant-bit combinations for media/foreign-request visibility, 96 owner/shared/destructive policy decisions, session revocation, and manager control/revocation/owner-quota regressions. `final-acceptance-tests.md`, `manager-control-review.md`. Component/API evidence; real hardware remains separately qualified. |
| T16 | Passed traversal/symlink/metainfo properties and explicit DownloadLayout mapping/piece intersections beyond uint.MaxValue. `final-acceptance-tests.md`, parser/property suites. No multi-GiB payload was allocated. |
| T17 | Passed for recorded Compose-integrated egress guard scenarios: `../M11/packaged-operations-final.log`, plus positive-control packet evidence in `egress-final-image.json`. Scope is the tested tracker/webseed/redirect/rebind/peer cases. |
| T18 | Passed login/refresh/replay/logout/disable plus open progressive-response logout and lease cleanup; other watchdog mutations remain covered separately. `final-acceptance-tests.md`. |
| T19 | Passed server/component; later legitimate ticket ranges and cross-user denial covered. |
| T20 | Partial; Linux mpv launch/reap passed. Android external launch, no-handler and selected-handler race remain unverified. |
| T21 | Passed local discovery suite. |
| T22 | Passed emulator full D-pad playback flow and pairing (`5c91008357ea4f10a146055d806dd5ee`, M08 report); physical remote/device remains unverified. |
| T23 | Partial; Linux desktop and Android TV flow passed; mobile lifecycle and Windows/macOS cases remain. |
| T24 | Passed bounded server EXIF pixel orientation, thumbnail output cap and oversized image-header rejection before decoder launch. `final-acceptance-tests.md`. Physical slideshow/zoom remains owner verification. |
| T25 | Passed actual four-service configuration restore over retained original media, with request/grant/key/idempotency/inode/hash preservation, observed recheck and resumed 8MiB transfer matching source SHA256. `download-restore-manager-final-pass.json` (final image), with prior `download-restore-torrent-upload-retry-v2.json`. New-volume identity migration is outside this proof. |
| T26 | **Blocked by explicit user deferral.** No Pi access/testing is authorized; user will test. No benchmark or soak result. |
| T27 | Partial; Linux/amd64 deployment passed. Final x64 packaged image workflows passed; ARM64 native runtime is owner-deferred. No Pi testing. |
| T28 | Passed recorded contract generation/validation path; preserve generated-client diff verification for final integration. |
| T29 | Partial; preference/admin suites and focused concurrency regressions passed; full reset/role/client matrix remains. |
| T30 | Private candidate packaged with hashes/source/provenance/SBOM/notices; release certification remains blocked on explicit platform/signing/native correspondence/coverage/resilience gates. `../M11/report.md`. |
| T31 | Passed connected Android TV pairing and grant-limited library check (`android-pairing.md`); physical TV remains unverified. |
| T32 | Passed for all three named real SIGKILL boundaries: after upstream add, after import hard-link, and after engine removal before DB commit. Five API restarts; retained data/hash, seeding registration and durable removal all verified in `crash-matrix.json` (run `dfe5552380d54e6e8000f314e1ada4cb`). |

## Current local gates

Latest supplied regression result: .NET 398 tests passed; Media64 and Identity45/Download101 include the six additions after the `ContainedDirectory.Validate` loop fix. See the current integrated regression logs; earlier logs in this directory include superseded failed runs and must not be presented as the latest outcome. `SecretStore` branch coverage remains 3/4 (75%) and its cold run passed. The controlled qBittorrent operator-restart variant passed, while spontaneous network recovery remains unreliable/unproven despite one 15 MB hash-matching unassisted pass; see [qbittorrent-network-loss.md](qbittorrent-network-loss.md). Final x64 image desktop/TV and packaged operations workflows passed; ARM64 native runtime remains owner-deferred.

No further Pi testing is to be performed; the user expressly reserved it. Windows/macOS and physical Android are unavailable. These are verification limitations, not missing implementation paths. The release remains blocked by the local gates above and external platform evidence.

Final local additions: six focused acceptance tests passed and close the recorded timeout reconciliation/shared-request control/large-offset/open-stream revocation and media authorization/image-bound component gaps. See `final-acceptance-tests.md`. Final server image `sha256:1a079aaab0eb2bda34598bb7cb2c77fd1f3ded446415549b505eec542d6cebf5` passed desktop run `78cce57174a1418aa221e3541c3b0e06`, Android TV run `640d7278d8d0466b8e226ad54e1e0ad9`, and the packaged four-service drill, all exit 0 (`../M11/` logs). Physical Android and Pi verification are explicitly reserved to the owner. Package/native license certification and spontaneous qBittorrent recovery remain qualified.
