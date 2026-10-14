using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Playback;
public static class PlaybackAdmission
{
    // Called under WriteGate by both completed and progressive session creation.
    public static async Task RequireAsync(BrianiDb db,Guid userId,DateTimeOffset now,CancellationToken ct)
    {
        var idle=now.AddMinutes(-30);
        var live=db.PlaybackSessions.Where(x=>x.RevokedAt==null && x.AbsoluteExpiresAt>now && (x.ActivatedAt==null?x.FirstUseDeadline>now:x.LastActivityAt!=null && x.LastActivityAt>idle));
        if(await live.CountAsync(x=>x.UserId==userId,ct)>=64 || await live.CountAsync(ct)>=512)throw new ApiException(429,"playback_session_limit");
    }
}
