using System.Text.Json;
using System.Text;
using Briani.Api.Modules.Media;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Briani.Api.Modules.Downloads.Queries;

public sealed record DownloadView(Guid Id, Guid LibraryId, Guid OwnerId, string? Name, string State,
    long? SelectedBytes, long DownloadedSelectedBytes, long? TorrentBytes, long DownloadBps, long UploadBps,
    long? SeedersConnected, long? PeersConnected, long? EtaSeconds, bool Sequential, bool FirstLastMetadataAssist,
    string Generation, long Version, string? ErrorCode, string? ErrorDetail, DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt, string[] Tags, string SourceState, string TransferState, string ImportState);

public sealed record DownloadFileView(Guid Id, Guid DownloadId, string Name, string RelativePath, long SizeBytes,
    long DownloadedBytes, long ContiguousBytes, string Kind, bool Selected, string Priority,
    string PlaybackState, Guid? ImportedMediaId, long Version);

public sealed record DownloadPageView(DownloadView[] Items, string? NextCursor, long? TotalKnown,
    bool Truncated, string[] Warnings);

public static class DownloadQueries
{
    private const int DefaultPageSize = 50;
    private const int MaxPageSize = 200;
    private const int MaxVisibleRequests = 10_000;
    private static readonly string[] PublicStates =
    [
        "resolving", "metadataPending", "awaitingSelection", "queued", "downloading", "paused", "stalled",
        "completeSelected", "importing", "seeding", "completed", "removing", "removed", "failed"
    ];

    public static void MapDownloadQueries(this WebApplication app)
    {
        var downloads = app.MapGroup("/api/v1/downloads").RequireAuthorization();
        downloads.MapGet("", ListDownloads);
        downloads.MapGet("/{id:guid}", ReadDownload);
        downloads.MapGet("/{id:guid}/files", ListFiles);
        downloads.MapGet("/{id:guid}/settings", ReadSettings);
        app.MapGet("/api/v1/events", DownloadEvents).RequireAuthorization();
    }

    private sealed record DownloadEvent(string Id, string Type, DateTimeOffset OccurredAt, object Payload);
    private sealed record EventRow(DownloadRequest Request, TorrentJob? Job, string Signature);
    private sealed record EventPermissions(Guid[] Readable, Guid[] Managed, string Fingerprint);
    internal sealed class EventAccessGuard(string fingerprint) : IDisposable
    {
        private string currentFingerprint = fingerprint;
        private readonly CancellationTokenSource revoked = new();
        public CancellationToken Token => revoked.Token;
        public string Fingerprint { get => Volatile.Read(ref currentFingerprint); set => Volatile.Write(ref currentFingerprint, value); }
        public void Revoke() { try { revoked.Cancel(); } catch (ObjectDisposedException) { } }
        public void Dispose() => revoked.Dispose();
    }
    private static readonly object EventAdmissionLock = new();
    private static readonly Dictionary<Guid, int> EventConnectionsByUser = [];
    private static int eventConnections;

    private sealed class EventConnectionLease(Guid userId) : IDisposable
    {
        private bool disposed;
        public void Dispose()
        {
            lock (EventAdmissionLock)
            {
                if (disposed) return;
                disposed = true;
                eventConnections--;
                if (EventConnectionsByUser.TryGetValue(userId, out var count))
                {
                    if (count <= 1) EventConnectionsByUser.Remove(userId);
                    else EventConnectionsByUser[userId] = count - 1;
                }
            }
        }
    }

    private static EventConnectionLease? TryAcquireEventConnection(Guid userId)
    {
        lock (EventAdmissionLock)
        {
            var userCount = EventConnectionsByUser.GetValueOrDefault(userId);
            if (eventConnections >= 16 || userCount >= 2) return null;
            eventConnections++;
            EventConnectionsByUser[userId] = userCount + 1;
            return new EventConnectionLease(userId);
        }
    }

