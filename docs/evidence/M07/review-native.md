# M07 bounded native playback security review

Date: 2026-10-12. Reviewer owns only `client/test_native/native_security_test.dart` and this report. Parent owns production fixes. This experiment uses the production `MediaKitPlaybackAdapter(headless: true, cacheBytes: 8388608)`, vendored media_kit 1.2.6 and real installed `/usr/lib/libmpv.so`, which reports `mpv v0.41.0`. It does not invoke system mpv as a substitute for the Flutter adapter.

Follow-up scope also owns `client/test_native/native_baseline_test.dart`. **Final host result: native boundary, config/script isolation, MP4 and MKV decode pass after parent corrections.** Exact failures, corrections, commands and passes are preserved below. This certifies these local generated fixtures only; release/hardware and full Compose progressive gates remain separate.

## Historical confirmed finding: [P1] Native playlist loading escapes the validated ticket URL

Paths: `client/lib/core/playback/playback_adapter.dart:78–80` and `126–130`; `client/vendor/media_kit/lib/src/player/native/player/real.dart:2432–2437`.

`PlaybackSource` checks the initial source's server origin and scoped route. The native engine can subsequently interpret the delivered bytes as an M3U playlist, regardless of the source's `.mp4` extension or `video/mp4` response type. The HTTP/HTTPS protocol whitelist does not enforce origin or ticket-path scope. Generated M3U content caused actual unauthenticated GET requests to a second owned loopback origin and to an arbitrary path on the first origin, then decoded each linked generated WAV. This gives an attacker-controlled media file a client-side HTTP-request capability beyond the server playback URL. No account-token exfiltration or remote service compromise is claimed; the demonstrated requests used generated fixture content and owned servers only.

The progressive server path checks selected video-file kind, verified torrent layout/available bytes and torrent metadata, rather than a successful bounded media probe before handing out a stream URL (`server/src/Briani.Api/Modules/Playback/ProgressivePlayback.cs:23–28,60–63`). Thus the client must not rely on completed-library FFprobe rejection as its only parser boundary. This review did not run the full server/Compose torrent exploit path.

The adapter also followed an HTTP 302 from its otherwise-valid initial scoped URL to the second owned origin, decoding that resource. This is a distinct observed transport behavior; this experiment does not claim the production Briani stream endpoint currently generates attacker-controlled redirects.

Production correction must prevent untrusted playlist/container references from opening arbitrary resources and explicitly contain redirect behavior while preserving valid media decode. Merely restricting URI schemes, extensions or the initial `PlaybackSource` is insufficient. The initial test failed at that boundary; the parent correction and passing follow-up are documented below.

## Captured observations

Both executions completed the native scenarios in about four seconds, under the test's 15-second timeout. Every listed HTTP request was an actual captured `GET` with `Range: bytes=0-`. Primary and secondary servers bound only `127.0.0.1` on fresh ephemeral ports. The 43-character `a` ticket is fake and appears only in generated fixtures.

| Source fixture served at `/stream/<fake-ticket>/…` | Captured additional request | Native result |
|---|---|---|
| `baseline.mp4`, generated one-second PCM WAV | None | duration 1000 ms; codec `PCM signed 16-bit little-endian` |
| `foreign-playlist.mp4`, M3U linking the secondary origin | Secondary `/foreign-target.wav` | duration 2000 ms; native path changed to secondary URL; PCM decoded |
| `same-playlist.mp4`, M3U linking arbitrary primary path | Primary `/same-target.wav` | duration 2000 ms; native path changed to arbitrary path; PCM decoded |
| `file-playlist.mp4`, M3U linking an owned local three-second WAV | No linked HTTP request | duration 0; empty native path and audio codec; local fixture did not decode |
| `redirect.mp4`, scoped response with 302 to secondary | Secondary `/redirect-target.wav` | duration 2000 ms; PCM decoded; native path remained initial scoped URL |

