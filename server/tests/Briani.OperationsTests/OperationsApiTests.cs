using System.Net;
using System.Net.Http.Json;
using Briani.IdentityTests;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Modules.Preferences;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Playback;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Data.Sqlite;

namespace Briani.OperationsTests;

public sealed class OperationsApiTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Health_is_admin_only_and_does_not_trigger_upstream_probes()
    {
        using var anonymous = await fixture.Client.GetAsync("/api/v1/admin/health");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);

        using var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        using var response = await client.GetAsync("/api/v1/admin/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var services = await response.Content.ReadFromJsonAsync<ApplicationHealth[]>();
        Assert.NotNull(services);
        Assert.Contains(services, x => x.Service == "database");
        Assert.Contains(services, x => x.Service == "queue");
        Assert.Contains(services, x => x.Service == "storageVolumes");
        Assert.DoesNotContain(services, x => x.Detail?.Contains("http", StringComparison.OrdinalIgnoreCase) == true);
    }

    [Fact]
    public async Task Member_cannot_read_administrator_health()
    {
        using var admin = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new
        {
            username = "operationsmember", displayName = "Operations Member", password = TestPasswords.Member, role = "member"
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        using var login = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            username = "operationsmember", password = TestPasswords.Member, deviceName = "operations-test"
        });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var member = await login.Content.ReadFromJsonAsync<AuthReply>();
        Assert.NotNull(member);
        using var client = IdentityFixture.As(fixture.Client, member.AccessToken);
        using var health = await client.GetAsync("/api/v1/admin/health");
        Assert.Equal(HttpStatusCode.Forbidden, health.StatusCode);
    }

    [Fact]
    public async Task Health_reports_a_missing_mounted_data_root_as_unavailable()
    {
        var data = Path.Combine(fixture.Host.Root, "data");
        var detached = data + ".detached";
        Directory.Move(data, detached);
        try
        {
            using var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
            using var response = await client.GetAsync("/api/v1/admin/health");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var services = await response.Content.ReadFromJsonAsync<ApplicationHealth[]>();
            Assert.NotNull(services);
            Assert.Contains(services, x => x.Service == "data" && x.State == "unavailable");
        }
        finally
        {
            if (Directory.Exists(detached) && !Directory.Exists(data)) Directory.Move(detached, data);
        }
    }

    [Fact]
    public async Task Maintenance_validates_action_and_reuses_idempotency_key()
    {
        using var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        using (var invalid = await client.PostAsJsonAsync("/api/v1/admin/maintenance", new { action = "deleteEverything" }))
            Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);

        var snapshotDir = Path.Combine(fixture.Host.Root, "state", "snapshots");
        Directory.CreateDirectory(snapshotDir);
        for (var i = 0; i < 6; i++)
            await File.WriteAllBytesAsync(Path.Combine(snapshotDir, $"briani-20000101T00000{i}000Z-{i:D32}.sqlite"), []);

        using var firstRequest = new HttpRequestMessage(HttpMethod.Post, "/api/v1/admin/maintenance")
        {
            Content = JsonContent.Create(new { action = "databaseSnapshot" })
        };
        firstRequest.Headers.Add("Idempotency-Key", "operations-test-key");
        using var first = await client.SendAsync(firstRequest);
        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);
        var one = await first.Content.ReadFromJsonAsync<JobReply>();
        Assert.NotNull(one);

        var worker = fixture.Host.Services.GetRequiredService<ApplicationOperationsWorker>();
        Assert.True(await worker.RunOnceAsync());
        var persisted = await fixture.Host.InDb(db => db.Jobs.AsNoTracking().SingleAsync(x => x.Id == one.Id));
        Assert.Equal("completed", persisted.State);
        var snapshotFiles = Directory.GetFiles(snapshotDir, "*.sqlite");
        Assert.Equal(5, snapshotFiles.Length);
        Assert.Empty(Directory.GetFiles(snapshotDir, "*.tmp"));
        if (!OperatingSystem.IsLinux()) throw new PlatformNotSupportedException("Operations host requires Linux file-mode checks.");
        var latestSnapshot = snapshotFiles.OrderByDescending(x => x, StringComparer.Ordinal).First();
        Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite,
            File.GetUnixFileMode(latestSnapshot) & (UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.GroupRead |
                UnixFileMode.GroupWrite | UnixFileMode.OtherRead | UnixFileMode.OtherWrite));
        await using var restored = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = latestSnapshot, Mode = SqliteOpenMode.ReadOnly, Pooling = false
        }.ToString());
        await restored.OpenAsync();
        await using var verify = restored.CreateCommand();
        verify.CommandText = "SELECT count(*) FROM users";
        Assert.True(Convert.ToInt32(await verify.ExecuteScalarAsync()) >= 1);

        using var retryRequest = new HttpRequestMessage(HttpMethod.Post, "/api/v1/admin/maintenance")
        {
            Content = JsonContent.Create(new { action = "databaseSnapshot" })
        };
        retryRequest.Headers.Add("Idempotency-Key", "operations-test-key");
        using var retry = await client.SendAsync(retryRequest);
        Assert.Equal(HttpStatusCode.Accepted, retry.StatusCode);
        var two = await retry.Content.ReadFromJsonAsync<JobReply>();
        Assert.Equal(one.Id, two?.Id);

        using var conflictRequest = new HttpRequestMessage(HttpMethod.Post, "/api/v1/admin/maintenance")
        {
            Content = JsonContent.Create(new { action = "pruneThumbnailCache" })
        };
        conflictRequest.Headers.Add("Idempotency-Key", "operations-test-key");
        using var conflict = await client.SendAsync(conflictRequest);
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
    }

    [Fact]
    public async Task Rescan_rejects_unknown_library_and_deduplicates_active_library_scan()
    {
        using var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        using var missing = await client.PostAsJsonAsync("/api/v1/admin/maintenance",
            new { action = "rescanLibraries", libraryId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);

        var libraryId = Guid.NewGuid();
        var scanJobId = Guid.NewGuid();
        var scanDedup = fixture.Host.Services.GetRequiredService<SecretStore>().Digest($"scan-library:{libraryId:D}");
        await fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(new Library
            {
                Id = libraryId, Name = "Ops test", RootPath = "/test", RootIdentity = "1:1:1",
                CreatedAt = fixture.Host.Clock.GetUtcNow(), Enabled = true, Online = true
            });
            db.Jobs.Add(new WorkJob { Id = scanJobId, Kind = "scan", TargetId = libraryId, DedupKey = scanDedup,
                PayloadJson = "{}", State = "queued", CreatedAt = fixture.Host.Clock.GetUtcNow(),
                UpdatedAt = fixture.Host.Clock.GetUtcNow(), NextAttemptAt = fixture.Host.Clock.GetUtcNow() });
            await db.SaveChangesAsync();
            return true;
        });
        using var first = await client.PostAsJsonAsync("/api/v1/admin/maintenance",
            new { action = "rescanLibraries", libraryId });
        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);
        using var secondRequest = new HttpRequestMessage(HttpMethod.Post, "/api/v1/admin/maintenance")
        {
            Content = JsonContent.Create(new { action = "rescanLibraries", libraryId })
        };
        secondRequest.Headers.Add("Idempotency-Key", "rescan-again");
        using var second = await client.SendAsync(secondRequest);
        Assert.Equal(HttpStatusCode.Accepted, second.StatusCode);
        var worker = fixture.Host.Services.GetRequiredService<ApplicationOperationsWorker>();
        Assert.True(await worker.RunOnceAsync());
        Assert.True(await worker.RunOnceAsync());
        var scans = await fixture.Host.InDb(db => db.Jobs.AsNoTracking().CountAsync(x =>
            x.Kind == "scan" && x.TargetId == libraryId && (x.State == "queued" || x.State == "running")));
        Assert.Equal(1, scans);
        Assert.True(await fixture.Host.InDb(db => db.Jobs.AsNoTracking().AnyAsync(x => x.Id == scanJobId)));
    }

    [Fact]
    public async Task Thumbnail_prune_deletes_only_owned_inactive_cache_files()
    {
        var statePath = Path.Combine(fixture.Host.Root, "state");
        await File.WriteAllBytesAsync(Path.Combine(statePath, "outside.jpg"), [10, 11, 12]);
        using (var root = new ContainedDirectory(statePath))
        {
            root.CreateDirectory("cache");
            using var cache = root.Directory("cache");
            cache.CreateDirectory("media");
        }
        var cachePath = Path.Combine(statePath, "cache", "media");
        var eligiblePath = Path.Combine(cachePath, "eligible.jpg");
        var activePath = Path.Combine(cachePath, "active.jpg");
        var linkPath = Path.Combine(cachePath, "link.jpg");
        var externalPath = Path.Combine(fixture.Host.Root, "outside.jpg");
        await File.WriteAllBytesAsync(eligiblePath, [1, 2, 3]);
        await File.WriteAllBytesAsync(activePath, [4, 5, 6]);
        await File.WriteAllBytesAsync(externalPath, [7, 8, 9]);
        File.CreateSymbolicLink(linkPath, externalPath);
        var libraryId = Guid.NewGuid();
        var eligibleMedia = Guid.NewGuid();
        var activeMedia = Guid.NewGuid();
        var linkedMedia = Guid.NewGuid();
        var outsideMedia = Guid.NewGuid();
        string eligibleIdentity;
        string activeIdentity;
        string linkIdentity;
        string outsideIdentity;
        using (var root = new ContainedDirectory(statePath))
        {
            using var file = root.OpenFile("cache/media/eligible.jpg"); eligibleIdentity = ContainedDirectory.Inspect(file).Key;
            using var active = root.OpenFile("cache/media/active.jpg"); activeIdentity = ContainedDirectory.Inspect(active).Key;
            using var outside = root.OpenFile("outside.jpg"); outsideIdentity = ContainedDirectory.Inspect(outside).Key;
        }
        linkIdentity = "symlink-is-not-openable";
        await fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(new Library { Id = libraryId, Name = "Cache test", RootPath = "/cache-test", RootIdentity = "1:1:2", CreatedAt = fixture.Host.Clock.GetUtcNow() });
            foreach (var id in new[] { eligibleMedia, activeMedia, linkedMedia, outsideMedia })
                db.MediaItems.Add(new MediaItem { Id = id, LibraryId = libraryId, RelativePath = id.ToString("N"), DisplayName = "fixture.jpg", Kind = "photo" });
            db.ThumbnailEntries.AddRange(
                Thumbnail(eligibleMedia, "cache/media/eligible.jpg", eligibleIdentity),
                Thumbnail(activeMedia, "cache/media/active.jpg", activeIdentity),
                Thumbnail(linkedMedia, "cache/media/link.jpg", linkIdentity),
                Thumbnail(outsideMedia, "outside.jpg", outsideIdentity));
            await db.SaveChangesAsync();
            return true;
        });
        using var activeLease = fixture.Host.Services.GetRequiredService<MediaReaders>().Acquire(Guid.NewGuid(), activeMedia, CancellationToken.None);
        using var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        using var queued = await client.PostAsJsonAsync("/api/v1/admin/maintenance", new { action = "pruneThumbnailCache" });
        Assert.Equal(HttpStatusCode.Accepted, queued.StatusCode);
        Assert.True(await fixture.Host.Services.GetRequiredService<ApplicationOperationsWorker>().RunOnceAsync());
        Assert.False(File.Exists(eligiblePath));
        Assert.True(File.Exists(activePath));
        Assert.True(File.Exists(linkPath));
        Assert.True(File.Exists(externalPath));
        Assert.True(File.Exists(Path.Combine(statePath, "outside.jpg")));
        var remaining = await fixture.Host.InDb(db => db.ThumbnailEntries.AsNoTracking().Select(x => x.MediaItemId).ToArrayAsync());
        Assert.Equal(3, remaining.Length);
        Assert.DoesNotContain(eligibleMedia, remaining);
    }

    [Fact]
    public async Task Configure_engine_job_retries_and_runs_without_holding_write_gate()
    {
        await using var host = new OperationsTestHost();
        var client = host.CreateClient();
        var admin = await IdentityFixture.Bootstrap(client, File.ReadAllText(Path.Combine(host.Root, "state", "bootstrap.code")),
            "engineadmin", "Engine Admin", TestPasswords.Root);
        var now = host.Clock.GetUtcNow();
        var jobId = Guid.NewGuid();
        await host.InDb(async db =>
        {
            db.Jobs.Add(new WorkJob { Id = jobId, Kind = "configureEngine", State = "queued", TargetId = Guid.Empty,
                CreatedAt = now, UpdatedAt = now, NextAttemptAt = now });
            await db.SaveChangesAsync();
            return true;
        });
        var worker = host.Services.GetRequiredService<ApplicationOperationsWorker>();
        Assert.True(await worker.RunOnceAsync());
        var retry = await host.InDb(db => db.Jobs.AsNoTracking().SingleAsync(x => x.Id == jobId));
        Assert.Equal("queued", retry.State);
        Assert.Equal(1, retry.Attempt);
        Assert.Equal("maintenance_failed", retry.LastErrorCode);
        Assert.Equal(1, host.Engine.Calls);

        host.Clock.Advance(TimeSpan.FromSeconds(20));
        Assert.True(await worker.RunOnceAsync());
        var completed = await host.InDb(db => db.Jobs.AsNoTracking().SingleAsync(x => x.Id == jobId));
        Assert.Equal("completed", completed.State);
        Assert.Equal(2, completed.Attempt);
        Assert.Equal(2, host.Engine.Calls);
    }

    private ThumbnailEntry Thumbnail(Guid mediaId, string path, string identity) => new()
    {
        MediaItemId = mediaId, Generation = 1, Variant = "default", CacheRelativePath = path,
        FileIdentity = identity, Bytes = 3, CreatedAt = fixture.Host.Clock.GetUtcNow(),
        LastAccessedAt = fixture.Host.Clock.GetUtcNow().AddDays(-1)
    };

    private sealed record ApplicationHealth(string Service, string State, string? Detail, DateTimeOffset CheckedAt);
    private sealed record JobReply(Guid Id, string Kind, string State, double? Progress, object? Error,
        DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);
    [Fact]
    public async Task Settings_changed_during_engine_apply_are_requeued_without_losing_the_latest_version()
    {
        await using var host = new OperationsTestHost();
        using var client=host.CreateClient();
        var auth=await IdentityFixture.Bootstrap(client,File.ReadAllText(Path.Combine(host.Root,"state","bootstrap.code")),"raceadmin","Race Admin",TestPasswords.Root);
        IdentityFixture.As(client,auth.AccessToken);
        host.Engine.FailFirst=false;
        (await client.PutAsJsonAsync("/api/v1/admin/settings",new{version=1,activeDownloads=3})).EnsureSuccessStatusCode();
        host.Engine.DuringConfigure=async ct=>{
            host.Engine.DuringConfigure=null;
            (await client.PutAsJsonAsync("/api/v1/admin/settings",new{version=2,activeDownloads=4},ct)).EnsureSuccessStatusCode();
        };
        var worker=host.Services.GetRequiredService<ApplicationOperationsWorker>();
        Assert.True(await worker.RunOnceAsync());
        Assert.Equal("queued",await host.InDb(db=>db.Jobs.Where(x=>x.Kind=="configureEngine").Select(x=>x.State).SingleAsync()));
        Assert.True(await worker.RunOnceAsync());
        Assert.Equal("completed",await host.InDb(db=>db.Jobs.Where(x=>x.Kind=="configureEngine").Select(x=>x.State).SingleAsync()));
        Assert.Equal(2,host.Engine.Calls);
    }

}

