# Briani Player logo — 17 October 2026

Status: **implemented; verified on Linux desktop and by an Android debug build. No Android, Android TV, Windows or macOS device or build exercised the new icons.** The owner supplied the logo (pot with a play glyph over the "Briani Player" wordmark) and asked for it to be used where needed without changing the colour palette.

## What changed

- **Master and generator.** `docs/brand/briani-logo.png` is the supplied artwork with the encoder's faint background noise removed and full opacity restored (the file topped out at alpha 254), trimmed to the artwork. `tools/brand/render_brand_assets.py` splits it into the full logo and the pot mark and renders every derivative below. `docs/brand/README.md` lists the outputs and the command.
- **Flutter client.** `BrandMark` is now the pot image instead of a primary-coloured tile with a play icon. It replaces the old tile in the desktop navigation rail (`shell.dart`) and the TV top bar (`remote_navigation.dart`). The server list header (`BrandHeader`) shows the full logo, labelled "Briani Player" for screen readers, instead of the tile plus a "Briani Player" heading. Assets: `client/assets/brand/{logo,mark,app_icon}.png`, declared in `pubspec.yaml`.
- **Android.** An adaptive launcher icon (`mipmap-anydpi/ic_launcher.xml`): white background, the pot inside the 66 dp safe circle, and a one-colour layer for Android 13 themed icons. The TV banner is now the full logo on white (`drawable-xhdpi/tv_banner.png`, 640×360). The old blue folder vectors (`drawable/briani_icon.xml`, `drawable/tv_banner.xml`) and Flutter's default `mipmap-*/ic_launcher.png` were removed; minSdk is 26, so the adaptive icon covers every supported version.
- **Desktop.** macOS `AppIcon.appiconset` (white rounded tile, Apple 824/1024 grid) and the Windows `app_icon.ico` (16–256 px, transparent) replace Flutter's default icons. The Linux runner sets the window icon from the bundled `assets/brand/app_icon.png`.
- **Download page.** Favicon and header mark are inline PNGs of the pot. The CSS rule for the old tile was replaced; the CSP already allowed `img-src data:`.
- **README.** The logo is shown above the title.

No colour token changed. The Material seed colours in `theme.dart`, the download page palette and all UI colours are untouched. The logo keeps its own colours, and launcher tiles use white, the background the logo was supplied on.

## Verification

Commands ran on the local Linux host (Flutter 3.47.7). Logs are in this folder.

| Check | Result / exit | Log |
|---|---|---|
| `python3 tools/brand/render_brand_assets.py`, run twice | Second run byte-identical / 0 | `render-brand-assets.log` |
| `flutter analyze` | No issues / 0 | `flutter-analyze.log` |
| `flutter test` | 149 passed / 0 | `flutter-test.log` |
| `python3 -m pytest -q tests/downloads` | 12 passed / 0 | `downloads-tests.log` |
| `flutter build apk --debug` | Built / 0; `aapt2 dump badging` reports `icon='res/mipmap-anydpi-v21/ic_launcher.xml'` and `banner='res/drawable-xhdpi-v4/tv_banner.png'`, brand assets present in `flutter_assets` | `android-debug-build.log` |
| `flutter build linux --debug` | Built / 0 | `linux-debug-build.log` |
| Real Linux app, isolated XDG data dirs, XWayland | Server list shows the full logo in dark theme; the window carries a 256×256 `_NET_WM_ICON` (read with python-xlib) | `screenshots/linux-servers-dark.png` |
| Download page served locally (`server.py`, API pointed at an unreachable address so no GitHub call) | Header mark renders under the page CSP; no console errors | — |
| Offscreen render with Roboto: desktop rail and TV top bar, light and dark | Mark fits both without layout change | `screenshots/desktop-rail.png`, `screenshots/tv-top-bar.png` |
| Icon sheet: adaptive icon under circle and squircle masks with the safe zone, themed icon, TV banner, macOS and Windows sizes | Pot stays inside the safe circle | `screenshots/icon-sheet.png` |

The offscreen render was a temporary test file, deleted after use.

## Review

Self-review of the full diff: no API, contract, server, migration or dependency change. The only new runtime file reads are Flutter's own asset bundle and, in the Linux runner, a fixed path inside the app bundle resolved from `/proc/self/exe`; a missing file leaves the default icon. `BrandMark` is excluded from semantics because each use sits next to a label (rail tooltip, TV tabs); the full logo carries the product name as its label.

## Limitations

- No Android phone, Android TV, Windows or macOS device or build verified the new icons. Launcher and banner appearance on real launchers is unverified.
- The Linux window icon only applies where the window manager reads it from the window (X11/XWayland). Native Wayland shells take icons from an installed desktop entry, and the Linux bundle does not install one.
- At 16 px (Windows small icon, macOS 16 pt) the pot shrinks to an orange shape with a light triangle; the food details are not legible at that size.
