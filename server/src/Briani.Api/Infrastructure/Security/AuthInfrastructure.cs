using System.Security.Claims;
using System.Text.Encodings.Web;
using Briani.Api.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
namespace Briani.Api.Infrastructure.Security;
public sealed class OpaqueAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options,ILoggerFactory logger,UrlEncoder encoder,BrianiDb db,TimeProvider clock) : AuthenticationHandler<AuthenticationSchemeOptions>(options,logger,encoder)
{
    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var header=Request.Headers.Authorization.ToString();if(!header.StartsWith("Bearer ",StringComparison.Ordinal))return AuthenticateResult.NoResult();
        var token=header[7..];if(token.Length!=43)return AuthenticateResult.Fail("session_expired");var hash=Credentials.Hash(token);
        var now=clock.GetUtcNow(); var match=await (from t in db.AccessTokens.AsNoTracking() join s in db.AuthSessions.AsNoTracking() on t.SessionId equals s.Id join u in db.Users.AsNoTracking() on s.UserId equals u.Id where t.TokenHash==hash && t.ExpiresAt>now && s.RefreshExpiresAt>now && s.RevokedAt==null && u.Enabled select new{u,s}).SingleOrDefaultAsync(Context.RequestAborted);
        if(match is null)return AuthenticateResult.Fail("session_expired");
        var claims=new List<Claim>{new(ClaimTypes.NameIdentifier,match.u.Id.ToString()),new(ClaimTypes.Role,match.u.Role),new("session",match.s.Id.ToString()),new("access_hash",hash)};if(match.u.MustChangePassword)claims.Add(new("password_change","required"));
        return AuthenticateResult.Success(new(new ClaimsPrincipal(new ClaimsIdentity(claims,Scheme.Name)),Scheme.Name));
    }
    protected override Task HandleChallengeAsync(AuthenticationProperties properties)=>Problems.WriteAsync(Context,401,"session_expired");
    protected override Task HandleForbiddenAsync(AuthenticationProperties properties)=>Problems.WriteAsync(Context,403,"forbidden");
}
public static class Problems
{
    public static Task WriteAsync(HttpContext c,int status,string code,string? detail=null,int? retry=null)
    { if(retry is int seconds)c.Response.Headers.RetryAfter=seconds.ToString(System.Globalization.CultureInfo.InvariantCulture);c.Response.ContentLength=null;c.Response.Headers.Remove("ETag");c.Response.Headers.Remove("Content-Disposition");if(status!=416){c.Response.Headers.Remove("Content-Range");c.Response.Headers.Remove("Accept-Ranges");}c.Response.StatusCode=status;return c.Response.WriteAsJsonAsync(new {type="about:blank",title=code.Replace('_',' '),status,code,detail=detail??code.Replace('_',' '),traceId=c.TraceIdentifier,retryAfterSeconds=retry},options:(System.Text.Json.JsonSerializerOptions?)null,contentType:"application/problem+json",cancellationToken:c.RequestAborted); }
}
public sealed class AuthLimiter(TimeProvider clock)
{
    private sealed record Bucket(DateTimeOffset Start,int Count);
    private readonly Dictionary<string,Bucket> buckets=new();private readonly object sync=new();
    public void Check(HttpContext c,string operation,string? account=null,int limit=10,int? accountLimit=null)
    { lock(sync){var now=clock.GetUtcNow();foreach(var k in buckets.Where(x=>x.Value.Start.AddMinutes(1)<=now).Select(x=>x.Key).ToArray())buckets.Remove(k);
        var keys=new List<string>{operation+":ip:"+Credentials.Hash(c.Connection.RemoteIpAddress?.ToString()??"local")};if(account is not null)keys.Add(operation+":account:"+Credentials.Hash(account.ToUpperInvariant()));
        foreach(var key in keys){if(!buckets.TryGetValue(key,out var b)){if(buckets.Count>=4096)throw new ApiException(429,"rate_limited");b=new(now,0);}if(b.Count>=(key.Contains(":account:",StringComparison.Ordinal)?accountLimit??limit:limit))throw new ApiException(429,"rate_limited");buckets[key]=b with{Count=b.Count+1};}
    } }
}
