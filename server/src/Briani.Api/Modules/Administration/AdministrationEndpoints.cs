using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Briani.Api.Modules.Administration;

// Request shapes intentionally mirror the frozen OpenAPI contract. Passwords only
// live in the request and the framework hash; idempotency records contain digests.
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record CreateUserRequest(
    [property: JsonRequired] string Username, [property: JsonRequired] string DisplayName,
    [property: JsonRequired] string Password, [property: JsonRequired] string ConfirmPassword, [property: JsonRequired] string Role);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record PatchUserRequest(string? DisplayName, string? Role, bool? Enabled, [property: JsonRequired] long Version);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record ResetPasswordRequest([property: JsonRequired] string NewPassword, [property: JsonRequired] string ConfirmNewPassword, [property: JsonRequired] long Version);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record LibraryCreateRequest(
    [property: JsonRequired] string Name, string? Description, [property: JsonRequired] Guid StorageRootId,
    [property: JsonRequired] string RelativePath, [property: JsonRequired] bool ReadOnly);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record LibraryPatchRequest(
    string? Name, string? Description, bool? Enabled, bool? ReadOnly, [property: JsonRequired] long Version, int? ScanIntervalSeconds);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record GrantItem(
    [property: JsonRequired] Guid UserId, [property: JsonRequired] bool Read, [property: JsonRequired] bool Download,
    [property: JsonRequired] bool Manage, long? QuotaBytes);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record GrantUpdateRequest(
    [property: JsonRequired] long Version, [property: JsonRequired] IReadOnlyList<GrantItem> Grants);