The local-file observation is limited to this fixture and engine version. It is not an exhaustive local-file/protocol guarantee.

## Configuration/script isolation

Each run set `MPV_HOME` to its own fresh `/tmp/briani-m07-native-review-*` directory, equal to `BRIANI_NATIVE_REVIEW_ROOT`. The test wrote only owned fixtures there: `mpv.conf` with `volume=13`, a Lua script which immediately writes an owned marker if loaded, and generated PCM audio. No user configuration was changed.

Native option reads returned `config=no`, `load-scripts=no`, `ytdl=no`, `cache-on-disk=no`. Volume was 100, and the script marker was absent. The explicit positive decode assertion passed, so an inactive or broken native engine cannot falsely satisfy the boundary test. The observed lavf options were:

```text
seg_max_retry=5,strict=experimental,allowed_extensions=ALL,protocol_whitelist=http,https,tcp,tls
```

## Commands, exit codes and artifacts

The review ran through approved escalated native Flutter test execution, without modifying production/manifest code or loosening native protocol options. Reproduction from the client directory:

```bash
task_native_root=$(mktemp -d /tmp/briani-m07-native-review-XXXXXX)
env MPV_HOME="$task_native_root" BRIANI_NATIVE_REVIEW_ROOT="$task_native_root" LIBMPV_LIBRARY_PATH=/usr/lib/libmpv.so /opt/flutter/bin/flutter test --no-pub --reporter expanded test_native/native_security_test.dart > "$task_native_root/result.log" 2>&1
```

1. Initial run exit **1**, `/tmp/briani-m07-native-review-wvzcBW/result.log`. Captured foreign-playlist, same-origin playlist and redirect requests; no script marker or local-file decode.
2. Final run after adding positive decode/native-option assertions exit **1**, `/tmp/briani-m07-native-review-DOl36q/result.log`. Native test output `00:03 +0 -1`; failing assertion at `client/test_native/native_security_test.dart:127`: the secondary request collection was not empty. It contained `/foreign-target.wav` and `/redirect-target.wav`. Positive decode, native option, volume and script-marker assertions executed before this failure and passed. Same-origin/local-file results are captured in the JSON evidence before assertions; their later assertions were not reached after the first failing boundary assertion.

The source fixture/test is persistent in the repository. Raw logs and temporary configuration/fixture artifacts are ephemeral `/tmp` paths; their substantive observations are preserved above. Every owned HTTP server is force-closed and its subscription cancelled in test cleanup; the production adapter is disposed. No real credentials, copyrighted media, production data or router settings were used.

No packaged-library release, GUI rendering, Raspberry Pi, Android/TV, Windows/macOS, hardware decoding, or actual external-player compatibility result is claimed.

## Parent correction and follow-up review

The parent added `client/lib/core/playback/playback_relay.dart`: per-player loopback server, random capability path, exact issued media/subtitle target map, four upstream requests at once, strict default TLS, bounded connection/header/body waits, no incoming account-token/cookie forwarding, fixed outbound URI and no redirect following. The adapter opens the relay capability through native playback and explicitly sets `access-references=no`, `ordered-chapters=no`, and `autoload-files=no`. Relay target/subtitle registration is now deduplicated and capped at 17 total targets.

Two concrete integration defects were reported and corrected during the review:

- `_register` initially stored a relative `media/...` key while native HTTP used `/media/...`, producing 404 for every request. A bounded Dart URI experiment demonstrated the normalization difference. The parent added a leading empty path segment; reviewed current keys and outgoing URL paths match.
- Vendored media_kit originally opened even a single explicit source via a temporary `loadlist`. `access-references=no` rejected this initial playlist, so all positive fixtures failed with no upstream requests. Sanitized native log evidence confirmed `_command(loadlist, /tmp/<owned-uuid>, append)` failure and `cplayer: Unable to load playlist`. The parent now uses direct `loadfile` for a single explicitly supplied `Media`, retaining native reference restrictions rather than enabling arbitrary local playlist loading.

