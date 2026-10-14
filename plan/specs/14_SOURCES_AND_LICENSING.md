# 14 — Primary sources, verification and licensing

**Research date:** 12 October 2026. These references informed the plan. Source code on master/develop is diagnostic evidence, not a contract for the stable release that will be deployed. M00/M01 must lock and verify actual binaries; versions must not drift just because a newer release appears.

Other specifications cite `S01`–`S29`. Performance targets, default resource limits, code structure, milestone boundaries and model assignments are engineering decisions for this project, not benchmark claims attributed to these sources.

## Source register

### S01 — .NET support policy

`https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core`

Select supported .NET 10 LTS patches; freeze actual SDK/runtime/package versions. Support dates do not prove application performance.

### S02 — qBittorrent Web API 5 documentation

`https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-5.0)`

File lists, piece states, sequential/first-last options and operations. Probe capabilities against the pinned stable version.

### S03 — qBittorrent implementation evidence

`https://raw.githubusercontent.com/qbittorrent/qBittorrent/master/src/webui/api/torrentscontroller.cpp`

Current source helps audit metadata acquisition, export and state behavior. Master is not a promise that a stable image exposes the same API. Also inspect matching-version src/base/bittorrent/torrentimpl.cpp.

### S04 — Prowlarr API documentation

`https://prowlarr.com/docs/api/`

Supported application API; corroborate version-sensitive details with the pinned build and current source.

### S05 — Prowlarr search controller

`https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/src/Prowlarr.Api.V1/Search/SearchController.cs`

Search inputs, cache/proxy behavior and returned release mapping. Develop-branch behavior must be verified in the selected release.

### S06 — Prowlarr release resource

`https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/src/Prowlarr.Api.V1/Search/ReleaseResource.cs`

Nullable seeder/leech fields and peer-count mapping; do not fabricate zeros or add duplicate swarm counts.

### S07 — libtorrent streaming guidance

`https://libtorrent.org/streaming.html`

Sequential downloading differs from deadline/seek-aware streaming. Briani deliberately does not implement deadline reprioritization.

### S08 — libtorrent alerts and piece reads

`https://libtorrent.org/reference-Alerts.html`

Piece completion notification and disk-write visibility are distinct considerations; asynchronous read_piece completion and buffer lifetime inform safe bridge behavior.

### S09 — HTTP Semantics, RFC 9110

`https://www.rfc-editor.org/rfc/rfc9110.html`

GET/HEAD, Range, Content-Range, 206 and 416 semantics. Application-specific timeout policy is selected by this plan.

### S10 — BitTorrent v2, BEP 52

`https://www.bittorrent.org/beps/bep_0052.html`

v2 file tree/alignment, hashing and hybrid considerations. Do not derive offsets from filtered display files.

### S11 — mpv stable manual

`https://mpv.io/manual/stable/`

HTTP input, caching, playback controls and rendering configuration. Test the actual native binary packaged per target.

### S12 — SQLite WAL and backup

`https://www.sqlite.org/wal.html`

WAL concurrency/local filesystem constraints. Backup reference: https://www.sqlite.org/backup.html ; coherent app DB snapshots and full-stack backups have different scopes.

### S13 — Docker on Raspberry Pi OS

`https://docs.docker.com/engine/install/raspberry-pi-os/`

Use 64-bit OS/ARM64-compatible Docker installation guidance; follow current Debian guidance for 64-bit Raspberry Pi OS where directed.

### S14 — LinuxServer qBittorrent image

`https://docs.linuxserver.io/images/docker-qbittorrent/`

ARM64/amd64 images, mounts, permissions and first-run Web UI authentication. Avoid an invented environment variable for password setup.

### S15 — LinuxServer Prowlarr image

`https://docs.linuxserver.io/images/docker-prowlarr/`

Multi-architecture deployment and configuration persistence. Container distribution is third-party packaging of upstream software.

### S16 — Docker storage volumes

`https://docs.docker.com/engine/storage/volumes/`

Persist data outside container writable layers; filesystem/mount/permission behavior still matters.

### S17 — Raspberry Pi 5 specifications

