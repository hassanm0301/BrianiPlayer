# Local qBittorrent network-loss recovery probe

**Status: partial; spontaneous engine recovery reliability remains open.** The probe generated a private v1 torrent from the repository's synthetic 15,787,543-byte MP4 and exercised the pinned qBittorrent 5.2.4 image on an owned Docker `--internal` network. No external tracker, swarm, host service, Pi, or production data was used. One unassisted run completed and matched all bytes, but two other unassisted runs stalled. A controlled downloader restart completed successfully, proving the explicit operator-controlled recovery path; it does not establish spontaneous recovery reliability. The unassisted passing run is [qbittorrent-network-loss-unassisted-success.json](qbittorrent-network-loss-unassisted-success.json), and the controlled pass is [qbittorrent-network-loss-controlled-restart-v2.json](qbittorrent-network-loss-controlled-restart-v2.json).

Run `a237a1947e06436893dbcf9430610fb9` completed with exit 0. Before disconnect, the downloader had an active peer and 49,328 downloaded bytes. Disconnecting only its full-ID container from the owned network stabilized the observed byte count at 114,688 after 3.76 seconds. The runner reconnected that same container at its original IP, re-added the exact seeder peer, started the same torrent, cleared the receiver cap, and raised the seed upload limit to 8 MiB/s. The existing transfer resumed 5.568 seconds after reconnect and reached 100% within the completion bound. The completed file's 15,787,543 bytes matched the independent generated source SHA-256 `40f1485f12f0d7da01e433ac15d21ec84bd66911c62f1e8648fad6a960578907`; the retained seeder metadata and seeder file matched the same torrent and hash.

The reconnect progress deadline is 210 seconds, based on the pinned libtorrent 2.0.15 source setting `min_reconnect_time` to 60 seconds and the locked qBittorrent 5.2.4 session implementation not overriding it. The deadline and source references are recorded in the JSON. The 30-second run `440d8b8112064e278e7ef0b0b09207b0` and 210-second run `f8c430b0d7b74e05a132405265f6302d` both failed to recover; there was no intervening code or transfer-control change before the later pass. Their raw outputs are preserved as [30-second failure](qbittorrent-network-loss-30s-failure.json) and [210-second failure](qbittorrent-network-loss-210s-failure.json). The latter ended `stalledDL` with zero connected seeds. The subsequent unassisted run passed, but its cause relative to the previous stall is unknown, so spontaneous-recovery reliability is not established.

The first controlled-restart attempt (`c5e0f6fe6ecb435aa306fa1f62816fdf`) stopped at an invalid monotonic-progress assertion; its failure artifact is retained. The corrected single run (`10ba7c4dcff84134a79a4f660410e274`) recorded volatile torrent counters and piece counts before and after restart without requiring monotonicity. qBittorrent reauthenticated, retained the exact torrent, and kept all 15,787,543 partial-file bytes with identical SHA-256 (`7b79dc15c6c6f15fe0053bf1623ad020da2690a438b1f52250a108d0fa11534c`). After the harness re-added only the exact owned seeder peer and started the same torrent, the transfer resumed in 2.541 seconds and completed. The final downloader and retained seeder independently matched the generated source SHA-256 `40f1485f12f0d7da01e433ac15d21ec84bd66911c62f1e8648fad6a960578907`. This establishes the tested explicit restart-and-peer-readd recovery path, while spontaneous recovery remains open due to the earlier unexplained stalls.

All actual runs used exact run labels. The unassisted success, earlier controlled failure, and corrected controlled success removed their qBittorrent containers and private networks with no cleanup errors; their marker-owned scratch roots were removed. Cleanup normalizes Docker's abbreviated IDs before deduplicating them.

## Commands and results

```sh
python3 -m unittest prototypes/security/resource_faults/test_run.py
# exit 0: 4 ownership, metainfo, and source-derived timeout checks passed

python3 -m py_compile prototypes/security/resource_faults/run_qbittorrent_network_loss.py
# exit 0

DOCKER_CONFIG="$PWD/.tools/docker-config" \
  python3 prototypes/security/resource_faults/run_qbittorrent_network_loss.py
# exit 0: one unassisted complete transfer; independent payload hashes matched
# run ID a237a1947e06436893dbcf9430610fb9; reliability remains open

DOCKER_CONFIG="$PWD/.tools/docker-config" \
  python3 prototypes/security/resource_faults/run_qbittorrent_network_loss.py \
  --recovery restart-downloader \
  --output docs/evidence/M10/qbittorrent-network-loss-controlled-restart-v2.json
# exit 0: exact partial-file hash retained through restart; re-added private peer and
# explicit start recovered and completed the torrent; independent source hashes matched
# run ID 10ba7c4dcff84134a79a4f660410e274
```

The runner verifies the local image ID against its pinned digest and reports the actual qBittorrent API version. The fixture is generated synthetic media, the torrent is private and has no tracker URLs, and all peers stay on the internal Docker network. No startup guarantee or repeatable spontaneous peer-reconnect behavior is claimed.
