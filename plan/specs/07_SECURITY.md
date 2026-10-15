# 07 — Security, trust and permissions

## Threat model

Treat torrent metadata, torrent contents, indexer fields/URLs, filenames, image/video parsers, clients and external-player arguments as untrusted. The host administrator is trusted; an ordinary Briani user must not escape their library, consume unlimited resources, obtain source passkeys, affect another user's download, or turn the server into an arbitrary network proxy.

Main protections cover unauthorized file access, credential leakage, SSRF, path traversal/symlinks, malicious metainfo/decoder inputs, resource exhaustion and destructive operations. This is a home/self-hosted service, not a security reason to omit authorization.

## Authentication

Use the framework PasswordHasher implementation, not custom cryptography. Passwords have no length or content rules (owner decision, 2026-10-16); account creation and password changes require a matching confirmation checked server-side; no logging. Rate limit login by account and source IP with safe proxy handling. Failed login messages do not reveal whether an account exists. Persist user disable and revoke effects.

Opaque access tokens: 32 random bytes, hashed at rest, 15-minute lifetime. Refresh tokens: independent 32 random bytes, hashed, 30-day absolute lifetime, rotated on use with reuse detection. Tokens are associated with named device sessions; user can revoke one or all. Change/reset password revokes prior sessions. Use TLS or a trusted VPN; “LAN” does not make credentials cryptographically protected.

Bootstrap uses a generated one-time secret mounted from a restricted file, displayed explicitly by a setup command rather than repeatedly dumped in general logs. It works only before the first administrator exists, expires after 30 minutes per generated code, and is protected by a database transaction. Container CLI can regenerate it; do not expose an unauthenticated reset endpoint.

TV pairing uses separate random device secret and eight-character human code, five-minute expiry, limited polling and authenticated approval. Short codes never directly authorize media access. Prevent concurrent approvals/replay and show the account/device being linked.

Client refresh and access tokens use OS-backed secret storage. Linux Secret Service/keyring unavailability produces an understandable storage error with session-only login available; do not fall back to plaintext silently. Do not modify a user's KDE/GNOME keyring configuration automatically.

## Authorization matrix

| Operation | Requirement |
|---|---|
| Browse/search library, thumbnail/image/subtitle, create playback session | Read grant on target library |
| Start torrent/file selection | Download grant on destination + quota; read required |
| Discovery queries | Download grant on at least one library |
| Pause/resume/retry unshared request | Owner still authorized, manager, or administrator |
| Shared download lifecycle | Manager/administrator; one attached user cannot stop others |
| Rename/move/trash visible media | Manage grant; read-only and active-reader constraints |
| Recheck/delete payload/permanent delete | Manager/admin, explicit confirmation, safe lifecycle |
| Manage users, roots, providers, global limits | Administrator only |
| Approve TV pairing | Logged-in user approving their own new device |
| View own progress/preferences/sessions | Matching authenticated user only |

Return generic not-found for inaccessible object IDs where disclosure is harmful. Never rely on hidden UI buttons. Re-evaluate grants when serving/renewing playback, not only when listing a file.

## Contained storage access

Clients use media/library/file IDs, not arbitrary paths. Administrator root selection is restricted to pre-mounted `/data` paths and cannot select `/`, `/config`, another service state directory, nested/overlapping library roots or symlink roots.

Implement one Linux containment helper using descriptor-relative resolution (`openat2`/equivalent safe no-symlink traversal) with beneath/no-symlink semantics. Verify the actual Linux kernel/toolchain support in M02. A mere string prefix, `Path.GetFullPath` check followed by an unrelated open, or `..` replacement is inadequate for symlink and TOCTOU safety. A component-by-component no-follow fallback is acceptable only with race tests and identical containment guarantees.

Reject torrent symlinks and special/device files. Reject absolute, traversal, NUL/control and ambiguous normalized paths. File create/rename/link/delete uses the same containment layer. Never follow staging/trash links recursively. Filenames are display data, not code, shell arguments, URLs or trusted HTML.

Use separate state mounts per service. Prowlarr has no media mount. qBittorrent and Briani receive only necessary storage. A shared host UID/GID for media access is an operations choice, not application authorization. No root filesystem or Docker socket mount. Do not run privileged containers to avoid a permission error.