A separate P2 source review identified overlapping adapter opens/stops overwriting `_relay` and potentially orphaning a capability listener. The parent serializes open/stop/sidecar/dispose with `_lifecycle`, closes an active relay immediately on stop/dispose to interrupt reads, closes the old relay before replacing it, and closes a newly bound relay if disposal started during its bind. Inspection of the corrected source found the reported ownership race resolved. This reviewer did not independently count native listener resources under concurrent opens. Parent relay unit/cancellation tests supply their own evidence.

The relay forwarding review found no new concrete origin, redirect, bearer-header or filesystem-path escape in the inspected corrected code. It accepts only exact registered paths, GET/HEAD, the loopback Host authority, and no query; it rejects positive-content-length requests and forwards no request body. It forwards a bounded list of range/precondition headers to its fixed target. Stream bytes are piped with automatic decompression off and failures abort the downstream socket. Native parser reference blocking remains essential: the local relay alone cannot constrain a native parser that independently opens an absolute foreign HTTP URI.

## Final native verification

The native test initially inherited Flutter's default `TestWidgetsFlutterBinding` HTTP-400 mock, which cannot exercise the new Dart relay. These **explicit native** test files now use an `AutomatedTestWidgetsFlutterBinding` subclass with `overrideHttpClient=false` to allow real Dart socket transport to the owned loopback fixture servers. This is a test-harness prerequisite; no production security option was relaxed and no global user configuration was changed.

Additional retained run evidence:

| Run/log | Exit | Actual outcome |
|---|---|---|
| `/tmp/briani-m07-native-review-ETLND2/result.log` | 1 | All three positive checks fail because Flutter mock HttpClient sends no upstream request. Not evidence of production relay behavior. |
| `/tmp/briani-m07-native-review-2884tU/result.log` | 1 | Real HTTP enabled; WAV, MP4 and MKV still receive no upstream requests due to initial `loadlist` rejection. |
| `/tmp/briani-m07-native-review-VF9W4i/result.log` | 1 | Native security-only diagnostic captures exact initial `loadlist` command errors. |
| `/tmp/briani-m07-native-review-QcypCg/result.log` | **0** | After direct trusted-source `loadfile` correction: security suite plus generated MP4/MKV suite, **3 tests passed**, native test time about 5 seconds. |
| `/tmp/briani-m07-native-review-2diiYG/result.log` | **0** | Follow-up security suite adds recognized HLS MIME; **1 test passed**, native test time about 5 seconds. |

The passing combined command used the same isolated environment shown above, adding `--concurrency=1` and both explicit paths:

```bash
/opt/flutter/bin/flutter test --no-pub --concurrency=1 --reporter expanded test_native/native_security_test.dart test_native/native_baseline_test.dart
```

Every native test has a 15-second timeout, and all owned servers, response gates and adapters have cleanup. All native capability paths and error text are redacted before printing; fake upstream fixture tickets are not real credentials.

Final boundary observations: baseline PCM WAV still decodes for 1000 ms with volume 100, no script marker and all configuration/reference options disabled. Foreign/same-origin M3U, local-file M3U, HTTP 302, HLS under `video/mp4`, and HLS under recognized `application/vnd.apple.mpegurl` each fetch only their initial exact scoped fixture URL. There are **zero** secondary-origin requests and **zero** arbitrary same-origin `/same-target.wav` requests. The recognized HLS case explicitly reports `lavf: Not opening '<redacted relay>' due to --access-references=no`, independently proving that its rejection does not rely solely on the installed FFmpeg's extension/MIME sniffing. No playlist/local-file payload decodes.

### Generated video baselines

`native_baseline_test.dart` invokes installed `/usr/bin/ffmpeg` with argument arrays, shell off and a four-second kill bound to generate eight seconds of `testsrc2` video (160×90 at 24 fps) plus a 440 Hz generated sine tone, H.264/libx264 ultrafast, AAC, one encoder/filter thread. MP4 uses `+faststart`; MKV uses the same generated streams. Generator exit is checked. Host tool reports `ffmpeg version n9.0.2`; no downloaded/copyrighted fixture is used.

