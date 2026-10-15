using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Infrastructure.Security;
public sealed class ApiException(int status,string code,string? detail=null,int? retryAfterSeconds=null) : Exception(code)
{ public int Status { get; }=status; public string Code { get; }=code; public string SafeDetail { get; }=detail ?? ErrorMessages.For(code); public int? RetryAfterSeconds {get;}=retryAfterSeconds; }
public static class IdentityInput
{
    public static void Username(string? value) { if(value is null || !Regex.IsMatch(value,"\\A[A-Za-z0-9._-]{3,64}\\z")) throw new ApiException(400,"validation_failed","Usernames must be 3–64 characters using only letters, numbers, dots, underscores or hyphens."); }
    // Passwords have no content rules; only presence and the confirmation match are checked.
    public static void Password(string? value) { if(value is null) throw new ApiException(400,"validation_failed","Enter a password."); }
    public static void Password(string? value,string? confirmation) { Password(value); if(!string.Equals(value,confirmation,StringComparison.Ordinal)) throw new ApiException(400,"password_mismatch"); }
    public static string Text(string? value,int max=200,bool required=true,string field="This value") {
        if(value is null || (required && string.IsNullOrWhiteSpace(value))) throw new ApiException(400,"validation_failed",$"{field} is required.");
        if(value.Length>max) throw new ApiException(400,"validation_failed",$"{field} must be at most {max} characters.");
        if(value.Any(char.IsControl)) throw new ApiException(400,"validation_failed",$"{field} cannot contain control characters.");
        return value; }
    public static void Role(string? role) { if(role is not ("administrator" or "member")) throw new ApiException(400,"validation_failed","The role must be administrator or member."); }
}
public static class Credentials
{
    public static string NewToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+','-').Replace('/','_');
    public static string Hash(string? token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token ?? "")));
    public static bool EqualHash(string left,string right) => CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(left),Encoding.ASCII.GetBytes(right));
}
public sealed class WriteGate
{
    private readonly SemaphoreSlim gate=new(1,1);
    public async Task<IDisposable> EnterAsync(CancellationToken ct=default) { await gate.WaitAsync(ct); return new Lease(gate); }
    private sealed class Lease(SemaphoreSlim gate):IDisposable { public void Dispose()=>gate.Release(); }
}
public sealed record Actor(Guid UserId,Guid SessionId,string Role,bool MustChangePassword=false,string? AccessTokenHash=null)
{
    public bool IsAdministrator=>Role=="administrator";
    public static Actor From(ClaimsPrincipal p)=>new(Guid.Parse(p.FindFirstValue(ClaimTypes.NameIdentifier)!),Guid.Parse(p.FindFirstValue("session")!),p.FindFirstValue(ClaimTypes.Role)!,p.HasClaim("password_change","required"),p.FindFirstValue("access_hash"));
}
public sealed record Capabilities(bool Read,bool Download,bool Manage);
public sealed class PermissionService(BrianiDb db,TimeProvider clock)
{
    public async Task<bool> IsSessionValidAsync(Guid sessionId,CancellationToken ct=default)=> await (from s in db.AuthSessions join u in db.Users on s.UserId equals u.Id where s.Id==sessionId && s.RevokedAt==null && s.RefreshExpiresAt>clock.GetUtcNow() && u.Enabled select s.Id).AnyAsync(ct);
    public async Task<bool> IsAccessValidAsync(Actor actor,CancellationToken ct=default) => actor.AccessTokenHash is not null && await db.AccessTokens.AsNoTracking().AnyAsync(x=>x.TokenHash==actor.AccessTokenHash && x.SessionId==actor.SessionId && x.ExpiresAt>clock.GetUtcNow(),ct) && await IsSessionValidAsync(actor.SessionId,ct);
    public async Task<Capabilities> CapabilitiesAsync(Actor actor,Library l,CancellationToken ct=default)
    {
        var live=await db.Libraries.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==l.Id,ct);if(live is null)return new(false,false,false);l=live;
        if(!l.Enabled || !l.Online || !await db.AuthSessions.AsNoTracking().AnyAsync(x=>x.Id==actor.SessionId && x.UserId==actor.UserId && x.RevokedAt==null && x.RefreshExpiresAt>clock.GetUtcNow(),ct))return new(false,false,false);
        var user=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==actor.UserId && x.Enabled,ct);
        if(user is null || user.MustChangePassword)return new(false,false,false);
        if(user.Role=="administrator")return new(true,!l.ReadOnly,!l.ReadOnly);
        var g=await db.LibraryGrants.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==actor.UserId && x.LibraryId==l.Id,ct);
        return new(g?.CanRead==true,g?.CanRead==true && g.CanDownload && !l.ReadOnly,g?.CanRead==true && g.CanManage && !l.ReadOnly);
    }
    public async Task<Library> RequireLibraryAsync(Actor actor,Guid id,string capability="read",CancellationToken ct=default)
    { var l=await db.Libraries.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==id,ct) ?? throw new ApiException(404,"not_found"); var c=await CapabilitiesAsync(actor,l,ct); if(!(capability switch{"read"=>c.Read,"download"=>c.Download,"manage"=>c.Manage,_=>false}))throw new ApiException(404,"not_found"); return l; }
    public async Task<bool> CanDiscoverAsync(Actor a,CancellationToken ct=default) { foreach(var l in await db.Libraries.AsNoTracking().Where(x=>x.Enabled && x.Online && !x.ReadOnly).ToListAsync(ct)) if((await CapabilitiesAsync(a,l,ct)).Download)return true;return false; }
    public async Task RequireDownloadControlAsync(Actor a,Guid libraryId,Guid ownerId,bool shared,bool destructive=false,CancellationToken ct=default)
    { var l=await RequireLibraryAsync(a,libraryId,"read",ct);var c=await CapabilitiesAsync(a,l,ct); if(!(c.Manage || (!shared && !destructive && ownerId==a.UserId && c.Download)))throw new ApiException(404,"not_found"); }
}
public sealed class Audit(BrianiDb db,TimeProvider clock)
{ public void Add(Guid? actor,string action,string targetType,string targetId,string trace="",string result="success")=>db.AuditEvents.Add(new(){ActorId=actor,Action=action,TargetType=targetType,TargetId=targetId,TraceId=trace,Result=result,CreatedAt=clock.GetUtcNow()}); }
