# M06 initial independent corruption/security review

Date: 2026-10-12. Reviewer scope: read-only production reader, availability publication, ticket/session lifecycle and download-reader fencing. Only this review artifact was written. The parent was implementing the reviewed paths concurrently; locations below identify the initial inspected implementation and should be reconciled against the final diff.

Inputs inspected: root AGENTS.md, plan/00_START_HERE.md, plan/agents/EXECUTION_PROTOCOL.md, M06 milestone, specification 05 in full, specification 07, relevant generation/session sections of specification 03, M00 report/checkpoint/lifecycle evidence, and the preserved pinned source paths for pieceStates/download-queue masking. Production paths inspected include ProgressiveReader, TorrentAvailability, ProgressivePlayback, CompletedPlayback, MediaReaders, PermissionService, MediaAccess, DownloadCommands, DownloadWorker and the qBittorrent adapter.

This is a static review with explicit reproducible schedules, not an executed test report. No suite was run because the parent and oracle workers own acceptance execution. Missing sidecars and pending real-engine proof were explicitly excluded as review findings.

## Findings

### R1 — P1: an old bitmap can be published under a new engine epoch

Location: `server/src/Briani.Api/Modules/Playback/TorrentAvailability.cs:57` through line 60; `ProgressiveReader.cs:51` through line 61.

Refresh captures `connection` after VersionAsync, obtains pieces, and checks the epoch at line 57. It then awaits the database reread and pending-operation query. Publication calls `Generation(job,e)`, which reads the live `engine.ConnectionGeneration`, instead of the captured epoch. A concurrent engine request can encounter 401/403 and increment the epoch during those awaits. The old response's bitmap is then labeled with the new epoch. The reader accepts bitmap generation equality and cannot distinguish this mismatch. Additionally, an already-published old snapshot remains usable by the reader between an engine epoch increment and subsequent availability publication, since Entry.Current does not validate its captured epoch.

Reproduction schedule: pause refresh after PiecesAsync and the first connection comparison; issue another adapter request that triggers authentication renewal/ConnectionGeneration increment; resume the database reads/publication. Inspect the published snapshot generation versus the epoch under which PiecesAsync returned. In the second schedule, increment engine epoch immediately after a healthy snapshot is published and attempt another read before the next refresh/watcher tick.

Minimal fix: construct publication generation from the captured epoch; revalidate at publication and make source Current/reader validation reject a snapshot whose captured engine epoch no longer matches the adapter. A reconnect must fence existing readers before they use another stale chunk. Add a deterministic publication-race and immediate stale-epoch regression.

### R2 — P2: selection cancels active playback before checking the conflict

Location: `server/src/Briani.Api/Modules/Downloads/DownloadCommands.cs:89` through line 97.

The non-preserving selection branch calls FenceAsync at line 92. FenceAsync immediately cancels session/media reader leases. Only afterward does line 97 test active readers and Force. A rejected selection therefore interrupts active playback. If cancellation disposes the leases before line 97, the same request can instead pass the check and proceed without the intended active-reader conflict.

Reproduction: start an active progressive or imported-media reader, submit a non-preserving selection with Force=false, and observe the lease cancellation before the 409 check. Hold reader disposal to observe rejected-but-canceled behavior; permit prompt disposal to expose the race that lets the operation proceed.

Minimal fix: check all relevant active reader IDs before any FenceAsync/cancellation side effect or selection changes. Only an authorized force action may cancel them. Regression should assert a rejected selection leaves the existing lease live and no mutation persisted.

### R3 — P2: availability entries permanently consume admission capacity

Location: `server/src/Briani.Api/Modules/Playback/TorrentAvailability.cs:25` through line 27.

Disposal reduces Users and publishes an unhealthy snapshot, but never removes an entry from `active`. Subscribe refuses new IDs once active.Count reaches 512. Thus this limit counts every distinct job ever played during the process lifetime, rather than relevant subscriptions. After old jobs retire, a valid new job can remain permanently unplayable with 429 even when there are no active readers.

Reproduction: subscribe/dispose 512 distinct job IDs sequentially, then subscribe a 513th. No active subscriptions are required at the failure point.

Minimal fix: evict inactive entries safely or bound an inactive cache separately. Preserve invalidation identity across eviction so recreating an entry cannot resurrect an old fenced ticket. Cover retired-job churn and old-ticket generation reuse.

### R4 — P2: completed-media creation bypasses the shared session bound

Location: `server/src/Briani.Api/Modules/Playback/CompletedPlayback.cs:24` through line 30; compare `ProgressivePlayback.cs:59`.

Progressive creation enforces 64 live sessions per user and 512 globally under WriteGate. Completed-media creation has no corresponding admission check and adds a new PlaybackSession on every non-idempotent request. A client can therefore exceed those limits through ordinary completed media, accumulate unbounded live session rows/tickets, and block subsequent progressive creation through the shared counts.

