# 01 — Product requirements and scope

## Product definition

Briani Player is a self-hosted, media-focused directory browser. A user connects a client to a server, sees only assigned libraries, browses photos/videos, finds torrents, selects media files, downloads into a permitted library, and plays videos in the embedded player or a compatible external application. It should feel straightforward to a nontechnical viewer while exposing useful controls to a power user.

The SFTP comparison describes the **file-oriented experience**, not the transport. Use an authenticated HTTP API and byte-range media delivery. Do not build SSH accounts or an SFTP server.

## Personas and access

**Administrator:** creates libraries/users, assigns capabilities, configures indexers and torrent limits, checks health, performs maintenance and backups. One or more administrators; the last enabled administrator cannot be removed/demoted.

**Library viewer:** lists and plays assigned media, views photos, sets personal display/player preferences, records playback progress. Cannot start downloads merely because a library is readable.

**Contributor:** viewer plus permission to add/download selected media and manage their own download requests, within quotas. Editing/deleting library content needs a separate grant.

Roles are `administrator` and `member`; library capabilities are explicit booleans: `read`, `download`, `manage`. Manage permits supported content operations, not server configuration. Administrators have all capabilities. Download and manage require read. Missing grants deny access.

Discovery requires an authenticated user with download rights to at least one library. No public registration, anonymous browsing, public sharing, or direct exposure of backend service credentials.

## Functional requirements

| ID | Requirement and exact scope |
|---|---|
| R01 | Server is Docker-only; one documented Compose deployment for ARM64 and amd64. |
| R02 | Native desktop clients for Linux x64, Windows x64 and macOS arm64/x64; Android arm64/armv7 as dependency support permits and x86_64 emulator build. |
| R03 | Multiple accounts, saved server profiles, session revocation and per-library authorization. |
| R04 | Each library maps to one directory inside explicitly mounted storage. No overlapping/nested library roots. |
| R05 | Folder/list/grid browsing, filename search, sort/filter, breadcrumbs, pagination, local metadata, thumbnails, supported media identification. |
| R06 | JPEG, PNG, WebP and supported GIF viewing; zoom/pan, fit, next/previous, slideshow and EXIF orientation. No RAW/HEIC/SVG guarantee. |
| R07 | Embedded video playback with play/pause, seek where data permits, volume, fullscreen, tracks, subtitles, speed, aspect/fit and resume. |
| R08 | External-player chooser/preference and Copy playback URL, with scoped credentials and explicit limitations. |
| R09 | Latest, Most seeded and text torrent search through administrator-configured Prowlarr indexers. |
| R10 | Results expose title, bytes, seeders, leechers and derived total peers when valid; source, date and freshness are secondary. Unknown values stay unknown. |
| R11 | Add a discovered torrent, paste a magnet, or import a `.torrent`; choose destination library and files. No arbitrary URL downloader. |
| R12 | Sequential downloading is enabled and verified for Briani-managed downloads. Fixed first/last-piece assist is permitted; seeking never changes scheduling. |
| R13 | Play a supported video during download once its required metadata and initial verified data are available. This is a core release gate. |
| R14 | Buffer on missing data; seeking into already available data works, seeking beyond it waits without reprioritization. A user's cancel/back action always remains responsive. |
| R15 | Show progress, transfer speeds, selected/total bytes, peer counts, ETA when known, errors, file selection and per-download actions. |
| R16 | Pause/resume, retry, remove task vs delete data, queue ordering, file priority, rate limits, seeding policy, tags and tracker summary. Recheck/reannounce are advanced actions. |
| R17 | Import completed supported files into the chosen library without breaking seeding; do not duplicate large media by default. |
| R18 | Persist configuration, jobs and downloads across app/container restarts. Reconcile upstream state; do not assume a successful HTTP call equals a durable completed operation. |
| R19 | Functionality-first UI with simple defaults, contextual advanced controls, per-user layout/player preferences and reset defaults. |
| R20 | Android TV navigation works exclusively with D-pad/Select/Back, visible focus, sensible focus restoration, readable layouts and remote-friendly controls. |
| R21 | Client devices do video decoding. No server transcoding, remuxing or adaptive streaming. |
| R22 | CLI-first Codex workflow; Android Studio is optional for SDK/emulator/debugger convenience, never a required IDE. |
| R23 | High-reasoning orchestration with bounded lower-cost subagents, explicit ownership, tests, evidence and resumable milestones. |
| R24 | Enforce filesystem containment, authorization, credential protection, resource limits and safe third-party URL handling. |
| R25 | Pi 5 performance and real Android TV playback are measured release gates, not assumptions. |
| R26 | Source/license notices, dependency lockfiles, software bill of materials, safe upgrade/backup/restore and honest compatibility documentation. |

