# M06 — Progressive playback gateway evidence

## Summary

**Milestone:** M06, progressive gateway and playback sessions. **Evidence date:** 2026-10-12. **Code status:** complete for the local M06 implementation. **Local verification:** passed for the recorded host suites, player proof, original M00 regression, and actual v1/v2/hybrid layout matrix. **Hardware verification:** not run here; the available production Pi and final Android TV checks remain assigned to later integration. Windows/macOS runners are unavailable. **Commit:** none; this checkout has no Git repository metadata. The whole Briani Player application remains in progress; this report does not certify a release or later milestones.

Production playback reads validated, piece-available ranges through scoped sessions. Actual engine runs verified incomplete MP4/MKV playback, buffering and resume, byte equality, and layout behavior. Limitations below remain part of the result.

## Environment and versions

- Host: Linux x86_64, kernel `7.2.9-zen1-1-zen`; native .NET SDK `10.0.112`.
- API image used by the production proof: image ID `sha256:617088d4092aafa77a4849941092150b23e99d45ce2d2705e22d779ca067553e` (`briani-server:dev`).
- qBittorrent: `v5.2.4`, Web API `2.15.1`, libtorrent `2.0.15.0`; image pinned to `lscr.io/linuxserver/qbittorrent@sha256:97333cc1ccf903e0bbcd8eb67e3332e4970e9c1ecabe145e499e9c0847ebcaed`.
- Player/tooling: mpv `0.41.0`, FFmpeg `9.0.2`; VLC runtime `3.0.20`, Python VLC `3.0.20123`, VLC image ID `sha256:dc17d534e78a256cb3dc377628f36c5a28ed85df866d84eb3110cc46221617a6`.
- Fixture-generation Python libtorrent binding was `2.1.2.0`; that is distinct from the qBittorrent engine's libtorrent `2.0.15.0`.
- Real-engine swarms used internal Docker networks, no published ports, local synthetic media and no external trackers or peers. The final layout matrix had no remaining containers or network under its run label.

No Raspberry Pi 5, physical display, Android TV device, Windows runner or macOS runner was used. No CPU, memory, sustained I/O or Pi performance benchmark is claimed.

## Implemented behavior and observed proof

The M06 server code adds the piece-aware progressive reader, shared torrent availability snapshots, range handling, scoped playback ticket/session lifecycle, permission and generation rechecks, bounded reader leases, status/event hints and sidecar delivery. Eleven EF migrations are present, including playback ticket issuance and the playback-invalidating operation fence. The independent review in `review-final.md` inspected playback source and its download/session boundaries, found no additional P0–P2 issues, and records all six initial findings as statically resolved. It did not run tests; test evidence below is separate.

Production artifact `prototypes/playback/production/artifacts/4265575d595f4591ae2d1fa24b06c7ab/result.json` passed for three generated files. mpv decoded the faststart MP4's first frame at 0.151 s with torrent progress 85.4%, and the MKV first frame at 0.151 s with progress 81.2%; both were incomplete, with 17,301,504 and 16,777,216 contiguous bytes respectively. In both cases the result records decoded H.264 video parameters, buffering, a cache pause stable for just over one second, and resume in the same player. The MKV fixture had multiple audio and subtitle tracks. These are local decode observations, not universal startup-time promises.

The tail-metadata MP4 waited until completion and then decoded at about 4.06 s; this is an honest metadata wait, not an early-play pass. VLC decoded an incomplete faststart MP4 frame in the dummy output. VLC did **not** decode the incomplete MKV within its 27-second bound; the same URL decoded after completion (61 video decodes, five pictures reported by the dummy output). Thus the incomplete MKV VLC attempt is a recorded failure, and its completed comparison is not evidence of early VLC MKV playback. Neither player run certifies physical display output.

The final actual layout matrix (`layout-83f5dbaa0efc4c2f90a0b58293fc0d89/result.json`) passed for v1, v2 and hybrid torrents, including native offsets, nonaligned files, padding/ignored neighbors and independent byte-oracle checks. Each mode exercised four ranges, including a piece-boundary range and concurrent identical readers; priorities remained unchanged. All three staged files retained their full logical length while allocated blocks were lower than logical length, and each incomplete gap wait returned zero body bytes. The v1 restart race terminated an open reader at the missing gap with zero gap bytes; its old URL returned a problem response and the fresh session served exact source bytes under a changed generation. Recheck fenced the old ticket and the replacement ticket also matched the source. The harness requires a structured 404 `not_found` or 409 `generation_changed` response, rejecting success-shaped media responses.

The original M00 engine regression `ad61572024e14eddad15b4b384a5d64f` passed. It covered five early-play cases (faststart v1/v2/hybrid, MKV v1 with second audio/subtitle selection, and tail-metadata MP4 v1), three multifile layout modes, metadata-only behavior, and cancellation. Its multifile oracle compared 16,902,070 bytes in each mode with exact equality, including ignored files and a fenced recheck. The M06 layout matrix adds actual qBittorrent v1/v2/hybrid staging and sparse-storage checks. It does not cover >4 GiB offsets.

## Commands and results

