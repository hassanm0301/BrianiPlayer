# 05 — Sequential progressive playback: implementation contract

## Non-negotiable rules

Playback before torrent completion is mandatory for the verified baseline media corpus. Only sequential downloading is supported. No seek-triggered priorities, deadlines, independent torrent engine, transcoding, remuxing or HLS is introduced.

The player consumes an HTTP media URL. mpv does not understand or schedule the torrent. A conventional static-file response over an incomplete file is unsafe: allocated length can include holes or unavailable data. The gateway must not return missing bytes as zeros or signal a successful end-of-file before the advertised response is complete.

This is the highest-risk component and must pass M00 before extensive client work. Source references S02, S03, S07–S10 explain upstream capabilities and HTTP/container constraints; the design below is Briani-specific.

## What “sequential playback only” means

The normal path reads from the start after startup metadata is ready. Backward/forward seeks into downloaded ranges may work. A range request into missing data waits for the engine's existing sequence and peer availability. It never changes download scheduling. The UI warns that a far-forward seek can wait a long time and offers Cancel/Return to available position.

Do not forbid every nonzero HTTP range: even initial container probing may request the file end. Fixed first/last assistance is allowed. It does not ensure an MP4's entire tail `moov` atom or every MKV index is immediately available. Affected media can show `Waiting for media metadata` until the required bytes arrive; a documented format-specific wait is different from claiming all videos start instantly.

## Core interfaces

```text
TorrentLayout {
  generation, engineTorrentId, format, pieceLength, pieceCount,
  files: [{ stableFileId, upstreamIndex, metadataIndex, path, length,
            torrentOffset, firstPiece, lastPiece, padding, symlink }]
}
AvailabilitySnapshot {
  generation, observedAt, engineState, readablePieceBitmap,
  selectedFilesComplete, dependencyHealthy
}
ProgressiveRead(target, fileOffset, requestedCount, generation, cancellation)
  -> verified/available bytes, WaitForData, GenerationChanged, or typed failure
```

The gateway operates on an **immutable layout generation** and a contained open file descriptor. It never derives file identity from a user path or trusts `progress * fileLength` as a byte availability boundary.

### File-to-piece mapping

For a v1 layout with file start `F`, piece length `P`, and file-relative byte `x`, global piece index is `floor((F+x)/P)`. An inclusive request `[a,b]` intersects pieces from `floor((F+a)/P)` through `floor((F+b)/P)`.

`F` is the offset in the entire torrent, including preceding files and padding—not an offset after filtering media. Reject overflow and out-of-bounds maps. A selected file can start or end in a piece shared with an ignored file. qBittorrent may store boundary material in auxiliary part files; the gateway only serves the selected file's bytes and must not expose those auxiliary paths.

Build authoritative layouts from validated metainfo/export plus engine file IDs/ranges, checking every mapped size and boundary. Do not rely on a JSON list order after padding files have been hidden. For v2, respect piece-aligned per-file address space and gaps; hybrid mappings must match the engine's actual interpretation. BEP52 differs from a naive sum of visible file lengths. M00 must prove v1 nonaligned multifile, hybrid padding and v2 mapping with fixtures. Unknown/inconsistent layouts fail closed with `layout_unverified`; they do not use a guessed offset.

### Piece status versus readable storage

qBittorrent's piece-state API is necessary evidence, not by itself a documented cross-process durability promise. Upstream libtorrent distinguishes some completion notifications from disk flush. Pin the exact engine/storage configuration and inspect how its bitfield is published; verify cross-process reads against known original data under stress and restart/recheck conditions.

Before any piece is allowed to feed a response: require a current compatible generation, a complete engine bit, a non-maintenance engine state, a contained target descriptor with matching identity, and successful exact reads of the authorized subrange. Never infer readiness from file size or add a fixed sleep as a correctness substitute. Integration tests compare delivered bytes to an independent fixture oracle. If the pinned engine cannot establish safe readable ordering, activate the narrow same-engine read bridge contingency D12 rather than ignoring the race.

