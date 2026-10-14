using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Playback;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class FinalAcceptanceTests
{
    [Fact]
    public async Task Shared_hash_isolation_keeps_control_and_quota_per_user_and_hides_other_library_conflict()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("finalowner");
        using var ownerClient = owner.Client;
        await fixture.Grant(owner.User.Id);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash,
            Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));

        var contributor = await fixture.CreateUser("finalcontributor");
        using var contributorClient = contributor.Client;
        await fixture.Grant(contributor.User.Id, quota: 300_000_000);
        var attached = await fixture.CreateDownload(contributorClient, fixture.LibraryId);
        var jobCount = await fixture.InDb(db => db.TorrentJobs.CountAsync());
        Assert.Equal(1, jobCount);

        using (var ownerPause = await ownerClient.PostAsJsonAsync(
                   $"/api/v1/downloads/{fixture.Engine.RequestId}/actions",
                   new { action = "pause", version = 1L }))
            Assert.Equal(HttpStatusCode.NotFound, ownerPause.StatusCode);
        Assert.Equal(0, fixture.Engine.StopCalls);
        Assert.Equal("running", await fixture.InDb(db => db.TorrentJobs.AsNoTracking()
            .Where(x => x.Id == fixture.Engine.JobId).Select(x => x.DesiredState).SingleAsync()));

        var otherLibrary = await fixture.CreateLibrary("Private destination");
        await fixture.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant
            {
                UserId = contributor.User.Id, LibraryId = otherLibrary,
                CanRead = true, CanDownload = true, QuotaBytes = 300_000_000
            });
            await db.SaveChangesAsync();
            return true;
        });
        using (var conflict = await contributorClient.PostAsJsonAsync("/api/v1/downloads", new
               {
                   libraryId = otherLibrary,
                   source = new { kind = "magnet", value = $"magnet:?xt=urn:btih:{LifecycleFixture.Hash}" }
               }))
        {
            Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
            var body = await conflict.Content.ReadAsStringAsync();
            Assert.Contains("torrent_already_managed", body, StringComparison.Ordinal);
            Assert.DoesNotContain(fixture.LibraryId.ToString(), body, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain(LifecycleFixture.Hash, body, StringComparison.OrdinalIgnoreCase);
        }

        await fixture.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == contributor.User.Id && x.LibraryId == fixture.LibraryId);
            grant.QuotaBytes = 1;
            await db.SaveChangesAsync();
            return true;
        });
        using var selection = await contributorClient.PutAsJsonAsync(
            $"/api/v1/downloads/{attached.Id}/selection",
            new
            {
                files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "normal" } },
                autoStart = false,
                version = attached.Version
            });
        Assert.Equal(HttpStatusCode.Conflict, selection.StatusCode);
        Assert.Contains("quota_exceeded", await selection.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        Assert.Equal(0, await fixture.InDb(db => db.Operations.CountAsync(x => x.TargetId == attached.Id)));
    }

    [Fact]
    public async Task Foreign_download_identifiers_require_read_and_manage_for_every_grant_combination()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("finalmatrixowner");
        var viewer = await fixture.CreateUser("finalmatrixviewer");
        await fixture.Grant(viewer.User.Id);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);

        for (var bits = 0; bits < 8; bits++)
        {
            var canRead = (bits & 1) != 0;
            var canManage = (bits & 4) != 0;
            await fixture.InDb(async db =>
            {
                var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == viewer.User.Id && x.LibraryId == fixture.LibraryId);
                grant.CanRead = canRead; grant.CanDownload = (bits & 2) != 0; grant.CanManage = canManage;
                await db.SaveChangesAsync(); return true;
            });
            var expected = canRead && canManage ? HttpStatusCode.OK : HttpStatusCode.NotFound;
            using (var summary = await viewer.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}")) Assert.Equal(expected, summary.StatusCode);
            using (var files = await viewer.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/files")) Assert.Equal(expected, files.StatusCode);
            using (var list = await viewer.Client.GetAsync("/api/v1/downloads"))
            {
                Assert.Equal(HttpStatusCode.OK, list.StatusCode);
                var page = (await list.Content.ReadFromJsonAsync<DownloadPageView>())!;
                Assert.Equal(canRead && canManage, page.Items.Any(x => x.Id == fixture.Engine.RequestId));
            }
        }
    }

    [Fact]
    public async Task Manage_only_grant_can_control_existing_foreign_request_but_cannot_create_or_work_after_revocation()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("finalcontrolowner");
        var manager = await fixture.CreateUser("finalcontrolmanager");
        await fixture.Grant(owner.User.Id);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        await fixture.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = manager.User.Id, LibraryId = fixture.LibraryId, CanRead = true, CanDownload = false, CanManage = true });
            await db.SaveChangesAsync(); return true;
        });
        fixture.Engine.ConfigureFiles(4, new EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));

        using (var visible = await manager.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}")) Assert.Equal(HttpStatusCode.OK, visible.StatusCode);
        using var settingsResponse = await manager.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/settings");
        Assert.Equal(HttpStatusCode.OK, settingsResponse.StatusCode);
        var settings = (await settingsResponse.Content.ReadFromJsonAsync<DownloadSettings>())!;
        using (var configure = await manager.Client.PatchAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/settings", settings))
            Assert.Equal(HttpStatusCode.OK, configure.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Equal("completed", await LatestOperationState(fixture, manager.User.Id));

        var version = await RequestVersion(fixture, manager.Client);
        using (var pause = await manager.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "pause", version }))
            Assert.Equal(HttpStatusCode.Accepted, pause.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Equal(1, fixture.Engine.StopCalls);

        version = await RequestVersion(fixture, manager.Client);
        Guid resumeOperationId;
        using (var resume = await manager.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "resume", version }))
        {
            Assert.Equal(HttpStatusCode.Accepted, resume.StatusCode);
            using var body = JsonDocument.Parse(await resume.Content.ReadAsStringAsync());
            resumeOperationId = body.RootElement.GetProperty("id").GetGuid();
        }
        Assert.True(await fixture.Worker.RunOnceAsync());
        var resumeResult = await OperationDetails(fixture, resumeOperationId);
        Assert.Equal("completed/", resumeResult);
        Assert.Equal(1, fixture.Engine.StartCalls);

        using (var newSource = await manager.Client.PostAsJsonAsync("/api/v1/downloads", new
               { libraryId = fixture.LibraryId, source = new { kind = "magnet", value = $"magnet:?xt=urn:btih:{LifecycleFixture.Hash}" } }))
            Assert.Equal(HttpStatusCode.NotFound, newSource.StatusCode);

        version = await RequestVersion(fixture, owner.Client);
        Guid queuedOperationId;
        using (var queued = await manager.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "pause", version }))
        {
            Assert.Equal(HttpStatusCode.Accepted, queued.StatusCode);
            using var body = JsonDocument.Parse(await queued.Content.ReadAsStringAsync());
            queuedOperationId = body.RootElement.GetProperty("id").GetGuid();
        }
        await fixture.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == manager.User.Id && x.LibraryId == fixture.LibraryId);
            grant.CanManage = false; grant.CanDownload = true;
            await db.SaveChangesAsync(); return true;
        });
        var stopsBeforeDeniedWork = fixture.Engine.StopCalls;
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Equal(stopsBeforeDeniedWork, fixture.Engine.StopCalls);
        Assert.Equal("failed", await OperationState(fixture, queuedOperationId));
        var desiredAfterDeniedWork = await fixture.InDb(db => db.TorrentJobs.AsNoTracking()
            .Where(x => x.Id == fixture.Engine.JobId).Select(x => x.DesiredState).SingleAsync());
        Assert.Equal("running", desiredAfterDeniedWork);
        var startsBeforePoll = fixture.Engine.StartCalls;
        await fixture.Worker.PollOnceAsync();
        Assert.Equal(stopsBeforeDeniedWork, fixture.Engine.StopCalls);
        Assert.Equal(startsBeforePoll, fixture.Engine.StartCalls);
        Assert.Equal("running", await fixture.InDb(db => db.TorrentJobs.AsNoTracking()
            .Where(x => x.Id == fixture.Engine.JobId).Select(x => x.DesiredState).SingleAsync()));

        version = await RequestVersion(fixture, owner.Client);
        await fixture.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == manager.User.Id && x.LibraryId == fixture.LibraryId);
            grant.CanManage = true;
            var library = await db.Libraries.SingleAsync(x => x.Id == fixture.LibraryId);
            library.ReadOnly = true;
            await db.SaveChangesAsync(); return true;
        });
        using var readOnlyDenied = await manager.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "pause", version });
        Assert.Equal(HttpStatusCode.NotFound, readOnlyDenied.StatusCode);
    }

    [Fact]
    public async Task Manage_only_owner_can_remove_own_request_without_deleting_shared_data()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("finalremoveowner");
        await fixture.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = owner.User.Id, LibraryId = fixture.LibraryId, CanRead = true, CanDownload = false, CanManage = true });
            await db.SaveChangesAsync(); return true;
        });
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        var version = await RequestVersion(fixture, owner.Client);
        using var removal = await owner.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "remove", version });
        Assert.Equal(HttpStatusCode.Accepted, removal.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        var removed = await fixture.InDb(db => db.DownloadRequests.AsNoTracking().Where(x => x.Id == fixture.Engine.RequestId).Select(x => x.RemovedAt).SingleAsync());
        Assert.NotNull(removed);
        Assert.True(File.Exists(Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"), "fixture.mp4")));
    }

    [Fact]
    public async Task Revoking_manager_during_shared_remove_stops_before_second_priority_write_or_catalog_removal()
    {
        await using var fixture = await LifecycleFixture.Create();
        var targetOwner = await fixture.CreateUser("finalsharedtarget");
        var remainingOwner = await fixture.CreateUser("finalsharedremaining");
        var manager = await fixture.CreateUser("finalsharedmanager");
        await fixture.Grant(targetOwner.User.Id);
        await fixture.Grant(remainingOwner.User.Id);
        await fixture.SeedReadyDownload(targetOwner.User.Id, targetOwner.Auth.SessionId);
        var secondFileId = await fixture.AddSecondReadyFile();
        await fixture.InDb(async db =>
        {
            var file = await db.DownloadFiles.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.FileId);
            var now = fixture.Clock.GetUtcNow();
            var request = new Briani.Api.Modules.Downloads.DownloadRequest
            {
                Id = Guid.NewGuid(), OwnerId = remainingOwner.User.Id, AuthSessionId = remainingOwner.Auth.SessionId,
                LibraryId = fixture.LibraryId, TorrentJobId = fixture.Engine.JobId, SourceKind = "magnet",
                SourceDigest = "shared-second-request", EncryptedSourceReference = "", State = "downloading",
                SourceState = "ready", SelectedBytes = file.SizeBytes, ReservedBytes = file.SizeBytes,
                VolumeIdentity = "test-volume", CreatedAt = now, UpdatedAt = now, Version = 1
            };
            db.DownloadRequests.Add(request);
            db.DownloadRequestFiles.Add(new Briani.Api.Modules.Downloads.DownloadRequestFile
            { DownloadRequestId = request.Id, DownloadFileId = file.Id, Selected = true, Priority = 7 });
            db.LibraryGrants.Add(new LibraryGrant { UserId = manager.User.Id, LibraryId = fixture.LibraryId, CanRead = true, CanDownload = false, CanManage = true });
            await db.SaveChangesAsync(); return true;
        });

        var version = await RequestVersion(fixture, manager.Client);
        Guid operationId;
        using (var remove = await manager.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "remove", version }))
        {
            Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
            using var body = JsonDocument.Parse(await remove.Content.ReadAsStringAsync());
            operationId = body.RootElement.GetProperty("id").GetGuid();
        }

        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        fixture.Engine.BeforePriorityUpdate = async (call, ct) =>
        {
            if (call == 1) { entered.TrySetResult(); await release.Task.WaitAsync(ct); }
        };
        var running = fixture.Worker.RunOnceAsync();
        try
        {
            await entered.Task.WaitAsync(TimeSpan.FromSeconds(3));
            await fixture.InDb(async db =>
            {
                var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == manager.User.Id && x.LibraryId == fixture.LibraryId);
                grant.CanManage = false; grant.CanDownload = true;
                await db.SaveChangesAsync(); return true;
            });
        }
        finally
        {
            release.TrySetResult();
        }
        Assert.True(await running.WaitAsync(TimeSpan.FromSeconds(5)));

        Assert.Equal(1, fixture.Engine.PriorityUpdateCalls);
        Assert.Single(fixture.Engine.PriorityUpdates);
        Assert.Equal(0, fixture.Engine.StartCalls);
        Assert.Equal("failed", await OperationState(fixture, operationId));
        Assert.Equal(0, await fixture.InDb(db => db.DownloadFiles.AsNoTracking()
            .Where(x => x.Id == secondFileId).Select(x => x.FilePriority).SingleAsync()));
        var requestRows = await fixture.InDb(async db =>
        {
            var target = await db.DownloadRequests.AsNoTracking().Where(x => x.Id == fixture.Engine.RequestId).Select(x => x.RemovedAt).SingleAsync();
            var remaining = await db.DownloadRequests.AsNoTracking().Where(x => x.OwnerId == remainingOwner.User.Id && x.TorrentJobId == fixture.Engine.JobId).Select(x => x.RemovedAt).SingleAsync();
            return (Target: target, Remaining: remaining);
        });
        Assert.Null(requestRows.Target);
        Assert.Null(requestRows.Remaining);
    }

    [Fact]
    public async Task Same_hash_attachment_waits_for_existing_job_lock_then_joins_the_owned_job()
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("finallockowner");
        var contributor = await fixture.CreateUser("finallockjoiner");
        await fixture.Grant(owner.User.Id);
        await fixture.Grant(contributor.User.Id);
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);

        var jobId = fixture.Engine.JobId;
        var jobLock = await fixture.Services.GetRequiredService<DownloadJobLocks>().EnterAsync(jobId);
        var attachment = fixture.CreateDownload(contributor.Client, fixture.LibraryId);
        try
        {
            // Bounded wait gives the in-process request time to reach its lock wait;
            // completion while we hold the lock would expose an attachment race.
            var raced = await Task.WhenAny(attachment, Task.Delay(TimeSpan.FromMilliseconds(250)));
            Assert.NotSame(attachment, raced);
            Assert.Equal(1, await fixture.InDb(db => db.DownloadRequests.CountAsync(x => x.RemovedAt == null)));
        }
        finally
        {
            jobLock.Dispose();
        }

        var attached = await attachment.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.NotEqual(fixture.Engine.RequestId, attached.Id);
        var joined = await fixture.InDb(db => db.DownloadRequests.AsNoTracking()
            .Where(x => x.RemovedAt == null).Select(x => new { x.OwnerId, x.TorrentJobId }).ToArrayAsync());
        Assert.Equal(2, joined.Length);
        Assert.All(joined, request => Assert.Equal(jobId, request.TorrentJobId));
        Assert.Contains(joined, request => request.OwnerId == contributor.User.Id);
    }

    [Theory]
    [InlineData(LifecycleFixture.FileBytes, 1L, true)]
    [InlineData(LifecycleFixture.FileBytes - 1, null, false)]
    public async Task Foreign_manager_selection_quota_is_attributed_to_request_owner(long ownerQuota, long? managerQuota, bool accepted)
    {
        await using var fixture = await LifecycleFixture.Create();
        var owner = await fixture.CreateUser("finalquotaowner");
        var manager = await fixture.CreateUser("finalquotamanager");
        await fixture.Grant(owner.User.Id, quota: ownerQuota);
        await fixture.Grant(manager.User.Id, quota: managerQuota);
        await fixture.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == manager.User.Id && x.LibraryId == fixture.LibraryId);
            grant.CanManage = true; grant.CanDownload = false;
            await db.SaveChangesAsync(); return true;
        });
        await fixture.SeedReadyDownload(owner.User.Id, owner.Auth.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        var initialVersion = await RequestVersion(fixture, owner.Client);

        using var selection = await manager.Client.PutAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/selection", new
        {
            files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "normal" } },
            autoStart = false,
            version = initialVersion
        });

        if (accepted)
        {
            Assert.Equal(HttpStatusCode.Accepted, selection.StatusCode);
            Assert.True(await fixture.Worker.RunOnceAsync());
            Assert.Equal("completed", await LatestOperationState(fixture, manager.User.Id));
            Assert.Equal(ownerQuota, await fixture.InDb(db => db.LibraryGrants.AsNoTracking()
                .Where(x => x.UserId == owner.User.Id && x.LibraryId == fixture.LibraryId).Select(x => x.QuotaBytes!.Value).SingleAsync()));
        }
        else
        {
            Assert.Equal(HttpStatusCode.Conflict, selection.StatusCode);
            Assert.Contains("quota_exceeded", await selection.Content.ReadAsStringAsync(), StringComparison.Ordinal);
            Assert.False(await fixture.InDb(db => db.Operations.AnyAsync(x => x.TargetId == fixture.Engine.RequestId && x.UserId == manager.User.Id)));
            Assert.Equal(initialVersion, await RequestVersion(fixture, owner.Client));
        }
    }

    private static async Task<long> RequestVersion(LifecycleFixture fixture, HttpClient client)
    {
        using var response = await client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<DownloadView>())!.Version;
    }

    private static Task<string> LatestOperationState(LifecycleFixture fixture, Guid userId) => fixture.InDb(db =>
        db.Operations.AsNoTracking().Where(x => x.UserId == userId).OrderByDescending(x => x.CreatedAt).Select(x => x.State).FirstAsync());

    private static Task<string> OperationState(LifecycleFixture fixture, Guid operationId) => fixture.InDb(db =>
        db.Operations.AsNoTracking().Where(x => x.Id == operationId).Select(x => x.State).SingleAsync());

    private static Task<string> OperationDetails(LifecycleFixture fixture, Guid operationId) => fixture.InDb(db =>
        db.Operations.AsNoTracking().Where(x => x.Id == operationId).Select(x => x.State + "/" + (x.ErrorCode ?? "")).SingleAsync());

    [Fact]
    public async Task Refreshed_session_logout_aborts_an_open_progressive_response_on_watchdog_tick()
    {
        await using var fixture = await LifecycleFixture.Create();
        var user = await fixture.CreateUser("finalwatchdog");
        using var member = user.Client;
        await fixture.Grant(user.User.Id);
        await fixture.SeedReadyDownload(user.User.Id, user.Auth.SessionId);
        fixture.Engine.ConfigureFiles(4, new EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3));
        var stage = Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, stage);

        using var created = await member.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "downloadFile", id = fixture.Engine.FileId }, mode = "internal"
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var session = (await created.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
        Assert.NotNull(session.StreamUrl);

        using var scope = fixture.Services.CreateScope();
        var response = new BlockedResponse();
        var lifetime = new RequestLifetime();
        var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        context.Features.Set<IHttpRequestLifetimeFeature>(lifetime);
        context.Request.Method = "GET";
        context.Request.Host = new HostString("localhost");
        context.Response.Body = response;
        var ticket = new Uri(session.StreamUrl!).AbsolutePath.Split('/')[2];
        var running = scope.ServiceProvider.GetRequiredService<ProgressivePlayback>()
            .StreamAsync(ticket, "fixture.mp4", context);
        try
        {
            await response.Blocked.WaitAsync(TimeSpan.FromSeconds(3));
            Assert.True(fixture.Services.GetRequiredService<MediaReaders>().HasReaders(fixture.Engine.FileId));

            using var refreshed = await member.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = user.Auth.RefreshToken });
            Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
            var rotated = (await refreshed.Content.ReadFromJsonAsync<AuthReply>())!;
            member.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", rotated.AccessToken);
            using var logout = await member.PostAsync("/api/v1/auth/logout", null);
            Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);

            await running.WaitAsync(TimeSpan.FromSeconds(4));
            Assert.True(lifetime.Aborted);
            Assert.True(response.Cancelled);
            Assert.Equal(1, response.WriteCount);
            Assert.False(fixture.Services.GetRequiredService<MediaReaders>().HasReaders(fixture.Engine.FileId));
            Assert.NotNull(await fixture.InDb(db => db.AuthSessions.AsNoTracking()
                .Where(x => x.Id == user.Auth.SessionId).Select(x => x.RevokedAt).SingleAsync()));
        }
        finally
        {
            lifetime.Abort();
            await running.WaitAsync(TimeSpan.FromSeconds(3));
        }
    }

    [Fact]
    public void Download_layout_preserves_offsets_and_piece_intersections_above_four_gibibytes()
    {
        const long pieceLength = 16 * 1024;
        var prefixBytes = (1L << 32) + 123;
        var targetBytes = 50_000L;
        var targetOffset = prefixBytes;
        var firstPiece = checked((int)(targetOffset / pieceLength));
        var lastPiece = checked((int)((targetOffset + targetBytes - 1) / pieceLength));
        var descriptor = new Briani.Api.Modules.Discovery.Sources.MetainfoDescriptor(
            "large", "v1hash", null, pieceLength,
            [new(0, "large.bin", prefixBytes, false), new(1, "target.mp4", targetBytes, false)], []);
        var engine = new[]
        {
            new EngineFile(0, "large.bin", prefixBytes, 1, 0, 0, checked((int)((prefixBytes - 1) / pieceLength))),
            new EngineFile(1, "target.mp4", targetBytes, 0, 0, firstPiece, lastPiece)
        };

        var mapped = DownloadLayout.Map(Guid.NewGuid(), descriptor, engine);
        var target = Assert.Single(mapped, x => x.RelativePath == "target.mp4");
        Assert.True(target.TorrentOffset > uint.MaxValue);
        Assert.Equal(targetOffset, target.TorrentOffset);
        Assert.Equal(firstPiece, target.PieceFirst);
        Assert.Equal(lastPiece, target.PieceLast);

        var pieces = new byte[lastPiece + 1];
        for (var piece = firstPiece; piece <= lastPiece; piece++) pieces[piece] = 2;
        Assert.Equal(targetBytes, DownloadLayout.Available(target, pieceLength, pieces));
        Assert.Equal(targetBytes, DownloadLayout.Available(target, pieceLength, pieces, contiguous: true));
        pieces[firstPiece + 1] = 1;
        Assert.Equal(targetBytes - pieceLength, DownloadLayout.Available(target, pieceLength, pieces));
        Assert.Equal((long)(firstPiece + 1) * pieceLength - targetOffset,
            DownloadLayout.Available(target, pieceLength, pieces, contiguous: true));
    }

    private sealed class BlockedResponse : Stream
    {
        private readonly TaskCompletionSource blocked = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task Blocked => blocked.Task;
        public int WriteCount { get; private set; }
        public bool Cancelled { get; private set; }
        public override async ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default)
        {
            WriteCount++;
            blocked.TrySetResult();
            try { await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); }
            catch (OperationCanceledException) { Cancelled = true; throw; }
        }
        public override bool CanRead => false;
        public override bool CanSeek => false;
        public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() { }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }

    private sealed class RequestLifetime : IHttpRequestLifetimeFeature
    {
        private readonly CancellationTokenSource source = new();
        public bool Aborted { get; private set; }
        public CancellationToken RequestAborted { get => source.Token; set { } }
        public void Abort() { Aborted = true; source.Cancel(); }
    }
}
