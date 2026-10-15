using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Discovery;
using Briani.Api.Modules.Discovery.Sources;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DiscoveryTests;

public sealed class SourceApiTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Integration_secret_is_encrypted_at_rest_and_never_returned_by_admin_api()
    {
        using (var anonymous = await fixture.Client.GetAsync("/api/v1/admin/integrations")) Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        var secret = Credentials.NewToken();
        var request = new { baseUrl = "http://prowlarr:9696/", version = 1, username = "fixture-user", secret };
        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        using var saved = await admin.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", request);
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);
        var savedBody = await saved.Content.ReadAsStringAsync();
        Assert.DoesNotContain(secret, savedBody, StringComparison.Ordinal);
        Assert.DoesNotContain("encryptedSecret", savedBody, StringComparison.OrdinalIgnoreCase);

        using var listed = await admin.GetAsync("/api/v1/admin/integrations");
        Assert.Equal(HttpStatusCode.OK, listed.StatusCode);
        var listedBody = await listed.Content.ReadAsStringAsync();
        Assert.DoesNotContain(secret, listedBody, StringComparison.Ordinal);
        Assert.Contains("credentialConfigured", listedBody, StringComparison.Ordinal);
        var stored = await fixture.Host.InDb(db => db.Settings.AsNoTracking().SingleAsync(x => x.Key == "integration.prowlarr"));
        Assert.DoesNotContain(secret, stored.ValueJson, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Integration_updates_enforce_version_and_nonadministrator_denial()
    {
        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var password = Credentials.NewToken();
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "source-member", displayName = "Source Member", password, confirmPassword = password, role = "member" });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        using var loginResponse = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "source-member", password, deviceName = "test" });
        loginResponse.EnsureSuccessStatusCode();
        var memberTokens = await loginResponse.Content.ReadFromJsonAsync<AuthReply>();
        Assert.NotNull(memberTokens);
        using var member = IdentityFixture.As(fixture.Host.CreateClient(), memberTokens.AccessToken);
        using (var denied = await member.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = "http://prowlarr:9696/", version = 1, secret = Credentials.NewToken() }))
            Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
        using var first = await admin.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = "http://prowlarr:9696/", version = 1, secret = Credentials.NewToken() });
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        using var stale = await admin.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = "http://prowlarr:9696/", version = 1, secret = Credentials.NewToken() });
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);
    }

    [Fact]
    public async Task Upload_requires_authentication_and_accepts_bounded_generated_torrent()
    {
        var torrent = TorrentFixture.CreateV1("generated.mkv", [7, 8, 9]).Bytes;
        using (var anonymous = new MultipartFormDataContent())
        {
            anonymous.Add(new ByteArrayContent(torrent), "file", "generated.torrent");
            using var denied = await fixture.Client.PostAsync("/api/v1/torrent-uploads", anonymous);
            Assert.Equal(HttpStatusCode.Unauthorized, denied.StatusCode);
        }
        var rootName = "upload-test-" + Guid.NewGuid().ToString("N");
        Directory.CreateDirectory(Path.Combine(fixture.Host.Root, "data", rootName));
        var storage = fixture.Host.Services.GetRequiredService<Briani.Api.Infrastructure.Storage.ContainedStorage>();
        var library = new Library { Id = Guid.NewGuid(), Name = rootName, RootPath = rootName, RootIdentity = storage.ValidateLibraryRoot(rootName).Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db => { db.Libraries.Add(library); await db.SaveChangesAsync(); return 0; });

        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var now = fixture.Host.Clock.GetUtcNow();
        const string key = "upload-idempotency-fixture";
        using var response = await Upload(admin, torrent, key);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var returned = await response.Content.ReadAsStringAsync();
        Assert.Contains("sizeBytes", returned, StringComparison.Ordinal);
        Assert.DoesNotContain("generated.mkv", returned, StringComparison.Ordinal);
        Assert.DoesNotContain("uploads/", returned, StringComparison.Ordinal);
        using var returnedJson = System.Text.Json.JsonDocument.Parse(returned);
        var uploadId = returnedJson.RootElement.GetProperty("id").GetGuid();
        Assert.Equal(now.AddMinutes(30), returnedJson.RootElement.GetProperty("expiresAt").GetDateTimeOffset());
        using (var repeated = await Upload(admin, torrent, key))
        {
            Assert.Equal(HttpStatusCode.Created, repeated.StatusCode);
            using var repeatedJson = await System.Text.Json.JsonDocument.ParseAsync(await repeated.Content.ReadAsStreamAsync());
            Assert.Equal(uploadId, repeatedJson.RootElement.GetProperty("id").GetGuid());
        }
        using (var collision = await Upload(admin, TorrentFixture.CreateV1("different.mkv", [3, 2, 1]).Bytes, key))
        {
            Assert.Equal(HttpStatusCode.Conflict, collision.StatusCode);
            Assert.Equal("idempotency_conflict", (await collision.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>()).GetProperty("code").GetString());
        }
        using (var extra = await Upload(admin, torrent, null, addUnexpectedField: true)) Assert.Equal(HttpStatusCode.BadRequest, extra.StatusCode);
        using (var malformed = await Upload(admin, [1, 2, 3], null)) Assert.Equal(HttpStatusCode.BadRequest, malformed.StatusCode);
        var oversizedPayload = new byte[16 * 1024 * 1024 + 64 * 1024 + 1];
        using (var oversize = await Upload(admin, oversizedPayload, null)) Assert.Equal(HttpStatusCode.RequestEntityTooLarge, oversize.StatusCode);
        foreach (var alias in new[] { "/API/v1/torrent-uploads", "/api/v1/torrent-uploads/" })
        {
            using var aliasResponse = await Upload(admin, oversizedPayload, null, path: alias);
            Assert.Contains(aliasResponse.StatusCode, new[] { HttpStatusCode.RequestEntityTooLarge, HttpStatusCode.NotFound });
        }
        using (var scope = fixture.Host.Services.CreateScope())
        {
            var sources = scope.ServiceProvider.GetRequiredService<SourceService>();
            var adminActor = new Actor(fixture.Admin.User.Id, fixture.Admin.SessionId, fixture.Admin.User.Role);
            var resolved = await sources.ResolveAsync(adminActor, "torrentUpload", uploadId.ToString("D"));
            Assert.Equal(torrent, resolved.Torrent);
            Assert.NotNull(resolved.Metadata?.InfoHashV1);
        }

        var password = Credentials.NewToken();
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "upload-other-user", displayName = "Upload Other User", password, confirmPassword = password, role = "member" });
        created.EnsureSuccessStatusCode();
        var user = await created.Content.ReadFromJsonAsync<UserReply>();
        Assert.NotNull(user);
        await fixture.Host.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = user.Id, LibraryId = library.Id, CanRead = true, CanDownload = true });
            await db.SaveChangesAsync(); return 0;
        });
        using var login = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "upload-other-user", password, deviceName = "other-user" });
        login.EnsureSuccessStatusCode();
        var other = await login.Content.ReadFromJsonAsync<AuthReply>();
        Assert.NotNull(other);
        using (var scope = fixture.Host.Services.CreateScope())
        {
            var sources = scope.ServiceProvider.GetRequiredService<SourceService>();
            var otherActor = new Actor(other.User.Id, other.SessionId, other.User.Role);
            var denied = await Assert.ThrowsAsync<ApiException>(() => sources.ResolveAsync(otherActor, "torrentUpload", uploadId.ToString("D")));
            Assert.Equal("not_found", denied.Code);
        }
        var uploadRow = await fixture.Host.InDb(db => db.TorrentUploads.AsNoTracking().SingleAsync(x => x.Id == uploadId));
        var storedPath = Path.Combine(fixture.Host.Root, "state", uploadRow.RelativePath.Replace('/', Path.DirectorySeparatorChar));
        var tampered = torrent.ToArray(); tampered[^1] ^= 0x01; await File.WriteAllBytesAsync(storedPath, tampered);
        using (var scope = fixture.Host.Services.CreateScope())
        {
            var sources = scope.ServiceProvider.GetRequiredService<SourceService>();
            var adminActor = new Actor(fixture.Admin.User.Id, fixture.Admin.SessionId, fixture.Admin.User.Role);
            var changed = await Assert.ThrowsAsync<ApiException>(() => sources.ResolveAsync(adminActor, "torrentUpload", uploadId.ToString("D")));
            Assert.Equal("source_changed", changed.Code);
        }
        fixture.Host.Clock.Advance(TimeSpan.FromMinutes(31));
        using (var scope = fixture.Host.Services.CreateScope())
        {
            var sources = scope.ServiceProvider.GetRequiredService<SourceService>();
            var adminActor = new Actor(fixture.Admin.User.Id, fixture.Admin.SessionId, fixture.Admin.User.Role);
            var expired = await Assert.ThrowsAsync<ApiException>(() => sources.ResolveAsync(adminActor, "torrentUpload", uploadId.ToString("D")));
            Assert.Equal("not_found", expired.Code);
        }
    }

    private static async Task<HttpResponseMessage> Upload(HttpClient client, byte[] bytes, string? key, bool addUnexpectedField = false, string path = "/api/v1/torrent-uploads")
    {
        using var form = new MultipartFormDataContent();
        form.Add(new ByteArrayContent(bytes), "file", "generated.torrent");
        if (addUnexpectedField) form.Add(new StringContent("unexpected"), "comment");
        using var request = new HttpRequestMessage(HttpMethod.Post, path) { Content = form };
        if (key is not null) request.Headers.Add("Idempotency-Key", key);
        return await client.SendAsync(request);
    }
}
