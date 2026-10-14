# M11 — Package the implementation and complete the operational handoff

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M10 required gates passed; any remaining blocker explicitly prevents the corresponding release/support claim.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 09_TEST_AND_RELEASE.md, 10_TOOLCHAIN.md, 13_TRACEABILITY.md, 14_SOURCES_AND_LICENSING.md and all acceptance reports. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own release audit, truthful support matrix and final artifact manifests.
**Worker A — Luna medium:** user/operator/developer documentation and screenshot organization from actual application runs.
**Worker B — Luna medium:** packaging/checksum/SBOM/license-source verification scripts and clean-install tests.
**Reviewer — Sol high for unresolved risks; Luna medium for artifact/document consistency.**

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Rebuild from a clean, locked checkout with the approved source tree. Produce native ARM64/amd64 server OCI images and Compose manifest; verify runtime on native architectures. Include any D12 patch and full matching build/source obligations. Record digests rather than inventing registry locations.
2. Build desktop application bundles on their required hosts and Android mobile/TV APKs with tested native player libraries. Linux AppImage/Windows installer conveniences must not obscure missing base bundles. Sign/notarize only with authorized credentials; unsigned test bundles are labeled accurately.
3. Generate per-artifact checksums, dependency licenses, native provenance, SBOM, corresponding-source/notices manifest and tested toolchain versions. Flutter wrapper licensing does not settle libmpv/FFmpeg obligations. Do not assign the owner's public licensing grant or publish a store listing without authorization.
4. Finish installation, first administrator, indexer setup, user permissions, discovery limitations, sequential buffering/seek behavior, external-player caveats, supported formats/hardware, configuration, upgrades, backups, restore and troubleshooting documentation. Explain no native server install, no web client and no Stremio integration.
5. Run a clean-room installation from produced artifacts, not a developer checkout with hidden SDK/system dependencies. Confirm persistent data survives image replacement and restore/rollback follows documented compatible state. Verify CLI/native client usability without Android Studio installed.
6. Complete the traceability table with actual code paths and evidence references; every acceptance status remains factual. Include known limitations, unresolved environmental gates and a release checklist. Remove secrets, fixture outputs accidentally bundled with runtime, dead feature flags and critical TODOs.
7. Prepare release notes and a local `dist/manifest.json` covering source commit, platform/architecture, artifact hash, signing state and verification status. A reproducibility report must distinguish deterministic rebuild evidence from merely locked dependency intent.
8. Deliver files and implementation handoff. Do not push tags, publish images/apps, modify production servers, register domains/package names or distribute copyrighted test media unless explicitly authorized. The plan allows finishing implementation without a second product-planning session, not bypassing ownership/credentials or real tests.

## Acceptance and execution

Required scenarios: **T25/T27/T28/T30 and final R01–R26 completeness audit; all mandatory prior gates retained.** Definitions are in specification 09; they are not optional examples.

Run `python tools/dev.py release --task verify`, clean-install/restore smoke, artifact checksum verification and all required release suites on the actual built artifacts. Document signing/platform commands and their real exit status.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Release-candidate artifacts in dist/, checksums/SBOM/source notices, complete documentation, final traceability/support matrix and handoff. Mark `release_ready` only when mandatory evidence exists; otherwise deliver an explicitly blocked candidate with exact next verification commands.

Write `docs/evidence/M11/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

No further architectural redesign or new features in release packaging. Do not report “fully implemented and tested” while any required function remains stubbed, any corruption/security gate fails, or hardware tests were not performed.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
