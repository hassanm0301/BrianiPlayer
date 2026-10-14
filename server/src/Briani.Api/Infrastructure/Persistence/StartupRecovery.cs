using Microsoft.EntityFrameworkCore;

namespace Briani.Api.Infrastructure.Persistence;

public static class StartupRecovery
{
    // Called after acquiring the exclusive state-directory process lock and
    // before starting hosted workers. Every old running lease belongs to the
    // terminated process, even if its wall-clock expiration is still ahead.
    public static async Task RequeueOrphanedWorkAsync(BrianiDb db, TimeProvider clock, CancellationToken ct = default)
    {
        var now = clock.GetUtcNow();
        foreach (var job in await db.Jobs.Where(x => x.State == "running").ToArrayAsync(ct))
        {
            job.State = "queued";
            job.LeaseOwner = null;
            job.LeaseUntil = null;
            job.NextAttemptAt = now;
            job.UpdatedAt = now;
        }
        await db.SaveChangesAsync(ct);
    }
}