`https://www.raspberrypi.com/products/raspberry-pi-5/`

ARM hardware and network/storage connectivity. Product specifications do not establish the performance targets in specification 08.

### S18 — Android SDK command-line tools

`https://developer.android.com/tools`

SDK/tooling use without Android Studio as the active IDE.

### S19 — Android Emulator command-line options

`https://developer.android.com/studio/run/emulator-commandline`

List/start AVDs and configure emulator operation; discover actual installed system-image identifiers.

### S20 — Android TV navigation and hardware

`https://developer.android.com/training/tv/get-started/navigation`

D-pad/focus requirements. Companion hardware guidance: https://developer.android.com/training/tv/get-started/hardware .

### S21 — Flutter supported platforms

`https://docs.flutter.dev/reference/supported-platforms`

Framework support/build requirements; package-level libmpv/TV behavior still needs separate tests.

### S22 — Codex subagents and configuration

`https://developers.openai.com/codex/subagents`

Official entry point currently redirects to current agent-configuration documentation. Model availability/settings are verified again in the installed Codex version; optional templates are not a claim of executed agents.

### S23 — Codex AGENTS.md guidance

`https://developers.openai.com/codex/guides/agents-md`

Scoped repository instructions and file-based agent context.

### S24 — media_kit project

`https://github.com/media-kit/media-kit`

Flutter playback integration and platform/native dependencies. Wrapper license does not determine the license of bundled libmpv/FFmpeg binaries.

### S25 — Android common intents

`https://developer.android.com/guide/components/intents-common`

ACTION_VIEW media handoff; receiving-player features and returned progress are not universally standardized.

### S26 — Media3 supported formats

`https://developer.android.com/media/media3/exoplayer/supported-formats`

Possible Android-only adapter and device-dependent format/decoder support; not a desktop replacement.

### S27 — mpv copyright/license details

`https://raw.githubusercontent.com/mpv-player/mpv/master/Copyright`

Exact build/source/components determine GPL/LGPL obligations. Audit the packaged version, not a generic project label.

### S28 — FFmpeg legal information

`https://ffmpeg.org/legal.html`

LGPL/GPL/nonfree build flags and redistribution considerations. Record enabled components and matching source.

### S29 — ASP.NET Core Minimal API responses

`https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/responses?view=aspnetcore-10.0`

Framework file/result support for completed files; not a safe automatic solution for incomplete torrent files.

## Distribution and license policy

Treat server integration and native embedding separately. Calling qBittorrent/Prowlarr through APIs does not mean their bundled images lose their own license obligations. Embedding libmpv means auditing the actual native build and linked components, not only media_kit's wrapper license. FFprobe/thumbnail tooling likewise carries the licensing of its FFmpeg build.

Before any public binary distribution, produce a per-artifact table: dependency name/version/commit, architecture, origin URL, binary hash, build configuration, SPDX license expression, modifications/patches, required notices and matching-source location. Verify the chosen combination is distributable together. Preserve notices and corresponding source/build scripts where required. Never use a `nonfree` FFmpeg build as though it were automatically redistributable.

The owner has not granted a public project license in this conversation. Do not silently choose an incompatible permissive license or claim the owner approved GPL licensing for their own code. Implementation may proceed privately with full third-party compliance records; public release has an explicit owner-authorization/license check. This is a release ownership decision, not another architecture-planning stage. Keep the code/build provenance ready for a copyleft-compatible distribution if required by the chosen binaries, and do not market the entire bundle as MIT based on a wrapper's license.

Use generated/public-domain/licensed test media with recorded provenance. Do not bundle downloaded copyrighted releases, tracker account data, passkeys, private configuration or user library samples into tests or deliverables. Torrent discovery is provider-configurable; no universal legality or store-approval claim is made. Deployment/publication must comply with the rights and rules applicable to its actual use.

## Validation status of this package

The package contains a plan, schemas, defaults, agent templates and validation tools. It does not contain a completed application, a tested qBittorrent patch, measured Raspberry Pi benchmarks, signed native clients or proof that a particular TV supports HDR. The provided package validator checks document/contract consistency only; implementation tests T01–T32 start `not_run`.
