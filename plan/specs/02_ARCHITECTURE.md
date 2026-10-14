# 02 — Architecture and technology decisions

## Fixed stack

| Layer | Selection | Reason for this project |
|---|---|---|
| Server | C# / .NET 10 LTS / ASP.NET Core Minimal APIs | Typed contracts, asynchronous I/O, integrated DI/logging/auth primitives, mature Linux ARM64 runtime. Selection is a workload/maintenance judgment, not a claim of benchmark supremacy. |
| Persistence | EF Core 10 and SQLite | Low deployment complexity, migrations and transaction support; one server process, not a multi-node database. |
| Client | Flutter stable + Dart | Shared desktop/Android code, custom TV focus layouts, one primary UI implementation. |
| Client state/network | Riverpod without unnecessary code generation, go_router, Dio, json_serializable | Explicit feature boundaries, request cancellation and testability; pin compatible stable packages in M01. |
| Video | media_kit + media_kit_video + native video libraries | Embedded libmpv on native targets; one adapter initially, replaceable boundary. |
| Discovery | Prowlarr HTTP API | Avoid implementing and maintaining tracker-specific scrapers. |
| Torrent transfer | qBittorrent-nox using libtorrent 2.x | Separate mature service, full-download operations and sequential mode. Exact compatible image pinned by M00. |
| Inspection | FFprobe and bounded FFmpeg thumbnail commands | Metadata and small previews only; never a video conversion service. |
| Deployment | Docker Engine + Compose plugin | Native ARM64/amd64 images, persistent mounts, reproducible lifecycle. |
| Client/API contract | OpenAPI 3.0.3, generated Dart client | One maintained wire contract; no hand-copied DTO variants. |
| Progress | Authenticated server-sent events + snapshot polling fallback | One-way updates are sufficient. No Redis, Kafka or WebSocket cluster. |

.NET 10 is an LTS release; use a current supported 10.0 patch at implementation time and pin it. Framework support does not establish application throughput. See S01 in `14_SOURCES_AND_LICENSING.md`.

Go was considered for footprint; TypeScript/Fastify for terse integrations; Rust for control; Python for rapid orchestration. None is needed to meet this workload if large transfers use bounded asynchronous I/O. Do not run another language tournament during implementation. Profile actual bottlenecks before considering a rewrite.

## Runtime shape

```text
Flutter clients (desktop / phone / TV)
       | authenticated control API, events, media ranges
       v
Briani Server — one application container, one SQLite owner
   |                  |                     |
   | Prowlarr API     | qBittorrent API      | bounded jobs
   v                  v                     v
Prowlarr container   qBittorrent container  FFprobe / thumbnails
   |                  |
configured indexers   BitTorrent peers
                      |
               mounted /data storage
```

No client receives qBittorrent or Prowlarr administrative credentials. The server coordinates downloading; client phones and TVs never join torrent swarms. Server mpv is unnecessary.

## Repository layout

```text
AGENTS.md
plan/                         # this package, copied intact
server/
  Briani.sln
  src/Briani.Api/              # composition, routes, modules, background workers
    Modules/{Auth,Libraries,Discovery,Downloads,Playback,Settings}/
    Infrastructure/{Persistence,FileSystem,QBit,Prowlarr,Jobs}/
  tests/{Briani.UnitTests,Briani.IntegrationTests,Briani.ContractTests}/
client/
  lib/{app,core,features}/
  packages/briani_api/         # generated; never manually edited
  test/
  integration_test/
  android/ linux/ windows/ macos/
contracts/                    # implementation copy of plan contract + lock metadata
infra/{compose,images,proxy}/
tools/{dev,test,release,fixtures}/
docs/{user,admin,development,evidence,adr}/
```

Keep one modular application, not independent microservices per feature. Start with one production .NET project and separate test projects. Do not add generic repositories, mediator/CQRS frameworks, event sourcing, microservice buses, or interfaces for every class. Introduce interfaces at external systems, clock, filesystem and player boundaries where tests/replacement justify them.

## Module contracts

**Auth:** accounts, token lifecycle, sessions/devices, authorization policies, bootstrap. Provides identity and library grants; owns no media bytes.

