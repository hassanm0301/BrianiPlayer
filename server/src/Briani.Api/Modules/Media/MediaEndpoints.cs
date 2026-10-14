using System.Buffers;
using System.Text.Json.Serialization;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Playback;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Media;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record ProgressUpdate([property:JsonRequired]long PositionMs,[property:JsonRequired]long? DurationMs,[property:JsonRequired]long Version,bool? Watched);
public static class MediaEndpoints
{
    private static object ProgressView(PlaybackProgress p)=>new{positionMs=p.PositionMs,durationMs=p.DurationMs,watched=p.Completed,updatedAt=p.UpdatedAt,version=p.Version};
    public static void Map(WebApplication app)
    {
        app.MapGet("/api/v1/media/{id:guid}/image",async(Guid id,HttpContext c,MediaAccess access,BrianiDb db,PermissionService permissions,MediaReaders readers,TimeProvider clock,WriteGate gate,IServiceScopeFactory scopes)=>
        {
            FileStream file;MediaReaders.Lease lease;MediaItem item;
            using(await gate.EnterAsync(c.RequestAborted)) {
            var a=Actor.From(c.User);var(found,library)=await access.RequireAsync(a,id,ct:c.RequestAborted);item=found;if(item.Kind!="photo")throw new ApiException(404,"not_found");
            var metadata=await db.MediaMetadata.AsNoTracking().SingleOrDefaultAsync(x=>x.MediaItemId==id,c.RequestAborted);
            if(metadata is null || metadata.ProbeStatus!="ready" || metadata.ContentGeneration!=item.Version || metadata.Width is null || metadata.Height is null || (long)metadata.Width*metadata.Height>40000000)throw new ApiException(409,"image_unavailable");
            file=access.Open(item,library);try{lease=readers.Acquire(a.SessionId,item.Id,c.RequestAborted);}catch{file.Dispose();throw;}
            }
            using(file)using(lease)await CopyAsync(c,file,item.MimeType,Actor.From(c.User),item,scopes,clock,lease);
        });
        app.MapGet("/api/v1/media/{id:guid}/thumbnail",async(Guid id,HttpContext c,MediaAccess access,BrianiDb db,PermissionService permissions,MediaReaders readers,TimeProvider clock,ServerOptions options,WriteGate gate,IServiceScopeFactory scopes)=>
        {
            FileStream file;MediaReaders.Lease lease;MediaItem item;
            using(await gate.EnterAsync(c.RequestAborted)){
            var a=Actor.From(c.User);var(found,_)=await access.RequireAsync(a,id,ct:c.RequestAborted);item=found;var t=await db.ThumbnailEntries.AsNoTracking().SingleOrDefaultAsync(x=>x.MediaItemId==id && x.Generation==item.Version && x.Variant=="default",c.RequestAborted)??throw new ApiException(404,"not_found");
            using var root=new ContainedDirectory(options.StateRoot);file=root.OpenFile(t.CacheRelativePath,t.FileIdentity);try{if(file.Length!=t.Bytes || t.Bytes>524288)throw new ApiException(409,"thumbnail_unavailable");lease=readers.Acquire(a.SessionId,item.Id,c.RequestAborted);}catch{file.Dispose();throw;}
            }
            using(file)using(lease)await CopyAsync(c,file,"image/jpeg",Actor.From(c.User),item,scopes,clock,lease);
        });
        app.MapGet("/api/v1/media/{id:guid}/progress",async(Guid id,HttpContext c,MediaAccess access,BrianiDb db,TimeProvider clock)=>
        {var a=Actor.From(c.User);await access.RequireAsync(a,id,ct:c.RequestAborted);var p=await db.PlaybackProgress.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==a.UserId && x.MediaItemId==id,c.RequestAborted)??new(){UserId=a.UserId,MediaItemId=id,UpdatedAt=clock.GetUtcNow()};return Results.Ok(ProgressView(p));});
        app.MapPut("/api/v1/media/{id:guid}/progress",async(Guid id,ProgressUpdate r,HttpContext c,MediaAccess access,BrianiDb db,WriteGate gate,TimeProvider clock)=>
        {
            if(r.PositionMs<0 || r.DurationMs<0 || r.Version<1 || r.DurationMs is long d && r.PositionMs>d)throw new ApiException(400,"invalid_progress");
            var a=Actor.From(c.User);using var lease=await gate.EnterAsync(c.RequestAborted);var(item,_)=await access.RequireAsync(a,id,ct:c.RequestAborted);if(item.Kind!="video")throw new ApiException(400,"invalid_progress_target");
            var p=await db.PlaybackProgress.SingleOrDefaultAsync(x=>x.UserId==a.UserId && x.MediaItemId==id,c.RequestAborted);if(p is not null && p.Version!=r.Version || p is null && r.Version!=1)throw new ApiException(409,"version_conflict");
            if(p is null){p=new(){UserId=a.UserId,MediaItemId=id,Version=2};db.PlaybackProgress.Add(p);}else p.Version++;
            var metadata=await db.MediaMetadata.AsNoTracking().SingleOrDefaultAsync(x=>x.MediaItemId==id,c.RequestAborted);var duration=metadata?.ContentGeneration==item.Version?metadata.DurationMs:null;
            if(r.DurationMs is long given && duration is long actual && Math.Abs((decimal)given-actual)>Math.Max(5000,actual/20))throw new ApiException(400,"invalid_duration");
            p.PositionMs=r.PositionMs;p.DurationMs=duration??r.DurationMs;p.Completed=r.Watched??(duration is >0 && (decimal)r.PositionMs/duration.Value>=.95m);p.UpdatedAt=clock.GetUtcNow();p.ClientEventId=Guid.NewGuid();await db.SaveChangesAsync(c.RequestAborted);return Results.Ok(ProgressView(p));
        });
        app.MapGet("/api/v1/me/continue-watching",async(HttpContext c,BrianiDb db,MediaAccess access,PageCursor pages,int? limit,string? cursor)=>
        {
            var count=limit??50;if(count is <1 or >200)throw new ApiException(400,"invalid_pagination");var a=Actor.From(c.User);var offset=pages.Decode(cursor,$"continue:{a.UserId}");
            var administrator=await db.Users.AsNoTracking().AnyAsync(x=>x.Id==a.UserId && x.Enabled && x.Role=="administrator",c.RequestAborted);
            var query=from progress in db.PlaybackProgress.AsNoTracking() join item in db.MediaItems.AsNoTracking() on progress.MediaItemId equals item.Id join library in db.Libraries.AsNoTracking() on item.LibraryId equals library.Id
                where progress.UserId==a.UserId && !progress.Completed && progress.PositionMs>0 && item.Kind=="video" && item.Lifecycle=="available" && library.Enabled && library.Online && (administrator || db.LibraryGrants.Any(g=>g.UserId==a.UserId && g.LibraryId==library.Id && g.CanRead))
                orderby progress.UpdatedAt descending, progress.MediaItemId select new{progress,item};
            var values=await query.Skip(offset).Take(count+1).ToArrayAsync(c.RequestAborted);var result=new List<object>();
            foreach(var v in values.Take(count)){try{var(item,_)=await access.RequireAsync(a,v.item.Id,ct:c.RequestAborted);var meta=await db.MediaMetadata.AsNoTracking().SingleOrDefaultAsync(x=>x.MediaItemId==item.Id,c.RequestAborted);var tracks=System.Text.Json.JsonSerializer.Deserialize<MediaTrack[]>(meta?.TracksJson??"[]");
                result.Add(new{media=new{id=item.Id,libraryId=item.LibraryId,entryId=item.Id,name=item.DisplayName,kind=item.Kind,mimeType=item.MimeType,sizeBytes=item.SizeBytes??0,durationMs=meta?.DurationMs,width=meta?.Width,height=meta?.Height,tracks,complete=true,probeState=meta?.ContentGeneration==item.Version?meta.ProbeStatus:"pending",version=item.Version},progress=ProgressView(v.progress)});
            }catch(ApiException e)when(e.Status==404){}}
            return Results.Ok(new{items=result,nextCursor=values.Length>count && offset+count<10000?pages.Encode($"continue:{a.UserId}",offset+count):null,totalKnown=(long?)null,truncated=offset+count>=10000 && values.Length>count,warnings=Array.Empty<string>()});
        });
    }
    internal static async Task CopyAsync(HttpContext c,FileStream file,string type,Actor actor,MediaItem original,IServiceScopeFactory scopes,TimeProvider clock,MediaReaders.Lease lease)
    {
        var ct=lease.Token;c.Response.ContentType=type;c.Response.ContentLength=file.Length;c.Response.Headers.CacheControl="private, no-store";
        var buffer=ArrayPool<byte>.Shared.Rent(262144);using var stop=CancellationTokenSource.CreateLinkedTokenSource(ct);
        var watcher=WatchAsync(c,actor,original,scopes,clock,lease,stop.Token);
        try{long remaining=file.Length;while(remaining>0){ct.ThrowIfCancellationRequested();var wanted=(int)Math.Min(remaining,262144);await file.ReadExactlyAsync(buffer.AsMemory(0,wanted),ct);await c.Response.Body.WriteAsync(buffer.AsMemory(0,wanted),ct);remaining-=wanted;}}
        catch(OperationCanceledException)when(ct.IsCancellationRequested){c.Abort();}
        catch{if(c.Response.HasStarted){c.Abort();return;}throw;}
        finally{stop.Cancel();try{await watcher;}catch(OperationCanceledException){}ArrayPool<byte>.Shared.Return(buffer);}
    }
    private static async Task WatchAsync(HttpContext context,Actor actor,MediaItem original,IServiceScopeFactory scopes,TimeProvider clock,MediaReaders.Lease lease,CancellationToken stop)
    {
        try{while(true){await Task.Delay(TimeSpan.FromSeconds(1),clock,stop);using var scope=scopes.CreateScope();
            var permissions=scope.ServiceProvider.GetRequiredService<PermissionService>();if(!await permissions.IsAccessValidAsync(actor,stop))throw new ApiException(401,"session_expired");
            var access=scope.ServiceProvider.GetRequiredService<MediaAccess>();var(item,library)=await access.RequireAsync(actor,original.Id,ct:stop);
            if(MediaAccess.Generation(item)!=MediaAccess.Generation(original))throw new ApiException(409,"media_changed");using var source=access.Open(item,library);
        }}catch(OperationCanceledException)when(stop.IsCancellationRequested){}catch{lease.Cancel();context.Abort();}
    }
}
