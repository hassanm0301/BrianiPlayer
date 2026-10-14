using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.IdentityTests;

public sealed class PermissionBoundaryTests
{
    [Fact]
    public async Task Download_control_distinguishes_ownership_shared_requests_and_destructive_actions()
    {
        var fixture = new IdentityFixture();
        await fixture.InitializeAsync();
        try
        {
            await fixture.Host.InDb(async db =>
            {
                var now = fixture.Host.Clock.GetUtcNow();
                var member = new User { Username = "control", NormalizedUsername = "CONTROL", DisplayName = "Control", CreatedAt = now, UpdatedAt = now };
                var session = new AuthSession { UserId = member.Id, RefreshHash = "control", RefreshExpiresAt = now.AddDays(1), CreatedAt = now, LastSeenAt = now };
                var library = new Library { Name = "Control", RootPath = "control", RootIdentity = "control", CreatedAt = now };
                var grant = new LibraryGrant { UserId = member.Id, LibraryId = library.Id, CanRead = true };
                db.AddRange(member, session, library, grant); await db.SaveChangesAsync();
                using var scope = fixture.Host.Services.CreateScope();
                var permissions = scope.ServiceProvider.GetRequiredService<PermissionService>();
                var actor = new Actor(member.Id, session.Id, "member");
                // Expected decisions are explicit product cases, including manager control of shared requests.
                (bool download, bool manage, bool owner, bool shared, bool destructive, bool allowed)[] cases = [
                    (true, false, true, false, false, true),
                    (true, false, false, false, false, false),
                    (true, false, true, true, false, false),
                    (true, false, true, false, true, false),
                    (true, false, true, true, true, false),
                    (false, false, true, false, false, false),
                    (false, true, false, true, true, true),
                    (false, true, true, false, false, true),
                    (true, true, false, false, true, true)
                ];
                foreach (var c in cases)
                {
                    grant.CanDownload = c.download; grant.CanManage = c.manage; await db.SaveChangesAsync();
                    Func<Task> act = () => permissions.RequireDownloadControlAsync(actor, library.Id, c.owner ? member.Id : fixture.Admin.User.Id, c.shared, c.destructive);
                    if (c.allowed) await act();
                    else Assert.Equal("not_found", (await Assert.ThrowsAsync<ApiException>(act)).Code);
                }
                grant.CanDownload = grant.CanManage = true; library.ReadOnly = true; await db.SaveChangesAsync();
                Assert.Equal(404, (await Assert.ThrowsAsync<ApiException>(() => permissions.RequireDownloadControlAsync(actor, library.Id, member.Id, false))).Status);
                library.ReadOnly = false; grant.CanRead = false; await db.SaveChangesAsync();
                Assert.Equal(404, (await Assert.ThrowsAsync<ApiException>(() => permissions.RequireDownloadControlAsync(actor, library.Id, member.Id, false))).Status);
                return 0;
            });
        }
        finally { await fixture.DisposeAsync(); }
    }

    [Fact]
    public async Task Discovery_requires_at_least_one_live_writable_download_grant()
    {
        var fixture = new IdentityFixture(); await fixture.InitializeAsync();
        try
        {
            await fixture.Host.InDb(async db =>
            {
                var now = fixture.Host.Clock.GetUtcNow();
                var member = new User { Username = "discover", NormalizedUsername = "DISCOVER", DisplayName = "Discover", CreatedAt = now, UpdatedAt = now };
                var session = new AuthSession { UserId = member.Id, RefreshHash = "discover", RefreshExpiresAt = now.AddDays(1), CreatedAt = now, LastSeenAt = now };
                var blocked = new Library { Name = "Read only", RootPath = "readonly", RootIdentity = "readonly", ReadOnly = true, CreatedAt = now };
                var writable = new Library { Name = "Writable", RootPath = "writable", RootIdentity = "writable", CreatedAt = now };
                var grant = new LibraryGrant { UserId = member.Id, LibraryId = writable.Id, CanRead = true };
                db.AddRange(member, session, blocked, writable, grant); await db.SaveChangesAsync();
                using var scope = fixture.Host.Services.CreateScope(); var permissions = scope.ServiceProvider.GetRequiredService<PermissionService>();
                var actor = new Actor(member.Id, session.Id, "member");
                Assert.False(await permissions.CanDiscoverAsync(actor));
                grant.CanDownload = true; await db.SaveChangesAsync(); Assert.True(await permissions.CanDiscoverAsync(actor));
                writable.Online = false; await db.SaveChangesAsync(); Assert.False(await permissions.CanDiscoverAsync(actor));
                writable.Online = true; writable.Enabled = false; await db.SaveChangesAsync(); Assert.False(await permissions.CanDiscoverAsync(actor));
                writable.Enabled = true; writable.ReadOnly = true; await db.SaveChangesAsync(); Assert.False(await permissions.CanDiscoverAsync(actor));
                writable.ReadOnly = false; session.RevokedAt = now; await db.SaveChangesAsync(); Assert.False(await permissions.CanDiscoverAsync(actor));
                session.RevokedAt = null; member.MustChangePassword = true; await db.SaveChangesAsync(); Assert.False(await permissions.CanDiscoverAsync(actor));
                return 0;
            });
        }
        finally { await fixture.DisposeAsync(); }
    }
}
