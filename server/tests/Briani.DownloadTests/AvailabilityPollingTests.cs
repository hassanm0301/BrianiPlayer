using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Briani.DownloadTests;

public sealed class AvailabilityPollingTests
{
    [Fact]
    public async Task Held_refresh_semaphore_returns_retryable_http_problem_and_releases_reader_lease()
    {
        await using var fixture = await LifecycleFixture.Create(testServices: services =>
        {
            services.RemoveAll<ProgressivePlayback>();
            services.AddScoped(provider =>
            {
                var playback = ActivatorUtilities.CreateInstance<ProgressivePlayback>(provider);
                playback.FirstByteTimeout = TimeSpan.FromMilliseconds(150);
                return playback;
            });
        });
        await SeedReadyTorrent(fixture);
        var session = await CreateDownloadSession(fixture);
        Assert.NotNull(session.StreamUrl);
        var availability = fixture.Services.GetRequiredService<TorrentAvailability>();
        using var heldSubscription = availability.Subscribe(fixture.Engine.JobId);
        await heldSubscription.Source.Fetch.WaitAsync();
        try
        {
            using var response = await fixture.Client.GetAsync(session.StreamUrl);
            Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
            Assert.Equal("2", response.Headers.RetryAfter?.ToString());
            using var problem = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            Assert.Equal(2, problem.RootElement.GetProperty("retryAfterSeconds").GetInt32());
            Assert.Equal("waiting_for_data", problem.RootElement.GetProperty("code").GetString());
        }
        finally
        {
            heldSubscription.Source.Fetch.Release();
        }
        Assert.False(fixture.Services.GetRequiredService<MediaReaders>().HasReaders(fixture.Engine.FileId));
    }

    [Fact]
    public void Availability_current_fences_old_engine_epoch_until_new_snapshot_is_published()
    {
        var engine = new EpochEngine();
        var entry = new TorrentAvailability.Entry(Guid.NewGuid(), engine);
        var now = DateTimeOffset.UtcNow;
        entry.Source.Publish(new("old-generation", now, true, [2], engine.ConnectionGeneration));
        Assert.True(entry.Current!.Healthy);

        engine.ConnectionGeneration = 1;
        var invalid = entry.Current;
        Assert.NotNull(invalid);
        Assert.False(invalid.Healthy);
        Assert.Empty(invalid.CopyStates());

        entry.Source.Publish(new("fresh-generation", now, true, [2], engine.ConnectionGeneration));
        Assert.True(entry.Current!.Healthy);
        Assert.Equal("fresh-generation", entry.Current.Generation);

        engine.ConnectionGeneration = 2;
        Assert.False(entry.Current!.Healthy);
    }

    [Fact]
    public async Task Availability_cache_evicts_idle_lifetime_entries_and_never_reuses_the_evicted_incarnation()
    {
        await using var fixture = await LifecycleFixture.Create();
        var availability = fixture.Services.GetRequiredService<TorrentAvailability>();
        var firstId = Guid.NewGuid();
        TorrentAvailability.Entry original;
        using (var first = availability.Subscribe(firstId)) original = first.Source;
        var job = new TorrentJob { Id = firstId };
        var oldGeneration = availability.Generation(job, original);

        for (var index = 1; index < 512; index++)
        {
            using var subscription = availability.Subscribe(Guid.NewGuid());
        }

        using (var overflow = availability.Subscribe(Guid.NewGuid()))
        using (var reopened = availability.Subscribe(firstId))
        {
            Assert.NotSame(original, reopened.Source);
            Assert.NotEqual(oldGeneration, availability.Generation(job, reopened.Source));
        }
    }

