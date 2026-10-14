using System.Buffers;
using System.Text;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;
using Briani.Api.Modules.Preferences;
namespace Briani.Api.Modules.Playback;

// Derived capabilities are independently bound to one sidecar's inode/content and
// the parent session's current ticket hash. No ordinary account token enters a URL.
public sealed class SubtitleDelivery(BrianiDb db,MediaAccess media,PermissionService permissions,SecretStore secrets,ContainedStorage storage,WriteGate gate,MediaReaders readers,IServiceScopeFactory scopes,TimeProvider clock,TorrentAvailability availability)
{
    private readonly BrianiDb database=db;
    private const int MaximumBytes=4*1024*1024;
    private sealed record Candidate(Guid Id,Library Library,string Path,string Name,string Identity,long Bytes,long MtimeNs);
    private static bool Supported(string name)=>Path.GetExtension(name).ToLowerInvariant() is ".srt" or ".ass" or ".ssa" or ".vtt";
    private static bool Related(string video,string subtitle)=>Supported(subtitle) && Path.GetFileNameWithoutExtension(subtitle).StartsWith(Path.GetFileNameWithoutExtension(video)+".",StringComparison.OrdinalIgnoreCase) || Supported(subtitle) && Path.GetFileNameWithoutExtension(subtitle).Equals(Path.GetFileNameWithoutExtension(video),StringComparison.OrdinalIgnoreCase);
    private static string Parent(string path)=>path.Contains('/')?path[..path.LastIndexOf('/')]:"";
    private static string Mime(string name)=>Path.GetExtension(name).ToLowerInvariant() switch{".vtt"=>"text/vtt; charset=utf-8",".srt"=>"application/x-subrip; charset=utf-8",_=>"text/plain; charset=utf-8"};
    private string Signature(PlaybackSession s,Candidate f)=>secrets.Digest($"subtitle-v1:{s.Id:N}:{s.TicketHash}:{s.TargetGeneration}:{f.Id:N}:{f.Library.Id:N}:{f.Path}:{f.Identity}:{f.Bytes}:{f.MtimeNs}");
    private string Token(PlaybackSession s,Candidate f)=>$"s.{s.Id:N}.{f.Id:N}.{Signature(s,f)}";
    private async Task<(Actor Actor,List<Candidate> Files)> ResolveAsync(PlaybackSession session,CancellationToken ct)
    {
        if(!session.TicketIssued || session.RevokedAt is not null || PlaybackExpiry.Expired(session,clock.GetUtcNow()) || !await permissions.IsSessionValidAsync(session.AuthSessionId,ct))throw new ApiException(404,"not_found");
        var user=await database.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==session.UserId && x.Enabled && !x.MustChangePassword,ct)??throw new ApiException(404,"not_found");var actor=new Actor(user.Id,session.AuthSessionId,user.Role);
        var candidates=new List<Candidate>(16);MediaItem? item=null;DownloadFile? video=null;Library library;
        if(session.MediaItemId is Guid mediaId)
        {
            (item,library)=await media.RequireAsync(actor,mediaId,ct:ct);
            if(item.Kind!="video" || MediaAccess.Generation(item)!=session.TargetGeneration)throw new ApiException(404,"not_found");using var held=media.Open(item,library);
            if(item.SourceKind!="virtual")
            {
                using var root=storage.OpenLibrary(library);var directory=Parent(item.RelativePath);
                foreach(var name in root.Names(directory).Where(n=>Related(item.DisplayName,n)).Take(16))
                {
                    var path=directory==""?name:directory+"/"+name;
                    try{var node=root.Inspect(path);if(!node.IsFile || node.Length<=0 || node.Length>MaximumBytes)continue;var id=new Guid(Convert.FromHexString(secrets.Digest($"subtitle-file:{library.Id}:{path}")[..32]));candidates.Add(new(id,library,path,name,node.Key,node.Length,node.MtimeNs));}catch(ApiException){}
                }
            }
            if(item.DownloadFileId is Guid downloadId)video=await database.DownloadFiles.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==downloadId,ct);
        }
        else if(session.DownloadFileId is Guid fileId)
        {
            video=await database.DownloadFiles.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==fileId && x.Wanted && !x.Padding && x.Kind=="video",ct)??throw new ApiException(404,"not_found");
            var job=await database.TorrentJobs.AsNoTracking().SingleAsync(x=>x.Id==video.TorrentJobId,ct);library=await permissions.RequireLibraryAsync(actor,job.LibraryId,ct:ct);
            using var subscription=availability.Subscribe(job.Id);
            if(job.RetiredAt is not null || job.PayloadRemoved || job.DesiredState=="removing" || session.TargetGeneration!=availability.Generation(job,subscription.Source) || await TorrentAvailability.PendingAsync(database,job.Id,ct))throw new ApiException(404,"not_found");
        }
        else throw new ApiException(404,"not_found");
        if(video is not null && candidates.Count<16)
        {
            var job=await database.TorrentJobs.AsNoTracking().SingleAsync(x=>x.Id==video.TorrentJobId,ct);
            if(job.RetiredAt is null && !job.PayloadRemoved && job.DesiredState!="removing" && !await TorrentAvailability.PendingAsync(database,job.Id,ct))
            {
                library=await permissions.RequireLibraryAsync(actor,job.LibraryId,ct:ct);using var root=storage.OpenLibrary(library);
                var files=await database.DownloadFiles.AsNoTracking().Where(x=>x.TorrentJobId==job.Id && x.Wanted && x.Completed && !x.Padding && x.Kind=="subtitle" && x.SizeBytes>0 && x.SizeBytes<=MaximumBytes).OrderBy(x=>x.MetadataFileIndex).Take(10000).ToArrayAsync(ct);
                foreach(var f in files.Where(f=>Parent(f.RelativePath)==Parent(video.RelativePath) && Related(video.DisplayName,f.DisplayName)).Take(16-candidates.Count))
                {
                    var path=job.ManagedPath+"/"+f.RelativePath;
                    try{var node=root.Inspect(path);if(!node.IsFile || node.Key!=f.FileIdentity || node.Length!=f.SizeBytes || node.MtimeNs!=f.MtimeNs)continue;candidates.Add(new(f.Id,library,path,f.DisplayName,node.Key,node.Length,node.MtimeNs));}catch(ApiException){}
                }
            }
        }
        return(actor,candidates);
    }
    public async Task<PlaybackSidecarView[]> DescribeAsync(PlaybackSession session,HttpContext context,CancellationToken ct)
    {
        if(!session.TicketIssued)return[];
        try{var(_,files)=await ResolveAsync(session,ct);var origin=await AdministratorConfiguration.OriginAsync(database,context,ct);return files.Select(f=>new PlaybackSidecarView(f.Id,f.Name,null,Mime(f.Name),$"{origin}/stream/{Token(session,f)}/{Uri.EscapeDataString(f.Name)}")).ToArray();}
        catch(ApiException){return[];}
    }
    public async Task StreamAsync(string token,string name,HttpContext c)
    {
        var parts=token.Split('.');if(parts.Length!=4 || parts[0]!="s" || parts[1].Length!=32 || parts[2].Length!=32 || parts[3].Length!=64 || !Guid.TryParseExact(parts[1],"N",out var sessionId) || !Guid.TryParseExact(parts[2],"N",out var fileId) || parts[3].Any(x=>!Uri.IsHexDigit(x)))throw new ApiException(404,"not_found");
        FileStream descriptor;Candidate file;PlaybackSession session;MediaReaders.Lease lease;
        using(await gate.EnterAsync(c.RequestAborted))
        {
            session=await database.PlaybackSessions.SingleOrDefaultAsync(x=>x.Id==sessionId,c.RequestAborted)??throw new ApiException(404,"not_found");var(_,files)=await ResolveAsync(session,c.RequestAborted);
            file=files.SingleOrDefault(x=>x.Id==fileId && x.Name==name)??throw new ApiException(404,"not_found");if(!Credentials.EqualHash(parts[3],Signature(session,file)))throw new ApiException(404,"not_found");
            using var root=storage.OpenLibrary(file.Library);descriptor=root.OpenFile(file.Path,file.Identity);
            try{var stat=ContainedDirectory.Inspect(descriptor);if(stat.Length!=file.Bytes || stat.MtimeNs!=file.MtimeNs)throw new ApiException(404,"not_found");lease=readers.Acquire(session.Id,session.MediaItemId??session.DownloadFileId??fileId,c.RequestAborted);try{session.ActivatedAt??=clock.GetUtcNow();session.LastActivityAt=clock.GetUtcNow();await database.SaveChangesAsync(c.RequestAborted);}catch{lease.Dispose();throw;}}catch{descriptor.Dispose();throw;}
        }
        using(descriptor)using(lease)
        {
            c.Response.Headers.AcceptRanges="bytes";c.Response.Headers.CacheControl="private, no-store";c.Response.Headers.XContentTypeOptions="nosniff";c.Response.ContentType=Mime(name);
            if(HttpMethods.IsHead(c.Request.Method)){c.Response.ContentLength=file.Bytes;return;}
            ByteRange range;try{range=ByteRange.Parse(c.Request.Headers.IfRange.Count>0?null:c.Request.Headers.Range.ToString(),file.Bytes);}catch(RangeException error){if(error.Unsatisfiable)c.Response.Headers.ContentRange=$"bytes */{file.Bytes}";throw new ApiException(error.Unsatisfiable?416:400,"range_invalid");}
            var bytes=ArrayPool<byte>.Shared.Rent((int)file.Bytes);using var stop=CancellationTokenSource.CreateLinkedTokenSource(lease.Token);var watch=WatchAsync(session.Id,file,parts[3],lease,c,stop.Token);
            try
            {
                await descriptor.ReadExactlyAsync(bytes.AsMemory(0,(int)file.Bytes),lease.Token);
                var text=new UTF8Encoding(false,true).GetString(bytes,0,(int)file.Bytes);if(text.Contains('\0'))throw new ApiException(409,"subtitle_invalid");
                var stat=ContainedDirectory.Inspect(descriptor);if(stat.Key!=file.Identity || stat.Length!=file.Bytes || stat.MtimeNs!=file.MtimeNs)throw new ApiException(409,"media_changed");
                c.Response.StatusCode=range.Partial?206:200;c.Response.ContentLength=range.Length;if(range.Partial)c.Response.Headers.ContentRange=$"bytes {range.Start}-{range.End}/{file.Bytes}";
                long offset=range.Start,remaining=range.Length;while(remaining>0){var count=(int)Math.Min(remaining,262144);await c.Response.Body.WriteAsync(bytes.AsMemory((int)offset,count),lease.Token);offset+=count;remaining-=count;}
            }
            catch(DecoderFallbackException){if(c.Response.HasStarted)c.Abort();else throw new ApiException(409,"subtitle_invalid");}
            catch(OperationCanceledException)when(lease.Token.IsCancellationRequested){c.Abort();}
            catch{if(c.Response.HasStarted)c.Abort();else throw;}
            finally{stop.Cancel();try{await watch;}catch(OperationCanceledException){}ArrayPool<byte>.Shared.Return(bytes,true);}
        }
    }
    private async Task WatchAsync(Guid id,Candidate original,string signature,MediaReaders.Lease lease,HttpContext context,CancellationToken ct)
    {
        var lastPersist=clock.GetUtcNow();
        try{while(true){await Task.Delay(TimeSpan.FromSeconds(1),clock,ct);using var scope=scopes.CreateScope();var service=scope.ServiceProvider.GetRequiredService<SubtitleDelivery>();var session=await service.database.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id,ct)??throw new ApiException(404,"not_found");var(_,files)=await service.ResolveAsync(session,ct);var live=files.SingleOrDefault(x=>x.Id==original.Id)??throw new ApiException(404,"not_found");if(!Credentials.EqualHash(signature,service.Signature(session,live)))throw new ApiException(404,"not_found");var now=clock.GetUtcNow();if(now-lastPersist>=TimeSpan.FromSeconds(15)){using(await gate.EnterAsync(ct))await service.database.PlaybackSessions.Where(x=>x.Id==id && x.RevokedAt==null).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.LastActivityAt,now),ct);lastPersist=now;}}}
        catch(OperationCanceledException)when(ct.IsCancellationRequested){}
        catch{lease.Cancel();context.Abort();}
    }
}
