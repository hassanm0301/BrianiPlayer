# Client UI redesign — 16 October 2026

Status: **implemented and verified on Linux desktop; Android phone/TV builds and devices not exercised.** The owner reported that the Linux app "looks unfinished and too complex" and asked for a redesign using current conventions before testing the APK and TV builds.

This is a presentation redesign of the Flutter client. API calls, request cancellation and generation guards, session checks, permission gating, confirmations, server-authored error text, polling and preference persistence are unchanged. No dependency, contract, server or migration change.

## What changed

**Foundation (new)**
- `client/lib/app/theme.dart` — one Material 3 theme for light/dark built from the user's accent: tonal surfaces instead of outlines and shadows, rounded inputs, 2024 M3 progress indicators and sliders, focus rings on buttons (thicker on TV), floating snack bars, semantic success/warning colours (`StatusColors`).
- `client/lib/app/shell.dart` — adaptive navigation shell. Desktop/tablet: navigation rail with app mark, Settings and an account avatar menu, and content on a rounded panel. Phone: bottom navigation bar with the avatar in each top-level page's app bar. TV: one compact row of top tabs (Google TV convention) instead of three giant buttons plus an app bar; the selected tab takes focus at launch.
- `client/lib/core/widgets/` — `adaptive.dart` (Material window size classes, TV detection, gutters), `states.dart` (`EmptyState`, `NoticeBanner`, `SectionHeader`, `StatusPill`, `FocusOutline`), `media_tile.dart` (authorized thumbnails with a bounded per-session cache, artwork tiles), `brand.dart` (signed-out frame), `section_jump.dart` (side jump list with current-section tracking).
- Native window title "Briani Player" instead of `briani_player` (Linux, Windows runners) and a 400×520 minimum desktop window.
- `docs/user-guide.md` and `docs/client-installation.md` updated to the new labels (account menu from the avatar, **Filters**, **Add → Magnet link…**, **Settings → …**); `docs/evidence/M11/self-hosting-docs/validate_docs.py` passes (exit 0).

**Screens**
- Servers, sign-in, device link and approval: centred signed-out frame, password visibility toggle, confirmation before removing a saved server, numbered device-link steps.
- Libraries home: thumbnail Continue-watching row with progress and time left; tonal library cards.
- Folder browser: breadcrumb title, search field, sort menu with current choice, folders-first grid of thumbnails or list with Size/Modified columns, one file menu (also on right-click), details sheet, tidier move picker, automatic next page, up-navigation when opened by link.
- Photo viewer: immersive full-screen view with auto-hiding chrome, arrow keys, slideshow.
- Player: controls overlaid on the video with seek bar, ±10 s, volume, tracks/options panels, keyboard shortcuts and auto-hide (kept visible while touched); TV overlay with large focusable buttons.
- Discover: Add menu (magnet / torrent file) replaces the FAB and upload icon; Latest / Most seeded / Search segmented control; Filters panel with active-count badge; table with sortable headers on wide windows.
- Downloads: cards with status pill, progress and icon metrics, inline Pause/Resume/Retry; details page with summary card, stat tiles and a pinned "Save selection and start" bar.
- Settings and Administration: sectioned cards with help text, segmented choices and accent swatches, side jump list on wide windows; administration fields grouped with units and "leave blank for unlimited" guidance; status pills for health and integrations.
- Account and devices: profile card, password card, device list with device-type icons.

## Work method

The parent built the foundation, shell, Libraries home, connect flow, Account, Settings and Administration. Two parallel workers with disjoint file ownership redesigned (1) folder browser, photo viewer and player and (2) Discover and Downloads. A separate read-only reviewer then audited the whole diff. Every screen was rendered offscreen at desktop 1440×900, phone 412×892 and TV 960×540 in light and dark, from responses recorded against an isolated native dev server plus synthetic discovery/download fixtures (the dev server had no Prowlarr/qBittorrent). That scratch harness is not part of the repository.

## Independent review and fixes

