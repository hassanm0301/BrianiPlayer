using System.Globalization;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.Prowlarr;
namespace Briani.Api.Infrastructure.Integrations;
// Administrator-only indexer management. Like the integration test endpoint this does not hold the
// global write gate across upstream calls (Prowlarr tests an indexer before saving it); the live
// administrator check runs before, again just before a change is sent, and after, and the gate is
// taken only for the audit row. A change Prowlarr did not confirm in time is audited as unconfirmed.
public static class IndexerManagement
{
    public static void Map(WebApplication app)
    {
        var group=app.MapGroup("/api/v1/admin/indexers").RequireAuthorization("administrator");
        group.MapGet("",async(HttpContext c,BrianiDb db,PermissionService permissions,IndexerAdministration indexers)=>
        {var actor=await LiveAsync(c,db,permissions);var list=await indexers.ListAsync(c.RequestAborted);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);return Results.Ok(list);});
        group.MapPost("",async(IndexerCreateRequest request,HttpContext c,BrianiDb db,PermissionService permissions,IndexerAdministration indexers,Audit audit,WriteGate gate)=>
        {
            var actor=await LiveAsync(c,db,permissions);var created=await UnconfirmedAsync(actor,"indexer.created","",db,audit,gate,c,()=>indexers.CreateAsync(request,Authorize(actor,db,permissions),c.RequestAborted));
            await RecordAsync(actor,"indexer.created",created.Id,db,audit,gate,c);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);
            return Results.Created("/api/v1/admin/indexers/"+created.Id,created);
        });
        group.MapPatch("/{id}",async(string id,IndexerPatchRequest request,HttpContext c,BrianiDb db,PermissionService permissions,IndexerAdministration indexers,Audit audit,WriteGate gate)=>
        {
            var actor=await LiveAsync(c,db,permissions);var parsed=ParseId(id);
            var (updated,changed)=await UnconfirmedAsync(actor,request.Enabled?"indexer.enabled":"indexer.disabled",parsed.ToString(CultureInfo.InvariantCulture),db,audit,gate,c,()=>indexers.SetEnabledAsync(parsed,request.Enabled,Authorize(actor,db,permissions),c.RequestAborted));
            if(changed)await RecordAsync(actor,request.Enabled?"indexer.enabled":"indexer.disabled",updated.Id,db,audit,gate,c);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);
            return Results.Ok(updated);
        });
        group.MapDelete("/{id}",async(string id,HttpContext c,BrianiDb db,PermissionService permissions,IndexerAdministration indexers,Audit audit,WriteGate gate)=>
        {
            var actor=await LiveAsync(c,db,permissions);var parsed=ParseId(id);
            await UnconfirmedAsync(actor,"indexer.deleted",parsed.ToString(CultureInfo.InvariantCulture),db,audit,gate,c,async()=>{await indexers.DeleteAsync(parsed,Authorize(actor,db,permissions),c.RequestAborted);return true;});
            await RecordAsync(actor,"indexer.deleted",parsed.ToString(CultureInfo.InvariantCulture),db,audit,gate,c);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);
            return Results.NoContent();
        });
        group.MapPost("/{id}/test",async(string id,HttpContext c,BrianiDb db,PermissionService permissions,IndexerAdministration indexers)=>
        {var actor=await LiveAsync(c,db,permissions);var result=await indexers.TestAsync(ParseId(id),c.RequestAborted);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);return Results.Ok(result);});
        group.MapGet("/definitions",async(HttpContext c,BrianiDb db,PermissionService permissions,IndexerAdministration indexers)=>
        {var actor=await LiveAsync(c,db,permissions);var list=await indexers.DefinitionsAsync(c.RequestAborted);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);return Results.Ok(list);});
        group.MapGet("/definitions/{key}",async(string key,HttpContext c,BrianiDb db,PermissionService permissions,IndexerAdministration indexers)=>
        {var actor=await LiveAsync(c,db,permissions);var detail=await indexers.DefinitionAsync(key,c.RequestAborted);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);return Results.Ok(detail);});
    }
    private static async Task<Actor> LiveAsync(HttpContext c,BrianiDb db,PermissionService permissions)
    {var actor=Actor.From(c.User);await IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,c.RequestAborted);return actor;}
    // Prowlarr indexer IDs are positive 32-bit integers; anything else is simply not found.
    private static int ParseId(string id)=>id.Length<=10 && int.TryParse(id,NumberStyles.None,CultureInfo.InvariantCulture,out var value) && value>0?value:throw new ApiException(404,"not_found");
    private static Func<CancellationToken,Task> Authorize(Actor actor,BrianiDb db,PermissionService permissions)=>ct=>IntegrationHealth.RequireAdministratorAsync(actor,db,permissions,ct);
    private static async Task<T> UnconfirmedAsync<T>(Actor actor,string action,string id,BrianiDb db,Audit audit,WriteGate gate,HttpContext c,Func<Task<T>> change)
    {
        try{return await change();}
        catch(UnconfirmedIndexerChange){await RecordAsync(actor,action,id,db,audit,gate,c,"unconfirmed");throw new ApiException(504,"indexer_timeout");}
    }
    private static async Task RecordAsync(Actor actor,string action,string id,BrianiDb db,Audit audit,WriteGate gate,HttpContext c,string result="success")
    {using var lease=await gate.EnterAsync(CancellationToken.None);audit.Add(actor.UserId,action,"indexer",id,c.TraceIdentifier,result);await db.SaveChangesAsync(CancellationToken.None);}
}
