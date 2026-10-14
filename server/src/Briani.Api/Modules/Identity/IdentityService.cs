using System.Security.Cryptography;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Identity;
public sealed class IdentityService(BrianiDb db,IPasswordHasher<User> hasher,TimeProvider clock,Audit audit,SecretStore secrets)
{
    public async Task InitializeBootstrapAsync(bool regenerate=false,CancellationToken ct=default)
    {
        if(await db.Users.AnyAsync(ct)){secrets.RemoveBootstrap();return;}
        var s=await db.Settings.FindAsync(["bootstrap"],ct);
        if(!regenerate && s is not null)return;
        var code=Credentials.NewToken();secrets.WriteBootstrap(code);
        var value=JsonSerializer.Serialize(new BootstrapState(Credentials.Hash(code),clock.GetUtcNow().AddMinutes(30)));
        if(s is null)db.Settings.Add(new(){Key="bootstrap",ValueJson=value,UpdatedAt=clock.GetUtcNow()});else{s.ValueJson=value;s.Version++;s.UpdatedAt=clock.GetUtcNow();}
        await db.SaveChangesAsync(ct);
    }
    private sealed record BootstrapState(string Hash,DateTimeOffset ExpiresAt);
    public async Task<AuthTokens> BootstrapAsync(BootstrapRequest r,string trace,CancellationToken ct)
    {
        IdentityInput.Username(r.Username);IdentityInput.Text(r.DisplayName);IdentityInput.Password(r.Password);
        var s=await db.Settings.FindAsync(["bootstrap"],ct);var code=s is null?null:JsonSerializer.Deserialize<BootstrapState>(s.ValueJson);
        if(r.Code is null || r.Code.Length!=43 || await db.Users.AnyAsync(ct) || code is null || code.ExpiresAt<=clock.GetUtcNow() || !Credentials.EqualHash(code.Hash,Credentials.Hash(r.Code)))throw new ApiException(403,"bootstrap_unavailable");
        var u=new User{Username=r.Username,NormalizedUsername=r.Username.ToUpperInvariant(),DisplayName=r.DisplayName,Role="administrator",CreatedAt=clock.GetUtcNow(),UpdatedAt=clock.GetUtcNow()};u.PasswordHash=hasher.HashPassword(u,r.Password);db.Users.Add(u);db.Settings.Remove(s!);audit.Add(u.Id,"bootstrap","user",u.Id.ToString(),trace);return await IssueAsync(u,"Initial setup",ct);
    }
    public async Task<AuthTokens> LoginAsync(LoginRequest r,string trace,CancellationToken ct)
    {
        if(r.Username is null || r.Username.Length>128 || r.Password is null || r.Password.Length>128)throw new ApiException(401,"login_failed");IdentityInput.Text(r.DeviceName);
        var u=await db.Users.SingleOrDefaultAsync(x=>x.NormalizedUsername==r.Username.ToUpperInvariant(),ct);
        // Dummy verification follows the same framework hash path for absent accounts.
        var dummy=new User();var hashed=u?.PasswordHash??DummyPassword.Hash;
        var result=hasher.VerifyHashedPassword(u??dummy,hashed,r.Password);
        if(u is null || !u.Enabled || result==PasswordVerificationResult.Failed){audit.Add(null,"login","authentication","",trace,"denied");await db.SaveChangesAsync(ct);throw new ApiException(401,"login_failed");}
        if(result==PasswordVerificationResult.SuccessRehashNeeded)u.PasswordHash=hasher.HashPassword(u,r.Password);
        audit.Add(u.Id,"login","user",u.Id.ToString(),trace);return await IssueAsync(u,r.DeviceName,ct);
    }
    private static class DummyPassword { internal static readonly string Hash=new PasswordHasher<User>().HashPassword(new(),Credentials.NewToken()); }
    public async Task<AuthTokens> IssueAsync(User user,string deviceName,CancellationToken ct,AuthSession? session=null)
    {
        var now=clock.GetUtcNow();var refresh=Credentials.NewToken();var access=Credentials.NewToken();
        if(session is null){session=new(){UserId=user.Id,DeviceName=deviceName,CreatedAt=now,RefreshExpiresAt=now.AddDays(30)};db.AuthSessions.Add(session);}
        session.RefreshHash=Credentials.Hash(refresh);session.RefreshGeneration++;session.LastSeenAt=now;
        var expiry=now.AddMinutes(15);if(expiry>session.RefreshExpiresAt)expiry=session.RefreshExpiresAt;
        db.AccessTokens.Add(new(){SessionId=session.Id,TokenHash=Credentials.Hash(access),ExpiresAt=expiry});await db.SaveChangesAsync(ct);
        return new(access,expiry,refresh,session.RefreshExpiresAt,session.Id,UserView.Of(user));
    }
    public async Task<AuthTokens> RefreshAsync(string? token,string trace,CancellationToken ct)
    {
        if(token is null || token.Length!=43)throw new ApiException(401,"session_expired");var hash=Credentials.Hash(token);var now=clock.GetUtcNow();
        var replay=await db.RefreshReplays.FindAsync([hash],ct);if(replay is not null){var old=await db.AuthSessions.FindAsync([replay.SessionId],ct);if(old is not null){old.RevokedAt=now;await db.AccessTokens.Where(x=>x.SessionId==old.Id).ExecuteDeleteAsync(ct);}audit.Add(null,"refresh_replay","session",replay.SessionId.ToString(),trace,"denied");await db.SaveChangesAsync(ct);throw new ApiException(401,"session_expired");}
        var s=await db.AuthSessions.SingleOrDefaultAsync(x=>x.RefreshHash==hash,ct);if(s is null || s.RevokedAt is not null || s.RefreshExpiresAt<=now)throw new ApiException(401,"session_expired");
        var u=await db.Users.SingleAsync(x=>x.Id==s.UserId,ct);if(!u.Enabled)throw new ApiException(401,"session_expired");
        db.RefreshReplays.Add(new(){ConsumedHash=hash,SessionId=s.Id,ExpiresAt=s.RefreshExpiresAt});
        await db.AccessTokens.Where(x=>x.SessionId==s.Id).ExecuteDeleteAsync(ct);
        audit.Add(u.Id,"refresh","session",s.Id.ToString(),trace);return await IssueAsync(u,s.DeviceName,ct,s);
    }
    public async Task RevokeAsync(Guid userId,Guid? sessionId,CancellationToken ct)
    {var now=clock.GetUtcNow();await db.AuthSessions.Where(x=>x.UserId==userId && (sessionId==null || x.Id==sessionId)).ExecuteUpdateAsync(x=>x.SetProperty(s=>s.RevokedAt,now),ct);}
    public async Task<User> CurrentUserAsync(Actor a,CancellationToken ct)
    {var u=await db.Users.SingleOrDefaultAsync(x=>x.Id==a.UserId && x.Enabled,ct);if(u is null || !await db.AuthSessions.AnyAsync(x=>x.Id==a.SessionId && x.UserId==a.UserId && x.RevokedAt==null && x.RefreshExpiresAt>clock.GetUtcNow(),ct))throw new ApiException(401,"session_expired");return u;}
    public async Task<object> CreatePairAsync(string deviceName,CancellationToken ct)
    {
        IdentityInput.Text(deviceName);if(await db.DevicePairings.CountAsync(x=>x.ExpiresAt>clock.GetUtcNow() && x.ConsumedAt==null,ct)>=128)throw new ApiException(429,"rate_limited");
        const string alphabet="ABCDEFGHJKLMNPQRSTUVWXYZ23456789";var code=string.Concat(Enumerable.Range(0,8).Select(_=>alphabet[RandomNumberGenerator.GetInt32(alphabet.Length)]));var secret=Credentials.NewToken();var expires=clock.GetUtcNow().AddMinutes(5);
        db.DevicePairings.Add(new(){DeviceSecretHash=Credentials.Hash(secret),HumanCodeHash=Credentials.Hash(code),DeviceName=deviceName,ExpiresAt=expires});await db.SaveChangesAsync(ct);return new{deviceSecret=secret,userCode=code,expiresAt=expires,pollIntervalSeconds=5};
    }
    public async Task<object> InspectPairAsync(Actor a,string? code,CancellationToken ct)
    {
        await CurrentUserAsync(a,ct);
        if(code is null || code.Length!=8)throw new ApiException(404,"not_found");
        var hash=Credentials.Hash(code.ToUpperInvariant());
        var p=await db.DevicePairings.AsNoTracking().SingleOrDefaultAsync(x=>x.HumanCodeHash==hash,ct);
        if(p is null || p.ExpiresAt<=clock.GetUtcNow() || p.ConsumedAt is not null || p.ApprovedBy is not null)throw new ApiException(404,"not_found");
        return new{deviceName=p.DeviceName,expiresAt=p.ExpiresAt};
    }
    public async Task ApprovePairAsync(Actor a,string? code,string trace,CancellationToken ct)
    {
        await CurrentUserAsync(a,ct);if(code is null || code.Length!=8)throw new ApiException(404,"not_found");var hash=Credentials.Hash(code.ToUpperInvariant());var p=await db.DevicePairings.SingleOrDefaultAsync(x=>x.HumanCodeHash==hash,ct);
        if(p is null || p.ExpiresAt<=clock.GetUtcNow() || p.ConsumedAt is not null || p.ApprovedBy is not null)throw new ApiException(404,"not_found");p.ApprovedBy=a.UserId;p.ApprovedSessionId=a.SessionId;p.ApprovedAt=clock.GetUtcNow();audit.Add(a.UserId,"pair_approved","device",p.Id.ToString(),trace);await db.SaveChangesAsync(ct);
    }
    public async Task<AuthTokens?> PollPairAsync(string? secret,string trace,CancellationToken ct)
    {
        if(secret is null || secret.Length!=43)throw new ApiException(401,"pairing_expired");var hash=Credentials.Hash(secret);var p=await db.DevicePairings.SingleOrDefaultAsync(x=>x.DeviceSecretHash==hash,ct);var now=clock.GetUtcNow();
        if(p is null || p.ExpiresAt<=now || p.ConsumedAt is not null)throw new ApiException(401,"pairing_expired");if(p.LastPolledAt is not null && p.LastPolledAt.Value.AddSeconds(5)>now)throw new ApiException(429,"slow_down");p.LastPolledAt=now;p.PollCount++;if(p.PollCount>60)throw new ApiException(429,"rate_limited");
        if(p.ApprovedBy is null){await db.SaveChangesAsync(ct);return null;}
        var u=await db.Users.SingleOrDefaultAsync(x=>x.Id==p.ApprovedBy && x.Enabled,ct);if(u is null || u.MustChangePassword || !await db.AuthSessions.AnyAsync(x=>x.Id==p.ApprovedSessionId && x.UserId==u.Id && x.RevokedAt==null && x.RefreshExpiresAt>now,ct))throw new ApiException(401,"pairing_expired");p.ConsumedAt=now;audit.Add(u.Id,"pair_exchange","device",p.Id.ToString(),trace);return await IssueAsync(u,p.DeviceName,ct);
    }
}
