using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Administration;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Libraries.Queries;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace Briani.Api.Modules.Preferences;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record MaintenanceRequest(string Action, Guid? LibraryId = null);
public sealed record ApplicationServiceHealth(string Service, string State, string? Detail, DateTimeOffset CheckedAt);

/// <summary>Bounded, local-only administrative diagnostics and durable maintenance actions.</summary>
public static class ApplicationOperations
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public static void Map(WebApplication app)
    {
        var admin = app.MapGroup("/api/v1/admin").RequireAuthorization("administrator")
            .AddEndpointFilter<LiveAdministratorFilter>();
        admin.MapGet("/health", ReadHealth);
        admin.MapPost("/maintenance", QueueMaintenance);
    }

    private static async Task<IResult> ReadHealth(BrianiDb db, ServerOptions options,
        ServiceConnections connections, TimeProvider clock, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var count = await db.Jobs.AsNoTracking().Where(x => x.State == "queued" || x.State == "running")
            .Select(x => x.Id).Take(1001).CountAsync(ct);
        var available = true;
        try
        {
            await db.Database.ExecuteSqlRawAsync("SELECT 1", ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            available = false;
        }
        var rootsOnline = await StorageRootsOnline(db, ct);
        var services = new List<ApplicationServiceHealth>
        {
            new("database", available ? "healthy" : "unavailable", null, now),
            new("queue", count < 1000 ? "healthy" : "degraded", $"{Math.Min(count, 1000)} active jobs (capped at 1000).", now),
            StorageHealth("state", options.StateRoot, now),
            StorageHealth("data", options.DataRoot, now),
            new("storageVolumes", rootsOnline ? "healthy" : "degraded", null, now)
        };
        foreach (var kind in new[] { "prowlarr", "qbittorrent" })
        {
            try
            {
                var value = await connections.ReadAsync(kind, ct);
                var view = connections.View(kind, value);
                var health = view.GetType().GetProperty("health")?.GetValue(view);
                var state = health?.GetType().GetProperty("state")?.GetValue(health)?.ToString() ?? "unknown";
                var checkedAt = health?.GetType().GetProperty("checkedAt")?.GetValue(health) as DateTimeOffset? ?? now;
                var detail = state is "healthy" or "unknown" or "unavailable" ? null : "See protected integration settings.";
                services.Add(new(kind, state, detail, checkedAt));
            }
            catch (Exception e) when (e is ApiException or IOException)
            {
                services.Add(new(kind, "unknown", null, now));
            }
        }
        return Results.Ok(services);
    }

    private static ApplicationServiceHealth StorageHealth(string name, string root, DateTimeOffset now)
    {
        try
        {
            using var contained = new ContainedDirectory(root);
            var volume = contained.Volume();
            return new(name, volume.Writable ? "healthy" : "degraded", null, now);
        }
        catch (Exception e) when (e is ApiException or IOException or UnauthorizedAccessException or PlatformNotSupportedException)
        {
            return new(name, "unavailable", null, now);
        }
    }

    private static async Task<bool> StorageRootsOnline(BrianiDb db, CancellationToken ct)
    {
        var roots = await db.Libraries.AsNoTracking().Select(x => x.Online).Take(1000).ToArrayAsync(ct);
        return roots.All(x => x);
    }

    private static async Task<IResult> QueueMaintenance(MaintenanceRequest request, HttpContext context,
        BrianiDb db, TimeProvider clock, CancellationToken ct)
    {
        if (request.Action is not ("rescanLibraries" or "pruneThumbnailCache" or "databaseSnapshot") ||
            (request.Action != "rescanLibraries" && request.LibraryId is not null))
            throw new ApiException(400, "validation_failed");
        var idempotency = context.Request.Headers["Idempotency-Key"].ToString();
        if (idempotency.Length > 200 || idempotency.Any(char.IsControl)) throw new ApiException(400, "validation_failed");
        var actor = Actor.From(context.User);
        var body = JsonSerializer.Serialize(request, Json);
        var key = string.IsNullOrEmpty(idempotency) ? Guid.NewGuid().ToString("N") :
            Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{actor.UserId:N}:{idempotency}")));
        var dedup = "admin:" + key;

        var now = clock.GetUtcNow();
        await db.Jobs.Where(x => x.Kind == "adminMaintenance" &&
                (x.State == "completed" || x.State == "failed") && x.UpdatedAt < now.AddDays(-30))
            .OrderBy(x => x.UpdatedAt).Take(500).ExecuteDeleteAsync(ct);
        await db.Jobs.Where(x => x.Kind == "adminMaintenance" && (x.State == "completed" || x.State == "failed"))
            .OrderByDescending(x => x.UpdatedAt).Skip(500).Take(500).ExecuteDeleteAsync(ct);
        if (request.Action == "rescanLibraries" && request.LibraryId is not null &&
            !await db.Libraries.AnyAsync(x => x.Id == request.LibraryId && x.Enabled, ct))
            throw new ApiException(404, "not_found");

        var prior = await db.Jobs.SingleOrDefaultAsync(x => x.DedupKey == dedup, ct);
        if (prior is not null)
        {
            if (!string.Equals(prior.PayloadJson, body, StringComparison.Ordinal)) throw new ApiException(409, "idempotency_conflict");
            return Results.Accepted($"/api/v1/jobs/{prior.Id:D}", ToDto(prior));
        }
        if (await db.Jobs.CountAsync(x => x.Kind == "adminMaintenance" && (x.State == "queued" || x.State == "running"), ct) >= 100)
            throw new ApiException(429, "maintenance_queue_full", retryAfterSeconds: 30);
        var job = new WorkJob
        {
            Kind = "adminMaintenance", TargetId = actor.UserId, DedupKey = dedup, PayloadJson = body,
            State = "queued", CreatedAt = now, UpdatedAt = now, NextAttemptAt = now
        };
        db.Jobs.Add(job);
        await db.SaveChangesAsync(ct);
        return Results.Accepted($"/api/v1/jobs/{job.Id:D}", ToDto(job));
    }

    internal static JobDto ToDto(WorkJob j) => new(j.Id, j.Kind, j.State, j.Progress,
        j.LastErrorCode is null ? null : new { code = j.LastErrorCode }, j.CreatedAt, j.UpdatedAt);
}

