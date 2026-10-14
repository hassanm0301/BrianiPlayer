# M08 connected Android TV E2E

The separate connected device-code pairing scenario now passes on the owned emulator; details and artifact are in [android-pairing.md](android-pairing.md). The playback diagnosis and historical runs below describe the previous checkpoint state and are superseded for normal playback by the later successful workflow recorded in [report.md](report.md).

Status: **emulator gates pass; physical-device verification remains blocked**. The final emulator playback and pairing results are recorded in [report.md](report.md) and [android-pairing.md](android-pairing.md). Historical diagnostics below preserve an earlier black-surface failure that was subsequently resolved; it is not the latest playback result.

## Earlier renderer failure and subsequent harness corrections

The integration harness now matches the TV player UI: it D-pad-focuses the visible `Pause` button text, which also wakes the auto-hiding control overlay. A focused regression verifies TV Play and Pause are focusable text labels (not tooltips) and that Select activates Play. The route-scope-only focus regression remains independent. The real server-profile Connect action can already be focused by its configured autofocus; the connected flow therefore retains the actual D-pad traversal and primary-focus assertion without an invalid unfocused precondition.

The connected run `df32052c268643af8b6e759f3f94e10c` reached selection submission, opened the actual player, and recorded position 83 ms, H.264 video codec, and `gpu` output. The screenshot `artifacts/df32052c268643af8b6e759f3f94e10c/android-tv-render.png` shows a black video region with visible Pause/Tracks controls; the isolated center-region pixel analysis rejected it as lacking the generated color bars. The first-frame readbacks do not substitute for decoded-frame pixels. No cache pause/resume or import checkpoints were reached. This matches the prior native-render limitation in [review-native.md](review-native.md); no production fix is claimed by this test-harness work.

Two earlier invocations are separately classified: `1b89f4e7ab3747688940a5dda0254599` was interrupted by its outer orchestration cell before the runner produced a result (partial checkpoints are retained; it is not a test failure); `e642a48deeb4451e8977f63e6a423d2b` exited at a stale assertion that expected the auto-focused Connect action to be unfocused; `d04a487e308b45649f713ea933fc675a` reached the player but asked the production adapter for unsupported speed 8×. The harness now uses the allowed maximum 4×. These were test harness corrections; no production source was changed by this worker.

## Latest run after TV file-control update

The parent changed TV file rows to use direct focusable controls while preserving desktop `ListTile` presentation. Full run `3bd96dc59b994938a8921f6e5931118b` built a fresh debug APK on the owned API 36 TV AVD and passed the formerly blocked checkbox path. The integration test's actual synthetic fixture caused D-pad focus to reach the Checkbox; its focus/toggle assertions passed and the test reached `selection-submitted`.

The test then opened the embedded player route, but timed out waiting for the Pause control. The visible player UI showed `The action could not be completed. Retry or check the server status.` along with Play, Tracks, and Playback options. No first-frame, cache-starvation pause/resume, Back-from-player, or imported-library checkpoints were emitted. See `artifacts/3bd96dc59b994938a8921f6e5931118b/result.json` and `flutter-android-e2e.log`. No retry was made.

Post-run cleanup check: no M08-labeled containers, networks, or ADB reverse mappings remained. The owned emulator stayed online. This is an emulator result, not physical TV or ARM decode evidence.

## 2026-10-13 resumption check

The project-owned AVD was located at `.tools/android-avd/Briani_Test_TV_API36.avd`, started on port 5580, and confirmed online as `sdk_google_atv64_x86_64`, API 36. The single authorized fresh connected diagnostic attempt was:

| Command | Exit | Result |
|---|---:|---|
| `python3 prototypes/client/run_android_e2e.py --diagnostic-back --timeout 90` | 1 | Stopped before APK build/install: runner expected `briani-server:m10` image `sha256:c70113ab7c784f82a8a627b518f037e8a96bb02b011e4717fdaf10b4572a2cfb`, but the current local tag resolves to `sha256:177dda1d57e8623a30780e18f9d0b5439a9bd54f729d4d98737e3798272db0ca`. No fresh APK or UI test was produced. Result: `artifacts/1d6a6300379a4ba2b1ef77e4e3aa6372/result.json`. |


The image guard now reads `services.briani.localTag` and `localImageId` from root `images.lock.json`, validates the format and exact tag/ID, and applies to preflight and connected runs. Harness syntax check passed (`python3 -m py_compile prototypes/client/run_android_e2e.py`, exit 0). The rebuilt image matched lock ID `sha256:95ab935e5834f4dab1390fbea017dbfd4a99a0d5b998b01e7acf808a89fc9b3b`.