public sealed record LibraryView(Guid Id, string Name, string Description, bool ReadOnly, bool Enabled, long Version,
    Capabilities Capabilities, [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? RootPath, int? ScanIntervalSeconds);

public static class AdministrationEndpoints
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static WebApplication MapAdministration(this WebApplication app)
    {
        var users = app.MapGroup("/api/v1/admin/users").RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        users.MapGet("", ListUsers);
        users.MapPost("", CreateUser);
        users.MapGet("/{id:guid}", GetUser);
        users.MapPatch("/{id:guid}", PatchUser);
        users.MapDelete("/{id:guid}", DeleteUser);
        users.MapPost("/{id:guid}/reset-password", ResetPassword);

        var storage = app.MapGroup("/api/v1/admin/storage").RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        storage.MapGet("", ListStorageRoots);
        storage.MapGet("/{id:guid}/directories", ListStorageDirectories);

        var libraries = app.MapGroup("/api/v1/libraries").RequireAuthorization();
        libraries.MapGet("", ListLibraries);
        libraries.MapPost("", CreateLibrary).RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        libraries.MapGet("/{id:guid}", GetLibrary);
        libraries.MapPatch("/{id:guid}", PatchLibrary).RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        libraries.MapDelete("/{id:guid}", DeleteLibrary).RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        libraries.MapGet("/{id:guid}/grants", GetGrants).RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        libraries.MapPut("/{id:guid}/grants", SetGrants).RequireAuthorization("administrator").AddEndpointFilter<LiveAdministratorFilter>();
        return app;
    }

    private static async Task<IResult> ListUsers(BrianiDb db, CancellationToken ct) =>
        Results.Ok(await db.Users.AsNoTracking().OrderBy(x => x.Username).Select(x => UserView.Of(x)).ToListAsync(ct));

    private static async Task<IResult> GetUser(Guid id, BrianiDb db, CancellationToken ct) =>
        Results.Ok(UserView.Of(await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound()));

    private static async Task<IResult> CreateUser(HttpContext context, CreateUserRequest request, BrianiDb db,
        WriteGate gate, IPasswordHasher<User> hasher, Audit audit, TimeProvider clock, SecretStore secrets, CancellationToken ct)
    {
        IdentityInput.Username(request.Username); IdentityInput.Password(request.Password, request.ConfirmPassword); IdentityInput.Role(request.Role);
        var display = IdentityInput.Text(request.DisplayName, field: "Display name");
        var normalized = request.Username.ToUpperInvariant();
        var actor = Actor.From(context.User);
        var key = context.Request.Headers["Idempotency-Key"].FirstOrDefault();
        if (key is { Length: > 200 } || (key is not null && (key.Length == 0 || key.Any(char.IsControl)))) throw BadRequest();
        var bodyDigest = secrets.Digest(JsonSerializer.Serialize(request,JsonOptions));
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        if (key is not null)
        {
            var record = await FindIdempotency(db, actor.UserId, "create-user", key, ct);
            if (record is not null)
            {
                if (!DigestEquals(record.RequestDigest, bodyDigest)) throw new ApiException(409, "idempotency_conflict");
                var prior = JsonSerializer.Deserialize<UserView>(record.ResultJson, JsonOptions)!;
                await tx.CommitAsync(ct);
                return Results.Created($"/api/v1/admin/users/{prior.Id}", prior);
            }
        }
        if (await db.Users.AnyAsync(x => x.NormalizedUsername == normalized, ct)) throw new ApiException(409, "username_taken");
        var now = clock.GetUtcNow();
        var user = new User { Username = request.Username, NormalizedUsername = normalized, DisplayName = display,
            Role = request.Role, PasswordHash = "", CreatedAt = now, UpdatedAt = now };
        user.PasswordHash = hasher.HashPassword(user, request.Password);
        db.Users.Add(user);
        audit.Add(actor.UserId, "user.created", "user", user.Id.ToString("D"), context.TraceIdentifier);
        var view = UserView.Of(user);
        if (key is not null) StoreIdempotency(db, actor.UserId, "create-user", key, bodyDigest, JsonSerializer.Serialize(view, JsonOptions), now);
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        return Results.Created($"/api/v1/admin/users/{user.Id}", view);
    }

    private static async Task<IResult> PatchUser(Guid id, PatchUserRequest request, HttpContext context, BrianiDb db,
        WriteGate gate, Audit audit, TimeProvider clock, CancellationToken ct)
    {
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        if (request.Version != user.Version) throw Conflict();
        if (request.DisplayName is not null) user.DisplayName = IdentityInput.Text(request.DisplayName, field: "Display name");
        if (request.Role is not null) { IdentityInput.Role(request.Role); user.Role = request.Role; }
        if (request.Enabled is not null) user.Enabled = request.Enabled.Value;
        await EnsureEnabledAdminRemains(db, user, ct);
        user.Version++; user.UpdatedAt = clock.GetUtcNow();
        if (!user.Enabled) await RevokeSessions(db, id, clock.GetUtcNow(), ct);
        audit.Add(Actor.From(context.User).UserId, "user.updated", "user", id.ToString("D"), context.TraceIdentifier);
        await db.SaveChangesAsync(ct); return Results.Ok(UserView.Of(user));
    }

    private static async Task<IResult> DeleteUser(Guid id, long? version, HttpContext context, BrianiDb db,
        WriteGate gate, Audit audit, TimeProvider clock, CancellationToken ct)
    {
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        if (version is not null && version != user.Version) throw Conflict();
        user.Enabled = false; user.Version++; user.UpdatedAt = clock.GetUtcNow();
        await EnsureEnabledAdminRemains(db, user, ct);
        await RevokeSessions(db, id, clock.GetUtcNow(), ct);
        audit.Add(Actor.From(context.User).UserId, "user.disabled", "user", id.ToString("D"), context.TraceIdentifier);
        await db.SaveChangesAsync(ct); return Results.NoContent();
    }

    private static async Task<IResult> ResetPassword(Guid id, ResetPasswordRequest request, HttpContext context, BrianiDb db,
        WriteGate gate, IPasswordHasher<User> hasher, Audit audit, TimeProvider clock, CancellationToken ct)
    {
        IdentityInput.Password(request.NewPassword, request.ConfirmNewPassword);
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        if (request.Version != user.Version) throw Conflict();
        user.PasswordHash = hasher.HashPassword(user, request.NewPassword); user.MustChangePassword = true;
        user.Version++; user.UpdatedAt = clock.GetUtcNow();
        await RevokeSessions(db, id, clock.GetUtcNow(), ct);
        audit.Add(Actor.From(context.User).UserId, "user.password_reset", "user", id.ToString("D"), context.TraceIdentifier);
        await db.SaveChangesAsync(ct); return Results.NoContent();
    }

    private static async Task<IResult> ListLibraries(HttpContext context, BrianiDb db, PermissionService permissions, CancellationToken ct)
    {
        var actor = Actor.From(context.User); var result = new List<LibraryView>();
        foreach (var lib in await db.Libraries.AsNoTracking().OrderBy(x => x.Name).ToListAsync(ct))
        {
            var caps = await permissions.CapabilitiesAsync(actor, lib, ct);
            if (caps.Read) result.Add(View(lib, caps, actor.IsAdministrator ? lib.RootPath : null));
        }
        return Results.Ok(result);
    }

    private static async Task<IResult> GetLibrary(Guid id, HttpContext context, BrianiDb db, PermissionService permissions, CancellationToken ct)
    {
        var actor = Actor.From(context.User); var lib = await permissions.RequireLibraryAsync(actor, id, "read", ct);
        return Results.Ok(View(lib, await permissions.CapabilitiesAsync(actor, lib, ct), actor.IsAdministrator ? lib.RootPath : null));
    }

    private static async Task<IResult> CreateLibrary(HttpContext context, LibraryCreateRequest request, BrianiDb db,
        WriteGate gate, Audit audit, TimeProvider clock, SecretStore secrets, CancellationToken ct)
    {
        IdentityInput.Text(request.Name, field: "Library name");
        if (request.Description?.Length > 2000) throw BadRequest("Library description must be at most 2000 characters.");
        IdentityInput.Text(request.RelativePath, 4096, field: "Library folder");
        var actor = Actor.From(context.User); var key = context.Request.Headers["Idempotency-Key"].FirstOrDefault();
        if (key is { Length: > 200 } || (key is not null && (key.Length == 0 || key.Any(char.IsControl)))) throw BadRequest();
        var digest = secrets.Digest(JsonSerializer.Serialize(request,JsonOptions));
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        if (key is not null)
        {
            var record = await FindIdempotency(db, actor.UserId, "create-library", key, ct);
            if (record is not null)
            {
                if (!DigestEquals(record.RequestDigest, digest)) throw new ApiException(409, "idempotency_conflict");
                var prior = JsonSerializer.Deserialize<LibraryView>(record.ResultJson, JsonOptions)!;
                await tx.CommitAsync(ct); return Results.Created($"/api/v1/libraries/{prior.Id}", prior);
            }
        }
        // Storage identity resolution and overlap checks are performed by the contained-storage owner.
        var storage = context.RequestServices.GetRequiredService<ContainedStorage>();
        if (!Guid.TryParse(storage.RootId, out var rootId) || request.StorageRootId != rootId) throw NotFound();
        var contained = storage.ValidateLibraryRoot(request.RelativePath);
        var existing = await db.Libraries.AsNoTracking().ToListAsync(ct);
        if (storage.Overlaps(contained, existing.Select(x => (Path: x.RootPath, Identity: x.RootIdentity)))) throw new ApiException(409, "library_roots_overlap");
        var lib = new Library { Name = request.Name.Trim(), Description = request.Description ?? "", RootPath = contained.RelativePath,
            RootIdentity = contained.Identity, ReadOnly = request.ReadOnly, CreatedAt = clock.GetUtcNow() };
        db.Libraries.Add(lib); audit.Add(actor.UserId, "library.created", "library", lib.Id.ToString("D"), context.TraceIdentifier);
        var result = View(lib, new(true, !lib.ReadOnly, !lib.ReadOnly), lib.RootPath);
        if (key is not null) StoreIdempotency(db, actor.UserId, "create-library", key, digest, JsonSerializer.Serialize(result, JsonOptions), clock.GetUtcNow());
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return Results.Created($"/api/v1/libraries/{lib.Id}", result);
    }

    private static async Task<IResult> PatchLibrary(Guid id, LibraryPatchRequest request, HttpContext context, BrianiDb db,
        WriteGate gate, Audit audit, TimeProvider clock, CancellationToken ct)
    {
        var lib = await db.Libraries.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        if (request.Version != lib.Version) throw Conflict();
        if (request.Name is not null) { IdentityInput.Text(request.Name, field: "Library name"); lib.Name = request.Name.Trim(); }
        if (request.Description is not null) { if (request.Description.Length > 2000) throw BadRequest("Library description must be at most 2000 characters."); lib.Description = request.Description; }
        if (request.Enabled is not null) lib.Enabled = request.Enabled.Value;
        if (request.ReadOnly is not null) lib.ReadOnly = request.ReadOnly.Value;
        if (request.ScanIntervalSeconds is not null && request.ScanIntervalSeconds < 60) throw BadRequest("The scan interval must be at least 60 seconds.");
        lib.ScanIntervalSeconds = request.ScanIntervalSeconds; lib.Version++;
        audit.Add(Actor.From(context.User).UserId, "library.updated", "library", id.ToString("D"), context.TraceIdentifier);
        await db.SaveChangesAsync(ct); return Results.Ok(View(lib, new(true, !lib.ReadOnly, !lib.ReadOnly), lib.RootPath));
    }

    private static async Task<IResult> DeleteLibrary(Guid id, long? version, HttpContext context, BrianiDb db,
        WriteGate gate, Audit audit, Briani.Api.Modules.Playback.MediaReaders readers, TimeProvider clock, CancellationToken ct)
    {
        var lib = await db.Libraries.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        if (version is not null && version != lib.Version) throw Conflict();
        if(await db.DownloadRequests.AnyAsync(x=>x.LibraryId==id && x.RemovedAt==null,ct) || await db.TorrentJobs.AnyAsync(x=>x.LibraryId==id && x.RetiredAt==null,ct))throw new ApiException(409,"library_has_downloads");
        var active=readers.ActiveMediaIds();
        if(await db.MediaItems.AnyAsync(x=>x.LibraryId==id && active.Contains(x.Id),ct) || await db.Operations.AnyAsync(x=>db.MediaItems.Any(m=>m.LibraryId==id && m.Id==x.TargetId) && (x.State=="pending" || x.State=="running"),ct))throw new ApiException(409,"library_in_use");
        await using var transaction=await db.Database.BeginTransactionAsync(ct);
        await db.PlaybackSessions.Where(x=>x.MediaItemId!=null && db.MediaItems.Any(m=>m.Id==x.MediaItemId && m.LibraryId==id)).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.MediaItemId,(Guid?)null).SetProperty(x=>x.RevokedAt,clock.GetUtcNow()),ct);
        var retiredIds=await db.TorrentJobs.Where(x=>x.LibraryId==id).Select(x=>x.Id).ToArrayAsync(ct);
        var requestIds=await db.DownloadRequests.Where(x=>x.LibraryId==id).Select(x=>x.Id).ToArrayAsync(ct);
        var fileIds=await db.DownloadFiles.Where(x=>retiredIds.Contains(x.TorrentJobId)).Select(x=>x.Id).ToArrayAsync(ct);
        await db.PlaybackSessions.Where(x=>fileIds.Contains(x.DownloadFileId??Guid.Empty)).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.DownloadFileId,(Guid?)null).SetProperty(x=>x.RevokedAt,clock.GetUtcNow()),ct);
        await db.Operations.Where(x=>requestIds.Contains(x.TargetId) || fileIds.Contains(x.TargetId)).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.State,"failed").SetProperty(x=>x.ErrorCode,"library_removed"),ct);
        await db.DownloadOwnerships.Where(x=>x.LibraryId==id).ExecuteDeleteAsync(ct);
        await db.DownloadRequestFiles.Where(x=>requestIds.Contains(x.DownloadRequestId)).ExecuteDeleteAsync(ct);
        await db.DownloadRequests.Where(x=>x.LibraryId==id).ExecuteDeleteAsync(ct);
        await db.DownloadFiles.Where(x=>retiredIds.Contains(x.TorrentJobId)).ExecuteDeleteAsync(ct);
        await db.TorrentJobs.Where(x=>x.LibraryId==id).ExecuteDeleteAsync(ct);
        await db.MediaItems.Where(x=>x.LibraryId==id).ExecuteDeleteAsync(ct);
        await db.Jobs.Where(x=>x.TargetId==id && x.Kind=="scan" && (x.State=="queued" || x.State=="running")).ExecuteUpdateAsync(b=>b.SetProperty(x=>x.State,"cancelled").SetProperty(x=>x.DedupKey,(string?)null).SetProperty(x=>x.LeaseOwner,(string?)null).SetProperty(x=>x.LeaseUntil,(DateTimeOffset?)null),ct);
        db.LibraryGrants.RemoveRange(await db.LibraryGrants.Where(x => x.LibraryId == id).ToListAsync(ct));
        db.Libraries.Remove(lib);
        audit.Add(Actor.From(context.User).UserId, "library.removed", "library", id.ToString("D"), context.TraceIdentifier);
        await db.SaveChangesAsync(ct); await transaction.CommitAsync(ct);return Results.NoContent();
    }

    private static async Task<IResult> GetGrants(Guid id, BrianiDb db, CancellationToken ct)
    {
        var library = await db.Libraries.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        var grants = await db.LibraryGrants.AsNoTracking().Where(x => x.LibraryId == id).OrderBy(x => x.UserId)
            .Select(x => new GrantItem(x.UserId, x.CanRead, x.CanDownload, x.CanManage, x.QuotaBytes)).ToListAsync(ct);
        return Results.Ok(new { version = library.Version, grants });
    }

    private static async Task<IResult> SetGrants(Guid id, GrantUpdateRequest request, HttpContext context, BrianiDb db,
        WriteGate gate, Audit audit, CancellationToken ct)
    {
        if (request.Grants is null || request.Grants.Count > 1000 || request.Grants.Any(x => x is null)) throw BadRequest("Provide at most 1000 access grants.");
        if (request.Grants.Select(x => x.UserId).Distinct().Count() != request.Grants.Count) throw BadRequest("Each user can only appear once in the access list.");
        if (request.Grants.Any(x => (x.Download || x.Manage) && !x.Read || x.QuotaBytes < 0)) throw BadRequest("Download and manage access also need read access, and quotas cannot be negative.");
        var lib = await db.Libraries.SingleOrDefaultAsync(x => x.Id == id, ct) ?? throw NotFound();
        if (request.Version != lib.Version) throw Conflict();
        var users = request.Grants.Select(x => x.UserId).ToArray();
        if (await db.Users.CountAsync(x => users.Contains(x.Id) && x.Enabled, ct) != users.Distinct().Count()) throw BadRequest("Access can only be granted to existing, enabled users.");
        var existing = await db.LibraryGrants.Where(x => x.LibraryId == id).ToDictionaryAsync(x => x.UserId, ct);
        foreach(var old in existing.Values.Where(x => !users.Contains(x.UserId))) db.LibraryGrants.Remove(old);
        foreach (var grant in request.Grants) {
            if(!existing.TryGetValue(grant.UserId,out var row)) { row=new LibraryGrant {LibraryId=id,UserId=grant.UserId};db.LibraryGrants.Add(row); }
            row.CanRead=grant.Read;row.CanDownload=grant.Download;row.CanManage=grant.Manage;row.QuotaBytes=grant.QuotaBytes;
        }
        lib.Version++;
        audit.Add(Actor.From(context.User).UserId, "library.grants_updated", "library", id.ToString("D"), context.TraceIdentifier);
        await db.SaveChangesAsync(ct);
        return Results.Ok(new { version = lib.Version, grants = request.Grants });
    }

    private static async Task<IResult> ListStorageRoots(ContainedStorage storage, BrianiDb db, CancellationToken ct)
    {
        var path = storage.RootPath;
        long? free=null,total=null;bool ready=false,writable=false;
        try{var volume=storage.Volume();free=volume.FreeBytes;total=volume.TotalBytes;writable=volume.Writable;ready=true;}catch(ApiException){}
        var id = Guid.Parse(storage.RootId);
        return Results.Ok(new[] { new { id, label = "Mounted media storage", path, writable,
            freeBytes = free, totalBytes = total, reservedBytes = 0L, available = ready, supportsHardLinks = (bool?)null } });
    }

    private static async Task<IResult> ListStorageDirectories(Guid id, string? relativePath, ContainedStorage storage,BrianiDb db,CancellationToken ct)
    {
        if (!Guid.TryParse(storage.RootId, out var rootId) || id != rootId) throw NotFound();
        var directories = storage.DescribeDirectories(relativePath ?? "");
        var assigned=await db.Libraries.AsNoTracking().ToListAsync(ct);
        return Results.Ok(directories.Select(d=>d with{AlreadyAssigned=storage.Overlaps(storage.ValidateLibraryRoot(d.RelativePath),assigned.Select(l=>(l.RootPath,l.RootIdentity)))}));
    }

    private static LibraryView View(Library x, Capabilities c, string? root) => new(x.Id, x.Name, x.Description, x.ReadOnly, x.Enabled, x.Version, c, root, x.ScanIntervalSeconds);
    private static ApiException NotFound() => new(404, "not_found");
    private static ApiException BadRequest(string? detail = null) => new(400, "validation_failed", detail);
    private static ApiException Conflict() => new(409, "version_conflict");
    private sealed record IdempotencyValue(string RequestDigest, string ResultJson);
    private static string IdemKey(Guid actor, string op, string key) => $"admin-idem:{actor:N}:{op}:{Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(key)))}";
    private static bool DigestEquals(string left, string right) => CryptographicOperations.FixedTimeEquals(Convert.FromHexString(left), Convert.FromHexString(right));
    private static async Task<IdempotencyValue?> FindIdempotency(BrianiDb db, Guid actor, string op, string key, CancellationToken ct)
    {
        var row = await db.Settings.AsNoTracking().SingleOrDefaultAsync(x => x.Key == IdemKey(actor, op, key), ct);
        return row is null ? null : JsonSerializer.Deserialize<IdempotencyValue>(row.ValueJson, JsonOptions);
    }
    private static void StoreIdempotency(BrianiDb db, Guid actor, string op, string key, string digest, string result, DateTimeOffset now) =>
        db.Settings.Add(new Setting { Key = IdemKey(actor, op, key), ValueJson = JsonSerializer.Serialize(new IdempotencyValue(digest, result), JsonOptions), UpdatedAt = now });
    private static async Task RevokeSessions(BrianiDb db, Guid userId, DateTimeOffset now, CancellationToken ct)
    {
        var sessions = await db.AuthSessions.Where(x => x.UserId == userId && x.RevokedAt == null).ToListAsync(ct);
        foreach (var session in sessions) session.RevokedAt = now;
        var ids = sessions.Select(x => x.Id).ToArray();
        db.AccessTokens.RemoveRange(await db.AccessTokens.Where(x => ids.Contains(x.SessionId)).ToListAsync(ct));
    }
    private static async Task EnsureEnabledAdminRemains(BrianiDb db, User changed, CancellationToken ct)
    {
        if (changed.Enabled && changed.Role == "administrator") return;
        if (await db.Users.CountAsync(x => x.Enabled && x.Role == "administrator" && x.Id != changed.Id, ct) == 0)
            throw new ApiException(409, "last_enabled_administrator");
    }
}

public sealed class LiveAdministratorFilter(WriteGate gate, BrianiDb db, TimeProvider clock) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        var actor = Actor.From(http.User);
        using var lease = await gate.EnterAsync(http.RequestAborted);
        var now = clock.GetUtcNow();
        var valid = await (from user in db.Users join session in db.AuthSessions on user.Id equals session.UserId
                           where user.Id == actor.UserId && user.Enabled && user.Role == "administrator"
                           && session.Id == actor.SessionId && session.RevokedAt == null && session.RefreshExpiresAt > now
                           select user.Id).AnyAsync(http.RequestAborted);
        if (!valid) throw new ApiException(403, "forbidden");
        return await next(context);
    }
}
