# M03 libraries and completed media

The server implementation includes contained roots, persistent scans and bounded native metadata/thumbnail jobs, folder search/filter/sort with signed scoped pagination, authorized photo/thumbnail routes, completed-video byte ranges and hashed playback tickets, per-user resume/watched progress, Continue watching, and journaled same-library rename/move/trash/permanent removal. Visible hardlinks retain their seeding payload; virtual catalog operations do not remove payload. Scans hide `.briani` and tolerate per-item corruption/change. Existing media works without configured upstream services.

## Executed verification

| Command | Exit | Evidence |
|---|---:|---|
| `python tools/dev.py test --suite media` | 0, 49 tests | `media-final.log`, runner artifact recorded therein |
| `python tools/dev.py test --suite identity` | 0, 32 tests | `identity-final.log` |
| `python tools/dev.py test --suite unit` | 0, including verified-byte reader/fixture/tool checks | `unit.log` |
| `python tools/dev.py test --suite integration` | 0, 2 tests | `integration.log` |
| `python tools/dev.py test --suite contract` | 0, including deterministic Dart regeneration | `contract.log` |
| `docker buildx build --load -t briani-server:dev -f infra/images/server.Dockerfile .` | 0 | `image.log` |
| `python tools/dev.py compose --task smoke` | 0 | `compose.log` |
| `python tools/media_container_probe.py` | 0 | `native-api.log`, `artifacts/media-container/08214e0fb9bb46d89e99df2cf65df70b/result.json` |

The actual nonroot/read-only Linux amd64 Docker application scanned generated H264 MP4/JPEG files, used its packaged FFmpeg9.0.2, produced bounded JPEG thumbnails, served exact original photo bytes and an exact video byte range. Prowlarr/qBittorrent were unconfigured throughout. The container used a 1GiB limit and 256-process limit; this was functionality verification, not a benchmark. Bounded probe subprocess address space is 1GiB; prior host512MiB experiment failed and was not treated as passing.

Media regressions cover conditional/range/HEAD behavior, malformed/empty/changed media, ticket lifecycle and ownership, live revocation during blocked writes, source replacement, thumbnail/source generation, optimistic per-user progress, unknown duration, 95% watched threshold, pagination scope, stable identity/history across moves, collisions/traversal, hardlink preservation, force reader cancellation, virtual deletion, interrupted move reconciliation and revoked authority before permanent cleanup. An asymmetric generated EXIF-orientation6 JPEG verifies output dimensions and colored pixel placement. Mount mapping tests include filesystem-root ancestry in both directions.

## Review and corrections

Separate Sol high review findings and fixes are recorded in `review.md`. Corrections include independent authorization watchers during blocked image writes; reauthorization before irreversible recovery cleanup; fresh checks for virtual/no-op recovery; bounded logical library removal and cancellation of scan leases; scan/catalog writes deferred during pending mutation journals to preserve stable identity after interrupted moves; root bind-alias ancestry; and playback creation idempotency. Retries return the original session with a null raw URL because only hashes are persisted. See `docs/development/playback-idempotency.md`.

One identity regression initially failed because its manually configured state directory did not exist; the fixture now creates both required roots. The task runner initially omitted returning its discovered media project; that dispatch bug was fixed before recording the successful media gate. No security behavior or test was disabled.

## Limits and subsequent work

This completes the M03 server slice of T07/T15/T16/T18/T19/T24 and initial T12/T32 storage cases. Later torrent imports, progressive delivery, client photo zoom/slideshow, full10k performance, hardware players, and process-kill/system resilience tests remain in their later milestones. No Pi, Windows, macOS, phone or TV result is claimed. Durable SQLite journals recover process interruption; full power-loss acceptance remains M10. Production configuration/data were not changed. M04 proceeds with Prowlarr discovery.
