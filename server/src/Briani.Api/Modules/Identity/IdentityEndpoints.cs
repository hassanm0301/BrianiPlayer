using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Identity;
public static class IdentityEndpoints
{
    public static void MapIdentity(this WebApplication app)
    {
        var api=app.MapGroup("/api/v1");
        api.MapPost("/bootstrap",async (BootstrapRequest r,HttpContext c,IdentityService identity,WriteGate gate,AuthLimiter limiter,BrianiDb db,SecretStore secrets)=>
        {limiter.Check(c,"bootstrap",limit:5);using var lease=await gate.EnterAsync(c.RequestAborted);await using var tx=await db.Database.BeginTransactionAsync(c.RequestAborted);var result=await identity.BootstrapAsync(r,c.TraceIdentifier,c.RequestAborted);await tx.CommitAsync(c.RequestAborted);secrets.RemoveBootstrap();return Results.Json(result,statusCode:201);}).AllowAnonymous();
        api.MapPost("/auth/login",async (LoginRequest r,HttpContext c,IdentityService identity,WriteGate gate,AuthLimiter limiter)=>
        {limiter.Check(c,"login",r.Username,accountLimit:5);using var lease=await gate.EnterAsync(c.RequestAborted);return Results.Ok(await identity.LoginAsync(r,c.TraceIdentifier,c.RequestAborted));}).AllowAnonymous();
        api.MapPost("/auth/refresh",async (RefreshRequest r,HttpContext c,IdentityService identity,WriteGate gate,AuthLimiter limiter)=>
        {limiter.Check(c,"refresh",limit:30);using var lease=await gate.EnterAsync(c.RequestAborted);return Results.Ok(await identity.RefreshAsync(r.RefreshToken,c.TraceIdentifier,c.RequestAborted));}).AllowAnonymous();
        api.MapPost("/auth/logout",async (HttpContext c,IdentityService identity,WriteGate gate,BrianiDb db,Audit audit)=>
        {var a=Actor.From(c.User);using var lease=await gate.EnterAsync(c.RequestAborted);await identity.CurrentUserAsync(a,c.RequestAborted);await identity.RevokeAsync(a.UserId,a.SessionId,c.RequestAborted);audit.Add(a.UserId,"logout","session",a.SessionId.ToString(),c.TraceIdentifier);await db.SaveChangesAsync(c.RequestAborted);return Results.NoContent();});
        api.MapGet("/me",async (HttpContext c,IdentityService identity)=>Results.Ok(UserView.Of(await identity.CurrentUserAsync(Actor.From(c.User),c.RequestAborted))));
        api.MapPost("/me/password",async (PasswordChange r,HttpContext c,IdentityService identity,WriteGate gate,BrianiDb db,IPasswordHasher<User> hasher,Audit audit,TimeProvider clock,AuthLimiter limiter)=>
        {IdentityInput.Password(r.NewPassword);limiter.Check(c,"password",Actor.From(c.User).UserId.ToString(),5);using var lease=await gate.EnterAsync(c.RequestAborted);var a=Actor.From(c.User);var u=await identity.CurrentUserAsync(a,c.RequestAborted);if(r.CurrentPassword is null || r.CurrentPassword.Length>128 || hasher.VerifyHashedPassword(u,u.PasswordHash,r.CurrentPassword)==PasswordVerificationResult.Failed)throw new ApiException(401,"login_failed");
            await using var tx=await db.Database.BeginTransactionAsync(c.RequestAborted);u.PasswordHash=hasher.HashPassword(u,r.NewPassword);u.MustChangePassword=false;u.Version++;u.UpdatedAt=clock.GetUtcNow();await identity.RevokeAsync(a.UserId,null,c.RequestAborted);audit.Add(a.UserId,"password_change","user",a.UserId.ToString(),c.TraceIdentifier);await db.SaveChangesAsync(c.RequestAborted);await tx.CommitAsync(c.RequestAborted);return Results.NoContent();});
        api.MapGet("/me/sessions",async (HttpContext c,BrianiDb db,TimeProvider clock)=>
        {var a=Actor.From(c.User);var now=clock.GetUtcNow();var list=await db.AuthSessions.AsNoTracking().Where(x=>x.UserId==a.UserId && x.RevokedAt==null && x.RefreshExpiresAt>now).ToListAsync(c.RequestAborted);return Results.Ok(list.Select(x=>new{id=x.Id,deviceName=x.DeviceName,createdAt=x.CreatedAt,lastSeenAt=x.LastSeenAt,expiresAt=x.RefreshExpiresAt,current=x.Id==a.SessionId}));});
        api.MapDelete("/me/sessions/{id:guid}",async (Guid id,HttpContext c,IdentityService identity,BrianiDb db,WriteGate gate,Audit audit)=>
        {var a=Actor.From(c.User);using var lease=await gate.EnterAsync(c.RequestAborted);await identity.CurrentUserAsync(a,c.RequestAborted);if(!await db.AuthSessions.AnyAsync(x=>x.Id==id && x.UserId==a.UserId,c.RequestAborted))throw new ApiException(404,"not_found");await identity.RevokeAsync(a.UserId,id,c.RequestAborted);audit.Add(a.UserId,"session_revoke","session",id.ToString(),c.TraceIdentifier);await db.SaveChangesAsync(c.RequestAborted);return Results.NoContent();});
        api.MapPost("/auth/device-code",async (DeviceCodeRequest r,HttpContext c,IdentityService identity,WriteGate gate,AuthLimiter limiter)=>
        {limiter.Check(c,"pair_start",limit:5);using var lease=await gate.EnterAsync(c.RequestAborted);return Results.Json(await identity.CreatePairAsync(r.DeviceName,c.RequestAborted),statusCode:201);}).AllowAnonymous();
        api.MapPost("/auth/device-code/inspect",async (DeviceCodeApprove r,HttpContext c,IdentityService identity,AuthLimiter limiter)=>
        {limiter.Check(c,"pair_inspect",Actor.From(c.User).UserId.ToString(),5);return Results.Ok(await identity.InspectPairAsync(Actor.From(c.User),r.UserCode,c.RequestAborted));});
        api.MapPost("/auth/device-code/approve",async (DeviceCodeApprove r,HttpContext c,IdentityService identity,WriteGate gate,AuthLimiter limiter)=>
        {limiter.Check(c,"pair_approve",Actor.From(c.User).UserId.ToString(),5);using var lease=await gate.EnterAsync(c.RequestAborted);await identity.ApprovePairAsync(Actor.From(c.User),r.UserCode,c.TraceIdentifier,c.RequestAborted);return Results.NoContent();});
        api.MapPost("/auth/device-code/token",async (DeviceCodePoll r,HttpContext c,IdentityService identity,WriteGate gate,AuthLimiter limiter)=>
        {limiter.Check(c,"pair_poll",limit:60);using var lease=await gate.EnterAsync(c.RequestAborted);var token=await identity.PollPairAsync(r.DeviceSecret,c.TraceIdentifier,c.RequestAborted);return token is null?Results.Json(new{state="pending",retryAfterSeconds=5},statusCode:202):Results.Ok(token);}).AllowAnonymous();
    }
}
