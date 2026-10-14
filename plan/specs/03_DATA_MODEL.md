# 03 — Persistence and state machines

## Database conventions

Use SQLite on a local persistent filesystem, WAL mode, foreign keys enabled, a 5-second busy timeout, and short transactions. Use `synchronous=FULL` for configuration/job durability; optimize only after measured tests. One Briani process owns writes. WAL is not supported over a network filesystem; see S12.

Store UTC timestamps, integer byte counts, integer milliseconds for playback, and normalized enums as stable strings. IDs are server-generated UUIDs represented as strings on the wire. Use nullable values for genuinely unknown size/duration/counts. No binary media or per-piece updates in SQLite. Store credentials only as hashes or encrypted secrets as specified in security.

Use EF Core migrations, explicit indexes, optimistic `version` integers on mutable records, and unique constraints for logical uniqueness. Filesystem operations are not magically atomic with a database transaction: use durable jobs and reconcile after a crash.

## Tables

| Table | Required fields and important constraints |
|---|---|
| `users` | id, username, normalized_username UNIQUE, display_name, password_hash, role, enabled, must_change_password, created_at, updated_at, version. Username 3–64 ASCII letters/digits/`._-`; display name may be Unicode. |
| `auth_sessions` | id, user_id FK, device_id, device_name, platform, refresh_hash UNIQUE, refresh_expires_at, created_at, last_seen_at, revoked_at, refresh_generation. |
| `access_tokens` | token_hash PK, session_id FK, expires_at; delete expired tokens. Never persist raw access tokens. |
| `refresh_replays` | consumed_hash PK, session_id, expires_at; detects replay of a rotated refresh credential and revokes that session. |
| `libraries` | id, name, description, root_path, root_identity, enabled, online, read_only, managed, scan_interval_seconds nullable, created_at, version. Canonical roots cannot overlap; no symlinks. |
| `library_grants` | user_id, library_id, can_read, can_download, can_manage, quota_bytes nullable; composite PK. Download/manage imply read. |
| `media_items` | id, library_id, parent_relative_path, relative_path, display_name, kind, extension, MIME, size_bytes, mtime_ns, file_identity, source_kind, download_file_id nullable, lifecycle, missing_since nullable, created_at, indexed_at, version. Unique library + canonical relative path for physical entries. |
| `media_metadata` | media_item_id PK/FK, duration_ms, width, height, rotation, video_codec, audio_summary_json, subtitle_summary_json, container, probe_version, probe_status, probe_error_code, content_generation. Bounded JSON only. |
| `thumbnail_entries` | media_item_id, generation, variant, cache_relative_path, bytes, created_at, last_accessed_at. Cache may be deleted without losing media. |
| `playback_progress` | user_id + media_item_id PK, position_ms, duration_ms nullable, completed, updated_at, client_event_id, version. Never infer external position from bytes served. |
| `user_preferences` | user_id PK, validated settings_json, version. Display/player preferences without server secrets. |
| `device_preferences` (client-local only) | Local user/server/device key, validated settings_json, version. This is not a server EF table/API; executable paths and window/decoder/cache preferences never synchronize to the server. |
| `device_pairings` | id, device_secret_hash UNIQUE, human_code_hash UNIQUE while active, device_name, expires_at, approved_by nullable, approved_at nullable, consumed_at nullable, poll timestamps/counters. No plaintext private device secret. |
| `torrent_uploads` | id, owner_id, contained_temporary_path, metainfo_hash, bytes, expires_at, consumed_by_request nullable. Default unclaimed lifetime 30 minutes; bounded cleanup and no payload download. |
| `discovery_snapshots` | id, scope_key, query_signature, fetched_at, expires_at, status, truncated, provider_status_json. |
| `discovery_results` | snapshot_id + result_id PK, source_id, source_guid, title, bytes nullable, published_at nullable, seeders nullable, leechers nullable, peers_total nullable, infohash_v1/v2 nullable, category_ids_json, encrypted_resolution_json, observed_at. No public source passkeys. |
| `download_requests` | id, owner_id, library_id, torrent_job_id nullable, source_kind, source_ref, state, error_code nullable, selected_bytes nullable, reserved_bytes, created_at, updated_at, version, idempotency_key. |
| `torrent_jobs` | id, upstream_id UNIQUE, infohash_v1 nullable, infohash_v2 nullable, destination_library_id, managed_path, upstream_generation, metadata_status, engine_state, sequential, metadata_assist, selected_complete, imported, bytes_downloaded, bytes_uploaded, seeding_policy_json, created_at, updated_at. Hash identities are not interchangeable strings. |
| `download_files` | id, torrent_job_id, upstream_file_index, metadata_file_index, relative_path, size_bytes, torrent_offset, piece_first, piece_last, wanted, file_priority, kind, completed, imported_item_id nullable, version. Unique job+upstream_file_index. |
| `playback_sessions` | id, user_id, auth_session_id, media_item_id/download_file_id target, target_generation, ticket_hash UNIQUE, mode internal/external, created_at, first_use_deadline, absolute_expires_at, activated_at, last_activity_at, revoked_at, initial_position_ms. |
| `jobs` | id, kind, target_id, payload_json, dedup_key UNIQUE while active, state, attempt, next_attempt_at, lease_owner, lease_until, last_error_code, created_at, updated_at. |
| `operations` | id, user_id, kind, target_id, idempotency_key, request_hash, state, result_json, created_at, expires_at. Unique user+kind+idempotency_key. |
| `settings` | key PK, validated value_json, version, updated_at. Secret references, not plaintext credentials. |
| `audit_events` | id, actor_id nullable, action, target_type/id, result, safe_details_json, trace_id, created_at. No raw URLs/tokens or tracker passkeys. |
| `schema_state` | current schema marker/migration information, plan_version, compatibility lock hash. |

