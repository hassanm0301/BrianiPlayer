# M10 benchmark tooling

This adds a bounded collector, not benchmark evidence. No Pi or production stack was contacted and no measurements are claimed here. `tools/dev.py benchmark --profile pi5` remains parent-owned; the parent can invoke this standalone collector after the isolated workload and fixture API exist.

## Collector interface

Run `python tools/benchmarks/collect.py --help` for the full interface. The collector requires the exact Compose project and all three explicit full container IDs. It calls `docker inspect` for those IDs and requires labels `com.docker.compose.project=<project>`, `com.docker.compose.service` in `briani|qbittorrent|prowlarr`, and `org.brianiplayer.fixture=true`; all three services must be running. Sampling uses only `docker stats --no-stream` with those same IDs, for at most 1,800 seconds. It never discovers containers or issues global stop/kill/remove commands.

Example, after the parent creates a fixture-only project and records its IDs/API fixture hash:

```sh
python tools/benchmarks/collect.py \
  --project briani-m10-fixture \
  --container-id <briani-id> --container-id <qbittorrent-id> --container-id <prowlarr-id> \
  --api-url http://127.0.0.1:18088 --api-path /healthz \
  --credentials /run/user/1000/briani-benchmark-credentials.json \
  --fixture-url http://127.0.0.1:18088/api/v1/fixtures/<authorized-fixture-id>/bytes \
  --fixture-sha256 <independently-recorded-sha256> \
  --storage-path /mnt/fixture-data --duration 1800 --interval 5 \
  --output docs/evidence/M10/pi5-benchmark.json
```

The credentials file is JSON with string fields such as `{"bearer":"..."}` or `{"header:X-API-Key":"..."}`. It must be mode 0600 or stricter. Secrets are never added to the command line or output. The API request is repeated as a warm GET (25 samples by default); the optional fixture transfer must use the same API origin and an explicit `/api/v1/` path, and its complete response is checked against the separately supplied SHA-256 before throughput is reported. The fixture API endpoint and authorization must be supplied by the integrated test harness; this tool does not invent one.

Output captures OS/kernel, architecture, device-tree model, detected RAM and thermal readings, storage mount/device, discovered network interface carrier/speed, warm API median/p95, hash-verified fixture throughput, raw per-container Docker CPU/memory samples and rollups. The API origin is restricted to loopback, avoiding credential forwarding to a remote host. Fixture transfer is streamed in 1 MiB blocks with an 8 GiB cap. Docker memory is documented as working-set usage; it does not prove process RSS or separate reclaimable page cache. Cooling, actual drive model/connection and end-to-end link throughput still need operator evidence. Unknown hardware is saved as unknown and exits 3. Missing Docker, labels, running services, authorized fixture endpoint, or a usable fixture hash is a nonzero blocked/error result, never a pass.

`tools/benchmarks/fault.py` supports one explicit `stop` or `start` action for container IDs carrying the same project, service and fixture labels. It rejects running targets for start and non-running targets for stop, and uses a bounded command timeout. It provides no host-level network, power, filesystem, or production-data fault controls.

## Local verification

`python -m unittest discover -s tests/benchmarks -v` exercises label validation, explicit ID validation, secret-file permissions, p95 calculation, Docker stats parsing and bounded duration handling with fake command output. It does not simulate hardware and does not establish performance results. Native hardware capture is pending integration with the isolated Compose fixture stack and operator-recorded cooling/storage/network details.
