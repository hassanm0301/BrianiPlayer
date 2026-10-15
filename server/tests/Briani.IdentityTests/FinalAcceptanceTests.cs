using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.IdentityTests;

public sealed class FinalAcceptanceTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();

    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Refreshed_access_and_refresh_tokens_are_revoked_when_administrator_disables_account()
    {
        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new
        {
            username = "refreshdisable",
            displayName = "Refresh Disable",
            password = TestPasswords.Initial, confirmPassword = TestPasswords.Initial,
            role = "member"
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var user = (await created.Content.ReadFromJsonAsync<UserReply>())!;

        using var login = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new
        {
            username = user.Username,
            password = TestPasswords.Initial,
            deviceName = "final-acceptance"
        });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var initial = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        using var refreshedResponse = await fixture.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = initial.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refreshedResponse.StatusCode);
        var refreshed = (await refreshedResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        Assert.NotEqual(initial.RefreshToken, refreshed.RefreshToken);

        using var active = IdentityFixture.As(fixture.Host.CreateClient(), refreshed.AccessToken);
        using (var me = await active.GetAsync("/api/v1/me")) Assert.Equal(HttpStatusCode.OK, me.StatusCode);

        using var disabled = await admin.PatchAsJsonAsync($"/api/v1/admin/users/{user.Id}",
            new { version = user.Version, enabled = false });
        Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
        using (var staleAccess = await active.GetAsync("/api/v1/me")) Assert.Equal(HttpStatusCode.Unauthorized, staleAccess.StatusCode);
        using (var staleRefresh = await fixture.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = refreshed.RefreshToken }))
            Assert.Equal(HttpStatusCode.Unauthorized, staleRefresh.StatusCode);

        var revoked = await fixture.Host.InDb(db => db.AuthSessions.AsNoTracking()
            .Where(x => x.Id == refreshed.SessionId).Select(x => x.RevokedAt).SingleAsync());
        Assert.NotNull(revoked);
    }

    [Fact]
    public async Task Download_control_checks_every_grant_combination_and_uses_database_role()
    {
        await fixture.Host.InDb(async db =>
        {
            var now = fixture.Host.Clock.GetUtcNow();
            var user = new User { Username = "controlmatrix", NormalizedUsername = "CONTROLMATRIX", DisplayName = "Control Matrix", Role = "member", CreatedAt = now, UpdatedAt = now };
            var auth = new AuthSession { UserId = user.Id, RefreshHash = "control-matrix", RefreshExpiresAt = now.AddDays(1), CreatedAt = now, LastSeenAt = now };
            var library = new Library { Name = "Control Matrix", RootPath = "control-matrix", RootIdentity = "control-matrix", CreatedAt = now };
            var grant = new LibraryGrant { UserId = user.Id, LibraryId = library.Id };
            db.AddRange(user, auth, library, grant);
            await db.SaveChangesAsync();
            using var scope = fixture.Host.Services.CreateScope();
            var policy = scope.ServiceProvider.GetRequiredService<PermissionService>();
            var shapes = new[] { (owner: true, shared: false, destructive: false), (owner: false, shared: true, destructive: false), (owner: true, shared: false, destructive: true) };
            var cases = 0;
            for (var bits = 0; bits < 8; bits++)
            for (var readOnly = 0; readOnly < 2; readOnly++)
            foreach (var shape in shapes)
            {
                grant.CanRead = (bits & 1) != 0; grant.CanDownload = (bits & 2) != 0; grant.CanManage = (bits & 4) != 0;
                library.ReadOnly = readOnly != 0;
                await db.SaveChangesAsync();
                var allowed = grant.CanRead && !library.ReadOnly &&
                    (grant.CanManage || (grant.CanDownload && shape.owner && !shape.shared && !shape.destructive));
                var targetOwner = shape.owner ? user.Id : fixture.Admin.User.Id;
                foreach (var suppliedRole in new[] { "member", "administrator" })
                {
                    var actor = new Actor(user.Id, auth.Id, suppliedRole);
                    if (allowed) await policy.RequireDownloadControlAsync(actor, library.Id, targetOwner, shape.shared, shape.destructive);
                    else Assert.Equal("not_found", (await Assert.ThrowsAsync<ApiException>(() => policy.RequireDownloadControlAsync(actor, library.Id, targetOwner, shape.shared, shape.destructive))).Code);
                    cases++;
                }
            }
            Assert.Equal(96, cases); // 8 grants × 2 read-only states × 3 controls × 2 claimed roles.
            Assert.Equal("member", await db.Users.Where(x => x.Id == user.Id).Select(x => x.Role).SingleAsync());
            return true;
        });
    }
}
