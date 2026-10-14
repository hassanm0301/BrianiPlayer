# Connected Android TV device-code pairing

Status: **passed on the owned API 36 Android TV emulator**. This adds a real UI/API pairing proof; it does not replace the separate physical TV/remote verification gate.

The runner now has an explicit `--pairing-only` scenario. On `emulator-5580` (`sdk_google_atv64_x86_64`, API 36), the integration test uses D-pad and Select to connect to the fixture profile, choose **Link using another signed-in device**, request a real device code, and display the waiting state. A generated signed-in member account approves through the production inspect/approve API. The TV exchanges its private pairing secret through the production polling API, installs the member session, and loads the libraries screen.

The fixture grants that member read access to one generated library and leaves a second generated library ungranted. The test checks the installed identity against the fixture member, calls the authenticated library-list endpoint, and verifies exactly one result: the granted library. The TV screen shows that library and omits the restricted one. After exchange, the companion API verifies that the human code is no longer inspectable. The existing API contract’s five-minute expiry and private device-secret replay behavior are not re-timed by this emulator workflow.

The actual human code and companion credentials stay in process memory. The loopback approval endpoint accepts only an eight-character code in a bounded JSON body, never persists the body, and responds with boolean proof or a secret-free stage name. Control markers contain only `{}`; there is no pairing-screen screenshot. Runner cleanup removed its labeled containers/network and ADB reverse mapping, and the devtest package and temporary handoff config were absent afterward.

| Command | Exit | Result |
|---|---:|---|
| `cd client && flutter analyze integration_test/android_pairing_test.dart` | 0 | No analyzer issues. |
| `python3 -m py_compile prototypes/client/run_android_e2e.py` | 0 | Runner syntax valid. |
| `python3 prototypes/client/run_android_e2e.py --pairing-only --timeout 360` | 0 | Run `c2bebb959dcf422c88bd620b9b9bf771`; all four safe checkpoints passed: code visible, approval, member library permissions, consumed code. Flutter integration exit 0. |

Result: [result.json](/home/hassan/projects/BrianiPlayer/docs/evidence/M08/artifacts/c2bebb959dcf422c88bd620b9b9bf771/result.json). The fresh debug APK SHA-256 was `e07b1fcf72cf6fc56f88dfa16d08efe6883398d0f873840bc1224ab2d1944d90`; the API image matched locked ID `sha256:95ab935e5834f4dab1390fbea017dbfd4a99a0d5b998b01e7acf808a89fc9b3b`.

Three earlier attempts exposed harness-only setup/focus/framing defects and were corrected before the passing run. A separate interrupted diagnostic exposed a temporary method-placement mistake in the relay handler; it was corrected and structurally checked before the successful run. The parent owns a final rerun of the normal playback workflow because the relay handler is shared with that scenario. No Pi or physical device was used.