“Readable” means available correctly to another process on the same host; it does not mean immune to a future power loss. Recovery invalidates cached availability and lets the torrent engine recheck uncertain data.

## Reader algorithm

1. Validate playback ticket, current user/grant, target generation and request limits.
2. Resolve the logical file to a contained descriptor; retain it for this HTTP response. No open-by-unchecked-path step.
3. Parse the requested range against the **final known file length** from metadata.
4. Find the next intersecting piece; obtain a fresh-enough shared snapshot.
5. If that piece is not readable, await a shared availability notification with cancellation and timeout. Do not hold a database transaction or block a thread.
6. If readable, copy only bytes within both the requested range and readable piece extent, using bounded pooled buffers. Handle short reads as unavailable/error, never pad with zeros.
7. Recheck generation/dependency health on each chunk/piece boundary. Backpressure follows the HTTP client. Repeat until the exact declared response length is sent.
8. On client disconnect, free resources promptly. On invalidation or a terminal error after response headers, abort the response/connection; do not append JSON to video bytes or pretend it completed.

One in-memory availability loop per active torrent, not one poller per HTTP connection. Poll every 500 ms while playing, every 2 seconds while downloading without playback, and stop piece polling when unused. General torrent status may be slower. Snapshots expire after 2 seconds for serving new progressive pieces. A stale dependency is not “probably complete.” Use compact bitsets; do not persist the bitmap on each tick.

A first implementation may scan a bounded interval bitmap rather than a complex interval tree. Requests awaiting the same piece share a notification. No whole-video buffering or unbounded per-player cache.

## HTTP semantics

| Request/condition | Response contract |
|---|---|
| `HEAD` with valid target metadata | 200, final `Content-Length`, content type and `Accept-Ranges: bytes`; no body and no wait for payload. |
| `GET` without Range | 200 with final length; stream sequentially, waiting when needed. |
| Single closed range `bytes=a-b` | 206, exact `Content-Range` and `Content-Length=b-a+1`, cap b to N-1 where valid. |
| Open-ended/suffix range | Correctly resolve against final N; support typical player probes. |
| Start beyond final length / unsatisfiable range | 416 with `Content-Range: bytes */N`. Missing downloaded bytes are **not** 416. |
| Invalid/overflowing range | Bounded parse; reject malformed requests consistently without allocating from attacker-supplied size. |
| Multiple ranges | v1 ignores the Range header and serves a full 200 response; document/test this valid fallback. Do not fabricate a multipart response or quietly serve only the first part as if all were honored. |
| Missing first requested data | Wait up to 60 seconds before headers, then 503 with Retry-After and a non-media error. Internal client can retry. |
| Gap after headers | Await data, up to 120 seconds without progress; on timeout abort so a truncated body is detected. Internal playback retries/reopens from actual position; arbitrary external players may stop. |
| Client cancel | Cancel wait/read promptly and release reader lease. |
| qBittorrent recheck/restart/move/selection change | Invalidate generation, terminate affected reads, advertise recoverable state; never continue from a stale map. |
| Completed immutable file | Ordinary bounded range-serving path after identity/completion validation; same authorization. |

Do not enable response compression on binary media. Avoid buffering a whole response in middleware or a reverse proxy. Do not enforce a web-style minimum response data rate on endpoints deliberately waiting for a torrent piece; keep finite idle/resource limits instead. Configure optional proxies for long reads and disable inappropriate buffering/caching.

For incomplete objects, use `Cache-Control: private, no-store`, no misleading strong ETag, and no `If-Range` assumptions based on unstable modification times. The final logical object length stays fixed while downloaded availability changes. Completed-file validators must match real object identity/generation. Include tests for Range combined with HEAD, cancellation and conditionals; never label a partial body a successful full entity.

## Startup and buffering policy