/// <summary>Claims one maintenance/configuration job per call so tests and hosts can drive bounded work.</summary>
public sealed class ApplicationOperationsWorker(IServiceScopeFactory scopes, WriteGate gate,
    TimeProvider clock, ServerOptions options, Microsoft.Extensions.Hosting.IHostEnvironment environment) : BackgroundService
{
    private readonly string leaseOwner = Guid.NewGuid().ToString("N");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.BackgroundMediaOperations || environment.IsEnvironment("Testing")) return;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (!await RunOnceAsync(stoppingToken)) await Task.Delay(TimeSpan.FromSeconds(2), clock, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch { try { await Task.Delay(TimeSpan.FromSeconds(3), clock, stoppingToken); } catch (OperationCanceledException) { break; } }
        }
    }

    public async Task<bool> RunOnceAsync(CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        WorkJob? job;
        using (await gate.EnterAsync(ct))
        {
            var now = clock.GetUtcNow();
            job = await db.Jobs.Where(x => (x.Kind == "adminMaintenance" || x.Kind == "configureEngine") &&
                    x.NextAttemptAt <= now && (x.State == "queued" || (x.State == "running" && x.LeaseUntil < now)))
                .OrderBy(x => x.CreatedAt).FirstOrDefaultAsync(ct);
            if (job is null) return false;
            job.State = "running"; job.LeaseOwner = leaseOwner; job.LeaseUntil = now.AddMinutes(2);
            job.Attempt++; job.UpdatedAt = now;
            await db.SaveChangesAsync(ct);
        }

        long? configurationVersion=null;
        try
        {
            if (job.Kind == "configureEngine")
            {
                // Configuration is idempotent and applies the latest administrator settings.
                configurationVersion=await db.Settings.AsNoTracking().Where(x=>x.Key==AdministratorConfiguration.Key).Select(x=>(long?)x.Version).SingleOrDefaultAsync(ct)??1;
                await scope.ServiceProvider.GetRequiredService<ITorrentEngine>().ConfigureManagedAsync(ct);
            }
            else await ExecuteMaintenanceAsync(job, scope.ServiceProvider, ct);

            using (await gate.EnterAsync(ct))
            {
                var current = await db.Jobs.SingleOrDefaultAsync(x => x.Id == job.Id && x.LeaseOwner == leaseOwner, ct);
                if (current is not null)
                {
                    if(configurationVersion is long applied && (await db.Settings.AsNoTracking().Where(x=>x.Key==AdministratorConfiguration.Key).Select(x=>(long?)x.Version).SingleOrDefaultAsync(ct)??1)!=applied) {
                        current.State="queued";current.Attempt=0;current.LeaseOwner=null;current.LeaseUntil=null;current.NextAttemptAt=clock.GetUtcNow();current.UpdatedAt=clock.GetUtcNow();
                        await db.SaveChangesAsync(ct);return true;
                    }
                    current.State = "completed"; current.Progress = 1; current.LeaseOwner = null; current.LeaseUntil = null;
                    current.UpdatedAt = clock.GetUtcNow(); await db.SaveChangesAsync(ct);
                }
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception)
        {
            using (await gate.EnterAsync(ct))
            {
                var current = await db.Jobs.SingleOrDefaultAsync(x => x.Id == job.Id && x.LeaseOwner == leaseOwner, ct);
                if (current is not null)
                {
                    current.LastErrorCode = "maintenance_failed"; current.LeaseOwner = null; current.LeaseUntil = null;
                    current.UpdatedAt = clock.GetUtcNow();
                    if (current.Attempt >= 5) current.State = "failed";
                    else { current.State = "queued"; current.NextAttemptAt = clock.GetUtcNow().AddSeconds(Math.Min(300, 5 * (1 << current.Attempt))); }
                    await db.SaveChangesAsync(ct);
                }
            }
        }
        return true;
    }

    private async Task ExecuteMaintenanceAsync(WorkJob job, IServiceProvider services, CancellationToken ct)
    {
        var request = JsonSerializer.Deserialize<MaintenanceRequest>(job.PayloadJson, new JsonSerializerOptions(JsonSerializerDefaults.Web))
            ?? throw new ApiException(400, "validation_failed");
        switch (request.Action)
        {
            case "rescanLibraries":
            {
                var db = services.GetRequiredService<BrianiDb>();
                using var held = await gate.EnterAsync(ct);
                var ids = await db.Libraries.AsNoTracking().Where(x => x.Enabled && x.Online &&
                    (request.LibraryId == null || x.Id == request.LibraryId)).OrderBy(x => x.Id).Take(1000).Select(x => x.Id).ToArrayAsync(ct);
                var now = clock.GetUtcNow();
                var secrets = services.GetRequiredService<SecretStore>();
                foreach (var id in ids)
                {
                    var dedup = secrets.Digest($"scan-library:{id:D}");
                    if (await db.Jobs.AnyAsync(x => x.DedupKey == dedup && (x.State == "queued" || x.State == "running"), ct)) continue;
                    db.Jobs.Add(new WorkJob { Kind = "scan", TargetId = id, DedupKey = dedup, PayloadJson = "{}", State = "queued", CreatedAt = now, UpdatedAt = now, NextAttemptAt = now });
                }
                await db.SaveChangesAsync(ct);
                break;
            }
            case "pruneThumbnailCache":
                await PruneThumbnailsAsync(services.GetRequiredService<BrianiDb>(), services.GetRequiredService<ServerOptions>(),
                    services.GetRequiredService<MediaReaders>(), gate, ct);
                break;
            case "databaseSnapshot":
                await SnapshotDatabaseAsync(services.GetRequiredService<BrianiDb>(), options, ct);
                break;
            default: throw new ApiException(400, "validation_failed");
        }
    }

    private static async Task PruneThumbnailsAsync(BrianiDb db, ServerOptions options, MediaReaders readers, WriteGate gate, CancellationToken ct)
    {
        using var held = await gate.EnterAsync(ct);
        var rows = await db.ThumbnailEntries.OrderBy(x => x.LastAccessedAt).Take(500).ToArrayAsync(ct);
        using var state = new ContainedDirectory(options.StateRoot);
        var removed = new List<ThumbnailEntry>();
        foreach (var row in rows)
        {
            ct.ThrowIfCancellationRequested();
            if (row.CacheRelativePath is not { Length: > 0 and <= 256 } path || !path.StartsWith("cache/media/", StringComparison.Ordinal) ||
                    readers.HasReaders(row.MediaItemId)) continue;
            try
            {
                using var file = state.OpenFile(path, row.FileIdentity);
                if (file.Length != row.Bytes || row.Bytes is < 0 or > 524288) continue;
                file.Dispose(); state.Unlink(path); removed.Add(row);
            }
            catch (ApiException) { }
        }
        db.ThumbnailEntries.RemoveRange(removed);
        await db.SaveChangesAsync(ct);
    }

    private static async Task SnapshotDatabaseAsync(BrianiDb db, ServerOptions options, CancellationToken ct)
    {
        var snapshotsPath = Path.Combine(options.StateRoot, "snapshots");
        using (var root = new ContainedDirectory(options.StateRoot))
        {
            try { using var existing = root.Directory("snapshots"); }
            catch (ApiException) { root.CreateDirectory("snapshots"); }
        }
        using var snapshots = new ContainedDirectory(snapshotsPath);
        snapshots.RestrictPermissions();
        var fileName = $"briani-{DateTimeOffset.UtcNow:yyyyMMddTHHmmssfffZ}-{Guid.NewGuid():N}.sqlite";
        var temp = fileName + ".tmp";
        var source = (SqliteConnection)db.Database.GetDbConnection();
        var databaseBytes = File.Exists(source.DataSource) ? new FileInfo(source.DataSource).Length : 0;
        var walBytes = File.Exists(source.DataSource + "-wal") ? new FileInfo(source.DataSource + "-wal").Length : 0;
        if (databaseBytes + walBytes > 1024L * 1024 * 1024) throw new ApiException(413, "snapshot_size_limit");
        using (snapshots.CreateFile(temp)) { }
        var target = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = Path.Combine(snapshotsPath, temp), Mode = SqliteOpenMode.ReadWrite, Pooling = false }.ToString());
        try
        {
            if (source.State != System.Data.ConnectionState.Open) await source.OpenAsync(ct);
            await target.OpenAsync(ct);
            source.BackupDatabase(target);
            await target.CloseAsync();
            snapshots.Rename(temp, fileName);
        }
        finally
        {
            await target.DisposeAsync();
            try { snapshots.Unlink(temp); } catch (ApiException) { }
        }
        var retained = snapshots.Names().Where(x => x.StartsWith("briani-", StringComparison.Ordinal) && x.EndsWith(".sqlite", StringComparison.Ordinal))
            .OrderByDescending(x => x, StringComparer.Ordinal).ToArray();
        if (retained.Length > 10000) throw new ApiException(409, "snapshot_retention_limit");
        foreach (var old in retained.Skip(5))
        {
            try { snapshots.Unlink(old); } catch (ApiException) { }
        }
    }
}
