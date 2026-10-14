# M00 — Prove sequential playback before the torrent completes

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** None; run this before committing to engine implementation.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 02_ARCHITECTURE.md, 04_DISCOVERY_AND_DOWNLOADS.md, 05_PROGRESSIVE_PLAYBACK.md, 08_DOCKER_AND_PI.md, 09_TEST_AND_RELEASE.md, 11_DECISIONS_AND_RISKS.md. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own the byte-availability proof, engine API audit and HTTP contract.
**Worker A — Luna medium:** isolated legal fixture generator, local seeder and expected-byte oracle under `prototypes/playback/fixtures/`; no gateway edits.
**Worker B — Luna medium:** engine capability probe, pinned-image inventory and repeatable Compose harness under `prototypes/playback/harness/`; do not invent unverified stable APIs.
**Reviewer — Sol high, read-only:** inspect offsets, sparse-file safety, disk visibility and timeout semantics after integration. Native bridge work, if triggered, stays with a Sol high owner rather than a routine worker.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Create an isolated `prototypes/playback/` proof with a minimal .NET host, qBittorrent service and controlled legal local swarm. Use no real personal library. Disable public trackers/DHT for fixtures. Record native architecture, OS, storage, exact image digest, qBittorrent API version and linked libtorrent version.
2. Generate sufficiently long, rate-limited fixtures so playback demonstrably begins before completion: faststart H.264/AAC MP4, MKV with tracks/subtitles, tail-metadata MP4, nonaligned multi-file torrent with an ignored neighbor, v1/v2/hybrid variants, sparse/preallocated backing files, and a file exceeding 4 GiB logical offsets where practical. Record fixture hashes and an independent expected layout.
3. Exercise the pinned stable engine for metadata-only acquisition, file enumeration/index mapping, selected-file priorities, sequential and first/last options, piece states, export, pause/resume and restart. Verify actual API responses and payload byte counters before file consent. Master-source examples are not proof of installed behavior.
4. Implement the smallest piece-aware reader and GET/HEAD gateway that satisfy specification 05. Start with a deterministic fake availability source for arithmetic, then connect the real engine. Reading an allocated file, counting progress or delaying a fixed number of milliseconds is not an availability proof.
5. Audit the pinned engine's status publication and disk-read path. Inject gaps, recheck/restart and rapid status transitions; byte-compare every response with the original. If safety, metadata selection or layout cannot be established, activate D12's narrow same-engine extension. Record a minimal reproduction, patch, native tests, source provenance and exact scope. Never silently downgrade to blind file reads or introduce a second engine.
6. Open the endpoint with actual packaged mpv or a small media_kit harness. Capture first-frame time, torrent percentage/selected-file bytes, buffering and resume, backward seek, missing forward seek and cancellation. Prove that seeking does not invoke piece priority/deadline changes. Test a normal external mpv/VLC HTTP client as a separate compatibility observation.
7. Exercise exact HTTP ranges, final lengths, suffix requests, unavailable first bytes, mid-body timeout and cancellation. No short successful body, zero-filled gap or invalid 416 for merely missing data.
8. Run on native ARM64 Pi 5 when available and on the development machine. A desktop proof is valuable but not a Pi performance result. Write the selected stock-engine or D12 bridge path into `docs/compatibility/torrent-engine.md`; downstream milestones consume this decision, not a new engine-selection exercise.

## Acceptance and execution

Required scenarios: **T01–T09, T11, initial T19/T26/T27. All baseline progressive-byte tests must use the real engine at least once.** Definitions are in specification 09; they are not optional examples.

Create and run `python prototypes/playback/run.py doctor`, `... fixtures`, `... verify` and `... report`; their implementation must return nonzero for failed assertions. Use temporary project-scoped Compose volumes and an explicit cleanup command that cannot touch user volumes. Record exact underlying dotnet/mpv/Docker commands in the report.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

`prototypes/playback/`, deterministic fixtures/manifest, capability report, `docs/compatibility/torrent-engine.md`, any narrowly required engine patch/build recipe, packet/range byte assertions and genuine playback evidence. The evidence must distinguish verified data safety from container-specific delayed startup.

Write `docs/evidence/M00/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

No feature UI, real indexer credentials, production authentication framework or broad torrent scheduler. Do not spend this milestone polishing screens. M01–M04 foundation/auth/library/discovery work may proceed after a clear code-level proof even when physical hardware evidence is unavailable, but M06 and release cannot be certified without the critical proof; preserve `blocked_verification` honestly.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
