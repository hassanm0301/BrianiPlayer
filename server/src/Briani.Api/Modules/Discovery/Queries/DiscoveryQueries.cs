using System.Text.Json;
using Briani.Api.Modules.Preferences;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.Prowlarr;
using Briani.Api.Modules.Media;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Briani.Api.Modules.Discovery.Queries;

public sealed record ProviderView(string Id, string Name, bool Enabled, bool SupportsSearch,
    bool SupportsRecent, long[] Categories, string State, string? Warning);
public sealed record DiscoveryResultView(Guid Id, string Title, long? SizeBytes, long? Seeders,
    long? Leechers, long? Peers, string ProviderId, string ProviderName, DateTimeOffset? PublishedAt,
    DateTimeOffset FetchedAt, bool Stale, bool Downloadable, long[] Categories);
public sealed record DiscoverySnapshotView(Guid Id, string State, DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt, DiscoveryResultView[] Items, string? NextCursor, long? TotalKnown,
    bool Truncated, string[] Warnings);

public static class DiscoveryQueries
{
    public static void MapDiscoveryQueries(this WebApplication app)
    {
        app.MapGet("/api/v1/discovery/providers", ListProviders).RequireAuthorization();
        app.MapPost("/api/v1/discovery/queries", CreateQuery).RequireAuthorization();
        app.MapGet("/api/v1/discovery/queries/{id:guid}", ReadSnapshot).RequireAuthorization();
    }

    private static async Task<IResult> ListProviders(HttpContext context, DiscoveryAccess access,
        IProwlarrClient prowlarr, BrianiDb db, CancellationToken cancellationToken)
    {
        var actor = Actor.From(context.User);
        await access.RequireAsync(actor, cancellationToken);
        ProviderInfo[] providers;
        try { providers = await prowlarr.ProvidersAsync(cancellationToken); }
        catch (ProwlarrFailure) { throw new ApiException(503, "dependency_unavailable"); }
        await access.RequireAsync(actor, cancellationToken);
        var configuration=await AdministratorConfiguration.ReadAsync(db,cancellationToken);
        var administrator=await db.Users.AsNoTracking().AnyAsync(u=>u.Id==actor.UserId && u.Enabled && !u.MustChangePassword && u.Role=="administrator",cancellationToken);
        var safe = providers.Where(p=>administrator || AdministratorConfiguration.ProviderAllowed(configuration,p.Id)).Take(QueryRules.MaxProviders).OrderBy(x => x.Id, StringComparer.Ordinal)
            .Select(SafeProvider).ToArray();
        return Results.Ok(safe);
    }