The reviewer counted calls for all 73 generated API methods (identical before/after), and found guards (`identical(`, `_sameAdminSession`, `CancelToken()`), gating and confirmations preserved and no weakened test assertions. Findings and dispositions:

| # | Severity | Finding | Fix |
|---|---|---|---|
| 1 | Blocking | Breadcrumb rebuilt its scroll view when the fade toggled: position snapped back and TV focus was lost | Mask always present; regression test |
| 2 | Should-fix | Administration jump links did nothing for unbuilt sections | All sections mounted in one child; scroll-spy jump list; regression test |
| 3 | Should-fix | TV top bar overflowed with a long server label at large text | Label flexes and ellipsizes; regression test |
| 4 | Should-fix | Touch: player chrome hid during taps/scrubbing | Pointer hold keeps chrome visible (player and photo viewer); regression test |
| 5 | Low | Scroll auto-load grew the window the 5 s Downloads poll refetches | Auto-load removed from the polled list; button kept |
| 6 | Nit | "Move here" allowed the file's own folder | Disabled for the current folder; test fixture made realistic |
| 7 | Nit | Continue watching requested thumbnails on every visit | Bounded per-session cache incl. "no thumbnail" (404); unit test |
| 8 | Nit | Unknown total rendered as 0% | Bar hidden when total unknown |
| 9 | Nit | TV account avatar focus by colour only | Focus outline added |
| 10 | Nit | "Choose playback" default action order | Built-in player is primary and takes focus |
| 11 | Nit | Library list keys, Discover typing flag, shell notifications | Fixed |

A first real-engine run also exposed overflows with taller font metrics in library cards and media tiles; tiles now give the text room in fixed-height cells.

## Verification

All commands ran from `client/` on the local Linux host (Flutter 3.47.7, Dart 3.13.5; see `flutter-version.log`).

| Check | Result / exit | Log |
|---|---|---|
| `flutter analyze` | No issues / 0 | `flutter-analyze.log` |
| `flutter test` | 133 passed (was 117) / 0 | `flutter-test.log` |
| `flutter build linux --debug` | Built / 0 | `linux-debug-build.log` |
| Real Linux app tour (temporary `integration_test` file, removed afterwards) against an isolated native dev server: sign-in, Libraries, folders, real media_kit playback, photos, Discover with Prowlarr down, Downloads, Settings, Administration, Account | 1 passed / 0 | `real-linux-tour.log`, `screenshots/real-linux/` |
| Offscreen screenshot tour (43 scenarios, desktop/phone/TV, light/dark) | No render exceptions | `screenshots/before/`, `screenshots/after/` (curated, 60%) |

Test changes: 16 new tests (`ui_shell_test.dart`, `ui_review_regressions_test.dart`, plus TV D-pad, auto-load, photo keyboard and stricter breadcrumb/read-only tests). Existing tests were updated only where a control changed type or text: ChoiceChip → SegmentedButton finder, GridView → SliverGrid, the magnet flow opened through Add → Magnet link…, unknown counts found by semantics label, one empty-state title without a trailing period, "Move here" instead of "Select library root" (move fixture file placed in a subfolder so the root is a real target), the pairing test settles by time because the approval wait now animates. The desktop/Android integration tests had finders updated to match; they were not run.

## Limitations

- Android APK, Android TV and physical devices were not built or exercised; phone/TV layouts are verified only by offscreen rendering and widget tests with D-pad events.
- `prototypes/client/run_desktop_e2e.py` is blocked before creating resources: its preflight requires `briani-server:m10` to equal the API image in `images.lock.json`, which now names the v1.1.0 image. Images and the lock were not changed. Full-stack download-to-playback through the new UI is therefore not re-certified.
- Windows/macOS builds not run; the Windows runner change is a title string only.
- "Before" screenshots were rendered with Flutter's test default of disabled shadows, which draws elevated surfaces with black outlines; "after" screenshots use real shadows.
- A folder opened by deep link without navigation state still shows "Folder" as its name; the API has no folder lookup.
