using System.Text.Json;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.Prowlarr;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Infrastructure.Integrations;
public static class IntegrationHealth
{
    public static void Map(WebApplication app)
    {
        app.MapPost("/api/v1/admin/integrations/{kind}/test",async(string kind,HttpContext context,BrianiDb db,PermissionService permissions,IProwlarrTransport prowlarr,ITorrentEngine torrents,TimeProvider clock,ServiceConnections connections)=>
        {
            if(kind is not ("prowlarr" or "qbittorrent"))throw new ApiException(404,"not_found");var actor=Actor.From(context.User);var ct=context.RequestAborted;await RequireAdministratorAsync(actor,db,permissions,ct);
            var configured=await connections.ReadAsync(kind,ct);string state="unavailable",detail="dependency_unavailable";
            if(kind=="prowlarr")
            {
                try{var bytes=await prowlarr.GetAsync("/api/v1/system/status",ct);using var document=JsonDocument.Parse(bytes,new JsonDocumentOptions{MaxDepth=32});if(document.RootElement.ValueKind==JsonValueKind.Object && document.RootElement.TryGetProperty("version",out var version) && version.ValueKind==JsonValueKind.String && version.GetString() is {Length:>0 and <=200}){state="healthy";detail="Connection succeeded.";}else detail="invalid_response";}
                catch(ProwlarrFailure error){detail=error.Code is "credentials_missing" or "credentials_rejected"?error.Code:"dependency_unavailable";}
                catch(JsonException){detail="invalid_response";}
            }
            else{try{await torrents.VersionAsync(ct);state="healthy";detail="Connection succeeded.";}catch(EngineFailure error){detail=error.Code is "credentials_missing" or "credentials_rejected" or "engine_incompatible"?error.Code:"dependency_unavailable";}}
            await RequireAdministratorAsync(actor,db,permissions,ct);connections.Observe(kind,configured.Version,state,detail);return Results.Ok(new{service=kind,state,detail,checkedAt=clock.GetUtcNow()});
        }).RequireAuthorization("administrator");
    }
    internal static async Task RequireAdministratorAsync(Actor actor,BrianiDb db,PermissionService permissions,CancellationToken ct)
    {if(!await permissions.IsAccessValidAsync(actor,ct) || !await db.Users.AsNoTracking().AnyAsync(x=>x.Id==actor.UserId && x.Enabled && !x.MustChangePassword && x.Role=="administrator",ct))throw new ApiException(403,"forbidden");}
}
