# M01 — Create the repository, reproducible builds and API foundation

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M00 compatibility report; hardware-only blockers may remain explicitly recorded.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 02_ARCHITECTURE.md, 03_DATA_MODEL.md, 10_TOOLCHAIN.md, 12_API_CONTRACT.md; contracts/openapi.yaml and contracts/defaults.json. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own solution composition, contracts, migrations policy, toolchain lock, Compose and CI root files.
**Worker A — Luna medium:** Flutter shell/router/state structure and generated-client integration in `client/`, using frozen contracts; no independent API design.
**Worker B — Luna medium:** test harness, provider-neutral task runner and contract checks under `tests/` and `tools/`; coordinate files before editing.
**Reviewer — Luna medium or Sol medium:** clean-checkout/build reproducibility and accidental service exposure.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Inspect existing repository work and merge root AGENTS safely. Create the module-oriented server/client/tests/deploy/tools/docs layout from specification 02; do not introduce microservices, generic repositories, CQRS buses or an elaborate plugin framework.
2. Lock supported .NET 10 SDK/packages, Flutter revision, Dart packages, native media binaries, Android toolchain/JDK/Gradle, OpenAPI generator and image digests. Record architecture variants and the M00-selected qBittorrent path in `toolchain.lock.json`. Use real available versions; no fabricated container tag or prerelease chosen for novelty.
3. Copy canonical contracts into repository `contracts/`. Validate OpenAPI, generate the Dart client once, commit generator configuration and add a no-diff regeneration check. Preserve typed errors, nullable swarm counts and int64 byte values. The parent owns any necessary pre-release contract corrections.
4. Build ASP.NET composition with dependency injection, configuration validation, Problem responses, structured redacted logging, correlation IDs, liveness/readiness and cancellation. Establish EF Core migrations/SQLite settings and a clean database test fixture without implementing every feature prematurely.
5. Create the Flutter application shell with server profiles, routing, Riverpod state, secure credential-store boundary, placeholder-free development diagnostics and adaptive desktop/mobile/TV layout foundations. Product screens arrive in later milestones; developer stubs are not declared completed features.
6. Provide Dockerfile and development/production/test Compose separation. Production targets ARM64/amd64, persist `/config` and shared `/data`, publish only intended Briani access, and keep upstream administration private. Use dummy generated test secrets, not baked-in defaults.
7. Implement the portable `python tools/dev.py` task interface described below. Reference GitHub Actions calls these same commands with isolated test data, never UAT/production. Add formatting/analyzers, secret scanning, dependency inventory and contract drift checks.
8. Validate a clean checkout can restore, build, test the skeleton and start Compose. Document optional Android Studio and CLI emulator workflow. Record unavailable Windows/macOS/ARM runners as environmental blockers; do not claim their binaries were tested.

## Acceptance and execution

Required scenarios: **T27 initial packaging, T28 contract generation; existing M00 proof remains reproducible.** Definitions are in specification 09; they are not optional examples.

Create `python tools/dev.py doctor`, `build`, `test --suite unit`, `test --suite contract`, `test --suite integration`, `client --task analyze`, `client --task test`, `client --task build --platform <name>`, `compose --task smoke`, `benchmark --profile pi5`, and `release --task verify`. Each command calls the actual underlying tools with argument arrays, logs versions/exit status and fails on an unavailable required prerequisite. Later milestones implement/add real suite content. Empty suites must be reported `not_run`, never pass. Run doctor/build/unit/contract/client analyze and Compose smoke here.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Working solution and Flutter shell, initial migrations infrastructure, Docker/CI/task runner, `toolchain.lock.json`, generated client and contract checks, environment report and exact clean-checkout instructions.

Write `docs/evidence/M01/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

No arbitrary dependency upgrades in subsequent milestones. No production deploy or repository publication. This milestone establishes buildable foundations, not the finished authentication/library/player feature set.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
