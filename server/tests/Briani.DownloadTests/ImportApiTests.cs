using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Downloads.Queries;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class ImportApiTests
{
    [Fact]
    public async Task Poll_recovers_probe_after_import_catalog_commit_interruption()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        using var scope = fixture.Services.CreateScope();
        var importer = scope.ServiceProvider.GetRequiredService<DownloadImport>();
        var first = true;
        importer.TransactionBoundary = boundary =>
        {
            if (boundary == "catalog_committed" && first)
            {
                first = false;
                throw new InvalidOperationException("simulated interruption after catalog commit");
            }
        };

        await Assert.ThrowsAsync<InvalidOperationException>(() => importer.ImportAsync(fixture.Engine.JobId, fixture.Engine.FileId));
        var committed = await fixture.InDb(db => db.MediaMetadata.AsNoTracking().Where(x => x.MediaItemId == db.MediaItems.Where(m => m.DownloadFileId == fixture.Engine.FileId).Select(m => m.Id).Single()).Select(x => x.ProbeStatus).SingleAsync());
        Assert.Equal("pending", committed);

        importer.TransactionBoundary = null;
        await fixture.Worker.PollOnceAsync();

        var final = await fixture.InDb(async db => await db.MediaMetadata.AsNoTracking().Where(x => x.MediaItemId == db.MediaItems.Where(m => m.DownloadFileId == fixture.Engine.FileId).Select(m => m.Id).Single())
            .Select(x => new { x.ProbeStatus, x.ContentGeneration, Version = db.MediaItems.Where(m => m.Id == x.MediaItemId).Select(m => m.Version).Single() }).SingleAsync());
        Assert.NotEqual("pending", final.ProbeStatus);
        Assert.Equal(final.Version, final.ContentGeneration);
        Assert.Equal(1, await fixture.InDb(db => db.Operations.CountAsync(x => x.Kind == "download-import" && x.TargetId == fixture.Engine.FileId && x.State == "completed")));
    }

    [Fact]
    public async Task Poll_imports_at_most_one_completed_file_per_job_and_resumes_next_file_on_next_poll()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var secondId = await fixture.AddSecondReadyFile();
        var stage = Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"));
        File.WriteAllBytes(Path.Combine(stage, "second.mp4"), Enumerable.Range(0, (int)LifecycleFixture.FileBytes).Select(i => (byte)((i + 7) % 251)).ToArray());
        using (var root = new ContainedDirectory(fixture.LibraryPath))
        using (var directory = root.Directory(Path.Combine(".briani", "staging", fixture.Engine.JobId.ToString("N"))))
        {
            var node = directory.Inspect("second.mp4");
            await fixture.InDb(async db =>
            {
                var file = await db.DownloadFiles.SingleAsync(x => x.Id == secondId);
                file.FileIdentity = node.Key;
                file.MtimeNs = node.MtimeNs;
                return await db.SaveChangesAsync();
            });
        }

        await fixture.Worker.PollOnceAsync();
        var afterFirstPoll = await fixture.InDb(async db => await db.DownloadFiles.AsNoTracking()
            .Where(x => x.Id == fixture.Engine.FileId || x.Id == secondId)
            .OrderBy(x => x.UpstreamFileIndex).Select(x => x.ImportedItemId).ToArrayAsync());
        Assert.NotNull(afterFirstPoll[0]);
        Assert.Null(afterFirstPoll[1]);

        await fixture.Worker.PollOnceAsync();
        var afterSecondPoll = await fixture.InDb(async db => await db.DownloadFiles.AsNoTracking()
            .Where(x => x.Id == fixture.Engine.FileId || x.Id == secondId)
            .OrderBy(x => x.UpstreamFileIndex).Select(x => x.ImportedItemId).ToArrayAsync());
        Assert.All(afterSecondPoll, value => Assert.True(value.HasValue));
        Assert.NotEqual(afterSecondPoll[0], afterSecondPoll[1]);
    }

    [Fact]
    public async Task Complete_selected_file_imports_as_stable_media_id_and_hard_link()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var stagePath = Path.Combine(".briani", "staging", fixture.Engine.JobId.ToString("N"));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, stagePath));

        for (var i = 0; i < 8; i++)
        {
            await fixture.Worker.PollOnceAsync();
            await fixture.Worker.RunOnceAsync();
            if (await fixture.InDb(db => db.MediaItems.AnyAsync(x => x.DownloadFileId == fixture.Engine.FileId))) break;
        }

        var media = await fixture.InDb(db => db.MediaItems.AsNoTracking().SingleAsync(x => x.DownloadFileId == fixture.Engine.FileId));
        var downloadFile = await fixture.InDb(db => db.DownloadFiles.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.FileId));
        Assert.Equal(media.Id, downloadFile.ImportedItemId);
        Assert.True(downloadFile.Completed);
        Assert.Equal("complete", downloadFile.PlaybackState);
        var destination = Path.Combine(fixture.LibraryPath, media.RelativePath);
        Assert.True(File.Exists(destination));
        Assert.Equal(LifecycleFixture.FileBytes, new FileInfo(destination).Length);
        using (var libraryRoot = new ContainedDirectory(fixture.LibraryPath))
            Assert.Equal(libraryRoot.Inspect(Path.Combine(stagePath, "fixture.mp4")).Key, libraryRoot.Inspect(media.RelativePath).Key);

        using var response = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/files");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var files = await response.Content.ReadFromJsonAsync<DownloadFileView[]>();
        Assert.NotNull(files);
        Assert.Equal(media.Id, Assert.Single(files).ImportedMediaId);

        await fixture.Worker.PollOnceAsync();
        await fixture.Worker.RunOnceAsync();
        var afterReplay = await fixture.InDb(db => db.MediaItems.AsNoTracking().Where(x => x.DownloadFileId == fixture.Engine.FileId).Select(x => x.Id).ToArrayAsync());
        Assert.Equal(new[] { media.Id }, afterReplay);
    }

    [Fact]
    public async Task Recheck_advances_generation_and_revokes_old_reader_before_engine_recheck()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        var generationBefore = await fixture.InDb(db => db.TorrentJobs.Where(x => x.Id == fixture.Engine.JobId).Select(x => x.Generation).SingleAsync());
        await fixture.InDb(async db =>
        {
            db.PlaybackSessions.Add(new Briani.Api.Modules.Media.PlaybackSession
            {
                Id = Guid.NewGuid(), UserId = fixture.Admin.User.Id, AuthSessionId = fixture.Admin.SessionId,
                DownloadFileId = fixture.Engine.FileId, TargetGeneration = generationBefore.ToString(),
                TicketHash = "test-ticket-hash", Mode = "internal", CreatedAt = fixture.Clock.GetUtcNow(),
                FirstUseDeadline = fixture.Clock.GetUtcNow().AddMinutes(1), AbsoluteExpiresAt = fixture.Clock.GetUtcNow().AddMinutes(5)
            });
            await db.SaveChangesAsync();
            return 0;
        });
        using var read = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var view = await read.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(view);
        using var recheck = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "recheck", version = view.Version });

        Assert.Equal(HttpStatusCode.Accepted, recheck.StatusCode);
        var fenced = await fixture.InDb(async db =>
        {
            var job = await db.TorrentJobs.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.JobId);
            var session = await db.PlaybackSessions.AsNoTracking().SingleAsync(x => x.DownloadFileId == fixture.Engine.FileId);
            return (job.Generation, session.RevokedAt);
        });
        Assert.Equal(generationBefore + 1, fenced.Generation);
        Assert.NotNull(fenced.RevokedAt);
        Assert.True(await fixture.Worker.RunOnceAsync());
        await fixture.Worker.PollOnceAsync();
        var file = await fixture.InDb(db => db.DownloadFiles.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.FileId));
        Assert.NotEqual("eligible", file.PlaybackState);
    }

    [Fact]
    public async Task Recheck_rejects_active_media_reader_before_engine_effect()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        await fixture.Worker.PollOnceAsync();
        var mediaId = await fixture.InDb(db => db.MediaItems.AsNoTracking().Where(x => x.DownloadFileId == fixture.Engine.FileId).Select(x => x.Id).SingleAsync());
        var readers = fixture.Services.GetRequiredService<Briani.Api.Modules.Playback.MediaReaders>();
        using var lease = readers.Acquire(fixture.Admin.SessionId, mediaId, CancellationToken.None);
        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);

        using var response = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new { action = "recheck", version = summary.Version });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains("active_reader_conflict", await response.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        Assert.Equal(0, fixture.Engine.RecheckCalls);
    }

    [Fact]
    public async Task Imported_hardlink_remains_readable_after_delete_data_and_retired_library_can_be_deleted()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        using (var scope = fixture.Services.CreateScope())
            await scope.ServiceProvider.GetRequiredService<DownloadImport>().ImportAsync(fixture.Engine.JobId, fixture.Engine.FileId);
        var mediaId = await fixture.InDb(db => db.MediaItems.AsNoTracking().Where(x => x.DownloadFileId == fixture.Engine.FileId).Select(x => x.Id).SingleAsync());
        using var summaryResponse = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);

        using var remove = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/actions", new
        { action = "remove", deleteData = true, confirmation = "DELETE DATA", version = summary.Version });
        Assert.Equal(HttpStatusCode.Accepted, remove.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.False(File.Exists(Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"), "fixture.mp4")));

        using (var scope = fixture.Services.CreateScope())
        {
            var access = scope.ServiceProvider.GetRequiredService<MediaAccess>();
            var (item, library) = await access.RequireAsync(new(fixture.Admin.User.Id, fixture.Admin.SessionId, "administrator"), mediaId);
            using var file = access.Open(item, library);
            var bytes = new byte[32];
            await file.ReadExactlyAsync(bytes);
            Assert.Equal(Enumerable.Range(0, 32).Select(i => (byte)(i % 251)), bytes);
        }

        var libraryVersion = await fixture.InDb(db => db.Libraries.AsNoTracking().Where(x => x.Id == fixture.LibraryId).Select(x => x.Version).SingleAsync());
        using var deleteLibrary = await fixture.Client.DeleteAsync($"/api/v1/libraries/{fixture.LibraryId}?version={libraryVersion}");
        Assert.Equal(HttpStatusCode.NoContent, deleteLibrary.StatusCode);
        Assert.False(await fixture.InDb(db => db.Libraries.AnyAsync(x => x.Id == fixture.LibraryId)));
    }
}
