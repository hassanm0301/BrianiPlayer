using System.Text.Json;
using Briani.Api.Modules.Preferences;
using System.Text;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.Prowlarr;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;

namespace Briani.Api.Modules.Discovery.Queries;

public sealed class DiscoveryQueryWorker(IServiceScopeFactory scopes, IProwlarrClient prowlarr,
    WriteGate writeGate, TimeProvider clock, SecretStore secrets, ServerOptions serverOptions) : BackgroundService
{
    private static readonly SemaphoreSlim ProviderSlots = new(2, 2);
    private static readonly object UserSlotsGate = new();
    private static readonly Dictionary<Guid, UserSlot> UserSlots = [];
    private readonly string leaseOwner = Guid.NewGuid().ToString("N");
    private static readonly TimeSpan LeaseDuration = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan ProviderTimeout = TimeSpan.FromSeconds(20);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!serverOptions.BackgroundDiscovery) return;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (!await RunOnceAsync(stoppingToken))
                    await Task.Delay(TimeSpan.FromSeconds(2), clock, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch
            {
                try { await Task.Delay(TimeSpan.FromSeconds(3), clock, stoppingToken); }
                catch (OperationCanceledException) { break; }
            }
        }
    }

    public async Task<bool> RunOnceAsync(CancellationToken ct = default)
    {
        var claim = await ClaimAsync(ct);
        if (claim is null) return false;
        using var release = new SemaphoreRelease(claim.UserId, claim.UserSlot);
        using var renewStop = CancellationTokenSource.CreateLinkedTokenSource(ct);
        var renewer = RenewLeaseAsync(claim.JobId, renewStop.Token);
        try
        {
            await ProcessAsync(claim, ct);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch
        {
            await MarkFailedAsync(claim, "dependency_unavailable", ct);
        }
        finally
        {
            renewStop.Cancel();
            try { await renewer; } catch (OperationCanceledException) { }
        }
        return true;
    }

    private async Task<JobClaim?> ClaimAsync(CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        using (await writeGate.EnterAsync(ct))
        {
            var now = clock.GetUtcNow();
            var jobs = await db.Jobs.Where(x => x.Kind == "discovery" &&
                    (x.State == "queued" || x.State == "running" && x.LeaseUntil < now) && x.NextAttemptAt <= now)
                .OrderBy(x => x.NextAttemptAt).ThenBy(x => x.CreatedAt).Take(20).ToListAsync(ct);
            foreach (var job in jobs)
            {
                var snapshot = await db.DiscoverySnapshots.SingleOrDefaultAsync(x => x.Id == job.TargetId, ct);
                if (snapshot is null || snapshot.ExpiresAt <= now)
                {
                    job.State = "completed"; job.DedupKey = null; job.LeaseOwner = null;
                    job.LeaseUntil = null; job.UpdatedAt = now;
                    await db.SaveChangesAsync(ct);
                    continue;
                }
                var userSlot = TryAcquireUserSlot(snapshot.UserId);
                if (userSlot is null) continue;
                try
                {
                    job.State = "running"; job.LeaseOwner = leaseOwner; job.LeaseUntil = now.Add(LeaseDuration);
                    job.Attempt++; job.UpdatedAt = now;
                    snapshot.State = "running";
                    await db.SaveChangesAsync(ct);
                    return new JobClaim(job.Id, snapshot.Id, snapshot.UserId, userSlot);
                }
                catch
                {
                    ReleaseUserSlot(snapshot.UserId, userSlot);
                    throw;
                }
            }
        }
        return null;
    }

    private async Task ProcessAsync(JobClaim claim, CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        var access = scope.ServiceProvider.GetRequiredService<DiscoveryAccess>();
        var snapshot = await db.DiscoverySnapshots.SingleOrDefaultAsync(x => x.Id == claim.SnapshotId && x.UserId == claim.UserId, ct);
        if (snapshot is null) { await CompleteJobAsync(db, claim, null, ct); return; }
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == snapshot.UserId, ct);
        if (user is null) { await MarkFailedAsync(claim, "permission_changed", ct); return; }
        var actor = new Actor(snapshot.UserId, snapshot.AuthSessionId, user.Role, user.MustChangePassword);
        string permissionStamp;
        try { permissionStamp = await access.RequireAsync(actor, ct); }
        catch (ApiException) { await MarkFailedAsync(claim, "permission_changed", ct); return; }
        if (permissionStamp != snapshot.PermissionStamp) { await MarkFailedAsync(claim, "permission_changed", ct); return; }

        var configuration=await AdministratorConfiguration.ReadAsync(db,ct);
        var query = AdministratorConfiguration.ApplyDiscoveryPolicy(configuration,JsonSerializer.Deserialize<DiscoveryQuery>(snapshot.QueryJson) ?? throw new InvalidDataException());
        ProviderInfo[] allProviders;
        try { allProviders = await prowlarr.ProvidersAsync(ct); }
        catch (ProwlarrFailure) { await PersistOutageAsync(db, access, actor, claim, snapshot, query, "providers_unavailable", ct); return; }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch { await PersistOutageAsync(db, access, actor, claim, snapshot, query, "providers_unavailable", ct); return; }

        var warnings = new HashSet<string>(StringComparer.Ordinal);
        var requestedIds = query.ProviderIds ?? [];
        var providers = allProviders.Where(x => x.Enabled && AdministratorConfiguration.ProviderAllowed(configuration,x.Id) && (configuration["enabledCategoryIds"] is not System.Text.Json.Nodes.JsonArray categories || categories.Count>0) && (requestedIds.Length == 0 || requestedIds.Contains(x.Id, StringComparer.Ordinal)))
            .OrderBy(x => x.Id, StringComparer.Ordinal).Take(QueryRules.MaxProviders).ToArray();
        foreach (var missingId in requestedIds.Where(id => !providers.Any(x => x.Id == id)))
            warnings.Add("provider_unavailable:" + DiscoveryQueries.SafeLabel(missingId, 128));

        var recentFeed = query.Mode == "latest" || query.Mode == "mostSeeded" && string.IsNullOrWhiteSpace(query.Query);
        var eligible = new List<ProviderInfo>();
        foreach (var provider in providers)
        {
            if (recentFeed && !provider.SupportsRecent)
            {
                warnings.Add("recent_unsupported:" + DiscoveryQueries.SafeLabel(provider.Id, 128));
                continue;
            }
            if (!recentFeed && !provider.SupportsSearch)
            {
                warnings.Add("search_unsupported:" + DiscoveryQueries.SafeLabel(provider.Id, 128));
                continue;
            }
            eligible.Add(provider);
        }
        if (eligible.Count == 0 && providers.Length == 0) warnings.Add("no_enabled_providers");

        var search = new ProwlarrSearch(recentFeed ? "latest" : "search",
            query.Query ?? "", query.Categories ?? []);
        var observedAt = clock.GetUtcNow();
        var aggregate = new List<AggregateRelease>();
        var providerTruncated = false;
        var failedProviders = false;
        var successfulProviders = 0;
        foreach (var providerBatch in eligible.Chunk(2))
        {
            var fetched = await Task.WhenAll(providerBatch.Select(provider => FetchProviderAsync(provider, search, ct)));
            foreach (var batch in fetched.OrderBy(x => x.Provider.Id, StringComparer.Ordinal))
            {
                if (batch.ErrorCode is not null)
                {
                    failedProviders = true;
                    warnings.Add("provider_failed:" + DiscoveryQueries.SafeLabel(batch.Provider.Id, 128) + ":" + batch.ErrorCode);
                    continue;
                }
                if (batch.Results is null) continue;
                successfulProviders++;
                if (batch.Results.Provider.Id != batch.Provider.Id)
                {
                    warnings.Add("provider_failed:" + DiscoveryQueries.SafeLabel(batch.Provider.Id, 128) + ":invalid_response");
                    failedProviders = true;
                    successfulProviders--;
                    continue;
                }
                var health = batch.Results.Provider;
                var healthWarning = SafeHealthWarning(health.Warning, health.State);
                if (healthWarning is not null || health.State is "degraded" or "unavailable")
                {
                    failedProviders = true;
                    warnings.Add("provider_health:" + DiscoveryQueries.SafeLabel(batch.Provider.Id, 128) + ":" +
                        (healthWarning ?? (health.State == "unavailable" ? "provider_unavailable" : "provider_degraded")));
                    if (health.State == "unavailable" && (batch.Results.Releases?.Length ?? 0) == 0)
                        successfulProviders--;
                }
                providerTruncated |= batch.Results.Truncated;
                var releases = batch.Results.Releases ?? [];
                if (releases.Length > QueryRules.MaxSnapshotResults) { providerTruncated = true; releases = releases.Take(QueryRules.MaxSnapshotResults).ToArray(); }
                foreach (var release in releases.OrderBy(x => x.SourceGuid, StringComparer.Ordinal))
                {
                    var normalized = NormalizeRelease(batch.Provider, release, observedAt, warnings);
                    if (normalized is null) { warnings.Add("invalid_release"); continue; }
                    if (!QueryRules.Matches(query, normalized)) continue;
                    var same = aggregate.FirstOrDefault(x => SameTorrent(x.Value, normalized) ||
                        (!HasValidHash(x.Value) || !HasValidHash(normalized)) && x.Value.SourceId == normalized.SourceId && x.Value.SourceGuid == normalized.SourceGuid);
                    if (same is null)
                    {
                        if (aggregate.Count < QueryRules.MaxSnapshotResults)
                            aggregate.Add(new AggregateRelease(normalized, ReadOptions(normalized.EncryptedResolutionJson)));
                        else providerTruncated = true;
                    }
                    else if (same.Merge(normalized, ReadOptions(normalized.EncryptedResolutionJson), secrets))
                        warnings.Add("resolution_alternative_limit");
                }
            }
        }

        var ordered = QueryRules.Sort(aggregate.Select(x => x.ToRelease(secrets)), query);
        var truncated = providerTruncated || ordered.Length > QueryRules.MaxSnapshotResults;
        var selected = ordered.Take(QueryRules.MaxSnapshotResults).ToArray();
        string finalState;
        if (selected.Length == 0 && failedProviders && successfulProviders == 0)
        {
            if (await CopyStaleResultsAsync(db, snapshot, query, warnings, observedAt, ct)) finalState = "partial";
            else finalState = "failed";
        }
        else finalState = failedProviders || warnings.Count > 0 || providerTruncated ? "partial" : "complete";

        permissionStamp = await access.RequireAsync(actor, ct);
        if (permissionStamp != snapshot.PermissionStamp) { await MarkFailedAsync(claim, "permission_changed", ct); return; }
        using (await writeGate.EnterAsync(ct))
        {
            var currentJob = await db.Jobs.SingleOrDefaultAsync(x => x.Id == claim.JobId && x.State == "running" && x.LeaseOwner == leaseOwner, ct);
            if (currentJob is null) return;
            if (finalState != "failed")
            {
                foreach (var item in selected)
                    db.DiscoveryResults.Add(new DiscoveryResult
                    {
                        SnapshotId = snapshot.Id, SourceId = item.SourceId, SourceName = item.SourceName,
                        SourceGuid = item.SourceGuid, Title = item.Title, Bytes = item.Bytes,
                        Seeders = item.Seeders, Leechers = item.Leechers, PeersTotal = item.Peers,
                        PublishedAt = item.PublishedAt, ObservedAt = item.ObservedAt,
                        InfoHashV1 = item.InfoHashV1, InfoHashV2 = item.InfoHashV2,
                        CategoriesJson = JsonSerializer.Serialize(item.Categories),
                        EncryptedResolutionJson = item.EncryptedResolutionJson, CanDownload = item.CanDownload
                    });
            }
            snapshot.State = finalState; snapshot.FetchedAt = observedAt; snapshot.Truncated = truncated;
            snapshot.WarningsJson = JsonSerializer.Serialize(warnings.Order(StringComparer.Ordinal).ToArray());
            currentJob.State = "completed"; currentJob.DedupKey = null; currentJob.LeaseOwner = null;
            currentJob.LeaseUntil = null; currentJob.Progress = 1; currentJob.UpdatedAt = observedAt;
            await UpdateOperationsAsync(db, snapshot.Id, finalState, observedAt, ct);
            await db.SaveChangesAsync(ct);
        }
    }

    private async Task<ProviderFetch> FetchProviderAsync(ProviderInfo provider, ProwlarrSearch query, CancellationToken ct)
    {
        await ProviderSlots.WaitAsync(ct);
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(ProviderTimeout);
            try
            {
                var results = await prowlarr.SearchAsync(provider, query, timeout.Token);
                return new(provider, results, null);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch (OperationCanceledException) { return new(provider, null, "timeout"); }
            catch (ProwlarrFailure failure) { return new(provider, null, SafeFailureCode(failure.Code)); }
            catch { return new(provider, null, "invalid_response"); }
        }
        finally { ProviderSlots.Release(); }
    }

    private static string SafeFailureCode(string code) => code switch
    {
        "timeout" or "provider_timeout" => "timeout",
        "dependency_unavailable" or "provider_unavailable" => "unavailable",
        "rate_limited" => "rate_limited",
        _ => "invalid_response"
    };

    private static string? SafeHealthWarning(string? warning, string state) => warning switch
    {
        "provider_temporarily_disabled" => "provider_temporarily_disabled",
        "provider_recent_failure" => "provider_recent_failure",
        "recent_unsupported" => "recent_unsupported",
        "contact_verified" => null,
        _ when state is "degraded" => "provider_degraded",
        _ when state is "unavailable" => "provider_unavailable",
        null => null,
        _ => "provider_degraded"
    };

    private NormalizedRelease? NormalizeRelease(ProviderInfo provider, ProwlarrRelease release, DateTimeOffset observedAt,
        HashSet<string> warnings)
    {
        var title = DiscoveryQueries.SafeLabel(release.Title, 500);
        if (title == "unknown" || string.IsNullOrWhiteSpace(release.SourceGuid)) return null;
        var guid = release.SourceGuid.Trim();
        if (guid.Length > 4096 || guid.Any(char.IsControl)) return null;
        var v1 = NormalizeHash(release.InfoHashV1, 40);
        var v2 = NormalizeHash(release.InfoHashV2, 64);
        var categories = (release.Categories ?? []).Where(x => x >= 0).Distinct().Take(QueryRules.MaxCategories).Order().ToArray();
        var canDownload = !string.IsNullOrWhiteSpace(release.MagnetUri) || !string.IsNullOrWhiteSpace(release.DownloadUrl);
        var resolution = canDownload ? new[] { new ResolutionOption(provider.Id, guid, release.DownloadUrl, release.MagnetUri, v1, v2) } : [];
        var resolutionJson = JsonSerializer.Serialize(resolution);
        if (Encoding.UTF8.GetByteCount(resolutionJson) > QueryRules.MaxResolutionPlaintextBytes)
        {
            warnings.Add("resolution_oversized");
            resolution = [];
            canDownload = false;
            resolutionJson = "[]";
        }
        var encrypted = secrets.Encrypt(resolutionJson);
        var safeId = DiscoveryQueries.SafeLabel(provider.Id, 128);
        return new NormalizedRelease(Guid.NewGuid(), safeId, DiscoveryQueries.SafeLabel(provider.Name, 128),
            secrets.Digest("discovery-source-guid:" + provider.Id + ":" + guid), title,
            release.SizeBytes is >= 0 ? release.SizeBytes : null,
            release.Seeders is >= 0 ? release.Seeders : null,
            release.Leechers is >= 0 ? release.Leechers : null,
            QueryRules.PeersTotal(release.Seeders is >= 0 ? release.Seeders : null,
                release.Leechers is >= 0 ? release.Leechers : null),
            release.PublishedAt, observedAt, v1, v2, categories, encrypted, canDownload);
    }

    private static string? NormalizeHash(string? value, int length)
    {
        if (value is null) return null;
        var hash = value.Trim();
        return hash.Length == length && hash.All(Uri.IsHexDigit) ? hash.ToLowerInvariant() : null;
    }

    private static bool HasValidHash(NormalizedRelease x) => x.InfoHashV1 is not null || x.InfoHashV2 is not null;

    private static bool SameTorrent(NormalizedRelease a, NormalizedRelease b)
    {
        if (!HasValidHash(a) || !HasValidHash(b)) return false;
        if (a.InfoHashV1 is not null && b.InfoHashV1 is not null && a.InfoHashV1 != b.InfoHashV1) return false;
        if (a.InfoHashV2 is not null && b.InfoHashV2 is not null && a.InfoHashV2 != b.InfoHashV2) return false;
        return a.InfoHashV1 is not null && a.InfoHashV1 == b.InfoHashV1 ||
               a.InfoHashV2 is not null && a.InfoHashV2 == b.InfoHashV2;
    }

    private ResolutionOption[] ReadOptions(string encrypted)
    {
        if (string.IsNullOrEmpty(encrypted)) return [];
        try { return JsonSerializer.Deserialize<ResolutionOption[]>(secrets.Decrypt(encrypted)) ?? []; }
        catch (JsonException) { return []; }
    }

    private sealed record ResolutionOption(string ProviderId, string SourceGuid, string? DownloadUrl,
        string? MagnetUri, string? InfoHashV1, string? InfoHashV2);

    private sealed class AggregateRelease(NormalizedRelease value, ResolutionOption[] options)
    {
        public NormalizedRelease Value { get; private set; } = value;
        private readonly List<ResolutionOption> options = [.. options];
        public bool Merge(NormalizedRelease other, ResolutionOption[] more, SecretStore secrets)
        {
            var omitted = false;
            foreach (var option in more)
            {
                if (options.Any(x => x.ProviderId == option.ProviderId && x.SourceGuid == option.SourceGuid &&
                    x.DownloadUrl == option.DownloadUrl && x.MagnetUri == option.MagnetUri)) continue;
                var candidate = options.Append(option).ToArray();
                var candidateJson = JsonSerializer.Serialize(candidate);
                if (options.Count >= QueryRules.MaxResolutionAlternatives ||
                    Encoding.UTF8.GetByteCount(candidateJson) > QueryRules.MaxResolutionPlaintextBytes)
                {
                    omitted = true;
                    continue;
                }
                options.Add(option);
            }
            Value = Value with
            {
                Categories = Value.Categories.Union(other.Categories).Distinct().Order().ToArray(),
                CanDownload = options.Count > 0,
                EncryptedResolutionJson = secrets.Encrypt(JsonSerializer.Serialize(options.ToArray()))
            };
            return omitted;
        }
        public NormalizedRelease ToRelease(SecretStore secrets)
        {
            if (Value.EncryptedResolutionJson.Length == 0 || options.Count == 0)
                return Value with { CanDownload = false };
            return Value with { EncryptedResolutionJson = secrets.Encrypt(JsonSerializer.Serialize(options.ToArray())), CanDownload = true };
        }
    }

    private async Task<bool> CopyStaleResultsAsync(BrianiDb db, DiscoverySnapshot target, DiscoveryQuery query,
        HashSet<string> warnings, DateTimeOffset now, CancellationToken ct)
    {
        var previous = await db.DiscoverySnapshots.AsNoTracking().Where(x => x.UserId == target.UserId &&
                x.PermissionStamp == target.PermissionStamp && x.QueryKey == target.QueryKey && x.Id != target.Id &&
                x.ExpiresAt > now && (x.State == "complete" || x.State == "partial"))
            .OrderByDescending(x => x.FetchedAt).FirstOrDefaultAsync(ct);
        if (previous is null) return false;
        var rows = await db.DiscoveryResults.AsNoTracking().Where(x => x.SnapshotId == previous.Id)
            .Take(QueryRules.MaxSnapshotResults).ToArrayAsync(ct);
        if (rows.Length == 0) return false;
        foreach (var row in rows)
            db.DiscoveryResults.Add(new DiscoveryResult
            {
                SnapshotId = target.Id, SourceId = row.SourceId, SourceName = row.SourceName, SourceGuid = row.SourceGuid,
                Title = row.Title, Bytes = row.Bytes, Seeders = row.Seeders, Leechers = row.Leechers,
                PeersTotal = row.PeersTotal, PublishedAt = row.PublishedAt, ObservedAt = row.ObservedAt,
                InfoHashV1 = row.InfoHashV1, InfoHashV2 = row.InfoHashV2, CategoriesJson = row.CategoriesJson,
                EncryptedResolutionJson = row.EncryptedResolutionJson, CanDownload = row.CanDownload
            });
        warnings.Add("stale_results");
        return true;
    }

    private async Task PersistOutageAsync(BrianiDb db, DiscoveryAccess access, Actor actor, JobClaim claim,
        DiscoverySnapshot snapshot, DiscoveryQuery query, string warning, CancellationToken ct)
    {
        var warnings = new HashSet<string>(StringComparer.Ordinal) { warning };
        string state;
        if (await access.RequireAsync(actor, ct) == snapshot.PermissionStamp &&
            await CopyStaleResultsAsync(db, snapshot, query, warnings, clock.GetUtcNow(), ct)) state = "partial";
        else state = "failed";
        snapshot.State = state; snapshot.FetchedAt = clock.GetUtcNow();
        snapshot.WarningsJson = JsonSerializer.Serialize(warnings.Order(StringComparer.Ordinal).ToArray());
        await CompleteJobAsync(db, claim, state, ct);
    }

    private async Task MarkFailedAsync(JobClaim claim, string warning, CancellationToken ct)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        using (await writeGate.EnterAsync(ct))
        {
            var snapshot = await db.DiscoverySnapshots.SingleOrDefaultAsync(x => x.Id == claim.SnapshotId, ct);
            if (snapshot is not null)
            {
                snapshot.State = "failed"; snapshot.FetchedAt = clock.GetUtcNow();
                snapshot.WarningsJson = JsonSerializer.Serialize(new[] { warning });
                await UpdateOperationsAsync(db, snapshot.Id, "failed", clock.GetUtcNow(), ct);
            }
            var job = await db.Jobs.SingleOrDefaultAsync(x => x.Id == claim.JobId && x.LeaseOwner == leaseOwner, ct);
            if (job is not null) { job.State = "completed"; job.DedupKey = null; job.LeaseOwner = null; job.LeaseUntil = null; job.UpdatedAt = clock.GetUtcNow(); }
            await db.SaveChangesAsync(ct);
        }
    }

    private async Task CompleteJobAsync(BrianiDb db, JobClaim claim, string? state, CancellationToken ct)
    {
        using (await writeGate.EnterAsync(ct))
        {
            var job = await db.Jobs.SingleOrDefaultAsync(x => x.Id == claim.JobId && x.LeaseOwner == leaseOwner, ct);
            if (job is not null) { job.State = "completed"; job.DedupKey = null; job.LeaseOwner = null; job.LeaseUntil = null; job.Progress = 1; job.UpdatedAt = clock.GetUtcNow(); }
            if (state is not null) await UpdateOperationsAsync(db, claim.SnapshotId, state, clock.GetUtcNow(), ct);
            await db.SaveChangesAsync(ct);
        }
    }

    private static async Task UpdateOperationsAsync(BrianiDb db, Guid snapshotId, string state,
        DateTimeOffset now, CancellationToken ct)
    {
        var operations = await db.Operations.Where(x => x.Kind == "discovery.query" && x.TargetId == snapshotId).ToListAsync(ct);
        foreach (var operation in operations) { operation.State = state; operation.UpdatedAt = now; }
    }

    private async Task RenewLeaseAsync(Guid jobId, CancellationToken ct)
    {
        while (true)
        {
            await Task.Delay(TimeSpan.FromSeconds(30), clock, ct);
            using var scope = scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
            using (await writeGate.EnterAsync(ct))
            {
                var job = await db.Jobs.SingleOrDefaultAsync(x => x.Id == jobId && x.State == "running" && x.LeaseOwner == leaseOwner, ct);
                if (job is null) return;
                job.LeaseUntil = clock.GetUtcNow().Add(LeaseDuration); job.UpdatedAt = clock.GetUtcNow(); await db.SaveChangesAsync(ct);
            }
        }
    }

    private static UserSlot? TryAcquireUserSlot(Guid userId)
    {
        lock (UserSlotsGate)
        {
            if (!UserSlots.TryGetValue(userId, out var slot)) UserSlots[userId] = slot = new UserSlot();
            if (!slot.Semaphore.Wait(0)) return null;
            slot.References++;
            return slot;
        }
    }

    private static void ReleaseUserSlot(Guid userId, UserSlot slot)
    {
        lock (UserSlotsGate)
        {
            slot.Semaphore.Release();
            if (--slot.References == 0 && UserSlots.TryGetValue(userId, out var current) && ReferenceEquals(current, slot))
                UserSlots.Remove(userId);
        }
    }

    private sealed class UserSlot { public SemaphoreSlim Semaphore { get; } = new(1, 1); public int References { get; set; } }
    private sealed record ProviderFetch(ProviderInfo Provider, ProviderResults? Results, string? ErrorCode);
    private sealed record JobClaim(Guid JobId, Guid SnapshotId, Guid UserId, UserSlot UserSlot);
    private sealed class SemaphoreRelease(Guid userId, UserSlot slot) : IDisposable { public void Dispose() => ReleaseUserSlot(userId, slot); }
}
