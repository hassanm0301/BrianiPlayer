using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Discovery.Sources;
public sealed class SourceHousekeeping(IServiceScopeFactory scopes,ServerOptions options,WriteGate gate,TimeProvider clock):BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {while(!ct.IsCancellationRequested){try{await Task.Delay(TimeSpan.FromMinutes(1),clock,ct);await PruneAsync(ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}catch(Exception){}}}
    public async Task PruneAsync(CancellationToken ct=default)
    {
        using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<BrianiDb>();using var lease=await gate.EnterAsync(ct);await PruneUploadsAsync(db,options,clock,ct);
        var expired=clock.GetUtcNow().AddDays(-1);var snapshots=await db.DiscoverySnapshots.Where(x=>x.ExpiresAt<expired).OrderBy(x=>x.ExpiresAt).Select(x=>x.Id).Take(50).ToArrayAsync(ct);
        await db.Jobs.Where(x=>x.Kind=="discovery" && snapshots.Contains(x.TargetId)).ExecuteDeleteAsync(ct);await db.DiscoverySnapshots.Where(x=>snapshots.Contains(x.Id)).ExecuteDeleteAsync(ct);
        var operations=await db.Operations.Where(x=>x.ExpiresAt<clock.GetUtcNow() && (x.State=="completed" || x.State=="failed" || x.State=="cancelled" || x.Kind=="discovery.query" || x.Kind=="torrent-upload")).OrderBy(x=>x.ExpiresAt).Select(x=>x.Id).Take(500).ToArrayAsync(ct);
        await db.Operations.Where(x=>operations.Contains(x.Id)).ExecuteDeleteAsync(ct);
    }
    // Caller owns WriteGate: there can be no legitimate uncommitted upload
    // writer when catalog/orphan reconciliation runs in this directory.
    internal static async Task<int> PruneUploadsAsync(BrianiDb db,ServerOptions options,TimeProvider clock,CancellationToken ct)
    {
        using var root=new ContainedDirectory(options.StateRoot);var expired=await db.TorrentUploads.Where(x=>x.ExpiresAt<=clock.GetUtcNow()).OrderBy(x=>x.ExpiresAt).Take(32).ToArrayAsync(ct);
        foreach(var upload in expired)
        {
            try{var node=root.Inspect(upload.RelativePath);if(!node.IsFile || node.Key!=upload.FileIdentity)continue;root.Unlink(upload.RelativePath);}
            catch(ApiException error)when(error.Code=="path_unavailable"){}
            db.TorrentUploads.Remove(upload);
        }
        await db.SaveChangesAsync(ct);
        IReadOnlyList<string> names;try{using var directory=root.Directory("uploads");names=directory.Names();}catch(ApiException error)when(error.Code=="path_unavailable"){return 0;}
        if(names.Count>512)throw new ApiException(507,"upload_storage_full");int removed=0;
        foreach(var name in names)
        {
            if(removed>=32)break;if(name.Length!=40 || !name.EndsWith(".torrent",StringComparison.Ordinal) || !Guid.TryParseExact(name[..32],"N",out var id) || await db.TorrentUploads.AnyAsync(x=>x.Id==id,ct))continue;
            var relative="uploads/"+name;try{var node=root.Inspect(relative);if(node.IsFile && node.Length<=16777216){root.Unlink(relative);removed++;}}catch(ApiException){}
        }
        return names.Count-removed;
    }
}
