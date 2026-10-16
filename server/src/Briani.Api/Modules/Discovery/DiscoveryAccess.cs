using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Discovery;
public sealed class DiscoveryAccess(BrianiDb db,PermissionService permissions,SecretStore secrets)
{
    // Discovery needs somewhere to download into, so say which library condition is missing instead of a bare "forbidden".
    public const string NoAdministratorLibrary="Discovery needs a library to download into. In Administration → Libraries, add a library that is not read-only, or make an existing one writable, and check that it is enabled and its disk is online.";
    public const string NoGrantedLibrary="Discovery needs download access to a library. Ask an administrator to grant you download access to a writable library.";
    public async Task<string> RequireAsync(Actor actor,CancellationToken ct=default)
    {
        if(!await permissions.IsSessionValidAsync(actor.SessionId,ct))throw new ApiException(404,"not_found");
        var user=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==actor.UserId && x.Enabled && !x.MustChangePassword,ct)??throw new ApiException(403,"forbidden");
        var sessionOwned=await db.AuthSessions.AsNoTracking().AnyAsync(x=>x.Id==actor.SessionId && x.UserId==actor.UserId,ct);if(!sessionOwned)throw new ApiException(403,"forbidden");
        var libraries=await db.Libraries.AsNoTracking().Where(x=>x.Enabled && x.Online && !x.ReadOnly && (user.Role=="administrator" || db.LibraryGrants.Any(g=>g.LibraryId==x.Id && g.UserId==user.Id && g.CanRead && g.CanDownload))).OrderBy(x=>x.Id).Select(x=>new{x.Id,x.Version}).ToArrayAsync(ct);
        if(libraries.Length==0)throw new ApiException(403,"forbidden",user.Role=="administrator"?NoAdministratorLibrary:NoGrantedLibrary);return secrets.Digest(System.Text.Json.JsonSerializer.Serialize(libraries));
    }
}
