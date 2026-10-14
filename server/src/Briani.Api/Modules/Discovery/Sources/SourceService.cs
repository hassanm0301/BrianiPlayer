using System.Text;
using Briani.Api.Modules.Preferences;
using System.Security.Cryptography;
using System.Text.Json;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.Prowlarr;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Discovery.Sources;
public sealed record ResolvedSource(string Kind,byte[]? Torrent,string? Magnet,MetainfoDescriptor? Metadata,Guid? ResultId=null,Guid? UploadId=null);
internal sealed record ResolutionOption(string ProviderId,string SourceGuid,string? DownloadUrl,string? MagnetUri,string? InfoHashV1,string? InfoHashV2);
public sealed class SourceService(BrianiDb db,DiscoveryAccess access,ServiceConnections connections,SafeHttp http,ISafeDns dns,IProwlarrClient prowlarr,SecretStore secrets,ServerOptions options,WriteGate gate,TimeProvider clock,SourceLimits limits)
{
    private static readonly JsonSerializerOptions Json=new(JsonSerializerDefaults.Web){PropertyNameCaseInsensitive=true};
    public async Task<ResolvedSource> ResolveAsync(Actor actor,string kind,string value,CancellationToken ct=default)
    {using var lease=limits.Enter();try{return await ResolveCoreAsync(actor,kind,value,ct);}catch(OperationCanceledException)when(!ct.IsCancellationRequested){throw new ApiException(503,"source_timeout");}catch(ProwlarrFailure){throw new ApiException(503,"dependency_unavailable");}}
    private async Task RequireCurrentAsync(Actor actor,string stamp,CancellationToken ct)
    {if(await access.RequireAsync(actor,ct)!=stamp)throw new ApiException(404,"not_found");}
    private async Task<ResolvedSource> ResolveCoreAsync(Actor actor,string kind,string value,CancellationToken ct)
    {
        var stamp=await access.RequireAsync(actor,ct);using var deadline=CancellationTokenSource.CreateLinkedTokenSource(ct);deadline.CancelAfter(TimeSpan.FromSeconds(25));ct=deadline.Token;
        if(kind=="magnet")
        {var magnet=SourceValidation.Magnet(value);await SourceValidation.ValidateTrackerDnsAsync(magnet.Trackers,dns,ct);await RequireCurrentAsync(actor,stamp,ct);return new(kind,null,magnet.Uri,null);}
        if(!Guid.TryParse(value,out var id))throw new ApiException(400,"invalid_source");
        if(kind=="torrentUpload")
        {
            var upload=await db.TorrentUploads.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id && x.UserId==actor.UserId && x.ExpiresAt>clock.GetUtcNow(),ct)??throw new ApiException(404,"not_found");
            using var root=new ContainedDirectory(options.StateRoot);using var file=root.OpenFile(upload.RelativePath,upload.FileIdentity);if(file.Length!=upload.Bytes || file.Length>16777216)throw new ApiException(409,"source_changed");var payload=new byte[(int)file.Length];await file.ReadExactlyAsync(payload,ct);
            if(!Credentials.EqualHash(Convert.ToHexString(SHA256.HashData(payload)),upload.Sha256))throw new ApiException(409,"source_changed");var metadata=Metainfo.Parse(payload);await SourceValidation.ValidateTrackerDnsAsync(metadata.Trackers,dns,ct);await RequireCurrentAsync(actor,stamp,ct);if(!await db.TorrentUploads.AsNoTracking().AnyAsync(x=>x.Id==id && x.UserId==actor.UserId && x.ExpiresAt>clock.GetUtcNow(),ct))throw new ApiException(409,"source_expired");return new(kind,payload,null,metadata,UploadId:id);
        }
        if(kind!="discoveryResult")throw new ApiException(400,"invalid_source");
        var result=await db.DiscoveryResults.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id,ct)??throw new ApiException(404,"not_found");var snapshot=await db.DiscoverySnapshots.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==result.SnapshotId && x.UserId==actor.UserId && x.PermissionStamp==stamp,ct)??throw new ApiException(404,"not_found");
        var alternatives=JsonSerializer.Deserialize<ResolutionOption[]>(secrets.Decrypt(result.EncryptedResolutionJson),Json)??throw new ApiException(409,"source_expired");if(alternatives.Length is <1 or >100)throw new ApiException(409,"source_expired");
        var configuration=await AdministratorConfiguration.ReadAsync(db,ct);
        var first=alternatives.FirstOrDefault(x=>AdministratorConfiguration.ProviderAllowed(configuration,x.ProviderId))??throw new ApiException(409,"source_disabled");
        if(!AdministratorConfiguration.CategoriesAllowed(configuration,JsonSerializer.Deserialize<long[]>(result.CategoriesJson)??[]))throw new ApiException(409,"source_disabled");
        if(clock.GetUtcNow()-result.ObservedAt>TimeSpan.FromMinutes(5) || snapshot.ExpiresAt<=clock.GetUtcNow())
        {
            var provider=(await prowlarr.ProvidersAsync(ct)).SingleOrDefault(x=>x.Id==first.ProviderId && x.Enabled && x.SupportsSearch)??throw new ApiException(409,"source_expired");
            var releases=await prowlarr.SearchAsync(provider,new("search",result.Title.Length>200?result.Title[..200]:result.Title,[]),ct);
            var fresh=releases.Releases.FirstOrDefault(x=>x.SourceGuid==first.SourceGuid && Compatible(first.InfoHashV1,first.InfoHashV2,x.InfoHashV1,x.InfoHashV2));if(fresh is null)throw new ApiException(409,"source_expired");
            first=new(provider.Id,fresh.SourceGuid,fresh.DownloadUrl,fresh.MagnetUri,fresh.InfoHashV1,fresh.InfoHashV2);
        }
        ResolvedSource resolved;
        if(first.MagnetUri is not null && first.MagnetUri.StartsWith("magnet:?",StringComparison.OrdinalIgnoreCase))resolved=await FromMagnetAsync(first.MagnetUri,ct);
        else
        {
            var reference=first.DownloadUrl??first.MagnetUri??throw new ApiException(409,"source_unavailable");
            if(reference.StartsWith("magnet:?",StringComparison.OrdinalIgnoreCase))resolved=await FromMagnetAsync(reference,ct);
            else
            {
                var connection=await connections.RequiredAsync("prowlarr",ct);Uri current;
                if(reference.StartsWith('/') || !Uri.TryCreate(reference,UriKind.Absolute,out current!))current=new Uri(connection.Origin,reference);
                var seen=new HashSet<string>(StringComparer.Ordinal);resolved=null!;
                for(int redirect=0;redirect<=5;redirect++)
                {
                    SafeHttp.ValidateContentUrl(current,connection.Origin);if(!seen.Add(current.AbsoluteUri))throw new ApiException(400,"source_redirect_loop");
                    var response=await http.GetAsync(current,16777216,connection.Origin,connection.Secret,ct);
                    if(response.Status is 301 or 302 or 303 or 307 or 308)
                    {
                        if(response.Location is null || redirect==5)throw new ApiException(400,"source_redirect_limit");var next=response.Location.IsAbsoluteUri?response.Location:new Uri(current,response.Location);
                        if(next.Scheme=="magnet"){resolved=await FromMagnetAsync(next.OriginalString,ct);break;}
                        if(current.Scheme=="https" && next.Scheme!="https")throw new ApiException(400,"source_redirect_downgrade");current=next;continue;
                    }
                    if(response.Status!=200)throw new ApiException(503,"source_unavailable");
                    if(response.Body.Length<=65536 && Encoding.ASCII.GetString(response.Body.AsSpan(0,Math.Min(8,response.Body.Length))).Equals("magnet:?",StringComparison.OrdinalIgnoreCase))resolved=await FromMagnetAsync(new UTF8Encoding(false,true).GetString(response.Body).Trim(),ct);
                    else{var metadata=Metainfo.Parse(response.Body);await SourceValidation.ValidateTrackerDnsAsync(metadata.Trackers,dns,ct);resolved=new("discoveryResult",response.Body,null,metadata);}
                    break;
                }
                if(resolved is null)throw new ApiException(400,"source_redirect_limit");
            }
        }
        var foundV1=resolved.Metadata?.InfoHashV1;var foundV2=resolved.Metadata?.InfoHashV2;if(resolved.Magnet is not null){var m=SourceValidation.Magnet(resolved.Magnet);foundV1=m.InfoHashV1;foundV2=m.InfoHashV2;}
        if(!Compatible(first.InfoHashV1,first.InfoHashV2,foundV1,foundV2))throw new ApiException(409,"source_identity_changed");await RequireCurrentAsync(actor,stamp,ct);configuration=await AdministratorConfiguration.ReadAsync(db,ct);if(!AdministratorConfiguration.ProviderAllowed(configuration,first.ProviderId) || !AdministratorConfiguration.CategoriesAllowed(configuration,JsonSerializer.Deserialize<long[]>(result.CategoriesJson)??[]))throw new ApiException(409,"source_disabled");return resolved with{Kind=kind,ResultId=id};
    }
    private static bool Compatible(string? expected1,string? expected2,string? actual1,string? actual2)=> (expected1 is null || expected1.Equals(actual1,StringComparison.OrdinalIgnoreCase)) && (expected2 is null || expected2.Equals(actual2,StringComparison.OrdinalIgnoreCase));
    private async Task<ResolvedSource> FromMagnetAsync(string value,CancellationToken ct){var magnet=SourceValidation.Magnet(value);await SourceValidation.ValidateTrackerDnsAsync(magnet.Trackers,dns,ct);return new("magnet",null,magnet.Uri,null);}
    public async Task<object> UploadAsync(Actor actor,IFormFile input,HttpContext context,CancellationToken ct)
    {
        await access.RequireAsync(actor,ct);var form=await context.Request.ReadFormAsync(ct);if(form.Count!=0 || form.Files.Count!=1 || input.Name!="file")throw new ApiException(400,"invalid_upload_form");if(input.Length is <1 or >16777216)throw new ApiException(400,"torrent_upload_too_large");using var source=input.OpenReadStream();using var buffer=new MemoryStream();var chunk=new byte[65536];int read;
        while((read=await source.ReadAsync(chunk,ct))>0){if(buffer.Length+read>16777216)throw new ApiException(400,"torrent_upload_too_large");buffer.Write(chunk,0,read);}var payload=buffer.ToArray();Metainfo.Parse(payload);
        var hash=Convert.ToHexString(SHA256.HashData(payload));var key=context.Request.Headers["Idempotency-Key"].ToString();if(key.Length>200 || key.Any(char.IsControl))throw new ApiException(400,"invalid_idempotency_key");var storedKey=key==""?null:Credentials.Hash(key);
        using var lease=await gate.EnterAsync(ct);await access.RequireAsync(actor,ct);
        if(storedKey is not null){var prior=await db.Operations.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==actor.UserId && x.Kind=="torrent-upload" && x.IdempotencyKey==storedKey,ct);if(prior is not null){if(!Credentials.EqualHash(prior.RequestHash,hash))throw new ApiException(409,"idempotency_conflict");var old=await db.TorrentUploads.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==prior.TargetId && x.UserId==actor.UserId && x.ExpiresAt>clock.GetUtcNow(),ct)??throw new ApiException(409,"source_expired");return View(old);}}
        var retainedFiles=await SourceHousekeeping.PruneUploadsAsync(db,options,clock,ct);
        if(retainedFiles>=32 || await db.TorrentUploads.CountAsync(x=>x.UserId==actor.UserId,ct)>=4 || await db.TorrentUploads.CountAsync(ct)>=32)throw new ApiException(429,"upload_limit");
        using var root=new ContainedDirectory(options.StateRoot);try{if(!root.Inspect("uploads").IsDirectory)throw new ApiException(409,"upload_storage_unavailable");}catch(ApiException error)when(error.Code=="path_unavailable"){root.CreateDirectory("uploads");}
        if(root.Volume().FreeBytes<payload.Length+16777216L)throw new ApiException(507,"disk_unavailable");
        var now=clock.GetUtcNow();var upload=new TorrentUpload{UserId=actor.UserId,Bytes=payload.Length,Sha256=hash,CreatedAt=now,ExpiresAt=now.AddMinutes(30)};upload.RelativePath=$"uploads/{upload.Id:N}.torrent";
        try{using(var file=root.CreateFile(upload.RelativePath)){upload.FileIdentity=ContainedDirectory.Inspect(file).Key;await file.WriteAsync(payload,ct);file.Flush(true);}
        db.TorrentUploads.Add(upload);if(storedKey is not null)db.Operations.Add(new(){UserId=actor.UserId,Kind="torrent-upload",TargetId=upload.Id,IdempotencyKey=storedKey,RequestHash=hash,State="completed",CreatedAt=now,UpdatedAt=now,ExpiresAt=upload.ExpiresAt});
        await db.SaveChangesAsync(ct);}catch{if(upload.FileIdentity!=""){try{if(root.Inspect(upload.RelativePath).Key==upload.FileIdentity)root.Unlink(upload.RelativePath);}catch(ApiException){}}throw;}return View(upload);
    }
    private static object View(TorrentUpload upload)=>new{id=upload.Id,expiresAt=upload.ExpiresAt,sizeBytes=upload.Bytes};
    public static void Map(WebApplication app)=>app.MapPost("/api/v1/torrent-uploads",async(IFormFile file,HttpContext c,SourceService sources)=>Results.Json(await sources.UploadAsync(Actor.From(c.User),file,c,c.RequestAborted),statusCode:201)).DisableAntiforgery().RequireAuthorization();
}
