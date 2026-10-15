using System.Net;
using System.Text.Json;
using System.Text.Json.Nodes;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Administration;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Preferences;

public static class AdministratorConfiguration
{
    public const string Key="admin.settings";
    public static JsonObject DefaultValues()
    {
        var defaults=ConfigurationSchema.Defaults;var d=defaults["downloads"]!;
        var result=new JsonObject{["version"]=1,["serverName"]="Briani Player",["publicBaseUrl"]=null,
            ["activeDownloads"]=d["activeGlobal"]!.DeepClone(),["activeDownloadsPerUser"]=d["activePerUser"]!.DeepClone(),["activeSeeds"]=d["activeSeeds"]!.DeepClone(),
            ["globalConnections"]=d["globalConnections"]!.DeepClone(),["connectionsPerTorrent"]=d["connectionsPerTorrent"]!.DeepClone(),
            ["downloadLimitBytesPerSecond"]=d["globalDownloadBytesPerSecond"]?.DeepClone(),["uploadLimitBytesPerSecond"]=d["globalUploadBytesPerSecond"]!.DeepClone(),
            ["defaultRatioLimit"]=null,["defaultSeedTimeMinutes"]=null,["defaultUserQuotaBytes"]=null,
            ["lowDiskFloorBytes"]=d["lowDiskFloorBytes"]!.DeepClone(),["lowDiskFloorFraction"]=d["lowDiskFloorFraction"]!.DeepClone(),
            ["thumbnailCacheMaxBytes"]=defaults["media"]!["thumbnailCacheMaxBytes"]!.DeepClone(),["auditRetentionDays"]=defaults["server"]!["auditRetentionDays"]!.DeepClone(),
            ["enabledProviderIds"]=null,["enabledCategoryIds"]=null,["libraryScanIntervalSeconds"]=defaults["media"]!["scanIntervalSeconds"]!.DeepClone(),
            ["discoveryCacheSeconds"]=defaults["discovery"]!["cacheSeconds"]!.DeepClone(),["discoveryRecentRefreshSeconds"]=defaults["discovery"]!["recentRefreshSeconds"]!.DeepClone()};
        return result;
    }
    public static async Task<JsonObject> ReadAsync(BrianiDb db,CancellationToken ct=default)
    {
        var row=await db.Settings.AsNoTracking().SingleOrDefaultAsync(x=>x.Key==Key,ct);if(row is null)return DefaultValues();
        try{using var document=JsonDocument.Parse(row.ValueJson);Validate(document.RootElement);return ConfigurationSchema.Merge(DefaultValues(),document.RootElement,row.Version);}
        catch(Exception e)when(e is JsonException or ApiException or InvalidOperationException){throw new ApiException(503,"administrator_configuration_invalid");}
    }
    public static void Validate(JsonElement input)
    {
        ConfigurationSchema.Validate("AdminSettings",input);
        if(input.TryGetProperty("publicBaseUrl",out var baseUrl) && baseUrl.ValueKind!=JsonValueKind.Null){
            var value=baseUrl.GetString()!;
            if(value.Length>2048 || !Uri.TryCreate(value,UriKind.Absolute,out var uri) || uri.Scheme is not("http" or "https") ||
                uri.UserInfo!="" || uri.Query!="" || uri.Fragment!="" || uri.AbsolutePath!="/" || string.IsNullOrEmpty(uri.Host) || uri.Port<1 ||
                uri.HostNameType==UriHostNameType.Unknown)throw new ApiException(400,"invalid_public_origin");
        }
        foreach(var name in new[]{"downloadLimitBytesPerSecond","uploadLimitBytesPerSecond"})
            if(input.TryGetProperty(name,out var speed) && speed.ValueKind!=JsonValueKind.Null && speed.GetInt64()>1073741824)throw new ApiException(400,"invalid_settings",$"{ConfigurationSchema.Label(name)} must be at most 1 GiB/s (1073741824 bytes per second).");
        if(input.TryGetProperty("defaultRatioLimit",out var ratio) && ratio.ValueKind!=JsonValueKind.Null && ratio.GetDouble()>10000)throw new ApiException(400,"invalid_settings","Default ratio limit must be at most 10000.");
        if(input.TryGetProperty("defaultSeedTimeMinutes",out var minutes) && minutes.ValueKind!=JsonValueKind.Null && minutes.GetInt64()>525600)throw new ApiException(400,"invalid_settings","Default seed time must be at most 525600 minutes (one year).");
        if(input.TryGetProperty("thumbnailCacheMaxBytes",out var cache) && cache.GetInt64()>8589934592)throw new ApiException(400,"invalid_settings","Thumbnail cache size must be at most 8 GiB.");
        if(input.TryGetProperty("libraryScanIntervalSeconds",out var scan) && scan.GetInt64()>31536000)throw new ApiException(400,"invalid_settings","Library scan interval must be at most one year (31536000 seconds).");
        if(input.TryGetProperty("enabledProviderIds",out var providers) && providers.ValueKind==JsonValueKind.Array && providers.EnumerateArray().Any(x=>x.GetString() is not {Length:>0 and <=200}))throw new ApiException(400,"invalid_settings","Indexer IDs must be 1–200 characters each.");
        if(input.TryGetProperty("enabledCategoryIds",out var categories) && categories.ValueKind==JsonValueKind.Array && categories.EnumerateArray().Any(x=>x.GetInt64()<0))throw new ApiException(400,"invalid_settings","Category IDs must be whole numbers of zero or more.");
    }
    public static async Task<string> OriginAsync(BrianiDb db,HttpContext context,CancellationToken ct=default) =>
        (await ReadAsync(db,ct))["publicBaseUrl"]?.GetValue<string>()?.TrimEnd('/') ?? $"{context.Request.Scheme}://{context.Request.Host}";
    public static bool ProviderAllowed(JsonObject settings,string id) => settings["enabledProviderIds"] is not JsonArray ids || ids.Any(x=>x!.GetValue<string>()==id);
    public static bool CategoriesAllowed(JsonObject settings,IEnumerable<long> categories) => settings["enabledCategoryIds"] is not JsonArray ids || categories.Any(category=>ids.Any(x=>x!.GetValue<long>()==category));
    public static Discovery.DiscoveryQuery ApplyDiscoveryPolicy(JsonObject settings,Discovery.DiscoveryQuery query) {
        if(query.ProviderIds?.Any(id=>!ProviderAllowed(settings,id))==true || query.Categories?.Any(id=>settings["enabledCategoryIds"] is JsonArray ids && !ids.Any(x=>x!.GetValue<long>()==id))==true)throw new ApiException(403,"discovery_filter_disabled");
        return query with {ProviderIds=query.ProviderIds is {Length:>0}?query.ProviderIds:settings["enabledProviderIds"]?.AsArray().Select(x=>x!.GetValue<string>()).ToArray(),
            Categories=query.Categories is {Length:>0}?query.Categories:settings["enabledCategoryIds"]?.AsArray().Select(x=>x!.GetValue<long>()).ToArray()};
    }
    public static void MapAdministratorConfiguration(this WebApplication app)
    {
        var group=app.MapGroup("/api/v1/admin").RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        group.MapGet("/settings",async(BrianiDb db,CancellationToken ct)=>Results.Ok(await ReadAsync(db,ct)));
        group.MapPut("/settings",async(JsonElement input,HttpContext c,BrianiDb db,WriteGate gate,Audit audit,TimeProvider clock)=>{
            Validate(input); // LiveAdministratorFilter owns the write gate through this mutation.
            var row=await db.Settings.SingleOrDefaultAsync(x=>x.Key==Key,c.RequestAborted);
            if(input.GetProperty("version").GetInt64()!=(row?.Version??1))throw new ApiException(409,"version_conflict");
            var fresh=ConfigurationSchema.Merge(await ReadAsync(db,c.RequestAborted),input,(row?.Version??1)+1);
            using(var document=JsonDocument.Parse(fresh.ToJsonString()))Validate(document.RootElement);
            if(row is null){row=new(){Key=Key};db.Settings.Add(row);}
            row.Version=fresh["version"]!.GetValue<long>();row.ValueJson=fresh.ToJsonString();row.UpdatedAt=clock.GetUtcNow();
            // Durable application desired state; upstream work never holds the write gate.
            if(!await db.Jobs.AnyAsync(x=>x.Kind=="configureEngine" && (x.State=="queued" || x.State=="running"),c.RequestAborted))db.Jobs.Add(new(){Kind="configureEngine",TargetId=Guid.Empty,CreatedAt=clock.GetUtcNow(),UpdatedAt=clock.GetUtcNow(),NextAttemptAt=clock.GetUtcNow()});
            audit.Add(Actor.From(c.User).UserId,"configuration.updated","configuration","administrator",c.TraceIdentifier);
            await db.SaveChangesAsync(c.RequestAborted);return Results.Ok(fresh);});
        group.MapGet("/audit",async(HttpContext c,BrianiDb db,PageCursor cursors,int? limit,string? cursor,DateTimeOffset? before,CancellationToken ct)=>{
            var size=Math.Clamp(limit??50,1,200);var actor=Actor.From(c.User);var cursorScope=$"audit:{actor.UserId:D}:{before?.UtcTicks}";var offset=cursors.Decode(cursor,cursorScope);
            if(offset<0 || offset>100000)throw new ApiException(400,"invalid_cursor");
            var query=db.AuditEvents.AsNoTracking().Where(x=>before==null || x.CreatedAt<before).OrderByDescending(x=>x.CreatedAt).ThenByDescending(x=>x.Id);
            var rows=await query.Skip((int)offset).Take(size+1).ToArrayAsync(ct);var more=rows.Length>size;
            return Results.Ok(new{items=rows.Take(size).Select(x=>new{x.Id,occurredAt=x.CreatedAt,actorId=x.ActorId,action=x.Action,resourceType=x.TargetType,
                    resourceId=Guid.TryParse(x.TargetId,out var id)?id:(Guid?)null,outcome=x.Result,detail=(string?)null}),
                nextCursor=more && offset+size<=10000?cursors.Encode(cursorScope,offset+size):null,totalKnown=(long?)null,truncated=more && offset+size>10000,warnings=Array.Empty<string>()});});
    }
}
