# M07 independent source/security review — initial findings

Reviewed 2026-10-12. Scope: `client/lib/core/session/client_session.dart`, server-profile credential integration, `client/lib/core/playback/{playback_adapter,external_player}.dart`, session/playback screens, and the `media_kit` native initialization patch. Reviewer changed only this evidence file. This is a snapshot while parent/feature integration is ongoing; it does not claim the final integrated tree has these defects.

The reviewed revision guards login/restore/refresh installation with a session epoch, closes pending transports on transitions, serializes credential writes/deletes per profile, and binds refresh retry closures to their original API/epoch. The native patch supplies `config=no`, `load-scripts=no`, and `ytdl=no` before initialization and keeps Android font configuration from re-enabling user config. Scoped subtitle validation accepts production uppercase HMAC hex while retaining same-origin validation. No remaining concrete cross-profile account-token replay or shell interpolation defect was found in these inspected paths.

## Findings

### [P2] Clone multipart bodies before retrying an authenticated upload

Path: `client/lib/core/session/client_session.dart:203–206`; caller: `client/packages/briani_api/lib/src/api/downloads_api.dart:921` and `client/lib/features/discover/discover_screen.dart:428–431`.

The 401 interceptor mutates and resends the original `RequestOptions`, including its `FormData` body. Locked Dio 5.11.1 finalizes that body before the first transport call; attempting to resend it throws `StateError: The FormData has already been finalized`. Thus uploading a `.torrent` after the 15-minute access token expires fails even when rotating refresh succeeds. The catch returns the original 401, presenting a sign-in error while the account is actually renewed.

Reproduction: send the generated multipart upload through an adapter that returns 401 for the original access token and accepts the renewed token. The retry never reaches the adapter. A bounded standalone experiment used the locked package configuration and the production replay pattern with a three-byte generated fixture, returning `final_request_failed=true adapter_calls=1`. Preserve idempotency headers and clone a finalized replayable `FormData` before `dio.fetch`; add a refresh/upload regression.

Evidence command: `/opt/flutter/bin/cache/dart-sdk/bin/dart --packages=client/.dart_tool/package_config.json /tmp/m07_multipart_review.dart`, exit 0. Output: `retry_error=DioException [unknown]: null`; `Error: Bad state: The FormData has already been finalized. This typically means you are using the same FormData in repeated requests.`; `final_request_failed=true adapter_calls=1`. The first attempted `/usr/bin/dart` command printed `unionfs failed` with exit 0 and did not run the experiment; only the direct SDK invocation above is experiment evidence. `/tmp` reproduction is ephemeral.

### [P2] Do not install the progress timer after playback screen disposal

Path: `client/lib/features/playback/player_screen.dart:79–80`; related cleanup: lines 205–209.

`_start` awaits `_open` and then installs `Timer.periodic` without checking `_closing` or `mounted`. Leaving the screen while progress retrieval, resume confirmation, playback-session creation, or native open is pending invokes `dispose` while `_progressTimer` is still null. When startup resumes, `_open` returns because the screen is closing (or completes its pending open), and `_start` creates a new timer that no later disposal cancels. It retains the disposed screen, old API/account tokens and player reference indefinitely; if playback was observed it can continue attempted progress writes on the old transport.

Reproduction for a widget regression: hold `getPlaybackProgress` or adapter `open` on a completer; mount the screen, navigate away, release the completer, and advance 15 seconds. Assert no timer/progress request survives removal. Guard startup continuations and timer creation after awaits. Source control-flow finding; no widget test execution is claimed by this reviewer.

### [P2] Preserve server watched state when rebasing a progress conflict

Path: `client/lib/features/playback/player_screen.dart:145–147`, outgoing update: lines 140–142.

On 409 the screen reads the latest progress but copies only `version`. If another device manually marks this item watched while this screen is playing below 95%, the initial update conflicts, the read sees `watched=true`, and the next timer sends the old `_wasWatched=false` with the new version. It silently clears the explicit watched mark. Startup retention alone does not cover this concurrent update.

Reproduction: begin with version N / watched false and play below 95%; externally mark watched true at N+1; have the screen's next save receive 409 and read N+1 / watched true; trigger another save. The request currently contains watched false. Retain fetched watched state when rebasing a conflict, with explicit user clear handled deliberately. Source control-flow finding; no two-device test execution is claimed.

## Investigation/verification limits

Native playback, GUI, Windows/macOS, hardware decoding, real external applications and real keyring behavior were not exercised by this review. Parent test reports must supply their own commands/artifacts; their prior passes are not reproduced here. The native media parser's behavior with embedded HTTP playlist references and redirects remains an investigation note: validating the initial ticket origin and restricting schemes alone does not prove all subsequent parser requests stay on that origin. Do not treat that observation as a demonstrated exploit or failed gate without a bounded native fixture test.
