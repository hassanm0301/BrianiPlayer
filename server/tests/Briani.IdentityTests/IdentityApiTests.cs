using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Administration;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace Briani.IdentityTests;

public sealed class IdentityApiTests : IAsyncLifetime
{
    private readonly IdentityFixture f = new();
    public Task InitializeAsync() => f.InitializeAsync();
    public Task DisposeAsync() => f.DisposeAsync();

    [Fact]
    public async Task Bootstrap_is_one_time_and_competing_claims_have_single_winner()
    {
        using var host = new TestHost();
        using var initial = host.CreateClient();
        var code = host.BootstrapCode();
        var calls = Enumerable.Range(0, 2).Select(async i =>
        {
            using var client = host.CreateClient();
            return await client.PostAsJsonAsync("/api/v1/bootstrap", new { code, username = $"winner{i}", displayName = "Winner", password = TestPasswords.BootstrapRace });
        }).ToArray();
        var results = await Task.WhenAll(calls);
        Assert.Single(results, x => x.StatusCode == HttpStatusCode.Created);
        Assert.Single(results, x => x.StatusCode == HttpStatusCode.Forbidden);
        Assert.False(File.Exists(Path.Combine(host.Root, "state", "bootstrap.code")));
    }

    [Fact]
    public async Task Last_enabled_administrator_is_protected_and_members_cannot_administer()
    {
        var admin = IdentityFixture.As(f.Client, f.Admin.AccessToken);
        var demote = await admin.PatchAsJsonAsync($"/api/v1/admin/users/{f.Admin.User.Id}", new { version = f.Admin.User.Version, role = "member" });
        Assert.Equal(HttpStatusCode.Conflict, demote.StatusCode);
        Assert.Equal("last_enabled_administrator", await Code(demote));
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "member1", displayName = "Member", password = TestPasswords.Member, role = "member" });
        created.EnsureSuccessStatusCode();
        var member = (await created.Content.ReadFromJsonAsync<UserReply>())!;
        var login = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "member1", password = TestPasswords.Member, deviceName = "test" });
        var tokens = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        IdentityFixture.As(f.Client, tokens.AccessToken);
        var users = await f.Client.GetAsync("/api/v1/admin/users");
        Assert.Equal(HttpStatusCode.Forbidden, users.StatusCode);
        Assert.Equal("member", member.Role);
    }

    [Fact]
    public async Task Validation_rejects_unknown_json_and_missing_fields()
    {
        var unknown = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "nobody", password = TestPasswords.Wrong, deviceName = "test", extra = true });
        Assert.Equal(HttpStatusCode.BadRequest, unknown.StatusCode);
        var missing = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "nobody" });
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        var shortPassword = await f.Client.PostAsJsonAsync("/api/v1/bootstrap", new { code = "bad", username = "newuser", displayName = "New", password = new string('x', 5) });
        Assert.Equal(HttpStatusCode.BadRequest, shortPassword.StatusCode);
    }

    [Fact]
    public async Task Refresh_rotation_replay_revokes_session_and_tokens_are_hashed_at_rest()
    {
        var raw = f.Admin.RefreshToken;
        var rotatedResponse = await f.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = raw });
        rotatedResponse.EnsureSuccessStatusCode();
        var rotated = (await rotatedResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        Assert.NotEqual(raw, rotated.RefreshToken);
        var replay = await f.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = raw });
        Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
        Assert.Equal("session_expired", await Code(replay));
        Assert.Equal(0, await f.Host.InDb(db => db.AccessTokens.CountAsync(x => x.SessionId == rotated.SessionId)));
        var dbRows = await f.Host.InDb(async db => new
        {
            access = await db.AccessTokens.Select(x => x.TokenHash).ToListAsync(),
            refresh = await db.AuthSessions.Select(x => x.RefreshHash).ToListAsync(),
            replay = await db.RefreshReplays.Select(x => x.ConsumedHash).ToListAsync()
        });
        Assert.DoesNotContain(dbRows.access, x => x == rotated.AccessToken || x == f.Admin.AccessToken);
        Assert.DoesNotContain(dbRows.refresh, x => x == rotated.RefreshToken || x == raw);
        Assert.DoesNotContain(dbRows.replay, x => x == raw);
    }

    [Fact]
    public async Task Clock_expiry_is_utc_and_refresh_has_absolute_lifetime()
    {
        Assert.Equal(TimeSpan.FromMinutes(15), f.Admin.AccessExpiresAt - f.Host.Clock.GetUtcNow());
        Assert.Equal(TimeSpan.FromDays(30), f.Admin.RefreshExpiresAt - f.Host.Clock.GetUtcNow());
        Assert.Equal(TimeSpan.Zero, f.Admin.AccessExpiresAt.Offset);
        var actor = new Actor(f.Admin.User.Id, f.Admin.SessionId, "administrator", false, Credentials.Hash(f.Admin.AccessToken));
        Assert.True(await f.Host.Services.CreateAsyncScope().Use(scope => scope.ServiceProvider.GetRequiredService<PermissionService>().IsAccessValidAsync(actor)));
        f.Host.Clock.Advance(TimeSpan.FromMinutes(15));
        Assert.False(await f.Host.Services.CreateAsyncScope().Use(scope => scope.ServiceProvider.GetRequiredService<PermissionService>().IsAccessValidAsync(actor)));
        var refresh = await f.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = f.Admin.RefreshToken });
        refresh.EnsureSuccessStatusCode();
        var renewed = (await refresh.Content.ReadFromJsonAsync<AuthReply>())!;
        Assert.Equal(f.Admin.RefreshExpiresAt, renewed.RefreshExpiresAt);
        Assert.Equal(TimeSpan.FromMinutes(15), renewed.AccessExpiresAt - f.Host.Clock.GetUtcNow());
        f.Host.Clock.Advance(TimeSpan.FromDays(30));
        Assert.Equal(HttpStatusCode.Unauthorized, (await f.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = renewed.RefreshToken })).StatusCode);
    }

    [Fact]
    public async Task Password_change_revokes_all_sessions_and_logout_revokes_current_session()
    {
        var secondLogin = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "rootuser", password = TestPasswords.Root, deviceName = "second" });
        var second = (await secondLogin.Content.ReadFromJsonAsync<AuthReply>())!;
        IdentityFixture.As(f.Client, f.Admin.AccessToken);
        var changed = await f.Client.PostAsJsonAsync("/api/v1/me/password", new { currentPassword = TestPasswords.Root, newPassword = TestPasswords.Replacement });
        Assert.Equal(HttpStatusCode.NoContent, changed.StatusCode);
        var oldAccess = await f.Client.GetAsync("/api/v1/me");
        Assert.Equal(HttpStatusCode.Unauthorized, oldAccess.StatusCode);
        Assert.Equal(2, await f.Host.InDb(db => db.AuthSessions.CountAsync(s => s.RevokedAt != null)));
        var login = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "rootuser", password = TestPasswords.Replacement, deviceName = "new" });
        var fresh = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        IdentityFixture.As(f.Client, fresh.AccessToken);
        Assert.Equal(HttpStatusCode.NoContent, (await f.Client.PostAsync("/api/v1/auth/logout", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await f.Client.GetAsync("/api/v1/me")).StatusCode);
        Assert.NotEqual(second.SessionId, fresh.SessionId);
    }

    [Fact]
    public async Task Administrator_password_reset_and_disable_revoke_user_sessions()
    {
        var admin = IdentityFixture.As(f.Client, f.Admin.AccessToken);
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "resetuser", displayName = "Reset User", password = TestPasswords.Initial, role = "member" });
        var user = (await created.Content.ReadFromJsonAsync<UserReply>())!;
        var login = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "resetuser", password = TestPasswords.Initial, deviceName = "tablet" });
        var original = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        using var reset = await admin.PostAsJsonAsync($"/api/v1/admin/users/{user.Id}/reset-password", new { newPassword = TestPasswords.Reset, version = user.Version });
        Assert.Equal(HttpStatusCode.NoContent, reset.StatusCode);
        using var stale = f.Host.CreateClient();
        IdentityFixture.As(stale, original.AccessToken);
        Assert.Equal(HttpStatusCode.Unauthorized, (await stale.GetAsync("/api/v1/me")).StatusCode);
        var oldPassword = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "resetuser", password = TestPasswords.Initial, deviceName = "tablet" });
        Assert.Equal(HttpStatusCode.Unauthorized, oldPassword.StatusCode);
        var changedPassword = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "resetuser", password = TestPasswords.Reset, deviceName = "tablet" });
        var afterReset = (await changedPassword.Content.ReadFromJsonAsync<AuthReply>())!;
        using var disabled = await admin.PatchAsJsonAsync($"/api/v1/admin/users/{user.Id}", new { version = user.Version + 1, enabled = false });
        Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
        using var staleAfterDisable = f.Host.CreateClient();
        IdentityFixture.As(staleAfterDisable, afterReset.AccessToken);
        Assert.Equal(HttpStatusCode.Unauthorized, (await staleAfterDisable.GetAsync("/api/v1/me")).StatusCode);
    }

    [Fact]
    public async Task Tv_pairing_is_pending_then_approved_once_and_expires_after_five_minutes()
    {
        var start = await f.Client.PostAsJsonAsync("/api/v1/auth/device-code", new { deviceName = "Living room TV" });
        start.EnsureSuccessStatusCode(); var pair = (await start.Content.ReadFromJsonAsync<PairReply>())!;
        Assert.Equal(TimeSpan.FromMinutes(5), pair.ExpiresAt - f.Host.Clock.GetUtcNow());
        var pending = await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/token", new { deviceSecret = pair.DeviceSecret });
        Assert.Equal(HttpStatusCode.Accepted, pending.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/inspect", new { userCode = pair.UserCode })).StatusCode);
        IdentityFixture.As(f.Client, f.Admin.AccessToken);
        var preview = await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/inspect", new { userCode = pair.UserCode });
        preview.EnsureSuccessStatusCode();
        var previewJson = await preview.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        Assert.Equal("Living room TV", previewJson.GetProperty("deviceName").GetString());
        Assert.False(previewJson.TryGetProperty("deviceSecret", out _));
        Assert.False(previewJson.TryGetProperty("userCode", out _));
        var approved = await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/approve", new { userCode = pair.UserCode });
        Assert.Equal(HttpStatusCode.NoContent, approved.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/inspect", new { userCode = pair.UserCode })).StatusCode);
        f.Host.Clock.Advance(TimeSpan.FromSeconds(5));
        var token = await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/token", new { deviceSecret = pair.DeviceSecret });
        token.EnsureSuccessStatusCode();
        Assert.NotNull(await token.Content.ReadFromJsonAsync<AuthReply>());
        f.Host.Clock.Advance(TimeSpan.FromSeconds(5));
        var replay = await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/token", new { deviceSecret = pair.DeviceSecret });
        Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
        var second = await f.Client.PostAsJsonAsync("/api/v1/auth/device-code", new { deviceName = "Expired TV" });
        var expiring = (await second.Content.ReadFromJsonAsync<PairReply>())!;
        f.Host.Clock.Advance(TimeSpan.FromMinutes(5));
        Assert.Equal(HttpStatusCode.Unauthorized, (await f.Client.PostAsJsonAsync("/api/v1/auth/device-code/token", new { deviceSecret = expiring.DeviceSecret })).StatusCode);
    }

    [Theory]
    [InlineData("logout")]
    [InlineData("password-change")]
    [InlineData("disable-reenable")]
    public async Task Approved_pairing_cannot_exchange_after_approving_session_is_revoked(string revocation)
    {
        var admin = IdentityFixture.As(f.Host.CreateClient(), f.Admin.AccessToken);
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "pairmember", displayName = "Pair Member", password = TestPasswords.Member, role = "member" });
        var user = (await created.Content.ReadFromJsonAsync<UserReply>())!;
        var memberClient = f.Host.CreateClient();
        var login = await memberClient.PostAsJsonAsync("/api/v1/auth/login", new { username = "pairmember", password = TestPasswords.Member, deviceName = "phone" });
        var member = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        IdentityFixture.As(memberClient, member.AccessToken);
        var deviceClient = f.Host.CreateClient();
        var started = await deviceClient.PostAsJsonAsync("/api/v1/auth/device-code", new { deviceName = "TV" });
        var pairing = (await started.Content.ReadFromJsonAsync<PairReply>())!;
        Assert.Equal(HttpStatusCode.NoContent, (await memberClient.PostAsJsonAsync("/api/v1/auth/device-code/approve", new { userCode = pairing.UserCode })).StatusCode);

        if (revocation == "logout")
        {
            Assert.Equal(HttpStatusCode.NoContent, (await memberClient.PostAsync("/api/v1/auth/logout", null)).StatusCode);
        }
        else if (revocation == "password-change")
        {
            Assert.Equal(HttpStatusCode.NoContent, (await memberClient.PostAsJsonAsync("/api/v1/me/password", new { currentPassword = TestPasswords.Member, newPassword = TestPasswords.Replacement })).StatusCode);
        }
        else
        {
            using var disabled = await admin.PatchAsJsonAsync($"/api/v1/admin/users/{user.Id}", new { version = user.Version, enabled = false });
            Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
            using var reenabled = await admin.PatchAsJsonAsync($"/api/v1/admin/users/{user.Id}", new { version = user.Version + 1, enabled = true });
            Assert.Equal(HttpStatusCode.OK, reenabled.StatusCode);
        }

        f.Host.Clock.Advance(TimeSpan.FromSeconds(5));
        var exchange = await deviceClient.PostAsJsonAsync("/api/v1/auth/device-code/token", new { deviceSecret = pairing.DeviceSecret });
        Assert.Equal(HttpStatusCode.Unauthorized, exchange.StatusCode);
        Assert.Equal("pairing_expired", await Code(exchange));
    }

    [Fact]
    public async Task Login_failures_are_generic_and_limited()
    {
        using var host = new TestHost(); using var client = host.CreateClient();
        await IdentityFixture.Bootstrap(client, host.BootstrapCode(), "rootuser", "Root User", TestPasswords.Root);
        var a = await client.PostAsJsonAsync("/api/v1/auth/login", new { username = "rootuser", password = TestPasswords.Wrong, deviceName = "test" });
        var b = await client.PostAsJsonAsync("/api/v1/auth/login", new { username = "no-such-user", password = TestPasswords.Wrong, deviceName = "test" });
        Assert.Equal(a.StatusCode, b.StatusCode);
        Assert.Equal(await Code(a), await Code(b));
        HttpResponseMessage? last = null;
        for (var i = 0; i < 9; i++) last = await client.PostAsJsonAsync("/api/v1/auth/login", new { username = "rootuser", password = TestPasswords.Wrong, deviceName = "test" });
        Assert.Equal((HttpStatusCode)429, last!.StatusCode);
    }

    [Fact]
    public async Task Contained_directory_rejects_traversal_symlinks_and_symlink_swap_without_reading_outside()
    {
        var root = Path.Combine(f.Host.Root, "data", "safe"); Directory.CreateDirectory(root);
        var file = Path.Combine(root, "content.bin"); await File.WriteAllTextAsync(file, "inside");
        var outside = Path.Combine(f.Host.Root, "outside.txt"); await File.WriteAllTextAsync(outside, "outside-secret");
        var link = Path.Combine(root, "link.txt"); File.CreateSymbolicLink(link, outside);
        using var contained = new ContainedDirectory(root);
        Assert.Throws<ApiException>(() => contained.OpenFile("../outside.txt"));
        Assert.Throws<ApiException>(() => contained.OpenFile("link.txt"));
        using var stop = new CancellationTokenSource();
        var swapper = Task.Run(async () =>
        {
            while (!stop.IsCancellationRequested)
            {
                try { File.Delete(link); File.CreateSymbolicLink(link, outside); File.Delete(link); File.CreateSymbolicLink(link, file); } catch (IOException) { }
                await Task.Yield();
            }
        });
        try
        {
            for (var i = 0; i < 400; i++)
            {
                try { using var stream = contained.OpenFile("link.txt"); using var reader = new StreamReader(stream); Assert.Equal("inside", await reader.ReadToEndAsync()); }
                catch (ApiException) { }
            }
        }
        finally { stop.Cancel(); await swapper; }
    }

    [Fact]
    public async Task Open_library_remains_pinned_to_original_identity_and_data_root()
    {
        var data = Path.Combine(f.Host.Root, "data", "pinned-library-data");
        var state = Path.Combine(f.Host.Root, "state", "pinned-library-state");
        var originalA = Path.Combine(data, "A"); var originalB = Path.Combine(data, "B");
        Directory.CreateDirectory(originalA); Directory.CreateDirectory(originalB); Directory.CreateDirectory(state);
        await File.WriteAllTextAsync(Path.Combine(originalA, "ownedA.txt"), "owner-A");
        await File.WriteAllTextAsync(Path.Combine(originalB, "secretB.txt"), "secret-B");
        using var storage = new ContainedStorage(new Briani.Api.Infrastructure.ServerOptions { DataRoot = data, StateRoot = state });
        var root = storage.ValidateLibraryRoot("A");
        var library = new Library { Name = "A", RootPath = root.RelativePath, RootIdentity = root.Identity };
        using var held = storage.OpenLibrary(library);

        var movedA = Path.Combine(data, "oldA");
        Directory.Move(originalA, movedA);
        Directory.Move(originalB, originalA);
        using (var owned = held.OpenFile("ownedA.txt"))
        using (var reader = new StreamReader(owned)) Assert.Equal("owner-A", await reader.ReadToEndAsync());
        Assert.Throws<ApiException>(() => held.OpenFile("secretB.txt"));
        Assert.Throws<ApiException>(() => held.Inspect("secretB.txt"));
        Assert.DoesNotContain("secretB.txt", held.Names());

        var escaped = Path.Combine(f.Host.Root, "outside-library-data");
        Directory.Move(movedA, escaped);
        Assert.Throws<ApiException>(() => held.OpenFile("ownedA.txt"));
        Assert.Equal("owner-A", await File.ReadAllTextAsync(Path.Combine(escaped, "ownedA.txt")));
    }

    [Fact]
    public async Task Contained_directory_supports_unicode_and_rejects_special_files()
    {
        var root = Path.Combine(f.Host.Root, "data", "contained"); Directory.CreateDirectory(root);
        using var contained = new ContainedDirectory(root);
        using (var file = contained.CreateFile("日本語 🎬.mkv")) { await file.WriteAsync("valid"u8.ToArray()); file.Flush(true); }
        Assert.Contains("日本語 🎬.mkv", contained.Names());
        using var opened = contained.OpenFile("日本語 🎬.mkv");
        using var reader = new StreamReader(opened);
        Assert.Equal("valid", await reader.ReadToEndAsync());
        Assert.Throws<ApiException>(() => ContainedDirectory.Validate("a/../b"));
        Assert.Throws<ApiException>(() => ContainedDirectory.Validate("a\\b"));
        contained.CreateDirectory("nested");
        using (var sparse = contained.CreateFile("nested/large.bin")) { sparse.SetLength(4L * 1024 * 1024 * 1024 + 19); }
        Assert.Equal(4L * 1024 * 1024 * 1024 + 19, contained.Inspect("nested/large.bin").Length);
        contained.HardLink("nested/large.bin", "nested/linked.bin");
        contained.Rename("nested/linked.bin", "nested/renamed.bin");
        contained.Unlink("nested/renamed.bin");
        Assert.Throws<ApiException>(() => contained.OpenFile("nested/renamed.bin"));
    }

    [Theory]
    [InlineData("create-dir")]
    [InlineData("link")]
    [InlineData("rename")]
    [InlineData("unlink")]
    public async Task Parent_directory_move_during_mutation_never_changes_outside_tree(string operation)
    {
        var root = Path.Combine(f.Host.Root, "data", "mutation-root", operation);
        var nested = Path.Combine(root, "nested");
        var outside = Path.Combine(f.Host.Root, "outside-mutation", operation);
        Directory.CreateDirectory(nested);
        Directory.CreateDirectory(outside);
        await File.WriteAllTextAsync(Path.Combine(nested, "source.txt"), "sentinel");
        using var contained = new ContainedDirectory(root);
        using var ready = new ManualResetEventSlim();
        using var release = new ManualResetEventSlim();
        contained.BeforeMutation = () =>
        {
            ready.Set();
            if (!release.Wait(TimeSpan.FromSeconds(10))) throw new TimeoutException("Mutation race release timed out.");
        };

        var mutation = Task.Run(() =>
        {
            switch (operation)
            {
                case "create-dir": contained.CreateDirectory("nested/created"); break;
                case "link": contained.HardLink("nested/source.txt", "nested/linked.txt"); break;
                case "rename": contained.Rename("nested/source.txt", "nested/renamed.txt"); break;
                case "unlink": contained.Unlink("nested/source.txt"); break;
                default: throw new InvalidOperationException(operation);
            }
        });

        try
        {
            Assert.True(ready.Wait(TimeSpan.FromSeconds(10)), "Mutation did not reach its deterministic race hook.");
            Directory.Move(nested, Path.Combine(outside, "nested"));
        }
        finally { release.Set(); }

        var error = await Assert.ThrowsAsync<ApiException>(async () => await mutation);
        Assert.Equal(409, error.Status);
        Assert.Equal("sentinel", await File.ReadAllTextAsync(Path.Combine(outside, "nested", "source.txt")));
        Assert.False(Directory.Exists(Path.Combine(outside, "nested", "created")));
        Assert.False(File.Exists(Path.Combine(outside, "nested", "linked.txt")));
        Assert.False(File.Exists(Path.Combine(outside, "nested", "renamed.txt")));
    }

    [Fact]
    public async Task Mutations_reject_source_and_destination_symlink_paths()
    {
        var root = Path.Combine(f.Host.Root, "data", "symlink-mutation");
        var nested = Path.Combine(root, "nested");
        var outside = Path.Combine(f.Host.Root, "outside-symlink-mutation");
        Directory.CreateDirectory(nested); Directory.CreateDirectory(outside);
        await File.WriteAllTextAsync(Path.Combine(nested, "source.txt"), "inside");
        await File.WriteAllTextAsync(Path.Combine(outside, "sentinel.txt"), "outside-secret");
        File.CreateSymbolicLink(Path.Combine(nested, "source-link"), Path.Combine(outside, "sentinel.txt"));
        Directory.CreateSymbolicLink(Path.Combine(nested, "destination-link"), outside);
        using var contained = new ContainedDirectory(root);

        Assert.Throws<ApiException>(() => contained.HardLink("nested/source-link", "nested/copy.txt"));
        Assert.Throws<ApiException>(() => contained.Unlink("nested/source-link"));
        Assert.Throws<ApiException>(() => contained.CreateDirectory("nested/destination-link/new"));
        Assert.Throws<ApiException>(() => contained.HardLink("nested/source.txt", "nested/destination-link/copy.txt"));
        Assert.Throws<ApiException>(() => contained.Rename("nested/source.txt", "nested/destination-link/renamed.txt"));
        Assert.Equal("outside-secret", await File.ReadAllTextAsync(Path.Combine(outside, "sentinel.txt")));
        Assert.False(File.Exists(Path.Combine(outside, "copy.txt")));
        Assert.False(File.Exists(Path.Combine(outside, "renamed.txt")));
    }

    [Theory]
    [InlineData("create-file")]
    [InlineData("create-dir")]
    [InlineData("link")]
    [InlineData("rename")]
    [InlineData("unlink")]
    public async Task Retained_child_handle_cannot_mutate_after_move_outside_root(string operation)
    {
        var rootPath = Path.Combine(f.Host.Root, "data", "retained-child", operation);
        var nested = Path.Combine(rootPath, "nested");
        var outside = Path.Combine(f.Host.Root, "outside-retained-child", operation);
        Directory.CreateDirectory(nested); Directory.CreateDirectory(outside);
        await File.WriteAllTextAsync(Path.Combine(nested, "source.txt"), "sentinel");
        using var root = new ContainedDirectory(rootPath);
        using var child = root.Directory("nested");
        Directory.Move(nested, Path.Combine(outside, "nested"));

        var error = Assert.Throws<ApiException>(() =>
        {
            switch (operation)
            {
                case "create-file": using (var created = child.CreateFile("created.txt")) { } break;
                case "create-dir": child.CreateDirectory("created"); break;
                case "link": child.HardLink("source.txt", "linked.txt"); break;
                case "rename": child.Rename("source.txt", "renamed.txt"); break;
                case "unlink": child.Unlink("source.txt"); break;
                default: throw new InvalidOperationException(operation);
            }
        });
        Assert.Equal(409, error.Status);
        Assert.Equal("sentinel", await File.ReadAllTextAsync(Path.Combine(outside, "nested", "source.txt")));
        Assert.False(File.Exists(Path.Combine(outside, "nested", "created.txt")));
        Assert.False(Directory.Exists(Path.Combine(outside, "nested", "created")));
        Assert.False(File.Exists(Path.Combine(outside, "nested", "linked.txt")));
        Assert.False(File.Exists(Path.Combine(outside, "nested", "renamed.txt")));
    }

    [Fact]
    public async Task Rename_does_not_turn_into_directory_move_after_source_swap()
    {
        var rootPath = Path.Combine(f.Host.Root, "data", "rename-source-swap"); Directory.CreateDirectory(rootPath);
        var source = Path.Combine(rootPath, "source.txt"); await File.WriteAllTextAsync(source, "original");
        using var contained = new ContainedDirectory(rootPath);
        using var ready = new ManualResetEventSlim(); using var release = new ManualResetEventSlim();
        contained.BeforeMutation = () =>
        {
            ready.Set();
            if (!release.Wait(TimeSpan.FromSeconds(10))) throw new TimeoutException("Rename race release timed out.");
        };
        var rename = Task.Run(() => contained.Rename("source.txt", "renamed.txt"));
        try
        {
            Assert.True(ready.Wait(TimeSpan.FromSeconds(10)), "Rename did not reach its deterministic race hook.");
            File.Delete(source); Directory.CreateDirectory(source); await File.WriteAllTextAsync(Path.Combine(source, "sentinel.txt"), "sentinel");
        }
        finally { release.Set(); }
        var error = await Assert.ThrowsAsync<ApiException>(async () => await rename);
        Assert.Equal(409, error.Status);
        Assert.True(Directory.Exists(source));
        Assert.False(File.Exists(Path.Combine(rootPath, "renamed.txt")));
        Assert.Equal("sentinel", await File.ReadAllTextAsync(Path.Combine(source, "sentinel.txt")));
    }

    [Fact]
    public void Login_account_limit_applies_across_distinct_source_ips()
    {
        var limiter = new AuthLimiter(f.Host.Clock);
        for (var i = 1; i <= 5; i++)
        {
            var context = new Microsoft.AspNetCore.Http.DefaultHttpContext();
            context.Connection.RemoteIpAddress = IPAddress.Parse($"192.0.2.{i}");
            limiter.Check(context, "login", "same-account", limit: 10, accountLimit: 5);
        }
        var sixth = new Microsoft.AspNetCore.Http.DefaultHttpContext();
        sixth.Connection.RemoteIpAddress = IPAddress.Parse("192.0.2.6");
        var error = Assert.Throws<ApiException>(() => limiter.Check(sixth, "login", "same-account", limit: 10, accountLimit: 5));
        Assert.Equal(429, error.Status);
        Assert.Equal("rate_limited", error.Code);
    }

    [Fact]
    public async Task Permission_service_applies_all_grant_bits_and_live_session_revocation()
    {
        var result = await f.Host.Services.CreateAsyncScope().Use(async scope =>
        {
            var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
            var clock = scope.ServiceProvider.GetRequiredService<TimeProvider>();
            var admin = await db.Users.SingleAsync(u => u.Id == f.Admin.User.Id);
            var member = new User { Username = "perm", NormalizedUsername = "PERM", DisplayName = "Permission", PasswordHash = "", Role = "member", CreatedAt = clock.GetUtcNow(), UpdatedAt = clock.GetUtcNow() };
            db.Users.Add(member);
            var library = new Library { Name = "Test", RootPath = "safe", RootIdentity = "identity", CreatedAt = clock.GetUtcNow() }; db.Libraries.Add(library);
            var session = new AuthSession { UserId = member.Id, DeviceName = "test", RefreshHash = "abc", CreatedAt = clock.GetUtcNow(), LastSeenAt = clock.GetUtcNow(), RefreshExpiresAt = clock.GetUtcNow().AddDays(30) }; db.AuthSessions.Add(session);
            await db.SaveChangesAsync();
            var service = scope.ServiceProvider.GetRequiredService<PermissionService>();
            var observed = new List<Capabilities>();
            foreach (var bits in new[] { (false,false,false), (true,false,false), (true,true,false), (true,false,true), (true,true,true), (false,true,false), (false,false,true) })
            {
                var g = await db.LibraryGrants.SingleOrDefaultAsync(x => x.LibraryId == library.Id && x.UserId == member.Id);
                if (g is null) { g = new() { LibraryId = library.Id, UserId = member.Id }; db.LibraryGrants.Add(g); }
                (g.CanRead, g.CanDownload, g.CanManage) = bits; await db.SaveChangesAsync(); db.Entry(g).State = Microsoft.EntityFrameworkCore.EntityState.Detached;
                observed.Add(await service.CapabilitiesAsync(new(member.Id, session.Id, "member"), library));
            }
            session.RevokedAt = clock.GetUtcNow(); await db.SaveChangesAsync();
            var revoked = await service.CapabilitiesAsync(new(member.Id, session.Id, "member"), library);
            return (observed, revoked, memberId: member.Id, libraryId: library.Id, sessionId: session.Id);
        });
        Assert.Equal(new Capabilities(false,false,false), result.observed[0]);
        Assert.Equal(new Capabilities(true,false,false), result.observed[1]);
        Assert.Equal(new Capabilities(true,true,false), result.observed[2]);
        Assert.Equal(new Capabilities(true,false,true), result.observed[3]);
        Assert.Equal(new Capabilities(true,true,true), result.observed[4]);
        Assert.All(result.observed.Skip(5), c => Assert.Equal(new Capabilities(false,false,false), c));
        Assert.Equal(new Capabilities(false,false,false), result.revoked);
        f.Host.Clock.Advance(TimeSpan.FromDays(31));
        Assert.False(await f.Host.Services.CreateAsyncScope().Use(scope => scope.ServiceProvider.GetRequiredService<PermissionService>().IsSessionValidAsync(result.sessionId)));
    }

    [Fact]
    public async Task Permission_service_reloads_current_user_library_and_grant_state()
    {
        var result = await f.Host.Services.CreateAsyncScope().Use(async scope =>
        {
            var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
            var now = scope.ServiceProvider.GetRequiredService<TimeProvider>().GetUtcNow();
            var member = new User { Username = "coldperm", NormalizedUsername = "COLDPERM", DisplayName = "Cold", PasswordHash = "", Role = "member", CreatedAt = now, UpdatedAt = now };
            var library = new Library { Name = "Cold library", RootPath = "cold", RootIdentity = "cold-identity", CreatedAt = now };
            var session = new AuthSession { UserId = member.Id, DeviceName = "test", RefreshHash = "cold", CreatedAt = now, LastSeenAt = now, RefreshExpiresAt = now.AddDays(30) };
            var grant = new LibraryGrant { UserId = member.Id, LibraryId = library.Id, CanRead = true, CanDownload = true, CanManage = true };
            db.AddRange(member, library, session, grant); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
            var service = scope.ServiceProvider.GetRequiredService<PermissionService>();
            var actor = new Actor(member.Id, session.Id, "member");
            var readWrite = await service.CapabilitiesAsync(actor, await db.Libraries.SingleAsync(x => x.Id == library.Id));
            var missingUser = await service.CapabilitiesAsync(actor with { UserId = Guid.NewGuid() }, await db.Libraries.SingleAsync(x => x.Id == library.Id));
            var wrongSession = await service.CapabilitiesAsync(actor with { SessionId = Guid.NewGuid() }, await db.Libraries.SingleAsync(x => x.Id == library.Id));

            await db.Users.Where(x => x.Id == member.Id).ExecuteUpdateAsync(x => x.SetProperty(u => u.Role, "administrator")); db.ChangeTracker.Clear();
            var promoted = await service.CapabilitiesAsync(actor, await db.Libraries.SingleAsync(x => x.Id == library.Id));
            await db.Users.Where(x => x.Id == member.Id).ExecuteUpdateAsync(x => x.SetProperty(u => u.Role, "member"));
            await db.Libraries.Where(x => x.Id == library.Id).ExecuteUpdateAsync(x => x.SetProperty(l => l.ReadOnly, true)); db.ChangeTracker.Clear();
            var readOnly = await service.CapabilitiesAsync(actor, await db.Libraries.SingleAsync(x => x.Id == library.Id));
            await db.Libraries.Where(x => x.Id == library.Id).ExecuteUpdateAsync(x => x.SetProperty(l => l.Enabled, false)); db.ChangeTracker.Clear();
            var disabledLibrary = await service.CapabilitiesAsync(actor, await db.Libraries.SingleAsync(x => x.Id == library.Id));
            await db.Libraries.Where(x => x.Id == library.Id).ExecuteUpdateAsync(x => x.SetProperty(l => l.Enabled, true));
            await db.Users.Where(x => x.Id == member.Id).ExecuteUpdateAsync(x => x.SetProperty(u => u.Enabled, false)); db.ChangeTracker.Clear();
            var disabledUser = await service.CapabilitiesAsync(actor, await db.Libraries.SingleAsync(x => x.Id == library.Id));
            return (readWrite, missingUser, wrongSession, promoted, readOnly, disabledLibrary, disabledUser);
        });
        Assert.Equal(new Capabilities(true, true, true), result.readWrite);
        Assert.Equal(new Capabilities(false, false, false), result.missingUser);
        Assert.Equal(new Capabilities(false, false, false), result.wrongSession);
        Assert.Equal(new Capabilities(true, true, true), result.promoted);
        Assert.Equal(new Capabilities(true, false, false), result.readOnly);
        Assert.Equal(new Capabilities(false, false, false), result.disabledLibrary);
        Assert.Equal(new Capabilities(false, false, false), result.disabledUser);
    }

    [Fact]
    public async Task Housekeeping_prunes_only_expired_ephemeral_rows_and_preserves_identity_and_configuration()
    {
        var baseTime = f.Host.Clock.GetUtcNow();
        var expiredAccessHash = Credentials.Hash("expired-access-test-value");
        var liveAccessHash = Credentials.Hash("live-access-test-value");
        var expiredReplayHash = Credentials.Hash("expired-replay-test-value");
        var liveReplayHash = Credentials.Hash("live-replay-test-value");
        var expiredPairId = Guid.NewGuid(); var livePairId = Guid.NewGuid();
        var expiredAuditId = Guid.NewGuid(); var liveAuditId = Guid.NewGuid();
        const string oldIdempotencyKey = "admin-idem:actor:old";
        const string liveIdempotencyKey = "admin-idem:actor:live";
        const string secretSettingKey = "upstream-secret";

        await f.Host.InDb(async db =>
        {
            db.AccessTokens.AddRange(
                new AccessToken { TokenHash = expiredAccessHash, SessionId = f.Admin.SessionId, ExpiresAt = baseTime.AddMinutes(1) },
                new AccessToken { TokenHash = liveAccessHash, SessionId = f.Admin.SessionId, ExpiresAt = baseTime.AddDays(2) });
            db.RefreshReplays.AddRange(
                new RefreshReplay { ConsumedHash = expiredReplayHash, SessionId = f.Admin.SessionId, ExpiresAt = baseTime.AddMinutes(1) },
                new RefreshReplay { ConsumedHash = liveReplayHash, SessionId = f.Admin.SessionId, ExpiresAt = baseTime.AddDays(2) });
            db.DevicePairings.AddRange(
                new DevicePairing { Id = expiredPairId, DeviceSecretHash = Credentials.Hash("expired-device"), HumanCodeHash = Credentials.Hash("expired-code"), DeviceName = "expired", ExpiresAt = baseTime.AddMinutes(1) },
                new DevicePairing { Id = livePairId, DeviceSecretHash = Credentials.Hash("live-device"), HumanCodeHash = Credentials.Hash("live-code"), DeviceName = "live", ExpiresAt = baseTime.AddDays(2) });
            db.AuditEvents.AddRange(
                new AuditEvent { Id = expiredAuditId, Action = "old", TargetType = "test", TargetId = "old", CreatedAt = baseTime.AddDays(-30).AddMinutes(-1) },
                new AuditEvent { Id = liveAuditId, Action = "recent", TargetType = "test", TargetId = "recent", CreatedAt = baseTime });
            db.Settings.AddRange(
                new Setting { Key = oldIdempotencyKey, ValueJson = "old", UpdatedAt = baseTime.AddHours(-24).AddMinutes(-1) },
                new Setting { Key = liveIdempotencyKey, ValueJson = "live", UpdatedAt = baseTime },
                new Setting { Key = secretSettingKey, ValueJson = "preserve-this-secret-value", UpdatedAt = baseTime.AddDays(-90) });
            await db.SaveChangesAsync();
            return true;
        });

        f.Host.Clock.Advance(TimeSpan.FromMinutes(2));
        var housekeeping = f.Host.Services.GetServices<IHostedService>().OfType<IdentityHousekeeping>().Single();
        await housekeeping.PruneAsync();

        var state = await f.Host.InDb(async db => new
        {
            access = await db.AccessTokens.Select(x => x.TokenHash).ToListAsync(),
            replays = await db.RefreshReplays.Select(x => x.ConsumedHash).ToListAsync(),
            pairs = await db.DevicePairings.Select(x => x.Id).ToListAsync(),
            audits = await db.AuditEvents.Select(x => x.Id).ToListAsync(),
            settings = await db.Settings.ToDictionaryAsync(x => x.Key, x => x.ValueJson),
            users = await db.Users.CountAsync(),
            sessions = await db.AuthSessions.CountAsync(x => x.Id == f.Admin.SessionId)
        });
        Assert.DoesNotContain(expiredAccessHash, state.access); Assert.Contains(liveAccessHash, state.access);
        Assert.DoesNotContain(expiredReplayHash, state.replays); Assert.Contains(liveReplayHash, state.replays);
        Assert.DoesNotContain(expiredPairId, state.pairs); Assert.Contains(livePairId, state.pairs);
        Assert.DoesNotContain(expiredAuditId, state.audits); Assert.Contains(liveAuditId, state.audits);
        Assert.DoesNotContain(oldIdempotencyKey, state.settings.Keys); Assert.Contains(liveIdempotencyKey, state.settings.Keys);
        Assert.Equal("preserve-this-secret-value", state.settings[secretSettingKey]);
        Assert.Equal(1, state.users); Assert.Equal(1, state.sessions);
    }

    [Fact]
    public async Task Own_sessions_are_scoped_to_authenticated_user()
    {
        var admin = IdentityFixture.As(f.Client, f.Admin.AccessToken);
        var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "owncheck", displayName = "Own Check", password = TestPasswords.OwnSession, role = "member" });
        created.EnsureSuccessStatusCode();
        var login = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "owncheck", password = TestPasswords.OwnSession, deviceName = "phone" });
        var member = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        IdentityFixture.As(f.Client, member.AccessToken);
        var sessions = await f.Client.GetFromJsonAsync<JsonArray>("/api/v1/me/sessions");
        var adminSession = sessions!.Select(x => (Guid)x!["id"]!).FirstOrDefault();
        var cross = await f.Client.DeleteAsync($"/api/v1/me/sessions/{f.Admin.SessionId}");
        Assert.Equal(HttpStatusCode.NotFound, cross.StatusCode);
        Assert.Equal(0, await f.Host.InDb(db => db.AuthSessions.CountAsync(s => s.Id == f.Admin.SessionId && s.RevokedAt != null)));
        Assert.NotEqual(Guid.Empty, adminSession);
    }

    [Fact]
    public async Task Grant_updates_are_idempotent_in_shape_and_inaccessible_libraries_are_hidden()
    {
        var admin = IdentityFixture.As(f.Client, f.Admin.AccessToken);
        using var userResponse = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "grantuser", displayName = "Grant User", password = TestPasswords.Grant, role = "member" });
        var user = (await userResponse.Content.ReadFromJsonAsync<UserReply>())!;
        var rootId = Guid.Parse(await f.Host.InDb(async db => (await db.Settings.SingleAsync(x => x.Key == "storage_root_id")).ValueJson));
        Directory.CreateDirectory(Path.Combine(f.Host.Root, "data", "library"));
        using var libraryResponse = await admin.PostAsJsonAsync("/api/v1/libraries", new { name = "Library", description = "", storageRootId = rootId, relativePath = "library", readOnly = false });
        libraryResponse.EnsureSuccessStatusCode();
        var library = (await libraryResponse.Content.ReadFromJsonAsync<LibraryView>())!;
        IdentityFixture.As(f.Client, f.Admin.AccessToken);
        using var denied = f.Host.CreateClient();
        var login = await f.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "grantuser", password = TestPasswords.Grant, deviceName = "browser" });
        var member = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        IdentityFixture.As(denied, member.AccessToken);
        var missingGrant = await denied.GetAsync($"/api/v1/libraries/{library.Id}");
        Assert.Equal(HttpStatusCode.NotFound, missingGrant.StatusCode);
        var version = library.Version;
        for (var i = 0; i < 2; i++)
        {
            using var update = await admin.PutAsJsonAsync($"/api/v1/libraries/{library.Id}/grants", new { version, grants = new[] { new { userId = user.Id, read = true, download = true, manage = false, quotaBytes = (long?)1000 } } });
            update.EnsureSuccessStatusCode();
            version++;
        }
        var allowed = await denied.GetAsync($"/api/v1/libraries/{library.Id}");
        Assert.Equal(HttpStatusCode.OK, allowed.StatusCode);
        using var invalid = await admin.PutAsJsonAsync($"/api/v1/libraries/{library.Id}/grants", new { version, grants = new[] { new { userId = user.Id, read = false, download = true, manage = false, quotaBytes = (long?)null } } });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await denied.GetAsync($"/api/v1/libraries/{Guid.NewGuid()}")).StatusCode);
    }

    private static async Task<string?> Code(HttpResponseMessage response)
    { var node = JsonNode.Parse(await response.Content.ReadAsStringAsync()); return node?["code"]?.GetValue<string>(); }

}

internal static class ScopeExtensions
{
    public static async Task<T> Use<T>(this AsyncServiceScope scope, Func<AsyncServiceScope, Task<T>> action)
    { await using (scope) return await action(scope); }
}

public sealed record PairReply(string DeviceSecret, string UserCode, DateTimeOffset ExpiresAt, int PollIntervalSeconds);