    private static async Task<IResult> CreateQuery(HttpContext context, [FromBody] DiscoveryQuery request,
        BrianiDb db, DiscoveryAccess access, PageCursor cursors, SecretStore secrets, WriteGate gate,
        TimeProvider clock, CancellationToken cancellationToken)
    {
        var actor = Actor.From(context.User);
        var permissionStamp = await access.RequireAsync(actor, cancellationToken);
        var configuration=await AdministratorConfiguration.ReadAsync(db,cancellationToken);
        var query = AdministratorConfiguration.ApplyDiscoveryPolicy(configuration,QueryRules.Normalize(request));
        var canonical = QueryRules.CanonicalJson(query);
        var requestHash = secrets.Digest("discovery-request:" + canonical);
        string? idempotencyKey = context.Request.Headers["Idempotency-Key"].ToString();
        if (idempotencyKey.Length > 200 || idempotencyKey.Any(char.IsControl))
            throw new ApiException(400, "validation_failed");
        if (idempotencyKey.Length == 0) idempotencyKey = null;
        var storedIdempotencyKey = idempotencyKey is null ? null : secrets.Digest($"discovery-idempotency:{actor.UserId:N}:{idempotencyKey}");
        DiscoverySnapshot? snapshot;
        using (await gate.EnterAsync(cancellationToken))
        {
            permissionStamp = await access.RequireAsync(actor, cancellationToken);
            var now = clock.GetUtcNow();
            var queryKey = secrets.Digest("discovery-cache:" + permissionStamp + ":" + configuration["version"] + ":" + canonical);
            Operation? expiredOperation = null;
            if (storedIdempotencyKey is not null)
            {
                var previous = await db.Operations.SingleOrDefaultAsync(x => x.UserId == actor.UserId &&
                    x.Kind == "discovery.query" && x.IdempotencyKey == storedIdempotencyKey, cancellationToken);
                if (previous is not null && previous.ExpiresAt > now)
                {
                    if (!Credentials.EqualHash(previous.RequestHash, requestHash))
                        throw new ApiException(409, "idempotency_conflict");
                    snapshot = await db.DiscoverySnapshots.AsNoTracking().SingleOrDefaultAsync(x =>
                        x.Id == previous.TargetId && x.UserId == actor.UserId && x.PermissionStamp == permissionStamp && x.ExpiresAt > now,
                        cancellationToken) ?? throw new ApiException(409, "idempotency_conflict");
                    return Results.Accepted($"/api/v1/discovery/queries/{snapshot.Id}",
                        await SnapshotView(db, snapshot, actor.UserId, permissionStamp, cursors, secrets, clock, null, QueryRules.DefaultPageSize, cancellationToken));
                }
                expiredOperation = previous;
            }

            snapshot = await db.DiscoverySnapshots.Where(x => x.UserId == actor.UserId && x.PermissionStamp == permissionStamp &&
                    x.QueryKey == queryKey && x.ExpiresAt > now && (x.State == "queued" || x.State == "running"))
                .OrderByDescending(x => x.CreatedAt).FirstOrDefaultAsync(cancellationToken)
                ?? await FindRecentCache(db, actor.UserId, permissionStamp, queryKey,
                    TimeSpan.FromSeconds(configuration[IsRecentFeed(query)?"discoveryRecentRefreshSeconds":"discoveryCacheSeconds"]!.GetValue<int>()), now, cancellationToken);

            if (snapshot is null)
            {
                var queued = await db.Jobs.CountAsync(x => x.Kind == "discovery" && x.State == "queued", cancellationToken);
                if (queued >= 20) throw new ApiException(429, "discovery_queue_full");
                var active = await db.DiscoverySnapshots.AnyAsync(x => x.UserId == actor.UserId &&
                    (x.State == "queued" || x.State == "running") && x.ExpiresAt > now, cancellationToken);
                if (active) throw new ApiException(429, "discovery_query_active");
                var userSnapshotCount = await db.DiscoverySnapshots.CountAsync(x => x.UserId == actor.UserId, cancellationToken);
                if (userSnapshotCount >= QueryRules.MaxSnapshotsPerUser ||
                    await db.DiscoverySnapshots.CountAsync(cancellationToken) >= QueryRules.MaxSnapshotsGlobal)
                    throw new ApiException(429, "discovery_snapshot_limit");
                snapshot = new DiscoverySnapshot
                {
                    UserId = actor.UserId, AuthSessionId = actor.SessionId, PermissionStamp = permissionStamp,
                    QueryKey = queryKey, QueryJson = canonical, State = "queued", CreatedAt = now,
                    ExpiresAt = now.Add(QueryRules.SnapshotLifetime), WarningsJson = "[]"
                };
                db.DiscoverySnapshots.Add(snapshot);
                db.Jobs.Add(new WorkJob
                {
                    Kind = "discovery", TargetId = snapshot.Id,
                    DedupKey = secrets.Digest("discovery-job:" + snapshot.Id.ToString("N")),
                    PayloadJson = "{}", State = "queued", NextAttemptAt = now, CreatedAt = now, UpdatedAt = now
                });
            }

            if (storedIdempotencyKey is not null)
            {
                if (expiredOperation is null)
                {
                    var userOperationCount = await db.Operations.CountAsync(x => x.UserId == actor.UserId && x.Kind == "discovery.query", cancellationToken);
                    if (userOperationCount >= QueryRules.MaxOperationsPerUser ||
                        await db.Operations.CountAsync(x => x.Kind == "discovery.query", cancellationToken) >= QueryRules.MaxOperationsGlobal)
                        throw new ApiException(429, "discovery_operation_limit");
                }
                var operation = expiredOperation ?? new Operation
                {
                    UserId = actor.UserId, Kind = "discovery.query", TargetId = snapshot.Id,
                    IdempotencyKey = storedIdempotencyKey
                };
                operation.TargetId = snapshot.Id;
                operation.RequestHash = requestHash;
                operation.State = snapshot.State;
                operation.PayloadJson = "{}";
                operation.ResultJson = "{}";
                operation.CreatedAt = now;
                operation.UpdatedAt = now;
                operation.ExpiresAt = now.Add(QueryRules.SnapshotLifetime);
                operation.ErrorCode = null;
                if (expiredOperation is null)
                    db.Operations.Add(operation);
            }
            await db.SaveChangesAsync(cancellationToken);
        }

        if (snapshot is null) throw new ApiException(500, "dependency_unavailable");
        return Results.Accepted($"/api/v1/discovery/queries/{snapshot.Id}",
            await SnapshotView(db, snapshot, actor.UserId, permissionStamp, cursors, secrets, clock, null, QueryRules.DefaultPageSize, cancellationToken));
    }

