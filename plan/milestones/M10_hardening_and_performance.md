# M10 — Validate security, resilience and Raspberry Pi performance

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M00–M09 implemented; this milestone integrates and closes outstanding genuine verification gates.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 07_SECURITY.md, 08_DOCKER_AND_PI.md, 09_TEST_AND_RELEASE.md, 13_TRACEABILITY.md and all previous evidence. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own triage, integration corrections and acceptance accounting.
**Worker A — Sol high, read-only initially:** independent threat-model/authorization/filesystem/HTTP/native-boundary review; report reproductions before fixes.
**Worker B — Luna medium:** benchmark collector, fault-run automation and traceability reconciliation; cannot turn missing measurements into passes.
Assign fixes to bounded owners after review; do not have the reviewer simultaneously rewrite every audited module.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Reconcile R01–R26 against code, T01–T32 and prior reports. Identify missing feature paths, disabled tests, mock-only acceptance, untested external launchers or unsupported platform claims. Finish required functionality rather than relabeling it out of scope.
2. Run the full isolated real-engine suite and crash matrix. Kill processes between upstream add and DB commit, during import and removal; restart/recheck while serving media; revoke users during reads; simulate disk-full/read-only/missing mounts and network loss. Verify bytes and retained data after recovery.
3. Fuzz/property-test range and torrent/layout parsers, authorization matrices, malformed names/metainfo and image bounds. Test SSRF across discovery URLs, redirects/DNS, tracker/webseed/explicit-peer inputs, not only the first HTTP fetch. Validate the actual container/engine egress policy rather than claiming a bridge network is isolation.
4. Run native Pi 5 measurements with the hardware/storage/network manifest. Measure idle and loaded per-container memory/CPU, file throughput, warm API latency, two completed streams plus a download, progressive playback and 30-minute concurrent workload. Include a longer bounded soak when available and record duration. Numbers from specification 08 are targets, not preexisting results.
5. Diagnose bottlenecks using evidence: storage latency, peer connection count, metadata/scanning, duplicated polling, allocations and cache settings before considering language/runtime changes. Optimize bounded hot paths while retaining correctness. Update conservative shipping defaults only with a recorded benchmark reason and all dependent contracts/tests.
6. Run real Android TV/mobile and Windows/macOS/Linux compatibility evidence that earlier environments could not supply. Device absence is `blocked_verification`; CI emulation and another platform are not substitutes.
7. Perform dependency/image/secret scans and independent critical-boundary review. Fix all critical/high security or corruption findings, rerun affected scenarios, and document residual nonbaseline compatibility limitations without hiding them.
8. Produce an acceptance report with measured values, raw log paths, reproducibility, actual failures/blocked tests and release-blocker list. Do not publish or deploy automatically as a consequence of passing tests.

## Acceptance and execution

Required scenarios: **All T01–T32, with particular focus on T15–T19/T25/T26/T27/T32. Critical paths require the branch-focused coverage stated in specification 09.** Definitions are in specification 09; they are not optional examples.

Run all test suites, `python tools/dev.py benchmark --profile pi5` on actual Pi hardware, native platform/device checks and `release --task verify`. Save logs/versions/exit codes; repeat failed cases after a fix, not until a random pass appears.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Full acceptance matrix, actual Pi benchmark and soak report, platform/device evidence, security findings/fixes, dependency scan report and a truthful release-blocker ledger.

Write `docs/evidence/M10/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

Do not remove early playback, safety checks, low-memory targets or authorization to obtain a green report. Hardware/signing/provider-access blockers permit a code-complete candidate only, not a fully validated release claim.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
