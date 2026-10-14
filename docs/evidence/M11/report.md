# M11 private candidate handoff

Application implementation is complete across M00–M11. A private local candidate is packaged in `dist/`; release certification remains blocked. No images, tags, apps or store entries were published. Pi and physical Android checks are reserved to the owner. Windows/macOS build hosts and release signing credentials are unavailable.

## Produced files

- `dist/images/briani-server-and-egress-linux-amd64.tar`: final server and namespace firewall Docker images.
- `dist/images/briani-server-linux-arm64.tar` and `briani-egress-linux-arm64.tar`: ARM64 candidates, runtime verification deferred.
- `dist/client/briani-player-linux-x64.tar.gz`: optimized Linux Flutter bundle, requiring system GTK and libmpv dependencies documented in the client build guide.
- `dist/client/android/briani-player-unsigned.apk`: optimized universal Android APK, unsigned.
- `dist/client/android/briani-player-local-test.apk`: ordinary application debug APK, signed only with the local Android Debug certificate. This is not the integration-test APK.
- `dist/briani-operations.tar.gz`: operations CLI, Compose manifests and exact image/toolchain locks. Its archive layout is `briani-operations/dist/operations/`; use that directory as the operations root.
- `dist/manifest.json`, `dist/provenance.json`, `dist/SHA256SUMS`, CycloneDX `dist/sbom.json`, license/source/notices inventories, project source snapshot and retained dependency sources.

Use SHA256SUMS from the repository root (`sha256sum --check dist/SHA256SUMS`). Artifact paths and source identity are in the manifest. A Git commit is unavailable in this workspace; source files, names and normalized executable modes are hashed instead. The source snapshot excludes build/cache/evidence outputs and the generated private swarm state and media. Package sources are retained separately with exact hashes and provenance qualifications.

## Local checks and actual evidence

| Check | Exit/result | Evidence |
|---|---|---|
| Locked final server build | 0 | `server-manager-fix-build.log` |
| ARM64 portable API overlay, COPY only, no ARM execution | 0 | `portable-api-manager-build.log`, `server-arm64-manager-overlay.log` |
| Final server solution regression | 0, 412 tests across ten suites | `dotnet-quota-final-regression.log` |
| Additional acceptance tests | 0, fourteen final acceptance cases; Download108, Media64, Identity46 (included in 412) | `../M10/final-acceptance-tests.md`, `dotnet-quota-final-regression.log` |
| Python tooling regression | 0, 134 tests and 21 subtests | `python-final-regression.log` |
| Flutter unit regression / final analysis | 0, 86 tests / no analysis issues | `../M08/flutter-final-regression.log`, `flutter-manager-final-analyze.log` |
| Final-image desktop real-engine flow | 0, MP4/MKV/tail metadata; rendered video and external mpv handoff | `desktop-manager-retry.log`, run `4115614232624b71ab58a9ac1f082448` |
| Final-image Android TV emulator flow | 0, D-pad, rendered early video, buffering/recovery, tracks, navigation, import | `android-manager-retry.log`, M08 run `020dfef6666f4771a7af36618fe7acc9` |
| TV device-code pairing / grant isolation | 0 | `../M08/android-pairing.md` |
| Packaged four-service installation, configuration state backup, restore and rollback | 0, exact owned resources removed | `packaged-operations-manager-final.log` |
| Optimized Linux startup with fresh profile and no SDK on PATH | 0 | `linux-packaged-startup.json`, `.png`, `linux-runtime-ldd.log` |
| Ordinary packaged Android test APK install/start/cleanup | 0 | `android-packaged-startup.json`, `.png` |
| APK signatures | unsigned optimized APK: expected exit 1; test APK: exit 0, Android Debug certificate only | `android-signature-check.log`, `android-local-test-signature.log` |
| Cold secret-store/read-only failure and retained key | 0 | `../M10/resource-fault-secret-store.json` |
| Controlled qBittorrent restart after network loss | 0, source/download/seeder hashes match | `../M10/qbittorrent-network-loss-controlled-restart-v2.json` |
| Deterministic contract generation | 0 | `../M10/contracts-final.log` |
| Dependency inventory/source assembly | expected exit 3, retained explicit evidence blockers | `dependencies.md`, `native-sources.md` |
| Candidate assembly/package audit/release gate | exit 3 expected while blocked while certification blockers remain | `candidate-final-assembly.log`, `package-audit-final.json`, `release-verify-final.log` |