    private static async Task DownloadEvents(HttpContext context, BrianiDb db, PermissionService permissions,
        TimeProvider clock, IServiceScopeFactory scopeFactory, Briani.Api.Modules.Playback.TorrentAvailability availability)
    {
        var actor = Actor.From(context.User);
        using var connectionLease = TryAcquireEventConnection(actor.UserId) ?? throw new ApiException(429, "event_stream_limit");
        var access = await LoadEventPermissionsAsync(db, permissions, actor, context.RequestAborted);
        if (access is null) throw new ApiException(401, "unauthorized");
        using var accessGuard = new EventAccessGuard(access.Fingerprint);
        using var watcherStop = CancellationTokenSource.CreateLinkedTokenSource(context.RequestAborted);
        var watcher = WatchEventAccessAsync(scopeFactory, actor, accessGuard, watcherStop.Token, clock);
        context.Response.StatusCode = StatusCodes.Status200OK;
        context.Response.ContentType = "text/event-stream; charset=utf-8";
        context.Response.Headers.CacheControl = "no-cache, no-store";
        context.Response.Headers["X-Accel-Buffering"] = "no";
        var lastKeepAlive = clock.GetUtcNow();
        var previous = new Dictionary<Guid, string>();
        var previousPlayback = new Dictionary<Guid,string>();
        var snapshotRequiredSent = false;
        try
        {
            while (!context.RequestAborted.IsCancellationRequested && !accessGuard.Token.IsCancellationRequested)
            {
                using var tickStop = CancellationTokenSource.CreateLinkedTokenSource(context.RequestAborted, accessGuard.Token);
                var ct = tickStop.Token;
                access = await LoadEventPermissionsAsync(db, permissions, actor, ct);
                if (access is null) return;
                accessGuard.Fingerprint = access.Fingerprint;

                var visible = db.DownloadRequests.AsNoTracking().Where(x => x.RemovedAt == null &&
                    ((x.OwnerId == actor.UserId && access.Readable.Contains(x.LibraryId)) || access.Managed.Contains(x.LibraryId)));
                var requests = await visible.OrderByDescending(x => x.UpdatedAt).ThenBy(x => x.Id)
                    .Take(MaxVisibleRequests + 1).ToArrayAsync(ct);
                var truncated = requests.Length > MaxVisibleRequests;
                if (truncated) requests = requests.Take(MaxVisibleRequests).ToArray();
                var jobs = await LoadJobs(db, requests.Where(x => x.TorrentJobId.HasValue).Select(x => x.TorrentJobId!.Value), ct);
                var rows = requests.Select(request =>
                {
                    jobs.TryGetValue(request.TorrentJobId ?? Guid.Empty, out var job);
                    var signature = $"{request.Version}:{request.UpdatedAt.UtcTicks}:{request.State}:{job?.Generation}:{job?.UpdatedAt.UtcTicks}:{job?.EngineState}:{job?.DownloadedBytes}:{job?.DownloadBps}:{job?.UploadBps}";
                    return new EventRow(request, job, signature);
                }).ToArray();
                var currentIds = rows.Select(x => x.Request.Id).ToHashSet();
                foreach (var stale in previous.Keys.Where(id => !currentIds.Contains(id)).ToArray()) previous.Remove(stale);

                var changed = new List<EventRow>(64);
                var tooManyChanges = false;
                foreach (var row in rows)
                {
                    if (previous.TryGetValue(row.Request.Id, out var signature) && signature == row.Signature) continue;
                    if (changed.Count == 64) { tooManyChanges = true; break; }
                    changed.Add(row);
                }
                var eventBytes = new List<byte[]>(changed.Count);
                foreach (var row in changed)
                {
                    var view = await DownloadViews.ViewAsync(db, row.Request, row.Job, ct);
                    var progress = view.SelectedBytes is > 0 ? Math.Clamp((double)view.DownloadedSelectedBytes / view.SelectedBytes.Value, 0d, 1d) : (double?)null;
                    var envelope = new DownloadEvent(Guid.NewGuid().ToString("N"), "download.updated", clock.GetUtcNow(),
                        new { id = view.Id, version = view.Version, state = view.State, progress, downloadBps = view.DownloadBps, uploadBps = view.UploadBps });
                    var bytes = JsonSerializer.SerializeToUtf8Bytes(envelope, JsonOptions);
                    if (bytes.Length <= 64 * 1024) eventBytes.Add(bytes);
                }
                if (truncated || tooManyChanges)
                {
                    eventBytes.Clear();
                    if (!snapshotRequiredSent)
                        eventBytes.Add(JsonSerializer.SerializeToUtf8Bytes(new DownloadEvent(Guid.NewGuid().ToString("N"), "snapshot.required", clock.GetUtcNow(), new { }), JsonOptions));
                    snapshotRequiredSent = true;
                    foreach (var row in rows) previous[row.Request.Id] = row.Signature;
                }
                else
                {
                    snapshotRequiredSent = false;
                    foreach (var row in changed) previous[row.Request.Id] = row.Signature;
                }

                var playback = await Briani.Api.Modules.Playback.PlaybackEvents.LoadAsync(db,permissions,availability,actor,clock,ct);
                var playbackIds=playback.Items.Select(x=>x.SessionId).ToHashSet();
                foreach(var stale in previousPlayback.Keys.Where(x=>!playbackIds.Contains(x)).ToArray())previousPlayback.Remove(stale);
                foreach(var hint in playback.Items)
                {
                    var signature=$"{hint.State}:{hint.Generation}:{hint.ContiguousBytes}:{hint.TotalBytes}";
                    if(previousPlayback.GetValueOrDefault(hint.SessionId)==signature)continue;
                    if(eventBytes.Count>=64 || playback.Truncated){eventBytes.Clear();eventBytes.Add(JsonSerializer.SerializeToUtf8Bytes(new DownloadEvent(Guid.NewGuid().ToString("N"),"snapshot.required",clock.GetUtcNow(),new{}),JsonOptions));break;}
                    eventBytes.Add(JsonSerializer.SerializeToUtf8Bytes(new DownloadEvent(Guid.NewGuid().ToString("N"),"playback.state",clock.GetUtcNow(),hint),JsonOptions));previousPlayback[hint.SessionId]=signature;
                }

                using var writeTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
                using var writeStop = CancellationTokenSource.CreateLinkedTokenSource(ct, writeTimeout.Token);
                try
                {
                    var now = clock.GetUtcNow();
                    if (eventBytes.Count == 0 && now - lastKeepAlive >= TimeSpan.FromSeconds(15))
                    {
                        await context.Response.WriteAsync(": keepalive\n\n", writeStop.Token);
                        lastKeepAlive = now;
                    }
                    await WriteEventBatchAsync(context.Response.Body, eventBytes, writeStop.Token);
                }
                catch (OperationCanceledException) when (writeStop.IsCancellationRequested) { return; }
                using var pollDelay = CancellationTokenSource.CreateLinkedTokenSource(ct);
                try { await Task.Delay(TimeSpan.FromSeconds(1), clock, pollDelay.Token); }
                catch (OperationCanceledException) when (pollDelay.IsCancellationRequested) { return; }
            }
        }
        finally { watcherStop.Cancel(); try { await watcher; } catch (OperationCanceledException) { } }
    }

