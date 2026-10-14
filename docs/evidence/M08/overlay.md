# M08 TV playback overlay evidence

Implemented `TvAutoHideControls` as a reusable wrapper for the parent playback
screen. It retains the child subtree and its focus nodes in an `Offstage`
subtree, hides only during active playback after the configured inactivity
timeout, and keeps controls visible while paused. The hardware-key handler
wakes the controls on directional/Select input and returns `false`, allowing
that same event to continue through Flutter focus traversal and activation.
Back and media keys are left to route/player bindings. A covered route does not
consume keys or continue the overlay timer. Disposal removes the global key
handler and cancels the timer.

Widget coverage uses Flutter's test binding and fake time:

| Command | Exit | Result |
|---|---:|---|
| `cd client && flutter test test/tv_overlay_test.dart` | 0 | 7 tests passed: timeout/mounted child, paused visibility, first-arrow focus movement, first-Select activation, Back, modal-route ownership, and dispose/timer cleanup. |
| `cd client && flutter analyze lib/core/input test/tv_overlay_test.dart` | 0 | No issues found. |

The test log was returned directly by the local Flutter test runner; no log
artifact was persisted. These are widget tests only; no physical TV or emulator
verification is claimed.