    private static async Task<DiscoverySnapshot?> FindRecentCache(BrianiDb db, Guid userId, string permissionStamp,
        string queryKey, TimeSpan maxAge, DateTimeOffset now, CancellationToken ct) =>
        await db.DiscoverySnapshots.AsNoTracking().Where(x => x.UserId == userId && x.PermissionStamp == permissionStamp &&
                x.QueryKey == queryKey && x.ExpiresAt > now && x.FetchedAt != null && (x.State == "complete" || x.State == "partial") &&
                x.FetchedAt >= now.Subtract(maxAge))
            .OrderByDescending(x => x.FetchedAt).FirstOrDefaultAsync(ct);

    private static bool IsRecentFeed(DiscoveryQuery query) => query.Mode == "latest" ||
        query.Mode == "mostSeeded" && string.IsNullOrWhiteSpace(query.Query);

    private static async Task<IResult> ReadSnapshot(HttpContext context, Guid id, BrianiDb db,
        DiscoveryAccess access, PageCursor cursors, SecretStore secrets, TimeProvider clock,
        [FromQuery] int? limit, [FromQuery] string? cursor, CancellationToken cancellationToken)
    {
        var actor = Actor.From(context.User);
        var permissionStamp = await access.RequireAsync(actor, cancellationToken);
        var snapshot = await db.DiscoverySnapshots.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id && x.UserId == actor.UserId,
            cancellationToken) ?? throw new ApiException(404, "not_found");
        if (snapshot.PermissionStamp != permissionStamp || snapshot.ExpiresAt <= clock.GetUtcNow())
            throw new ApiException(404, "not_found");
        await access.RequireAsync(actor, cancellationToken);
        var pageSize = limit ?? QueryRules.DefaultPageSize;
        if (pageSize is < 1 or > QueryRules.MaxPageSize) throw new ApiException(400, "validation_failed");
        return Results.Ok(await SnapshotView(db, snapshot, actor.UserId, permissionStamp, cursors, secrets, clock, cursor, pageSize, cancellationToken));
    }

    internal static async Task<DiscoverySnapshotView> SnapshotView(BrianiDb db, DiscoverySnapshot snapshot,
        Guid userId, string permissionStamp, PageCursor cursors, SecretStore secrets, TimeProvider clock,
        string? cursor, int pageSize, CancellationToken ct)
    {
        var query = JsonSerializer.Deserialize<DiscoveryQuery>(snapshot.QueryJson) ?? new("latest");
        var scope = $"discovery:{userId:N}:{snapshot.Id:N}:{permissionStamp}:{query.Sort}:{query.Order}";
        var offset = cursors.Decode(cursor, scope);
        var rows = await db.DiscoveryResults.AsNoTracking().Where(x => x.SnapshotId == snapshot.Id)
            .Take(QueryRules.MaxSnapshotResults + 1).ToArrayAsync(ct);
        if (rows.Length > QueryRules.MaxSnapshotResults) rows = rows.Take(QueryRules.MaxSnapshotResults).ToArray();
        var configuration=await AdministratorConfiguration.ReadAsync(db,ct);
        var cache=TimeSpan.FromSeconds(configuration[IsRecentFeed(query)?"discoveryRecentRefreshSeconds":"discoveryCacheSeconds"]!.GetValue<int>());
        var items = rows.Select(ToNormalized).Where(x=>AdministratorConfiguration.ProviderAllowed(configuration,x.SourceId) && AdministratorConfiguration.CategoriesAllowed(configuration,x.Categories)).ToArray();
        var sorted = QueryRules.Sort(items, query);
        if (offset > sorted.Length) throw new ApiException(400, "invalid_cursor");
        var page = sorted.Skip(offset).Take(pageSize).Select(x => new DiscoveryResultView(x.Id, x.Title,
            x.Bytes, x.Seeders, x.Leechers, x.Peers, x.SourceId, x.SourceName, x.PublishedAt,
            x.ObservedAt, clock.GetUtcNow() - x.ObservedAt > cache, x.CanDownload, x.Categories)).ToArray();
        var nextOffset = offset + page.Length;
        var next = nextOffset < sorted.Length ? cursors.Encode(scope, nextOffset) : null;
        var warnings = ReadWarnings(snapshot.WarningsJson);
        if (snapshot.FetchedAt is DateTimeOffset fetched && clock.GetUtcNow() - fetched > cache &&
            !warnings.Contains("stale_results", StringComparer.Ordinal)) warnings = [.. warnings, "stale_results"];
        long? total = snapshot.State is "queued" or "running" ? null : sorted.LongLength;
        return new DiscoverySnapshotView(snapshot.Id, snapshot.State, snapshot.CreatedAt, snapshot.ExpiresAt,
            page, next, total, snapshot.Truncated, [.. warnings.Select(ErrorMessages.Warning)]);
    }

    internal static NormalizedRelease ToNormalized(DiscoveryResult row)
    {
        long[] categories;
        try { categories = JsonSerializer.Deserialize<long[]>(row.CategoriesJson) ?? []; }
        catch (JsonException) { categories = []; }
        return new NormalizedRelease(row.Id, row.SourceId, row.SourceName, row.SourceGuid, row.Title,
            row.Bytes, row.Seeders, row.Leechers, row.PeersTotal, row.PublishedAt, row.ObservedAt,
            row.InfoHashV1, row.InfoHashV2, categories, row.EncryptedResolutionJson, row.CanDownload);
    }

    internal static string[] ReadWarnings(string? value)
    {
        try { return JsonSerializer.Deserialize<string[]>(value ?? "[]") ?? []; }
        catch (JsonException) { return []; }
    }

    internal static ProviderView SafeProvider(ProviderInfo provider)
    {
        var id = SafeLabel(provider.Id, 128);
        var name = SafeLabel(provider.Name, 128);
        var state = provider.State is "healthy" or "degraded" or "unavailable" or "unknown" ? provider.State : "unknown";
        var warning = provider.Warning is null ? null : provider.Warning.Contains("recent", StringComparison.OrdinalIgnoreCase)
            ? "recent_unsupported" : "provider_degraded";
        return new(id, name, provider.Enabled, provider.SupportsSearch, provider.SupportsRecent,
            (provider.Categories ?? []).Where(x => x >= 0).Distinct().Take(QueryRules.MaxCategories).Order().ToArray(), state, warning);
    }

    internal static string SafeLabel(string? value, int limit)
    {
        if (string.IsNullOrWhiteSpace(value)) return "unknown";
        var safe = new string(value.Where(c => !char.IsControl(c)).Take(limit).ToArray()).Trim();
        if (safe.Contains("http://", StringComparison.OrdinalIgnoreCase) || safe.Contains("https://", StringComparison.OrdinalIgnoreCase))
            return "configured provider";
        return safe.Length == 0 ? "unknown" : safe;
    }
}
