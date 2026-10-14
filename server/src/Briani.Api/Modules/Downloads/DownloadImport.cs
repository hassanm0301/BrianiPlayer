using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Media.Processing;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Downloads;
public sealed record ImportIntent(string Source,string Destination,string Identity,long Bytes,long MtimeNs,Guid MediaId);
public sealed class DownloadImport(BrianiDb db,ITorrentEngine engine,ContainedStorage storage,WriteGate gate,TimeProvider clock,ProbeService probe,ScanWorker scanner,Briani.Api.Modules.Playback.TorrentAvailability availability)
{
    public Action<string>? TransactionBoundary{get;set;}
    public async Task ImportAsync(Guid jobId,Guid fileId,CancellationToken ct=default)
    {
        var job=await db.TorrentJobs.AsNoTracking().SingleAsync(x=>x.Id==jobId,ct);var file=await db.DownloadFiles.AsNoTracking().SingleAsync(x=>x.Id==fileId && x.TorrentJobId==jobId,ct);if(!file.Wanted || !file.Completed || file.Padding || file.Kind is not("video" or "photo" or "subtitle"))return;
        var library=await db.Libraries.AsNoTracking().SingleAsync(x=>x.Id==job.LibraryId && x.Enabled && x.Online && !x.ReadOnly,ct);
        if(job.UpstreamId is null)throw new ApiException(409,"engine_job_missing");var observed=(await engine.TorrentsAsync(job.UpstreamId,ct)).SingleOrDefault()??throw new ApiException(409,"engine_job_missing");
        if(observed.State.StartsWith("checking",StringComparison.Ordinal)||!observed.Tags.Contains(job.OwnershipTag)||Path.TrimEndingDirectorySeparator(observed.SavePath)!=Path.Combine(storage.RootPath,library.RootPath,job.ManagedPath))throw new ApiException(409,"import_not_ready");
        var pieces=await availability.GetPiecesAsync(job,ct);if(pieces.Length!=job.PieceCount || DownloadLayout.Available(file,job.PieceLength,pieces)!=file.SizeBytes)throw new ApiException(409,"import_not_ready");
        Operation op;ImportIntent intent;MediaItem? item=null;
        using(await gate.EnterAsync(ct))
        {
            db.ChangeTracker.Clear();job=await db.TorrentJobs.SingleAsync(x=>x.Id==jobId,ct);file=await db.DownloadFiles.SingleAsync(x=>x.Id==fileId,ct);library=await db.Libraries.SingleAsync(x=>x.Id==job.LibraryId,ct);
            if(!file.Completed || !file.Wanted || job.RetiredAt is not null || !library.Enabled || !library.Online || library.ReadOnly)throw new ApiException(409,"import_not_ready");
            if(file.ImportedItemId is Guid existing){var done=await db.MediaItems.SingleOrDefaultAsync(x=>x.Id==existing,ct);if(done is not null && done.Lifecycle!="available")return;if(done is not null)return;}
            if(await db.Operations.AnyAsync(x=>(x.Kind=="rename"||x.Kind=="move"||x.Kind=="trash"||x.Kind=="permanent")&&(x.State=="pending"||x.State=="running")&&db.MediaItems.Any(m=>m.DownloadFileId==fileId&&m.Id==x.TargetId),ct))return;
            using var root=storage.OpenLibrary(library);var source=job.ManagedPath+"/"+file.RelativePath;using var input=root.OpenFile(source,file.FileIdentity);var node=ContainedDirectory.Inspect(input);if(node.Length!=file.SizeBytes || node.MtimeNs!=file.MtimeNs)throw new ApiException(409,"media_changed");
            op=await db.Operations.SingleOrDefaultAsync(x=>x.Kind=="download-import" && x.TargetId==file.Id,ct)??new(){Kind="download-import",TargetId=file.Id,UserId=(await db.DownloadRequests.Where(x=>x.TorrentJobId==jobId).OrderBy(x=>x.CreatedAt).FirstAsync(ct)).OwnerId,State="pending",CreatedAt=clock.GetUtcNow(),UpdatedAt=clock.GetUtcNow(),ExpiresAt=clock.GetUtcNow().AddDays(7)};
            if(op.PayloadJson=="{}")
            {var name=ShortName(job.Name,180)+"--"+job.Id.ToString("N")[..8];var destination="Downloads/"+name+"/"+file.RelativePath;intent=new(source,destination,node.Key,node.Length,node.MtimeNs,file.ImportedItemId??Guid.NewGuid());op.PayloadJson=JsonSerializer.Serialize(intent,DownloadCommands.Json);if(db.Entry(op).State==EntityState.Detached)db.Operations.Add(op);await db.SaveChangesAsync(ct);}
            else intent=JsonSerializer.Deserialize<ImportIntent>(op.PayloadJson,DownloadCommands.Json)??throw new ApiException(409,"invalid_import_intent");
            if(intent.Identity!=node.Key || intent.Bytes!=node.Length || intent.MtimeNs!=node.MtimeNs)throw new ApiException(409,"media_changed");TransactionBoundary?.Invoke("intent_committed");
            var linked=false;Guid? parentId=null;
            if(Encoding.UTF8.GetByteCount(intent.Destination)<=4096)
            {
                parentId=await EnsureFoldersAsync(root,library,intent.Destination[..intent.Destination.LastIndexOf('/')],ct);
                try{var target=root.Inspect(intent.Destination);if(target.Key!=intent.Identity||!target.IsFile)throw new ApiException(409,"import_destination_conflict");linked=true;}
                catch(ApiException e)when(e.Code=="path_unavailable")
                {try{root.HardLink(intent.Source,intent.Destination);var target=root.Inspect(intent.Destination);if(target.Key!=intent.Identity)throw new ApiException(409,"media_changed");linked=true;}catch(ApiException failure)when(failure.Code=="hardlink_unavailable"){linked=false;}}
            }
            TransactionBoundary?.Invoke("link_applied");
            if(file.Kind!="subtitle")
            {
                item=await db.MediaItems.SingleOrDefaultAsync(x=>x.Id==intent.MediaId,ct);if(item is not null && item.Lifecycle!="available")return;
                if(item is null){item=new(){Id=intent.MediaId,LibraryId=library.Id,RelativePath=linked?intent.Destination:intent.Source,ParentRelativePath=linked?intent.Destination[..intent.Destination.LastIndexOf('/')]:"",ParentId=linked?parentId:null,DisplayName=file.DisplayName,SearchKey=ScanWorker.SearchKey(file.DisplayName),Kind=file.Kind,Extension=Path.GetExtension(file.RelativePath).ToLowerInvariant(),MimeType=ScanWorker.Mime(Path.GetExtension(file.RelativePath)),SourceKind=linked?"hardlink":"virtual",DownloadFileId=file.Id,SizeBytes=node.Length,FileIdentity=node.Key,MtimeNs=node.MtimeNs,CreatedAt=clock.GetUtcNow(),IndexedAt=clock.GetUtcNow()};db.MediaItems.Add(item);db.MediaMetadata.Add(new(){MediaItemId=item.Id,ProbeStatus="pending",ContentGeneration=item.Version});}
                else if(linked && item.SourceKind=="virtual"){item.RelativePath=intent.Destination;item.ParentRelativePath=intent.Destination[..intent.Destination.LastIndexOf('/')];item.ParentId=parentId;item.SourceKind="hardlink";item.Version++;}
                file.ImportedItemId=item.Id;
            }
            op.State="completed";op.UpdatedAt=clock.GetUtcNow();job.ImportState="complete";job.Imported=true;library.Version++;await db.SaveChangesAsync(ct);TransactionBoundary?.Invoke("catalog_committed");
        }
        if(item is not null)await ProbePendingAsync(item.Id,ct);
    }
    public async Task<bool> ProbePendingAsync(Guid mediaId,CancellationToken ct=default)
    {
        var item=await db.MediaItems.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==mediaId && x.Lifecycle=="available",ct);if(item?.DownloadFileId is not Guid fileId || !await db.DownloadFiles.AsNoTracking().AnyAsync(x=>x.Id==fileId && x.Completed,ct))return false;
        var metadata=await db.MediaMetadata.AsNoTracking().SingleOrDefaultAsync(x=>x.MediaItemId==mediaId,ct);if(metadata is not null && metadata.ProbeStatus!="pending" && metadata.ContentGeneration==item.Version)return false;
        var library=await db.Libraries.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==item.LibraryId && x.Enabled && x.Online,ct);if(library is null)return false;
        // The committed import retained a complete hashed inode. Revalidate size/mtime in ProbeService; never probe incomplete data.
        var result=await probe.ProbeAsync(item,library,ct);var cached=result.ThumbnailJpeg is {Length:>0} jpeg?await scanner.SaveThumbnailAsync(db,jpeg,ct):null;using var held=await gate.EnterAsync(ct);db.ChangeTracker.Clear();var current=await db.MediaItems.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==item.Id && x.Version==item.Version && x.Lifecycle=="available",ct);if(current is null || !await db.DownloadFiles.AnyAsync(x=>x.Id==fileId && x.Completed,ct))return true;
        var target=await db.MediaMetadata.SingleOrDefaultAsync(x=>x.MediaItemId==item.Id,ct);if(target is null){target=new(){MediaItemId=item.Id};db.MediaMetadata.Add(target);}
        target.DurationMs=result.DurationMs;target.Width=result.Width;target.Height=result.Height;target.Rotation=result.Rotation;target.ExifOrientation=result.ExifOrientation;target.VideoCodec=result.VideoCodec;target.TracksJson=JsonSerializer.Serialize(result.Tracks);target.Container=result.Container;target.ProbeStatus=result.ProbeStatus=="pending"?"failed":result.ProbeStatus;target.ProbeErrorCode=result.ProbeErrorCode;if(result.ProbeStatus=="pending"){var unavailable=await db.MediaItems.SingleAsync(x=>x.Id==item.Id,ct);unavailable.Lifecycle="missing";unavailable.MissingSince=clock.GetUtcNow();unavailable.Version++;var ownerLibrary=await db.Libraries.SingleAsync(x=>x.Id==item.LibraryId,ct);ownerLibrary.Version++;}target.ProbeVersion=result.ProbeVersion;target.ContentGeneration=item.Version;if(cached is not null && current.Lifecycle=="available" && result.ProbeStatus=="ready" && !await db.ThumbnailEntries.AnyAsync(x=>x.MediaItemId==item.Id && x.Generation==item.Version && x.Variant=="default",ct))db.ThumbnailEntries.Add(new(){MediaItemId=item.Id,Generation=item.Version,Variant="default",CacheRelativePath=cached.Path,FileIdentity=cached.FileIdentity,Bytes=cached.Bytes,CreatedAt=clock.GetUtcNow(),LastAccessedAt=clock.GetUtcNow()});await db.SaveChangesAsync(ct);return true;
    }
    private async Task<Guid?> EnsureFoldersAsync(ContainedDirectory root,Library library,string relative,CancellationToken ct)
    {
        var path="";Guid? parent=null;foreach(var name in relative.Split('/'))
        {var previous=path;path=path==""?name:path+"/"+name;DownloadCommands.EnsureDirectory(root,path);var node=root.Inspect(path);var item=await db.MediaItems.SingleOrDefaultAsync(x=>x.LibraryId==library.Id&&x.RelativePath==path,ct);if(item is null){item=new(){LibraryId=library.Id,RelativePath=path,ParentRelativePath=previous,ParentId=parent,DisplayName=name,SearchKey=ScanWorker.SearchKey(name),Kind="folder",MimeType="inode/directory",FileIdentity=node.Key,MtimeNs=node.MtimeNs,CreatedAt=clock.GetUtcNow(),IndexedAt=clock.GetUtcNow()};db.MediaItems.Add(item);}else if(item.Kind!="folder" || item.FileIdentity!=node.Key)throw new ApiException(409,"import_destination_conflict");parent=item.Id;}return parent;
    }
    private static string ShortName(string name,int maxBytes){var builder=new StringBuilder();foreach(var rune in name.EnumerateRunes()){if(Encoding.UTF8.GetByteCount(builder.ToString())+rune.Utf8SequenceLength>maxBytes)break;builder.Append(rune);}return builder.Length==0?"Download":builder.ToString();}
}
