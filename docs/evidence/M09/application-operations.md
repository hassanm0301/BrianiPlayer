# M09 application operations

This evidence note covers the server application-operations slice in `ApplicationOperations.cs` and its focused API tests. The milestone remains incomplete until the parent integration runs the full M09 gates and records the independent review.

## Implemented behavior

- `GET /api/v1/admin/health` is restricted to a live administrator session. It reports local database readiness, bounded active queue count, state/data volume writability, library storage online observations, and cached Prowlarr/qBittorrent observations. It does not probe upstream services or expose their URLs or credentials.
- `POST /api/v1/admin/maintenance` queues `rescanLibraries`, `pruneThumbnailCache`, or `databaseSnapshot`. It rejects invalid action/library combinations, validates the optional idempotency key, coalesces retries by actor/action/key, rejects a changed request body, caps active maintenance jobs at 100, and retains at most 500 completed/failed idempotency records plus 30 days of recent history.
- The hosted worker claims durable `WorkJob` rows with a two-minute lease, retries failures with bounded exponential delay, and fails after five attempts. `RunOnceAsync` allows deterministic host-driven execution. The host option `BackgroundMediaOperations=false` disables its polling loop.
- `rescanLibraries` adds at most 1,000 enabled/online library scans using the same keyed dedup value as normal library scans, so duplicate active work is skipped. Thumbnail pruning examines at most 500 DB-owned entries under `WriteGate` and deletes only identity-checked files beneath the app thumbnail cache; entries with active readers are skipped.
- `databaseSnapshot` uses SQLite's online backup API into a random temporary name in a fixed application-state `snapshots` directory. The source database plus WAL is capped at 1 GiB, the directory is restricted to 0700, newly created files use 0600, publication uses a contained rename, and the newest five snapshots are retained. A folder with more than 10,000 snapshots fails closed for operator cleanup. This is an application database snapshot, not a full-stack backup.
- Existing `configureEngine` jobs are handled by calling `ITorrentEngine.ConfigureManagedAsync` outside the write gate, so each job applies current administrator settings without holding the database gate during upstream I/O.

## Validation evidence

| Command | Result | Artifact |
|---|---:|---|
| `DOTNET_CLI_HOME=.tools/dotnet-home NUGET_PACKAGES=.tools/nuget dotnet build server/src/Briani.Api/Briani.Api.csproj --no-restore` | Exit 0; 0 warnings, 0 errors | Build output in parent task log |
| `DOTNET_CLI_HOME=/home/hassan/projects/BrianiPlayer/.tools/dotnet-home NUGET_PACKAGES=/home/hassan/projects/BrianiPlayer/.tools/nuget dotnet test server/tests/Briani.OperationsTests/OperationsTests.csproj --no-restore` | Exit 0; 7 passed, 0 failed | VSTest output in parent task log |

The API tests cover live admin/member access to health, missing mounted data-root reporting, absence of raw URLs in health details, invalid maintenance action rejection, idempotent replay, changed-body conflict, and invalid library rejection. Worker checks run the snapshot action and restore/query its SQLite result, assert private file mode, temp cleanup and five-file retention, exercise safe thumbnail pruning against active readers, symlinks and non-cache paths, verify scan deduplication, and verify engine configuration retries after an upstream failure without holding `WriteGate`.

## Limits and review

The online backup call itself is synchronous and has no cancellation overload in the pinned Microsoft.Data.Sqlite API. Its input size is bounded to 1 GiB; the backup runs without holding the global write gate so normal app writes do not wait for a potentially lengthy copy. Temporary files are removed on success and failure. SQLite's backup API provides a transactionally consistent destination while the source remains active. The server source build and focused operations tests passed. Reviewer findings and the integrated M09 gates remain pending.
