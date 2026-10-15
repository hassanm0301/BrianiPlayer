using System.Text.Json;
using System.Text.Json.Serialization;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Playback;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Media.Operations;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record RenameRequest([property:JsonRequired]string Name,[property:JsonRequired]long Version);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record MoveRequest([property:JsonRequired]Guid? TargetFolderId,[property:JsonRequired]long Version);
public sealed record MutationCommand(Guid SessionId,Guid LibraryId,long Version,string Source,string Destination,string Identity,long Bytes,long Mtime,string Name,Guid? ParentId,string ParentPath,bool Virtual,string Stage="planned",bool Force=false);
public sealed class MediaOperations(BrianiDb db,MediaAccess media,WriteGate gate,PermissionService permissions,ContainedStorage storage,MediaReaders readers,SecretStore secrets,TimeProvider clock,Audit audit)
{
    private static readonly JsonSerializerOptions Json=new(JsonSerializerDefaults.Web);
    internal Action? BeforeCatalogCommit {get;set;}
    public static void Map(WebApplication app)
    {
        app.MapPost("/api/v1/media/{id:guid}/rename",async(Guid id,RenameRequest r,HttpContext c,MediaOperations m)=>Results.Json(await m.ScheduleAsync(Actor.From(c.User),id,"rename",r.Version,r.Name,null,false,c),statusCode:202));
        app.MapPost("/api/v1/media/{id:guid}/move",async(Guid id,MoveRequest r,HttpContext c,MediaOperations m)=>Results.Json(await m.ScheduleAsync(Actor.From(c.User),id,"move",r.Version,null,r.TargetFolderId,false,c),statusCode:202));
        app.MapDelete("/api/v1/media/{id:guid}",async(Guid id,long? version,string? mode,bool? force,HttpContext c,MediaOperations m)=>Results.Json(await m.ScheduleAsync(Actor.From(c.User),id,mode??"trash",version??0,null,null,force??false,c),statusCode:202));
        app.MapGet("/api/v1/operations/{id:guid}",async(Guid id,HttpContext c,BrianiDb db)=>{var actor=Actor.From(c.User);var op=await db.Operations.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id && x.UserId==actor.UserId,c.RequestAborted)??throw new ApiException(404,"not_found");if(op.Kind.StartsWith("download-",StringComparison.Ordinal)){if(op.Kind=="download-import")throw new ApiException(404,"not_found");await c.RequestServices.GetRequiredService<Briani.Api.Modules.Downloads.DownloadAccess>().RequireAsync(actor,op.TargetId,c.RequestAborted);}else{var item=await db.MediaItems.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==op.TargetId,c.RequestAborted)??throw new ApiException(404,"not_found");await c.RequestServices.GetRequiredService<PermissionService>().RequireLibraryAsync(actor,item.LibraryId,ct:c.RequestAborted);}return View(op);});
    }
    public static object View(Operation op)=>new{id=op.Id,state=op.State=="queued"?"pending":op.State,resourceId=(Guid?)op.TargetId,resourceType=op.Kind.StartsWith("download-",StringComparison.Ordinal)?"download":"media",createdAt=op.CreatedAt,updatedAt=op.UpdatedAt,error=op.ErrorCode is null?null:new{type="about:blank",title=ErrorMessages.For(op.ErrorCode),status=409,code=op.ErrorCode,detail=ErrorMessages.For(op.ErrorCode),traceId=op.Id.ToString("N")}};
    public async Task<object> ScheduleAsync(Actor actor,Guid id,string kind,long version,string? name,Guid? folder,bool force,HttpContext c)
    {
        if(kind is not ("rename" or "move" or "trash" or "permanent") || version<1)throw new ApiException(400,"invalid_operation");
        using var lease=await gate.EnterAsync(c.RequestAborted);var(item,library)=await media.RequireAsync(actor,id,"manage",c.RequestAborted);
        if(item.Kind is not ("video" or "photo") || item.SizeBytes is null)throw new ApiException(409,"unsupported_operation");
        var key=c.Request.Headers["Idempotency-Key"].ToString();if(key.Length>200 || key.Any(char.IsControl))throw new ApiException(400,"invalid_idempotency_key");var storedKey=key==""?null:Credentials.Hash(key);
        var digest=secrets.Digest(JsonSerializer.Serialize(new{id,kind,version,name,folder,force},Json));
        if(storedKey is not null){var old=await db.Operations.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==actor.UserId && x.Kind==kind && x.IdempotencyKey==storedKey,c.RequestAborted);if(old is not null){if(!Credentials.EqualHash(old.RequestHash,digest))throw new ApiException(409,"idempotency_conflict");return View(old);}}
        if(version!=item.Version)throw new ApiException(409,"version_conflict");
        if(await db.Operations.AnyAsync(x=>x.TargetId==id && (x.State=="pending" || x.State=="running"),c.RequestAborted))throw new ApiException(409,"operation_pending");
        if(await db.Operations.CountAsync(x=>x.UserId==actor.UserId && (x.State=="pending" || x.State=="running"),c.RequestAborted)>=100)throw new ApiException(429,"operation_limit");
        var targetName=item.DisplayName;var targetParent=item.ParentId;var parentPath=item.ParentRelativePath;
        if(kind=="rename")
        {targetName=IdentityInput.Text(name,255,field:"Name");ContainedDirectory.Validate(targetName);if(targetName.Contains('/') || targetName.StartsWith('.'))throw new ApiException(400,"invalid_name");}
        if(kind=="move")
        {targetParent=folder;parentPath="";if(folder is Guid folderId){var target=await db.MediaItems.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==folderId && x.LibraryId==library.Id && x.Kind=="folder" && x.Lifecycle=="available",c.RequestAborted)??throw new ApiException(404,"not_found");parentPath=target.RelativePath;}}
        var now=clock.GetUtcNow();var op=new Operation{UserId=actor.UserId,Kind=kind,TargetId=id,IdempotencyKey=storedKey,RequestHash=digest,State="pending",CreatedAt=now,UpdatedAt=now,ExpiresAt=now.AddDays(7)};
        var destination=parentPath==""?targetName:parentPath+"/"+targetName;
        if(kind is "trash" or "permanent")destination=$".briani/{(kind=="trash"?"trash":"removing")}/{op.Id:N}{(item.Extension.Length<=10?item.Extension:".bin")}";
        var command=new MutationCommand(actor.SessionId,library.Id,version,item.RelativePath,destination,item.FileIdentity,item.SizeBytes.Value,item.MtimeNs,targetName,targetParent,parentPath,item.SourceKind=="virtual",Force:force);op.PayloadJson=JsonSerializer.Serialize(command,Json);
        if(readers.HasReaders(id))
        {if(!force || kind is not ("trash" or "permanent"))throw new ApiException(409,"active_reader_conflict");await db.PlaybackSessions.Where(x=>x.MediaItemId==id && x.RevokedAt==null).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.RevokedAt,now),c.RequestAborted);readers.Cancel(id);}
        db.Operations.Add(op);audit.Add(actor.UserId,"media.operation_requested","media",id.ToString(),c.TraceIdentifier);await db.SaveChangesAsync(c.RequestAborted);return View(op);
    }
    public async Task<bool> RunOnceAsync(CancellationToken ct=default)
    {
        using var lease=await gate.EnterAsync(ct);var op=await db.Operations.Where(x=>new[]{"rename","move","trash","permanent"}.Contains(x.Kind) && (x.State=="pending" || x.State=="running")).OrderBy(x=>x.CreatedAt).FirstOrDefaultAsync(ct);if(op is null)return false;
        op.State="running";op.UpdatedAt=clock.GetUtcNow();await db.SaveChangesAsync(ct);bool applied=false;
        try
        {
            var cmd=JsonSerializer.Deserialize<MutationCommand>(op.PayloadJson,Json)??throw new ApiException(409,"journal_invalid");
            var item=await db.MediaItems.SingleOrDefaultAsync(x=>x.Id==op.TargetId && x.LibraryId==cmd.LibraryId,ct)??throw new ApiException(404,"not_found");
            var library=await db.Libraries.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==cmd.LibraryId,ct)??throw new ApiException(404,"not_found");using var root=storage.OpenLibrary(library);
            NodeIdentity? source=TryInspect(root,cmd.Source),destination=TryInspect(root,cmd.Destination);
            applied=!cmd.Virtual && cmd.Source!=cmd.Destination && ((source is null && Matches(destination,cmd)) || (op.Kind=="permanent" && cmd.Stage=="moved" && source is null && destination is null));
            if(!applied)
            {
                var u=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==op.UserId && x.Enabled && !x.MustChangePassword,ct)??throw new ApiException(403,"forbidden");await permissions.RequireLibraryAsync(new(u.Id,cmd.SessionId,u.Role),library.Id,"manage",ct);
                if(item.Version!=cmd.Version)throw new ApiException(409,"version_conflict");if(readers.HasReaders(item.Id)){if(cmd.Force){readers.Cancel(item.Id);op.State="pending";await db.SaveChangesAsync(ct);return false;}throw new ApiException(409,"active_reader_conflict");}
                if(!cmd.Virtual)
                {
                    if(!Matches(source,cmd))throw new ApiException(409,"file_identity_changed");if(destination is not null && cmd.Source!=cmd.Destination)throw new ApiException(409,"destination_exists");
                    if(op.Kind is "trash" or "permanent"){EnsureDirectory(root,".briani");EnsureDirectory(root,op.Kind=="trash"?".briani/trash":".briani/removing");}
                    if(cmd.Source!=cmd.Destination)root.Rename(cmd.Source,cmd.Destination);
                    if(!Matches(root.Inspect(cmd.Destination),cmd))
                    {if(TryInspect(root,cmd.Source) is null)root.Rename(cmd.Destination,cmd.Source);throw new ApiException(409,"file_identity_changed");}
                }
                cmd=cmd with{Stage="moved"};op.PayloadJson=JsonSerializer.Serialize(cmd,Json);await db.SaveChangesAsync(ct);applied=true;
            }
            if(op.Kind=="permanent" && !cmd.Virtual && TryInspect(root,cmd.Destination) is NodeIdentity remaining)
            {var owner=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==op.UserId && x.Enabled && !x.MustChangePassword,ct)??throw new ApiException(403,"forbidden");await permissions.RequireLibraryAsync(new(owner.Id,cmd.SessionId,owner.Role),library.Id,"manage",ct);if(!Matches(remaining,cmd))throw new ApiException(409,"file_identity_changed");root.Unlink(cmd.Destination);}
            BeforeCatalogCommit?.Invoke();
            var now=clock.GetUtcNow();await using var transaction=await db.Database.BeginTransactionAsync(ct);
            if(op.Kind is "trash" or "permanent")
            {item.Lifecycle=op.Kind=="trash"?"trashed":"deleted";item.MissingSince=now;if(!cmd.Virtual)item.RelativePath=cmd.Destination;}
            else
            {if(!cmd.Virtual)item.RelativePath=cmd.Destination;item.DisplayName=cmd.Name;item.ParentId=cmd.ParentId;item.ParentRelativePath=cmd.ParentPath;item.SearchKey=cmd.Name.Normalize(System.Text.NormalizationForm.FormKC).ToUpperInvariant();item.Extension=Path.GetExtension(cmd.Name).ToLowerInvariant();}
            item.Version++;item.IndexedAt=now;
            var meta=await db.MediaMetadata.SingleOrDefaultAsync(x=>x.MediaItemId==item.Id,ct);if(meta is not null && meta.ContentGeneration==cmd.Version)meta.ContentGeneration=item.Version;
            var thumbnails=await db.ThumbnailEntries.Where(x=>x.MediaItemId==item.Id && x.Generation==cmd.Version).ToArrayAsync(ct);
            foreach(var t in thumbnails){db.ThumbnailEntries.Remove(t);db.ThumbnailEntries.Add(new(){MediaItemId=t.MediaItemId,Generation=item.Version,Variant=t.Variant,CacheRelativePath=t.CacheRelativePath,FileIdentity=t.FileIdentity,Bytes=t.Bytes,CreatedAt=t.CreatedAt,LastAccessedAt=t.LastAccessedAt});}
            var trackedLibrary=await db.Libraries.SingleAsync(x=>x.Id==library.Id,ct);trackedLibrary.Version++;
            await db.PlaybackSessions.Where(x=>x.MediaItemId==item.Id && x.RevokedAt==null).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.RevokedAt,now),ct);readers.Cancel(item.Id);
            op.State="completed";op.ErrorCode=null;op.UpdatedAt=now;audit.Add(op.UserId,"media.operation_completed","media",item.Id.ToString());await db.SaveChangesAsync(ct);await transaction.CommitAsync(ct);return true;
        }
        catch(OperationCanceledException)when(ct.IsCancellationRequested){throw;}
        catch(ApiException e){op.State="failed";op.ErrorCode=e.Code;op.UpdatedAt=clock.GetUtcNow();await db.SaveChangesAsync(ct);return true;}
        catch(Exception)
        {
            var id=op.Id;db.ChangeTracker.Clear();var current=await db.Operations.SingleAsync(x=>x.Id==id,ct);
            if(current.State=="completed")return true;
            current.State=applied?"running":"failed";current.ErrorCode=applied?"operation_interrupted":"operation_failed";current.UpdatedAt=clock.GetUtcNow();await db.SaveChangesAsync(ct);return false;
        }
    }
    private static bool Matches(NodeIdentity? node,MutationCommand c)=>node?.IsFile==true && node.Key==c.Identity && node.Length==c.Bytes && node.MtimeNs==c.Mtime;
    private static NodeIdentity? TryInspect(ContainedDirectory root,string path){try{return root.Inspect(path);}catch(ApiException e)when(e.Code=="path_unavailable"){return null;}}
    private static void EnsureDirectory(ContainedDirectory root,string path){var node=TryInspect(root,path);if(node is null)root.CreateDirectory(path);else if(!node.IsDirectory)throw new ApiException(409,"path_unavailable");}
}
public sealed class MutationWorker(IServiceScopeFactory scopes,TimeProvider clock,ServerOptions options):BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {if(!options.BackgroundMediaOperations)return;while(!ct.IsCancellationRequested){try{using var scope=scopes.CreateScope();var processed=await scope.ServiceProvider.GetRequiredService<MediaOperations>().RunOnceAsync(ct);if(!processed)await Task.Delay(TimeSpan.FromSeconds(1),clock,ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}catch(Exception){await Task.Delay(TimeSpan.FromSeconds(1),clock,ct);}}}
}
