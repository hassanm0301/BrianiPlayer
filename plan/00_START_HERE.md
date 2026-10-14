# Briani Player — complete implementation plan

**Plan version:** 1.0 · **Date:** 12 October 2026 · **Status:** ready for implementation, not an implemented or benchmarked application.

## What is being built

A self-hosted, media-oriented file browser with user-controlled libraries, torrent discovery and downloads, photos, embedded video playback, and external-player handoff. Server deployment is **Docker Compose only**, targeting a **64-bit Raspberry Pi 5** and Linux x86-64. Clients are native Flutter applications for Linux, Windows, macOS, Android phones/tablets, and Android TV. There is no web client and no Stremio/Torrentio integration.

Users must be able to watch a video **before its torrent finishes downloading**. Downloads are sequential, with a fixed first/last-piece metadata assist. Seeking does not change torrent piece priorities. Missing data causes buffering, never fabricated bytes or premature successful EOF.

## How to execute this package

1. Place this package in the repository as `plan/`. Copy `plan/AGENTS.md` to repository-root `AGENTS.md`; that file is written for this location. Do not overwrite existing repository instructions without reconciling them.
2. Use **GPT 6.1 Sol / high** as the main orchestrator for each numbered milestone. Use the scoped worker/reviewer policy in `agents/EXECUTION_PROTOCOL.md`. Model identifiers and available reasoning settings must be verified in the installed Codex environment; examples are supplied, not permission to invent a model that is unavailable.
3. Start with `milestones/M00_playback_proof.md`, then execute M01 through M11 in numeric order. Each file is a complete execution assignment, with dependencies, inputs, ownership, tests, and completion criteria. Reference specifications are read-only input, not separate implementation milestones.
4. Read only the files listed by the active milestone, plus `AGENTS.md` and current evidence. Do not paste this entire package into every agent. Keep the files available locally so workers can retrieve narrow sections.
5. Run the prescribed checks, save evidence, update `evidence/status.json`, and write the milestone handoff. A missing Raspberry Pi, TV, macOS runner, signing key, or external player is a **recorded verification blocker**, not an invented test pass. Continue independent tasks, but do not publish a release claiming unsupported evidence.

### Prompt to use for each milestone

```text
Implement plan/milestones/M00_playback_proof.md in this repository.
Use GPT 6.1 Sol high as orchestrator. Follow AGENTS.md and
plan/agents/EXECUTION_PROTOCOL.md. Read the milestone's listed specifications.
Delegate bounded implementation/tests to the prescribed lower-cost subagents;
reserve higher reasoning for protocol, concurrency, security, and integration.
Implement and test, rather than returning another plan. Do not change scope.
Integrate worker changes, run acceptance checks, address failures, and record
truthful evidence plus a concise handoff. Continue all unblocked work. Never
claim real-device tests, agent use, or release artifacts that did not occur.
```

Replace the milestone filename for subsequent runs. This is an execution instruction, not a guarantee that one model invocation can finish an arbitrarily large milestone. Resume from the checkpoint rather than throwing away work when context or usage limits intervene.

## Package map

| Location | Purpose |
|---|---|
| `AGENTS.md` | Small, always-loaded project invariants and implementation rules |
| `specs/01_PRODUCT.md` | Scope, detailed requirements, permissions, exclusions, defaults |
| `specs/02_ARCHITECTURE.md` | Fixed stack, modules, storage, workflows, ownership boundaries |
| `specs/03_DATA_MODEL.md` | Tables, keys, transitions, quotas, recovery rules |
| `specs/04_DISCOVERY_AND_DOWNLOADS.md` | Prowlarr, qBittorrent, metadata and file selection, import/seeding |
| `specs/05_PROGRESSIVE_PLAYBACK.md` | Highest-risk subsystem: verified pieces, HTTP behavior, buffering |
| `specs/06_CLIENT_AND_UX.md` | Flutter architecture, screens, customization, external players, TV |
| `specs/07_SECURITY.md` | Authentication, authorization, path containment, networking, secrets |
| `specs/08_DOCKER_AND_PI.md` | Installation, ARM64 builds, performance budgets, backup, upgrades |
| `specs/09_TEST_AND_RELEASE.md` | Automated and hardware acceptance matrix, CI, release gates |
| `specs/10_TOOLCHAIN.md` | CLI-first Codex/Flutter/Android development and platform builds |
| `specs/11_DECISIONS_AND_RISKS.md` | Decision record, rejected alternatives, predetermined contingencies |
| `specs/12_API_CONTRACT.md` | API conventions, endpoint inventory, events, client-generation rules |
| `specs/13_TRACEABILITY.md` | Every discussed requirement mapped to implementation and tests |
| `specs/14_SOURCES_AND_LICENSING.md` | Primary references, verification notes, dependency/distribution policy |
| `contracts/openapi.yaml` | Machine-readable v1 API contract, schemas, security, responses |
| `contracts/defaults.json` | Authoritative proposed v1 operating defaults and limits |
| `agents/` | Orchestration policy, worker prompt, handoff, optional Codex templates |
| `milestones/` | M00–M11 executable work packages |
| `evidence/` | Initial status and reusable evidence template; no test results fabricated |
| `tools/validate_plan.py` | Validates package references, milestone ordering, defaults and API structure |

## Implementation order and release gates

| Milestone | Deliverable |
|---|---|
| M00 | Reproducible sequential-playback proof; pinned qBittorrent/libtorrent compatibility |
| M01 | Repository, builds, contracts, CI foundation, multi-architecture images |
| M02 | Authentication, bootstrap, users, devices, library permissions, secure paths |
| M03 | Folder libraries, photos, probing, thumbnails, completed-file delivery |
| M04 | Latest / Most seeded / Search through Prowlarr; source resolution |
| M05 | Production download lifecycle, metadata selection, quotas, import and seeding |
| M06 | Production progressive gateway, playback sessions, concurrency and recovery |
| M07 | Functional Flutter desktop application with embedded and external playback |
| M08 | Android mobile and TV, D-pad usability, hardware/player validation |
| M09 | Customization, administration, onboarding and operations |
| M10 | Security, resilience, performance and complete-system acceptance |
| M11 | Signed/reproducible packaging where credentials exist, docs, release audit |

M00 is deliberately first. An incomplete file served by a conventional file endpoint is **not** sufficient. Likewise, byte availability must not be confused with a player's ability to open a particular container before all required metadata arrives.

## What has been resolved versus what is measured

The product scope, stack, module boundaries, APIs, defaults, tests, milestone order, and agent policy are selected here. No second product-planning round is required. Implementers still must resolve compiler errors, inspect the actual pinned dependency API, and measure hardware behavior. Those are engineering and verification tasks, not permission to reopen framework selection or remove essential features.

Performance figures in this package are **targets to validate**, not claims that a Pi 5 has already achieved them. Universal HDR/Dolby Vision, arbitrary external-player behavior, complete torrent-index coverage, and uninterrupted playback with inadequate peers are explicitly not promised.

## Validate the planning package

From the repository root after placing this directory at `plan/`:

```bash
# In a development virtual environment with PyYAML available:
python plan/tools/validate_plan.py
```

The validator checks references, identifiers, defaults and OpenAPI structure. Installing `openapi-spec-validator` adds an optional standards-schema validation pass. Neither check runs the application acceptance tests. The original package's actual validation scope is recorded in `evidence/PACKAGE_VALIDATION.md`.
