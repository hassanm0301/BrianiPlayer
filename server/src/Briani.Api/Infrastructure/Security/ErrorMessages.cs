namespace Briani.Api.Infrastructure.Security;

// Every user-visible message originates here (or as an explicit ApiException detail);
// clients display the server's text verbatim and never map codes to their own strings.
public static class ErrorMessages
{
    public const string Fallback = "The request could not be completed. Try again or check the server status.";

    private static readonly Dictionary<string, string> Messages = new(StringComparer.Ordinal)
    {
        // Requests and validation
        ["validation_failed"] = "Some of the values are not valid. Check them and try again.",
        ["invalid_request"] = "The request was not understood. Check the values and try again.",
        ["request_failed"] = "The request could not be completed.",
        ["internal_error"] = "The server ran into an unexpected problem. Try again; if it keeps happening, check the server logs.",
        ["not_found"] = "This item is unavailable or no longer accessible.",
        ["unsupported_operation"] = "This action is not supported.",
        ["invalid_operation"] = "This action is not allowed for this item.",
        ["invalid_pagination"] = "The requested page is not valid. Refresh and try again.",
        ["invalid_cursor"] = "This list changed or the page link expired. Refresh and try again.",
        ["invalid_precondition"] = "The item version sent with the request is not valid. Refresh and try again.",
        ["precondition_failed"] = "This item changed since it was loaded. Refresh and try again.",
        ["version_conflict"] = "This item was changed by someone else. Refresh and try again.",
        ["generation_changed"] = "This item changed while the action was running. Refresh and try again.",
        ["invalid_idempotency_key"] = "The request identifier is not valid. Try again.",
        ["idempotency_conflict"] = "A different request was already sent with the same identifier. Try again.",
        ["idempotency_session_changed"] = "This request was started from another session. Try again.",
        ["idempotency_limit"] = "Too many requests are being tracked. Wait a moment and try again.",
        ["rate_limited"] = "Too many attempts. Wait a moment and try again.",
        ["slow_down"] = "Requests are arriving too quickly. Wait a moment and try again.",
        ["operation_pending"] = "Another change is already in progress for this item. Wait for it to finish.",
        ["operation_limit"] = "Too many changes are in progress. Wait for some to finish and try again.",
        ["operation_failed"] = "The change could not be completed.",
        ["operation_interrupted"] = "The change was interrupted, for example by a server restart. Try again.",
        ["range_invalid"] = "The requested part of the file is not available.",
        ["event_stream_limit"] = "Too many live update connections are open. Close other windows and try again.",
        ["dependency_unavailable"] = "A service the server depends on is unavailable. Try again shortly.",

        // Identity and sessions
        ["login_failed"] = "The username or password is incorrect.",
        ["unauthorized"] = "Sign in to continue.",
        ["session_expired"] = "Your session has ended. Sign in again to continue.",
        ["forbidden"] = "Your account does not have permission for this action.",
        ["password_change_required"] = "Change your password before continuing.",
        ["password_mismatch"] = "The passwords do not match.",
        ["username_taken"] = "That username is already in use. Choose another.",
        ["last_enabled_administrator"] = "At least one enabled administrator must remain.",
        ["bootstrap_unavailable"] = "The setup code is incorrect, expired, or already used. Display a new code on the server and try again.",
        ["pairing_expired"] = "This pairing code has expired. Start pairing again.",
        ["administrator_configuration_invalid"] = "The administrator configuration on the server is not valid.",

        // Settings and preferences
        ["invalid_settings"] = "One of the settings is not valid. Check the values and try again.",
        ["settings_too_large"] = "These settings are too large to save.",
        ["preferences_invalid"] = "Your saved preferences could not be read. Reset them and try again.",
        ["invalid_public_origin"] = "The public address must be a plain http:// or https:// address with no path, query, or credentials.",
        ["invalid_service_origin"] = "The service address must be a plain http:// or https:// address.",
        ["invalid_integration"] = "This integration is not recognised.",
        ["integration_configuration_invalid"] = "The integration settings are not valid.",
        ["integration_credential_file_invalid"] = "The integration credential file on the server is missing or not valid.",
        ["credentials_missing"] = "Credentials for this service have not been configured.",
        ["secret_store_unavailable"] = "The server cannot read its secret store. Check the state folder permissions.",
        ["maintenance_queue_full"] = "Too many maintenance tasks are queued. Wait and try again.",
        ["maintenance_failed"] = "The maintenance task failed. Check the server logs.",
        ["journal_invalid"] = "The server's change journal is damaged. Check the server logs.",

        // Libraries, files and storage
        ["invalid_name"] = "Names cannot be empty, start with a dot, or contain '/' or control characters.",
        ["invalid_path"] = "That path is not valid.",
        ["invalid_library_root"] = "That folder cannot be used as a library.",
        ["library_roots_overlap"] = "Libraries cannot overlap with another library's folder.",
        ["storage_roots_overlap"] = "The data and state folders must not overlap.",
        ["library_in_use"] = "This library is in use. Stop playback and downloads that use it, then try again.",
        ["library_has_downloads"] = "This library still has downloads. Remove them first.",
        ["library_removed"] = "The library was removed.",
        ["destination_exists"] = "An item with that name already exists here.",
        ["path_unavailable"] = "This file or folder is no longer available on the server.",
        ["file_identity_changed"] = "This file changed on disk. Refresh and try again.",
        ["media_changed"] = "This media file changed. Refresh and try again.",
        ["regular_file_required"] = "Only regular files can be used here.",
        ["disk_unavailable"] = "The storage disk is unavailable. Check that it is mounted.",
        ["disk_full"] = "The destination disk does not have enough free space.",
        ["quota_exceeded"] = "The selected files exceed the available space.",
        ["mount_layout_unavailable"] = "The server's storage layout could not be verified. Check the mounted disks.",
        ["layout_unverified"] = "The storage layout has not been verified yet. Try again shortly.",
        ["state_permissions_unavailable"] = "The server cannot secure its state folder permissions.",
        ["containment_unavailable"] = "This server's operating system does not support the required safe file access (openat2).",
        ["hardlink_unavailable"] = "Files cannot be linked across these disks.",
        ["permission_changed"] = "Your access to this library changed. Refresh and try again.",
        ["active_reader_conflict"] = "This file is being played or read. Stop playback and try again.",
        ["catalog_operation_pending"] = "The library is busy with another change. The scan will retry shortly.",
        ["scan_failed"] = "The library scan failed. Check that the folder is available and try again.",
        ["unsupported_format"] = "This file format is not supported.",
        ["thumbnail_unavailable"] = "No thumbnail is available for this item.",
        ["image_unavailable"] = "This image is unavailable.",
        ["subtitle_invalid"] = "This subtitle file is not valid or is too large.",
        ["upload_limit"] = "This upload is too large.",
        ["upload_storage_full"] = "The server does not have enough space for this upload.",
        ["upload_storage_unavailable"] = "The server cannot store uploads right now.",
        ["invalid_upload_form"] = "The upload was not sent correctly. Try again.",

        // Playback
        ["waiting_for_data"] = "This part of the file has not downloaded yet. Playback will continue when it arrives.",
        ["reader_limit"] = "Too many files are being played at once. Stop another playback and try again.",
        ["playback_session_limit"] = "Too many playback sessions are open. Close one and try again.",
        ["invalid_playback_target"] = "This item cannot be played.",
        ["invalid_progress"] = "The playback position is not valid.",
        ["invalid_progress_target"] = "Playback progress cannot be saved for this item.",
        ["invalid_duration"] = "The media duration is not valid.",
        ["metadata_pending"] = "Media details are still being read. Try again shortly.",
        ["metadata_unavailable"] = "Media details are unavailable.",
        ["metadata_limit"] = "Too many media details are being read. Try again shortly.",
        ["metadata_identity_unknown"] = "The media file could not be identified. Refresh and try again.",
        ["metadata_storage_conflict"] = "Media details could not be saved because the file changed.",

        // Discovery
        ["discovery_filter_disabled"] = "This discovery filter is turned off in the server settings.",
        ["discovery_operation_limit"] = "Too many discovery searches are running. Wait and try again.",
        ["discovery_query_active"] = "A discovery search is already running. Wait for it to finish.",
        ["discovery_queue_full"] = "The discovery queue is full. Wait and try again.",
        ["discovery_snapshot_limit"] = "Too many saved discovery results. Wait for older results to expire.",
        ["snapshot_size_limit"] = "The discovery results are too large to keep.",
        ["snapshot_retention_limit"] = "Too many discovery results are stored. Try again later.",
        ["source_expired"] = "This result has expired. Refresh the discovery results and try again.",
        ["source_unavailable"] = "The source for this result is unavailable.",
        ["source_disabled"] = "This indexer is disabled.",
        ["source_changed"] = "This result changed at the indexer. Refresh and try again.",
        ["source_identity_changed"] = "This result now points to a different torrent. Refresh and try again.",
        ["source_timeout"] = "The indexer did not respond in time. Try again.",
        ["source_connection_failed"] = "The server could not connect to the indexer.",
        ["source_payload_too_large"] = "The indexer returned a file that is too large.",
        ["source_redirect_limit"] = "The indexer redirected too many times.",
        ["source_redirect_loop"] = "The indexer link redirects in a loop.",
        ["source_redirect_downgrade"] = "The indexer redirected from a secure to an insecure address, so it was blocked.",
        ["source_resolution_limit"] = "Too many links are being resolved. Try again shortly.",
        ["source_url_rejected"] = "The indexer link is not allowed.",
        ["source_address_rejected"] = "The indexer link points to a blocked network address.",
        ["invalid_source"] = "This result's source is not valid.",

        // Indexer administration
        ["indexer_rejected"] = "Prowlarr did not accept this indexer change.",
        ["indexer_setup_in_prowlarr"] = "This indexer needs settings that only Prowlarr's own page supports.",
        ["invalid_indexer_settings"] = "Some indexer settings are not valid. Check them and try again.",
        ["indexer_profile_missing"] = "Prowlarr has no sync profile to give the indexer. Create one in Prowlarr's own page first.",
        ["indexer_timeout"] = "Prowlarr did not answer in time. Refresh the list to see whether the change was applied.",
        ["prowlarr_credentials_rejected"] = "Prowlarr rejected the API key Briani uses. Check the Prowlarr integration settings.",

        // Downloads and torrents
        ["download_failed"] = "The download failed.",
        ["download_conflict"] = "This download conflicts with an existing one.",
        ["download_limit"] = "The maximum number of downloads has been reached.",
        ["download_not_complete"] = "This download is not complete yet.",
        ["download_operation_limit"] = "Too many download changes are in progress. Wait and try again.",
        ["download_operation_pending"] = "Another change to this download is in progress.",
        ["download_removed"] = "This download was removed.",
        ["invalid_download_action"] = "This action is not available for the download in its current state.",
        ["invalid_download_command"] = "This download command is not valid.",
        ["invalid_download_policy"] = "The download options are not valid.",
        ["invalid_download_settings"] = "The download limits are not valid. Speeds must be 0–1 GiB/s, ratio 0–10000 and seed time 0–525600 minutes.",
        ["invalid_import_intent"] = "The import choice is not valid.",
        ["import_not_ready"] = "This download is not ready to import yet.",
        ["import_destination_conflict"] = "A file already exists where this download would be imported.",
        ["invalid_magnet"] = "This magnet link is not valid.",
        ["unsafe_magnet_field"] = "This magnet link contains a field that is not allowed.",
        ["invalid_metainfo"] = "This torrent file is not valid.",
        ["metainfo_too_many_pieces"] = "This torrent has too many pieces to be handled safely.",
        ["unsafe_metainfo_source"] = "This torrent file came from a source that is not allowed.",
        ["unsafe_tracker"] = "This torrent uses a tracker address that is not allowed.",
        ["torrent_upload_too_large"] = "This torrent file is too large.",
        ["torrent_already_managed"] = "This torrent is already being downloaded.",
        ["torrent_not_owned"] = "This torrent is not managed by Briani.",
        ["invalid_selection"] = "The file selection is not valid.",
        ["unsupported_file_selection"] = "This file selection is not supported.",
        ["payload_identity_unknown"] = "The downloaded files could not be identified.",
        ["stage_identity_unknown"] = "The download staging folder could not be identified.",
        ["metadata_timeout"] = "Torrent details were not received in time. Check the torrent's peers and try again.",
        ["reannounce_limit"] = "Trackers were contacted too recently. Wait and try again.",
        ["engine_unavailable"] = "The download engine (qBittorrent) is unavailable.",
        ["engine_job_missing"] = "The download is missing from the download engine.",
        ["engine_layout_mismatch"] = "The download engine's file layout does not match. Remove and add the download again.",
        ["engine_priority_mismatch"] = "The download engine did not apply the file priorities.",
        ["engine_sequential_mismatch"] = "The download engine did not apply sequential downloading.",
        ["engine_settings_changed"] = "The download engine's settings changed outside Briani.",
    };

