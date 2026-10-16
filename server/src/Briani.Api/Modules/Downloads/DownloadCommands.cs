using System.Security.Cryptography;
using System.Text.Json;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Integrations.QBittorrent;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Downloads;
public sealed record DownloadCommand(Guid SessionId,string Action,DownloadSelection? Selection=null,DownloadSettings? Settings=null,bool DeleteData=false,bool Force=false,bool PreserveTransfer=false,string? PreviousDesiredState=null);
public sealed class DownloadCommands(BrianiDb db,PermissionService permissions,DownloadAccess access,SourceService sources,DownloadAdmission admission,SecretStore secrets,ServerOptions options,WriteGate gate,TimeProvider clock,MediaReaders readers,DownloadJobLocks jobLocks)
{
    internal static readonly JsonSerializerOptions Json=new(JsonSerializerDefaults.Web);
    private static string Digest(object value)=>Credentials.Hash(JsonSerializer.Serialize(value,Json));
    private static string? Key(HttpContext c){var key=c.Request.Headers["Idempotency-Key"].ToString();if(key.Length>200 || key.Any(char.IsControl))throw new ApiException(400,"invalid_idempotency_key");return key==""?null:Credentials.Hash(key);}
    public async Task<DownloadRequest> CreateAsync(Actor actor,DownloadCreate create,HttpContext context,CancellationToken ct)
    {
        if(create.Source is null || create.Source.Kind is not("magnet" or "torrentUpload" or "discoveryResult") || create.Source.Value is null || create.Source.Value.Length>65536)throw new ApiException(400,"invalid_source");
        var library=await permissions.RequireLibraryAsync(actor,create.LibraryId,"download",ct);var key=Key(context);var digest=Digest(create);
        if(key is not null){var old=await db.DownloadRequests.AsNoTracking().SingleOrDefaultAsync(x=>x.OwnerId==actor.UserId && x.IdempotencyKey==key,ct);if(old is not null){if(old.RequestHash!=digest)throw new ApiException(409,"idempotency_conflict");return(await access.RequireAsync(actor,old.Id,ct)).Request;}}
        var source=await sources.ResolveAsync(actor,create.Source.Kind,create.Source.Value,ct);if(source.Metadata is not null)DownloadLayout.PieceCount(source.Metadata);
        var magnet=source.Magnet is null?null:SourceValidation.Magnet(source.Magnet);var hash1=source.Metadata?.InfoHashV1??magnet?.InfoHashV1;var hash2=source.Metadata?.InfoHashV2??magnet?.InfoHashV2;
        IDisposable? attachmentGuard=null,held=null;Guid? lockedJobId=null;TorrentJob? existing;
        try
        {
            // Serialize attachment with lifecycle controls, always acquiring the job lock before the write gate.
            for(var attempt=0;;attempt++)
            {
                held=await gate.EnterAsync(ct);db.ChangeTracker.Clear();library=await permissions.RequireLibraryAsync(actor,create.LibraryId,"download",ct);
                if(key is not null){var prior=await db.DownloadRequests.SingleOrDefaultAsync(x=>x.OwnerId==actor.UserId && x.IdempotencyKey==key,ct);if(prior is not null){if(prior.RequestHash!=digest)throw new ApiException(409,"idempotency_conflict");return prior;}}
                existing=await db.TorrentJobs.SingleOrDefaultAsync(x=>x.RetiredAt==null && ((hash1!=null && x.InfoHashV1==hash1)||(hash2!=null && x.InfoHashV2==hash2)),ct);
                if(existing is null || existing.Id==lockedJobId)break;
                held.Dispose();held=null;attachmentGuard?.Dispose();attachmentGuard=null;
                if(attempt>=3)throw new ApiException(409,"download_conflict");
                attachmentGuard=await jobLocks.EnterAsync(existing.Id,ct);lockedJobId=existing.Id;
            }
            await RequireOperationCapacityAsync(actor.UserId,ct);
            if(await db.DownloadRequests.CountAsync(x=>x.OwnerId==actor.UserId && x.RemovedAt==null,ct)>=128 || await db.TorrentJobs.CountAsync(x=>x.RetiredAt==null,ct)>=512)throw new ApiException(429,"download_limit");
        if(existing is not null && (existing.LibraryId!=library.Id || hash1 is not null && existing.InfoHashV1!=hash1 || hash2 is not null && existing.InfoHashV2!=hash2))throw new ApiException(409,"torrent_already_managed");
        var policy=await admission.PolicyAsync(ct);var now=clock.GetUtcNow();TorrentJob job;
        if(existing is null)
        {
            if(await db.TorrentJobs.CountAsync(x=>x.RetiredAt==null && x.MetadataStatus=="pending" && x.ErrorCode==null,ct)>=policy.MetadataConcurrency)throw new ApiException(429,"metadata_limit");
            var volume=await admission.RequireAsync(actor,library,null,policy.ProvisionalBytes,policy.ProvisionalBytes,null,ct);
            // A provisional name until metadata arrives; the metadata name replaces it.
            job=new(){LibraryId=library.Id,InfoHashV1=hash1,InfoHashV2=hash2,Name=source.Metadata?.Name??magnet?.DisplayName??"",VolumeIdentity=volume.Volume,ReservedBytes=volume.Bytes,CreatedAt=now,UpdatedAt=now,MetadataDeadline=now.AddSeconds(120)};
            var configured=await Briani.Api.Modules.Preferences.AdministratorConfiguration.ReadAsync(db,ct);
            job.SettingsJson=JsonSerializer.Serialize(new DownloadSettings(Version:1,RatioLimit:configured["defaultRatioLimit"]?.GetValue<double>(),SeedTimeMinutes:configured["defaultSeedTimeMinutes"]?.GetValue<long>()),Json);
            job.ManagedPath=$".briani/staging/{job.Id:N}";job.OwnershipTag=$"briani-{job.Id:N}";job.EncryptedMagnet=source.Magnet is null?null:secrets.Encrypt(source.Magnet);
            // Commit the source and reservation before filesystem effects; the worker initializes a journaled UUID stage.
            if(source.Torrent is not null){using var state=new ContainedDirectory(options.StateRoot);if(state.Volume().FreeBytes<6L*source.Torrent.Length+67108864L)throw new ApiException(507,"disk_full");job.EncryptedMetainfo=secrets.Encrypt(Convert.ToBase64String(source.Torrent));}
            db.TorrentJobs.Add(job);
        }
        else job=existing;
        var request=new DownloadRequest{OwnerId=actor.UserId,AuthSessionId=actor.SessionId,LibraryId=library.Id,TorrentJobId=job.Id,SourceKind=create.Source.Kind,EncryptedSourceReference=secrets.Encrypt(JsonSerializer.Serialize(create.Source,Json)),SourceDigest=Digest(create.Source),IdempotencyKey=key,RequestHash=digest,VolumeIdentity=job.VolumeIdentity,ReservedBytes=policy.ProvisionalBytes,CreatedAt=now,UpdatedAt=now,State=job.MetadataStatus=="ready"?"awaitingSelection":"metadataPending",SourceState=job.MetadataStatus=="ready"?"ready":"metadataPending"};
        if(existing is not null)await admission.RequireAsync(actor,library,job.Id,job.ReservedBytes,policy.ProvisionalBytes,null,ct);
        db.DownloadRequests.Add(request);if(existing is null)Enqueue(request,new(actor.SessionId,"add"),null,Digest(new{request.Id,Action="add"}));await db.SaveChangesAsync(ct);return request;
        }
        finally{held?.Dispose();attachmentGuard?.Dispose();}
    }
    internal static void EnsureDirectory(ContainedDirectory root,string path){try{if(!root.Inspect(path).IsDirectory)throw new ApiException(409,"path_unavailable");}catch(ApiException e)when(e.Code=="path_unavailable"){root.CreateDirectory(path);}}
    private async Task RequireOperationCapacityAsync(Guid userId,CancellationToken ct)
    {
        var retained=db.Operations.Where(x=>x.Kind.StartsWith("download-") && x.Kind!="download-import" && x.ExpiresAt>clock.GetUtcNow());
        if(await retained.CountAsync(x=>x.UserId==userId,ct)>=128 || await retained.CountAsync(ct)>=1024)throw new ApiException(429,"download_operation_limit");
    }
    private Operation Enqueue(DownloadRequest request,DownloadCommand command,string? key,string digest)
    {
        var now=clock.GetUtcNow();var op=new Operation{UserId=request.OwnerId,Kind="download-"+command.Action,TargetId=request.Id,IdempotencyKey=key,RequestHash=digest,State="pending",InvalidatesPlayback=command.Action is "recheck" or "retry" or "remove" || command.Action=="select" && !command.PreserveTransfer,PayloadJson=JsonSerializer.Serialize(command,Json),CreatedAt=now,UpdatedAt=now,ExpiresAt=now.AddDays(7)};db.Operations.Add(op);
        db.Jobs.Add(new(){Kind="download",TargetId=op.Id,PayloadJson="{}",State="queued",NextAttemptAt=now,CreatedAt=now,UpdatedAt=now});return op;
    }
    public async Task<Operation> SubmitAsync(Actor actor,Guid id,DownloadCommand command,long version,HttpContext context,CancellationToken ct)
    {
        var key=Key(context);var digest=Digest(new{id,version,command.Action,command.Selection,command.Settings,command.DeleteData,command.Force});var known=await access.RequireAsync(actor,id,ct);if(known.Job is null)throw new ApiException(409,"metadata_unavailable");using var jobGuard=await jobLocks.EnterAsync(known.Job.Id,ct);using var held=await gate.EnterAsync(ct);db.ChangeTracker.Clear();
        var (snapshot,library,job)=await access.RequireAsync(actor,id,ct);
        if(key is not null){var prior=await db.Operations.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==actor.UserId && x.Kind=="download-"+command.Action && x.IdempotencyKey==key,ct);if(prior is not null){if(prior.RequestHash!=digest)throw new ApiException(409,"idempotency_conflict");return prior;}}
        if(job is null || snapshot.RemovedAt is not null)throw new ApiException(409,"download_removed");
        await RequireOperationCapacityAsync(actor.UserId,ct);
        await access.RequireCommandAsync(actor,snapshot,command,ct);
        if(command.Selection is not null && snapshot.OwnerId==actor.UserId && await CompatibleSelectionAsync(db,snapshot,command.Selection,ct))command=command with{PreserveTransfer=true};
        if(snapshot.Version!=version)throw new ApiException(409,"version_conflict");
        if(await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==job.Id) && (x.State=="pending" || x.State=="running"),ct))throw new ApiException(409,"download_operation_pending");
        if(command.Action is "recheck" or "retry" || command.DeleteData || command.Selection is not null && !command.PreserveTransfer){var ids=await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).Select(x=>x.Id).ToArrayAsync(ct);var mediaIds=await db.MediaItems.Where(x=>ids.Contains(x.DownloadFileId??Guid.Empty)).Select(x=>x.Id).ToArrayAsync(ct);if(mediaIds.Concat(ids).Any(readers.HasReaders)){if(!command.Force)throw new ApiException(409,"active_reader_conflict");foreach(var mediaId in mediaIds.Concat(ids))readers.Cancel(mediaId);}}
        var request=await db.DownloadRequests.SingleAsync(x=>x.Id==id,ct);var tracked=await db.TorrentJobs.SingleAsync(x=>x.Id==job.Id,ct);var previousDesiredState=tracked.DesiredState;var reservationActor=new Actor(request.OwnerId,Guid.Empty,"member");
        if(command.Selection is not null)
        {
            if(job.MetadataStatus!="ready" || command.Selection.Files is null || command.Selection.Files.Length is <1 or >10000 || command.Selection.Files.Select(x=>x.FileId).Distinct().Count()!=command.Selection.Files.Length)throw new ApiException(400,"invalid_selection");
            var files=await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id && !x.Padding).ToArrayAsync(ct);var choices=command.Selection.Files.ToDictionary(x=>x.FileId);
            if(choices.Keys.Except(files.Select(x=>x.Id)).Any() || !choices.Values.Any(x=>x.Selected) || choices.Values.Any(x=>x.Priority is not("normal" or "high" or "maximum")))throw new ApiException(400,"invalid_selection");
            if(files.Any(f=>choices.TryGetValue(f.Id,out var choice) && choice.Selected && f.Kind=="other"))throw new ApiException(400,"unsupported_file_selection");
            long selected=0;foreach(var f in files)if(choices.TryGetValue(f.Id,out var c)&&c.Selected)selected=checked(selected+f.SizeBytes);
            var other=await db.DownloadRequestFiles.Where(x=>x.DownloadRequestId!=id && x.Selected && db.DownloadRequests.Any(r=>r.Id==x.DownloadRequestId && r.TorrentJobId==job.Id && r.RemovedAt==null)).ToArrayAsync(ct);
            var wantedIds=other.Select(x=>x.DownloadFileId).Concat(choices.Values.Where(x=>x.Selected).Select(x=>x.FileId)).ToHashSet();long remaining=0;
            foreach(var file in files.Where(x=>wantedIds.Contains(x.Id)))remaining=checked(remaining+Math.Max(0,file.SizeBytes-file.DownloadedBytes)+2*job.PieceLength);
            var volume=await admission.RequireAsync(reservationActor,library,job.Id,remaining,selected,id,ct,choices.Values.Where(x=>x.Selected).Select(x=>x.FileId).ToArray());tracked.ReservedBytes=volume.Bytes;request.ReservedBytes=selected;request.SelectedBytes=selected;
            var old=await db.DownloadRequestFiles.Where(x=>x.DownloadRequestId==id).ToDictionaryAsync(x=>x.DownloadFileId,ct);
            foreach(var file in files){choices.TryGetValue(file.Id,out var choice);if(!old.TryGetValue(file.Id,out var row)){row=new(){DownloadRequestId=id,DownloadFileId=file.Id};db.DownloadRequestFiles.Add(row);}row.Selected=choice?.Selected==true;row.Priority=Priority(choice?.Priority);if(row.Selected && !await db.DownloadOwnerships.AnyAsync(x=>x.OwnerId==request.OwnerId && x.DownloadFileId==file.Id,ct))db.DownloadOwnerships.Add(new(){OwnerId=request.OwnerId,LibraryId=library.Id,DownloadFileId=file.Id,Bytes=file.SizeBytes});}
            // Persist choices and fence availability before any upstream priority mutation.
            if(!command.PreserveTransfer){tracked.Generation++;tracked.SelectedComplete=false;tracked.Imported=false;tracked.ImportState="notReady";tracked.DesiredState=command.Selection.AutoStart?"running":"stopped";request.State=command.Selection.AutoStart?"queued":"paused";
            foreach(var file in files){file.PlaybackState="unavailable";file.Completed=false;file.Version++;}
            await FenceAsync(db,job.Id,ct,readers);}else request.State=tracked.SelectedComplete?"completeSelected":tracked.EngineState=="stopped"?"paused":tracked.EngineState;
        }
        if(command.Settings is not null){ValidateSettings(command.Settings);if(command.Settings.Version!=job.SettingsVersion)throw new ApiException(409,"version_conflict");tracked.SettingsVersion++;tracked.SettingsJson=JsonSerializer.Serialize(command.Settings with{Version=tracked.SettingsVersion},Json);tracked.TagsJson=JsonSerializer.Serialize(command.Settings.Tags??[],Json);}
        if(command.Action is "pause" or "resume")tracked.DesiredState=command.Action=="pause"?"stopped":"running";
        if(command.Action=="retry"){tracked.ErrorCode=null;request.ErrorCode=null;if(tracked.MetadataStatus!="ready"){var policy=await admission.PolicyAsync(ct);if(await db.TorrentJobs.CountAsync(x=>x.Id!=job.Id && x.RetiredAt==null && x.MetadataStatus=="pending" && x.ErrorCode==null,ct)>=policy.MetadataConcurrency)throw new ApiException(429,"metadata_limit");var volume=await admission.RequireAsync(reservationActor,library,job.Id,policy.ProvisionalBytes,policy.ProvisionalBytes,id,ct);tracked.VolumeIdentity=volume.Volume;tracked.ReservedBytes=volume.Bytes;request.ReservedBytes=policy.ProvisionalBytes;tracked.MetadataDeadline=clock.GetUtcNow().AddSeconds(120);tracked.MetadataStatus="pending";}else tracked.DesiredState="running";}
        if(command.Action is "recheck" or "retry" or "remove")
        {if(command.Action is "recheck" or "retry" || command.DeleteData){foreach(var f in await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).ToArrayAsync(ct)){f.Completed=false;f.PlaybackState="unavailable";}tracked.Generation++;tracked.DesiredState=command.Action=="remove"?"removing":tracked.DesiredState;await FenceAsync(db,job.Id,ct,readers);}if(command.Action=="remove")request.State="removing";}
        if(command.Action=="reannounce"){if(job.LastReannounceAt is DateTimeOffset last && clock.GetUtcNow()-last<TimeSpan.FromMinutes(1))throw new ApiException(429,"reannounce_limit");tracked.LastReannounceAt=clock.GetUtcNow();}
        request.Version++;request.UpdatedAt=clock.GetUtcNow();tracked.UpdatedAt=request.UpdatedAt;var operation=Enqueue(request,command with{SessionId=actor.SessionId,PreviousDesiredState=previousDesiredState},key,digest);operation.UserId=actor.UserId;await db.SaveChangesAsync(ct);return operation;
    }
    internal static async Task<bool> CompatibleSelectionAsync(BrianiDb db,DownloadRequest request,DownloadSelection selection,CancellationToken ct)
    {if(selection.Files is null || selection.Files.Length==0)return false;var otherSelected=await db.DownloadRequestFiles.AnyAsync(x=>x.DownloadRequestId!=request.Id && x.Selected && db.DownloadRequests.Any(r=>r.Id==x.DownloadRequestId && r.TorrentJobId==request.TorrentJobId && r.RemovedAt==null),ct);if(!otherSelected)return false;var files=await db.DownloadFiles.AsNoTracking().Where(x=>x.TorrentJobId==request.TorrentJobId).ToDictionaryAsync(x=>x.Id,ct);return selection.Files.Where(x=>x.Selected).All(x=>files.TryGetValue(x.FileId,out var file) && file.Wanted && Priority(x.Priority)<=file.FilePriority);}
    internal static int Priority(string? value)=>value switch{"maximum"=>7,"high"=>6,_=>1};
    internal static void ValidateSettings(DownloadSettings s)
    {if(s.DownloadLimitBytesPerSecond is <0 or >1073741824 || s.UploadLimitBytesPerSecond is <0 or >1073741824 || s.RatioLimit is double ratio && (!double.IsFinite(ratio)||ratio<0||ratio>10000)||s.SeedTimeMinutes is <0 or >525600||s.QueuePosition is <0 or >500||s.Tags is {Length:>50}||s.Tags?.Any(t=>string.IsNullOrWhiteSpace(t)||t.Length>100||t.Any(char.IsControl)||t.Contains(',')||t.StartsWith("briani-",StringComparison.OrdinalIgnoreCase))==true)throw new ApiException(400,"invalid_download_settings");}
    internal static async Task FenceAsync(BrianiDb db,Guid jobId,CancellationToken ct,MediaReaders? readers=null)
    {var ids=await db.DownloadFiles.Where(x=>x.TorrentJobId==jobId).Select(x=>x.Id).ToArrayAsync(ct);var media=await db.MediaItems.Where(x=>ids.Contains(x.DownloadFileId??Guid.Empty)).Select(x=>x.Id).ToArrayAsync(ct);var sessions=await db.PlaybackSessions.Where(x=>ids.Contains(x.DownloadFileId??Guid.Empty)||media.Contains(x.MediaItemId??Guid.Empty)).ToArrayAsync(ct);foreach(var s in sessions){s.RevokedAt=DateTimeOffset.UtcNow;readers?.CancelSession(s.Id);}foreach(var id in ids.Concat(media))readers?.Cancel(id);}
    internal static object OperationView(Operation op)=>new{id=op.Id,state=op.State,resourceId=(Guid?)op.TargetId,resourceType="download",error=op.ErrorCode is null?null:ErrorMessages.Problem(op.ErrorCode,409),createdAt=op.CreatedAt,updatedAt=op.UpdatedAt};
    public static void Map(WebApplication app)
    {
        var group=app.MapGroup("/api/v1/downloads").RequireAuthorization();
        group.MapPost("",async(DownloadCreate input,HttpContext c,DownloadCommands commands,BrianiDb db)=>{var r=await commands.CreateAsync(Actor.From(c.User),input,c,c.RequestAborted);return Results.Json(await DownloadViews.ViewAsync(db,r,c.RequestAborted),statusCode:202);});
        group.MapPut("/{id:guid}/selection",async(Guid id,DownloadSelection input,HttpContext c,DownloadCommands commands,BrianiDb db,DownloadAccess access)=>{var operation=await commands.SubmitAsync(Actor.From(c.User),id,new(Guid.Empty,"select",Selection:input),input.Version,c,c.RequestAborted);c.Response.Headers.Location=$"/api/v1/operations/{operation.Id:D}";var(request,_,_)=await access.RequireAsync(Actor.From(c.User),id,c.RequestAborted);return Results.Json(await DownloadViews.ViewAsync(db,request,c.RequestAborted),statusCode:202);});
        group.MapPatch("/{id:guid}/settings",async(Guid id,DownloadSettings input,HttpContext c,DownloadCommands commands,DownloadAccess access)=>{var actor=Actor.From(c.User);var before=await access.RequireAsync(actor,id,c.RequestAborted);var operation=await commands.SubmitAsync(actor,id,new(Guid.Empty,"settings",Settings:input),before.Request.Version,c,c.RequestAborted);c.Response.Headers.Location=$"/api/v1/operations/{operation.Id:D}";var after=await access.RequireAsync(actor,id,c.RequestAborted);return Results.Ok(DownloadViews.Settings(after.Job));});
        group.MapPost("/{id:guid}/actions",async(Guid id,DownloadAction input,HttpContext c,DownloadCommands commands)=>{if(input.Action is not("pause" or "resume" or "retry" or "remove" or "reannounce" or "recheck")||input.DeleteData && input.Action!="remove"||input.DeleteData && input.Confirmation!="DELETE DATA"||input.Force && !input.DeleteData)throw new ApiException(400,"invalid_download_action");return Results.Json(OperationView(await commands.SubmitAsync(Actor.From(c.User),id,new(Guid.Empty,input.Action,DeleteData:input.DeleteData,Force:input.Force),input.Version,c,c.RequestAborted)),statusCode:202);});
        group.MapGet("/{id:guid}/diagnostics",async(Guid id,HttpContext c,DownloadAccess a,ITorrentEngine engine)=>{var(_,_,job)=await a.RequireAsync(Actor.From(c.User),id,c.RequestAborted);var trackers=job?.UpstreamId is null?[]:await engine.TrackersAsync(job.UpstreamId,c.RequestAborted);await a.RequireAsync(Actor.From(c.User),id,c.RequestAborted);return Results.Ok(new{downloadId=id,engineState=job?.EngineState??"metadata",generation=job?.Generation.ToString()??"1",trackers=trackers.Select(x=>new{host=x.Host,state=x.Status,peers=x.Peers}),warnings=Array.Empty<string>()});});
    }
}
