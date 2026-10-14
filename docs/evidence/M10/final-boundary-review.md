# M10 final scoped boundary review

Date: 2026-10-13. Independent reviewer; source and saved-evidence inspection only. No production source was edited, no test suite or container was run, and no Pi, SSH, production data, account, or signing access was used. The only review write is this file. This is a review of the listed changes, not whole-product release certification.

## Result

No new reproducible critical/high security or corruption finding was found within the assigned scope. No cosmetic change is requested. Existing hardware, platform, complete-system, coverage, provenance, and signing gates must retain their actual states; this result does not make M10/M11 complete.

## Boundaries examined

- `server/src/Briani.Api/Infrastructure/Persistence/StartupRecovery.cs:10–22` requeues only running work, clears ownership/expiry, advances retry time, and preserves attempt history. Terminal jobs are untouched. `Program.cs:83–84,117–140,168` acquires the exclusive state-directory process lock before migrations/recovery and starts hosted workers only at `RunAsync`. Durable media mutation recovery precedes worker startup. The 1,000-operation startup bound does not silently permit scanners to adopt moved paths: `ScanWorker.cs:128–138` defers a library with pending/running mutation or import intents. `StartupRecoveryTests.cs:9–20` covers a future orphan lease and a terminal job.
- `ContainedStorage.cs:15–23` selects architecture-specific directory/no-follow flags. ARM64 `0x4000/0x8000` matches the octal definitions in the [Linux v6.18 ARM64 UAPI](https://raw.githubusercontent.com/torvalds/linux/v6.18/arch/arm64/include/uapi/asm/fcntl.h); x64 retains `0x10000/0x20000`. Other process architectures fail closed. `LinuxAbiTests.cs:11–13` is a value/unsupported-architecture regression, not native ARM64 execution evidence.
- `client/lib/core/input/shell_navigation_page.dart:10–14` lets primary content-route focus traverse to its parent navigation scope. The route applies through `app.dart:82–85`; modal routes keep their own traversal behavior. `tv_shell_traversal_test.dart:8–34` checks Up from focused content reaches primary navigation. `libraries_screen.dart:22–32` clears cached API/future state during a disconnected transition, and `_NavigationShell` at `app.dart:93–94` tolerates session teardown before route redirection. No new logout transition defect was identified in this change.
- `MediaKitPlaybackAdapter` at `playback_adapter.dart:120–166` awaits the native player handle, applies/readbacks emulator-only `gpu-debug`, retains the required safe player settings, and exposes eager configuration errors through `open`. The locked local `media_kit_video-2.0.1` source implements `Utils.IsEmulator` and defaults emulator decoding to software when no explicit `hwdec` is supplied. The adapter's `auto` preference leaves that plugin decision in place. Existing EGL experiment evidence supports this scoped correction; physical Android and TV playback remain separate gates.
- `tools/operations/briani.py:17–40,231–243` rejects missing Docker memory-limit support and the Landlock ABI/erratum required by `MutationSandbox.cs:27` before Compose startup. The checks read host capabilities and never change boot/kernel settings. `tests/operations/test_operations.py:34–50` includes rejection before Compose mutation and combined missing-capability reporting. This review did not execute host preflight or deploy a stack.
- `ProgressiveValidationBoundaryTests.cs:11–95` checks 13 invalid live-target cases cannot create a session/idempotency operation, stable retries cannot reissue a URL, changed request mode conflicts, and stale generation/auth session cannot reissue a ticket. The new progressive/completed watchdog tests block an actual response write and assert cancellation, no second write, reader release, and initial fixture bytes after live authorization/generation/file changes. They exercise service/SQLite/file boundaries with a fake engine where applicable; they do not substitute for the isolated real-engine or physical-player acceptance gates.

## Saved evidence checked

- `docs/evidence/M10/server-integrated-code-coverage.log`: ten passing test summaries sum to **380**, zero failed/skipped. This is an inspection of the parent's run, not a reviewer rerun or a claim that every required branch reaches its target.
- `docs/evidence/M10/progressive-validation-boundaries.log`: **14 passed**, zero failed/skipped. No additional execution is claimed here.
- `docs/evidence/M11/linux-packaged-startup.json`, `linux-packaged-startup.png`, `linux-packaged-startup.log`, and `linux-runtime-ldd.log`: saved smoke reports passed, a visible window, 230 colors, a fresh profile, and `playbackVerified:false`. The screenshot visibly shows the Servers screen. `tools/release/linux_smoke.py:23–31,87–92` copies the bundle to a temporary directory, launches it there with a fresh HOME/XDG profile and `/usr/bin:/bin` PATH, and terminates the owned child. Runtime system libraries remain required and are recorded. The evidence supports packaged Xvfb startup only, not embedded playback, audio, Wayland, another distribution, or a full clean-install certification. Shutdown `-15` is the harness's intentional termination, not a startup crash claim.
- The parent's M08 Android full-flow rerun was still pending when assigned; no success is asserted by this review. Native/source and resource workers were editing disjoint tooling; their final output is outside this review.

## Reproducibility and snapshot

Inspection commands used `rg --files`, targeted `rg -n`, `nl -ba`/`sed`, `cat`/`tail`, and `sha256sum`, plus the image-view tool. Successful targeted reads and the hash command exited 0. Initial discovery returned nonzero for the guessed nonexistent `M10_acceptance.md`/`clients` paths, and `git status --short` returned 128 because this workspace has no Git metadata; the correct paths were then read. No commit identity or test execution exit code is invented. The official Linux UAPI request succeeded and was read only.

Selected source SHA256 values at the end of inspection:

```text
StartupRecovery.cs  6c7bdbffe8ca9feff130d8b7b5ca3ec2058fcb6598b3dfa328feb26a3697a40a
Program.cs          b60130f0a9ad54730b2bbd33ad839efca89b48dbf9297de228a1eecf3e277a98
ContainedStorage.cs 6b5a16febeb853357cd9a60e6b1f3c39c9a6f82e56cee3d439828ddb7b474d72
playback_adapter.dart e7a35cf1994c061f57e8d9d40cf3e454f3cd79fed5adac6870c943daf1b84614
briani.py           f35c6a1dca56d5593c3df1be5024070cab959fbee28c71de33f40684d3c36a4f
linux_smoke.py      561ad7b934d013603cc5cf783c93db93feb390f3fe53bcdc59fbe2ec8ac1ea0e
```

The parent owns integration, evidence status, and any later revisions. If these boundaries change after this snapshot, the affected review conclusion needs a focused follow-up.

## Follow-up: ARM local operations and helper assembly

2026-10-13, read-only follow-up requested by the parent. No new critical/high finding was identified. No build, test, container, Pi, SSH, or production operation was performed by this reviewer.

`tools/operations/briani.py:109–114,132–150` now chooses the nested `nativeArm64` record on `aarch64`/`arm64` hosts for both API and namespace-guard local candidates. A missing native record raises an error. API local validation still requires the selected exact tag and a valid locked image ID. The inspected Docker ID must equal the selected record's `localImageId` or `runtimeConfigDigest`; this accounts for OCI index IDs versus the configuration ID returned after Docker archive loading without accepting an arbitrary installed image. Guard lookup similarly checks the selected record's two exact IDs. `tests/operations/test_operations.py:60–80` covers both accepted ID forms, a different ID, the amd64 API tag on ARM, and a missing ARM record. Saved `docs/evidence/M10/operations-candidate-regression.log` reports 26 tests and `OK`; it is the parent's run, not a reviewer rerun.

`tools/release/build_arm64_egress.py:28–79` parses the pinned Alpine base and exact nftables package from the source Dockerfile, mounts only a temporary staging directory into the bounded amd64 installer, copies the base image's public APK keys into the staging root, and runs aarch64 package installation with scripts disabled. It does not pass `--allow-untrusted`. The [apk-tools v3.0.8 context source](https://raw.githubusercontent.com/alpinelinux/apk-tools/v3.0.8/src/context.c) confirms default trust keys are loaded relative to the selected root from `etc/apk/keys`/`lib/apk/keys`, and allowing untrusted packages requires the corresponding explicit flag. The final ARM64 build has COPY instructions only; the staged nft executable is checked for ELF magic and ARM64 machine type before assembly. Guard and policy contents/hashes are recorded.

Saved `docs/evidence/M11/arm64-egress-assembly.log` shows 11 aarch64 packages installed and COPY-only ARM64 image export. `arm64-egress-assembly.json` records architecture `arm64`, the same index ID as the image lock, installed package versions/checksums, and **`nativeRuntimeVerified:false`, `armCodeExecuted:false`**. The build log's runtime config digest matches `images.lock.json`'s nested guard record. This supports local cross-assembly/provenance inspection, not native nftables behavior, ARM/Pi deployment, or package reproducibility over future repository changes.

Follow-up SHA256 values:

```text
tools/operations/briani.py          a8ed9466471e6dd337f45d97d017cd3393154a2a729da451d001af995262fd3d
tools/release/build_arm64_egress.py a8f1f5dfef3e755719da756de8ff95bf9e9707940260da0c15bb4633e64f5821
tests/operations/test_operations.py b4cd688593ee22d889daf20dfe6a99355a5e397f918e02d60162573669c287c0
```

## Follow-up: completed Android emulator evidence

The earlier pending-state note is superseded by direct inspection of `docs/evidence/M08/artifacts/1966597629c243fb847df025f1568c0a/result.json`, its `flutter-android-e2e.log`, and `android-tv-render.png`. The result says passed with Flutter exit 0; the log ends with four tests passed. The screenshot visibly shows the generated color-pattern video and focused Pause action. The recorded run used API 36 x86_64 Android TV emulator `emulator-5580`, locked local API image, and isolated fixture swarm; it records the first H.264/GPU decoded frame at engine progress 0.8244411512869052, native cache pause and resumed advancing position, 177,014 saturated pixels out of 290,304 sampled, and completed import browsed in the UI. These are saved observations from the actual run, not a new reviewer execution. This verifies that the parent's complete emulator flow is no longer pending; physical Android/TV and Pi/runtime gates remain deferred/unpassed. Ongoing disjoint source/resource worker outputs were not included.

Follow-up targeted source/log/hash reads exited 0. Default `rg --files` did not enumerate the ignored Android artifact folder; the parent's explicit path was then read successfully. A broad temporary-file inventory encountered inaccessible system-owned directories and yielded no useful source evidence. The official GitLab source URL was unavailable through the web tool; the official Alpine GitHub source mirror above was read successfully. No additional evidence or execution is inferred from those failed searches.

## Follow-up: cold SecretStore path validation

2026-10-13, narrow source review requested by the parent before packaging. No new critical/high defect was found in the correction. The reviewer did not run tests, builds, containers, hardware, Pi/SSH, or production operations.

`ContainedStorage.cs:83–92` replaces the two LINQ `Any` calls in `ContainedDirectory.Validate` with loops over the same characters and the same `Split('/')` segments. Compared with the prior source inspected above, the accepted/rejected paths are equivalent: empty input with `allowRoot:true` returns `"."` first; otherwise null, zero length, length above 4,096, leading slash, backslash, any UTF-16 character satisfying `char.IsControl`, empty/dot/dot-dot segments, and segments longer than 255 all throw the same 400 `invalid_path` error. Valid input is returned unchanged. The loops preserve the original short-circuit order and add no normalization or alternate separator acceptance.

Saved `docs/evidence/M10/resource-fault-secret-store-startup-failure.json` records a real failed cold `secret-prepare` subprocess against the preceding image. Its stack identifies `FileNotFoundException` loading `System.Linq` inside `Validate`, called by `OpenFile` after the confined thread invokes the filesystem operation. `SecretStore.cs:13–14` begins with that contained open and only treats `path_unavailable` as a reason to create a missing key; it does not silently replace an existing key on the loader failure. This is evidence of the preceding cold-start defect, not a successful final run.

The new validation body uses CoreLib operations instead of lazily loading LINQ on that confined thread. The inspected `MutationSandbox.cs:27–37` still applies the same ABI/erratum checks, handled rights, directory rules, and Landlock restriction before invoking the operation; permissions were not broadened. Existing traversal/backslash/Unicode/symlink cases in `IdentityApiTests.cs:239–263,298–308` and malformed/retained-key cases in `SecretPersistenceBoundaryTests.cs:13–42` remain meaningful regression sources, but a warmed test host cannot prove this specific cold-load boundary. The worker's no-warmup standalone baseline and read-only reruns were pending at this inspection and must supply their actual final results separately.

Snapshot SHA256: `ContainedStorage.cs` = `ac2895505326ee43ce4f98ea09831972763010f0698105c48f027ae10a3fb239`; `MutationSandbox.cs` = `cdfae4247ecfd59563f555e9e7aaddf845520b0b8557338783a5888d8d1f5421`. Targeted reads and hash inspection exited 0; a guessed nonexistent `tools/benchmarks/resource_faults.py` search returned 2 before the actual prototype paths were found. Only this review file was written.
