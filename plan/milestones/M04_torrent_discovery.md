# M04 — Implement latest, most seeded and filename search through Prowlarr

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M02 complete; normally execute after M03 for the shared library selector.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 04_DISCOVERY_AND_DOWNLOADS.md (discovery/source resolution), 07_SECURITY.md, 12_API_CONTRACT.md. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own SSRF-safe source resolution, permission boundaries and contract changes.
**Worker A — Luna medium:** Prowlarr typed adapter/capability/error mapping in `server/Integrations/Prowlarr/`.
**Worker B — Luna medium:** snapshot storage, sorting/paging/cache and fixture tests in `server/Modules/Discovery/`; no upstream credential access.
**Reviewer — Sol high:** redirects, proxy URLs, secret leakage and partial-failure behavior.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Connect to administrator-configured Prowlarr through a typed private API client with timeouts, bounded concurrency and explicit health errors. Use sanitized fixture responses for routine tests and a pinned local instance for compatibility checks.
2. Discover configured provider/category capabilities and represent unsupported recent browsing explicitly. Implement latest, most seeded and search as bounded snapshot queries, not promises of an exhaustive global listing. Search results stay useful even when one indexer fails.
3. Normalize title, exact byte size, nullable seeders/leechers/derived total peers, source/date and freshness. Preserve unknown counts; reject negative invalid values. Deduplicate without adding swarm counts from duplicates. Never reinterpret leechers as all peers.
4. Implement asynchronous query creation, user-scoped snapshots/cursors, stable sort, truncation/warnings and short cache with stale labeling. Enforce query length, limits, per-user active query count and upstream concurrency; no requery on every UI redraw.
5. Build opaque source references. Resolve the selected Prowlarr result/proxy endpoint to a permitted magnet or bounded torrent bytes on the server, preserving necessary private access without exposing credentials. Do not assume every `downloadUrl` is a magnet or ask Prowlarr to independently send a download to qBittorrent.
6. Validate redirects/DNS/host policy and all transport payload limits. The approved Prowlarr private origin is a specific exception, not a global allowance for arbitrary internal URLs. Defer arbitrary URL downloading entirely.
7. Implement `.torrent` upload staging with user scope, bounded metainfo parsing and expiry, plus strict magnet validation. Store source provenance safely for the M05 admission pipeline without executing a transfer as a side effect of merely browsing.
8. Test missing credentials, provider failure, delayed/duplicate data, expired results, unsupported feeds, malformed fields, invalid torrent bytes and URL abuse. Document administrator setup through Prowlarr's own private UI; no Stremio or site-specific adapter.

## Acceptance and execution

Required scenarios: **T17, T21, T28, relevant T15/T16.** Definitions are in specification 09; they are not optional examples.

Run unit/contract and new `test --suite discovery`; use a deterministic fixture-indexer/Prowlarr integration profile. Public torrent availability or private accounts are not required for a passing test.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Prowlarr adapter, query snapshots and normalized results, secure source resolution/upload handling, provider-health API and fixture coverage for all partial failure states.

Write `docs/evidence/M04/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

No “all torrents” claim, bundled piracy source, Stremio compatibility or secondary Jackett integration. No store of raw private tracker URLs in client-visible logs.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