    private static readonly Dictionary<string, string> WarningMessages = new(StringComparer.Ordinal)
    {
        ["results_truncated"] = "Only the first part of the results is shown.",
        ["stale_results"] = "Some results are from an earlier search because an indexer did not respond.",
        ["no_enabled_providers"] = "No indexers are enabled. Enable indexers in Prowlarr and in Briani's settings.",
        ["invalid_release"] = "Some results were skipped because an indexer returned incomplete data.",
        ["resolution_alternative_limit"] = "Some duplicate results were hidden.",
        ["resolution_oversized"] = "Some results were skipped because their details were too large.",
    };

    // Indexer reasons complete "Indexer 'x' failed: ..." / "Indexer 'x' ..." sentences.
    private static readonly Dictionary<string, string> ProviderReasons = new(StringComparer.Ordinal)
    {
        ["invalid_response"] = "returned a response that could not be read",
        ["provider_temporarily_disabled"] = "is temporarily disabled by Prowlarr",
        ["provider_recent_failure"] = "failed recently in Prowlarr",
        ["provider_degraded"] = "is reporting problems",
        ["provider_unavailable"] = "is unavailable",
        ["provider_timeout"] = "did not respond in time",
        ["timeout"] = "did not respond in time",
        ["unavailable"] = "is unavailable",
        ["recent_unsupported"] = "does not support browsing latest releases",
        ["rate_limited"] = "is rate limited; try again later",
        ["dependency_unavailable"] = "could not be reached because Prowlarr is unavailable",
    };

    public static bool IsKnown(string code) => Messages.ContainsKey(code);

    public static string For(string? code) =>
        code is not null && Messages.TryGetValue(code, out var message) ? message : Fallback;

    public static object Problem(string code, int status) =>
        new { type = "about:blank", title = For(code), status, code, detail = For(code) };

    // Warnings are stored as stable codes ("kind" or "kind:provider[:reason]") and rendered here.
    public static string Warning(string warning)
    {
        if (WarningMessages.TryGetValue(warning, out var direct)) return direct;
        var parts = warning.Split(':', 3);
        var provider = parts.Length > 1 ? $"Indexer '{parts[1]}'" : "An indexer";
        return parts[0] switch
        {
            "provider_unavailable" => $"{provider} is unavailable.",
            "recent_unsupported" => $"{provider} does not support browsing latest releases.",
            "search_unsupported" => $"{provider} does not support text search.",
            "provider_failed" or "provider_health" => $"{provider} {Reason(parts.Length > 2 ? parts[2] : null)}.",
            _ => "Some results may be incomplete.",
        };
    }

    private static string Reason(string? code) =>
        code is not null && ProviderReasons.TryGetValue(code, out var text) ? text : "did not respond correctly";
}
