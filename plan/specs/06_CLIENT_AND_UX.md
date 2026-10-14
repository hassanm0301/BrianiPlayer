# 06 — Native clients, playback and functional UX

## Principles

Prioritize functionality and predictable behavior over decorative design. Keep a clean main interface through progressive disclosure, not by removing useful controls. Advanced options belong in a clearly named menu or settings section and should remain discoverable. Do not copy Jellyfin's visual design or turn this into a poster-driven movie catalog.

Use one Flutter codebase with feature modules, shared API/domain code and device-specific layouts. Default navigation: **Libraries · Discover · Downloads**, plus Settings/Administration. Prefer standard controls and semantic labels over a custom design system. Dark and light themes, system theme by default, user accent choice and density settings. No theme scripting or remote UI plugins.

## Client structure

`app/` owns startup, router, theme, capabilities and server selection. `core/` owns typed HTTP/error handling, secure credential storage, playback interfaces, local device preferences, accessibility and formatters. Feature folders own screens, state and UI-specific view models. Generated API code lives outside hand-written feature code.

Use Riverpod for state/dependency injection, go_router for navigation and Dio underneath the generated API client. Do not mix several competing state frameworks. Use plain immutable models where code generation adds little; generated JSON codecs are appropriate for typed preferences/events.

One active server profile per foreground app session, multiple saved profiles locally. Store URL/display label separately from credentials; disconnect cancels events/requests/players and clears sensitive in-memory state. Connection loss never wipes a user's stored library contents or preferences.

## Screen inventory and behavior

| Screen | Primary actions | Advanced/context actions |
|---|---|---|
| Server/connect | Enter server URL, select saved server, sign in | Edit/remove profile, certificate information, clear credentials |
| First-run/admin | Claim bootstrap, create admin, add library, check services | Mounted-root diagnostics; upstream indexer setup instructions |
| Libraries home | Assigned libraries, recent/continue-watching entries | Sort/pin libraries, show/hide secondary sections |
| Folder browser | Breadcrumbs, folders, videos/photos, open/play | List/grid, columns, sort/filter, details, media-file rename/move/delete where permitted |
| Photo viewer | Fit, next/previous, zoom/pan, slideshow | Orientation/info, slideshow speed; original file remains unchanged |
| Video player | Play/pause, seek, volume, fullscreen, back | Tracks, subtitles, offsets, speed, aspect, player choice, buffering/download details |
| Discover | Latest / Most seeded / Search, essential columns | Indexer/category/size/seed filters, column selection, source alternatives |
| Add download | Destination, metadata/file list, size, confirm | File selection/priority, seeding/rate policy within permissions |
| Downloads | Progress, speed, status, pause/resume, Play | Files, peers/trackers, queue order, tags, limits, recheck/reannounce, remove |
| Settings | Playback, appearance, library behavior, account/devices | Reset section defaults, advanced network information, accessibility |
| Administration | Users/grants, libraries, service health, limits | Indexer link/setup, audit, cache/scan jobs, backup instructions |

All lists have loading, empty, partial/degraded, offline and failure states. Preserve selection and focus when progress updates arrive. Pagination/virtualization is mandatory for large folders/results. Avoid loading every thumbnail immediately.

## Customization contract

### Per-user, synced to server

Theme, accent preset, comfortable/compact density, library list/grid choice, visible desktop columns, default sort/order, remember folder sort, filename extension visibility, default subtitles/audio language, subtitle text scale, playback speed default, resume policy, preferred playback mode `internal`/`ask`/`external`, slideshow interval, continue-watching visibility and simple keyboard shortcuts where applicable.

### Per-device, stored locally

Preferred installed external player, executable/application path, safe argument list, display scaling, window size, fullscreen default, hardware-decoder preference among tested safe values, player cache preset and TV/mobile override. Do not synchronize Windows executable paths to Android or a desktop cache size blindly to TV.

### Administrator

Global transfer limits, active downloads/seeds, connection caps, per-user concurrent downloads, storage safeguards/quotas, default seeding policy, enabled discovery sources/categories, cache/retention limits, external service health and library scan schedules.

Every setting has a type, bounds, sensible default, help text and Reset. Reject unknown settings; never expose a raw qBittorrent JSON proxy or arbitrary mpv command execution. Optional expert mpv controls are limited to an allowlist implemented by the adapter. No scripts, shell commands, custom network protocols or uncontrolled filters.

### Settings placement

A normal user can connect, browse, search, download and play without seeing connection-pool or tracker settings. One overflow menu beside a download opens its advanced panel. Administration is hidden from members but server authorization remains mandatory. TV settings use full-width focusable rows and nested screens rather than tiny desktop dialogs.

## Player adapter

