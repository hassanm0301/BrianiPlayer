# Bounded local optimization measurement

Read-only production-source investigation. The microbenchmark wrote only owned temporary synthetic fixtures and this evidence directory; it did not contact Docker or an engine. A separate authorized single reconnect experiment subsequently exercised an owned isolated qBittorrent swarm as recorded below. No production library, Pi, physical Android device, or decoding was contacted.

Command actually run from the repository root:

```sh
python3 /tmp/briani-polish-performance/microbench.py --output /tmp/briani-polish-performance/microbench.json
```

Exit code **0**. Script and result were copied here as `microbench.py` and `microbench.json`. To repeat the bounded synthetic measurement with the retained script:

```sh
python3 docs/evidence/M10/polish/performance/microbench.py --output /tmp/briani-polish-performance/repeat.json
```

The benchmark uses Python 3.14.8 / SQLite 3.54.0 on local x86_64 Linux. It does not execute the application endpoint, EF-generated SQL, or native ContainedDirectory operations. It supplies a measurement candidate for two small changes, not an API latency or Pi performance claim.

| Synthetic scenario | Before median / p95 | After median / p95 | Verified structural difference |
|---|---|---|---|
| 10,000 catalog rows, 200 warm calls | 0.543 / 0.684 ms | 0.413 / 0.418 ms | Aggregate SQL statements 2 to 1; exact count/sum unchanged; empty catalog gives 0/0 |
| 1,000 tiny cache files, 30 warm calls, ample headroom | 0.810 / 0.815 ms | 0.787 / 0.792 ms | Entries sorted 1,000 to 0; all 1,000 physical entries still inspected |

Timings are one local run, ordered before/after, with five warmups. Small thumbnail timing differences can be noise; the eliminated sort is the meaningful structural result. The synthetic cache includes only regular tiny files. The parent owns actual EF/endpoint verification, eviction regressions and source changes.

Smallest source candidates:

- `LibraryQueries.cs:62–64`: one combined aggregate query with explicit empty-result handling. Preserve the catalog tuple and authenticated cursor invalidation; do not substitute only Library.Version because existing mutations are not proven to advance it uniformly.
- `ScanWorker.cs:311–317`: enter the sorted eviction loop only when `used + data.Length > cacheLimit`. Keep physical enumeration and inspection intact. Database thumbnail rows alone cannot account for orphan files or files written before registration, and cannot safely replace disk usage accounting.

## Single isolated reconnect reproduction, executed

```sh
python3 prototypes/security/resource_faults/run_qbittorrent_network_loss.py \
  --recovery unassisted \
  --scratch-parent /tmp/briani-polish-performance/reconnect-scratch \
  --output docs/evidence/M10/polish/performance/reconnect-unassisted.json
```

The existing runner creates two new owned qBittorrent containers on one new internal network, with run-specific labels, private trackerless generated metainfo, and an explicit owned seeder peer. It disconnects/reconnects only the exact owned downloader, uses a 210-second progress deadline, and checks independent source/download/seeder SHA-256. Cleanup validates run/owner/kind labels and removes only owned resources. The runner itself sets DOCKER_CONFIG to the repository `.tools/docker-config`.

Prerequisites: parent coordination before Docker/network operations; available local Docker daemon and CLI; local pinned image matching `lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed` (runner fails rather than pulling); container startup tools required by that image; generated fixture at `prototypes/playback/fixtures/generated/early-play-source/Faststart café [test].mp4`; writable owned scratch/output paths. Read-only preflight found that fixture (15,787,543 bytes) and `.tools/docker-config`. A normal-sandbox Docker image inspection exited 1 because socket access was denied; the exact experiment above then ran with approved escalation after parent authorization. Its image-ID preflight matched the pinned image and recorded qBittorrent v5.2.4. No image pull was performed.

**Actual command exit: 0; experiment result: passed.** Run `73827fafd5cf45df985443eae48b0320`, UTC 2026-10-14 13:17:02–13:18:46. This was one run, with no retry or engine/source changes. The 3.762-second isolated disconnect was followed by payload progress after 5.065 seconds, within the 210-second deadline. All 61 pieces completed. The downloaded file and retained seeder both independently matched all 15,787,543 source bytes with SHA-256 `40f1485f12f0d7da01e433ac15d21ec84bd66911c62f1e8648fad6a960578907`. Volatile `downloaded` accounting was lower than final file length; completion acceptance used pieces, amount-left, exact length and independent payload hash rather than that counter.

"Unassisted" means **without a daemon restart** in this runner: it explicitly reconnects the owned container, re-adds its owned seeder peer, starts the existing torrent and clears/raises fixture transfer limits. This result does not prove recovery without those fixture controls or explain previous stalls.

`reconnect-unassisted.json` records both removed full container IDs, the removed private network ID, and an empty cleanup error list. A post-run filesystem check confirmed the run's marker-owned scratch directory no longer exists. A separate mid-run status-inspection request hit the automatic permission-review deadline and produced no container result; it did not affect the authorized experiment or its cleanup.

Prior evidence: `qbittorrent-network-loss-210s-failure.json` stalled with zero connected seeds through 210.38 seconds; `qbittorrent-network-loss-unassisted-success.json` subsequently resumed without a code change; `qbittorrent-network-loss-controlled-restart-v2.json` passed explicit restart recovery. This new passing run cannot establish reconnect reliability or resolve the cause of those earlier failures. The existing reconnect verification blocker remains; no production restart behavior was changed.