| Fixture | Generated size | Native codec and tracks | Actual position/duration | Before complete upstream body? |
|---|---|---|---|---|
| MP4 | 345804 bytes | 160×90 H.264 video track `1`; AAC audio track `1` | 41 ms / 8000 ms | **Yes** |
| MKV | 343981 bytes | 160×90 H.264 video track `1`; AAC audio track `1` | 82 ms / 8064 ms | **Yes** |

Each baseline server supports actual byte ranges. It holds the final byte of an end-reaching response on a completer and sends it only after the native dimensions, nonzero actual position, and real video/audio tracks have been observed (or after a bounded fallback wait). Both passing fixtures made one `GET Range: bytes=0-` request and decoded while that final byte was still withheld. This proves ordinary container decode through the production Flutter adapter/relay before an HTTP body completes. It is **not** proof of verified incomplete torrent-piece delivery, buffering/recovery against qBittorrent, GUI rendering, or hardware acceleration; those require the parent's production harness and hardware gates.

## Final fail-closed option follow-up

The parent added explicit `getProperty('options/<name>') == 'no'` verification for the required configuration/script/reference/disk-cache restrictions, since the pinned native wrapper does not propagate all `setProperty` return errors. The reviewer reran both native files after this change without editing production/vendor/manifest files. Each test's sanitized evidence print now has a localized, documented `// ignore: avoid_print`; analyzer rules remain enabled elsewhere.

Final commands from `client/`, with a fresh owned MPV_HOME/BRIANI_NATIVE_REVIEW_ROOT and `LIBMPV_LIBRARY_PATH=/usr/lib/libmpv.so`:

| Command | Exit | Artifact |
|---|---|---|
| `/opt/flutter/bin/flutter test --no-pub --concurrency=1 --reporter expanded test_native/native_security_test.dart test_native/native_baseline_test.dart` | **0**, 3 tests passed (`00:05 +3`) | `/tmp/briani-m07-native-review-OujZ03/result.log` |
| `/opt/flutter/bin/flutter analyze --no-pub test_native` | **0**, `No issues found!` | `/tmp/briani-m07-native-review-OujZ03/analyze.log` |

Both were executed with explicit approved `exec_command` escalation for the Flutter/native runtime, rather than interpreting the default sandbox's unionfs tool issue as a valid test run. No new native behavior was enabled.

Exact strings returned by installed libmpv `getProperty('options/<name>')` in the security, MP4 and MKV checks with the requested 8 MiB adapter budget:

| Option | Actual returned string |
|---|---|
| `demuxer-max-bytes` | `8388608` |
| `demuxer-max-back-bytes` | `2097152` |
| `network-timeout` | `125.000000` |
| `cache-on-disk` | `no` |
| `config` | `no` |
| `load-scripts` | `no` |
| `ytdl` | `no` |
| `access-references` | `no` |
| `ordered-chapters` | `no` |
| `autoload-files` | `no` |

These are verified **option values**, not measured process memory, decoder/demuxer allocation totals, Pi performance, or an assertion that every media format remains within those values for total RSS. Timeout enforcement should parse the actual decimal representation rather than expecting an integer-form string.

Final positive video observations repeat the generated sizes/codecs/dimensions/tracks above: MP4 position 41 ms / duration 8000 ms; MKV position 41 ms / duration 8064 ms; both observed actual native H.264/AAC 160×90 playback while the final upstream body byte was still withheld. WAV/config/script checks remain passing. All seven boundary scenarios made only their permitted initial primary request, with zero forbidden-origin/arbitrary-primary-path requests; recognized HLS again reports explicit `access-references=no` rejection.

No new concrete finding arose in this final bounded follow-up. Existing parent relay/cancellation tests and full integration/hardware gates remain independently evidenced by the parent.
