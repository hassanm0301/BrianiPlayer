# M09 — Finish advanced controls, onboarding and Docker administration

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M02–M08 feature slices integrated; missing external hardware gates remain separately recorded.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 06_CLIENT_AND_UX.md, 08_DOCKER_AND_PI.md, 07_SECURITY.md, 03_DATA_MODEL.md, contracts/defaults.json. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own configuration scopes, migrations, deployment/backup safety and integration credential changes.
**Worker A — Luna medium:** organized Settings/Admin screens and preference persistence/reset behavior.
**Worker B — Luna medium:** installer/doctor/backup/restore/upgrade scripts and user docs, using isolated fixtures; no live host mutation.
**Reviewer — Sol high:** secrets, mounted paths, destructive maintenance and privilege boundaries.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Finish all enumerated customization: grid/list, density, visible torrent columns, sort/filter persistence, theme, resume/player/subtitle preferences, continue-watching visibility and reset-to-defaults. Distinguish user-synced, per-device and administrator-only settings; changing one must not accidentally overwrite another scope.
2. Expose curated torrent controls in contextual menus/details and global settings: active counts, connection limits, speed caps, seeding ratios/times, queue/tags/file priority, tracker summaries and advanced recheck/reannounce. Avoid dumping the entire upstream settings API into a member-accessible JSON editor.
3. Complete native-client first run for server address/bootstrap, libraries/users/grants, dependency connection and health, storage limits and safe defaults. Prowlarr indexer-specific configuration may open its separately protected admin UI; no Briani web frontend is introduced.
4. Build the production Compose installer/doctor with native ARM64/amd64 selection, stable mounts, generated secrets and private upstream APIs. qBittorrent first-run credentials follow the actual pinned image; do not invent a password environment variable. Confirm host UID/GID ownership and binding choices explicitly.
5. Provide maintenance commands for full-stack backup/restore/upgrade/rollback through host-side Docker tooling. A consistent backup includes database, keys and upstream state/config; stop/quiesce the whole necessary stack and label whether media payload is included. An online app DB snapshot is not falsely advertised as a full-stack backup.
6. Add supported diagnostics, disk/queue/service health, redacted audit and bounded cache cleanup. Liveness must not fail merely because an optional search provider is down; readiness reflects database/mount failures appropriately. Never mount the Docker socket into Briani to implement an admin button.
7. Test reset, migration, damaged config, lost mount, expired credentials, disabled user, seeding after restore and old-image rollback with matching data backup. Produce plain operator-facing instructions for LAN/VPN/reverse-proxy TLS, private upstream administration and recovery after power loss.
8. Walk through a clean installation with a nontechnical-user checklist and a separate administrator checklist. Move rarely used controls into menus/settings while keeping primary flows direct. No required function remains a dead button or an undocumented upstream workaround.

## Acceptance and execution

Required scenarios: **T25/T27/T29/T32 plus T15 privilege checks and T19 ticket/config regression.** Definitions are in specification 09; they are not optional examples.

Run new `test --suite operations`, `test --suite preferences`, clean Compose install/backup/restore/rollback drills in disposable directories, then client smoke on desktop/TV. Validate actual config defaults against contracts/defaults.json.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Complete customization/admin UX, Docker-only installer and operator commands, safe backup/restore/rollback, troubleshooting guide, tested clean-install/onboarding report and settings scope matrix.

Write `docs/evidence/M09/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

Do not support a parallel native server installer. No automatic production update, destructive disk formatting, router changes, VPN installation or public port opening without authorization. Do not claim an SSD filesystem or Docker networking eliminates all power-loss/egress risk.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
