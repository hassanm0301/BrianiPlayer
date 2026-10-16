# Release v1.1.0 — 2026-10-16

All server and client artifacts were rebuilt from source at `916c513`: server-authored error messages, no password rules, and server-checked confirmation fields. The image lock and operations docs now point at the `v1.1.0` image tags. This is an **unsigned pre-release**; the M11 certification blockers still apply.

**Compatibility:** bootstrap, create-user, change-password and reset-password now require `confirmPassword`/`confirmNewPassword`. Clients older than v1.1.0 cannot create accounts or change passwords against this server. Upgrade server and clients together. There is no database migration.

## Artifacts

| Artifact | Build | Notes |
|---|---|---|
| `dist/images/briani-server-and-egress-linux-amd64.tar` | `server-amd64-build.log` (exit 0) | `briani-server:v1.1.0` ID `sha256:0682a3e5…e79d`, config `sha256:c2b9760d…e5f5`; egress is the unchanged `briani-egress:m10` |
| `dist/images/briani-server-linux-arm64.tar` | `portable-api-build.log`, `server-arm64-overlay.log` (exit 0) | `briani-server:v1.1.0-arm64` ID/config `sha256:0bc9682e…f15e` / `sha256:7bf89adc…f0b`; COPY-only portable API overlay on `briani-server:m10-arm64`, same method as v1.0.0 |
| `dist/images/briani-egress-linux-arm64.tar` | unchanged M11 build | Egress sources unchanged |
| `dist/client/briani-player-linux-x64.tar.gz` | `linux-build.log` (exit 0) | Packaged startup smoke passed (`linux-packaged-startup.json`, `linux-smoke.log`) |
| `dist/client/android/briani-player-unsigned.apk` | `android-release-build.log` (exit 0) | Unsigned: `android-signature-check.log` (apksigner exit 1, expected) |
| `dist/client/android/briani-player-local-test.apk` | `android-local-test-build.log` (exit 0) | Android Debug certificate: `android-local-test-signature.log` |
| `dist/briani-operations.tar.gz` | refreshed from repository files | Same seven files as v1.0.0, with the v1.1.0 image lock and docs |

Image IDs are in `image-ids.log`.

## Regression checks (committed tree)

| Command | Exit | Result |
|---|---:|---|
| `dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration'` | 0 | 424 passed (`server-regression.log`) |
| `flutter analyze --no-pub` | 0 | No issues (`flutter-analyze.log`) |
| `flutter test --no-pub` | 0 | 116 passed (`flutter-test.log`) |
| `python3 -m unittest discover -s tests/operations` | 0 | 32 passed (`operations-tests.log`) |
| `python3 tools/release/linux_smoke.py --bundle dist/client/linux-x64 --evidence docs/evidence/release-v1.1.0` | 0 | Packaged startup under Xvfb |

The same server API is running on the Pi (`docs/evidence/M09/pi-deployment-20261016/messages-update.md`). There, live checks confirmed `password_mismatch`, the specific validation messages, and acceptance of a 4-character password.

## Limitations

- Clients were built with the locally installed Flutter (`flutter-version.log`); `toolchain.lock.json` pins 3.47.6.
- Playback, emulator/TV and engine harness checks were not repeated for this rebuild.
- The release APK is unsigned. All M11 certification blockers remain open; see `dist/manifest.json`.
