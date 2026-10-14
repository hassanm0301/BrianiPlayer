# M08 independent Android security/native review

Date: 2026-10-12. Reviewer owns only `client/integration_test/android_security_test.dart` and this report. Production adapter, Android manifests/build composition and vendor changes belong to the parent. No subagents were launched by this reviewer.

**Current result: the prepared integration test analyzes cleanly, real Android intent rejection checks pass, and all exercised URL-reference negatives reach their initial fixture without making forbidden requests. The combined test fails the actual video-pixel positive gate because the installed native renderer cannot create a GL context. No Android embedded video/rendering acceptance pass is claimed.**

## Narrow absent-ytdl fallback review

Reviewed `client/lib/core/playback/playback_adapter.dart` `_configure`: only an empty `options/ytdl` readback may be accepted, and only when a nonempty native `options` inventory excludes ytdl option names. All six other configuration/script/reference/disk-cache flags still require exact `no`. A present ytdl feature with an empty/bad readback fails; a missing/unreadable inventory fails; unexpected values fail. The word-boundary regex conservatively catches the base ytdl name and hyphenated variants in the native option-name string. No concrete bypass was found in that inspected fallback.

The reviewer independently fetched the exact upstream commit `78d43740f5`. `options/options.c` lines 459–477 places the three ytdl options under the Lua compile-time guard, while script-loading options have a broader script-runtime guard. This supports an absent-feature interpretation for a binary whose native inventory lacks those options; it does not justify ignoring present security settings. [Pinned upstream option declarations](https://raw.githubusercontent.com/mpv-player/mpv/78d43740f5/options/options.c).

At this commit, the `options` property returns the native option-name list (`access_option_list`/`mp_property_options`, lines 3196–3215); it is registered at line 3739. The initially proposed `option-list` property was corrected by the parent before this review's Android execution. [Pinned upstream property implementation](https://raw.githubusercontent.com/mpv-player/mpv/78d43740f5/player/command.c).

Actual reviewed Android binary reports `mpv v0.36.0-549-g78d43740f5-dirty`; it returned an empty ytdl readback, a 10605-character option inventory with no matched ytdl variants, and exact `no` for config, load-scripts, cache-on-disk, access-references, ordered-chapters and autoload-files. Configured limit strings were forward demux bytes `8388608`, back bytes `2097152`, network timeout `125.000000`. These are option values, not RSS measurements or a physical-device guarantee.

## Native ACTION_VIEW boundary review and checks

Reviewed `client/android/app/src/main/kotlin/org/brianiplayer/app/MainActivity.kt`, `client/lib/core/platform/platform_capabilities.dart`, external handoff in `client/lib/features/playback/player_screen.dart`, and Android manifest/network-security configuration. Dart handoff receives a typed PlaybackSource already bound to its server origin. Native validation independently requires HTTP(S), no user-info/query/fragment, the three-part scoped stream path, bounded ticket/filename, no decoded filename slash/control, and a bounded video MIME. Preferred package names must match discovered compatible handlers; absent/changed handlers and ActivityNotFound/Security exceptions produce fixed safe errors. Launch uses ACTION_VIEW data/MIME, no shell or arbitrary filesystem handoff. The manifest uses limited video intent queries rather than broad package enumeration. No concrete new token/path/intent escape was found in this source review.

The actual Android bridge integration case uses `videoHandlers` only, never launches an external application or fetches its discovery URI. Nine malformed URLs (file/intent schemes, user-info, query, fragment, short ticket, unscoped route, encoded newline and slash) plus an invalid MIME each returned `invalid_media`. Valid discovery returned one handler, within the native 32-handler bound. This is rejection/discovery evidence, not a successful real external-player compatibility test, preferred-player race test or lifecycle-return certification.

## Test implementation and actual native URL observations

`android_security_test.dart` uses `IntegrationTestWidgetsFlutterBinding`, asserts `Platform.isAndroid`, and creates only two fresh app-owned loopback HTTP servers. It uses the production non-headless MediaKitPlaybackAdapter/relay and the actual Android Video widget. Sources have fake 43-character scoped tickets. The generated MP4 fixture comes from `integration_test/fixtures/baseline.dart`, whose provenance records local FFmpeg testsrc2 + sine, 160×90, 24 fps, eight seconds, H.264/AAC, 345804 MP4 bytes. A three-second silent PCM WAV and directories are generated only in app-owned temporary storage. No remote network, user media, arbitrary scripts or OS-storage permissions are used.

Each negative fixture must make an actual initial primary request, preventing a zero-request false pass. Native capability and fixture ticket paths are redacted before printing; no real credential is present. The observed cases:

| Delivered fixture | Actual initial primary request | Forbidden secondary/arbitrary primary request | Native outcome |
|---|---|---|---|
| Generated MP4 positive | GET, Range bytes=0- | None | AAC decode/position 7291 ms, duration 8064 ms; video output unavailable |
| Foreign HTTP M3U, named .mp4 | GET, Range bytes=0- | None | Format rejected |
| Same-origin M3U referencing unscoped target | GET, Range bytes=0- | None | Format rejected |
| HLS with recognized application/vnd.apple.mpegurl MIME | GET, Range bytes=0- | None | Explicit `access-references=no` rejection |
| Initial HTTP 302 to secondary origin | GET, Range bytes=0- | None | Relay rejects redirect |
| M3U referencing an arbitrary HTTP folder | GET, Range bytes=0- | None | Format rejected |
| M3U referencing owned local folder | GET, Range bytes=0- | None | Format rejected; local path not opened/decoded |
| M3U referencing owned local PCM WAV | GET, Range bytes=0- | None | Format rejected; distinct three-second PCM not decoded |

All negative assertions executed and passed in the diagnostic run before its final actual-render pixel assertion failed. These observations independently show the captured requests and parser rejections; the **combined native test remains failed** until a positive video render succeeds.

## Confirmed required-baseline rendering defect

Severity P1 for M08 functionality: the current packaged player does not render the required ordinary generated H.264 video on this Android TV emulator. Native dimensions and a position advanced by audio do not prove a decoded/rendered video frame. The locked media_kit_video Android controller completes its `waitUntilFirstFrameRendered` future on a dimensions event (`android_video_controller/real.dart` around lines 88–125), so that future alone was insufficient evidence.

The reviewer strengthened the positive test to capture and decode an actual integration-test PNG, then sample the center 80% of a black scaffold with no colored UI. Generated testsrc2 must produce substantial saturated pixels and all RGB channels. First capture (200 ms after the dimensions future) was black. A bounded follow-up waits two seconds, records renderer properties, attempts native `screenshot-to-file` to a fresh owned path, then holds the original surface for five seconds so host ADB captures it independently before FlutterImageView conversion.

Actual native errors: `vo/gpu/opengl: Could not create a GL context.` and `vo/gpu: Failed initializing any suitable GPU context!`. Readbacks: `current-vo` empty; `vo-configured=no`; `video-format`, `video-dec-params`, `video-params/pixelformat` and `estimated-frame-number` empty; `options/vo=gpu`. Native screenshot command failed and produced **no decoded PNG**. The data at `/tmp/briani-m08-native-decoded-baseline.png` is the host's `cat: ... No such file` response, not an image artifact or a decoded-frame pass.

The delayed Flutter PNG was 1920×1080, with 1327104 sampled pixels and zero saturated/red/green/blue pixels; only its debug banner was visible outside the sampled region. The independent original-surface ADB PNG is completely black. Thus this is supported by native GL-init failure and independent screen evidence, not solely a possibly incomplete Flutter screenshot API.

Locked media_kit_video 2.0.1 README contains no Android/Impeller integration note. Inspection of its Android VideoOutput.java shows SurfaceProducer integration. Emulator logcat identifies Flutter's Impeller OpenGLES backend. The parent was asked to investigate a bounded parent-owned Impeller/renderer integration experiment before considering any D13 fallback. This reviewer did not edit manifests, disable native security flags or introduce Media3.

## Commands, exits and artifacts

All Flutter/ADB emulator execution used explicit approved `exec_command` escalation; default sandbox ADB listener denial was a tool-permission observation, not an emulator test result. Debug build composition was inspected: namespace `org.brianiplayer.app`, debug application suffix `.devtest`, so generated screenshot extraction uses `org.brianiplayer.app.devtest`. An initial screenshot pull used the namespace and then cache directory; those produced text errors. `adb run-as ... find` located the actual generated files in **code_cache**. Only valid PNG retrievals are listed below.

| Command/run | Exit/outcome | Log/artifact |
|---|---|---|
| `/opt/flutter/bin/flutter analyze --no-pub integration_test/android_security_test.dart` | 0, No issues found | `/tmp/briani-m08-review-security-analyze.log`, `...analyze2.log`, `...analyze3.log` |
| Same targeted analyzer, final diagnostic code | 0, No issues found | `/tmp/briani-m08-review-security-analyze-final.log` |
| `/opt/flutter/bin/flutter test --no-pub --no-uninstall --reporter expanded -d emulator-5580 integration_test/android_security_test.dart` | 1: intent case passes; first native case fails black-pixel check before negatives | `/tmp/briani-m08-review-android-security.log` |
| Background-shell coordination diagnostic | 1, **No tests ran**; owned Flutter test PID stopped after more than two minutes stalled at startup | `/tmp/briani-m08-review-android-security2.log` |
| `timeout --signal=INT 150s /opt/flutter/bin/flutter test --no-pub --no-uninstall --reporter expanded -d emulator-5580 integration_test/android_security_test.dart` | 1: 1 passed/1 failed; all native URL checks observed, final rendered-pixel check fails; native test phase ~17 s | `/tmp/briani-m08-review-android-security3.log` |
| `adb -s emulator-5580 exec-out screencap -p` during the five-second positive hold | 0, valid 1920×1080 PNG | `/tmp/briani-m08-security-adb-original-surface.png` |
| `adb -s emulator-5580 exec-out run-as org.brianiplayer.app.devtest cat code_cache/briani-m08-security-baseline.png` | 0, valid 1920×1080 PNG | `/tmp/briani-m08-security-baseline-first.png`, `/tmp/briani-m08-security-baseline-delayed.png` |

The explicit integration test has 90-second/30-second test bounds, bounded native opens/stops/disposal, and owned server/subscription/temp-fixture cleanup. Generated diagnostic screenshots remain in the debug test app's code_cache for review and can be removed by the parent with owned test-data cleanup. Host logs/screenshots are ephemeral /tmp evidence.

No physical ARM TV, hardware decode, HDR, actual external app launch, private credentials, production data or release signing result is claimed. The parent owns the renderer fix and final emulator/hardware acceptance reconciliation.

## Parent renderer experiment checkpoint

The parent added `io.flutter.embedding.android.EnableImpeller=false` as a bounded manifest interoperability experiment. The reviewer did not edit that production manifest. The same foreground command with a 150-second outer bound was attempted against emulator-5580, preserving every native security option and the same generated fixture/pixel criteria.

`/tmp/briani-m08-review-android-security-skia.log`: exit **1**. `assembleDebug` completed in 12.5 seconds, installation in 1408 ms, then loading failed with `Connecting to the VM Service timed out` from Flutter's integration test device startup. **No tests executed**, no diagnostic hold was reached, and no screenshot was captured for this setting. This cannot prove that disabling Impeller repairs or preserves the GL failure. The intermittent startup failure was escalated to the parent after the second startup stall; further emulator/service recovery and native rerun belong to the parent. Read-only inspection afterward found no current debug-app PID or fresh renderer error in the queried log tail.

The original-surface ADB screenshot was independently viewed: it is completely black. The earlier Flutter screenshot includes the debug banner; the test's center-region sampling deliberately excludes it. Both support the prior measured failure, rather than the unexecuted manifest experiment.
