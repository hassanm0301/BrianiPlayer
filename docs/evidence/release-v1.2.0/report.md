# Release v1.2.0 — 2026-10-16

All server and client artifacts were rebuilt from source at `3ebed52`. The image lock and operations docs now point at the `v1.2.0` image tags. This is an **unsigned pre-release**; the M11 certification blockers still apply.

## What changed since v1.1.0

- **Play while downloading works for MP4s that keep their index at the end.**
  - libtorrent could silently drop qBittorrent's first/last-piece boost after a file-priority change, so the video's tail arrived last. The server now re-asserts the fixed assist until those pieces arrive.
  - An MP4/MOV is reported playable only once its `moov` index is verified.
  - Evidence: `docs/evidence/live-pi-2026-10-16.md` and `live-pi-2026-10-16-piece-order.json`.
- **New magnets no longer fail within a second.** Metadata detection uses qBittorrent's `has_metadata` instead of treating `queuedDL` as "metadata received".
- **Server fixes:**
  - Subtitles are listed once, each with its language.
  - Import state stays `running` until every selected file is imported.
  - Video thumbnails skip black openings.
  - A magnet's name shows while metadata loads.
  - qBittorrent's "infinite" ETA is reported as unknown.
- **Desktop app:**
  - Playback, download progress and slideshows keep running when the window loses focus.
  - Paused downloads offer Resume again.
- **Device linking:** the TV code has a **Copy code** button, the approval dialog takes the code one character per box, and an expired code says so.
- **Redesigned app** (`fdcfe6b`): adaptive Material 3 shell and screens. Evidence: `docs/evidence/M07/ui-redesign-20261016/`.
- **Discover** explains a missing download-capable library instead of returning a bare "forbidden" (`ad3275a`).

**Compatibility:** the API contract (`plan/contracts/openapi.yaml`) is unchanged, and there is no database migration.

## Artifacts

| Artifact | Build | Notes |
|---|---|---|
| `dist/images/briani-server-and-egress-linux-amd64.tar` | `server-amd64-build.log` (exit 0) | `briani-server:v1.2.0` ID `sha256:0c7a3322…5b02`, config `sha256:cb3b9cee…009e`; egress is the unchanged `briani-egress:m10` |
| `dist/images/briani-server-linux-arm64.tar` | `portable-api-build.log`, `server-arm64-overlay.log` (exit 0) | `briani-server:v1.2.0-arm64` ID/config `sha256:659aa943…14de` / `sha256:87db6343…edf3`. COPY-only portable API overlay on `briani-server:m10-arm64`, same method as v1.1.0; its `Briani.Api.dll` is byte-identical to the portable publish |
| `dist/images/briani-egress-linux-arm64.tar` | unchanged M11 build | Egress sources unchanged |
| `dist/client/briani-player-linux-x64.tar.gz` | `linux-build.log` (exit 0) | Packaged startup smoke passed (`linux-packaged-startup.json`, `linux-smoke.log`) |
| `dist/client/android/briani-player-unsigned.apk` | `android-release-build.log` (exit 0) | Unsigned: `android-signature-check.log` (apksigner exit 1, expected) |
| `dist/client/android/briani-player-local-test.apk` | `android-local-test-build.log` (exit 0) | Android Debug certificate: `android-local-test-signature.log` |
| `dist/briani-operations.tar.gz` | refreshed from repository files | Same seven files, with the v1.2.0 image lock and docs |

Image IDs are in `image-ids.log`. The Linux client was built twice: the first bundle lacked the (empty) `lib/native_assets.json` that the build regenerates. `linux-build.log` and the smoke evidence are from the rebuilt, shipped bundle. Both server images were checked to contain this release's new types (`MediaIndexProbe`, `ReassertMetadataAssistAsync`, `SubtitleLanguage`).

## Regression checks (committed tree)

| Command | Exit | Result |
|---|---:|---|
| `dotnet test server/Briani.sln --no-restore -m:1 --filter 'Category!=EngineIntegration'` | 0 | 459 passed (`server-regression.log`) |
| `flutter analyze --no-pub` | 0 | No issues (`flutter-analyze.log`) |
| `flutter test --no-pub` | 0 | 146 passed (`flutter-test.log`) |
| `python3 -m unittest discover -s tests/operations` | 0 | 32 passed (`operations-tests.log`) |
| `python3 tools/release/linux_smoke.py --bundle dist/client/linux-x64 --evidence docs/evidence/release-v1.2.0` | 0 | Packaged startup under Xvfb |

The engine-backed checks below ran during development against the same server logic. Only a comment and one unit test changed before `3ebed52`. Their artifacts were kept local:
- `prototypes/downloads/engine/run_local_peer_transfer.py` and `run_pinned_engine.py` passed against qBittorrent 5.2.4.
- `prototypes/playback/production/run_api_playback.py` passed with a `briani-server:dev` image. mpv decoded the faststart MP4, the multi-track MKV and the tail-metadata MP4 before their downloads completed.

## Limitations

- Not deployed to or re-verified on the Raspberry Pi; the Pi still runs the `messages-20261016` image. ARM64 native runtime verification remains owner-deferred.
- Head-of-line blocking from a slow peer is still open and needs a decision (`plan/specs/11_DECISIONS_AND_RISKS.md`).
- Clients were built with Flutter 3.47.7 (`flutter-version.log`); `toolchain.lock.json` pins 3.47.6.
- Emulator/TV checks were not repeated for this rebuild.
- The release APK is unsigned. All M11 certification blockers remain open; see `dist/manifest.json`.
