using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Modules.Media;

namespace Briani.DownloadTests;

public sealed class StartupRecoveryTests
{
    [Fact]
    public async Task Exclusive_startup_reclaims_future_leases_without_retrying_terminal_jobs()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.InDb(async db => {
            var now=fixture.Clock.GetUtcNow();
            var orphan=new WorkJob {Kind="download",TargetId=Guid.NewGuid(),State="running",LeaseOwner="terminated-process",LeaseUntil=now.AddMinutes(2),Attempt=2,NextAttemptAt=now.AddMinutes(2)};
            var terminal=new WorkJob {Kind="download",TargetId=Guid.NewGuid(),State="failed",Attempt=3,LastErrorCode="disk_unavailable",NextAttemptAt=now.AddMinutes(2)};
            db.Jobs.AddRange(orphan,terminal);await db.SaveChangesAsync();
            await StartupRecovery.RequeueOrphanedWorkAsync(db,fixture.Clock);
            Assert.Equal("queued",orphan.State);Assert.Null(orphan.LeaseOwner);Assert.Null(orphan.LeaseUntil);
            Assert.Equal(now,orphan.NextAttemptAt);Assert.Equal(2,orphan.Attempt);
            Assert.Equal("failed",terminal.State);Assert.Equal(3,terminal.Attempt);Assert.Equal("disk_unavailable",terminal.LastErrorCode);
            return 0;
        });
    }
}