Reproduction: create 65 completed-media playback sessions for one authorized user without Idempotency-Key. The 65th is admitted while equivalent progressive creation is rejected.

Minimal fix: apply the same bounded admission policy to both creation paths under their existing WriteGate. Centralize the check if appropriate, and verify mixed completed/progressive requests count against the same limits.

### R5 — P2: the 60-second pre-header deadline excludes availability refresh

Location: `server/src/Briani.Api/Modules/Playback/ProgressivePlayback.cs:106` through line 108; `TorrentAvailability.cs:39` through line 56.

StreamAsync awaits RefreshAsync with only the lease cancellation token. FirstByteTimeout is created inside the subsequent reader call. Refresh can wait for a queued Fetch semaphore and performs sequential upstream requests (three for VersionAsync, then torrents/files/pieces), each with its own 20-second adapter deadline. A slow but responding engine can therefore consume more than the allowed 60-second pre-header interval before the data timeout even begins.

Reproduction: use a stale/no cached snapshot and an engine whose six refresh responses each take 11 seconds, or hold an existing Fetch long enough; request a missing first byte. The request has still not reached the first-byte timer at 60 seconds.

Minimal fix: one absolute linked pre-header deadline must cover refresh acquisition, refresh calls and the initial data read. Expiration returns the documented 503 with Retry-After and releases the reader lease. Test refresh contention as well as missing-piece waits.

## Reviewed behavior without an additional finding

The immutable layout slicing uses checked offsets and bounds reads to one intersecting piece and the logical file length. Exact disk reads fail closed on short reads; the stream copies bounded pooled buffers and aborts after-header failures. Single/open/suffix ranges use the final entity length; multirange fallback is a full 200. HEAD does not wait for payload. Reader leases enforce four requests per session and sixteen globally. The permission/session watcher uses fresh scoped state and cancellation during waits and slow writes. Activation, idle and absolute deadlines preserve later-range reuse after activation.

The inspected lock order does not show a WriteGate/job-lock deadlock: refresh occurs outside the playback WriteGate, worker/command paths acquire the job lock before WriteGate, and availability's Fetch path does not acquire WriteGate. No missing native read bridge was inferred: the preserved pinned qBittorrent pieceStates source masks downloading-queue pieces, and M00 records the stock validation proof. M06 must still execute its own production real-engine and lifecycle regressions.

## Resolution tracking

All five findings were sent to the parent during the review. This file preserves the initial findings; final fixes, test commands, exit codes and residual limitations belong in the parent M06 handoff. No fix or test result is claimed here.

## Static fix recheck

The parent requested a focused recheck after implementing the five fixes. No suite was run, and the unfinished sidecar subsystem remained outside scope.

- **R2 resolved in the inspected source:** DownloadCommands checks active reader IDs at line 75 before selection mutations and FenceAsync. A rejected non-forced selection reaches no cancellation side effect.
- **R3 resolved in the inspected source:** Subscribe evicts an inactive entry when its cache reaches 512 entries. Each Entry has a random Incarnation included in generation strings, so a recreated entry cannot recreate the generation of an old ticket.
- **R4 resolved in the inspected source:** CompletedPlayback.CreateAsync now checks the same 64/user and 512/global session counts under WriteGate before adding a session.
- **R5 resolved in the inspected source:** StreamAsync creates its absolute first-byte deadline before target/session database resolution, links it through gate acquisition, refresh and the first read, and maps pre-header deadline cancellation to 503/Retry-After. The reader lease retains the original request token and the deadline is disabled before body streaming.
- **R1 partially resolved; residual publication race reported:** generation publication is now stamped with the captured engine epoch, and refresh rechecks the epoch after database awaits. Entry.Current uses Compare-And-Swap invalidation, avoiding overwriting a newer snapshot with a stale invalidation. However, at `TorrentAvailability.cs:63`, refresh updates `e.Connection` before publishing its new snapshot. If execution pauses between those operations after epoch G0 changes to G1, Source still contains the healthy G0 snapshot while both `e.Connection` and the engine report G1. Entry.Current at line 23 compares these independently mutable epoch values, sees equality, and returns the old healthy G0 snapshot. An old-generation reader can pass both snapshot checks during that interval. The epoch must be attached to the immutable snapshot and compared from that snapshot, or snapshot and epoch must be published atomically. This is a remaining R1 schedule, not a new unrelated finding.

The four resolved findings are static resolution assessments only. Parent acceptance evidence must establish executed regressions and production behavior.

## Immutable epoch and subtitle recheck

The subsequent parent fix adds immutable `AvailabilitySnapshot.EngineGeneration`, stamps it with the captured epoch on publication, and compares that snapshot property with the live engine epoch in Entry.Current. **R1 is now resolved in the inspected source**, including the residual Connection-before-Publish schedule above: an old G0 snapshot remains identifiable as G0 even after Entry.Connection changes to G1. The CAS replacement still avoids overwriting a concurrently published newer snapshot. This closes all five initial findings statically; executed regressions remain the parent's responsibility.

