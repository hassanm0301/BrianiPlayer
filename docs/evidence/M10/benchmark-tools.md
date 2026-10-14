# M10 bounded workload tooling

This report describes tooling only. It contains no Pi, container, or performance measurement. The parent owns `tools/dev.py`, Compose fixture deployment, Pi access and device setup. The workload runner will run only after the parent provides an isolated fixture API and an explicit mode-0600 configuration.

## Workload configuration

`tools/benchmarks/workload.py --help` accepts `--config`, `--duration` (1–1800 seconds, default 1800), optional `--low-memory-mib` and `--output`. Configuration is bounded to 32 KiB, must be a regular non-symlink file with mode 0600 or stricter, and contains tokens and exact fixture API URLs. The API origin must be loopback. Folder and status URLs must stay on that exact origin and use `/api/v1/`; stream items accept only an issued same-origin `/stream/{43-character-ticket}/{encoded-file-name}` capability. No URL may contain a query, fragment or embedded credential. Redirects and environment proxy use are disabled. Tokens and URLs are omitted from results and transport errors are sanitized because playback URLs can contain scoped tickets.

Required JSON shape (replace placeholders with actual API IDs, tokens, fixture sizes/hashes and paths; expected SHA-256 values must come from an independent fixture oracle):

```json
{
  "baseUrl": "http://127.0.0.1:18088",
  "folderUsers": [
    {"name":"fixture-user-1","bearer":"...","refreshToken":"...","url":"/api/v1/libraries/<library-uuid>/entries?folderId=<folder-uuid>&limit=200"},
    {"name":"fixture-user-2","bearer":"...","refreshToken":"...","url":"/api/v1/libraries/<library-uuid>/entries?folderId=<folder-uuid>&limit=200"},
    {"name":"fixture-user-3","bearer":"...","refreshToken":"...","url":"/api/v1/libraries/<library-uuid>/entries?folderId=<folder-uuid>&limit=200"},
    {"name":"fixture-user-4","bearer":"...","refreshToken":"...","url":"/api/v1/libraries/<library-uuid>/entries?folderId=<folder-uuid>&limit=200"},
    {"name":"fixture-user-5","bearer":"...","refreshToken":"...","url":"/api/v1/libraries/<library-uuid>/entries?folderId=<folder-uuid>&limit=200"}
  ],
  "completedStreams": [
    {"url":"/stream/<43-character-ticket>/<encoded-name>","bearer":"...","refreshToken":"...","playbackSessionId":"<uuid>","generation":"<target-generation>","bytes":123456789,"sha256":"<64 lowercase hex>","oracleFile":"/mnt/test-fixtures/completed-1.bin","targetMbitPerSecond":25},
    {"url":"/stream/<43-character-ticket>/<encoded-name>","bearer":"...","refreshToken":"...","playbackSessionId":"<uuid>","generation":"<target-generation>","bytes":98765432,"sha256":"<64 lowercase hex>","oracleFile":"/mnt/test-fixtures/completed-2.bin","targetMbitPerSecond":25}
  ],
  "progressiveStream": {
    "url":"/stream/<43-character-ticket>/<encoded-name>","bearer":"...","refreshToken":"...","playbackSessionId":"<uuid>","generation":"<target-generation>","bytes":456789123,"sha256":"<64 lowercase hex>","oracleFile":"/mnt/test-fixtures/progressive-6gib.bin","targetMbitPerSecond":15,
    "downloadStatusUrl":"/api/v1/downloads/<fixture-download-id>","downloadRatePointer":"/downloadSpeed","minimumDownloadBytesPerSecond":3125000
  }
}
```

After the parent provisions the isolated fixture and writes the config with mode 0600, run the workload locally on the Pi with `python3 tools/benchmarks/workload.py --config /secure/path/m10-workload.json --duration 1800 --output /secure/path/m10-workload-result.json`. The collector is a separate bounded sampling command: `python3 tools/benchmarks/collect.py --project <fixture-compose-project> --container-id <full-briani-id> --container-id <full-qbittorrent-id> --container-id <full-prowlarr-id> --api-url http://127.0.0.1:<published-port> --api-path <explicit-warm-api-path> --storage-path <fixture-volume-path> --duration 1800 --output /secure/path/m10-container-samples.json`. Both commands require actual explicit inputs; placeholders are not valid acceptance runs. The collector validates fixture labels before Docker stats/top and never discovers or mutates containers.