| Command | Exit | Result |
|---|---:|---|
| `python3 prototypes/client/run_android_e2e.py --diagnostic-back --timeout 90` | 0 | Run `cf816e87c82f41fc9dfc65bc465ae8d7`: fresh debug APK built/installed; native Back returned to the library and restored focus; D-pad reached Downloads. Result `artifacts/cf816e87c82f41fc9dfc65bc465ae8d7/result.json`. |
| `python3 prototypes/client/run_android_e2e.py --timeout 480` | 1 | Run `423bfe1cebc94890b43a1498cda4f3a8`: fresh APK; Back/focus/Downloads navigation passed and the pending request appeared. After request activation, the UI remained on the Downloads list and timed out waiting for uploaded torrent file metadata; no playback/import stages ran. `artifacts/423bfe1cebc94890b43a1498cda4f3a8/result.json` and `flutter-android-e2e.log`. |
| `cd client && flutter analyze integration_test/android_e2e_test.dart` | 0 | No analyzer issues in strict nested-control focus helper and new regression. |
| `cd client && flutter test integration_test/android_e2e_test.dart -d emulator-5580 --plain-name 'focus matcher rejects a nested popup but accepts a real button'` | 0 | Regression confirms row text does not count as focused while its nested popup owns focus; Select opens the menu; a FilledButton remains correctly matched and activates. |
| `python3 -m py_compile prototypes/client/run_android_e2e.py && python3 prototypes/client/run_android_e2e.py --timeout 480` | 1 | Run `81a76278973f454598467ad913e18f7c`: Back, Downloads focus, request activation, and download details all reached; D-pad could not focus the leading file-selection checkbox. Failure log and activation diagnostic are under `artifacts/81a76278973f454598467ad913e18f7c/`. |

Run `81a76278973f454598467ad913e18f7c` reaches `download-details-visible`, then fails in `_focusByDpad` for `find.byType(Checkbox).first` (`client/integration_test/android_e2e_test.dart`, around the file-selection step). The focus diagnostics show a primary path through `InkWell` → `ListTile`, while the checkbox finder resolves to the sibling leading control inside that plain `ListTile`. Production layout is `client/lib/features/downloads/downloads_screen.dart` `_fileRow`: a `ListTile` has a leading `Checkbox(onChanged: ...)` and no row `onTap`. This suggests the checkbox is not D-pad reachable from the current focus path; parent-owned production review is needed. No second full run was attempted.

The post-request activation diagnostic in the run result records only a transient route-category and primary focus snapshot immediately after Select. It is retained to distinguish the request tap phase; the later `download-details-visible` checkpoint proves the test proceeded to the details route.

Possible harness clue, not yet confirmed: `Remove request` is rendered by the trailing `PopupMenuButton`'s menu. The focus helper matches the request text through an interactive ancestor, so it may report the row as focused while the trailing actions control owns primary focus; Select could then open the menu instead of invoking the row's `onTap`. Verify the primary focus target and whether the menu is open before deciding whether this is a test predicate issue or an application D-pad traversal issue.

## Environment and scope

- Target: owned Android TV emulator `emulator-5580`, API 36, `sdk_google_atv64_x86_64`.
- Server image: `briani-server:m10`, image ID `sha256:c70113ab7c784f82a8a627b518f037e8a96bb02b011e4717fdaf10b4572a2cfb`.
- qBittorrent image: locked linuxserver/qbittorrent v5.2.4 digest `sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed`.
- Runner uses unique M08 labels, an internal Docker network with no published ports, generated synthetic media, a loopback-only host relay, and one scoped `adb reverse` mapping. The runner installs only the `.devtest` package with `adb install -r`; it does not manually uninstall packages or target another device.
- UI actions use directional/Select key events. The intended remaining gates include real GPU-rendered pixels, progressive playback/cache starvation and resume, track panel and Back focus restoration, and browsing the completed import. None of those gates were reached.

## Commands and results

| Command | Exit | Result |
|---|---:|---|
| `python3 prototypes/client/run_android_e2e.py --preflight-only` | 0 | Emulator and pinned image identities checked; preflight artifact `artifacts/61fc1e9fa1b84ab79a601f6ccdf336b0/result.json`. |
| `python3 -m py_compile prototypes/client/run_android_e2e.py` | 0 | Runner syntax valid. |
| `cd client && flutter analyze integration_test/android_e2e_test.dart` | 0 | No issues found after the focus predicate and diagnostic changes. |
| `cd client && flutter test integration_test/android_e2e_test.dart -d emulator-5580 --plain-name 'focus matcher ignores a merely focused route scope'` | 0 | Bounded focus predicate test passed for focused and unfocused sibling button roots and labels. |
| `cd client && flutter analyze integration_test/android_e2e_test.dart test/server_profiles_tv_navigation_test.dart` | 0 | No issues found after adding Back and Downloads stage markers. |
| `cd client && flutter test test/server_profiles_tv_navigation_test.dart` | 0 | Actual TV server profile screen reaches Connect from Add server using D-pad Down then Left. |
| `python3 prototypes/client/run_android_e2e.py --timeout 480` | 1 | Latest connected run `a4465ad233064a4ca03c49bb0d1f2bab` timed out at 480 seconds after the empty library and host-requested system Back. It did not reach the `Your libraries` predicate or Downloads markers. |
| `python3 prototypes/client/run_android_e2e.py --diagnostic-back --timeout 90` | 1 | Bounded diagnostic `8c5ed2a57c5442ec87b15fb640d1ee02` stopped the Flutter runner 45 seconds after Back because no library-return/Downloads marker arrived. |
| `python3 prototypes/client/run_android_e2e.py --diagnostic-back --timeout 90` | 1 | Corrected route-state diagnostic `80fec6c363ff4ec89232036a00de72c3` confirmed `routeCategory=libraries`, `canPop=true`; app foreground became TV launcher after Back. |
| `python3 prototypes/client/run_android_e2e.py --diagnostic-back --timeout 90` | 1 | After the parent’s Android Back manifest fix, diagnostic `47a71eaf6e074b7fa59dbd21819ef461` observed `flutter-did-pop-route`, restored the libraries screen/focus, then failed with `activeApiProvider` session error while navigating toward Downloads. |
| `python3 prototypes/client/run_android_e2e.py --timeout 480` | 1 | One full rerun `b31adc6e9dbf45be9e50fb62f2901f4e` reproduced the same session provider failure after Back restoration and before Downloads focus. No playback or import gates ran. |
| `python3 prototypes/client/run_android_e2e.py --diagnostic-back --timeout 90` | 1 | Latest bounded focus diagnostic `7da01386fb66429e9a687723b29c19fa`: Back returned to libraries; session remained present through Up/Right/Right; D-pad could not focus Downloads. |

