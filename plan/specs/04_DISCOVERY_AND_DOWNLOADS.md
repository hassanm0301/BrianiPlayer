# 04 — Discovery, torrent control and imports

## Discovery scope

Use Prowlarr's API as the sole supported indexer gateway. No Stremio compatibility, Torrentio, site-specific scraping, Jackett implementation, movie catalog API, qBittorrent search-plugin subsystem or Usenet. The administrator chooses supported sources in Prowlarr. No default piracy-site list is shipped.

Prowlarr separates seeders and leechers in its normalized release representation; provider data can still be missing or inconsistent. Its upstream search responses/proxy URLs are implementation details that must be verified against the pinned version. See S04–S06.

### Client views

**Latest:** recently reported torrent uploads from sources that actually support a recent/empty-query feed. Sources lacking it are marked unsupported for this tab, while remaining available for search.

**Most seeded:** sort the current fetched result set by seeders descending, nulls last, then publication time and stable result ID. Label “Among fetched results”; do not claim a complete global ranking.

**Search:** explicit submit by default, not an upstream request per keystroke. Filter torrent-only results, enabled indexers, categories, minimum seeders, size and age. Sort by title, size, seeders, leechers, total peers or publication time. Preserve unknown values as null and show an em dash.

Default page size 50, maximum 200. Fetch a bounded snapshot and paginate it locally for consistent ordering. Cap at 500 results per query and expose `truncated=true`. For fresh exhaustive search users refine filters; the UI must not invent more pages than the snapshot contains.

### Normalized result

`id, snapshotId, title, sizeBytes?, publishedAt?, observedAt, sourceId, sourceName, categoryIds[], seeders?, leechers?, peersTotal?, sourceKind, canDownload, stale, warnings[]`.

Total peers may be derived as seeders+leechers only when both counts are nonnegative. Do not display leechers as “all peers.” In transfer details distinguish reported swarm counts from currently connected peers. Never sum seeder counts across duplicate indexer entries.

Deduplicate by verified compatible infohash when available, preserving source alternatives. Otherwise use source ID + source GUID; title+size is only a display grouping hint, not a safe torrent identity. Private/passkey sources remain distinct resolution options. A hidden provider URL is stored server-side with secret protection and expiry.

### Requests, caching and source health

Default upstream search timeout 20 seconds per source, two concurrent source queries, one active user search. Cache identical permission-equivalent queries for five minutes; recent listings refresh no more often than every 15 minutes while discovery is in use. Keep stale results up to 24 hours with an age marker, but re-resolve before adding a torrent.

Do not assume Prowlarr's API reports each provider failure cleanly. Query bounded per-indexer requests where necessary to distinguish timeouts from genuine zero results. Expose a provider health collection and aggregate state `fresh`, `partial`, `stale`, or `unavailable`. Retry with jitter/backoff; no anti-bot bypass or endless refresh loop.

`resultId` is an opaque server lookup. The download action never accepts a browser/client-supplied Prowlarr URL. Expired source entries are re-resolved once using original source identity; if absent, return `source_expired` and ask the user to refresh results through a normal UI action.

Prowlarr may return proxied magnet/download references, not a literal magnet in every “magnet” field. Resolve through the configured service with bounded redirects and allowed destinations. Preserve private tracker credentials server-side. Do not invoke Prowlarr's generic “grab/send to download client” action: Briani must control the destination and permissions itself.

## Supported input types

1. Opaque discovery result ID.
2. Magnet URI with a supported BitTorrent infohash, bounded length, allowed tracker/webseed fields and no arbitrary executable/protocol handler.
3. Uploaded `.torrent` bytes (maximum 16 MiB). Decode with bounded recursion/file-count/string sizes and preserve the original `info` bytes for identity validation.

Torrent v1, v2 and hybrid formats need explicit metadata mappings and test fixtures; never treat every identity as one 40-character SHA-1 hash. Reject symlinks, traversal paths, absolute paths, device names, ambiguous duplicate paths and unsupported metainfo versions. Media-only file selection is enforced after metadata arrives. Archives, installers and scripts are not unpacked or executed.

## qBittorrent adapter contract

Pin a stable qBittorrent 5.x/libtorrent 2.x image tested in M00. Observe application and Web API versions on startup. The adapter must exercise adding, stopping/starting, file listing/priorities, sequential state, fixed beginning/end priority, status, piece state, metadata export, per-torrent limits, tags and removal. Do not assume a master-branch API exists in the selected stable image.

