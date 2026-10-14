# M04 Prowlarr discovery and protected sources

The implementation provides asynchronous latest/most-seeded/search snapshots, scoped pagination and cached/stale results, Prowlarr provider capabilities and health, partial-failure handling, encrypted source alternatives, strict server-side magnet/metainfo resolution and expiring user-owned torrent uploads. It uses the sole supported Prowlarr gateway and ships no real indexer account or source list. Mutating retries, permission changes, deadlines, DNS/redirect policy and retained resource limits are enforced server-side.

## Executed verification

| Command | Exit | Result/evidence |
|---|---:|---|
| `dotnet test server/tests/Briani.DiscoveryTests/DiscoveryTests.csproj --no-restore` | 0 | 95 passed, no failures/skips; `discovery-final.log` |
| `python tools/dev.py test --suite integration` | 0 | 2 tests; `integration-final.log` |
| `python tools/dev.py test --suite identity` | 0 | 32 tests; `identity-final.log` |
| `python tools/dev.py test --suite media` | 0 | 49 tests; `media-final.log` |
| `python tools/dev.py test --suite unit` | 0 | reader/fixture/tool/security checks; `unit-final.log` |
| `python tools/dev.py test --suite contract` | 0 | contract plus deterministic generated Dart check; `contract-final.log` |
| `python3 prototypes/discovery/run.py` | 0 | pinned real Prowlarr/Torznab fixture; `prowlarr-compatibility.json`, `.log` |
| `docker buildx build --load -t briani-server:dev -f infra/images/server.Dockerfile .` | 0 | `image.log` |
| `python tools/dev.py compose --task smoke` | 0 | `compose.log` |
| `python tools/media_container_probe.py` | 0 | actual offline Docker photo/video scanning and exact bytes; `offline-media.log`, `artifacts/media-container/0e06e785dfd546e7972267cb8fabd327/result.json` |

The pinned Prowlarr digest reported2.6.5.5623/master. A local Torznab fixture produced one recent result and one submitted-search result. A deliberate indexer503 produced HTTP200 with empty search results; actual `/indexerstatus` failure fields make that distinguishable from a genuine zero-result response. The adapter and snapshot worker both consume this status, preserve useful successes and use stale fallback for all-provider outages. The throwaway bridge/container/config were removed with label checks; no ports were published, and the fixture bound only to its owned bridge gateway.

The final 95-test suite covers source parsing and original hashes across v1/v2/hybrid fixtures, valid and tampered Merkle layers, actual single-file paths, path/case/Unicode collisions, unsafe trackers/webseeds, DNS rebinding/private redirects and credential scope, upload limits/cleanup/ownership/expiry, permission changes while DNS is blocked, stale result re-resolution, protected connection settings and health, asynchronous queries, leases, idempotency, scopes/cursors, cache/stale TTLs, coherent nullable counts, provider failure mapping and resource caps. Details appear in `source-profile.md` and `query-limits.md`.

## Review and integration corrections

A separate Sol high review found and verified fixes for upload retention and asynchronous authority checks, parser path collisions and shared-Merkle work amplification, mixed-provider counts, and retained snapshots/idempotency records. Own before/after proof artifacts and findings are in `review.md`. The query worker was corrected after the actual pinned API demonstrated empty-success responses on provider failure. Earlier logs with fewer tests or transient compilation/fixture failures remain separate; this report relies on the final successful run.

The schema now includes discovery snapshots/results and uploads, using the existing durable jobs/operations and encrypted-secret store. Framework migrations applied on real temporary SQLite. API/test locks and CI dispatch include the discovery suite. Existing completed-media operation remains independent of upstream availability.

## Limits and handoff

This establishes the local M04 slice of T17/T21/T28 and relevant T15/T16. No private accounts, public swarm or production data were used. Application URL checks do not isolate the torrent daemon; destination admission, engine controls and daemon egress remain M05/M10 gates. M05 adds metadata-first sequential downloads, quota/reservation ownership, import/seeding preservation and crash reconciliation. Pi/hardware and unavailable desktop runners remain their recorded verification gates. No release is published.
