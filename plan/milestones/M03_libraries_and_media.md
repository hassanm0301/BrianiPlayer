# M03 — Implement file-oriented libraries, photos and completed-video delivery

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M02 complete; M00 byte proof remains available.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 01_PRODUCT.md, 03_DATA_MODEL.md, 05_PROGRESSIVE_PLAYBACK.md (completed delivery/session boundary), 06_CLIENT_AND_UX.md, 07_SECURITY.md. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own media identity, filesystem mutation transactions and ticket/authorization integration.
**Worker A — Luna medium:** bounded scanner/FFprobe/thumbnail jobs in `server/Modules/Media/Processing/`.
**Worker B — Luna medium:** library query/filter/pagination and photo metadata handlers in `server/Modules/Libraries/Queries/`, plus tests.
**Reviewer — Sol high for mutations/security; Luna medium for query/UI DTO consistency.**

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Implement administrator library roots, scans, paginated folder/list/grid data, breadcrumbs, filename search, filtering/sorting and opaque folder/media IDs. Hide `.briani` internal staging/trash from ordinary browsing. Scan only within authorized configured roots.
2. Add restart-safe background scanning with bounded concurrency and file change detection. Serialize expensive FFprobe/thumbnail work; skip unchanged media, tolerate corrupt/missing/locked files and expose per-item errors rather than aborting all libraries. No synchronous full-library scan in a user HTTP request.
3. Inspect video metadata without decoding whole files. Generate bounded thumbnails and image metadata; preserve EXIF orientation. Enforce pixel/output/time/cache limits and avoid SVG/executable handling. Define unsupported formats honestly. Do not send videos through mpv merely to display photos.
4. Implement authenticated image/thumbnail routes and completed-media session delivery with HTTP Range semantics from the common contract. The general static-file feature must never serve staging/incomplete torrents. Reuse safe open-file handles and scoped target validation.
5. Persist progress/resume/watched state by user/media and serve Continue watching. Large filenames, Unicode, >4 GiB files and a 10,000-entry library should not require unbounded client or server lists.
6. Add authorized rename, same-library move, trash and confirmed permanent removal. Reject invalid destinations/collisions/active reader conflicts and protect seeding references. Preserve identity/progress when a supported in-app move occurs. Cross-library move, automatic series renaming and organization by scraped metadata are out of scope.
7. Implement the hard-link/virtual-entry representation seam needed by M05 without assuming an incomplete file has been imported. Startup reconciliation repairs interrupted database/filesystem operations through durable job records.
8. Exercise an offline existing library while Prowlarr and qBittorrent are unavailable. Existing photos/completed media should remain browsable/playable; dependency downtime must not disable the whole application.

## Acceptance and execution

Required scenarios: **T07 for completed media, T15/T16/T18/T19/T24, initial T12/T32 storage cases.** Definitions are in specification 09; they are not optional examples.

Run unit, contract and a new `test --suite media` with real temporary files/SQLite; run integration with upstream dependencies stopped and `client --task test` for any shared DTO fixtures.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Library/media APIs, scanner/probe/thumbnail workers, completed-media HTTP delivery, image handling, progress storage, safe file operations and deterministic filesystem tests.

Write `docs/evidence/M03/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

Do not introduce transcoding, remuxing, HLS, metadata catalogs or movie artwork scraping. A completed-file endpoint is not evidence that progressive playback works.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
