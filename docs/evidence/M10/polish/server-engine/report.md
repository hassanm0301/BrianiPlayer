# Dedicated engine integration verification

Both repository EngineIntegration tests passed against new isolated containers using their dedicated harnesses, once each and sequentially. No production-source changes, real indexer accounts, Pi or physical Android contact. Parent had already built the test assembly; these invocations use `--no-build --no-restore`.

## Actual commands and results

From `/home/hassan/projects/BrianiPlayer`, with approved escalation for the local Docker socket:

```sh
DOCKER_CONFIG=/home/hassan/projects/BrianiPlayer/.tools/docker-config \
DOTNET_CLI_HOME=/home/hassan/projects/BrianiPlayer/.tools/dotnet-home \
NUGET_PACKAGES=/home/hassan/projects/BrianiPlayer/.tools/nuget \
timeout --signal=INT --kill-after=20s 300s \
python3 prototypes/downloads/engine/run_pinned_engine.py \
  --log docs/evidence/M10/polish/server-engine/adapter.json

DOCKER_CONFIG=/home/hassan/projects/BrianiPlayer/.tools/docker-config \
DOTNET_CLI_HOME=/home/hassan/projects/BrianiPlayer/.tools/dotnet-home \
NUGET_PACKAGES=/home/hassan/projects/BrianiPlayer/.tools/nuget \
timeout --signal=INT --kill-after=20s 300s \
python3 prototypes/downloads/engine/run_local_peer_transfer.py \
  --log docs/evidence/M10/polish/server-engine/metadata.json
```

| Harness | Run ID | Outer / test exit | Actual test result |
|---|---|---|---|
| Adapter | `f719c9bccf334dbf8f2f121258dc2b84` | 0 / 0 | `PinnedEngineLiveSmokeWhenConfigured`: 1 passed, 0 failed, 0 skipped; reported test duration 2 seconds |
| Metadata/layout | `35690af262d344fd88ea04e5ff8a02ac` | 0 / 0 | `LocalSeedMetadataMagnetsMapV1V2HybridAndZeroLengthWithoutPayload`: 1 passed, 0 failed, 0 skipped; reported test duration 15 seconds |

`adapter.json` and `metadata.json` retain the actual filtered test output. The adapter test asserts qBittorrent v5.2.4 / WebAPI 2.15.1 / libtorrent 2.0.15.0 and exercises managed preferences, sequential/metadata-assist settings, bounded add/export/files/limits/start/stop/removal and metadata-only add. The metadata test covers v1, v2, hybrid and zero-length layout/magnet fixtures, with typed hash observations retained in its JSON; hybrid metadata adopts the engine's truncated-v2 upstream ID while preserving its full v1/v2 identities.

## Isolation and cleanup

Preflight found the existing generated corpus and v1/v2/hybrid torrent files, the 3,564-byte metadata-consent torrent, and the built DownloadTests.dll. Inspection of that adapter torrent found no tracker announce/list or webseed fields. Both harnesses name new run-specific Docker networks/containers and create networks with `--internal`; all mounts contain only generated copies and unique temporary state. The metadata runner creates nonprivate trackerless copies for magnet acquisition, using only its explicit owned seeder; original private layouts are also tested. Dedicated test configuration applies managed engine preferences. No production Compose stack or existing container is addressed.

After both successful invocations, a separate read-only cleanup check queried only `org.briani.test=M05` plus each exact 32-character run ID. It checked both containers and networks, plus the exact run-prefix scratch directories. Command:

```sh
DOCKER_CONFIG=/home/hassan/projects/BrianiPlayer/.tools/docker-config \
python3 /tmp/briani-polish-performance/check_engine_cleanup.py
```

Exit **0**; `cleanup.json` reports no remaining containers, networks or scratch paths for either run. A retained copy of the checker is included here as `check_engine_cleanup.py`. No cleanup exceptions were inferred away from harness return codes.

These two actual harness passes supplement the ordinary solution invocation, whose missing fixture environment made its EngineIntegration dynamic-skip exceptions fail. They do not establish Pi performance, physical-platform compatibility, exhaustive upstream behavior or repeatable reconnect reliability. Existing hardware/reconnect release blockers remain unchanged.
