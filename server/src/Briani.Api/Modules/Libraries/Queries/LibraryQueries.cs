using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;

namespace Briani.Api.Modules.Libraries.Queries;

public sealed record EntryDto(Guid Id, Guid LibraryId, Guid? ParentId, string Kind, string Name,
    long? SizeBytes, DateTimeOffset? ModifiedAt, Guid? MediaId, bool ThumbnailAvailable, long Version);
public sealed record EntryPageDto(IReadOnlyList<EntryDto> Items, string? NextCursor, long? TotalKnown,
    bool Truncated, IReadOnlyList<string> Warnings);
public sealed record TrackDto(string Id, string Kind, string? Codec, string? Language, string? Title, bool Default);
public sealed record MediaDto(Guid Id, Guid LibraryId, Guid EntryId, string Name, string Kind, string MimeType,
    long SizeBytes, long? DurationMs, int? Width, int? Height, IReadOnlyList<TrackDto> Tracks, bool Complete,
    string ProbeState, long Version);
public sealed record JobDto(Guid Id, string Kind, string State, double? Progress, object? Error,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);
internal sealed record CursorData(Guid User, Guid Library, Guid? Folder, string Query, string Kind,
    string Sort, string Order, string Catalog, int Offset);

public static class LibraryQueries
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private const int MaxPageSize = 200;

    public static WebApplication MapLibraryQueries(this WebApplication app)
    {
        var api = app.MapGroup("/api/v1").RequireAuthorization();
        api.MapGet("/libraries/{id:guid}/entries", ListEntries);
        api.MapGet("/media/{id:guid}", GetMedia);
        api.MapPost("/libraries/{id:guid}/scan", ScanLibrary);
        api.MapGet("/jobs/{id:guid}", GetJob);
        return app;
    }

    private static async Task<IResult> ListEntries(Guid id, Guid? folderId, string? cursor, int? limit,
        string? query, string? kind, string? sort, string? order, HttpContext context, BrianiDb db,
        PermissionService permissions, SecretStore secrets, CancellationToken ct)
    {
        var actor = Actor.From(context.User);
        var library = await permissions.RequireLibraryAsync(actor, id, "read", ct);
        var size = limit ?? 50;
        if (size is < 1 or > MaxPageSize) throw new ApiException(400, "validation_failed");
        if (query is { Length: > 200 } || query?.Any(char.IsControl) == true) throw new ApiException(400, "validation_failed");
        var normalizedQuery = (query ?? "").Normalize(NormalizationForm.FormKC).ToUpperInvariant();
        var selectedKind = (kind ?? "all").ToLowerInvariant();
        var selectedSort = (sort ?? "name").ToLowerInvariant();
        var selectedOrder = (order ?? "asc").ToLowerInvariant();
        if (selectedKind is not ("all" or "folder" or "video" or "photo") ||
            selectedSort is not ("name" or "date" or "size") || selectedOrder is not ("asc" or "desc"))
            throw new ApiException(400, "validation_failed");

        var baseQuery = db.MediaItems.AsNoTracking().Where(x => x.LibraryId == id && x.Lifecycle == "available" &&
            (x.SourceKind=="virtual" || (!x.RelativePath.StartsWith(".briani/") && x.RelativePath != ".briani" &&
            !x.RelativePath.Contains("/.briani/") && !x.RelativePath.EndsWith("/.briani"))));
        if (folderId is not null && !await baseQuery.AnyAsync(x => x.Id == folderId && x.Kind == "folder", ct))
            throw new ApiException(404, "not_found");
        var catalogStamp = await db.MediaItems.AsNoTracking().Where(x => x.LibraryId == id)
            .GroupBy(_ => 1).Select(items => new { Count = items.Count(), VersionSum = items.Sum(x => (long)x.Version) })
            .SingleOrDefaultAsync(ct);
        var catalogCount = catalogStamp?.Count ?? 0;
        var catalogVersionSum = catalogStamp?.VersionSum ?? 0;
        var catalog = $"{library.Version}:{catalogCount}:{catalogVersionSum}";
        var offset = 0;
        if (cursor is not null)
        {
            var decoded = ReadCursor(cursor, secrets);
            if (decoded.User != actor.UserId || decoded.Library != id || decoded.Folder != folderId || decoded.Query != normalizedQuery ||
                decoded.Kind != selectedKind || decoded.Sort != selectedSort || decoded.Order != selectedOrder || decoded.Catalog != catalog ||
                decoded.Offset < 0 || decoded.Offset > 10_000)
                throw new ApiException(400, "invalid_cursor");
            offset = decoded.Offset;
        }
        if (offset > 10_000) throw new ApiException(400, "invalid_cursor");
        var selected = baseQuery.Where(x => x.ParentId == folderId);
        if (selectedKind != "all") selected = selected.Where(x => x.Kind == selectedKind);
        if (normalizedQuery.Length != 0)
        {
            var escaped = EscapeLike(normalizedQuery);
            selected = selected.Where(x => EF.Functions.Like(x.SearchKey, $"%{escaped}%", "\\"));
        }
        var total = await selected.LongCountAsync(ct);

        IOrderedQueryable<MediaItem> sorted = (selectedSort, selectedOrder) switch
        {
            ("date", "desc") => selected.OrderByDescending(x => x.MtimeNs).ThenBy(x => x.Id),
            ("date", _) => selected.OrderBy(x => x.MtimeNs).ThenBy(x => x.Id),
            ("size", "desc") => selected.OrderByDescending(x => x.SizeBytes).ThenBy(x => x.Id),
            ("size", _) => selected.OrderBy(x => x.SizeBytes).ThenBy(x => x.Id),
            ("name", "desc") => selected.OrderByDescending(x => x.SearchKey).ThenBy(x => x.Id),
            _ => selected.OrderBy(x => x.SearchKey).ThenBy(x => x.Id)
        };
        var pageSize = Math.Min(size, 10_000 - offset);
        var rows = await sorted.Skip(offset).Take(pageSize + 1).ToListAsync(ct);
        var hasMore = rows.Count > pageSize;
        if (hasMore) rows.RemoveAt(rows.Count - 1);
        var ids = rows.Where(x => x.Kind is "video" or "photo").Select(x => x.Id).ToArray();
        var currentThumbs = await (from t in db.ThumbnailEntries.AsNoTracking()
            join m in db.MediaMetadata.AsNoTracking() on t.MediaItemId equals m.MediaItemId
            where ids.Contains(t.MediaItemId) && t.Generation == m.ContentGeneration && t.Variant == "default"
            select t.MediaItemId).ToHashSetAsync(ct);
        var page = rows.Select(x => new EntryDto(x.Id, x.LibraryId, x.ParentId, x.Kind, x.DisplayName,
            x.SizeBytes, FromNanoseconds(x.MtimeNs), x.Kind is "video" or "photo" ? x.Id : null,
            currentThumbs.Contains(x.Id), x.Version)).ToArray();
        var nextOffset = offset + pageSize;
        string? next = hasMore && nextOffset < 10_000 ? WriteCursor(new(actor.UserId, id, folderId, normalizedQuery, selectedKind,
            selectedSort, selectedOrder, catalog, nextOffset), secrets) : null;
        return Results.Ok(new EntryPageDto(page, next, total, total > nextOffset && next is null, Array.Empty<string>()));
    }

    private static async Task<IResult> GetMedia(Guid id, HttpContext context, BrianiDb db,
        PermissionService permissions, CancellationToken ct)
    {
        var item = await db.MediaItems.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id && x.Lifecycle == "available", ct)
            ?? throw new ApiException(404, "not_found");
        var library = await permissions.RequireLibraryAsync(Actor.From(context.User), item.LibraryId, "read", ct);
        if (item.Kind is not ("video" or "photo") || Hidden(item.RelativePath)) throw new ApiException(404, "not_found");
        var metadata = await db.MediaMetadata.AsNoTracking().SingleOrDefaultAsync(x => x.MediaItemId == item.Id, ct);
        var tracks = metadata is null ? Array.Empty<TrackDto>() : ReadTracks(metadata.TracksJson);
        return Results.Ok(new MediaDto(item.Id, library.Id, item.Id, item.DisplayName, item.Kind, item.MimeType,
            item.SizeBytes ?? 0, metadata?.DurationMs, metadata?.Width, metadata?.Height, tracks, true,
            metadata?.ProbeStatus ?? "pending", item.Version));
    }

    private static async Task<IResult> ScanLibrary(Guid id, HttpContext context, BrianiDb db,
        PermissionService permissions, WriteGate gate, SecretStore secrets, TimeProvider clock, CancellationToken ct)
    {
        var actor = Actor.From(context.User);
        await permissions.RequireLibraryAsync(actor, id, "manage", ct);
        var key = context.Request.Headers["Idempotency-Key"].FirstOrDefault();
        if (key is { Length: > 200 } || key is { Length: 0 } || key?.Any(char.IsControl) == true)
            throw new ApiException(400, "validation_failed");
        var reqHash = secrets.Digest($"scan:{id:D}");
        var storedKey = key is null ? null : secrets.Digest($"scan:{actor.UserId:D}:{key}");
        using (await gate.EnterAsync(ct))
        {
            await permissions.RequireLibraryAsync(actor, id, "manage", ct);
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            if (storedKey is not null)
            {
                var old = await db.Operations.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == actor.UserId && x.Kind == "library-scan" && x.IdempotencyKey == storedKey, ct);
                if (old is not null)
                {
                    if (old.RequestHash != reqHash) throw new ApiException(409, "idempotency_conflict");
                    var prior = await db.Jobs.AsNoTracking().SingleAsync(x => x.Id == old.TargetId, ct);
                    await tx.CommitAsync(ct);
                    return Results.Accepted($"/api/v1/jobs/{prior.Id:D}", ToJob(prior));
                }
            }
            var dedup = secrets.Digest($"scan-library:{id:D}");
            var job = await db.Jobs.SingleOrDefaultAsync(x => x.DedupKey == dedup, ct);
            if (job is null || job.State is "completed" or "failed" or "cancelled")
            {
                if (job is not null) job.DedupKey = null;
                var now = clock.GetUtcNow();
                job = new WorkJob { Kind = "scan", TargetId = id, DedupKey = dedup, PayloadJson = "{}", State = "queued", NextAttemptAt = now, CreatedAt = now, UpdatedAt = now };
                db.Jobs.Add(job);
            }
            if (storedKey is not null) db.Operations.Add(new Operation { UserId = actor.UserId, Kind = "library-scan", TargetId = job.Id,
                IdempotencyKey = storedKey, RequestHash = reqHash, State = job.State, ResultJson = JsonSerializer.Serialize(ToJob(job), Json),
                PayloadJson = "{}", CreatedAt = clock.GetUtcNow(), ExpiresAt = clock.GetUtcNow().AddDays(30) });
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Results.Accepted($"/api/v1/jobs/{job.Id:D}", ToJob(job));
        }
    }

    private static async Task<IResult> GetJob(Guid id, HttpContext context, BrianiDb db,
        PermissionService permissions, CancellationToken ct)
    {
        var job = await db.Jobs.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw new ApiException(404, "not_found");
        var actor = Actor.From(context.User);
        if (job.Kind == "scan") await permissions.RequireLibraryAsync(actor, job.TargetId, "read", ct);
        else if (!actor.IsAdministrator) throw new ApiException(404, "not_found");
        return Results.Ok(ToJob(job));
    }

    private static JobDto ToJob(WorkJob j) => new(j.Id, j.Kind, j.State, j.Progress,
        j.LastErrorCode is null ? null : new { code = j.LastErrorCode }, j.CreatedAt, j.UpdatedAt);
    private static bool Hidden(string path) => path == ".briani" || path.StartsWith(".briani/", StringComparison.Ordinal) ||
        path.Contains("/.briani/", StringComparison.Ordinal) || path.EndsWith("/.briani", StringComparison.Ordinal);
    private static string EscapeLike(string value) => value.Replace("\\", "\\\\", StringComparison.Ordinal).Replace("%", "\\%", StringComparison.Ordinal).Replace("_", "\\_", StringComparison.Ordinal);
    private static DateTimeOffset? FromNanoseconds(long ns)
    {
        try { return DateTimeOffset.UnixEpoch.AddTicks(ns / 100); } catch (ArgumentOutOfRangeException) { return null; }
    }
    private static TrackDto[] ReadTracks(string json)
    {
        try
        {
            var tracks = JsonSerializer.Deserialize<MediaTrack[]>(json, Json) ?? [];
            return tracks.Select(x => new TrackDto(x.Id, x.Kind, x.Codec, x.Language, x.Title, x.Default)).ToArray();
        }
        catch (JsonException) { return []; }
    }
    private static string WriteCursor(CursorData data, SecretStore secrets)
    {
        var payload = Convert.ToBase64String(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(data, Json))).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return payload + "." + secrets.Digest("entry-cursor:" + payload);
    }
    private static CursorData ReadCursor(string cursor, SecretStore secrets)
    {
        try
        {
            if (cursor.Length > 4096) throw new FormatException();
            var parts = cursor.Split('.');
            if (parts.Length != 2 || !CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(parts[1]), Encoding.ASCII.GetBytes(secrets.Digest("entry-cursor:" + parts[0]))))
                throw new FormatException();
            var bytes = Convert.FromBase64String(parts[0].Replace('-', '+').Replace('_', '/') + new string('=', (4 - parts[0].Length % 4) % 4));
            return JsonSerializer.Deserialize<CursorData>(bytes, Json) ?? throw new FormatException();
        }
        catch (Exception e) when (e is FormatException or JsonException or ArgumentException) { throw new ApiException(400, "invalid_cursor"); }
    }
}
