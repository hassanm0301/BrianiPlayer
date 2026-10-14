using System.Net;
using System.Net.Sockets;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Discovery;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Identity;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.Prowlarr;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DiscoveryTests;

public sealed class SourceResolverTests : IAsyncLifetime
{
    private const string V1 = "0123456789abcdef0123456789abcdef01234567";
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Approved_origin_redirect_to_private_port_is_rejected_without_forwarding_credentials()
    {
        using var redirected = new TcpListener(IPAddress.Loopback, 0); redirected.Start();
        var redirectedPort = ((IPEndPoint)redirected.LocalEndpoint).Port;
        var redirectedAccept = Task.Run(async () => { try { using var client = await redirected.AcceptTcpClientAsync(); return true; } catch (SocketException) { return false; } });
        using var upstream = new FixtureHttpServer($"HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:{redirectedPort}/private\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        var setup = await PrepareResult(upstream.Origin, null, null, "fixture-secret");
        using var scope = fixture.Host.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<SourceService>();
        var failure = await Assert.ThrowsAsync<ApiException>(() => service.ResolveAsync(setup.Actor, "discoveryResult", setup.ResultId.ToString("D")));
        Assert.Equal("source_url_rejected", failure.Code);
        var request = await upstream.Request.WaitAsync(TimeSpan.FromSeconds(3));
        Assert.Contains("X-Api-Key: fixture-secret", request, StringComparison.OrdinalIgnoreCase);
        var received = await Task.WhenAny(redirectedAccept, Task.Delay(200));
        Assert.NotSame(redirectedAccept, received);
        redirected.Stop();
        Assert.False(await redirectedAccept);
    }

    [Fact]
    public async Task Malformed_bounded_upstream_payload_is_rejected_as_metainfo_without_echoing_body()
    {
        using var upstream = new FixtureHttpServer("HTTP/1.1 200 OK\r\nContent-Type: application/x-bittorrent\r\nContent-Length: 18\r\nConnection: close\r\n\r\nnot a torrent body");
        var setup = await PrepareResult(upstream.Origin, null, null, "safe-secret");
        using var scope = fixture.Host.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<SourceService>();
        var error = await Assert.ThrowsAsync<ApiException>(() => service.ResolveAsync(setup.Actor, "discoveryResult", setup.ResultId.ToString("D")));
        Assert.Equal("invalid_metainfo", error.Code);
        Assert.DoesNotContain("not a torrent", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Magnet_resolution_rechecks_disabled_user_after_tracker_dns_unblocks()
    {
        var rootName = "resolver-revoke-" + Guid.NewGuid().ToString("N");
        Directory.CreateDirectory(Path.Combine(fixture.Host.Root, "data", rootName));
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var library = new Library { Id = Guid.NewGuid(), Name = rootName, RootPath = rootName, RootIdentity = storage.ValidateLibraryRoot(rootName).Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db => { db.Libraries.Add(library); await db.SaveChangesAsync(); return 0; });
        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var password = Credentials.NewToken();
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "resolver-revoked", displayName = "Resolver Revoked", password, role = "member" });
        created.EnsureSuccessStatusCode(); var user = await created.Content.ReadFromJsonAsync<UserReply>(); Assert.NotNull(user);
        await fixture.Host.InDb(async db => { db.LibraryGrants.Add(new LibraryGrant { UserId = user.Id, LibraryId = library.Id, CanRead = true, CanDownload = true }); await db.SaveChangesAsync(); return 0; });
        using var login = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new { username = "resolver-revoked", password, deviceName = "resolver" });
        login.EnsureSuccessStatusCode(); var tokens = await login.Content.ReadFromJsonAsync<AuthReply>(); Assert.NotNull(tokens);
        var actor = new Actor(user.Id, tokens.SessionId, user.Role);
        var dns = new PausingDns(IPAddress.Parse("8.8.8.8"));
        using var scope = fixture.Host.Services.CreateScope();
        var provider = scope.ServiceProvider;
        var service = new SourceService(provider.GetRequiredService<BrianiDb>(), provider.GetRequiredService<DiscoveryAccess>(), provider.GetRequiredService<ServiceConnections>(),
            provider.GetRequiredService<SafeHttp>(), dns, provider.GetRequiredService<Briani.Api.Integrations.Prowlarr.IProwlarrClient>(), provider.GetRequiredService<SecretStore>(),
            provider.GetRequiredService<ServerOptions>(), provider.GetRequiredService<WriteGate>(), fixture.Host.Clock, provider.GetRequiredService<SourceLimits>());
        var task = service.ResolveAsync(actor, "magnet", $"magnet:?xt=urn:btih:{V1}&tr=https%3A%2F%2Ftracker.example%2Fannounce");
        await dns.Entered.Task.WaitAsync(TimeSpan.FromSeconds(3));
        using (var disabled = await admin.PatchAsJsonAsync($"/api/v1/admin/users/{user.Id:D}", new { version = user.Version, enabled = false })) Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
        dns.Release();
        var rejected = await Assert.ThrowsAsync<ApiException>(() => task);
        Assert.Contains(rejected.Status, new[] { 403, 404 });
    }