The new SubtitleDelivery path and CompletedPlayback/ProgressivePlayback integration received a focused static security review. No additional concrete finding was identified. The capability uses the existing HMAC-SHA256 SecretStore and binds the parent session ID/ticket hash/target generation to one sidecar ID, library, server-derived path, inode identity, byte length and modification time. The URL filename must match the resolved candidate; caller-controlled filesystem paths are not accepted. Resolution rechecks the creating user, original auth session, current read permission, ticket issue/revocation/expiry, parent target identity and generation. Managed subtitles require selection and completion, and pending download lifecycle operations prevent serving them. Imported targets also pass MediaAccess.Open's completion/pending-recheck guards.

Descriptors are opened through the contained storage helper and validated against the bound identity, size and modification time. Delivery reads the exact bounded file, validates strict UTF-8/no NUL, checks descriptor identity again before headers, and aborts after-header failures. Candidate sets are limited to sixteen, sidecar files to 4 MiB, directory enumeration to the containment helper's existing 10,001-entry bound, and requests share the four/session and sixteen/global lease limits. The one-second watcher re-resolves authorization and the same HMAC-bound candidate, so revocation, changed files and lifecycle fencing cancel active responses.

At this review point the parent explicitly identified SaveChanges-failure lease cleanup and periodic subtitle activity persistence as edits still in progress. Those unfinished changes were not counted as new findings or claimed fixed; the parent should preserve their final regression evidence. No heavy test or suite was executed during this recheck.

## Pending-operation and retry policy recheck

The narrowed pending predicate now excludes pause, resume, settings and reannounce from byte-layout fencing. Their unchanged layouts and healthy stopped/download states remain usable by progressive readers. Playback hint queries use the same unsafe kind list. The corrected outer DownloadCommands branch includes retry, so retry now advances job generation, clears completion flags and calls FenceAsync before enqueueing the worker effect. These two corrections are consistent in the inspected source; no test execution is claimed.

### R6 — P2: compatible shared selection still invalidates active URLs

Location: `server/src/Briani.Api/Modules/Playback/TorrentAvailability.cs:75`, `ProgressivePlayback.cs:26`, `PlaybackEvents.cs:59`; compare `DownloadCommands.cs:70` and line 91, and `DownloadWorker.cs:57`.

PendingAsync treats every download-select operation as unsafe. However, compatible shared selection sets PreserveTransfer=true, permits active readers, retains the generation, skips FenceAsync, and makes the worker skip engine selection changes. Its pending operation nevertheless causes the reader watcher to throw from RequireAsync or causes availability refresh to increment Invalidations. Existing playback URLs are then permanently fenced by an operation whose explicit implementation preserves the transfer.

Reproduction: user A streams an already-selected file. User B attaches a compatible selection of that file while another request is selecting it. Keep the operation queued for more than a poll/watch interval. Refresh sees the pending download-select and publishes an invalid generation, or the watcher sees it and cancels A's lease, despite no engine mutation and no persisted job-generation change. Fast worker completion can hide the failure but does not eliminate it.

Minimal fix: preserve an explicit trusted operation discriminator indicating whether it invalidates playback, or account for the stored PreserveTransfer value when identifying unsafe select operations. Align progressive/subtitle pending checks, completed-media MediaAccess checks and event hints. Unsafe select/recheck/retry/remove operations must retain their existing fences. Add a compatible shared-selection regression with the worker deliberately held queued and an existing reader kept active.

This new finding was sent to the parent. The five original findings remain statically resolved; R6 requires separate disposition.

## R6 and subtitle cleanup resolution

**R6 is resolved in the inspected source.** Operation now stores a trusted InvalidatesPlayback boolean. Enqueue sets it for non-preserving selection, retry, recheck and remove, while compatible PreserveTransfer selection leaves it false. TorrentAvailability.PendingAsync, PlaybackEvents and completed-media MediaAccess now use this same discriminator. No client request supplies the flag, and OperationView does not expose it. The OperationPlaybackFence migration defaults the field to false and conservatively marks pre-existing pending/running unsafe command kinds true, preserving upgrade safety rather than trusting old unclassified work.

The earlier subtitle implementation work is also now resolved statically: the inner SaveChanges failure handler disposes an acquired reader lease and the outer handler disposes the descriptor; the watcher persists LastActivityAt at fifteen-second intervals while retaining its one-second permission, expiry and capability checks. No additional concrete flaw was identified in this focused recheck.

All six recorded findings are now statically closed. No suite, Docker image or real-engine outcome is certified by this reviewer; regression execution and the API-driven pause/resume proof belong to the parent/assigned test workers.
