# M07 — Build the functional desktop client and both player modes

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M03–M06 APIs available; M01 Flutter shell/client generation ready.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 06_CLIENT_AND_UX.md, 01_PRODUCT.md, 05_PROGRESSIVE_PLAYBACK.md (client behavior), 07_SECURITY.md (launch/credentials), 12_API_CONTRACT.md. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own routing, shared state/API integration, playback adapter and desktop platform launch security.
**Worker A — Luna medium:** Libraries/Photos/Continue watching screens under assigned feature paths.
**Worker B — Luna medium:** Discover/Downloads/file-selection/details UI under nonoverlapping paths.
**Reviewer — Luna medium for UX/state tests; Sol high for external launch and credential boundaries.**

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Implement server profiles, bootstrap/login/session refresh and clear connection/certificate errors. Store credentials through platform-secure storage; Linux keyring absence falls back to session-only login rather than plaintext. Use generated API models and centralized error/session handling.
2. Build the three main sections Libraries, Discover and Downloads with contextual advanced controls. Add pagination, loading/empty/error/partial-failure states, sort/filter, breadcrumbs, list/grid, sensible keyboard shortcuts and persistent selection/focus. No fake data in production screens.
3. Implement folder browsing, photos with orientation/zoom/pan/slideshow, media details and Continue watching. Show actual metadata and unsupported-format feedback rather than scraped titles/posters. Wire safe rename/move/trash actions with permission-aware visibility and server-side enforcement.
4. Implement torrent queries, freshness/warnings, unknown counts, destination/file selection and download confirmation. Show selected-file progress, speeds, errors, queue/tags/limits and safe removal choices. Explain why a later selected video waits in sequential order.
5. Integrate media_kit/libmpv behind the replaceable adapter with tracks/subtitles, speed/aspect, volume/fullscreen and progress. Handle waiting for metadata/data, controlled reopen after transient HTTP failure, explicit retry/cancel, resume prompt and error details. Bound demux/cache memory and never seek-prioritize the engine.
6. Implement Play with, preferred external player and Copy playback URL. Use an executable plus a validated argument array, never shell interpolation; test spaces/quotes/newlines/Unicode and missing applications. Explain that external progress/resume callbacks are not universal. Copy URLs are bearer capabilities with limited scope/expiry.
7. Adapt Linux Wayland, Windows and macOS window/fullscreen/input behavior, return focus from external applications and dispose players cleanly. Package the actual native libraries used in release tests; system mpv behavior alone is not proof.
8. Run connected end-to-end flows against the real Compose stack: select legal torrent, begin internal playback early, buffer/resume, external handoff and completed import. Test network loss, expired session, permission revoke and upstream discovery outage without losing local UI state.

## Acceptance and execution

Required scenarios: **T01/T02 via client, T19/T20/T23/T24/T28/T29; cross-user UI checks complement T15 server tests.** Definitions are in specification 09; they are not optional examples.

Run `client --task analyze`, `client --task test`, `test --suite desktop-e2e`, platform-specific `client --task build --platform linux|windows|macos` on their actual build hosts. Record unavailable hosts as blocked, not simulated passes.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Usable desktop client with all three primary sections, photo viewer, embedded/external video playback, safe platform launchers, integrated error states and native build/test evidence.

Write `docs/evidence/M07/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

Do not wait for visual polish before delivering functionality. No browser fallback disguised as a desktop embedded player, unsafe custom shell command field, auto-download of executable players or all-platform success claim from a Linux build alone.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