A parallel test compilation encountered a shared PDB write lock; the download suite was rerun serially. The build diagnostic is retained in `download-acceptance-parallel-build-failure.log`. No test was disabled to obtain a pass. OS-isolated engine checks are separate from component tests filtered as `Category!=EngineIntegration`.

## Native provenance and reproducibility

All 247 locked package identities are inventoried. All 75 NuGet normalized content hashes and 162 hosted Dart archive hashes match their locks; 172 Dart trees and 14 immutable NuGet repository archives are retained. Five NuGet packages lack an immutable publisher-declared source pin. Twenty-four license expressions remain NOASSERTION; this inventory does not grant the project's public license. See `dependencies.md` for precise counts and qualifications.

Native Android payloads are inventoried by actual APK member hashes/ELF architecture. The observed mpv build is `0.36.0-549-g78d43740f5-dirty`, with FFmpeg n6.0. Matching upstream sources and builder patches are retained, but exact dirty-binary correspondence remains unproved. Wrapper licenses are not assigned to native payloads. The Android Maven runtime dependency graph is retained separately. Linux relies on the host libmpv/FFmpeg distribution; system runtime dependencies and observed host native provenance are recorded in `packaging.md`. A complete native/OS-base distribution SBOM and its obligations are not certified.

The final ARM64 server overlays portable .NET assemblies, including locked ARM64 SQLite assets, onto the retained native ARM64 runtime/FFmpeg image. It performs no ARM code execution and no Pi access. The entrypoint runs the DLL with dotnet; the x64 apphost is excluded from the overlay. ARM64 egress packages were signature-checked and assembled with scripts disabled; native runtime remains owner verification.

The archive writer normalizes gzip/tar timestamps, owners and executable modes. Focused tests verify deterministic archive and checksum regeneration. This establishes deterministic packaging logic, not reproducible native binaries or bit-identical OCI indexes: OCI build attestations vary. Full clean-host rebuild evidence and Windows/macOS bundles are absent.

## Remaining limits

Unassisted qBittorrent reconnect had bounded stalled runs. Controlled restart recovery passed with retained bytes; automatic recovery reliability is unresolved. Exact branch-coverage measurements from the final 412-test collection are in `critical-coverage-final.json`; the earlier collection remains in `critical-coverage-release.json`; some handlers remain below the 90% target, and direct OS fault proofs are separate evidence. Hardware/format/HDR/audio/Wayland and physical external-player compatibility are not universally certified. Optimized client startup is tested; connected playback used integration test variants rather than the optimized APK/bundle itself.

The user/operator/developer guides, R01–R26/T01–T32 reconciliation and status ledger carry these qualifications. `release --task verify` must continue returning blocked while required platform, signing, native provenance, coverage and resilience evidence is missing. Independent review is in `review.md` and `../M10/manager-control-review.md`. Manager-only controls share queue/worker authorization; each awaited engine effect rechecks grants, rejected foreign-manager work does not poison authorized owner state, shared attachments serialize with lifecycle work, and selection/retry quota belongs to the request owner. The final quota and revocation regressions passed without disabling earlier owner-revocation checks.

Package regeneration found a valid license-notice filename containing spaces that the prior checksum ownership parser rejected. The parser and preflight ordering were corrected; regression tests prove a failed preflight leaves outputs unchanged. Four generated partial outputs are retained in `artifacts/release-regeneration-recovery-20261013/`; final regenerated files and checksum verification supersede that draft.

The retained-media restore command is documented in the repository operations guide; configuration-only backups exclude payload. Copying media to new inodes is deliberately fenced, rather than treated as the same managed data. The resumed-download proof uses a stopped original stack and explicitly retained original test media.

