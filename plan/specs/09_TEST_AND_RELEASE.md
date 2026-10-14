# 09 — Test strategy and release acceptance

## Evidence policy

Tests are part of implementation, not a final optional phase. Use generated/legal media, an isolated local swarm, a fixture indexer and temporary storage. Never depend on the public availability of a particular copyrighted release or a live tracker for CI.

No test results exist merely because this plan lists them. Every milestone records commit, dependency/image versions, architecture, commands, exit codes, fixture identity and reports. Distinguish `passed`, `failed`, `not_run`, `blocked_environment`, and `not_applicable`. Do not report an Android emulator as a physical TV or emulated ARM as a Pi benchmark.

## Test layers

**Unit:** range parser and length arithmetic; v1/v2/hybrid file mapping; path containment; permission rules; quota reservations; state transitions; source normalization/dedup; expiry/refresh; UI state reducers. Favor property-based tests for offsets and range intersections.

**Component:** ASP.NET test host + real temporary SQLite; typed Prowlarr/qBittorrent fakes with recorded sanitized fixtures; Flutter widget/state tests; independent error paths. Use a fake clock for timeouts/backoff, not long sleeps.

**Integration:** actual locked containers; local seeder; actual incomplete files; real HTTP range responses and byte comparisons; migrations, import/hard-link lifecycle, restart/recheck, source proxy resolution and backup/restore. One job must exercise the real engine rather than only a mocked piece bitmap.

**End-to-end:** desktop and Android/TV flow from sign-in through discovery, file selection, progressive playback and library import; external player launch; reconnect/revocation; D-pad-only operation. Screenshot/log/video evidence only from actual runs.

**Hardware:** Pi 5 resource/throughput/soak matrix, ARM Android phone and Android TV playback, Windows/macOS native builds. Hardware gates may be recorded blocked, but the corresponding support claim cannot be released as fully validated.

## Named acceptance tests

| ID | Required scenario / pass condition |
|---|---|
| T01 | Generated faststart MP4 starts before complete; first-frame timestamp recorded alongside download percentage. |
| T02 | Generated MKV starts before complete; audio/subtitle track selection works where included. |
| T03 | Missing middle piece: no invalid bytes emitted, client buffers, playback resumes when data arrives. |
| T04 | Far-forward missing range does not alter sequential/priority settings; cancel returns within two seconds. |
| T05 | Nonaligned multi-file, ignored neighbors, padding/hybrid and pure v2 file layouts match a separate oracle. |
| T06 | Sparse/preallocated storage never makes missing regions appear playable; exact served bytes equal original. |
| T07 | HTTP HEAD/single/open/suffix/multirange fallback, overflow, 416 and timeout behavior satisfy contract. |
| T08 | Tail-metadata MP4 waits honestly or opens when needed metadata arrives; no hidden remux/transcode. |
| T09 | Engine restart/recheck/file selection change invalidates active generations; no stale-bit reads. |
| T10 | Same download idempotency key adds only once; timeout-after-add and retry reconcile without duplicate. |
| T11 | Metadata selection does not download unintended payload before consent; only permitted selected types are wanted. |
| T12 | Hard-link import preserves seeding; virtual import works without hard links; repeat import is idempotent. |
| T13 | Shared requests and duplicate hashes cannot stop another user or reveal inaccessible destination metadata. |
| T14 | Quota reservation race, disk-full, read-only/missing mount fail safely without auto-deleting data. |
| T15 | All cross-user/grant combinations on files, images, thumbnails, subtitles, downloads and sessions deny correctly. |
| T16 | Path traversal, symlink swap, malformed metainfo, duplicate/case/Unicode paths and >4 GiB offsets are safe. |
| T17 | Source SSRF/redirect/rebinding/webseed/tracker/explicit-peer policy blocks prohibited targets. |
| T18 | Login/refresh replay/disable/logout and playback revoke/expiry work, including while an HTTP stream is open. |
| T19 | Playback ticket still permits later legitimate range requests during a long movie; never grants a second file. |
| T20 | External launch injection/no-handler/preferred-player-uninstalled cases handled; no credentials in logs. |
| T21 | Prowlarr partial failures, unsupported recent feed, unknown/negative counts and duplicate releases normalize correctly. |
| T22 | All TV controls reachable with D-pad/Select/Back, stable focus after updates and returning from players. |
| T23 | Mobile lifecycle/audio focus/rotation/document picker and desktop window/fullscreen/Wayland paths verified. |
| T24 | Photos honor EXIF orientation; large/decompression-bomb images bounded; slideshow/zoom tested. |
| T25 | Migrations and full-stack restore return accounts/grants/requests/keys and resumed downloads consistently. |
| T26 | Pi targets in specification 08 measured; no corruption/timeout under concurrent load and soak. |
| T27 | amd64/arm64 images run natively, clean install succeeds, secrets and service administration stay private. |
| T28 | Contract/client generation deterministic, API schema validation passes, no hand-edited generated DTOs. |
| T29 | Configuration/reset/preferences persist correctly and cannot bypass role limits. |
| T30 | License/SBOM/native binary provenance, reproducible artifact checksums and upgrade rollback report complete. |
| T31 | TV pairing codes expire/replay safely and authorize only the approving account. |
| T32 | Kill between upstream command and DB commit, between hard link and import commit, and during removal; reconciliation repairs without data loss. |

