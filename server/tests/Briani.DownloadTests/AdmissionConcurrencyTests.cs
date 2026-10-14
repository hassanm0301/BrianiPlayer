using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Briani.DownloadTests;

public sealed class AdmissionConcurrencyTests
{
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Poll_start_reservation_prevents_command_loop_from_exceeding_owner_cap(bool sameOwner)
    {
        await using var fixture = await LifecycleFixture.Create();
        var ownerA = await fixture.CreateUser("admissiona");
        var ownerB = sameOwner ? ownerA : await fixture.CreateUser("admissionb");
        await fixture.Grant(ownerA.User.Id);
        if (!sameOwner) await fixture.Grant(ownerB.User.Id);
        await fixture.SeedReadyDownload(ownerA.User.Id, ownerA.Auth.SessionId);
        var jobA = fixture.Engine.JobId;
        var hashA = LifecycleFixture.Hash;
        fixture.Engine.RegisterExisting(hashA, Path.Combine(fixture.LibraryPath, ".briani", "staging", jobA.ToString("N")), state: "stoppedDL");
        fixture.Clock.Advance(TimeSpan.FromSeconds(1));
        fixture.Engine.JobId = Guid.NewGuid(); fixture.Engine.RequestId = Guid.NewGuid(); fixture.Engine.FileId = Guid.NewGuid();
        var hashB = new string('b', 40);
        await fixture.SeedReadyDownload(ownerB.User.Id, ownerB.Auth.SessionId, hash: hashB);
        var jobB = fixture.Engine.JobId;
        var requestB = fixture.Engine.RequestId;
        fixture.Engine.RegisterExisting(hashB, Path.Combine(fixture.LibraryPath, ".briani", "staging", jobB.ToString("N")), state: "stoppedDL");
        fixture.Engine.CompletePieces = false;
        await fixture.InDb(async db => {
            foreach (var job in await db.TorrentJobs.ToArrayAsync()) {
                job.EngineState = "stopped"; job.SelectedComplete = false;
                if (job.Id == jobB) { job.UpstreamId = hashB; job.InfoHashV1 = hashB; }
            }
            foreach (var file in await db.DownloadFiles.ToArrayAsync()) {
                file.Completed = false; file.DownloadedBytes = 0; file.ContiguousBytes = 0;
            }
            return await db.SaveChangesAsync();
        });
        var entered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        fixture.Engine.BeforeStart = async (hash, ct) => {
            if (hash == hashA) { entered.TrySetResult(); await release.Task.WaitAsync(ct); }
        };
        var polling = fixture.Worker.PollOnceAsync();
        try {
            await entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
            Assert.Equal("starting", await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(j => j.Id == jobA).Select(j => j.EngineState).SingleAsync()));
            using var queued = await fixture.Client.PostAsJsonAsync($"/api/v1/downloads/{requestB}/actions", new { action = "resume", version = 1 });
            Assert.Equal(HttpStatusCode.Accepted, queued.StatusCode);
            Assert.True(await fixture.Worker.RunOnceAsync().WaitAsync(TimeSpan.FromSeconds(5)));
            Assert.Equal(sameOwner ? 1 : 2, fixture.Engine.StartCalls);
            Assert.Equal(sameOwner ? "queued" : "downloading", await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(j => j.Id == jobB).Select(j => j.EngineState).SingleAsync()));
        } finally {
            release.TrySetResult();
            await polling.WaitAsync(TimeSpan.FromSeconds(5));
        }
    }
}