T25 full-stack retained-media restore/resume passed, exit 0: `../M10/download-restore-torrent-upload-retry-v2.json` and `.log`. All 8,388,608 payload bytes match the generated source; owner/grants/request/key/idempotency, original partial-file inode/hash and observed recheck survived. Both exact Compose projects, fixture seed/network and scratch were removed. The proof uses uploaded private metainfo: the preceding private-magnet diagnostic is explained by pinned libtorrent intentionally withholding its metadata plugin for private torrents (primary source linked in the T25 note), and is preserved separately. Four resource-harness tests and six restore-harness tests pass.

## Final regression diagnoses

The first final-image desktop rerun observed an incomplete JSON report while the integration client was writing its first-frame marker (`desktop-manager-final.log`, run `f318447acbd848989ab950f04d1a4032`). Test reports now publish through a flushed temporary file and atomic rename. The focused concurrent report-reader regression passed (`desktop-marker-regression.log`); the full desktop rerun passed all three media scenarios (`desktop-manager-retry.log`). This changed test code only; packaged clients were unchanged.

A first TV rerun timed out while its isolated qBittorrent seeder started (`android-manager-final.log`, run `6fe65b1baba24940a3d3998643ae7bbe`); a later complete run passed (`android-manager-retry.log`). The emulator package and ADB reverse forwarding were absent after teardown; only the owned emulator was shut down.

Two final restore attempts did not reach health through the published port. The API remained running and responded over its control network. Identical Host-header probes and a temporary explicit IPv4 listener ruled out the proposed listener correction. The host had a more-specific `172.26.0.0/24` route through `p81` overriding Docker's allocated client `/16`. Sanitized diagnostics and exact cleanup are in `../M10/download-restore-manager-retry-diagnostic.json`. Root-owned, unused internal Docker `/16` reservations keep automatic test allocation away from the observed conflicting 172.26/28/29/30/31 pools; no host firewall/routing setting, production Compose manifest or egress policy was changed. Its lifetime/cleanup is in `test-route-reservation.json`.

The final unchanged retained-media restore run passed on the rebuilt image (`../M10/download-restore-manager-final-pass.json`, run `2f62e6d70d204877`, exit 0). Source and restored client/control routes used their owned Docker bridges. The paused inode/hash, request owner, grant, idempotency replay, secret key and torrent identity survived; recheck checking/completion were observed; the resumed 8 MiB source and receiver hashes matched. All source/restore/fixture resources and scratch data were removed. The preceding failed attempts remain preserved.

The final packaged operations drill completed with `DRILL_RESULT=PASS`, exit 0, using the staged CLI/Compose/lock files and final server image. It backed up 603 configuration files and verified accounts, grants, encrypted integrations, preferences, qBittorrent limits, restore and compatible rollback. All three owned projects and scratch data were removed. All five unused route reservations were then removed by exact ID after verifying owner/run labels and empty endpoints.

## Sealed candidate audit

Final assembly exited 3 with seven artifacts, 247 package components and 164 declared assembly blockers. `sha256sum --check dist/SHA256SUMS` exited 0: all 843 indexed files matched. The final package audit exited 3 with valid blocked status and 474 certification qualifications, not malformed-input exit 2. `python3 tools/dev.py release --task verify` exited 3 for the recorded milestone/platform/native/signing qualifications. The earlier premature audit's evidence-log mismatch is retained in `package-audit-before-operations-completion.json`; the manifest was regenerated after the operations log finished, and every referenced evidence hash then matched.

Independent final review found no artifact/source/provenance/evidence mismatch. All seven actual artifact sizes and hashes, all referenced evidence and lock hashes, the 759-member source archive and current source identity agreed. Source tree SHA-256 is `90db9a029ed04265efe382fab2215d2158250a6ca37b154cde4852b270b5e94c`. No new certification is inferred from earlier resource-fault proofs on older images. Final artifact review is in `review.md`; the manager-boundary production review and exact source hashes are in `../M10/manager-control-review.md`.