Each folder user and each of the three playback owners needs a distinct device-session refresh token; playback items also require the ID and target generation from their actual session-creation response. The runner rotates each refresh token independently through `/api/v1/auth/refresh` every eight minutes, atomically publishing only that owner's new access/refresh pair. It polls existing authenticated GET `/api/v1/playback/sessions/{id}` every 30 seconds, requiring an active documented state, unchanged target generation, and—when returned—an unchanged issued capability URL. It does not POST renewal or change the ticket: active range reads update idle activity, and the accepted run is bounded to 30 minutes. A missing progressive stream, lease input or status monitor fails configuration validation with exit 3; it cannot be silently omitted. Every configured `oracleFile` must be an absolute local test-fixture path. The runner opens it read-only with no-follow, verifies regular-file identity and exact size, hashes the entire file in 1 MiB blocks before starting the workload, and compares each returned 256 KiB HTTP range with the corresponding local fixture offset before counting bytes. It rechecks descriptor/path identity during reads and closes only its opened descriptors. A 6 GiB progressive source therefore remains byte-verified during the run even when it cannot complete a full cycle. If no local oracle is configured, a stream passes byte acceptance only after a complete SHA-256 cycle; that is insufficient for a partial progressive run. Local paths are never written to evidence output. Completed streams are paced at 25 Mbit/s each; progressive playback is paced at 15 Mbit/s while the same fixture download's measured status rate is polled every five seconds. Each folder user issues one authenticated list request per second. Report includes request count, API latency median/p95 and the <250 ms five-user target, stream bytes/cycles/range-oracle/rate signals, download-rate median/target, cancellation/errors and actual bounded duration. A target is considered met only when observed average stream rate is at least 95% of configured target, and that tolerance is visible in each stream result. Folder responses are fully consumed up to a 2 MiB bound; status JSON is fully consumed up to 256 KiB.

The optional low-memory trip guard reads host `MemAvailable`; crossing the configured threshold stops the run and closes only registered HTTP responses owned by this runner. It does not change host limits or kill containers. This is a safety abort, not a pass.

## Collector additions

`collect.py` now reports per-container `dockerWorkingSetBytesMedian/Max` from Docker stats and `processRssBytesMedian/Max` from `docker top` over the same explicit verified container IDs. Process RSS sums host-visible process RSS and can double-count shared pages. `dockerMemoryLimitSupport` is read from Docker info and may be false/unknown; the Pi preflight currently reports memory-limit support false, which must remain an explicit environment limitation in the resulting report. This collector does not infer process RSS from Docker working set or treat unsupported memory limits as a successful configured cap.

Container selection remains explicit: caller supplies project and IDs, and inspect requires the exact project, fixture marker and allowed service label before stats/top. No container discovery, stop, kill, or host setting operation is performed by the collector. The separate fault helper remains limited to explicit fixture-labeled stop/start calls.

## Unit verification

`python -m unittest discover -s tests/benchmarks -v` passes the fake-command and fake-HTTP suite. It checks explicit container labels/IDs, working-set parsing, per-container RSS command scoping, Docker memory-limit false reporting, secret-file mode, p95 calculation, maximum window, required progressive config, five distinct user and owner refresh tokens, exact stream capability paths, same-origin API URL enforcement and restricted folderId/limit query validation, refresh-token rotation ownership, fail-closed session generation/status and unchanged ticket checks, target rate bounds, complete fixture prehash and size/hash checks, partial range-by-range oracle comparison without a completed cycle, immediate partial-range corruption rejection, changed symlink/path rejection and exact descriptor closure, redirect refusal before credential forwarding, and cancellation closing only owned responses. These tests exercise no hardware, do not fabricate a benchmark pass, and are not evidence of API workload behavior on the Pi.