## User journeys

### Initial administrator setup

Deploy Compose with mounted storage and generated secret files. Start the native desktop/mobile client, enter server URL, claim the one-time bootstrap code, create the administrator, select mounted directories as libraries, configure indexer access, set limits, and invite/create members. Bootstrap never binds administrator creation to an unauthenticated race.

Prowlarr's own administration UI is used for complex indexer-specific fields; Briani exposes connection health, enabled sources and categories. This upstream admin UI is **not a Briani web client**. Ordinary users never need it. Its port remains localhost-only, reachable by an administrator using an SSH tunnel when remote.

### Browse and watch existing media

Connect → sign in → library → folder → video → embedded player by default. Saved player preference can open an external player instead. Photos open a photo viewer, not mpv. Completed media is available even if Prowlarr is offline.

### Discover, download and watch early

Discover → latest/most seeded/search → select release → choose allowed library → obtain metadata → select video/photos and optional subtitle files → confirm size/quota → download sequentially → Play when eligible. Download continues while watching. If a torrent has multiple selected videos, their natural torrent ordering matters; the UI explains why a later video may wait.

### Power-user operations

Context menus expose file details, player choices, subtitle selection, completed-file rename/move, and carefully separated deletion. Downloads have a details panel for limits, tags, tracker state, priorities, recheck and seeding. Settings centralize advanced defaults without crowding the main screen.

## Release-one boundaries

No Stremio add-on protocol, Torrentio, third-party movie metadata/catalog APIs, custom website scraping, Jackett adapter, qBittorrent search plug-ins, Usenet, browser client, iOS, casting/DLNA/AirPlay, recommendations, episode recognition, automatic TV-series subscriptions, offline client synchronization, arbitrary executable downloads, DRM service integration, cloud-hosted account system, or user-executed scripts.

No seek-aware torrent streaming, piece-deadline scheduler, automatic transcoding or server-side HDR tone mapping. HDR and advanced audio work only when the client engine, render path and hardware support them. External playback provides an alternative, not a universal guarantee.

Customization does not mean mirroring every qBittorrent setting or building a plugin platform. Implement the enumerated controls; retain upstream admin access for unusual infrastructure settings.

## Important limitations to show users

“Most seeded” means highest reported seeder count among fetched results, **not all popular torrents worldwide**. Availability and freshness depend on configured indexers. No provider is bundled or advertised as a source of unauthorized copyrighted content.

Sequential downloading is approximate and peer-dependent. Containers may need metadata at the file end; fixed metadata assistance improves some cases but cannot guarantee immediate startup for every file. Present `Waiting for media metadata`, `Buffering`, `Unsupported format`, and `Download stalled` separately. Do not hide a dependency failure as an empty result list.

## Product acceptance story

An authorized member can search a fixture indexer, select a legal generated MKV/MP4, download it to their library on a Pi 5, start playback while less than the full file is downloaded, experience a controlled buffering interruption, resume without corrupt bytes, finish playback, and find the completed file in the library. The same account can launch a compatible external player and perform the flow with a TV remote. A different unassigned user cannot access any associated media or playback ticket.
