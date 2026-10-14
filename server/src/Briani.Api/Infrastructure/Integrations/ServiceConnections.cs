using System.Text.Json;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Infrastructure;
using System.Text.Json.Serialization;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Administration;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Infrastructure.Integrations;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record IntegrationUpdate([property:JsonRequired]string BaseUrl,[property:JsonRequired]long Version,string? Username=null,string? Secret=null);
public sealed record ProtectedConnection(string BaseUrl,string? Username,string? EncryptedSecret,long Version=1);
public sealed record ServiceConnection(Uri Origin,string? Username,string Secret,long Version);
public sealed class ServiceConnections(IServiceScopeFactory scopes,SecretStore secrets,TimeProvider clock,ServerOptions options)
{
    private readonly System.Collections.Concurrent.ConcurrentDictionary<string,HealthObservation> health=new();
    private sealed record HealthObservation(long Version,string State,string Detail,DateTimeOffset CheckedAt);
    public void Observe(string kind,long version,string state,string detail){if(kind is "prowlarr" or "qbittorrent")health[kind]=new(version,state,detail,clock.GetUtcNow());}
    private static readonly JsonSerializerOptions Json=new(JsonSerializerDefaults.Web);
    public static Uri ValidateOrigin(string value)
    {
        if(value.Length>2048 || !Uri.TryCreate(value,UriKind.Absolute,out var uri) || uri.Scheme is not ("http" or "https") || uri.UserInfo!="" || uri.Fragment!="" || uri.Query!="" || string.IsNullOrEmpty(uri.Host) || uri.HostNameType==UriHostNameType.Unknown)throw new ApiException(400,"invalid_service_origin");
        return new(uri.AbsoluteUri.TrimEnd('/')+"/");
    }
    public async Task<System.Text.Json.Nodes.JsonObject> AdministratorSettingsAsync(CancellationToken ct=default)
    {using var scope=scopes.CreateScope();return await Briani.Api.Modules.Preferences.AdministratorConfiguration.ReadAsync(scope.ServiceProvider.GetRequiredService<BrianiDb>(),ct);}
    public async Task<ProtectedConnection> ReadAsync(string kind,CancellationToken ct=default)
    {
        if(kind is not ("prowlarr" or "qbittorrent"))throw new ApiException(404,"not_found");using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<BrianiDb>();
        var value=await db.Settings.AsNoTracking().SingleOrDefaultAsync(x=>x.Key=="integration."+kind,ct);
        if(value is not null)return JsonSerializer.Deserialize<ProtectedConnection>(value.ValueJson,Json)??throw new ApiException(503,"integration_configuration_invalid");
        var secret=ReadMountedCredential(kind);
        return new(kind=="prowlarr"?"http://prowlarr:9696/":"http://qbittorrent:8080/",kind=="qbittorrent"?"admin":null,secret is null?null:secrets.Encrypt(secret));
    }
    private string? ReadMountedCredential(string kind)
    {
        if(!Directory.Exists(options.SecretsRoot))return null;
        try {
            using var directory=new ContainedDirectory(options.SecretsRoot);
            var name=kind=="qbittorrent"?"qbittorrent-webui-password":"prowlarr-api-key";
            var stat=directory.Inspect(name);
            if(!stat.IsFile || stat.Length is <1 or >10000 || (stat.Mode & 0x3f)!=0)throw new ApiException(503,"integration_credential_file_invalid");
            using var file=directory.OpenFile(name,stat.Key);using var reader=new StreamReader(file,new System.Text.UTF8Encoding(false,true),detectEncodingFromByteOrderMarks:false);
            var buffer=new char[10001];var count=reader.ReadBlock(buffer,0,buffer.Length);
            if(count>10000)throw new ApiException(503,"integration_credential_file_invalid");
            var value=new string(buffer,0,count).TrimEnd('\r','\n');
            if(value.Length is <1 or >10000 || value.Any(char.IsControl))throw new ApiException(503,"integration_credential_file_invalid");
            return value;
        } catch(ApiException e) when(e.Code=="path_unavailable") { return null; }
        catch(System.Text.DecoderFallbackException) {throw new ApiException(503,"integration_credential_file_invalid");}
        catch(IOException) {throw new ApiException(503,"integration_credential_file_invalid");}
    }
    public async Task<ServiceConnection> RequiredAsync(string kind,CancellationToken ct=default)
    {var c=await ReadAsync(kind,ct);if(c.EncryptedSecret is null)throw new ApiException(503,"credentials_missing");return new(ValidateOrigin(c.BaseUrl),c.Username,secrets.Decrypt(c.EncryptedSecret),c.Version);}
    public async Task<object> SaveAsync(string kind,IntegrationUpdate update,Actor actor,BrianiDb db,Audit audit,CancellationToken ct=default)
    {
        if(kind is not ("prowlarr" or "qbittorrent"))throw new ApiException(404,"not_found");var origin=ValidateOrigin(update.BaseUrl);
        if(update.Version<1 || update.Username?.Length>200 || update.Username?.Any(char.IsControl)==true || update.Secret?.Length>10000 || update.Secret?.Any(char.IsControl)==true || update.Secret=="")throw new ApiException(400,"invalid_integration");
        var row=await db.Settings.SingleOrDefaultAsync(x=>x.Key=="integration."+kind,ct);var old=row is null?await ReadAsync(kind,ct):JsonSerializer.Deserialize<ProtectedConnection>(row.ValueJson,Json)!;
        if(old.Version!=update.Version)throw new ApiException(409,"version_conflict");var fresh=new ProtectedConnection(origin.AbsoluteUri,update.Username??old.Username,update.Secret is null?old.EncryptedSecret:secrets.Encrypt(update.Secret),old.Version+1);
        if(row is null){row=new Setting{Key="integration."+kind};db.Settings.Add(row);}else row.Version++;
        row.ValueJson=JsonSerializer.Serialize(fresh,Json);row.UpdatedAt=clock.GetUtcNow();audit.Add(actor.UserId,"integration.updated","integration",kind);await db.SaveChangesAsync(ct);return View(kind,fresh);
    }
    public object View(string kind,ProtectedConnection c)
    {var observed=health.TryGetValue(kind,out var last) && last.Version==c.Version && clock.GetUtcNow()-last.CheckedAt<TimeSpan.FromMinutes(1)?last:null;return new{kind,baseUrl=c.BaseUrl,credentialConfigured=c.EncryptedSecret is not null,version=c.Version,health=new{service=kind,state=observed?.State??(c.EncryptedSecret is null?"unavailable":"unknown"),checkedAt=observed?.CheckedAt??clock.GetUtcNow(),detail=observed?.Detail??(c.EncryptedSecret is null?"credentials_missing":null)}};}
    public static void Map(WebApplication app)
    {
        var group=app.MapGroup("/api/v1/admin/integrations").RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        group.MapGet("",async(ServiceConnections service,CancellationToken ct)=>new[]{service.View("prowlarr",await service.ReadAsync("prowlarr",ct)),service.View("qbittorrent",await service.ReadAsync("qbittorrent",ct))});
        group.MapPut("/{kind}",async(string kind,IntegrationUpdate update,HttpContext c,ServiceConnections service,BrianiDb db,Audit audit,WriteGate gate)=>{return Results.Ok(await service.SaveAsync(kind,update,Actor.From(c.User),db,audit,c.RequestAborted));});
    }
}
