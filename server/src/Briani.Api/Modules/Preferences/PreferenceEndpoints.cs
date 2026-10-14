using System.Text.Json;
using System.Text.Json.Nodes;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Preferences;
public sealed class UserPreference
{
    public Guid UserId{get;set;} public string SettingsJson{get;set;}="{}";public long Version{get;set;}=1;
}
public static class PreferenceEndpoints
{
    public static void MapPreferences(this WebApplication app)
    {
        var group=app.MapGroup("/api/v1/me/preferences").RequireAuthorization();
        group.MapGet("",async(HttpContext c,BrianiDb db,IdentityService identity)=>{
            var actor=Actor.From(c.User);await identity.CurrentUserAsync(actor,c.RequestAborted);
            return Results.Ok(await ReadAsync(db,actor.UserId,c.RequestAborted));});
        group.MapPut("",async(JsonElement input,HttpContext c,BrianiDb db,WriteGate gate,IdentityService identity)=>{
            ConfigurationSchema.Validate("UserPreferences",input);using var held=await gate.EnterAsync(c.RequestAborted);
            var actor=Actor.From(c.User);await identity.CurrentUserAsync(actor,c.RequestAborted);
            var row=await db.UserPreferences.SingleOrDefaultAsync(x=>x.UserId==actor.UserId,c.RequestAborted);
            var current=await ReadAsync(db,actor.UserId,c.RequestAborted);
            if(input.GetProperty("version").GetInt64()!=(row?.Version??1))throw new ApiException(409,"version_conflict");
            var fresh=ConfigurationSchema.Merge(current,input,(row?.Version??1)+1);
            if(row is null){row=new(){UserId=actor.UserId};db.UserPreferences.Add(row);}
            row.Version=fresh["version"]!.GetValue<long>();row.SettingsJson=fresh.ToJsonString();await db.SaveChangesAsync(c.RequestAborted);return Results.Ok(fresh);});
        group.MapPost("/reset",async(JsonElement input,HttpContext c,BrianiDb db,WriteGate gate,IdentityService identity,SecretStore secrets,TimeProvider clock)=>{
            ConfigurationSchema.Validate("VersionRequest",input);using var held=await gate.EnterAsync(c.RequestAborted);
            var actor=Actor.From(c.User);await identity.CurrentUserAsync(actor,c.RequestAborted);
            var key=c.Request.Headers["Idempotency-Key"].FirstOrDefault();
            if(key is {Length:>200} || key is not null && (key.Length==0 || key.Any(char.IsControl)))throw new ApiException(400,"invalid_request");
            var cacheKey=key is null?null:$"preferences-reset:{actor.UserId:D}:{secrets.Digest(key)}";
            var requestHash=secrets.Digest(input.GetRawText());
            var cutoff=clock.GetUtcNow().AddDays(-1);
            if(cacheKey is not null) {
                var cached=await db.Settings.FindAsync([cacheKey],c.RequestAborted);
                if(cached is not null && cached.UpdatedAt>cutoff) {
                    var replay=JsonNode.Parse(cached.ValueJson)!.AsObject();if(replay["hash"]!.GetValue<string>()!=requestHash)throw new ApiException(409,"idempotency_conflict");return Results.Ok(replay["result"]!.DeepClone());
                }
                if(cached is not null) {db.Settings.Remove(cached);await db.SaveChangesAsync(c.RequestAborted);}
                var prefix=$"preferences-reset:{actor.UserId:D}:";
                var expired=await db.Settings.Where(x=>x.Key.StartsWith("preferences-reset:") && x.UpdatedAt<=cutoff).Select(x=>x.Key).Take(500).ToArrayAsync(c.RequestAborted);
                await db.Settings.Where(x=>expired.Contains(x.Key)).ExecuteDeleteAsync(c.RequestAborted);
                if(await db.Settings.CountAsync(x=>x.Key.StartsWith(prefix),c.RequestAborted)>=128 || await db.Settings.CountAsync(x=>x.Key.StartsWith("preferences-reset:"),c.RequestAborted)>=8192)throw new ApiException(429,"idempotency_limit");
            }
            var row=await db.UserPreferences.SingleOrDefaultAsync(x=>x.UserId==actor.UserId,c.RequestAborted);
            if(input.GetProperty("version").GetInt64()!=(row?.Version??1))throw new ApiException(409,"version_conflict");
            var fresh=ConfigurationSchema.UserDefaults();fresh["version"]=(row?.Version??1)+1;
            if(row is null){row=new(){UserId=actor.UserId};db.UserPreferences.Add(row);}
            row.Version=fresh["version"]!.GetValue<long>();row.SettingsJson=fresh.ToJsonString();
            if(cacheKey is not null)db.Settings.Add(new(){Key=cacheKey,ValueJson=new JsonObject{["hash"]=requestHash,["result"]=fresh.DeepClone()}.ToJsonString(),UpdatedAt=clock.GetUtcNow()});
            await db.SaveChangesAsync(c.RequestAborted);return Results.Ok(fresh);});
    }
    public static async Task<JsonObject> ReadAsync(BrianiDb db,Guid userId,CancellationToken ct)
    {
        var row=await db.UserPreferences.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==userId,ct);
        if(row is null)return ConfigurationSchema.UserDefaults();
        try{using var document=JsonDocument.Parse(row.SettingsJson);ConfigurationSchema.Validate("UserPreferences",document.RootElement);
            return ConfigurationSchema.Merge(ConfigurationSchema.UserDefaults(),document.RootElement,row.Version);}
        catch(Exception e)when(e is JsonException or ApiException or InvalidOperationException){throw new ApiException(503,"preferences_invalid");}
    }
}