```dart
abstract interface class PlaybackAdapter {
  Stream<PlaybackState> get states;
  Future<void> open(PlaybackSource source, {Duration? startPosition});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double value);
  Future<void> setSpeed(double value);
  Future<void> selectAudioTrack(String id);
  Future<void> selectSubtitleTrack(String? id);
  Future<void> setSubtitleDelay(Duration delay);
  Future<void> stop();
  Future<void> dispose();
}
```

Define typed source/state/error/capability models before implementing the adapter. Expose actual position, duration when known, buffering, track choices and native errors. UI must not call libmpv-specific APIs directly.

Initial implementation is `MediaKitPlaybackAdapter` across native targets. Player instances are not global immortal singletons; ownership and disposal follow screen/session lifecycle. One foreground video player per client. Disable auto-loading arbitrary user mpv config/scripts. Embedded subtitle tracks are supported; approved sidecars receive their own scoped stream access. Track metadata must never expose server paths.

Persist actual embedded playback position every 15 seconds and on pause/exit, coalescing changes. Mark watched after 95% only when duration is known and plausible; user can clear/mark manually. A failed open or file download completion is not watched. On return from external playback, do not fabricate a position; offer a manual watched action or preserve the previous internal position.

Normal codec/container compatibility is inherited from the bundled engine, not a promise of “every video.” Unsupported content is shown with a clear error and external-player action. Image display uses Flutter image rendering, not a video engine. FFmpeg/Media3 alternatives discussed previously are not parallel default implementations.

## External players

**Linux/Windows:** detect a short list of known installed players and allow a local executable picker. Invoke the executable with an argument array and shell execution disabled. Replace a single validated `{url}` argument slot; no shell-string concatenation, command substitution or injection through filenames. Avoid handing `.bat`/`.cmd` scripts arbitrary URLs on Windows; supported launchers are executables or vetted adapter commands.

**macOS:** use a tested application launch adapter; network access/entitlements and packaged native libraries must be tested on macOS. Do not assume `open URL` selects a media player instead of a browser.

**Android/TV:** send `ACTION_VIEW` with the media URL and appropriate MIME type through a minimal native channel or tested plugin. Handle no handler, disabled/uninstalled preferred package, intent failure and lifecycle return. Use only necessary package-visibility declarations; do not request broad application enumeration without justification. Some players require their own supported integration; unsupported apps are not advertised as compatible.

Offer Play internally, Choose external player, Preferred external player and Copy playback URL. The URL points to Briani, never the indexer or local server path. External URL expiry, no automatic progress callbacks, subtitle limitations and network reachability are documented. Do not assume Kodi or every installed media app can open the same intent without testing. VLC/mpv are baseline compatibility targets, not hard dependencies.

## Android mobile

Minimum product OS is Android 8 / API 26, or a higher floor required by the locked toolchain if necessary with an explicit compatibility report. Target SDK is the current stable level supported by the chosen Flutter/Gradle stack, recorded in the lock report. Phone and tablet layouts share adaptive breakpoints.

Use secure OS storage for credentials, lifecycle-aware playback pause/resume, audio focus and interruption handling, screen-awake only while actively watching, and system Back behavior. Background torrents continue on the server. No client storage permission is needed for ordinary server playback. Import `.torrent` via the system document picker and upload bytes; do not request broad filesystem access.

## Android TV

Provide a TV launcher manifest/banner and explicitly declare touchscreen not required. Detect television mode using platform capabilities, with an override for development. Use a dedicated focus layout, not a blown-up phone screen.

Every interactive element is reachable with D-pad; focused state is obvious without color alone. Back dismisses menu → exits fullscreen/player → returns folder → app home, with no focus trap. Restore the previous item and scroll position after returning from playback or details. Long lists scroll while maintaining focus. Context menus have visible button alternatives, not long-press-only actions. Player overlays time out without swallowing the next intended navigation key. Hardware media keys operate playback appropriately.

For entering credentials, allow a standard login screen and a device-link flow: TV requests a random secret plus short human code; a signed-in mobile/desktop client approves that code for its own account; TV polls until success/expiry. Code expires in five minutes, approval displays device name/server, polling is rate limited and no password is shown on TV. This is local-server pairing, not a cloud identity system.

Advanced admin operations remain reachable on TV when authorized, but ordinary setup is optimized for desktop/mobile. Do not silently remove file/download features from TV because touch widgets were easier.

## Accessibility and performance

Semantic labels, keyboard shortcuts and focus order are testable requirements. Respect text scaling, contrast and reduced-motion preferences. Favor icon+label over unlabeled symbols. Use placeholder previews, bounded image cache, virtualized lists and incremental events. No animated poster wall or constant high-frequency redraw for the full download list.

Test desktop Linux on Wayland and X11 where available. Test Android/TV both emulator x86_64 and real ARM hardware. Real 4K/HDR is a compatibility exercise, not an emulator-derived guarantee. If the embedded Android renderer fails a required ordinary playback case, fix the integration or apply the controlled Media3 contingency in decision D13; an external-only fallback cannot silently replace required embedded baseline playback.
