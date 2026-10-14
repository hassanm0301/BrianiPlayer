using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class LifecycleApiTests
{
    [Fact]
    public async Task New_download_operation_cap_allows_exact_idempotent_replay_but_rejects_new_operation()
    {
        await using var fixture = await LifecycleFixture.Create();
        var download = await fixture.CreateDownload(fixture.Client, fixture.LibraryId);
        Assert.True(await fixture.Worker.RunOnceAsync());
        var actionKey = "bounded-action";
        using var initialSummary = await fixture.Client.GetAsync($"/api/v1/downloads/{download.Id}");
        var summary = await initialSummary.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        using var first = await SendPause(fixture, download.Id, summary.Version, actionKey);
        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);

        await fixture.InDb(async db =>
        {
            db.Operations.AddRange(Enumerable.Range(0, 127).Select(i => new Operation
            {
                UserId = fixture.Admin.User.Id, Kind = "download-pause", TargetId = download.Id,
                IdempotencyKey = $"seed-{i}", RequestHash = $"hash-{i}", State = "completed",
                CreatedAt = fixture.Clock.GetUtcNow(), UpdatedAt = fixture.Clock.GetUtcNow(), ExpiresAt = fixture.Clock.GetUtcNow().AddDays(1)
            }));
            return await db.SaveChangesAsync();
        });

        using var replay = await SendPause(fixture, download.Id, summary.Version, actionKey);
        Assert.True(replay.StatusCode == HttpStatusCode.Accepted, await replay.Content.ReadAsStringAsync());
        using var refreshedResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{download.Id}");
        var refreshed = await refreshedResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(refreshed);
        using var overLimit = await SendPause(fixture, download.Id, refreshed.Version, "different-action");
        Assert.Equal(HttpStatusCode.TooManyRequests, overLimit.StatusCode);
        Assert.Contains("download_operation_limit", await overLimit.Content.ReadAsStringAsync(), StringComparison.Ordinal);
    }

    [Fact]
    public async Task Stale_torrent_job_context_cannot_overwrite_a_newer_revision()
    {
        await using var fixture = await LifecycleFixture.Create();
        var download = await fixture.CreateDownload(fixture.Client, fixture.LibraryId);
        using var firstScope = fixture.Services.CreateScope();
        using var staleScope = fixture.Services.CreateScope();
        var firstDb = firstScope.ServiceProvider.GetRequiredService<BrianiDb>();
        var staleDb = staleScope.ServiceProvider.GetRequiredService<BrianiDb>();
        var jobId = await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == download.Id).Select(x => x.TorrentJobId!.Value).SingleAsync());
        var first = await firstDb.TorrentJobs.SingleAsync(x => x.Id == jobId);
        var stale = await staleDb.TorrentJobs.SingleAsync(x => x.Id == jobId);

        first.Name = "newer-writer";
        await firstDb.SaveChangesAsync();
        stale.Name = "stale-writer";

        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => staleDb.SaveChangesAsync());
        Assert.Equal("newer-writer", await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.Id == jobId).Select(x => x.Name).SingleAsync()));
    }

    private static Task<HttpResponseMessage> SendPause(LifecycleFixture fixture, Guid id, long version, string key)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/downloads/{id}/actions")
        { Content = System.Net.Http.Json.JsonContent.Create(new { action = "pause", version }) };
        request.Headers.Add("Idempotency-Key", key);
        return fixture.Client.SendAsync(request);
    }

    [Fact]
    public async Task Blocked_tracker_dns_is_bounded_and_stalls_metadata_job_without_releasing_unowned_reservation()
    {
        var dns = new BlockingSafeDns();
        await using var fixture = await LifecycleFixture.Create(dns);
        fixture.Engine.IncludeTrackerInExport = true;
        fixture.Worker.MetadataOperationTimeout = TimeSpan.FromMilliseconds(100);
        var download = await fixture.CreateDownload(fixture.Client, fixture.LibraryId);
        Assert.True(await fixture.Worker.RunOnceAsync());
        var watch = System.Diagnostics.Stopwatch.StartNew();
        await fixture.Worker.PollOnceAsync();
        watch.Stop();

        Assert.True(dns.Calls > 0);
        Assert.True(watch.Elapsed < TimeSpan.FromSeconds(3), $"metadata poll took {watch.Elapsed}");
        var outcome = await fixture.InDb(async db =>
        {
            var request = await db.DownloadRequests.AsNoTracking().SingleAsync(x => x.Id == download.Id);
            var job = await db.TorrentJobs.AsNoTracking().SingleAsync(x => x.Id == request.TorrentJobId);
            return (RequestState: request.State, RequestError: request.ErrorCode, RequestReserved: request.ReservedBytes,
                MetadataStatus: job.MetadataStatus, JobReserved: job.ReservedBytes, JobError: job.ErrorCode);
        });
        Assert.Equal("stalled", outcome.RequestState);
        Assert.Equal("metadata_timeout", outcome.RequestError);
        Assert.Equal(0, outcome.RequestReserved);
        Assert.Equal("failed", outcome.MetadataStatus);
        Assert.Equal(0, outcome.JobReserved);
        Assert.Equal("metadata_timeout", outcome.JobError);
        Assert.Empty(await fixture.Engine.TorrentsAsync(LifecycleFixture.Hash));
    }

    private sealed class BlockingSafeDns : Briani.Api.Infrastructure.Integrations.ISafeDns
    {
        private int calls;
        public int Calls => Volatile.Read(ref calls);
        public async Task<System.Net.IPAddress[]> ResolveAsync(string host, CancellationToken ct)
        {
            Interlocked.Increment(ref calls);
            await Task.Delay(Timeout.InfiniteTimeSpan, ct);
            return [];
        }
    }

    [Fact]
    public async Task Create_reserves_provisional_quota_and_queues_add_without_calling_engine()
    {
        await using var fixture = await LifecycleFixture.Create();
        var view = await fixture.CreateDownload(fixture.Client, fixture.LibraryId, idempotencyKey: "request-one");

        Assert.Equal(0, fixture.Engine.AddCalls);
        var rows = await fixture.InDb(async db =>
        {
            var request = await db.DownloadRequests.AsNoTracking().SingleAsync(x => x.Id == view.Id);
            var job = await db.TorrentJobs.AsNoTracking().SingleAsync(x => x.Id == request.TorrentJobId);
            var work = await db.Jobs.AsNoTracking().Where(x => x.TargetId == db.Operations.Where(o => o.TargetId == request.Id).Select(o => o.Id).Single()).SingleAsync();
            return (RequestReservation: request.ReservedBytes, request.SelectedBytes, JobReservation: job.ReservedBytes, WorkState: work.State);
        });

        Assert.Equal(268_435_456, rows.RequestReservation);
        Assert.Null(rows.SelectedBytes);
        Assert.Equal(268_435_456, rows.JobReservation);
        Assert.Equal("queued", rows.WorkState);
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Equal(1, fixture.Engine.AddCalls);
    }

    [Fact]
    public async Task Selected_file_size_is_checked_against_live_user_quota_before_operation_is_queued()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("quotaowner");
        await fixture.Grant(owner.User.Id, quota: LifecycleFixture.FileBytes / 2);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        var payload = new
        {
            files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "high" } },
            autoStart = true,
            version = 1L
        };

        using var response = await owner.Client.PutAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/selection", payload);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains("quota_exceeded", await response.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        Assert.Equal(0, await fixture.InDb(db => db.Operations.CountAsync(x => x.TargetId == fixture.Engine.RequestId)));
    }

    [Fact]
    public async Task Existing_hash_in_another_library_returns_neutral_conflict()
    {
        await using var fixture = await LifecycleFixture.Create();
        var secondLibrary = await fixture.CreateLibrary("Other library");
        await fixture.CreateDownload(fixture.Client, fixture.LibraryId);
        using var conflict = await fixture.Client.PostAsJsonAsync("/api/v1/downloads", new
        { libraryId = secondLibrary, source = new { kind = "magnet", value = $"magnet:?xt=urn:btih:{LifecycleFixture.Hash}" } });

        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        var body = await conflict.Content.ReadAsStringAsync();
        Assert.Contains("torrent_already_managed", body, StringComparison.Ordinal);
        Assert.DoesNotContain(fixture.LibraryId.ToString(), body, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(1, await fixture.InDb(db => db.TorrentJobs.CountAsync()));
    }

    [Fact]
    public async Task Removing_one_shared_request_preserves_the_other_request_and_engine_torrent()
    {
        await using var fixture = await LifecycleFixture.Create();
        var member = await fixture.CreateUser("sharedowner");
        await fixture.Grant(member.User.Id);
        var first = await fixture.CreateDownload(fixture.Client, fixture.LibraryId);
        Assert.True(await fixture.Worker.RunOnceAsync());
        var second = await fixture.CreateDownload(member.Client, fixture.LibraryId);
        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{first.Id}");
        var current = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(current);

        using var remove = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{first.Id}/actions",
            new { action = "remove", version = current.Version });
        Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());

        Assert.Single(await fixture.Engine.TorrentsAsync(LifecycleFixture.Hash));
        var requests = await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == first.Id || x.Id == second.Id).ToArrayAsync());
        Assert.Contains(requests, x => x.Id == second.Id && x.RemovedAt is null);
        Assert.DoesNotContain(requests, x => x.Id == first.Id && x.RemovedAt is null);
    }

    [Fact]
    public async Task Removing_request_keeps_retained_file_quota_attributed_until_payload_is_removed()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("retainedquota");
        await fixture.Grant(owner.User.Id, quota: LifecycleFixture.FileBytes * 2);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        using (var scope = fixture.Services.CreateScope())
            await scope.ServiceProvider.GetRequiredService<DownloadImport>().ImportAsync(fixture.Engine.JobId, fixture.Engine.FileId);
        await fixture.InDb(async db =>
        {
            db.DownloadOwnerships.Add(new DownloadOwnership { OwnerId = owner.User.Id, LibraryId = fixture.LibraryId, DownloadFileId = fixture.Engine.FileId, Bytes = LifecycleFixture.FileBytes });
            await db.SaveChangesAsync();
            return 0;
        });
        using var summaryResponse = await owner.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        using var remove = await owner.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "remove", version = summary.Version });
        Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());

        var retained = await fixture.InDb(db => db.DownloadOwnerships.AsNoTracking().AnyAsync(x => x.OwnerId == owner.User.Id && x.DownloadFileId == fixture.Engine.FileId));
        Assert.True(retained);
        Assert.True(File.Exists(Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"), "fixture.mp4")));
    }

    [Fact]
    public async Task Queued_autostart_stops_when_owner_grant_is_revoked_before_worker_runs()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("revokedautostart");
        await fixture.Grant(owner.User.Id);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        using var summaryResponse = await owner.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        using var queued = await owner.Client.PutAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/selection", new
        {
            files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "high" } },
            autoStart = true,
            version = summary.Version
        });
        Assert.Equal(HttpStatusCode.Accepted, queued.StatusCode);
        await fixture.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == owner.User.Id && x.LibraryId == fixture.LibraryId);
            db.LibraryGrants.Remove(grant);
            return await db.SaveChangesAsync();
        });

        await fixture.Worker.RunOnceAsync();

        Assert.Equal(0, fixture.Engine.StartCalls);
        Assert.Equal("failed", await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == fixture.Engine.RequestId).Select(x => x.State).SingleAsync()));
    }

    [Fact]
    public async Task Completed_file_cannot_be_deselected_to_bypass_retained_quota_for_another_file()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("switchquota");
        await fixture.Grant(owner.User.Id, quota: LifecycleFixture.FileBytes);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        await fixture.InDb(async db =>
        {
            db.DownloadOwnerships.Add(new DownloadOwnership { OwnerId = owner.User.Id, LibraryId = fixture.LibraryId, DownloadFileId = fixture.Engine.FileId, Bytes = LifecycleFixture.FileBytes });
            db.DownloadFiles.Add(new DownloadFile
            {
                Id = Guid.NewGuid(), TorrentJobId = fixture.Engine.JobId, UpstreamFileIndex = 1, MetadataFileIndex = 1,
                RelativePath = "second.mp4", DisplayName = "second.mp4", SizeBytes = LifecycleFixture.FileBytes,
                TorrentOffset = LifecycleFixture.FileBytes, PieceFirst = 4, PieceLast = 7, Kind = "video", Wanted = false,
                FilePriority = 1, DownloadedBytes = 0, ContiguousBytes = 0, Completed = false, PlaybackState = "notSelected", Version = 1
            });
            await db.SaveChangesAsync();
            return 0;
        });
        var secondFileId = await fixture.InDb(db => db.DownloadFiles.AsNoTracking().Where(x => x.TorrentJobId == fixture.Engine.JobId && x.UpstreamFileIndex == 1).Select(x => x.Id).SingleAsync());
        using var summaryResponse = await owner.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);

        using var selection = await owner.Client.PutAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/selection", new
        {
            files = new[] { new { fileId = fixture.Engine.FileId, selected = false, priority = "normal" }, new { fileId = secondFileId, selected = true, priority = "normal" } },
            autoStart = true,
            version = summary.Version
        });

        Assert.Equal(HttpStatusCode.Conflict, selection.StatusCode);
        Assert.Contains("quota_exceeded", await selection.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        Assert.True(await fixture.InDb(db => db.DownloadOwnerships.AnyAsync(x => x.OwnerId == owner.User.Id && x.DownloadFileId == fixture.Engine.FileId)));
    }

    [Fact]
    public async Task Remove_replays_after_engine_removed_crash_boundary_without_losing_payload()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        using var remove = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "remove", version = summary.Version });
        Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
        var crashOnce = true;
        fixture.Worker.TransactionBoundary = boundary =>
        {
            if (boundary == "engine_removed" && crashOnce) { crashOnce = false; throw new InvalidOperationException("simulated process interruption"); }
        };

        await Assert.ThrowsAsync<InvalidOperationException>(() => fixture.Worker.RunOnceAsync());
        Assert.Empty(await fixture.Engine.TorrentsAsync(LifecycleFixture.Hash));
        Assert.True(File.Exists(Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"), "fixture.mp4")));

        fixture.Clock.Advance(TimeSpan.FromMinutes(2) + TimeSpan.FromSeconds(1));
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.True(File.Exists(Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"), "fixture.mp4")));
        Assert.Equal("removed", await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == fixture.Engine.RequestId).Select(x => x.State).SingleAsync()));
    }

    [Fact]
    public async Task Remove_finds_owned_hybrid_torrent_after_engine_hash_changes_to_v2_identifier()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var savePath = Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"));
        var newEngineHash = new string('a', 40);
        var expectedV2 = new string('b', 64);
        await fixture.InDb(async db =>
        {
            var job = await db.TorrentJobs.SingleAsync(x => x.Id == fixture.Engine.JobId);
            job.InfoHashV2 = expectedV2;
            job.UpstreamId = LifecycleFixture.Hash;
            await db.SaveChangesAsync();
            return 0;
        });
        fixture.Engine.RegisterHybridRehashed(LifecycleFixture.Hash, expectedV2, newEngineHash, savePath);
        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        using var remove = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/downloads/{fixture.Engine.RequestId}/actions")
        { Content = System.Net.Http.Json.JsonContent.Create(new { action = "remove", version = summary.Version }) };
        remove.Headers.Add("Idempotency-Key", "hybrid-rehash-remove");
        using var accepted = await fixture.Client.SendAsync(remove);
        Assert.Equal(HttpStatusCode.Accepted, accepted.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Empty(await fixture.Engine.TorrentsAsync());
        Assert.Equal("removed", await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == fixture.Engine.RequestId).Select(x => x.State).SingleAsync()));
    }

    [Fact]
    public async Task Remove_idempotency_retry_returns_original_operation_after_request_is_removed()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        const string key = "remove-exact-replay";
        async Task<HttpResponseMessage> SendRemove()
        {
            var request = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/downloads/{fixture.Engine.RequestId}/actions")
            { Content = System.Net.Http.Json.JsonContent.Create(new { action = "remove", version = summary.Version }) };
            request.Headers.Add("Idempotency-Key", key);
            return await fixture.Client.SendAsync(request);
        }

        using var first = await SendRemove();
        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);
        var initial = await first.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        var initialId = initial.GetProperty("id").GetGuid();
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.NotNull(await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == fixture.Engine.RequestId).Select(x => x.RemovedAt).SingleAsync()));

        using var replay = await SendRemove();
        Assert.Equal(HttpStatusCode.Accepted, replay.StatusCode);
        var replayed = await replay.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.Equal(initialId, replayed.GetProperty("id").GetGuid());
    }

    [Fact]
    public async Task Compatible_contributor_subset_attaches_without_pausing_or_changing_generation()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var secondFileId = await fixture.AddSecondReadyFile();
        using var originalResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var original = await originalResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(original);
        using var originalSelection = await fixture.Client.PutAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/selection", new
        {
            files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "high" }, new { fileId = secondFileId, selected = true, priority = "high" } },
            autoStart = true,
            version = original.Version
        });
        Assert.Equal(HttpStatusCode.Accepted, originalSelection.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        var before = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.Id == fixture.Engine.JobId).Select(x => new { x.Generation, x.DesiredState, x.EngineState }).SingleAsync());
        Assert.Equal("running", before.DesiredState);
        Assert.Equal(1, fixture.Engine.StartCalls);
        var stopCallsBeforeAttach = fixture.Engine.StopCalls;
        var contributor = await fixture.CreateUser("subsetcontributor");
        await fixture.Grant(contributor.User.Id);
        var attached = await fixture.CreateDownload(contributor.Client, fixture.LibraryId);
        using var attachSelection = await contributor.Client.PutAsJsonAsync($"/api/v1/downloads/{attached.Id}/selection", new
        {
            files = new[] { new { fileId = secondFileId, selected = true, priority = "normal" } },
            autoStart = false,
            version = attached.Version
        });
        Assert.Equal(HttpStatusCode.Accepted, attachSelection.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());

        var after = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.Id == fixture.Engine.JobId).Select(x => new { x.Generation, x.DesiredState, x.EngineState }).SingleAsync());
        Assert.Equal(before.Generation, after.Generation);
        Assert.Equal(before.DesiredState, after.DesiredState);
        Assert.Equal(before.EngineState, after.EngineState);
        Assert.Equal(1, fixture.Engine.StartCalls);
        Assert.Equal(stopCallsBeforeAttach, fixture.Engine.StopCalls);
        Assert.Equal(6, fixture.Engine.FilePriority(0));
        Assert.Equal(6, fixture.Engine.FilePriority(1));
    }

    [Fact]
    public async Task Removing_original_request_clears_only_its_engine_file_priorities_and_keeps_contributor_running()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var secondFileId = await fixture.AddSecondReadyFile();
        using var originalResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var original = await originalResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(original);
        using var originalSelection = await fixture.Client.PutAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/selection", new
        {
            files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "high" }, new { fileId = secondFileId, selected = true, priority = "high" } },
            autoStart = true,
            version = original.Version
        });
        Assert.Equal(HttpStatusCode.Accepted, originalSelection.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        var contributor = await fixture.CreateUser("remainingcontributor");
        await fixture.Grant(contributor.User.Id);
        var attached = await fixture.CreateDownload(contributor.Client, fixture.LibraryId);
        using var attachSelection = await contributor.Client.PutAsJsonAsync($"/api/v1/downloads/{attached.Id}/selection", new
        {
            files = new[] { new { fileId = secondFileId, selected = true, priority = "normal" } },
            autoStart = false,
            version = attached.Version
        });
        Assert.Equal(HttpStatusCode.Accepted, attachSelection.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        using var currentResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var current = await currentResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(current);

        using var remove = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "remove", version = current.Version });
        Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());

        Assert.Equal(0, fixture.Engine.FilePriority(0));
        Assert.Equal(1, fixture.Engine.FilePriority(1));
        var torrent = Assert.Single(await fixture.Engine.TorrentsAsync(LifecycleFixture.Hash));
        Assert.Equal("downloading", torrent.State);
        Assert.Equal("running", await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.Id == fixture.Engine.JobId).Select(x => x.DesiredState).SingleAsync()));
        Assert.Equal("removed", await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == fixture.Engine.RequestId).Select(x => x.State).SingleAsync()));
        Assert.Null(await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == attached.Id).Select(x => x.RemovedAt).SingleAsync()));
    }

    [Fact]
    public async Task Delete_data_captures_identity_of_partial_file_before_removing_engine_job()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var partialPath = Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"), "fixture.mp4");
        using (var partial = new FileStream(partialPath, FileMode.Open, FileAccess.Write, FileShare.None)) partial.SetLength(LifecycleFixture.FileBytes / 2);
        await fixture.InDb(async db =>
        {
            var file = await db.DownloadFiles.SingleAsync(x => x.Id == fixture.Engine.FileId);
            file.FileIdentity = null; file.MtimeNs = null; file.Completed = false; file.PlaybackState = "waitingForData";
            file.DownloadedBytes = LifecycleFixture.FileBytes / 2; file.ContiguousBytes = LifecycleFixture.FileBytes / 2;
            return await db.SaveChangesAsync();
        });
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        using var remove = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new
        { action = "remove", deleteData = true, confirmation = "DELETE DATA", version = summary.Version });
        Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
        var boundaries = new List<string>();
        fixture.Worker.TransactionBoundary = boundaries.Add;

        Assert.True(await fixture.Worker.RunOnceAsync());

        Assert.True(boundaries.IndexOf("deletion_identities_committed") >= 0);
        Assert.True(boundaries.IndexOf("engine_removed") > boundaries.IndexOf("deletion_identities_committed"));
        Assert.False(File.Exists(partialPath));
        var state = await fixture.InDb(async db =>
        {
            var job = await db.TorrentJobs.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.JobId);
            var file = await db.DownloadFiles.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.FileId);
            return (job.PayloadRemoved, file.FileIdentity, file.MtimeNs, file.Completed);
        });
        Assert.True(state.PayloadRemoved);
        Assert.NotNull(state.FileIdentity);
        Assert.NotNull(state.MtimeNs);
        Assert.False(state.Completed);
    }

    [Fact]
    public async Task Retired_metadata_cache_maintenance_removes_at_most_thirty_two_entries_per_poll()
    {
        await using var fixture = await LifecycleFixture.Create();
        var ids = Enumerable.Range(0, 33).Select(_ => Guid.NewGuid()).ToArray();
        var identities = new Dictionary<Guid, string>();
        using (var root = new ContainedDirectory(fixture.StatePath))
        {
            DownloadCommands.EnsureDirectory(root, "torrent-metainfo");
            foreach (var id in ids)
            {
                var path = $"torrent-metainfo/{id:N}.torrent";
                using var file = root.CreateFile(path);
                file.WriteByte(0x64);
                file.Flush(true);
                identities[id] = ContainedDirectory.Inspect(file).Key;
            }
        }
        await fixture.InDb(async db =>
        {
            foreach (var id in ids)
                db.TorrentJobs.Add(new TorrentJob
                {
                    Id = id, LibraryId = fixture.LibraryId, ManagedPath = $".briani/staging/{id:N}",
                    MetadataRelativePath = $"torrent-metainfo/{id:N}.torrent", MetadataFileIdentity = identities[id],
                    RetiredAt = fixture.Clock.GetUtcNow(), CreatedAt = fixture.Clock.GetUtcNow(), UpdatedAt = fixture.Clock.GetUtcNow()
                });
            await db.SaveChangesAsync();
            return 0;
        });

        await fixture.Worker.PollOnceAsync();

        var remaining = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.RetiredAt != null && x.MetadataRelativePath != null).Select(x => x.Id).ToArrayAsync());
        Assert.Single(remaining);
        Assert.Equal(32, ids.Count(id => !File.Exists(Path.Combine(fixture.StatePath, "torrent-metainfo", id.ToString("N") + ".torrent"))));
        Assert.True(File.Exists(Path.Combine(fixture.StatePath, "torrent-metainfo", remaining[0].ToString("N") + ".torrent")));
    }

    [Fact]
    public async Task Timed_out_add_is_reconciled_from_owned_engine_torrent_without_duplicate_add()
    {
        await using var fixture = await LifecycleFixture.Create();
        fixture.Engine.TimeoutAfterAddOnce = true;
        var request = await fixture.CreateDownload(fixture.Client, fixture.LibraryId);

        Assert.True(await fixture.Worker.RunOnceAsync());
        fixture.Clock.Advance(TimeSpan.FromMinutes(1));
        for (var i = 0; i < 3 && fixture.Engine.AddCalls == 0; i++) await fixture.Worker.RunOnceAsync();
        Assert.Equal(1, fixture.Engine.AddCalls);
        Assert.Single(await fixture.Engine.TorrentsAsync(LifecycleFixture.Hash));
        await fixture.Worker.PollOnceAsync();
        var job = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().SingleAsync(x => x.InfoHashV1 == LifecycleFixture.Hash));
        Assert.Equal(LifecycleFixture.Hash, job.UpstreamId);
    }

    [Fact]
    public async Task Metadata_cache_recovers_after_written_boundary_without_duplicate_engine_add()
    {
        await using var fixture = await LifecycleFixture.Create();
        var download = await fixture.CreateDownload(fixture.Client, fixture.LibraryId);
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Equal(1, fixture.Engine.AddCalls);
        var crashOnce = true;
        var reachedMetadataWritten = false;
        fixture.Worker.TransactionBoundary = boundary =>
        {
            if (boundary == "metadata_written" && crashOnce) { reachedMetadataWritten = true; crashOnce = false; throw new InvalidOperationException("simulated process interruption"); }
        };

        var interruption = await Record.ExceptionAsync(() => fixture.Worker.PollOnceAsync());
        var boundaryState = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.InfoHashV1 == LifecycleFixture.Hash).Select(x => $"{x.MetadataStatus}:{x.ErrorCode}:{x.MetadataRelativePath}:{x.InfoHashV1}").SingleAsync());
        var parsedInfoHash = Briani.Api.Modules.Discovery.Sources.Metainfo.Parse(LifecycleFixture.TorrentBytes).InfoHashV1;
        Assert.True(reachedMetadataWritten, $"metadata_written was not reached; poll error={interruption?.GetType().Name}:{interruption?.Message}; job={boundaryState}; exportHash={parsedInfoHash}");
        Assert.IsType<InvalidOperationException>(interruption);
        var persisted = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.InfoHashV1 == LifecycleFixture.Hash).Select(x => new { x.MetadataRelativePath, x.MetadataFileIdentity, x.MetadataStatus }).SingleAsync());
        Assert.Equal("pending", persisted.MetadataStatus);
        Assert.NotNull(persisted.MetadataRelativePath);
        Assert.NotNull(persisted.MetadataFileIdentity);
        var cachePath = Path.Combine(fixture.StatePath, persisted.MetadataRelativePath.Replace('/', Path.DirectorySeparatorChar));
        Assert.True(File.Exists(cachePath));
        using var cache = new ContainedDirectory(fixture.StatePath);
        using var cachedFile = cache.OpenFile(persisted.MetadataRelativePath, persisted.MetadataFileIdentity);
        var fileIdentity = ContainedDirectory.Inspect(cachedFile).Key;

        fixture.Worker.TransactionBoundary = null;
        await fixture.Worker.PollOnceAsync();

        var recovered = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.InfoHashV1 == LifecycleFixture.Hash).Select(x => new { x.MetadataRelativePath, x.MetadataFileIdentity, x.MetadataStatus }).SingleAsync());
        Assert.Equal("ready", recovered.MetadataStatus);
        Assert.Equal(persisted.MetadataRelativePath, recovered.MetadataRelativePath);
        Assert.Equal(fileIdentity, recovered.MetadataFileIdentity);
        Assert.Equal(1, fixture.Engine.AddCalls);
        Assert.Single(await fixture.Engine.TorrentsAsync(LifecycleFixture.Hash));

        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{download.Id}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        using var remove = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{download.Id}/actions", new { action = "remove", version = summary.Version });
        Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.False(File.Exists(cachePath));
        var retired = await fixture.InDb(async db =>
        {
            var jobId = await db.DownloadRequests.AsNoTracking().Where(x => x.Id == download.Id).Select(x => x.TorrentJobId).SingleAsync();
            return await db.TorrentJobs.AsNoTracking().Where(x => x.Id == jobId).Select(x => new { x.RetiredAt, x.EncryptedMagnet, x.EncryptedMetainfo, x.MetadataRelativePath, x.MetadataFileIdentity }).SingleAsync();
        });
        Assert.NotNull(retired.RetiredAt);
        Assert.Null(retired.EncryptedMagnet);
        Assert.Null(retired.EncryptedMetainfo);
        Assert.Null(retired.MetadataRelativePath);
        Assert.Null(retired.MetadataFileIdentity);
    }
}