Folder identity: `media_items.kind` also permits internal folder/subtitle entries with nullable media-only fields. `Entry.id` is this stable item ID; for video/photo `Media.id` and `Media.entryId` refer to the same item. Folder rows support navigation, not recursive directory mutation. Rename/move/delete in v1 apply to supported media entries; new folders or arbitrary recursive folder operations are not promised.

Add indexes for grant lookups, media parent folders/name search, user progress updated_at, download owner/library/state, jobs due date/state, ticket/token expiry and audit dates. Store filenames verbatim for display but use normalized search keys. Do not install full-text infrastructure until filename search is shown to require it; indexed normalized name prefix plus bounded substring search is sufficient for the 10,000-item target.

## Download and transfer state are different

A request follows:

```text
created -> resolving -> fetching_metadata -> awaiting_selection -> queued
 -> downloading -> selected_files_complete -> importing -> available
```

Side states: `paused`, `stalled`, `failed`, `cancelled`, `removing`. Paused/stalled are not completion or failure. `selected_files_complete` means the user's selected files are complete, not every file in a multi-file torrent. Seeding is a separate upstream state and can coexist with `available`.

The API exposes `sourceState`, `transferState` and `importState` separately, plus a derived `state` for UI convenience. Internal snake_case state labels map explicitly to the camelCase wire enums in OpenAPI; do not persist a UI summary as the only source of truth.

Maintain source state, transfer state and library import state separately. A scan/probe failure does not turn a successful torrent into a failed transfer. A retry resumes the failing phase rather than adding a second torrent.

### One torrent, one active destination

qBittorrent identifies a torrent globally. Do not pretend it can maintain two independent active copies of the same hash for two users/libraries.

For the same normalized torrent in the same library, allow a second authorized user to attach a request only when the selected-file set is compatible; otherwise require an explicit merged selection by a manager. For a different library, return a neutral `torrent_already_managed` conflict without exposing inaccessible library/user details. Cross-library imports/copies are outside the v1 application operation set. An administrator may manage files independently, then rescan, but Briani does not create a second active copy of the same torrent. No hidden cross-library copy endpoint is assumed.

Owners may pause/cancel only their own unshared job. If multiple requests attach, lifecycle/destructive controls require library manage or administrator rights. Removing one attached request must not stop others' download or delete their media.

## Durable command pattern

Within a short database transaction, validate identity/grant/quota, create an operation and desired state, then commit. Call upstream outside the transaction. Re-query upstream and persist the observation. On crash, replay the desired state idempotently. Never keep a transaction open during a torrent HTTP request or a long file read.

Store qBittorrent category/tag ownership, for example category `briani`, tag `briani:<job-id>`. The supplied instance is dedicated to Briani; foreign torrents are visible only in administrator diagnostics and are not automatically adopted or deleted.

## Quotas and disk reservations

The default Pi profile allows two active downloads globally and one per user. Storage has a low-space threshold: reserve the larger of 5 GiB or 5% of the relevant volume. This is a product default, not a torrent-engine guarantee.

Before metadata, reserve a bounded provisional 256 MiB and cap concurrent metadata requests. Before payload starts, reserve remaining selected-file bytes plus conservative boundary-piece overhead. Calculate reservations per actual filesystem identity; two libraries on one volume share capacity. Recompute under a serialized admission lock, including filesystem free space and outstanding reservations. Handle external writers by monitoring free space and pausing new/writing jobs before exhaustion. A configured per-user library quota counts actual/retained bytes plus reservations; downloads with unknown final size cannot bypass it.

Existing media counts against a library capacity view; ownership attribution is not invented for pre-existing files. Default user byte quota is unlimited subject to volume safeguards, unless the administrator sets one. No automatic deletion to recover space.

## Import and deletion transactions

An import job records source identity, expected size and destination before linking. It verifies completion, performs a bounded media probe, creates visible paths without overwrite, links eligible files, records media entries, then marks import complete. Re-running detects the same inode/operation and finishes safely. A crash after linking but before database commit does not produce duplicate files.

For managed payload removal, first reject or revoke active playback according to an explicitly confirmed force flag, stop the upstream torrent, wait for write activity to cease, preserve visible hard links, remove the torrent record with the correct delete policy, and clean orphan staging only when no live references remain. Keep an operation journal so half-completed removal is recoverable.

Library Delete uses a confirmation describing logical removal versus physical data. Default is move visible entry to private trash with a seven-day retention where safe; payload cleanup is a separate advanced action. Virtual entries are removed from the catalog without silently removing the only payload copy. A manager can request permanent deletion explicitly. Never recursively follow symlinks.

## Generation and availability rules

Piece snapshots are in memory, one poll loop per torrent. Any recheck, file selection/layout change, engine restart, relocation or unexpected file identity change invalidates the generation and closes dependent byte readers. After qBittorrent restart or an uncertain storage event, early playback waits until a fresh checked snapshot is trustworthy.

A completed media item may use the ordinary file endpoint only after completion and identity verification. Do not keep an optimistic `completed=true` forever after disk loss or external edits.

## Retention and backups

Prune expired access/playback tokens, discovery snapshots, finished transient jobs and audit entries using configurable bounded batches. Default audit retention is 30 days, discovery snapshots 24 hours, completed job diagnostics seven days. Keep user media and download history until explicit user/admin action.

Back up the database through SQLite's supported backup mechanism or with all relevant services cleanly stopped; include keys and qBittorrent/Prowlarr configuration. Copying only a live WAL-mode main database file is not the backup design. Restore tests are mandatory.
