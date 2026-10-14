using System.Buffers;
using Briani.Api.Modules.Preferences;
using System.Text.Json.Serialization;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Playback;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record PlaybackTarget([property:JsonRequired]string Kind,[property:JsonRequired]Guid Id);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record PlaybackCreate([property:JsonRequired]PlaybackTarget Target,[property:JsonRequired]string Mode,long InitialPositionMs=0);
public sealed class CompletedPlayback(BrianiDb db,MediaAccess media,PermissionService permissions,WriteGate gate,TimeProvider clock,MediaReaders readers,IServiceScopeFactory scopes,ContainedStorage storage,SecretStore secrets,SubtitleDelivery subtitles)
{
    public static void Map(WebApplication app)
    {
        app.MapPost("/api/v1/playback/sessions",async (PlaybackCreate request,HttpContext c,CompletedPlayback p,ProgressivePlayback progressive)=>Results.Json(request.Target?.Kind=="downloadFile"?await progressive.CreateAsync(Actor.From(c.User),request,c):await p.CreateAsync(Actor.From(c.User),request,c),statusCode:201));
        app.MapGet("/api/v1/playback/sessions/{id:guid}",async(Guid id,HttpContext c,CompletedPlayback p,ProgressivePlayback progressive,BrianiDb db)=>Results.Ok(await db.PlaybackSessions.AsNoTracking().AnyAsync(x=>x.Id==id && x.UserId==Actor.From(c.User).UserId && x.DownloadFileId!=null,c.RequestAborted)?await progressive.StatusAsync(Actor.From(c.User),id,c):await p.StatusAsync(Actor.From(c.User),id,c)));
        app.MapDelete("/api/v1/playback/sessions/{id:guid}",async(Guid id,HttpContext c,CompletedPlayback p)=>{await p.RevokeAsync(Actor.From(c.User),id,c.RequestAborted);return Results.NoContent();});
        app.MapMethods("/stream/{ticket}/{fileName}",["GET","HEAD"],async(string ticket,string fileName,HttpContext c,CompletedPlayback p,ProgressivePlayback progressive,SubtitleDelivery subtitles,BrianiDb db)=>{if(ticket.Length>200)throw new ApiException(404,"not_found");if(ticket.StartsWith("s.",StringComparison.Ordinal)){await subtitles.StreamAsync(ticket,fileName,c);return;}if(ticket.Length!=43)throw new ApiException(404,"not_found");var hash=Credentials.Hash(ticket);if(await db.PlaybackSessions.AsNoTracking().AnyAsync(x=>x.TicketHash==hash && x.DownloadFileId!=null,c.RequestAborted))await progressive.StreamAsync(ticket,fileName,c);else await p.StreamAsync(ticket,fileName,c);}).AllowAnonymous();
    }
    public async Task<object> CreateAsync(Actor a,PlaybackCreate request,HttpContext c)
    {
        if(request.Target is null || request.Target.Kind!="media" || request.Mode is not ("internal" or "external") || request.InitialPositionMs<0)throw new ApiException(400,"invalid_playback_target");
        using var lease=await gate.EnterAsync(c.RequestAborted);var(item,library)=await media.RequireAsync(a,request.Target.Id,ct:c.RequestAborted);
        var key=c.Request.Headers["Idempotency-Key"].ToString();if(key.Length>200 || key.Any(char.IsControl))throw new ApiException(400,"invalid_idempotency_key");var storedKey=key==""?null:Credentials.Hash(key);
        var digest=secrets.Digest(System.Text.Json.JsonSerializer.Serialize(request));
        if(storedKey is not null){var old=await db.Operations.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==a.UserId && x.Kind=="playback-create" && x.IdempotencyKey==storedKey,c.RequestAborted);if(old is not null){if(!Credentials.EqualHash(old.RequestHash,digest))throw new ApiException(409,"idempotency_conflict");var replay=await db.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==old.TargetId && x.UserId==a.UserId && x.AuthSessionId==a.SessionId,c.RequestAborted)??throw new ApiException(409,"idempotency_session_changed");return await ViewAsync(replay,item,null,replay.RevokedAt is not null?"revoked":Expired(replay)?"expired":replay.TargetGeneration!=MediaAccess.Generation(item)?"unavailable":"ready",c);}}
        if(item.Kind!="video" || item.SizeBytes is null || item.SizeBytes==0)throw new ApiException(409,"unsupported_format");using var file=media.Open(item,library);
        await PlaybackAdmission.RequireAsync(db,a.UserId,clock.GetUtcNow(),c.RequestAborted);
        var metadata=await db.MediaMetadata.AsNoTracking().SingleOrDefaultAsync(x=>x.MediaItemId==item.Id,c.RequestAborted);if(metadata?.ProbeStatus!="ready" || metadata.ContentGeneration!=item.Version)throw new ApiException(409,"metadata_pending");
        var now=clock.GetUtcNow();var token=Credentials.NewToken();var s=new PlaybackSession{UserId=a.UserId,AuthSessionId=a.SessionId,MediaItemId=item.Id,TargetGeneration=MediaAccess.Generation(item),TicketHash=Credentials.Hash(token),Mode=request.Mode,CreatedAt=now,FirstUseDeadline=now.AddMinutes(10),AbsoluteExpiresAt=now.AddHours(24),InitialPositionMs=request.InitialPositionMs};db.PlaybackSessions.Add(s);if(storedKey is not null)db.Operations.Add(new(){UserId=a.UserId,Kind="playback-create",TargetId=s.Id,IdempotencyKey=storedKey,RequestHash=digest,State="completed",CreatedAt=now,UpdatedAt=now,ExpiresAt=now.AddDays(1)});await db.SaveChangesAsync(c.RequestAborted);
        return await ViewAsync(s,item,$"{await AdministratorConfiguration.OriginAsync(db,c,c.RequestAborted)}/stream/{token}/{Uri.EscapeDataString(item.DisplayName)}", "ready",c);
    }
    private async Task<object> ViewAsync(PlaybackSession s,MediaItem item,string? url,string state,HttpContext c)=>new{id=s.Id,state,streamUrl=url,activationExpiresAt=s.FirstUseDeadline,idleExpiresAt=s.LastActivityAt?.AddMinutes(30),absoluteExpiresAt=s.AbsoluteExpiresAt,generation=s.TargetGeneration,contiguousBytes=item.SizeBytes??0,totalBytes=item.SizeBytes,mimeType=item.MimeType,fileName=item.DisplayName,sidecars=await subtitles.DescribeAsync(s,c,c.RequestAborted)};
    public async Task<object> StatusAsync(Actor a,Guid id,HttpContext c)
    {var ct=c.RequestAborted;var s=await db.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id && x.UserId==a.UserId,ct)??throw new ApiException(404,"not_found");var(item,_)=await media.RequireAsync(a,s.MediaItemId??Guid.Empty,ct:ct);return await ViewAsync(s,item,null,s.RevokedAt is not null || !await permissions.IsSessionValidAsync(s.AuthSessionId,ct)?"revoked":Expired(s)?"expired":s.TargetGeneration!=MediaAccess.Generation(item)?"unavailable":"ready",c);}
    public async Task RevokeAsync(Actor a,Guid id,CancellationToken ct)
    {using var lease=await gate.EnterAsync(ct);var s=await db.PlaybackSessions.SingleOrDefaultAsync(x=>x.Id==id && x.UserId==a.UserId,ct)??throw new ApiException(404,"not_found");s.RevokedAt=clock.GetUtcNow();await db.SaveChangesAsync(ct);readers.CancelSession(s.Id);}
    private bool Expired(PlaybackSession s){var now=clock.GetUtcNow();return now>=s.AbsoluteExpiresAt || (s.ActivatedAt is null?now>=s.FirstUseDeadline:s.LastActivityAt is null || now>=s.LastActivityAt.Value.AddMinutes(30));}
    private async Task<Actor> ActorAsync(PlaybackSession s,CancellationToken ct)
    {var u=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==s.UserId && x.Enabled && !x.MustChangePassword,ct);if(u is null || !await permissions.IsSessionValidAsync(s.AuthSessionId,ct))throw new ApiException(404,"not_found");return new(u.Id,s.AuthSessionId,u.Role);}
    public async Task StreamAsync(string ticket,string name,HttpContext c)
    {
        var ct=c.RequestAborted;if(ticket.Length!=43)throw new ApiException(404,"not_found");var hash=Credentials.Hash(ticket);PlaybackSession session;MediaItem item;Library library;FileStream file;MediaReaders.Lease readerLease;
        using(await gate.EnterAsync(ct))
        {
            session=await db.PlaybackSessions.SingleOrDefaultAsync(x=>x.TicketHash==hash,ct)??throw new ApiException(404,"not_found");if(session.MediaItemId is null || session.RevokedAt is not null || Expired(session))throw new ApiException(404,"not_found");
            var a=await ActorAsync(session,ct);(item,library)=await media.RequireAsync(a,session.MediaItemId.Value,ct:ct);
            if(name!=item.DisplayName || item.Kind!="video" || session.TargetGeneration!=MediaAccess.Generation(item))throw new ApiException(404,"not_found");file=media.Open(item,library);
            try{session.ActivatedAt??=clock.GetUtcNow();session.LastActivityAt=clock.GetUtcNow();await db.SaveChangesAsync(ct);readerLease=readers.Acquire(session.Id,item.Id,ct);}catch{file.Dispose();throw;}
        }
        using(file)using(var lease=readerLease)
        {
            ct=lease.Token;var length=file.Length;var etag='"'+session.TargetGeneration+'"';c.Response.Headers.AcceptRanges="bytes";c.Response.Headers.ETag=etag;c.Response.Headers.CacheControl="private, no-store";c.Response.ContentType=item.MimeType;
            if(c.Request.Headers.IfMatch.Count>0 && !Matches(c.Request.Headers.IfMatch.ToString(),etag,true))throw new ApiException(412,"precondition_failed");
            if(c.Request.Headers.IfNoneMatch.Count>0 && Matches(c.Request.Headers.IfNoneMatch.ToString(),etag,false)){c.Response.StatusCode=304;return;}
            if(HttpMethods.IsHead(c.Request.Method)){c.Response.StatusCode=200;c.Response.ContentLength=length;return;}
            ByteRange range;try{range=ByteRange.Parse(c.Request.Headers.IfRange.Count>0 && c.Request.Headers.IfRange.ToString()!=etag?null:c.Request.Headers.Range.ToString(),length);}catch(RangeException e){if(e.Unsatisfiable)c.Response.Headers.ContentRange=$"bytes */{length}";throw new ApiException(e.Unsatisfiable?416:400,"range_invalid");}
            c.Response.StatusCode=range.Partial?206:200;c.Response.ContentLength=range.Length;if(range.Partial)c.Response.Headers.ContentRange=$"bytes {range.Start}-{range.End}/{length}";
            var buffer=ArrayPool<byte>.Shared.Rent(262144);var lastCheck=clock.GetUtcNow();var lastPersist=lastCheck;file.Position=range.Start;long remaining=range.Length;
            using var watcherStop=CancellationTokenSource.CreateLinkedTokenSource(ct);
            var watcher=WatchAsync(session.Id,item,session.TargetGeneration,file,lease,c,watcherStop.Token);
            try
            {
                while(remaining>0)
                {
                    ct.ThrowIfCancellationRequested();var now=clock.GetUtcNow();
                    if(now-lastCheck>=TimeSpan.FromSeconds(1))
                    {
                        lastCheck=now;
                        if(now-lastPersist>=TimeSpan.FromSeconds(15)){using(await gate.EnterAsync(ct)){await db.PlaybackSessions.Where(x=>x.Id==session.Id && x.RevokedAt==null).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.LastActivityAt,now),ct);}lastPersist=now;}
                    }
                    var wanted=(int)Math.Min(remaining,262144);await file.ReadExactlyAsync(buffer.AsMemory(0,wanted),ct);await c.Response.Body.WriteAsync(buffer.AsMemory(0,wanted),ct);remaining-=wanted;
                }
            }
            catch(OperationCanceledException)when(ct.IsCancellationRequested){c.Abort();}
            catch{if(c.Response.HasStarted){c.Abort();return;}throw;}
            finally{watcherStop.Cancel();try{await watcher;}catch(OperationCanceledException){}ArrayPool<byte>.Shared.Return(buffer);}
        }
    }
    private static bool Matches(string header,string etag,bool strong)
    {
        if(header.Length>2048)throw new ApiException(400,"invalid_precondition");
        if(!Microsoft.Net.Http.Headers.EntityTagHeaderValue.TryParseList(new[]{header},out var values))throw new ApiException(400,"invalid_precondition");
        var target=new Microsoft.Net.Http.Headers.EntityTagHeaderValue(etag);
        return values.Any(v=>v.Tag.Value=="*" || v.Compare(target,strong));
    }
    private async Task WatchAsync(Guid id,MediaItem original,string generation,FileStream descriptor,MediaReaders.Lease lease,HttpContext context,CancellationToken stop)
    {
        try
        {
            while(true)
            {
                await Task.Delay(TimeSpan.FromSeconds(1),clock,stop);using var scope=scopes.CreateScope();var currentDb=scope.ServiceProvider.GetRequiredService<BrianiDb>();
                var session=await currentDb.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id,stop);
                if(session is null || session.RevokedAt is not null || Expired(session))throw new ApiException(404,"not_found");
                var user=await currentDb.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==session.UserId && x.Enabled && !x.MustChangePassword,stop);if(user is null)throw new ApiException(404,"not_found");
                var access=scope.ServiceProvider.GetRequiredService<MediaAccess>();var(item,library)=await access.RequireAsync(new(user.Id,session.AuthSessionId,user.Role),original.Id,ct:stop);
                using var root=storage.OpenLibrary(library);var pathStat=root.Inspect(item.RelativePath);var stat=ContainedDirectory.Inspect(descriptor);
                if(pathStat.Key!=original.FileIdentity || pathStat.Length!=original.SizeBytes || pathStat.MtimeNs!=original.MtimeNs || MediaAccess.Generation(item)!=generation || stat.Key!=original.FileIdentity || stat.Length!=original.SizeBytes || stat.MtimeNs!=original.MtimeNs)throw new ApiException(409,"media_changed");
            }
        }
        catch(OperationCanceledException)when(stop.IsCancellationRequested){}
        catch{lease.Cancel();context.Abort();}
    }

}