    [Fact]
    public async Task Shared_playback_cap_ignores_expired_rows_then_blocks_progressive_session_at_64_live_sessions()
    {
        await using var fixture = await LifecycleFixture.Create();
        await SeedReadyTorrent(fixture);
        var now = fixture.Clock.GetUtcNow();
        await fixture.InDb(async db =>
        {
            for (var index = 0; index < 63; index++) db.PlaybackSessions.Add(PlaybackRow(fixture, now, index));
            db.PlaybackSessions.Add(PlaybackRow(fixture, now, 1000, firstUse: now.AddSeconds(-1)));
            db.PlaybackSessions.Add(PlaybackRow(fixture, now, 1001, activatedAt: now.AddMinutes(-31), lastActivityAt: now.AddMinutes(-31)));
            db.PlaybackSessions.Add(PlaybackRow(fixture, now, 1002, absoluteExpiry: now.AddSeconds(-1)));
            await db.SaveChangesAsync();
            return 0;
        });

        var mediaId = await SeedPhysicalMedia(fixture);
        using (var completed = await fixture.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "media", id = mediaId }, mode = "internal", initialPositionMs = 0
        })) Assert.Equal(HttpStatusCode.Created, completed.StatusCode);

        using var progressive = await fixture.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "downloadFile", id = fixture.Engine.FileId }, mode = "internal", initialPositionMs = 0
        });
        Assert.Equal(HttpStatusCode.TooManyRequests, progressive.StatusCode);
        Assert.Contains("playback_session_limit", await progressive.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        Assert.Equal(64, await fixture.InDb(db => db.PlaybackSessions.CountAsync(x => x.RevokedAt == null && x.AbsoluteExpiresAt > now
            && (x.ActivatedAt == null ? x.FirstUseDeadline > now : x.LastActivityAt != null && x.LastActivityAt > now.AddMinutes(-30)))));
    }

    [Fact]
    public async Task Playback_housekeeping_prunes_first_use_idle_and_hard_expiry_rows_in_batches_of_500()
    {
        await using var fixture = await LifecycleFixture.Create();
        var now = fixture.Clock.GetUtcNow();
        await fixture.InDb(async db =>
        {
            for (var index = 0; index < 501; index++)
            {
                var session = PlaybackRow(fixture, now, 2000 + index);
                switch (index % 3)
                {
                    case 0: session.FirstUseDeadline = now.AddSeconds(-1); break;
                    case 1: session.ActivatedAt = now.AddMinutes(-31); session.LastActivityAt = now.AddMinutes(-31); break;
                    default: session.AbsoluteExpiresAt = now.AddSeconds(-1); break;
                }
                session.CreatedAt = now.AddMinutes(-index);
                db.PlaybackSessions.Add(session);
            }
            db.PlaybackSessions.Add(PlaybackRow(fixture, now, 3000));
            await db.SaveChangesAsync();
            return 0;
        });

        var housekeeper = new IdentityHousekeeping(fixture.Services.GetRequiredService<IServiceScopeFactory>(),
            fixture.Services.GetRequiredService<WriteGate>(), fixture.Clock);
        await housekeeper.PruneAsync();
        Assert.Equal(1, await fixture.InDb(db => db.PlaybackSessions.CountAsync(x => x.UserId == fixture.Admin.User.Id && x.AbsoluteExpiresAt <= now
            || x.UserId == fixture.Admin.User.Id && (x.ActivatedAt == null ? x.FirstUseDeadline <= now : x.LastActivityAt == null || x.LastActivityAt <= now.AddMinutes(-30)))));
        Assert.Equal(1, await fixture.InDb(db => db.PlaybackSessions.CountAsync(x => x.UserId == fixture.Admin.User.Id && x.AbsoluteExpiresAt > now
            && x.FirstUseDeadline > now && x.ActivatedAt == null)));

        await housekeeper.PruneAsync();
        Assert.Equal(0, await fixture.InDb(db => db.PlaybackSessions.CountAsync(x => x.UserId == fixture.Admin.User.Id && x.AbsoluteExpiresAt <= now
            || x.UserId == fixture.Admin.User.Id && (x.ActivatedAt == null ? x.FirstUseDeadline <= now : x.LastActivityAt == null || x.LastActivityAt <= now.AddMinutes(-30)))));
    }

    private static async Task SeedReadyTorrent(LifecycleFixture fixture)
    {
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        fixture.Engine.ConfigureFiles(4, new EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
    }

    private static async Task<PlaybackSessionView> CreateDownloadSession(LifecycleFixture fixture)
    {
        using var response = await fixture.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "downloadFile", id = fixture.Engine.FileId }, mode = "internal", initialPositionMs = 0
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
    }

    private static PlaybackSession PlaybackRow(LifecycleFixture fixture, DateTimeOffset now, int index,
        DateTimeOffset? firstUse = null, DateTimeOffset? activatedAt = null, DateTimeOffset? lastActivityAt = null, DateTimeOffset? absoluteExpiry = null) => new()
    {
        UserId = fixture.Admin.User.Id, AuthSessionId = fixture.Admin.SessionId, TicketHash = index.ToString("X64"),
        TargetGeneration = "fixture", CreatedAt = now.AddMinutes(-1), FirstUseDeadline = firstUse ?? now.AddMinutes(9),
        AbsoluteExpiresAt = absoluteExpiry ?? now.AddHours(24), ActivatedAt = activatedAt, LastActivityAt = lastActivityAt
    };

    private static async Task<Guid> SeedPhysicalMedia(LifecycleFixture fixture)
    {
        const string relative = "admission-video.mp4";
        var bytes = Enumerable.Range(0, 4096).Select(x => (byte)(x % 251)).ToArray();
        await File.WriteAllBytesAsync(Path.Combine(fixture.LibraryPath, relative), bytes);
        NodeIdentity identity;
        using (var root = new ContainedDirectory(fixture.LibraryPath))
        using (var file = root.OpenFile(relative)) identity = ContainedDirectory.Inspect(file);
        var media = new MediaItem
        {
            LibraryId = fixture.LibraryId, RelativePath = relative, DisplayName = relative, SearchKey = relative,
            Kind = "video", Extension = ".mp4", MimeType = "video/mp4", SizeBytes = bytes.Length,
            FileIdentity = identity.Key, MtimeNs = identity.MtimeNs, SourceKind = "physical", Lifecycle = "available",
            CreatedAt = fixture.Clock.GetUtcNow(), IndexedAt = fixture.Clock.GetUtcNow()
        };
        await fixture.InDb(async db =>
        {
            db.MediaItems.Add(media);
            db.MediaMetadata.Add(new MediaMetadata { MediaItemId = media.Id, ProbeStatus = "ready", ContentGeneration = media.Version, Container = "mp4", ProbeVersion = "fixture" });
            await db.SaveChangesAsync();
            return 0;
        });
        return media.Id;
    }

    private sealed class EpochEngine : ITorrentEngine
    {
        public long ConnectionGeneration { get; set; }
        private static NotSupportedException Unsupported() => new("Not used by this bounded generation test.");
        public Task<EngineVersion> VersionAsync(CancellationToken ct = default) => Task.FromException<EngineVersion>(Unsupported());
        public Task<EngineTorrent[]> TorrentsAsync(string? hash = null, CancellationToken ct = default) => Task.FromException<EngineTorrent[]>(Unsupported());
        public Task<EngineFile[]> FilesAsync(string hash, CancellationToken ct = default) => Task.FromException<EngineFile[]>(Unsupported());
        public Task<byte[]> ExportAsync(string hash, CancellationToken ct = default) => Task.FromException<byte[]>(Unsupported());
        public Task<byte[]> PiecesAsync(string hash, CancellationToken ct = default) => Task.FromException<byte[]>(Unsupported());
        public Task<EngineTracker[]> TrackersAsync(string hash, CancellationToken ct = default) => Task.FromException<EngineTracker[]>(Unsupported());
        public Task AddAsync(EngineAdd add, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task StopAsync(string hash, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task StartAsync(string hash, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task EnsureSequentialAsync(string hash, bool enabled, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task EnsureMetadataAssistAsync(string hash, bool enabled, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task SetFilePriorityAsync(string hash, int[] indexes, int priority, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task ApplyLimitsAsync(string hash, EngineLimits limits, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task RecheckAsync(string hash, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task ReannounceAsync(string hash, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task RemoveAsync(string hash, bool deleteFiles, CancellationToken ct = default) => Task.FromException(Unsupported());
        public Task ConfigureManagedAsync(CancellationToken ct = default) => Task.FromException(Unsupported());
    }
}
