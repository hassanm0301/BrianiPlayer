# M06 — Ship the safe piece-aware playback gateway and sessions

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M00 critical byte proof and M05 production engine lifecycle complete; M03 completed-media behavior available.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 05_PROGRESSIVE_PLAYBACK.md in full, 03_DATA_MODEL.md (generations/sessions), 07_SECURITY.md, 12_API_CONTRACT.md, M00 report. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own HTTP semantics, availability generations, safe reader and session lifecycle.
**Worker A — Luna medium:** independent byte/range oracle and fuzz/property tests under `tests/Streaming/`; no production reader edits.
**Worker B — Luna medium:** SSE/status DTOs, bounded diagnostics and session persistence handlers after interfaces are frozen.
**Reviewer — Sol high:** corruption, lifecycle races, tickets, cancellation and concurrency. Keep critical reader/native bridge changes with one high-reasoning owner.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Integrate M00-proven layout and data source behind the exact interfaces. Map v1/v2/hybrid offsets with padding and ignored files correctly; cache immutable layout by generation, not by mutable filenames alone. Never substitute summed visible file sizes for native offsets.
2. Implement one shared availability poller per relevant torrent, bounded freshness and subscription lifetime. Invalidate on restart/recheck/layout/selection changes. A downloaded bit is necessary but not automatically proof of safe direct filesystem reads; retain the established stock validation or D12 bridge.
3. Build GET/HEAD single/open/suffix range support, permitted multi-range fallback and exact final entity length. Wait before headers for initially missing data; copy only verified contiguous bytes in bounded chunks. Handle headers timeout, mid-body stalls, disconnects and cancellation without emitting success-shaped corruption.
4. Add scoped playback session creation/status/revocation, first-use/idle/absolute expiry and ongoing authorization. A session may report metadata pending before exposing a usable URL. Issue separate scoped sidecar URLs. Ticket URLs never contain ordinary auth tokens or arbitrary file paths; redact them in logs.
5. Enforce per-session/global request limits and one-second permission recheck/cancellation behavior. Valid later Range requests during a long movie must not be rejected simply because the short activation period ended. Admin disable/grant revoke must cancel active readers.
6. Compute UI readiness/buffering indicators from verified data and metadata state, not a fixed download percentage. Prefix threshold is a startup heuristic; container metadata/tail demands still govern. Seeking forward to missing data waits and never changes engine priorities.
7. Expose bounded events/diagnostics and client retry hints. Test browser-independent mpv/VLC HTTP behavior, while documenting that arbitrary external players may handle a long timeout differently. Completed and incomplete sources share session policy without sharing unsafe file-serving paths.
8. Run the entire generated-media matrix and byte-level property tests, including sparse allocation, >4 GiB offsets, recheck races, removed torrents, stalled peers and slow readers. Capture actual first frame before completion and hash equality for delivered ranges.

## Acceptance and execution

Required scenarios: **T01–T09, T15/T18/T19, T26 initial concurrent streaming, T32 lifecycle races.** Definitions are in specification 09; they are not optional examples.

Run unit/contract, `test --suite streaming`, full real-engine integration and the original M00 harness as regression. Run a long-session test using a fake clock for expiry plus an actual playback range-reopen check.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Production progressive gateway/session endpoints, bounded poller/reader integration, permission-aware events, exact HTTP matrix results and first-frame/buffering evidence. Any D12 production bridge must have native/API tests and source/build artifacts.

Write `docs/evidence/M06/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

This is not complete if it serves a partial file through a static file endpoint or claims success only after full download. Baseline MP4/MKV early playback is mandatory; documented tail-metadata limitations cannot be used to waive both baseline tests.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