## SSRF and upstream URL control

Briani reaches only its configured Prowlarr/qBittorrent origins with administrative credentials. Those origins are administrator-controlled infrastructure values, validated and separated from content URLs. Indexer-returned source URLs are not trusted because they came through Prowlarr.

Source resolution accepts only a stored result reference or validated magnet/metainfo. Limit schemes, ports, redirects, response size and time. Resolve/revalidate each redirect destination and protect against DNS rebinding, loopback, link-local/cloud metadata, multicast and unauthorized private ranges. Preserve an explicit allowlist for the known internal Prowlarr service; it is not a blanket allowlist for arbitrary 172/192 addresses. Tests include Prowlarr proxy links that redirect to magnets and private-indexer URLs.

Network policy must consider qBittorrent itself: torrent webseeds, trackers and explicit peers can target internal addresses even when Briani's HttpClient is protected. Disable webseed fetching by default unless sanitized against policy; strip/reject unsafe tracker/webseed/explicit-peer fields without changing the metainfo `info` hash, and restrict engine egress to sensitive host/LAN/cloud-metadata destinations through a documented container/host firewall policy. Allow designated controlled fixture peers only in the test profile. Never claim app-only URL checks isolate the torrent daemon.

Private tracker passkeys are secrets. Do not synthesize a public magnet that loses private announce information. Do not add public trackers to private torrents or override private swarm behavior.

## Process and parser safety

Invoke FFprobe/FFmpeg/player executables with argument arrays, fixed binary paths and shell execution off. Server probes operate on contained local files only; disallow network protocols in probe inputs as applicable. Add timeouts, output limits, CPU/memory/concurrency bounds, and kill/reap process trees on cancellation. No automatic execution/extraction of archives or sidecar scripts.

Images have decoded-pixel limits and thumbnail resource caps; no SVG/HTML execution. Media parser dependencies are patched regularly. The app cannot promise that an allowlisted extension proves a file harmless; validate actual content and maintain parser security updates.

## Media ticket design

Specification 05 defines lifespan and range reuse. Tokens are random and file-specific, not account tokens in query strings. Redact path/query ticket material in Briani, proxy, client and crash logs. Disable referrer leakage and caching. Include revocation, grant changes, user disable and hard expiry tests during open streams.

External players and OS process lists may expose their playback URL locally. The short scope, revocability and bounded lifetime mitigate this, but external playback is not a secrecy guarantee against the same OS user. Display a warning on Copy URL. Never include indexer passkeys or login credentials.

## Container/network posture

Default API bind is loopback unless installer explicitly selects a LAN/VPN address. qBittorrent/Prowlarr administrative ports stay unpublished or localhost-only. Torrent peer port TCP/UDP is a separate transport and may be published according to administrator policy; it is not the Web UI port. No automatic router/UPnP forwarding. Provide egress-isolation instructions and test them; bridge networks by themselves are not a firewall against the LAN.

Use non-root Briani, minimal filesystem writes, no-new-privileges and capability dropping where compatible. Upstream container initialization may have its own UID/GID model: follow and test it rather than applying unsafe blanket security flags that break startup. Image digests, scan results, SBOM and update/rollback procedures are release requirements.

## Destructive and privileged actions

Differentiate remove request, stop transfer, hide/trash library entry, delete payload and permanent delete. Display affected files, size and seeding consequences before confirmation. Require a current authorization check and version/operation token so stale dialogs do not delete a changed object. Active readers cause a conflict unless a manager explicitly confirms stop-and-delete.

No agent may publish a release, install a real private indexer, upload user files, expose ports on the user's router, obtain paid signing credentials, or alter production content merely because a milestone says to test. Use fixtures/test instances and leave explicit evidence blockers for missing authorized access.

## Security acceptance

Tests must include all role/grant permutations, cross-user resource IDs, revoked/expired media tickets, symlink races, malicious metainfo, archive/EXE filtering, SSRF redirects/rebinding, external launch injection, concurrent destructive operations, log redaction, quota race/exhaustion and engine restart/recheck during reads. Independent high-reasoning review is required for auth, path containment and progressive byte safety.
