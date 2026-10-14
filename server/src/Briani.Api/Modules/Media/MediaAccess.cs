using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Media;
public sealed class MediaAccess(BrianiDb db,PermissionService permissions,ContainedStorage storage)
{
    public async Task<(MediaItem Item,Library Library)> RequireAsync(Actor actor,Guid id,string capability="read",CancellationToken ct=default)
    {
        var item=await db.MediaItems.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id && x.Lifecycle=="available",ct)??throw new ApiException(404,"not_found");
        var library=await permissions.RequireLibraryAsync(actor,item.LibraryId,capability,ct);return(item,library);
    }
    public FileStream Open(MediaItem item,Library library)
    {if(item.DownloadFileId is Guid downloadId){var download=db.DownloadFiles.AsNoTracking().SingleOrDefault(x=>x.Id==downloadId);if(download?.Completed!=true || db.TorrentJobs.Any(j=>j.Id==download.TorrentJobId && j.DesiredState=="removing") || db.Operations.Any(o=>o.InvalidatesPlayback && (o.State=="pending" || o.State=="running") && db.DownloadRequests.Any(r=>r.Id==o.TargetId && r.TorrentJobId==download.TorrentJobId)))throw new ApiException(409,"download_not_complete");}using var directory=storage.OpenLibrary(library);var file=directory.OpenFile(item.RelativePath,item.FileIdentity);try{var node=ContainedDirectory.Inspect(file);if(item.SizeBytes!=node.Length || item.MtimeNs!=node.MtimeNs)throw new ApiException(409,"media_changed");return file;}catch{file.Dispose();throw;}}
    public static string Generation(MediaItem item)=>Credentials.Hash($"{item.Id}:{item.FileIdentity}:{item.SizeBytes}:{item.MtimeNs}:{item.Version}");
}