    [Fact]
    public async Task Upload_expiring_during_tracker_dns_resolution_is_not_returned()
    {
        var rootName = "upload-dns-expiry-" + Guid.NewGuid().ToString("N");
        Directory.CreateDirectory(Path.Combine(fixture.Host.Root, "data", rootName));
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var library = new Library { Id = Guid.NewGuid(), Name = rootName, RootPath = rootName, RootIdentity = storage.ValidateLibraryRoot(rootName).Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db => { db.Libraries.Add(library); await db.SaveChangesAsync(); return 0; });
        var torrent = TorrentFixture.CreateV1("tracked.mkv", [1, 2, 3], announce: "https://tracker.example/announce").Bytes;
        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        using var form = new MultipartFormDataContent(); form.Add(new ByteArrayContent(torrent), "file", "tracked.torrent");
        using var uploaded = await admin.PostAsync("/api/v1/torrent-uploads", form);
        Assert.Equal(HttpStatusCode.Created, uploaded.StatusCode);
        var uploadId = (await uploaded.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>()).GetProperty("id").GetGuid();
        var actor = new Actor(fixture.Admin.User.Id, fixture.Admin.SessionId, fixture.Admin.User.Role);
        var dns = new PausingDns(IPAddress.Parse("8.8.8.8"));
        using var scope = fixture.Host.Services.CreateScope();
        var provider = scope.ServiceProvider;
        var service = new SourceService(provider.GetRequiredService<Briani.Api.Infrastructure.Persistence.BrianiDb>(), provider.GetRequiredService<DiscoveryAccess>(), provider.GetRequiredService<ServiceConnections>(),
            provider.GetRequiredService<SafeHttp>(), dns, provider.GetRequiredService<Briani.Api.Integrations.Prowlarr.IProwlarrClient>(), provider.GetRequiredService<SecretStore>(),
            provider.GetRequiredService<ServerOptions>(), provider.GetRequiredService<WriteGate>(), fixture.Host.Clock, provider.GetRequiredService<SourceLimits>());
        var resolving = service.ResolveAsync(actor, "torrentUpload", uploadId.ToString("D"));
        await dns.Entered.Task.WaitAsync(TimeSpan.FromSeconds(3));
        fixture.Host.Clock.Advance(TimeSpan.FromMinutes(31));
        dns.Release();
        var expired = await Assert.ThrowsAsync<ApiException>(() => resolving);
        Assert.Equal("source_expired", expired.Code);
    }

    [Fact]
    public void Source_resolution_limit_rejects_a_third_lease_and_releases_disposed_leases()
    {
        var limits = fixture.Host.Services.GetRequiredService<SourceLimits>();
        using var first = limits.Enter();
        var second = limits.Enter();
        var limited = Assert.Throws<ApiException>(() => limits.Enter());
        Assert.Equal(429, limited.Status);
        second.Dispose();
        using var replacement = limits.Enter();
        Assert.Throws<ApiException>(() => limits.Enter());
    }

    [Theory]
    [InlineData("fixture-release", "0123456789abcdef0123456789abcdef01234567", true)]
    [InlineData("other", "0123456789abcdef0123456789abcdef01234567", false)]
    [InlineData("fixture-release", "1123456789abcdef0123456789abcdef01234567", false)]
    public async Task Stale_discovery_result_is_refetched_once_and_requires_matching_identity(string freshGuid, string freshHash, bool shouldResolve)
    {
        var setup = await PrepareResult(new Uri("http://127.0.0.1:9/"), V1, null);
        await fixture.Host.InDb(async db =>
        {
            var row = await db.DiscoveryResults.SingleAsync(x => x.Id == setup.ResultId);
            row.ObservedAt = fixture.Host.Clock.GetUtcNow().AddMinutes(-6);
            await db.SaveChangesAsync();
            return 0;
        });
        var magnet = $"magnet:?xt=urn:btih:{V1}";
        var release = new ProwlarrRelease(freshGuid, "Fixture release", 3, 1, 0, null, [], freshHash, null, null, magnet);
        var fake = new FixtureProwlarr(release);
        using var scope = fixture.Host.Services.CreateScope();
        var provider = scope.ServiceProvider;
        var service = new SourceService(provider.GetRequiredService<BrianiDb>(), provider.GetRequiredService<DiscoveryAccess>(), provider.GetRequiredService<ServiceConnections>(),
            provider.GetRequiredService<SafeHttp>(), provider.GetRequiredService<ISafeDns>(), fake, provider.GetRequiredService<SecretStore>(),
            provider.GetRequiredService<ServerOptions>(), provider.GetRequiredService<WriteGate>(), fixture.Host.Clock, provider.GetRequiredService<SourceLimits>());

        if (shouldResolve)
        {
            var resolved = await service.ResolveAsync(setup.Actor, "discoveryResult", setup.ResultId.ToString("D"));
            Assert.Equal(magnet, resolved.Magnet);
        }
        else
        {
            var error = await Assert.ThrowsAsync<ApiException>(() => service.ResolveAsync(setup.Actor, "discoveryResult", setup.ResultId.ToString("D")));
            Assert.Equal("source_expired", error.Code);
        }
        Assert.Equal(1, fake.ProviderCalls);
        Assert.Equal(1, fake.SearchCalls);
    }