    private static async Task<EventPermissions?> LoadEventPermissionsAsync(BrianiDb db, PermissionService permissions,
        Actor actor, CancellationToken ct)
    {
        if (!await permissions.IsAccessValidAsync(actor, ct)) return null;
        var readable = new List<Guid>();
        var managed = new List<Guid>();
        var stamps = new List<string>();
        var libraries = await db.Libraries.AsNoTracking().Where(x => x.Enabled && x.Online).OrderBy(x => x.Id).ToListAsync(ct);
        foreach (var library in libraries)
        {
            var capability = await permissions.CapabilitiesAsync(actor, library, ct);
            if (capability.Read) readable.Add(library.Id);
            if (capability.Manage) managed.Add(library.Id);
            stamps.Add($"{library.Id:N}:{(capability.Read ? 1 : 0)}:{(capability.Manage ? 1 : 0)}");
        }
        return new(readable.ToArray(), managed.ToArray(), string.Join('|', stamps));
    }

    private static async Task WatchEventAccessAsync(IServiceScopeFactory scopeFactory, Actor actor, EventAccessGuard guard,
        CancellationToken ct, TimeProvider clock)
    {
        try
        {
            while (!ct.IsCancellationRequested)
            {
                await Task.Delay(TimeSpan.FromSeconds(1), clock, ct);
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
                var permissions = scope.ServiceProvider.GetRequiredService<PermissionService>();
                var current = await LoadEventPermissionsAsync(db, permissions, actor, ct);
                if (current is null || current.Fingerprint != guard.Fingerprint) { guard.Revoke(); return; }
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { }
        catch (Exception) { guard.Revoke(); }
    }

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    internal static async Task WriteEventBatchAsync(Stream body, IReadOnlyList<byte[]> events, CancellationToken cancellationToken)
    {
        foreach (var bytes in events)
        {
            await body.WriteAsync("data: "u8.ToArray(), cancellationToken);
            await body.WriteAsync(bytes, cancellationToken);
            await body.WriteAsync("\n\n"u8.ToArray(), cancellationToken);
        }
        await body.FlushAsync(cancellationToken);
    }

    private static async Task<IResult> ListDownloads(HttpContext context, BrianiDb db, PermissionService permissions,
        PageCursor cursors, SecretStore secrets, TimeProvider clock, [FromQuery] int? limit,
        [FromQuery] Guid? libraryId, [FromQuery] string? state, [FromQuery] string? cursor, CancellationToken ct)
    {
        var actor = Actor.From(context.User);
        if (!await permissions.IsSessionValidAsync(actor.SessionId, ct)) throw new ApiException(404, "not_found");
        var pageSize = limit ?? DefaultPageSize;
        if (pageSize is < 1 or > MaxPageSize || (state is not null && !PublicStates.Contains(state, StringComparer.Ordinal)))
            throw new ApiException(400, "validation_failed");

        var readableLibraries = new List<Guid>();
        var managedLibraries = new List<Guid>();
        foreach (var library in await db.Libraries.AsNoTracking().Where(x => x.Enabled && x.Online).OrderBy(x => x.Id).ToListAsync(ct))
        {
            var capabilities = await permissions.CapabilitiesAsync(actor, library, ct);
            if (capabilities.Read) readableLibraries.Add(library.Id);
            if (capabilities.Manage) managedLibraries.Add(library.Id);
        }
        var visibleLibraries = readableLibraries.Union(managedLibraries).Distinct().ToArray();
        if (libraryId is Guid requestedLibrary && !visibleLibraries.Contains(requestedLibrary))
            return Results.Ok(new DownloadPageView([], null, 0, false, []));

        var query = db.DownloadRequests.AsNoTracking().Where(x => x.RemovedAt == null &&
            ((x.OwnerId == actor.UserId && readableLibraries.Contains(x.LibraryId)) || managedLibraries.Contains(x.LibraryId)));
        if (libraryId is Guid filterLibrary) query = query.Where(x => x.LibraryId == filterLibrary);
        if (state is not null) query = query.Where(x => RequestStateAliases(state).Contains(x.State));

        var count = await query.LongCountAsync(ct);
        var requests = await query.OrderByDescending(x => x.CreatedAt).ThenBy(x => x.Id)
            .Take(MaxVisibleRequests + 1).ToArrayAsync(ct);
        var truncated = requests.Length > MaxVisibleRequests;
        if (truncated) requests = requests.Take(MaxVisibleRequests).ToArray();
        var jobs = await LoadJobs(db, requests.Select(x => x.TorrentJobId).Where(x => x is not null).Select(x => x!.Value), ct);
        var catalog = secrets.Digest(string.Join('|', requests.Select(x =>
        {
            jobs.TryGetValue(x.TorrentJobId ?? Guid.Empty, out var job);
            return $"{x.Id:N}:{x.Version}:{x.UpdatedAt.UtcTicks}:{job?.Id:N}:{job?.Generation}:{job?.UpdatedAt.UtcTicks}";
        })));
        var scope = $"downloads:{actor.UserId:N}:{libraryId?.ToString("N") ?? "*"}:{state ?? "*"}:{catalog}";
        var offset = cursors.Decode(cursor, scope);
        if (offset > requests.Length) throw new ApiException(400, "invalid_cursor");
        var pageRequests = requests.Skip(offset).Take(pageSize).ToArray();
        var views = new DownloadView[pageRequests.Length];
        for (var i = 0; i < pageRequests.Length; i++)
            views[i] = await DownloadViews.ViewAsync(db, pageRequests[i], jobs.GetValueOrDefault(pageRequests[i].TorrentJobId ?? Guid.Empty), ct);
        var nextOffset = offset + views.Length;
        var next = nextOffset < requests.Length ? cursors.Encode(scope, nextOffset) : null;
        return Results.Ok(new DownloadPageView(views, next, truncated ? null : count, truncated,
            truncated ? ["results_truncated"] : []));
    }

    private static async Task<IResult> ReadDownload(Guid id, HttpContext context, DownloadAccess access,
        BrianiDb db, CancellationToken ct)
    {
        var (request, _, job) = await access.RequireAsync(Actor.From(context.User), id, ct);
        return Results.Ok(await DownloadViews.ViewAsync(db, request, job, ct));
    }

    private static async Task<IResult> ListFiles(Guid id, HttpContext context, DownloadAccess access,
        BrianiDb db, CancellationToken ct)
    {
        var (request, _, job) = await access.RequireAsync(Actor.From(context.User), id, ct);
        if (job is null) return Results.Ok(Array.Empty<DownloadFileView>());
        var selection = await db.DownloadRequestFiles.AsNoTracking().Where(x => x.DownloadRequestId == request.Id)
            .ToDictionaryAsync(x => x.DownloadFileId, ct);
        var rows = await db.DownloadFiles.AsNoTracking().Where(x => x.TorrentJobId == job.Id && !x.Padding)
            .OrderBy(x => x.MetadataFileIndex).ThenBy(x => x.UpstreamFileIndex).ThenBy(x => x.Id)
            .Take(10_000).ToArrayAsync(ct);
        var files = rows.Select(file =>
        {
            selection.TryGetValue(file.Id, out var selected);
            var name = SafeName(file.DisplayName, file.RelativePath);
            return new DownloadFileView(file.Id, request.Id, name, LogicalPath(file.RelativePath, name),
                Math.Max(0, file.SizeBytes), Math.Clamp(file.DownloadedBytes, 0, Math.Max(0, file.SizeBytes)),
                Math.Clamp(file.ContiguousBytes, 0, Math.Max(0, file.SizeBytes)), Kind(file.Kind),
                selected?.Selected == true, Priority(selected?.Priority ?? file.FilePriority),
                PlaybackState(file.PlaybackState), file.ImportedItemId, Math.Max(1, file.Version));
        }).ToArray();
        return Results.Ok(files);
    }

    private static async Task<IResult> ReadSettings(Guid id, HttpContext context, DownloadAccess access,
        BrianiDb db, CancellationToken ct)
    {
        var (_, _, job) = await access.RequireAsync(Actor.From(context.User), id, ct);
        return Results.Ok(DownloadViews.Settings(job));
    }

    private static async Task<Dictionary<Guid, TorrentJob>> LoadJobs(BrianiDb db, IEnumerable<Guid> ids, CancellationToken ct)
    {
        var distinct = ids.Distinct().ToArray();
        return distinct.Length == 0 ? [] : await db.TorrentJobs.AsNoTracking().Where(x => distinct.Contains(x.Id))
            .ToDictionaryAsync(x => x.Id, ct);
    }

    private static string[] RequestStateAliases(string state) => state switch
    {
        "metadataPending" => ["metadataPending", "metadata_pending", "fetching_metadata"],
        "awaitingSelection" => ["awaitingSelection", "awaiting_selection"],
        "completeSelected" => ["completeSelected", "selected_files_complete", "complete_selected"],
        _ => [state]
    };

    internal static string SafeName(string? displayName, string relativePath)
    {
        var value = string.IsNullOrWhiteSpace(displayName) ? Path.GetFileName(relativePath) : displayName;
        var safe = new string((value ?? "").Where(c => !char.IsControl(c)).Take(256).ToArray()).Trim();
        return safe.Length == 0 ? "unknown" : safe;
    }

    private static string LogicalPath(string? relativePath, string safeName)
    {
        if (string.IsNullOrWhiteSpace(relativePath) || relativePath.Length > 2048 || relativePath.Any(char.IsControl) ||
            relativePath.StartsWith('/') || relativePath.StartsWith('\\') || Path.IsPathRooted(relativePath) ||
            (relativePath.Length >= 2 && char.IsAsciiLetter(relativePath[0]) && relativePath[1] == ':') ||
            relativePath.Split(['/', '\\']).Any(x => x is ".." or ".")) return safeName;
        return relativePath.Replace('\\', '/');
    }

    private static string Kind(string? value) => value switch
    {
        "video" => "video", "photo" or "image" => "photo", "subtitle" => "subtitle", _ => "other"
    };

    private static string Priority(int value) => value switch { 7 => "maximum", 6 => "high", _ => "normal" };

    private static string PlaybackState(string? value) => value switch
    {
        "notSelected" => "notSelected", "metadataPending" => "metadataPending", "waitingForData" => "waitingForData",
        "eligible" => "eligible", "complete" => "complete", "unsupported" => "unsupported", _ => "unavailable"
    };
}

public static class DownloadViews
{
    private static readonly JsonSerializerOptions SettingsJsonOptions = new(JsonSerializerDefaults.Web);

    public static async Task<DownloadView> ViewAsync(BrianiDb db, DownloadRequest request, CancellationToken ct = default) =>
        await ViewAsync(db, request, request.TorrentJobId is Guid id
            ? await db.TorrentJobs.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id && x.LibraryId == request.LibraryId, ct)
            : null, ct);

    internal static async Task<DownloadView> ViewAsync(BrianiDb db, DownloadRequest request, TorrentJob? job, CancellationToken ct)
    {
        long? selectedBytes = null;
        long downloaded = 0;
        if (job is not null)
        {
            var selected = await (from requestFile in db.DownloadRequestFiles.AsNoTracking()
                                  join file in db.DownloadFiles.AsNoTracking() on requestFile.DownloadFileId equals file.Id
                                  where requestFile.DownloadRequestId == request.Id && requestFile.Selected &&
                                        file.TorrentJobId == job.Id && !file.Padding
                                  select new { file.SizeBytes, file.DownloadedBytes }).ToArrayAsync(ct);
            if (selected.Length > 0)
            {
                long total = 0;
                foreach (var file in selected)
                {
                    total = SaturatingAdd(total, Math.Max(0, file.SizeBytes));
                    downloaded = SaturatingAdd(downloaded, Math.Clamp(file.DownloadedBytes, 0, Math.Max(0, file.SizeBytes)));
                }
                selectedBytes = total;
            }
        }

        var tags = job is null ? [] : ReadTags(job.TagsJson);
        var sourceState = MapSourceState(request.SourceState);
        var transferState = MapTransferState(job?.EngineState);
        var importState = MapImportState(job?.ImportState);
        return new DownloadView(request.Id, request.LibraryId, request.OwnerId,
            job is null ? null : DownloadQueries.SafeName(job.Name, "unknown"), MapRequestState(request.State),
            selectedBytes, downloaded, job?.TotalBytes is >= 0 ? job.TotalBytes : null,
            Math.Max(0, job?.DownloadBps ?? 0), Math.Max(0, job?.UploadBps ?? 0),
            job?.SeedersConnected is >= 0 ? job.SeedersConnected : null,
            job?.PeersConnected is >= 0 ? job.PeersConnected : null,
            job?.EtaSeconds is >= 0 ? job.EtaSeconds : null,
            job?.Sequential ?? false, job?.MetadataAssist ?? false,
            job is null ? $"request:{request.Id:N}:{request.Version}" : $"{job.Id:N}:{job.Generation}",
            Math.Max(1, request.Version), SafeError(request.ErrorCode ?? job?.ErrorCode), SafeErrorDetail(request.ErrorCode ?? job?.ErrorCode),
            request.CreatedAt, request.UpdatedAt, tags, sourceState, transferState, importState);
    }

    public static DownloadSettings Settings(TorrentJob? job)
    {
        if (job is null) return new DownloadSettings(1, Tags: []);
        DownloadSettings? stored = null;
        try { stored = JsonSerializer.Deserialize<DownloadSettings>(job.SettingsJson, SettingsJsonOptions); }
        catch (JsonException) { }
        return new DownloadSettings(Math.Max(1, job.SettingsVersion),
            ValidLimit(stored?.DownloadLimitBytesPerSecond, 1_073_741_824),
            ValidLimit(stored?.UploadLimitBytesPerSecond, 1_073_741_824),
            stored?.RatioLimit is >= 0 and <= 10_000 ? stored.RatioLimit : null,
            ValidLimit(stored?.SeedTimeMinutes, 525_600),
            stored?.QueuePosition is >= 0 and <= 500 ? stored.QueuePosition : null,
            ReadTags(job.TagsJson));
    }

    private static long? ValidLimit(long? value, long max) => value is >= 0 && value <= max ? value : null;

    private static string[] ReadTags(string? json)
    {
        try
        {
            return (JsonSerializer.Deserialize<string[]>(json ?? "[]", SettingsJsonOptions) ?? [])
                .Where(x => !string.IsNullOrWhiteSpace(x) && x.Length <= 100 && !x.Any(char.IsControl))
                .Distinct(StringComparer.Ordinal).Take(50).ToArray();
        }
        catch (JsonException) { return []; }
    }

    private static string MapRequestState(string? state) => state switch
    {
        "resolving" or "created" => "resolving",
        "metadataPending" or "metadata_pending" or "fetching_metadata" => "metadataPending",
        "awaitingSelection" or "awaiting_selection" => "awaitingSelection",
        "queued" => "queued", "downloading" => "downloading", "paused" => "paused", "stalled" => "stalled",
        "completeSelected" or "complete_selected" or "selected_files_complete" => "completeSelected",
        "importing" => "importing", "seeding" => "seeding", "completed" or "available" => "completed",
        "removing" => "removing", "removed" or "cancelled" => "removed", "failed" => "failed", _ => "failed"
    };

    private static string MapSourceState(string? state) => state switch
    {
        "resolving" => "resolving", "metadataPending" or "metadata_pending" => "metadataPending",
        "ready" => "ready", "failed" => "failed", _ => "resolving"
    };

    private static string MapTransferState(string? state) => state switch
    {
        "metadata" => "metadata", "queued" or "queuedDL" => "queued",
        "downloading" or "downloadingDL" or "forcedDL" => "downloading",
        "paused" or "pausedDL" or "pausedUP" => "paused",
        "stalled" or "stalledDL" or "stalledUP" => "stalled",
        "checking" or "checkingDL" or "checkingUP" => "checking",
        "seeding" or "uploading" or "queuedUP" => "seeding",
        "complete" => "complete", "stopped" or "stoppedUP" or "stoppedDL" => "stopped",
        "failed" or "error" => "failed", _ => "stopped"
    };

    private static string MapImportState(string? state) => state switch
    {
        "pending" or "running" or "complete" or "failed" => state,
        "notReady" or "not_ready" => "notReady", _ => "notReady"
    };

    private static string? SafeError(string? code) => code is null ? null : code switch
    {
        "source_expired" or "source_unavailable" or "metadata_timeout" or "metadata_unavailable" or "disk_full" or
        "quota_exceeded" or "engine_unavailable" or "permission_changed" or "invalid_metainfo" or "invalid_selection" => code,
        _ => "download_failed"
    };

    private static string? SafeErrorDetail(string? code) => code is null ? null : code switch
    {
        "source_expired" => "The source entry expired. Refresh discovery results and try again.",
        "metadata_timeout" => "Torrent metadata was not received before the request expired.",
        "disk_full" => "The destination volume has insufficient free space.",
        "quota_exceeded" => "The selected files exceed the available quota.",
        "permission_changed" => "Access to the destination library changed.",
        _ => "The download operation failed."
    };

    private static long SaturatingAdd(long left, long right)
    {
        try { return checked(left + right); }
        catch (OverflowException) { return long.MaxValue; }
    }
}