| Command / activity | Environment | Exit | Result and evidence |
|---|---|---:|---|
| `python3 prototypes/playback/run.py verify --suite engine` | Linux/amd64, qBittorrent 5.2.4 / engine libtorrent 2.0.15.0, mpv 0.41.0 | 0 | M00 run `ad61572024e14eddad15b4b384a5d64f`; `prototypes/playback/artifacts/current-run.json` and per-case result JSON under `prototypes/playback/artifacts/runs/ad61572024e14eddad15b4b384a5d64f/` |
| `python3 prototypes/playback/production/run_api_playback.py --timeout 120` | Isolated production API/qBittorrent swarm; synthetic MP4/MKV | 0 | `prototypes/playback/production/artifacts/4265575d595f4591ae2d1fa24b06c7ab/result.json`; player logs beside the JSON |
| `python3 prototypes/playback/production/run_layout_matrix.py --timeout 120 --artifacts prototypes/playback/production/artifacts` | Isolated internal Docker swarm; qBittorrent pinned image | 0 | `prototypes/playback/production/artifacts/layout-83f5dbaa0efc4c2f90a0b58293fc0d89/result.json` |
| `dotnet test server/tests/Briani.StreamingTests/Briani.StreamingTests.csproj --nologo` | Native .NET 10.0.112 | 0 | 47 passed, 0 failed; `artifacts/dev/20261012T165234.946671Z/` |
| `dotnet test server/tests/Briani.DownloadTests/DownloadTests.csproj --nologo --filter Category!=EngineIntegration` | Native .NET 10.0.112 | 0 | 56 passed, 0 failed; `artifacts/dev/20261012T165202.581789Z/` |
| `dotnet test` media, identity and discovery projects | Native .NET 10.0.112 | 0 each | 49, 32 and 95 passed respectively; `artifacts/dev/20261012T165901.093856Z/`, `165919.539177Z/`, `165943.373561Z/` |
| `dotnet test` contract and unit projects; plan/API generation checks | Native .NET 10.0.112 | 0 each | Contract: 1 passed; unit: 3 passed; plan validator, generated-contract check, ReaderTests, tool/fixture/probe tests, secret scan and dependency inventory passed. `artifacts/dev/20261012T170007.508858Z/`, `170043.966019Z/` |
| Integration suite, pinned engine, local peer transfer and API restart/import checks | Native .NET 10.0.112 and isolated engine | 0 each | Integration: 2 passed; all recorded commands passed. `artifacts/dev/20261012T170107.188629Z/` |
| Docker API image build (`build4`) | Linux/amd64 | passed | `/tmp/briani-m06-image-build4.log`; resulting image ID is recorded in the production result JSON |

The compact suite table refers to full `run.json`, stdout and stderr records in each evidence directory. It does not imply every acceptance case in specification 09 has a separate direct test here.

## Acceptance mapping and limits

Evidence demonstrates the core portions of T01–T09: early MP4/MKV decode, wait and resume, unchanged priorities, v1/v2/hybrid and multifile mapping, sparse-file safety, HTTP range responses, honest tail-metadata waiting, and restart/recheck invalidation. The streaming/download/identity suites and source review provide regression coverage for authorization, session and lifecycle boundaries. This report does not claim the full cross-resource/cross-user matrix of T15, a 24-hour session soak for T19, the Raspberry Pi concurrent-load and performance targets of T26, or every crash window in T32. Those are unverified or assigned to later integrated/hardware acceptance, not inferred from the local passes.

The T26 Pi profile, physical display or audio, Android/TV external-player behavior, ARM64 runtime, Windows/macOS clients and >4 GiB layout offsets were not measured in this run. There was no Pi production data access. The available output/video players used a null or dummy renderer; no display claim is made. Failed earlier attempts remain preserved under `prototypes/playback/production/artifacts/`; the final passing runs are explicitly identified above.

## Independent review

`review-initial.md` records six findings: engine-epoch publication, cancellation order, availability-cache admission, shared session admission, first-byte deadline coverage and compatible shared-selection invalidation. `review-final.md` reports all six statically resolved, including subtitle cleanup and operation-fence consistency, and found no new P0–P2 defect in its final source pass. It was a separate read-only review; it ran no suite and is not a substitute for the recorded runtime checks.

## Subagent accounting

The milestone used scoped implementation workers and a separate source reviewer under the repository protocol. The parent retained production gateway, shared contracts, migrations and final integration ownership. The independent byte/layout harness and result lived under `prototypes/playback/production/`; stream and session test work lived in its assigned test/source areas. Exact worker model/reasoning metadata is not present in the preserved run records, so it is not asserted here. This evidence consolidation changed only M06 documentation.

## Blockers and remaining checks

Local Linux acceptance evidence is complete for the commands listed above. Raspberry Pi 5 ARM64 playback/performance and physical GUI/display/audio verification remain **not run in this local acceptance run**. Windows/macOS and Android TV checks were not run. T26 hardware targets and platform checks must remain unverified until their actual devices/runners are available. `plan/evidence/status.json` is owned by the milestone parent and is updated separately; its earlier in-progress state should not be overwritten by this documentation-only worker.

## Handoff

M06 local server implementation and the described host-side verification are ready for parent integration and M07 continuation. Preserve `layout-handoff.md`, `review-final.md` and the run JSON artifacts as evidence. Keep Pi/physical-display and broader T15/T19/T26/T32 acceptance explicitly visible in the parent status and later M10/M11 release audit. No commit or release artifact is available from this checkout.
