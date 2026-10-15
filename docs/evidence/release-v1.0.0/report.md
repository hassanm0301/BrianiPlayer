# Release v1.0.0 — artifact rebuild — 2026-10-16

All server and client artifacts were rebuilt from source at a39ce99 (the landlock-free containment and client polish commit). The image lock and operations docs now point at the `v1.0.0` image tags. The release is an **unsigned pre-release**; the M11 certification blockers still apply.

## Artifacts

| Artifact | Build | Notes |
|---|---|---|
| `dist/images/briani-server-and-egress-linux-amd64.tar` | `server-amd64-build.log` (exit 0) | `briani-server:v1.0.0` ID `sha256:9e5e0bc3…3d5d`, config `sha256:d037fb68…a921`; the egress image is the unchanged `briani-egress:m10` |
| `dist/images/briani-server-linux-arm64.tar` | `portable-api-build.log`, `server-arm64-overlay.log` (exit 0) | `briani-server:v1.0.0-arm64` ID/config `sha256:81ad1a1f…6818` / `sha256:64d5b93d…ac06`; COPY-only portable API overlay on retained `briani-server:m10-arm64` |
| `dist/images/briani-egress-linux-arm64.tar` | unchanged M11 build | Egress sources unchanged since M11 |
| `dist/client/briani-player-linux-x64.tar.gz` | `linux-build.log` (exit 0) | Packaged startup smoke passed: `linux-packaged-startup.json` |
| `dist/client/android/briani-player-unsigned.apk` | `android-release-build.log` (exit 0) | Unsigned: `android-signature-check.log` (apksigner exit 1, expected) |
| `dist/client/android/briani-player-local-test.apk` | `android-local-test-build.log` (exit 0) | Android debug certificate: `android-local-test-signature.log` |
| `dist/briani-operations.tar.gz` | refreshed from repository files | Includes the updated `images.lock.json` |

Image IDs are in `image-ids.log`.

## Regression checks

| Command | Exit | Result |
|---|---:|---|
| `dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration'` | 0 | 421 passed (`server-regression.log`) |
| `flutter analyze --no-pub` | 0 | No issues (`flutter-analyze.log`) |
| `flutter test --no-pub` | 0 | 112 passed (`flutter-test.log`) |
| `python3 -m unittest discover -s tests/operations` | 0 | 32 passed (`operations-tests.log`) |
| `python3 tools/release/linux_smoke.py --bundle dist/client/linux-x64 --evidence docs/evidence/release-v1.0.0` | 0 | Packaged startup under Xvfb |

## Limitations

- The clients were built with Flutter 3.47.7. `toolchain.lock.json` pins 3.47.6 (`flutter-version.log`).
- Playback, emulator/TV, Pi native runtime and engine harness checks were not repeated for this rebuild. Their evidence comes from M10/M11 and the landlock-free work.
- The release APK is unsigned and no Pi memory-limit blocker was resolved. All M11 certification blockers remain open. See `dist/manifest.json` blockers.