internal sealed class OperationsTestHost : WebApplicationFactory<Program>
{
    public string Root { get; } = Path.Combine(Path.GetTempPath(), "briani-operations-worker-" + Guid.NewGuid());
    public ManualClock Clock { get; } = new(new DateTimeOffset(2026, 1, 2, 3, 4, 5, TimeSpan.Zero));
    public FailingOnceTorrentEngine Engine { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Briani:StateRoot"] = Path.Combine(Root, "state"), ["Briani:DataRoot"] = Path.Combine(Root, "data"),
            ["Briani:BackgroundDownloads"] = "false", ["Briani:BackgroundDiscovery"] = "false",
            ["Briani:BackgroundMediaOperations"] = "false", ["MediaProcessing:BackgroundScansEnabled"] = "false"
        }));
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<TimeProvider>().AddSingleton<TimeProvider>(Clock);
            services.RemoveAll<ITorrentEngine>().AddSingleton<ITorrentEngine>(sp => Engine.WithGate(sp.GetRequiredService<WriteGate>()));
        });
    }

    public async Task<T> InDb<T>(Func<BrianiDb, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<BrianiDb>());
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(Root)) Directory.Delete(Root, true);
    }
}

internal sealed class FailingOnceTorrentEngine : ITorrentEngine
{
    private WriteGate? gate;
    public int Calls { get; private set; }
    public bool FailFirst {get;set;}=true;
    public Func<CancellationToken,Task>? DuringConfigure {get;set;}
    public FailingOnceTorrentEngine WithGate(WriteGate writeGate) { gate = writeGate; return this; }
    public async Task ConfigureManagedAsync(CancellationToken ct = default)
    {
        Calls++;
        using (await gate!.EnterAsync(ct)) { }
        if (DuringConfigure is not null) await DuringConfigure(ct);
        if (FailFirst && Calls == 1) throw new EngineFailure("temporary_failure");
    }
    public Task<EngineVersion> VersionAsync(CancellationToken ct = default) => throw new NotImplementedException();
    public Task<EngineTorrent[]> TorrentsAsync(string? hash = null, CancellationToken ct = default) => throw new NotImplementedException();
    public Task<EngineFile[]> FilesAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task<byte[]> ExportAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task<byte[]> PiecesAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task<EngineTracker[]> TrackersAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task AddAsync(EngineAdd add, CancellationToken ct = default) => throw new NotImplementedException();
    public Task StopAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task StartAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task EnsureSequentialAsync(string hash, bool enabled, CancellationToken ct = default) => throw new NotImplementedException();
    public Task EnsureMetadataAssistAsync(string hash, bool enabled, CancellationToken ct = default) => throw new NotImplementedException();
    public Task SetFilePriorityAsync(string hash, int[] indexes, int priority, CancellationToken ct = default) => throw new NotImplementedException();
    public Task ApplyLimitsAsync(string hash, EngineLimits limits, CancellationToken ct = default) => throw new NotImplementedException();
    public Task RecheckAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task ReannounceAsync(string hash, CancellationToken ct = default) => throw new NotImplementedException();
    public Task RemoveAsync(string hash, bool deleteFiles, CancellationToken ct = default) => throw new NotImplementedException();
}