## Fixture production

Create synthetic color/test-pattern videos and audio through fixed FFmpeg commands, plus generated pictures, subtitle tracks and Unicode filenames. Record hashes, codec/container, duration, size and rights/provenance. Generate v1, v2 and hybrid `.torrent` files with a tool invoking a pinned torrent library; the fixture generator is test tooling, not a second production engine.

Use a controlled seeder on a private Docker test network with no public trackers/DHT for the fixture. Introduce rate caps, missing-piece schedules, start/stop and connection drops deterministically. For exact boundary tests a deterministic fake reader is useful, but it never replaces the real engine test. Test sparse and normal allocation separately.

Do not make a CI run dependent on indexer credentials, public torrent seed counts, arbitrary mirrors or antimalware bypass. Disable external networking for unit/component tests where possible.

## CI design

Provider-neutral scripts are the primary interface. Supply GitHub Actions as the reference CI implementation, but do not require the user's code to be hosted there or create a repository without authorization.

On pull requests: server build/analyzers, unit/component tests, contract lint/generation diff, Flutter analyze/widget tests, secret scan and dependency/license checks. No deployment to UAT or production; isolated job services and temporary data only.

On integration runs: actual Compose stack with seeder/indexer fixtures, API/streaming tests, migrations/import/recovery. On scheduled/manual or release-candidate runs: Android TV emulator, Windows and macOS native build/test, native ARM runner and hardware profiles. Keep nightly suggestions as repository CI configuration, not a claim that this conversation has scheduled an automation.

Release candidate: full required suites, Pi benchmark, real TV test, full-stack backup/restore, security review, image scan, SBOM, checksums and notes. Public distribution requires explicit human authorization and signing access.

## Coverage and review standards

Critical arithmetic/permission/ticket/state-transition modules require branch-focused tests, including negative paths; target >=90% branch coverage there where tooling supports it. Overall percentage does not substitute for the named scenarios. No arbitrary coverage gate that forces meaningless assertions over generated code.

Independent reviewer examines protocol/availability, storage/auth and native launch boundaries. Review findings include severity, path/symbol, reproduction and expected fix. Zero unresolved critical/high security or corruption findings for a release. Clearly documented low-impact limitations may remain only if outside the baseline acceptance contract.

## Performance measurement protocol

Record Pi model/RAM, OS/kernel, architecture, cooling/throttling, filesystem, storage model/connection, network link/throughput, image digests, fixture bitrate and running services. Collect server and per-container CPU/RSS/working-set/page-cache, disk latency/throughput and network counters. Repeat cold/warm scenarios and report medians/p95 where meaningful.

A test with an overpowered desktop is not a Pi test. Emulation proves packaging/ABI smoke only, not real-time performance. Run the concurrent workload for 30 minutes and a longer session/restart soak where resources permit; record actual duration. Disable no safety mechanism merely to hit a throughput target.

## Definition of release readiness

Every in-scope R01–R26 requirement maps to completed code and tests; M00–M11 integration gates are satisfied; available platforms have genuine evidence; hardware/credential blockers are listed without being relabeled as passes. The user gets installation instructions, native packages, security/format limits, first-run flow, upgrade/rollback, backups and a complete third-party notices/source manifest. No stubbed UI buttons, TODOs on critical paths, fake API results or “coming soon” screens for required features.
