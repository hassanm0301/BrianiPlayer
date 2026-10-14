# M05 — Implement sequential transfers, file selection and seeding-safe import

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M00 engine path proven; M02–M04 complete.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 03_DATA_MODEL.md, 04_DISCOVERY_AND_DOWNLOADS.md, 07_SECURITY.md, 08_DOCKER_AND_PI.md, 11_DECISIONS_AND_RISKS.md. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own admission/reservations, hash ownership, durable state machine, migrations and crash reconciliation.
**Worker A — Luna medium:** typed qBittorrent adapter and curated transfer actions under `server/Integrations/QBittorrent/`, following M00 exact API evidence.
**Worker B — Luna medium:** import/seeding tests and progress/query handlers under separately assigned paths; no independent state machine.
**Reviewer — Sol high:** quota races, unintended payload, duplicate hashes, destructive actions and interrupted imports.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Port only verified M00 adapter behavior. Add durable requests/operations and idempotent source resolution, including timeout-after-add reconciliation. Persist enough source/job identity to recover without duplicate torrents after a crash.
2. Acquire metadata without unintended payload transfer. Reserve a bounded provisional metadata allowance, present all relevant files with opaque IDs and exact sizes, then accept validated selected media/subtitles. Confirm actual selected size/quota before starting; unwanted payload must remain excluded apart from unavoidable shared boundary-piece bytes.
3. Admit work under user/global counts, free-space floor, volume-aware reservations and read-only/missing mount checks. Use stable hidden staging inside the chosen library on the shared mount. Coordinate reservations transactionally and reconcile them after restart; do not double count the same physical volume or hard links.
4. Enable and verify sequential mode plus fixed first/last assist. Default file priority is normal; wanted/unwanted and explicit supported file-priority controls remain available. No player-generated reprioritization. Explain natural ordering when multiple videos are selected.
5. Implement pause/resume/retry, queue position, rate limits, tags, seeding limits, reannounce/recheck and separate remove-task/delete-data semantics. Apply ownership/grant policy to shared references; one user's removal must not stop another authorized active request. Block destructive action with active readers unless an explicit privileged force first cancels them.
6. Monitor one shared upstream state stream/poller with bounded updates, selected-file versus full-torrent progress and nullable ETA. Represent disk error, stalled peer availability, stopped, complete-selected and seeding as distinct states. A progress percentage is not a playback-eligibility result.
7. Import complete supported files using idempotent hard links into the visible library while retaining the engine payload. If hard links are unavailable, use the defined virtual entry rather than silently copying or breaking seeding. Sidecars follow the selected file. Refresh media jobs without rescanning everything.
8. Test interrupted add/selection/import/removal transactions, changed upstream state, manually missing engine jobs, disk-full, resume after container restarts and library disable. Reconcile safely; never auto-delete an uncertain directory as recovery.

## Acceptance and execution

Required scenarios: **T09–T14, T16/T17, T25/T32; sequential settings checked independently of UI.** Definitions are in specification 09; they are not optional examples.

Run unit/contract and new `test --suite downloads`; run `test --suite integration` against the real pinned qBittorrent image and fault-injected storage. Include process kills at defined transaction boundaries.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Production transfer state machine/adapter, metadata selection, admission/reservations, progress/events, power-user controls, import/recovery and a verified seeding-preservation report.

Write `docs/evidence/M05/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

Do not implement a second engine or downloader. Purely mocked API tests do not prove metadata-only selection or actual sequential behavior. M06 consumes these stable download/file IDs and generations.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
