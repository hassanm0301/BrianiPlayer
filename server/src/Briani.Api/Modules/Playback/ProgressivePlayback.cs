using System.Buffers;
using Briani.Api.Modules.Preferences;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Media.Processing;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.Kestrel.Core.Features;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Playback;

public sealed class ProgressivePlayback(BrianiDb db,PermissionService permissions,WriteGate gate,TimeProvider clock,MediaReaders readers,IServiceScopeFactory scopes,ContainedStorage storage,SecretStore secrets,TorrentAvailability availability,SubtitleDelivery subtitles)
{
    private readonly BrianiDb database=db;
    internal TimeSpan FirstByteTimeout {get;set;}=TimeSpan.FromSeconds(60);
    internal TimeSpan BodyIdleTimeout {get;set;}=TimeSpan.FromSeconds(120);
    private sealed record Target(DownloadFile File,TorrentJob Job,Library Library);
    private async Task<Target> RequireAsync(Actor actor,Guid id,CancellationToken ct)
    {
        var file=await database.DownloadFiles.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id && !x.Padding && x.Kind=="video",ct)??throw new ApiException(404,"not_found");
        var job=await database.TorrentJobs.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==file.TorrentJobId,ct)??throw new ApiException(404,"not_found");
        var library=await permissions.RequireLibraryAsync(actor,job.LibraryId,ct:ct);
        if(!file.Wanted || job.RetiredAt is not null || job.PayloadRemoved || job.DesiredState=="removing" || await TorrentAvailability.PendingAsync(database,job.Id,ct))throw new ApiException(409,"generation_changed");
        if(job.MetadataStatus!="ready" || job.PieceLength is <=0 or >67108864 || job.PieceCount<0 || file.SizeBytes<=0)throw new ApiException(409,"metadata_pending");
        if(file.TorrentOffset<0 || checked(file.TorrentOffset+file.SizeBytes)>checked((long)job.PieceCount*job.PieceLength) || file.PieceFirst!=file.TorrentOffset/job.PieceLength || file.PieceLast!=(file.TorrentOffset+file.SizeBytes-1)/job.PieceLength)throw new ApiException(409,"layout_unverified");
        return new(file,job,library);
    }
    private static long Prefix(Target t,AvailabilitySnapshot? snapshot)
    {
        if(snapshot is null || !snapshot.Healthy || snapshot.PieceCount!=t.Job.PieceCount)return 0;
        long bytes=0;for(var p=t.File.PieceFirst;p<=t.File.PieceLast;p++)
        {if(!snapshot.Contains(p))break;var start=Math.Max(t.File.TorrentOffset,checked((long)p*t.Job.PieceLength));var end=Math.Min(checked(t.File.TorrentOffset+t.File.SizeBytes),checked(((long)p+1)*t.Job.PieceLength));bytes=checked(bytes+end-start);}return bytes;
    }
    private (string State,long Prefix) State(Target t,TorrentAvailability.Entry entry)
    {
        var s=entry.Current;
        if(s is null || s.Generation!=availability.Generation(t.Job,entry) || !s.Healthy || clock.GetUtcNow()-s.ObservedAt>TimeSpan.FromSeconds(2))return("waitingForData",0);
        var prefix=Prefix(t,s);return(prefix==t.File.SizeBytes?"complete":prefix>=Math.Min(t.File.SizeBytes,16777216)?"ready":"buffering",prefix);
    }
    private async Task<PlaybackSessionView> ViewAsync(PlaybackSession s,Target t,string state,long prefix,string? url,HttpContext c)=>new(s.Id,state,url,s.FirstUseDeadline,s.LastActivityAt?.AddMinutes(30),s.AbsoluteExpiresAt,s.TargetGeneration,prefix,t.File.SizeBytes,ScanWorker.Mime(Path.GetExtension(t.File.DisplayName)),t.File.DisplayName,await subtitles.DescribeAsync(s,c,c.RequestAborted),state is "buffering" or "waitingForData"?2:null,t.File.ImportedItemId);
    private async Task<string> UrlAsync(HttpContext c,string token,string name)=>$"{await AdministratorConfiguration.OriginAsync(database,c,c.RequestAborted)}/stream/{token}/{Uri.EscapeDataString(name)}";
    public async Task<PlaybackSessionView> CreateAsync(Actor actor,PlaybackCreate request,HttpContext c)
    {
        if(request.Target is null || request.Target.Kind!="downloadFile" || request.Mode is not("internal" or "external") || request.InitialPositionMs<0)throw new ApiException(400,"invalid_playback_target");
        var ct=c.RequestAborted;var target=await RequireAsync(actor,request.Target.Id,ct);
        using var subscription=availability.Subscribe(target.Job.Id);await availability.RefreshAsync(subscription.Source,ct);
        var key=c.Request.Headers["Idempotency-Key"].ToString();if(key.Length>200 || key.Any(char.IsControl))throw new ApiException(400,"invalid_idempotency_key");var storedKey=key==""?null:Credentials.Hash(key);
        var digest=secrets.Digest(JsonSerializer.Serialize(request));
        using var held=await gate.EnterAsync(ct);target=await RequireAsync(actor,request.Target.Id,ct);
        if(storedKey is not null)
        {
            var operation=await database.Operations.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==actor.UserId && x.Kind=="playback-create" && x.IdempotencyKey==storedKey,ct);
            if(operation is not null)
            {if(!Credentials.EqualHash(operation.RequestHash,digest))throw new ApiException(409,"idempotency_conflict");var old=await database.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==operation.TargetId && x.UserId==actor.UserId && x.AuthSessionId==actor.SessionId,ct)??throw new ApiException(409,"idempotency_session_changed");var state=State(target,subscription.Source);return await ViewAsync(old,target,old.RevokedAt is not null?"revoked":PlaybackExpiry.Expired(old,clock.GetUtcNow())?"expired":old.TicketIssued && old.TargetGeneration!=availability.Generation(target.Job,subscription.Source)?"unavailable":state.State,state.Prefix,null,c);}
        }
        await PlaybackAdmission.RequireAsync(database,actor.UserId,clock.GetUtcNow(),ct);
        var readiness=State(target,subscription.Source);var token=Credentials.NewToken();var now=clock.GetUtcNow();var issued=readiness.State is "ready" or "complete";
        var session=new PlaybackSession{UserId=actor.UserId,AuthSessionId=actor.SessionId,DownloadFileId=target.File.Id,TargetGeneration=availability.Generation(target.Job,subscription.Source),TicketHash=Credentials.Hash(token),TicketIssued=issued,Mode=request.Mode,CreatedAt=now,FirstUseDeadline=now.AddMinutes(10),AbsoluteExpiresAt=now.AddHours(24),InitialPositionMs=request.InitialPositionMs};
        database.PlaybackSessions.Add(session);if(storedKey is not null)database.Operations.Add(new(){UserId=actor.UserId,Kind="playback-create",TargetId=session.Id,IdempotencyKey=storedKey,RequestHash=digest,State="completed",CreatedAt=now,UpdatedAt=now,ExpiresAt=now.AddDays(1)});await database.SaveChangesAsync(ct);
        return await ViewAsync(session,target,readiness.State,readiness.Prefix,issued?await UrlAsync(c,token,target.File.DisplayName):null,c);
    }
    public async Task<PlaybackSessionView> StatusAsync(Actor actor,Guid id,HttpContext c)
    {
        var ct=c.RequestAborted;var session=await database.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id && x.UserId==actor.UserId,ct)??throw new ApiException(404,"not_found");
        var target=await RequireAsync(actor,session.DownloadFileId??Guid.Empty,ct);using var subscription=availability.Subscribe(target.Job.Id);await availability.RefreshAsync(subscription.Source,ct);
        using var held=await gate.EnterAsync(ct);database.ChangeTracker.Clear();session=await database.PlaybackSessions.SingleAsync(x=>x.Id==id && x.UserId==actor.UserId,ct);target=await RequireAsync(actor,session.DownloadFileId!.Value,ct);var readiness=State(target,subscription.Source);
        if(session.RevokedAt is not null || !await permissions.IsSessionValidAsync(session.AuthSessionId,ct))return await ViewAsync(session,target,"revoked",0,null,c);
        if(PlaybackExpiry.Expired(session,clock.GetUtcNow()))return await ViewAsync(session,target,"expired",0,null,c);
        var generation=availability.Generation(target.Job,subscription.Source);
        if(session.TicketIssued && session.TargetGeneration!=generation)return await ViewAsync(session,target,"unavailable",0,null,c);
        string? url=null;if(!session.TicketIssued && readiness.State is "ready" or "complete")
        {var token=Credentials.NewToken();session.TargetGeneration=generation;session.TicketHash=Credentials.Hash(token);session.TicketIssued=true;await database.SaveChangesAsync(ct);url=await UrlAsync(c,token,target.File.DisplayName);}
        return await ViewAsync(session,target,readiness.State,readiness.Prefix,url,c);
    }
    private async Task<Actor> SessionActorAsync(PlaybackSession s,CancellationToken ct)
    {var user=await database.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==s.UserId && x.Enabled && !x.MustChangePassword,ct)??throw new ApiException(404,"not_found");if(!await permissions.IsSessionValidAsync(s.AuthSessionId,ct))throw new ApiException(404,"not_found");return new(user.Id,s.AuthSessionId,user.Role);}
    public async Task StreamAsync(string ticket,string name,HttpContext c)
    {
        using var deadline=new CancellationTokenSource(FirstByteTimeout,clock);using var beforeHeaders=CancellationTokenSource.CreateLinkedTokenSource(c.RequestAborted,deadline.Token);
        try{await StreamCoreAsync(ticket,name,c,beforeHeaders.Token,deadline);}
        catch(OperationCanceledException)when(deadline.IsCancellationRequested && !c.RequestAborted.IsCancellationRequested && !c.Response.HasStarted){c.Response.Headers.RetryAfter="2";throw new ApiException(503,"waiting_for_data",retryAfterSeconds:2);}
    }
    private async Task StreamCoreAsync(string ticket,string name,HttpContext c,CancellationToken requestCt,CancellationTokenSource firstDeadline)
    {
        if(ticket.Length!=43)throw new ApiException(404,"not_found");var hash=Credentials.Hash(ticket);
        var initial=await database.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.TicketHash==hash && x.DownloadFileId!=null,requestCt)??throw new ApiException(404,"not_found");
        var actor=await SessionActorAsync(initial,requestCt);var target=await RequireAsync(actor,initial.DownloadFileId!.Value,requestCt);
        using var subscription=availability.Subscribe(target.Job.Id);
        FileStream? descriptor=null;MediaReaders.Lease lease;PlaybackSession session;
        using(await gate.EnterAsync(requestCt))
        {
            session=await database.PlaybackSessions.SingleAsync(x=>x.Id==initial.Id,requestCt);
            if(!session.TicketIssued || session.RevokedAt is not null || PlaybackExpiry.Expired(session,clock.GetUtcNow()) || !Credentials.EqualHash(session.TicketHash,hash))throw new ApiException(404,"not_found");
            actor=await SessionActorAsync(session,requestCt);target=await RequireAsync(actor,session.DownloadFileId!.Value,requestCt);
            if(name!=target.File.DisplayName || session.TargetGeneration!=availability.Generation(target.Job,subscription.Source))throw new ApiException(404,"not_found");
            lease=readers.Acquire(session.Id,target.File.Id,c.RequestAborted);
            try{if(!HttpMethods.IsHead(c.Request.Method)){using var root=storage.OpenLibrary(target.Library);using var stage=root.Directory(target.Job.ManagedPath);if(stage.Identity!=target.Job.ManagedRootIdentity || target.File.FileIdentity is null)throw new ApiException(409,"file_identity_changed");descriptor=root.OpenFile(target.Job.ManagedPath+"/"+target.File.RelativePath,target.File.FileIdentity);}session.ActivatedAt??=clock.GetUtcNow();session.LastActivityAt=clock.GetUtcNow();await database.SaveChangesAsync(requestCt);}catch{lease.Dispose();descriptor?.Dispose();throw;}
        }
        using(lease)using(descriptor)
        {
            var length=target.File.SizeBytes;var ct=lease.Token;
            if(c.Features.Get<IHttpMinResponseDataRateFeature>() is { } rate)rate.MinDataRate=null;
            if(HttpMethods.IsHead(c.Request.Method)){Headers(c,target,length,false,0,length-1);return;}
            ByteRange range;try{range=ByteRange.Parse(c.Request.Headers.IfRange.Count>0?null:c.Request.Headers.Range.ToString(),length);}catch(RangeException error){if(error.Unsatisfiable)c.Response.Headers.ContentRange=$"bytes */{length}";throw new ApiException(error.Unsatisfiable?416:400,"range_invalid");}
            using var watcherStop=CancellationTokenSource.CreateLinkedTokenSource(ct);var watcher=WatchAsync(session,target,descriptor!,lease,c,subscription.Source,watcherStop.Token);
            var buffer=ArrayPool<byte>.Shared.Rent(262144);
            try
            {
                using var initialStop=CancellationTokenSource.CreateLinkedTokenSource(ct,requestCt);
                await availability.RefreshAsync(subscription.Source,initialStop.Token);
                var reader=new ProgressiveReader(new(session.TargetGeneration,target.Job.PieceLength,target.Job.PieceCount,target.File.TorrentOffset,length,target.File.FileIdentity!),subscription.Source,clock);
                long offset=range.Start,remaining=range.Length;var count=await reader.ReadAsync(descriptor!,offset,buffer.AsMemory(0,(int)Math.Min(remaining,262144)),FirstByteTimeout,initialStop.Token);
                firstDeadline.CancelAfter(Timeout.InfiniteTimeSpan);
                Headers(c,target,range.Length,range.Partial,range.Start,range.End);
                while(true)
                {
                    await c.Response.Body.WriteAsync(buffer.AsMemory(0,count),ct);offset+=count;remaining-=count;if(remaining==0)break;
                    count=await reader.ReadAsync(descriptor!,offset,buffer.AsMemory(0,(int)Math.Min(remaining,262144)),BodyIdleTimeout,ct);
                }
            }
            catch(DataWaitException){if(c.Response.HasStarted)c.Abort();else{c.Response.Headers.RetryAfter="2";throw new ApiException(503,"waiting_for_data",retryAfterSeconds:2);}}
            catch(OperationCanceledException)when(ct.IsCancellationRequested){c.Abort();}
            catch(IOException){if(c.Response.HasStarted)c.Abort();else throw new ApiException(503,"waiting_for_data",retryAfterSeconds:2);}
            catch{if(c.Response.HasStarted)c.Abort();else throw;}
            finally{watcherStop.Cancel();try{await watcher;}catch(OperationCanceledException){}ArrayPool<byte>.Shared.Return(buffer);}
        }
    }
    private static void Headers(HttpContext c,Target target,long responseLength,bool partial,long start,long end)
    {c.Response.StatusCode=partial?206:200;c.Response.ContentLength=responseLength;c.Response.ContentType=ScanWorker.Mime(Path.GetExtension(target.File.DisplayName));c.Response.Headers.AcceptRanges="bytes";c.Response.Headers.CacheControl="private, no-store";c.Response.Headers["X-Accel-Buffering"]="no";if(partial)c.Response.Headers.ContentRange=$"bytes {start}-{end}/{target.File.SizeBytes}";}
    private async Task WatchAsync(PlaybackSession original,Target target,FileStream descriptor,MediaReaders.Lease lease,HttpContext context,TorrentAvailability.Entry source,CancellationToken ct)
    {
        var lastPersist=clock.GetUtcNow();
        try
        {
            while(true)
            {
                await Task.Delay(TimeSpan.FromSeconds(1),clock,ct);using var scope=scopes.CreateScope();var current=scope.ServiceProvider.GetRequiredService<ProgressivePlayback>();
                var session=await current.database.PlaybackSessions.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==original.Id,ct);
                if(session is null || session.RevokedAt is not null || PlaybackExpiry.Expired(session,clock.GetUtcNow()) || session.TargetGeneration!=original.TargetGeneration || !Credentials.EqualHash(session.TicketHash,original.TicketHash))throw new IOException("session_expired");
                var actor=await current.SessionActorAsync(session,ct);var live=await current.RequireAsync(actor,target.File.Id,ct);
                if(live.Job.Generation!=target.Job.Generation || live.File.FileIdentity!=target.File.FileIdentity || live.File.SizeBytes!=target.File.SizeBytes || availability.Generation(live.Job,source)!=original.TargetGeneration)throw new GenerationException();
                using var root=storage.OpenLibrary(live.Library);var path=root.Inspect(live.Job.ManagedPath+"/"+live.File.RelativePath);var stat=ContainedDirectory.Inspect(descriptor);
                if(path.Key!=target.File.FileIdentity || stat.Key!=target.File.FileIdentity || path.Length>target.File.SizeBytes || stat.Length>target.File.SizeBytes)throw new GenerationException();
                var now=clock.GetUtcNow();if(now-lastPersist>=TimeSpan.FromSeconds(15)){using(await gate.EnterAsync(ct))await current.database.PlaybackSessions.Where(x=>x.Id==original.Id && x.RevokedAt==null).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.LastActivityAt,now),ct);lastPersist=now;}
            }
        }
        catch(OperationCanceledException)when(ct.IsCancellationRequested){}
        catch{lease.Cancel();context.Abort();}
    }
}
