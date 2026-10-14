# M00 — Sequential playback proof

## Summary

Milestone: M00 playback proof. Evidence date: 2026-10-12. Code status: local proof prototype exercised. Verification status: playback prototype gates demonstrated on the local Linux/amd64 development host; full hardware/release verification remains blocked. No commit identifier is available in this checkout. This report consolidates preserved artifacts; it does not assert that every M00 gate has passed.

## Environment and versions

The recorded engine is qBittorrent v5.2.4, Web API 2.15.1, libtorrent 2.0.15.0, running in an isolated local Compose swarm. Playback used packaged mpv 0.41.0 with the null renderer. Synthetic fixtures were generated locally. Exact component/build metadata is in `toolchain.lock.json` and `prototypes/playback/artifacts/doctor.json`. The current run is not Raspberry Pi 5 evidence and did not certify a display renderer.

## Implemented behavior and observed proof

The proof exercised faststart MP4 with v1, v2 and hybrid torrents, MKV v1, and tail-moov MP4 v1. The result JSON files report exact HTTP byte equality, valid initial ranges, and unchanged queue priority. Each playback probe produced a decoded frame while torrent progress ranged from 3.11% to 8.36%; first-frame observations were approximately 0.302–0.318 seconds in the recorded local runs. These are fixture-specific observations, not performance guarantees.

Gap/cancellation probes observed waiting while a required piece was missing, cancellation in approximately 0.0026–0.0036 seconds, equal resumed bytes, and unchanged priorities. Multifile mapping compared 16,902,070 bytes at the recorded v1/v2/hybrid offsets with byte equality and a fenced recheck. Metadata-only probing left payload bytes unchanged and downloaded zero payload bytes. The artifact explicitly says trackerless peer discovery was not certified by that harness. See `prototypes/playback/artifacts/summary.json`, individual `*-result.json` files, `commands.jsonl`, and associated logs.

## Commands and results

| Command / activity | Environment | Exit status | Evidence |
|---|---|---:|---|
| `dotnet run --project prototypes/playback/tests/ReaderTests.csproj` | Linux/amd64 | 0 | `prototypes/playback/artifacts/reader-unit.log` |
| Python fixture unit discovery | Linux/amd64 | 0 | `prototypes/playback/artifacts/fixtures-unit.log` |
| Python harness unit discovery | Linux/amd64 | 0 | `prototypes/playback/artifacts/harness-unit.log` |
| Gateway build | Linux/amd64 | 0 | `prototypes/playback/artifacts/gateway-build.log` |
| Isolated real-engine playback, range, gap/cancel, multifile and metadata-only probes | qBittorrent 5.2.4 / libtorrent 2.0.15.0 | recorded results | `prototypes/playback/artifacts/commands.jsonl`, `summary.json`, and result JSON files |

## Independent review

The M00 checkpoint records source inspection of the pinned libtorrent/qBittorrent paths and the stock queue mask behavior that prevents serving hash-passed but unflushed pieces. This report does not claim a separate reviewer agent; the checkpoint's source-review provenance is not more specific.

## Blockers and remaining checks

The metadata-only task proved the stopped metadata API path and zero payload change, but explicit peer discovery is not certified. The playback proof uses the null renderer and does not establish display/audio experience. Native Raspberry Pi 5 performance and hardware behavior remain blocked verification. No release certification is claimed; see `summary.json`.

## Handoff

M01 foundation work may use this as the local compatibility proof input. Preserve the distinction between synthetic isolated-engine evidence and Pi/hardware verification. Detailed M00 command output and generated fixture results remain in `prototypes/playback/artifacts/`.

## Follow-up proof tooling work (2026-10-12)

The fixture generator now rejects incomplete mode results, sets libtorrent creation date to zero when the binding exposes `set_creation_date`, and records `status: generated` for single-file torrents. Verification output is scoped under a fresh run ID so an earlier successful result cannot satisfy a later failed `verify`; the report task checks the current successful verify invocation and its recorded gateway-build command. The mpv integration path now records source track counts, selects and verifies second audio/subtitle tracks when present, and attempts a bounded engine-pause/cache-wait/resume observation. These integration changes have not yet been exercised against qBittorrent/mpv.

The latest fixture unit command, `python -m unittest discover -s prototypes/playback/fixtures -p 'test_*.py' -v`, exited 1 (one failure): libtorrent 2.1.2.0 omits the `creation date` metainfo key when `set_creation_date(0)` is called, while the new test currently expects the key to be present with value 0. The generator itself completed through torrent generation; this assertion needs to accept the omitted key as effective zero, then the suite must be rerun. Earlier in that same run, the new completeness check correctly exposed missing `status` fields in single-file generated records; those are now populated.

A targeted real-engine rerun was not performed: `docker compose ... ps` could not resolve the pinned image variable without the wrapper environment, and `docker ps` reported permission denied on `/var/run/docker.sock`. Existing prior M00 artifacts and generated fixtures were preserved; new results use `prototypes/playback/artifacts/runs/<runId>/`.


## Fresh controlled pause verification

`python prototypes/playback/run.py verify --suite engine`: exit0, current run36403b7239c145b7bdf5e40ba3227cfe. `report`: exit0, no missing current-run gates. Exact results are in prototypes/playback/artifacts/runs/36403b7239c145b7bdf5e40ba3227cfe. Full log /tmp/briani-m00-engine-controlled-pause.log. MKV second audio/subtitle selected and actual mpv cache wait/stable position/resume observed. Earlier new-check runs failed during asynchronous track/position transitions and remain recorded; transfer now freezes at first frame and the observer waits for selection/position stability. No timeout or gate was removed. Creation-date0 absent metainfo is valid for pinned binding; unit assertion now accepts absent as0. Native Pi/display certification, explicit preallocation and engine restart/selection transition checks remain pending.

## Lifecycle proof integration

The parent fixed test-host creation before recheck completion; the fresh lifecycle command exited0. See lifecycle.md, lifecycle-parent.log and lifecycle-result.json. Explicit preallocation, selection, recheck and actual isolated downloader restart checks passed locally. The earlier pending statements above are superseded for these local checks. Hardware/display/performance gates remain blocked verification. Separate scoped source/availability reviewers ran in this implementation session; source licensing audit remains M11.
