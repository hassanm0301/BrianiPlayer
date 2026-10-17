# Release v1.3.0 — 2026-10-18

All server and client artifacts were rebuilt from source at `07072f7`. The image lock and operations docs now point at the `v1.3.0` image tags. This is an **unsigned pre-release**; the M11 certification blockers still apply.

## What changed since v1.2.0

- **Indexer management in Administration** (`0377209`, review fixes `96a3af5`, `07161b9`; merged in `07072f7`).
  - Administrators can list Prowlarr torrent indexers, add one from a Prowlarr definition, switch it on or off, test it and remove it.
  - Prowlarr is reached only through nine fixed operations. No indexer setting values are returned, and secret-looking settings are write-only.
  - Seven new administrator-only operations in `contracts/openapi.yaml`.
  - Evidence: `docs/evidence/M09/indexer-admin-20261017/` (`report.md`, `review.md`, `tv-unaddable-definitions.md`).
- **Briani Player logo** (`025dfb1`): the in-app mark, Android adaptive/themed launcher icon and TV banner, macOS/Windows app icons and the Linux window icon. Evidence: `docs/evidence/M07/brand-logo-20261017/`.
- **Client download page** (`c0f690c`, `dd1ce68`): an optional, separate Compose project (`infra/downloads/`, `docs/operations/downloads.md`). Its deployment on the Pi is in `docs/evidence/downloads-page-2026-10-17.md`. It looks for the release asset names `briani-player-local-test.apk` and `briani-player-linux-x64.tar.gz`, and this release keeps both.
- **Discover:** Enter now submits the search (`7c82cf8`).
- **Docs:** step-by-step torrent search setup guide, `docs/operations/indexers.md` (`9945dec`).

**Compatibility:** the API gains the indexer administration operations; existing operations are unchanged. There is no database migration. No server, client or operations-bundle dependency changed (`client/pubspec.lock` and the server package locks are unchanged since v1.0.0).

## Artifacts

| Artifact | Build | Notes |
|---|---|---|
| `dist/images/briani-server-and-egress-linux-amd64.tar` | `server-amd64-build.log` (exit 0) | `briani-server:v1.3.0` ID `sha256:0a8ba6f9…e5e6`, config `sha256:15c5c31d…88d1c`; egress is the unchanged `briani-egress:m10` |
| `dist/images/briani-server-linux-arm64.tar` | `portable-api-build.log`, `server-arm64-overlay.log` (exit 0) | `briani-server:v1.3.0-arm64` ID/config `sha256:6d854030…1701` / `sha256:e308e70c…81f3`. COPY-only portable API overlay on `briani-server:m10-arm64`, same method as v1.2.0; its `Briani.Api.dll` is byte-identical to the portable publish |
| `dist/images/briani-egress-linux-arm64.tar` | unchanged M11 build | Egress sources unchanged |
| `dist/client/briani-player-linux-x64.tar.gz` | `linux-build.log` (exit 0) | Packaged startup smoke passed (`linux-packaged-startup.json`, `linux-smoke.log`); the screenshot shows the new logo |
| `dist/client/android/briani-player-unsigned.apk` | `android-release-build.log` (exit 0) | Unsigned: `android-signature-check.log` (apksigner exit 1, expected) |
| `dist/client/android/briani-player-local-test.apk` | `android-local-test-build.log` (exit 0) | Android Debug certificate: `android-local-test-signature.log` |
| `dist/briani-operations.tar.gz` | refreshed from repository files | Same seven files, with the v1.3.0 image lock and docs |

Image IDs are in `image-ids.log`. Both server images were checked to contain this release's new types (`IndexerAdministration`, `ProwlarrCall`).

## Regression checks (committed tree at `07072f7`)

| Command | Exit | Result |
|---|---:|---|
| `dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration'` | 0 | 533 passed, 0 failed (`server-regression.log`) |
| `flutter analyze --no-pub` | 0 | No issues (`flutter-analyze.log`) |
| `flutter test --no-pub` | 0 | 155 passed (`flutter-test.log`) |
| `python3 -m unittest discover -s tests/operations` | 0 | 32 passed (`operations-tests.log`) |
| `python3 -W error::ResourceWarning -m unittest discover -s tests/downloads` | 0 | 12 passed (`downloads-tests.log`) |
| `python3 tools/release/linux_smoke.py --bundle dist/client/linux-x64 --evidence docs/evidence/release-v1.3.0` | 0 | Packaged startup under Xvfb |
| `python3 plan/tools/validate_plan.py` | 0 | PASS, after the merge |

The indexer feature's end-to-end check ran against a local, isolated Prowlarr 2.6.5.5623 with a generated fixture definition and site (`docs/evidence/M09/indexer-admin-20261017/e2e-local-prowlarr.json`). It was not repeated for this rebuild. Playback and engine harnesses were not repeated either; no server playback code changed since v1.2.0.

## Limitations

- Not deployed to or re-verified on the Raspberry Pi. ARM64 native runtime verification remains owner-deferred.
- The Indexers section and the new icons were not checked on an Android phone, Android TV, Windows or macOS device.
- Open indexer review items (`docs/evidence/M09/indexer-admin-20261017/review.md`): the 18-second limit is per Prowlarr call rather than per request (Low); indexer audit rows show no resource (Info); smaller notes (Info).
- Owner decision pending: specs 01/08 describe indexer status/enable/test only. Add and Remove go further, and the spec text is unchanged.
- Head-of-line blocking from a slow peer is still open and needs a decision (`plan/specs/11_DECISIONS_AND_RISKS.md`).
- Clients were built with Flutter 3.47.7 (`flutter-version.log`); `toolchain.lock.json` pins 3.47.6.
- The release APK is unsigned. All M11 certification blockers remain open; see `dist/manifest.json`.

## Candidate assembly and audit

| Command | Exit | Result |
|---|---:|---|
| `python3 tools/release/build_candidate.py --root .` | 3 | `blocked`: 7 artifacts, 247 components, 166 blockers (`candidate-assembly.log`), as for v1.2.0 |
| `python3 tools/release/package_audit.py verify --root .` | 3 | `blocked`: 360 blockers (`release-verify.log`). The set matches v1.2.0's except that the Flutter-pin note now names v1.3.0 |

Both ran with `sourceCommit` set to the `v1.3.0` tag commit, on a clean hardlinked copy of the tagged tree. Both tools walk the whole working directory. A first run in the main checkout swept three local scratch checkouts into the source archive (2,401 extra files) and the lockfile inventory, so its outputs were discarded. The clean copy's source archive has 843 files. Compared with v1.2.0's 800, the only changes are this release's own files.

The APK native-member hashes in `dist/candidate-inputs.json` were refreshed from the new builds. Only the three `libapp.so` (compiled Dart) entries of the release APK changed; every third-party native library is byte-identical to v1.2.0's.
