# M02 — Accounts, sessions, grants and contained storage

Code implemented; local Linux amd64 verification is recorded below. No production data, real indexer credentials or public deployment were used. Native Pi/ARM64 access is pending. Windows/macOS are unavailable and Android TV remains reserved for final acceptance.

## Implementation

ASP.NET framework password hashing, one-time bootstrap (30-minute code in config file mode0600), access tokens (32 random bytes/15 minutes), refresh rotation (30-day absolute session expiry), hashed credentials, replay revocation, logout/own-session/password/reset/disable effects, five-minute TV pairing bound to the approving session, generic login failures, bounded account/IP limits (5/10 per minute), restricted secret key and standard AES-GCM setting envelope. Authentication denies expired/revoked/disabled accounts at each request. Central policy reloads live library/user/grant data; separate access and session validity seams preserve later media-ticket semantics. Bounded housekeeping prunes expired credentials/pairings and retained audits.

Administration implements users, mounted-root selection, libraries, grants, optimistic versions, safe idempotency digests and audit events. Last enabled administrator is protected under a single writer gate. User deletion disables accounts and preserves ownership/history. Download/manage imply read; read-only roots deny writes. Inaccessible library/session IDs return neutral404; members omit rootPath. No raw credentials enter API/audit values.

Linux containment uses openat2 BENEATH/NO_SYMLINKS and descriptor identities. Derived handles retain their original boundary, registered library roots retain original inode scope, and file mutations run on fresh bounded OS threads under intersected Landlock data/library policies. Operation-specific rights reject symlink/directory substitutions. No thread-pool thread is permanently restricted. Filesystem volume information comes from the mounted descriptor, not the host slash volume.

## Evidence

Commands ran with project-local DOTNET_CLI_HOME/NUGET_PACKAGES; socket/Docker tests required the host execution allowance. Logs are in `logs/`, and full structured command records remain in `artifacts/dev/`.

- `python tools/dev.py build`: exit0, zero warnings/errors (20261012T090818.188268Z).
- `python tools/dev.py test --suite unit`: exit0; server unit tests, 10,043 prototype reader assertions, runner/scanner and fixture/API probe tests (20261012T091901.126499Z).
- `python tools/dev.py test --suite identity`: exit0, 32 SQLite-backed cases; final housekeeping run `/tmp/briani-m02-final-housekeeping-tests.log` (20261012T091908.414956Z), including bootstrap race, cross-user grants, expiry/replay/revocation, pairing, symlink swaps, retained directory moves, root replacement and >4GiB sparse descriptor inspection.
- `python tools/dev.py test --suite integration`: exit0,2 existing SQLite/migration/readiness/error regressions (20261012T091905.808170Z).
- Server contract project: exit0. `python tools/contracts/generate.py --check`: exit0; pinned generator/serializers deterministic.
- Local Docker build and isolated Compose smoke: exit0 (20261012T091904.797711Z), actual HTTP readiness/schema check, non-root service, loopback-only API. Test project and volumes cleaned.
- Flutter analyze/test after remote HTTP trust fix: exit0,6 tests; separate M01 artifacts.

These are phase-specific portions of T15/T16/T18/T31. Media/image/subtitle/download and open playback-ticket coverage is extended in M03–M06; those broader acceptance IDs are not yet certified.

## Independent review and fixes

Sol high read-only reviewer independently reproduced stale role/library decisions, pairing surviving session revocation, retained child mutations outside root, file-to-directory rename swaps, and replacement library root reads. Each finding was fixed and covered by regressions. Final direct-source review denies all three filesystem exploits; pairing proof returns approval204, password change204, old credential401 and pairing exchange401. See `filesystem-review.txt` and `pairing-review.txt`. No remaining concrete critical finding in reviewed paths.

## Platform requirements and limits

This server ships only through Docker. Containment currently requires Linux amd64/ARM64 with openat2 and enabled Landlock ABI>=2 plus erratum3 (disconnected bind-mount directory fix); unsupported systems fail closed, never bypass containment. Actual host: x86_64 kernel7.2.9-zen1-1-zen, Landlock ABI10/errata15, SDK10.0.112/runtime10.0.12. Native ARM64/Pi and distro/kernel matrix remain unverified; this is no claim of every Linux kernel supporting these security APIs. Housekeeping has a fake-clock SQLite regression; the setup CLI now emits only the43-character code and writes mode0600. Pairing UI device confirmation is wired in later native-client milestones.

## Handoff

M03 can use the authoritative contained filesystem and permission services. It must add media identity, worker jobs and ticket scopes without reopening raw paths or bypassing containment. Active-reader/download guards on library removal are extended as those entities arrive. No release certification or complete-application claim is made.
