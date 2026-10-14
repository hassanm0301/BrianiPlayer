using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Identity;
public sealed class IdentityHousekeeping(IServiceScopeFactory scopes,WriteGate gate,TimeProvider clock) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {while(!stoppingToken.IsCancellationRequested){try{await Task.Delay(TimeSpan.FromMinutes(1),clock,stoppingToken);await PruneAsync(stoppingToken);}catch(OperationCanceledException)when(stoppingToken.IsCancellationRequested){break;}catch(Exception){ // Retry next bounded interval; never log credentials or database values.
        }}}
    public async Task PruneAsync(CancellationToken ct=default)
    {
        using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<BrianiDb>();using var lease=await gate.EnterAsync(ct);var now=clock.GetUtcNow();
        var tokens=await db.AccessTokens.Where(x=>x.ExpiresAt<=now).OrderBy(x=>x.ExpiresAt).Select(x=>x.TokenHash).Take(500).ToArrayAsync(ct);await db.AccessTokens.Where(x=>tokens.Contains(x.TokenHash)).ExecuteDeleteAsync(ct);
        var replays=await db.RefreshReplays.Where(x=>x.ExpiresAt<=now).OrderBy(x=>x.ExpiresAt).Select(x=>x.ConsumedHash).Take(500).ToArrayAsync(ct);await db.RefreshReplays.Where(x=>replays.Contains(x.ConsumedHash)).ExecuteDeleteAsync(ct);
        var pairs=await db.DevicePairings.Where(x=>x.ExpiresAt<=now).OrderBy(x=>x.ExpiresAt).Select(x=>x.Id).Take(500).ToArrayAsync(ct);await db.DevicePairings.Where(x=>pairs.Contains(x.Id)).ExecuteDeleteAsync(ct);
        var settings=await Briani.Api.Modules.Preferences.AdministratorConfiguration.ReadAsync(db,ct);var cutoff=now.AddDays(-settings["auditRetentionDays"]!.GetValue<int>());var audits=await db.AuditEvents.Where(x=>x.CreatedAt<cutoff).OrderBy(x=>x.CreatedAt).Select(x=>x.Id).Take(500).ToArrayAsync(ct);await db.AuditEvents.Where(x=>audits.Contains(x.Id)).ExecuteDeleteAsync(ct);
        var idle=now.AddMinutes(-30);
        var playback=await db.PlaybackSessions.Where(x=>x.RevokedAt!=null || x.AbsoluteExpiresAt<=now || (x.ActivatedAt==null?x.FirstUseDeadline<=now:x.LastActivityAt==null || x.LastActivityAt<=idle)).OrderBy(x=>x.CreatedAt).Select(x=>x.Id).Take(500).ToArrayAsync(ct);await db.PlaybackSessions.Where(x=>playback.Contains(x.Id)).ExecuteDeleteAsync(ct);
        var expired=now.AddDays(-1);var keys=await db.Settings.Where(x=>(x.Key.StartsWith("admin-idem:") || x.Key.StartsWith("preferences-reset:") || x.Key.StartsWith("maintenance-idem:")) && x.UpdatedAt<expired).Select(x=>x.Key).Take(500).ToArrayAsync(ct);await db.Settings.Where(x=>keys.Contains(x.Key)).ExecuteDeleteAsync(ct);
    }
}
