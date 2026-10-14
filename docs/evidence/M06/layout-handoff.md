# M06 layout matrix handoff

## Result

The actual isolated production-container layout matrix passed. Run ID: `83f5dbaa0efc4c2f90a0b58293fc0d89`. Full output is preserved at `prototypes/playback/production/artifacts/layout-83f5dbaa0efc4c2f90a0b58293fc0d89/result.json`.

## Commands and environment

| Command | Exit | Evidence |
|---|---:|---|
| `python3 -m py_compile prototypes/playback/production/run_layout_matrix.py` | 0 | Syntax check |
| `python3 prototypes/playback/production/run_layout_matrix.py --preflight-only --artifacts prototypes/playback/production/artifacts` | 0 | `prototypes/playback/production/artifacts/layout-b8370c96933e43c3b8cfa5a598a89f6b/result.json` |
| `python3 prototypes/playback/production/run_layout_matrix.py --timeout 120 --artifacts prototypes/playback/production/artifacts` | 0 | `prototypes/playback/production/artifacts/layout-83f5dbaa0efc4c2f90a0b58293fc0d89/result.json` |

The run used `briani-server:dev`, qBittorrent `lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed`, and the preflight-confirmed Python libtorrent `2.1.2.0`. Fixtures were a generated 120-second faststart H.264 MP4 with deterministic ignored neighbors; no copyrighted media was used.

## Verified behavior

All three actual metainfo modes—v1, v2, and hybrid—completed. Each reached an incomplete but verified contiguous prefix (18,014,813; 17,563,648; and 17,301,504 bytes respectively) while the 21,065,227-byte media file remained incomplete. Each mode passed four range checks against the independent source bytes, including a piece-boundary crossing and concurrent identical readers. The per-mode artifact records byte counts, hashes, native offsets/piece ranges, file mappings and the hidden-neighbor metadata.

Each mode also proved a gap wait returned zero body bytes after the bounded one-second client timeout, and qBittorrent file priorities remained unchanged. Physical stats showed full logical file length with lower allocated block counts for all three incomplete files, directly exercising sparse/preallocated storage. V1 restart terminated the already-open reader at a missing-data gap with zero bytes received there. After restart, the old ticket returned HTTP 404 with `application/problem+json` code `not_found`; the old-ticket media request returned no bytes and advertised no media range. A new session had a changed generation and its exact 32-byte range matched the source. Recheck likewise invalidated the old ticket with HTTP 409 and problem code `generation_changed`, then a fresh session served an exact matching range. Restart and recheck left file priorities unchanged.

The harness accepts the documented 404 `not_found` or 409 `generation_changed` invalidation response only when it is strict problem JSON with the matching HTTP status and no media-range headers. This maintains the old-ticket no-byte gate while respecting the implementation's deliberate concealment of expired or revoked ticket existence. File stat lookup now scopes to the current torrent's validated engine save path and API relative path, so identically named files from earlier layout cases cannot be confused.

## Cleanup and limits

The run used uniquely labeled containers on a Docker internal network without published ports. A post-run exact-label inspection found no container or network for run ID `83f5dbaa0efc4c2f90a0b58293fc0d89`. Earlier failed attempts and their artifacts remain preserved; their exact-run resources were also confirmed removed. No unrelated swarm or production Pi resources were touched.

This is host-side Linux Docker evidence, not Raspberry Pi hardware measurement. The restart race was exercised on v1 only; v1 recheck was exercised in the same run. It does not replace other M06 gates such as the separate player decode proof, broader lifecycle tests, or the independent source review.
