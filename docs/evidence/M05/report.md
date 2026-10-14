# M05 — sequential transfers, selection, and seeding-safe import

## Current status

The M05 implementation and local validation are complete for this Linux amd64 slice. The corrected integrated `python tools/dev.py test --suite integration` rerun passed. An earlier invocation exited 1 because the runner passed a generated-fixture root that did not contain the pinned-engine smoke torrent; that failed attempt is preserved at `/tmp/briani-m05-integration-final.log` and was not counted as acceptance. The corrected run used the checked-in deterministic generated fixtures and passed every integration step.

## Delivered behavior

The server now owns durable download requests, engine operations, source resolution, metadata and selection, quota/free-space reservations, task state, imports and recovery. It maps v1, v2 and hybrid torrent file layouts (including explicit padding and zero-length files), retains the original metainfo and reconciles engine identity changes without adopting unrelated torrents. Metadata acquisition stops before payload transfer; selected files are started only after admission and selection. Sequential mode and fixed first/last piece assistance are applied and observed independently of playback progress. The API includes bounded progress and history, selection, queue and rate/seeding controls, remove-task versus delete-data operations, and authenticated server-side import. Completed files are hard-linked into the library when possible while the engine's seeding payload remains in place; unsupported hard-link cases use the defined virtual-entry behavior. Durable operations reconcile after restarts, and active readers fence destructive actions.

The adapter targets the pinned LinuxServer qBittorrent image digest recorded in the harness and observed qBittorrent 5.2.4, Web API 2.15.1 and libtorrent 2.0.15.0. All live-engine proof used isolated, label-owned Docker resources on an internal network with no published ports and no external tracker or peer.

## Verification evidence

| Command / check | Exit | Result |
|---|---:|---|
| `dotnet build server/tests/Briani.DownloadTests/DownloadTests.csproj --nologo` | 0 | Clean build, 0 warnings/errors; `/tmp/briani-m05-build-final.log` |
| `python tools/dev.py test --suite downloads` | 0 | 39 non-integration tests passed; `/tmp/briani-m05-downloads-final.log` |
| `python tools/dev.py test --suite unit` | 0 | Unit, reader, secret-scan and fixture/tool checks; `/tmp/briani-m05-unit-final.log` |
| `python tools/dev.py test --suite identity` | 0 | 32 tests passed; `/tmp/briani-m05-identity-regression.log` |
| `python tools/dev.py test --suite media` | 0 | 49 tests passed; `/tmp/briani-m05-media-final.log` |
| `python tools/dev.py test --suite discovery` | 0 | 95 tests passed; `/tmp/briani-m05-discovery-regression.log` |
| `python tools/dev.py test --suite contract` | 0 | Contract and deterministic generated-client checks passed; `/tmp/briani-m05-contract-regression.log` |
| `python tools/dev.py test --suite integration` | 0 | 2 integration tests and all three actual Docker harnesses passed; `/tmp/briani-m05-integration-final2.log`, `artifacts/dev/20261012T143323.751260Z/` |
| Pinned engine smoke (`run_pinned_engine.py`) | 0 | Real qBittorrent API/configuration, stopped metainfo add, metadata-only magnet and controls; `/tmp/briani-m05-qbit-engine-final.json` |
| Trackerless local-peer metadata/layout harness (`run_local_peer_transfer.py`) | 0 | Real isolated v1/v2/hybrid/zero-length metadata mapping and no preselection payload; `/tmp/briani-m05-qbit-local-peer.json` |
| Production API lifecycle Docker proof | 0 | Two API restarts; durable selection/import, JPEG thumbnail, hard-link inode and SHA-256 preserved while qBittorrent remained seeding; `artifacts/dev/20261012T143323.751260Z/api-restart-import.json`, `artifacts/download-lifecycle/9d59b7a3dd6e42e196ff4d7768865fc6/result.json` |
| `docker buildx build --load -t briani-server:dev -f infra/images/server.Dockerfile .` | 0 | Final local image `sha256:1b54c4c49cc72738d49e1b74de71276afbb5490eb78019e88b734aa5e148ee66`; `/tmp/briani-m05-image-build-final.log` |

The lifecycle proof imported a generated 15,787,543-byte media file. The imported path shared the engine payload's device/inode and its SHA-256 matched; the engine still reported `stalledUP` and remained registered. The adapter's synthetic magnet acquired metadata with zero downloaded bytes before selection. Trackerless local-peer observations show hybrid hash identity changing from the v1-only pre-metadata form to the combined v1/v2 identity after metadata; recovery resolves by typed identity rather than duplicating the job.

The harnesses under `prototypes/downloads/engine/` and `prototypes/downloads/lifecycle/` accept `BRIANI_DOWNLOAD_FIXTURE_ROOT` (or `--fixture-root`) and write machine-readable logs with `--log`. The pinned engine runner also accepts `BRIANI_DOWNLOAD_SINGLE_TORRENT` / `--single-torrent`; the API lifecycle runner accepts `--torrent` and `--source`. Missing fixtures fail nonzero with a structured record. No shared runner or CI files were changed in this fixture-plumbing update.

## Review and remaining gates

The independent findings and fixes remain recorded in [review.md](review.md). Review concentrated on quota/reservation races, identity and duplicate-hash ownership, metadata-only behavior, crash recovery, reader fencing, destructive operations and hard-link preservation. The M05 suite filters the two real-engine cases under `Category=EngineIntegration`; ordinary test runs therefore do not silently treat unavailable Docker prerequisites as success. The integrated runner executed both against their isolated harnesses. The initial fixture-root wiring failure was corrected; the final run returned exit 0 with no test skips.

This is local Linux amd64 evidence. Raspberry Pi 5/ARM64 performance and storage behavior, Windows/macOS, Android TV and release validation remain outside this milestone's local proof. No production qBittorrent instance, user indexer account, public swarm, public port or copyrighted test media was used. M06 consumes the stable download/file identities and generations delivered here. Hardware and other client-platform checks remain separate gates.
