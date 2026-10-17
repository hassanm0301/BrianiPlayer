# Definitions Briani can't add, with a remote or keyboard (2026-10-17)

Follow-up to finding 6 in `review.md`, on top of `96a3af5`. Client only.

## What was actually wrong

On TV the app runs with `NavigationMode.directional`. In that mode Flutter 3.47.7's `InkWell` takes focus even when it is disabled (`ink_well.dart`, `_canRequestFocus`). So on `96a3af5`, Down already moved past the last addable definition, and the list scrolled to the definitions left to Prowlarr. An earlier run of the TV test below, before the tile checks were added, passed on unchanged code.

The gap is in traditional mode. A disabled tile can't take focus there, so arrow keys or Tab stop at the last addable definition. That covers the desktop keyboard, and a remote on an Android device that isn't detected as a TV. The TV case also depended on that Flutter behaviour, not on anything in the dialog.

## Change

`client/lib/features/administration/indexer_management.dart:498-514`: each definition Briani can't add is wrapped in its own `Focus`, with the tile's own focus excluded, so it is exactly one stop in both modes. The `ListTile` stays disabled. It keeps the same muted style, can't be tapped, and Select does nothing on it. While it has focus, it takes the theme's focus colour as its background. The order is unchanged: addable first, then the rest.

## Test

`client/test/indexer_management_test.dart`: "a TV remote scrolls past addable definitions to the Prowlarr-only ones", and the same with "the keyboard" (traditional mode). Both drive the dialog with key events only. The list has 8 addable and 7 Prowlarr-only definitions, and only part of it fits in the dialog. Each run checks the following:

- One Down press moves focus from the last addable definition to the first Prowlarr-only one, and the list scrolls to show it.
- That tile is still disabled and shows the focus colour.
- Each further press moves one definition down, through to the last one at the end of the list, with its setup note on screen.
- Select there doesn't open the settings form, and no definition detail is requested.
- Up goes back to the addable ones, which still open.

## Verification

| Command (in `client/`) | Exit | Result |
|---|---|---|
| `flutter test test/indexer_management_test.dart --plain-name 'Prowlarr-only' --no-pub`, with the dialog from `96a3af5` | 1 | Keyboard: focus stays on the last addable definition (`:752`). TV: focus and scrolling work; it fails only at the new check that the tile is wrapped (`:756`). Log: `tv-unaddable-confirm-on-96a3af5.log` |
| `flutter analyze` | 0 | No issues (`tv-unaddable-client-analyze.log`) |
| `flutter test` | 0 | 152 passed: 150 before plus the 2 new (`tv-unaddable-client-tests.log`) |
| `python3 plan/tools/validate_plan.py` (repository root) | 0 | PASS |

## Limitations

Widget tests only: not run on an Android TV with a real remote, or on a desktop build.
