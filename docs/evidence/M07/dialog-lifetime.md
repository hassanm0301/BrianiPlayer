# M07 dialog controller lifetime

## Change

Rename and magnet entry now use `OwnedTextDialog`, a stateful route child that
creates and disposes its own `TextEditingController`. Transfer settings use a
stateful dialog that owns all six controllers and returns an immutable text
draft to the screen. The screen parses and submits typed `DownloadSettings`
values after the dialog returns; it no longer reads or disposes controllers
while the exit transition can still leave their fields mounted.

## Verification

Commands were run from `client/` using the installed Flutter SDK with the
approved local SDK execution path.

| Command | Exit | Result |
|---|---:|---|
| `flutter analyze lib/features/libraries/folder_screen.dart lib/features/discover/discover_screen.dart lib/features/downloads/downloads_screen.dart lib/core/widgets/owned_text_dialog.dart test/dialog_lifecycle_test.dart` | 0 | No issues found. |
| `flutter test test/dialog_lifecycle_test.dart test/libraries_screens_test.dart test/discover_screen_test.dart test/downloads_screen_test.dart` | 0 | All tests passed. Covers rename submit, magnet cancel, transfer settings submit during dialog exit, and existing libraries/discover/downloads regressions. |

The new screen-level regression tests are in
`client/test/dialog_lifecycle_test.dart`. Their generated API fixture is local
to the test and performs no external network or media access. Each test pumps
through the route's reverse transition and checks that Flutter reports no
mounted-field/controller exception. Rename and settings tests also assert the
typed mutation payload; magnet cancellation asserts that no download request
was created.

## Limits and review

This verifies Flutter widget lifecycle behavior only. No connected Docker E2E,
desktop packaging, Android emulator, Android TV, or physical-device test was
run by this change. The existing download settings numeric validation and
server authorization behavior remain unchanged. No independent reviewer pass
was performed for this bounded worker change; the owning M07 parent should
include these paths in integration review.