Contract tests store sanitized real responses from that pinned image. Use an authenticated HttpClient with one cookie/session refresh path and request timeouts. Keep host/CSRF protections; configure trusted service names correctly rather than disabling protections wholesale.

An upstream 200 response is not always proof that the requested mutation happened. Reconcile actual torrent state. In particular, setting a boolean via a toggle needs observe/compare/act/verify under a per-torrent lock. Never retry a toggle blindly after a timeout.

### Metadata-first workflow

For `.torrent` uploads, inspect metadata before adding in a stopped state. For magnets, use the pinned engine's metadata-only capability where present; otherwise use its tested stop-on-metadata path. Validate that unwanted payload does not begin downloading before file selection. Do not assume a permanently stopped magnet will fetch metadata.

The engine-specific metadata API/flag must be recorded by M00 and represented by `FetchMetadataAsync`, not spread throughout the app. If neither safe capability exists in a candidate image, reject that candidate or use the small compatibility patch specified in decision D12. Do not download the entire torrent while showing a file-selection dialog.

A metadata request expires after 120 seconds by default with a recoverable stalled state. It may be retried explicitly; no automatic unlimited loop. Abort/expiry removes only Briani's provisional metadata task, not an unrelated torrent with the same hash.

After selection, calculate actual admission/reservation, create selected file records, set all other files to ignored, verify priorities, enable sequential mode and first/last assist, then start. Save path is derived solely from library ID and job UUID. Disable automatic torrent management, auto-move-on-completion and hidden temporary path changes for the managed instance unless exact behavior is integrated and tested.

## Sequential behavior

Sequential order is approximate piece order within the engine's selected-file set. It is not a promise that the user can immediately open the third episode in a season pack. Selecting a later video may require waiting for earlier selected videos. The user can choose only one video initially and add others later, with a confirmation explaining the effect.

Changing normal file priority is an explicit download-management operation; a seek or playback request never changes priorities. Default file priority is normal, unsupported file types ignored. Fixed first/last-piece assistance is enabled to make common media metadata accessible; it is not a dynamic seek scheduler.

## User actions and permissions

| Action | Who | Constraints |
|---|---|---|
| Add/select files | Contributor for destination library | Within quota; type/path validation; selection changes invalidate playback availability. |
| Pause/resume | Owner of unshared job, library manager, administrator | Pausing keeps playable downloaded bytes; playback may buffer. |
| Queue order/rate limits/tags | Owner of unshared job or manager | Values clamped to server policy; labels do not become filesystem paths. |
| Reannounce | Same as pause | Rate limited; no attempt to evade tracker rules. |
| Recheck | Manager/admin | Confirmation and stop active streams first; generation invalidated. |
| Remove request | Request owner | Does not delete data or other users' requests by default. |
| Delete payload | Manager/admin | Explicit confirmation; no active readers; preserve requested visible library links unless separately confirmed. |
| Change global connection/seeding limits | Administrator | Audited validated allowlist; no arbitrary engine configuration proxy. |

Expose rate limits, active queue count, ratio/time-based seeding limits, file priorities, tracker summary and retry/error detail. Default public-source seeding policy has no automatic ratio/time stop, but bounded active seed jobs and bandwidth; administrator can configure limits. Private-source rules may require different behavior and must not be silently overridden. No automatic “delete when ratio reached.”

## Import algorithm

A selected file's completion is determined independently of unselected torrent payload. Verify file identity and expected length, allow only supported media/sidecar types, probe with bounded resources, and create the visible library entry according to specification 02. Keep the managed payload stable until explicit lifecycle cleanup.

No content filename is trusted as a directory escape. Construct a safe display directory from a sanitized title plus stable short ID; do not overwrite pre-existing content. Preserve original relative folder relationships beneath that directory when safe. Sidecar subtitles remain linked with their video but are not a top-level “media type.”

Scanning excludes staging/trash. Downloads appear virtually while active, then point to the imported entry without losing progress history. Perform a single media ID transition/reconciliation, not two unrelated entries in Continue watching.

## Diagnostics

Persist normalized phase transitions and safe upstream errors. Expose last successful engine/indexer contact, versions, disk availability and queue counts to administrators. Do not leak tracker passkeys, peer IP lists, full upstream response bodies or private source URLs in general logs. Periodically reconcile missing upstream jobs, orphan managed files and invalid selected-file states; present destructive cleanup as an explicit administrative operation.
