# M06 final independent source review

Date: 2026-10-12. Scope: current `Modules/Playback/`, download command/worker lifecycle and query/event integration, shared media completion checks, operation discriminator/migration, and expiry cleanup. This is a separate final source pass following the implementation/fix cycles recorded in `review-initial.md`. Only this document was edited. No suite or Docker/real-engine command was executed by this reviewer.

## Result

No additional concrete P0, P1 or P2 defect was identified in the reviewed M06 source. All six findings in the initial review remain resolved in the inspected implementation. This is source clearance for the reviewed boundaries, not milestone completion or hardware/real-engine certification.

## Reviewed boundaries

- Immutable snapshots carry their captured engine epoch. Entry.Current rejects stale epochs and its conditional replacement does not overwrite a concurrently published newer snapshot. Publication rechecks the engine and persisted layout generation, ownership/save-path/hash binding, engine maintenance state, file mapping/priorities and staging identity. Cache eviction is bounded and new entry incarnations prevent old-ticket generation reuse.
- Progressive reads use checked logical offsets including torrent offsets, restrict each read to a readable piece extent and use bounded 256 KiB copy buffers. Exact descriptor reads reject short data; unavailable sparse/preallocated bytes cannot become ready based on file length. Generation, freshness and dependency health are checked around each read. Cancellation and after-header failures abort instead of returning successful short media entities.
- GET/HEAD range handling uses final logical length. Single, suffix and open ranges are bounded; multiranges use full 200 fallback. HEAD avoids payload waits. The first-byte deadline covers target/session setup, gate/refresh contention and initial reads; it stops before body streaming. Missing first data returns 503 with retry metadata, while body gaps use finite idle waits. Progressive media uses no-store, no strong ETag and no minimum response data rate.
- Tickets remain file/generation scoped, random and hashed at rest. Both creation paths share live-session admission under WriteGate, and expiry/admission/housekeeping agree on first-use, idle and absolute limits. Leases enforce four requests per session and sixteen globally. Fresh scoped watchers recheck users, original auth sessions, read grants, expiry and target identity. Session revoke and unsafe download effects cancel affected leases.
- Active-reader conflicts precede selection mutation/cancellation. Retry advances generation and fences tickets before worker effects. The trusted InvalidatesPlayback flag is computed by the server and consumed consistently by availability, completed-media access and event hints. Pause/resume/settings/reannounce and compatible shared selection preserve valid playback URLs. Unsafe commands retain their fences; old queued unsafe commands are conservatively backfilled by migration.
- Subtitle capabilities use HMAC-SHA256 and bind the parent ticket hash/generation to one sidecar's ID, library, server-derived contained path, inode, length and mtime. Filename matching, selected/completed managed-file checks, pending-operation checks and exact UTF-8 validation fail closed. Delivery is bounded to sixteen candidate sidecars and 4 MiB per file, shares reader limits, disposes descriptor/lease on setup failure and persists activity while its watcher rechecks authorization/capability each second.
- Playback SSE hints are permission filtered and bounded; event admission and write deadlines are finite. The inspected lock ordering retains job-lock-before-WriteGate and does not acquire WriteGate inside availability Fetch, so no new lock-order deadlock was identified.

## Test evidence inspected

The following results were read from both the runner manifest and stdout logs; this reviewer did not rerun them:

| Command recorded by runner | Exit | Recorded result | Artifact |
| --- | ---: | --- | --- |
| `dotnet test server/tests/Briani.StreamingTests/Briani.StreamingTests.csproj --nologo` | 0 | 47 passed, 0 failed, 0 skipped | `artifacts/dev/20261012T165234.946671Z/run.json` and `test-streaming-Briani.StreamingTests.stdout.log` |
| `dotnet test server/tests/Briani.DownloadTests/DownloadTests.csproj --nologo --filter Category!=EngineIntegration` | 0 | 56 passed, 0 failed, 0 skipped | `artifacts/dev/20261012T165202.581789Z/run.json` and `test-downloads-DownloadTests.stdout.log` |

The download sources include focused regressions for queued compatible shared selection with an active ticket, pause/resume generation preservation, retry fencing, initial refresh contention, stale engine epochs, cache incarnation eviction, expiry/admission cleanup and subtitle capability/byte delivery. Passing these mocked/local suites does not establish qBittorrent cross-process ordering or player behavior.

## Acceptance limits

The parent must separately reconcile current production-harness, original M00 regression and full integrated evidence into the final M06 report/status. This review does not certify Docker harness outcomes, first decoded frame before completion, actual buffering/reopen behavior, v2/hybrid/padding mapping against the running engine, restart/recheck/storage races, concurrent-stream resource measurements or VLC behavior. The inspected checkpoint still described those acceptance activities as ongoing and is not a final gate report. No native Pi, Android/TV external player, hardware decode or performance result is claimed here. Those gaps are verification requirements rather than additional source findings.
