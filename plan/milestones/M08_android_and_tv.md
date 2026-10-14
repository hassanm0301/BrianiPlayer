# M08 — Complete Android mobile and remote-first Android TV

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M07 shared client behavior implemented; M06 gateway stable.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 06_CLIENT_AND_UX.md, 10_TOOLCHAIN.md, 05_PROGRESSIVE_PLAYBACK.md, 07_SECURITY.md, 11_DECISIONS_AND_RISKS.md (D13). Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own Android native playback/lifecycle/pairing and platform manifest/build changes.
**Worker A — Luna medium:** adaptive mobile layout, file-picker/server-profile/lifecycle tests in assigned Android/mobile client paths.
**Worker B — Luna medium:** TV focus/navigation/control layouts and D-pad widget/integration tests; no separate duplicated business logic.
**Reviewer — Sol high:** playback/render path and ACTION_VIEW boundaries; independent remote-only usability pass.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Configure Android mobile and Leanback launch behavior, runtime TV detection, icons/banners and no-touchscreen requirement as appropriate. Use one shared codebase/APK by default; only thin build flavors when validated toolchain constraints require them. Lock minimum/target API and supported ABI packages with actual native libraries.
2. Adapt phone/tablet layouts, rotation/fullscreen, foreground/background lifecycle, audio focus, back navigation and document-picker torrent import. Do not force users to browse raw Android filesystem paths or grant unrestricted storage merely to stream server media.
3. Implement device pairing and ordinary login on TV, readable content density, visible focus, deterministic directional movement, accessible scroll behavior and focus restoration after asynchronous updates or external-player return. Every action required by the product must be reachable using D-pad/Select/Back.
4. Provide TV-specific playback controls and settings panels rather than enlarging a touch layout. Distinguish remote focus from playback state; avoid shortcuts swallowing Back or trapping the user while buffering. External player ACTION_VIEW must handle no receiver and uninstall/change cases.
5. Test actual media_kit packaged libmpv on Android, x86_64 emulator and a physical ARM TV. Cover ordinary baseline H.264/AAC MP4 and MKV first, then characterize HEVC/4K/HDR/audio/subtitles per device. Emulator success does not prove TV HDR or hardware decoding.
6. Repair integration/render configuration before replacing engines. If ordinary required embedded Android playback remains demonstrably broken, invoke D13: one Media3 adapter behind the existing interface and a suitable native surface. Desktop stays libmpv; unsupported advanced features become truthful capability reports. HDR-only differences do not trigger an unbounded rewrite.
7. Run end-to-end progressive playback, buffering/cancel/resume, external handoff, photos/slideshow, search/file selection and permissions with remote-only interactions. Attach actual screenshots/focus assertions and device/build/native-library versions.
8. Produce installable debug/test APKs and release build configurations. Keep keystores outside source; lack of signing credentials or hardware becomes an explicit verification blocker, not fabricated release acceptance.

## Acceptance and execution

Required scenarios: **T01/T02/T03/T04 on client, T20/T22/T23/T24/T31; native TV portion of T25/T26 as applicable.** Definitions are in specification 09; they are not optional examples.

Run Flutter analyze/widget tests, `test --suite android-e2e`, `test --suite tv-navigation`; use official Android TV AVD discovered from installed SDK and ADB explicit activity. Run physical-device matrix and Android builds with matching ABIs.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Android mobile/TV client, manifest and remote layouts, secure pairing/handoff, device capability matrix, native APKs where build access exists, and genuine emulator versus physical evidence.

Write `docs/evidence/M08/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

Android Studio remains optional. No emulator deployed on the Pi server, no touch-required TV action, no claim that all HDR/Dolby Vision formats are supported. Preserve a replaceable player boundary even if no Media3 fallback was necessary.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
