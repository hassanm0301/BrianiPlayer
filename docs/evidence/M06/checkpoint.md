# M06 checkpoint — final local evidence

This checkpoint supersedes the earlier in-progress text. The detailed final record is `docs/evidence/M06/report.md`; the actual v1/v2/hybrid run is `prototypes/playback/production/artifacts/layout-83f5dbaa0efc4c2f90a0b58293fc0d89/result.json`; the production player run is `prototypes/playback/production/artifacts/4265575d595f4591ae2d1fa24b06c7ab/result.json`.

## Current state

- Local M06 server implementation and its recorded Linux verification are complete. Whole-application implementation remains in progress. Parent owns `plan/evidence/status.json` and decides milestone state.
- mpv decoded generated faststart MP4 and MKV while incomplete, then recorded a stable cache pause and same-player resume. VLC decoded the incomplete MP4. Its incomplete MKV attempt timed out; a separate completed-file comparison on the same URL decoded. Tail-metadata MP4 waited until completion.
- Final actual qBittorrent matrix passed v1, v2 and hybrid layout mapping, exact-byte ranges, concurrent readers, missing-gap zero-byte wait, sparse storage checks, unchanged priorities, and v1 restart/recheck ticket invalidation and fresh-ticket recovery.
- Original M00 engine regression `ad61572024e14eddad15b4b384a5d64f` passed, including five media cases, three multifile modes and metadata-only behavior. M06 unit/streaming/download plus relevant media, identity, discovery, contract and integration suites are recorded with exit 0 in `artifacts/dev/`.
- `review-final.md` is a separate source review: six initial findings statically resolved, no additional P0–P2 defect identified. Reviewer did not run tests.

## Limits and resume

No Raspberry Pi 5, ARM64 runtime, physical display/audio, Android TV, Windows or macOS check was performed. No Pi performance, memory or I/O figures are claimed. VLC MKV incomplete playback is a failure observation, not a pass. Full T15/T19/T26/T32 acceptance should not be inferred from these artifacts; see the explicit mapping in `report.md`. Failed earlier harness attempts remain preserved; the final passing run is separately identified. Exact run-label cleanup was confirmed for the final layout matrix.

Use `docs/evidence/M06/handoff.md` for the next-milestone summary. Do not edit contracts, production code or status from this evidence-only checkpoint assignment.
