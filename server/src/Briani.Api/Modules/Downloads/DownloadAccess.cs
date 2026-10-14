using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Downloads;
public sealed class DownloadAccess(BrianiDb db,PermissionService permissions)
{
    public async Task<(DownloadRequest Request,Library Library,TorrentJob? Job)> RequireAsync(Actor actor,Guid id,CancellationToken ct=default)
    {
        var request=await db.DownloadRequests.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id,ct)??throw new ApiException(404,"not_found");var library=await permissions.RequireLibraryAsync(actor,request.LibraryId,ct:ct);var capabilities=await permissions.CapabilitiesAsync(actor,library,ct);
        if(request.OwnerId!=actor.UserId && !capabilities.Manage)throw new ApiException(404,"not_found");var job=request.TorrentJobId is Guid jobId?await db.TorrentJobs.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==jobId && x.LibraryId==library.Id,ct):null;return(request,library,job);
    }
    public async Task RequireControlAsync(Actor actor,DownloadRequest request,bool destructive=false,CancellationToken ct=default)
    {var shared=request.TorrentJobId is Guid id && await db.DownloadRequests.AnyAsync(x=>x.TorrentJobId==id && x.Id!=request.Id && x.RemovedAt==null,ct);await permissions.RequireDownloadControlAsync(actor,request.LibraryId,request.OwnerId,shared,destructive,ct);}
    public async Task RequireCommandAsync(Actor actor,DownloadRequest request,DownloadCommand command,CancellationToken ct=default)
    {
        // Creating a source requires download; manage independently authorizes existing lifecycle controls.
        if(command.Action=="add"){await permissions.RequireLibraryAsync(actor,request.LibraryId,"download",ct);return;}
        var library=await permissions.RequireLibraryAsync(actor,request.LibraryId,ct:ct);
        if((await permissions.CapabilitiesAsync(actor,library,ct)).Manage){await permissions.RequireLibraryAsync(actor,library.Id,"manage",ct);return;}
        if(request.OwnerId==actor.UserId && !command.DeleteData && (command.Action=="remove" || command.Action=="select" && command.Selection is not null &&
            (await DownloadCommands.CompatibleSelectionAsync(db,request,command.Selection,ct) || !await db.DownloadRequestFiles.AnyAsync(x=>x.Selected && x.DownloadRequestId!=request.Id && db.DownloadRequests.Any(r=>r.Id==x.DownloadRequestId && r.TorrentJobId==request.TorrentJobId && r.RemovedAt==null),ct))))
        {await permissions.RequireLibraryAsync(actor,library.Id,"download",ct);return;}
        await RequireControlAsync(actor,request,command.DeleteData,ct);
    }
    public async Task<Actor> RequestActorAsync(DownloadRequest request,CancellationToken ct)
    {var user=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==request.OwnerId && x.Enabled && !x.MustChangePassword,ct)??throw new ApiException(403,"forbidden");return new(user.Id,request.AuthSessionId,user.Role);}
}