The server reports `metadata_pending`, `buffering`, `ready`, `complete`, `unavailable`, or `error`, plus downloaded bytes, verified contiguous prefix, total size and generation. Do not convert a byte fraction into a precise playable timestamp for variable-bitrate video. Use approximate labels if time is estimated.

Default eligibility requires metadata known, a verified 16 MiB contiguous prefix (or the whole file if smaller), and a valid layout. That is a policy threshold, **not proof the decoder will open**. The player may need more bytes or tail metadata. Let a bounded client open/probe attempt distinguish metadata wait from unsupported codecs. Avoid running repeated FFprobe scans against growing files on the Pi.

Embedded mpv uses a modest cache target, bounded by client profile. First defaults: desktop 64 MiB, Android/TV 32 MiB, background fill according to engine support. Tune only with fixtures. Player cache, HTTP read buffers and torrent availability are different quantities.

If download speed falls below playback demand, buffering is expected. Show download speed and an understandable status, not a false uptime promise. Downloads continue if the player closes.

## Playback sessions and secure URLs

Control API uses normal authentication. Media URLs use random, unguessable, revocable **file-scoped playback tickets**, not access or refresh tokens. Both embedded and external playback use the same ticket mechanism for compatibility.

A ticket can be activated within ten minutes. After activation it remains valid while active, has a 30-minute idle expiration and a 24-hour hard lifetime. This permits later range requests during a long movie without the common mistake of expiring every URL after a few minutes. Validate current grants and revocation; refresh/check every bounded interval during open responses. Raw tickets are stored only by the requesting client; database stores a hash. Suppress tokens from all logs.

Limit four concurrent range requests per session and 16 globally in the Pi profile. A session targets one media file and generation. No wildcard library access. External players may issue multiple requests; ticket “one use only” is unsuitable. Copy URL clearly warns that anyone holding it can play that specific media until expiry/revocation.

## External-player compatibility

Briani launches a stream URL, not a server filesystem path. The external program must support reachable HTTP(S) media. Its buffering timeout, retry strategy, sidecar handling and progress callbacks are outside Briani's control. Test mpv and VLC on Linux plus at least one Android/TV external player; document observed behavior, not “all players supported.”

Embedded playback retries after a data-wait interruption with bounded backoff and the last actual playback position; do not start from zero without user confirmation. External failures show a return-to-Briani retry action; no attempt to inject custom controls into unrelated applications.

## Mandatory acceptance corpus

Generated single-file faststart MP4; MP4 with tail metadata; MKV with multiple audio/subtitle tracks; v1 multi-file torrent with non-piece-aligned boundaries and ignored neighbors; hybrid padding; v2 files; file names with spaces/Unicode; large offsets >4 GiB; missing middle pieces; sparse/preallocated storage; qBittorrent restarts, rechecks and short disk reads.

Baseline early-play guarantee is measured for normal unencrypted faststart MP4 and MKV in this corpus. Tail-metadata MP4 must wait honestly or start if its required metadata is present; do not silently transcode/remux it to pass. Record container-specific waits. Torrent-format mapping failures are engineering defects to fix, not a blanket excuse to remove progressive playback.

Every emitted test byte is checked against a known original. Zero corruption, bounded memory, cancellation and unchanged piece priorities are hard gates. Playback on an emulator alone does not certify Android TV hardware decoding, HDR or passthrough.


## Native read resource bound

Reject metainfo whose piece length exceeds 64 MiB in the reference profile before payload admission; do not allow a user-supplied piece length to drive an unbounded native allocation. Report the unsupported resource limit explicitly. For D12, allow one in-flight full native piece read per server by default and at most one completed shared piece buffer retained globally, with cancellation and generation invalidation. Stream/slice that buffer using the normal small HTTP copy buffers; deduplicate concurrent requests for that same piece instead of rereading it for every 256 KiB chunk. Normal direct-file mode does not need a full-piece cache. Benchmark the bridge separately if used, and retain the global byte budget when tuning concurrency.