Earlier connected runs exposed and corrected harness defects: text field traversal used an unsuitable mixed arrow route, checkbox matching failed to account for compound controls, and a FocusScope ancestor was mistaken for focus on Connect. The predicate-only test passes. An actual `ServerProfilesScreen` widget test now also passes: after Add server header focus, D-pad Down followed by at most two Left events reaches the profile Connect action. This verifies the latest production TV layout in widget tests only; it does not establish connected-device behavior.

Earlier connected runs passed login, library selection, and reached the real empty library root, then failed at system Back. Their evidence is retained below as history; the parent’s later manifest change corrected that Back transition.

The first bounded diagnostic established that system Back leaves the app: immediately before the key event, the resumed component was `org.brianiplayer.app.devtest/org.brianiplayer.app.MainActivity`; at 1 and 5 seconds afterward it was `com.google.android.tvlauncher/.MainActivity`. The test recorded `back-library-acknowledged` but did not record library return or Downloads focus; the wrapper terminated its Flutter test at 45 seconds after Back. That run's route-state marker payload was empty because Dart's `HttpClient` sent chunked request framing while the test relay only reads Content-Length. The harness now explicitly sets Content-Length and includes back snapshots in failure result JSON; route `canPop`/category from that attempt is unavailable.

A second one-run diagnostic with corrected marker framing captured `routeCategory=libraries` and `GoRouter.canPop=true` immediately before physical `KEYCODE_BACK`; it again moved from the devtest MainActivity to the TV launcher at 1 and 5 seconds. The test did not observe Flutter's legacy `WidgetsBindingObserver.didPopRoute`, and it did not return to the folder's parent library screen. Existing filtered Android logs have no framework back-registration or popRoute diagnostics. This narrows the symptom to the boundary between a poppable GoRouter state and Android's back handling, but does not prove whether the Flutter `setFrameworkHandlesBack` notification or Android 13+ predictive callback path caused it. Flutter SDK docs note predictive back may be handled without `didPopRoute`; the current observer does not instrument the predictive back-gesture commit channel. No further connected run was started.

After the parent’s `android:enableOnBackInvokedCallback=false` change, the bounded Back diagnostic observed `didPopRoute` with `canPop=true`, returned to `Your libraries`, and restored selected-library focus. The next full run hit `Bad state: Sign in to a server first.` from `activeApiProvider` during scheduled provider refresh. The parent corrected nullable session handling and `LibrariesScreen` disconnected rendering; this is no longer the latest failure. The latest bounded focus diagnostic records session present at library restoration and after each of Up, Right, Right. It fails in `_focusByDpad` because the primary context remains a `ListTile` instead of the Downloads navigation destination. The safe failure diagnostic records primary and target widget types. Playback, buffering, import, and browsing remain untested.

The actual-screen server-profile widget test is in `client/test/server_profiles_tv_navigation_test.dart`; it passes against the parent’s latest TV profile layout. The current connected blocker is D-pad focus traversal from the library card to Downloads, after successful native Back and focus restoration.

## Cleanup and limits

Post-run checks found no M08-labeled Docker containers or networks and no scoped ADB reverse mapping. The emulator remained online. `adb -s emulator-5580 shell pm path org.brianiplayer.app.devtest` returned no installed package path; Flutter integration teardown removed the devtest package. No manual uninstall was run. The runner removed its temporary host fixture/config data; the test removes the app-private handoff config and unique saved profile.

This is emulator verification only; it does not certify a physical television, remote, display, or audio device. A separate security/render experiment is not counted as completion of this connected end-to-end gate.