    private async Task<(Actor Actor, Guid ResultId)> PrepareResult(Uri origin, string? expectedV1, string? expectedV2, string? secret = null)
    {
        var actor = new Actor(fixture.Admin.User.Id, fixture.Admin.SessionId, fixture.Admin.User.Role);
        var library = new Library { Id = Guid.NewGuid(), Name = "source-resolution", RootPath = "unused", RootIdentity = "fixture-root", CreatedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db => { db.Libraries.Add(library); await db.SaveChangesAsync(); return 0; });
        using var scope = fixture.Host.Services.CreateScope();
        var provider = scope.ServiceProvider;
        var access = provider.GetRequiredService<DiscoveryAccess>();
        var stamp = await access.RequireAsync(actor);
        var secrets = provider.GetRequiredService<SecretStore>();
        var connections = provider.GetRequiredService<ServiceConnections>();
        var db = provider.GetRequiredService<BrianiDb>();
        await connections.SaveAsync("prowlarr", new IntegrationUpdate(origin.AbsoluteUri, 1, "fixture-user", secret ?? Credentials.NewToken()), actor, db, provider.GetRequiredService<Audit>());
        var snapshot = new DiscoverySnapshot { UserId = actor.UserId, AuthSessionId = actor.SessionId, PermissionStamp = stamp, QueryKey = "fixture", QueryJson = "{}", State = "completed", CreatedAt = fixture.Host.Clock.GetUtcNow(), ExpiresAt = fixture.Host.Clock.GetUtcNow().AddMinutes(10), FetchedAt = fixture.Host.Clock.GetUtcNow() };
        var resultId = Guid.NewGuid();
        var options = new[] { new ResolutionOption("4", "fixture-release", new Uri(origin, "download/fixture").AbsoluteUri, null, expectedV1, expectedV2) };
        db.DiscoverySnapshots.Add(snapshot);
        db.DiscoveryResults.Add(new DiscoveryResult { Id = resultId, SnapshotId = snapshot.Id, SourceId = "4", SourceName = "fixture", SourceGuid = "fixture-release", Title = "Fixture release", ObservedAt = fixture.Host.Clock.GetUtcNow(), InfoHashV1 = expectedV1, InfoHashV2 = expectedV2, EncryptedResolutionJson = secrets.Encrypt(JsonSerializer.Serialize(options, new JsonSerializerOptions(JsonSerializerDefaults.Web))), CanDownload = true });
        await db.SaveChangesAsync();
        return (actor, resultId);
    }

    private sealed class FixtureHttpServer : IDisposable
    {
        private readonly TcpListener listener;
        public Uri Origin { get; }
        public Task<string> Request { get; }
        public FixtureHttpServer(string response)
        {
            listener = new TcpListener(IPAddress.Loopback, 0); listener.Start();
            var port = ((IPEndPoint)listener.LocalEndpoint).Port; Origin = new Uri($"http://127.0.0.1:{port}/");
            Request = ServeAsync(response);
        }
        private async Task<string> ServeAsync(string response)
        {
            using var client = await listener.AcceptTcpClientAsync().WaitAsync(TimeSpan.FromSeconds(5));
            await using var stream = client.GetStream(); using var reader = new StreamReader(stream, Encoding.ASCII, leaveOpen: true);
            var lines = new List<string>(); string? line;
            while (!string.IsNullOrEmpty(line = await reader.ReadLineAsync().WaitAsync(TimeSpan.FromSeconds(3)))) lines.Add(line);
            await stream.WriteAsync(Encoding.ASCII.GetBytes(response));
            return string.Join("\n", lines);
        }
        public void Dispose() => listener.Stop();
    }

    private sealed class PausingDns(IPAddress answer) : ISafeDns
    {
        private readonly TaskCompletionSource release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Entered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public void Release() => release.TrySetResult();
        public async Task<IPAddress[]> ResolveAsync(string host, CancellationToken ct)
        { Entered.TrySetResult(); await release.Task.WaitAsync(ct); return [answer]; }
    }

    private sealed class FixtureProwlarr(ProwlarrRelease release) : IProwlarrClient
    {
        public int ProviderCalls { get; private set; }
        public int SearchCalls { get; private set; }
        private static readonly ProviderInfo Provider = new("4", "Fixture", true, true, false, []);
        public Task<ProviderInfo[]> ProvidersAsync(CancellationToken ct = default)
        { ProviderCalls++; return Task.FromResult(new[] { Provider }); }
        public Task<ProviderResults> SearchAsync(ProviderInfo provider, ProwlarrSearch query, CancellationToken ct = default)
        { SearchCalls++; return Task.FromResult(new ProviderResults(provider, [release], false)); }
    }
}
