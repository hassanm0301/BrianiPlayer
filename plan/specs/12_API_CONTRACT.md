# 12 — API and event contract

The machine-readable initial v1 interface is `contracts/openapi.yaml` (relative to package root). Copy it to repository `contracts/` in M01 and make it the implementation contract. Keep this narrative aligned with it. Do not independently invent a second shape in Flutter or expose upstream APIs directly.

## Conventions

Prefix control API with `/api/v1`. JSON uses camelCase, UUID strings, UTC RFC3339 timestamps, integer byte counts and playback milliseconds. Unknowns are null, not fabricated zeros. APIs use opaque media/file/result IDs; only administrator root configuration accepts a contained root path.

Normal calls use `Authorization: Bearer <access-token>`. Binary playback uses the path-scoped random ticket defined in specification 05. HTTPS is mandatory outside a trusted LAN/VPN arrangement; a remote external player must reach and trust the selected origin.

Mutating create/download/job requests accept `Idempotency-Key` (UUID recommended). Store the request body hash; reuse with a different body returns 409. Updates carry `version` for optimistic concurrency. Successful asynchronous commands return 202 plus an operation/job/request ID and a status endpoint. Do not hold an HTTP request until a torrent completes.

Errors are `application/problem+json` with `type`, `title`, `status`, stable `code`, safe `detail`, `traceId`, optional `fieldErrors`, `retryAfterSeconds`, and no secrets/stack trace. Codes include `forbidden`, `not_found`, `version_conflict`, `quota_exceeded`, `disk_unavailable`, `source_expired`, `dependency_unavailable`, `metadata_pending`, `layout_unverified`, `waiting_for_data`, `session_expired`, `range_invalid`, `active_reader_conflict` and `torrent_already_managed`. `title` and `detail` are human-readable messages written by the server (catalog in `ErrorMessages.cs`, with specific details at validation sites); clients display `detail` (falling back to `title`) verbatim and never translate `code` into their own text (owner decision, 2026-10-16). Page `warnings`, download `errorDetail`, and operation/job `error` problems follow the same rule. Clients write their own text only when no server reply exists (unreachable server, certificate failure) or input cannot be encoded (non-numeric text in a number field).

## Endpoint groups

- Bootstrap/server capabilities, login/refresh/logout/password, own identity/sessions and TV device pairing.
- Administrator users and library grants; library roots and scans.
- Folder entries, media detail/image/thumbnail/sidecar, progress, continue watching, supported rename/move/trash operations.
- Discovery providers, asynchronous query creation and paginated snapshot retrieval.
- Torrent metainfo upload, create/list/detail/download files, selection, curated settings and lifecycle actions.
- Playback session creation/status/revocation, media byte GET/HEAD and approved subtitle delivery.
- User preferences, server settings, integration health/setup tests, administrative audit/storage, maintenance jobs and operation status.
- Authenticated event stream and process readiness/liveness.

## Pagination

Use stable snapshot IDs + opaque cursor for discovery; page size 50/max200. Cursors bind query/sort/scope and cannot override user permissions. Library listing uses folder ID (null means root), query, kind, sort/order and an opaque cursor. Return `items`, `nextCursor`, `snapshotId?`, `totalKnown?`, `truncated` and `warnings`. Counts refer to the accessible/current snapshot, not the whole internet.

## Download API workflow

`POST /downloads` resolves a source and returns a request in a metadata/selection state. Source is a tagged choice of `discoveryResult`, `magnet`, or `torrentUpload` with exactly the corresponding value. `.torrent` uploads have a separate authenticated multipart endpoint and a short-lived user-scoped upload ID.

`GET /downloads/{id}/files` supplies opaque file IDs and metadata. `PUT /downloads/{id}/selection` commits selected IDs/priorities and optionally starts after admission. `POST /downloads/{id}/actions` accepts a bounded action enum and confirmation fields. Settings use typed curated fields, never an upstream arbitrary JSON blob. Cross-library duplicate behavior follows specification 03.

## Playback API workflow

`POST /playback/sessions` accepts `{target:{kind,id}, mode, initialPositionMs}` with target kind `media` or `downloadFile`. It validates library access and creates a scoped ticket. Response supplies session ID, stream URL, expiry/activation details, availability state, generation, and sidecar descriptors if available.

A session can be created while buffering, but a valid logical file length/layout is required before a usable byte URL is advertised. When metadata is not ready, return a typed pending response rather than a made-up length. Session-status endpoint reports later readiness. The player opens the supplied URL; it never constructs an engine hash/path URL on its own.

`GET/HEAD /stream/{ticket}/{fileName}` implements specification 05. `fileName` is a presentation suffix checked against the ticket target, not an alternate file selector. Sidecar URLs receive separate tickets or equally strict per-sidecar scopes. Ticket recreation/expiry cannot leak normal authentication tokens into logs.

## Events

`GET /api/v1/events` uses SSE with normal access-token authentication through a client library that supports headers. Events are hints, not the database of record. Event types:

```text
download.updated {id, version, state, progress, downloadBps, uploadBps}
media.changed    {libraryId, mediaId?, reason, version}
playback.state  {sessionId, state, generation, contiguousBytes, totalBytes?}
job.updated     {jobId, state, progress?}
service.health  {service, status}      # admin only
permissions.changed {version}
snapshot.required {}
```

Envelope: `id`, `type`, `occurredAt`, `payload`. Send a keepalive every 15 seconds. Filter at source per current user permissions; do not broadcast private library names/IDs to all clients. Coalesce progress to at most one visible update per second per active download. Cap connection/event buffers; a slow consumer receives `snapshot.required` and reconnects rather than growing memory indefinitely.

Do not promise persisted event replay. On reconnect/access-token refresh, fetch snapshots; a Last-Event-ID may help within a bounded in-memory window but is not a durability contract. Poll every five seconds as fallback while relevant screens are visible, back off in background.

## Contract validation and evolution

Schemas in the YAML describe wire fields; behavioral validation, permissions and lifecycle rules remain mandatory even where OpenAPI cannot express them. Add golden request/response fixtures for edge states. Generate the Dart client deterministically with a pinned generator, never edit generated output by hand. Server contract tests compare route/schema behavior; CI fails on unreviewed contract drift.

Within v1, prefer additive nullable fields and stable error codes. Breaking changes require a new API major or a coordinated pre-release contract update recorded by the parent owner. Workers may propose corrections but only the parent/contract owner merges them. Do not loosen validation to accommodate a worker that ignored the specification.