**Libraries:** allowed roots, browsing/search, scans, thumbnails, image and subtitle records, read/management operations. Does not initiate torrents.

**Discovery:** normalized result snapshots and source references. Knows Prowlarr, not filesystem paths. Returns opaque result identifiers, not indexer credentials.

**Downloads:** resolves a selected source, validates metainfo, controls qBittorrent, manages selected files, quotas, job state, import and seeding. Owns mapping from a Briani request to an upstream torrent.

**Playback:** creates scoped sessions, authorizes items, exposes completed or piece-aware streams. Consumes download availability without changing piece scheduling. Does not make player-specific decisions about download order.

**Settings/operations:** typed validated settings, health, service versions, backup/import job status, administrative audit. Exposes a curated subset of upstream configuration rather than a blind proxy.

### Required replaceable boundaries

`ITorrentEngine` handles metadata/status, selection, sequential mode, limits and lifecycle. `IAvailabilitySource` supplies generation-tagged piece maps and file layouts. `IProgressiveByteSource` reads available bytes with cancellation. `IIndexerGateway` returns normalized results/source resolution. `IContainedFileSystem` handles safe paths and descriptors. Flutter `PlaybackAdapter` and `ExternalPlayerLauncher` isolate native playback behavior.

Do not create a second torrent engine solely for HTTP serving. A narrow qBittorrent compatibility patch is a predetermined last-resort contingency in specification 11, not the default architecture.

## Storage layout and lifecycle

Default host storage is `/srv/briani/data`, mounted as `/data` in Briani and qBittorrent with identical paths. State lives in separate persistent local directories.

```text
/data/
  family-videos/               # library root; administrator-selected
    .briani/staging/<download-id>/...torrent payload...
    .briani/trash/<operation-id>/...
    Example release--<short-id>/movie.mkv    # completed hard link
  photos/
  other-library/
/config/briani.db
/config/keys/
/config/cache/                 # capped, disposable previews
```

Staging is inside the destination library's filesystem. This supports a same-filesystem hard-link import even when different libraries occupy separate mounted disks. Hide every `.briani` directory from ordinary browsing and scans. Show selected in-progress files as virtual library entries backed by download records.

On completion, validate media, then create a collision-safe visible directory and hard links. Keep the original payload at its staging path while qBittorrent seeds. Never move/rename its files directly. If hard links are unavailable, use a **virtual library entry pointing to the stable managed payload**; do not automatically copy gigabytes or break seeding. Existing files in libraries are indexed in place.

Renaming/moving a completed visible hard link within the same library does not rename the torrent payload. On a filesystem without hard links, rename is display-only while torrent-managed; the UI says so. Cross-library moves are excluded from v1; add-to-another-library is a separate explicit import after completion and only for administrators with storage space.

Deleting a visible file and deleting the torrent payload are different operations. A job must account for active sessions, visible links and retention before removing payload bytes. Never let `deleteFiles=true` be the default remove-download action.

## Control flow and recovery

All mutating download operations have idempotency keys and durable intents. Serialize operations per upstream torrent. Before retrying a non-idempotent upstream operation, reconcile observed state. qBittorrent sequential/first-last toggle endpoints are not safe to blindly retry: observe desired versus actual state before toggling.

SQLite is authoritative for users, grants, chosen destination, job intentions and user preferences. qBittorrent is authoritative for transfer state and available pieces. Filesystem is authoritative for actual file presence. A reconciler joins these realities and repairs interrupted operations rather than overwriting one with assumptions from another.

Use an in-process bounded job channel backed by durable job rows. On startup reacquire expired job leases and reconcile. SSE delivers invalidation/progress hints; clients recover from a reconnect by fetching snapshots. Persist transitions, not every piece poll or player-frame update.

## Dependency failure behavior

Prowlarr down: browsing/playback/download management still work; discovery returns explicit degraded status and cached results with timestamps. qBittorrent down: completed imported files still play; new downloads and progressive streams enter dependency-unavailable states. Missing disk: no new writes or pruning; mark library offline, preserve metadata and show corrective instructions. Client disconnect: cancel the HTTP read, release buffers, leave the torrent running unless the user explicitly paused it.
