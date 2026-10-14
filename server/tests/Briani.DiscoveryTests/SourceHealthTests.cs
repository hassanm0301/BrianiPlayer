using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.Prowlarr;
using Briani.Api.Modules.Identity;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Briani.DiscoveryTests;

public sealed class SourceHealthTests : IAsyncLifetime
{
    private readonly TestHost root = new();
    private WebApplicationFactory<Program> host = null!;
    private HttpClient client = null!;
    private AuthReply admin = null!;

    public async Task InitializeAsync()
    {
        host = root.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
            services.RemoveAll<IProwlarrTransport>().AddSingleton<IProwlarrTransport>(new FixtureTransport())));
        client = host.CreateClient();
        admin = await IdentityFixture.Bootstrap(client, root.BootstrapCode(), "health-admin", "Health Admin", Credentials.NewToken());
        IdentityFixture.As(client, admin.AccessToken);
    }

    public Task DisposeAsync()
    {
        client.Dispose(); host.Dispose(); root.Dispose();
        return Task.CompletedTask;
    }

    [Fact]
    public async Task Health_response_is_bounded_and_configuration_change_invalidates_observation()
    {
        using var saved = await client.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = "http://prowlarr:9696/", version = 1, secret = Credentials.NewToken() });
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);
        using var tested = await client.PostAsync("/api/v1/admin/integrations/prowlarr/test", null);
        Assert.Equal(HttpStatusCode.OK, tested.StatusCode);
        using var result = await tested.Content.ReadFromJsonAsync<System.Text.Json.JsonDocument>();
        Assert.NotNull(result);
        Assert.Equal("prowlarr", result.RootElement.GetProperty("service").GetString());
        Assert.Equal("healthy", result.RootElement.GetProperty("state").GetString());
        Assert.Equal("Connection succeeded.", result.RootElement.GetProperty("detail").GetString());
        Assert.Equal(root.Clock.GetUtcNow(), result.RootElement.GetProperty("checkedAt").GetDateTimeOffset());

        using var listed = await client.GetAsync("/api/v1/admin/integrations");
        using var list = await listed.Content.ReadFromJsonAsync<System.Text.Json.JsonDocument>();
        Assert.Equal("healthy", FindHealth(list!, "prowlarr").GetProperty("state").GetString());

        using var updated = await client.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = "http://prowlarr:9696/", version = 2, secret = Credentials.NewToken() });
        Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
        using var afterUpdate = await client.GetAsync("/api/v1/admin/integrations");
        using var view = await afterUpdate.Content.ReadFromJsonAsync<System.Text.Json.JsonDocument>();
        Assert.Equal("unknown", FindHealth(view!, "prowlarr").GetProperty("state").GetString());
    }

    [Theory]
    [InlineData("credentials_missing", "credentials_missing")]
    [InlineData("credentials_rejected", "credentials_rejected")]
    [InlineData("invalid-json", "invalid_response")]
    [InlineData("[]", "invalid_response")]
    [InlineData("null", "invalid_response")]
    public async Task Health_maps_dependency_failures_without_echoing_details(string fakeMode, string expected)
    {
        var transport = host.Services.GetRequiredService<IProwlarrTransport>() as FixtureTransport;
        Assert.NotNull(transport);
        transport.Mode = fakeMode;
        using var saved = await client.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = "http://prowlarr:9696/", version = 1, secret = Credentials.NewToken() });
        saved.EnsureSuccessStatusCode();
        using var tested = await client.PostAsync("/api/v1/admin/integrations/prowlarr/test", null);
        Assert.Equal(HttpStatusCode.OK, tested.StatusCode);
        var body = await tested.Content.ReadAsStringAsync();
        Assert.Contains(expected, body, StringComparison.Ordinal);
        Assert.DoesNotContain("fixture-secret", body, StringComparison.Ordinal);
        Assert.DoesNotContain("credentials were rejected by upstream", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Health_rechecks_live_role_after_paused_transport_returns()
    {
        using var saved = await client.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = "http://prowlarr:9696/", version = 1, secret = Credentials.NewToken() });
        saved.EnsureSuccessStatusCode();
        var transport = host.Services.GetRequiredService<IProwlarrTransport>() as FixtureTransport;
        Assert.NotNull(transport);
        transport.Pause = true;
        var healthTask = client.PostAsync("/api/v1/admin/integrations/prowlarr/test", null);
        await transport.Entered.Task.WaitAsync(TimeSpan.FromSeconds(3));
        await InDb(async db =>
        {
            var user = await db.Users.SingleAsync(x => x.Id == admin.User.Id);
            user.Role = "member";
            await db.SaveChangesAsync();
            return 0;
        });
        transport.Release();
        using var response = await healthTask.WaitAsync(TimeSpan.FromSeconds(3));
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    private static System.Text.Json.JsonElement FindHealth(System.Text.Json.JsonDocument document, string kind) =>
        document.RootElement.EnumerateArray().Single(x => x.GetProperty("kind").GetString() == kind).GetProperty("health");

    private Task<T> InDb<T>(Func<BrianiDb, Task<T>> action)
    {
        using var scope = host.Services.CreateScope();
        return action(scope.ServiceProvider.GetRequiredService<BrianiDb>());
    }

    private sealed class FixtureTransport : IProwlarrTransport
    {
        private readonly TaskCompletionSource release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public readonly TaskCompletionSource Entered = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public string Mode { get; set; } = "healthy";
        public bool Pause { get; set; }
        public void Release() => release.TrySetResult();

        public async Task<byte[]> GetAsync(string relativePath, CancellationToken ct = default)
        {
            if (Pause) { Entered.TrySetResult(); await release.Task.WaitAsync(ct); }
            if (Mode is "credentials_missing" or "credentials_rejected") throw new ProwlarrFailure(Mode);
            if(Mode is "[]" or "null")return System.Text.Encoding.UTF8.GetBytes(Mode);
            if (Mode == "invalid-json") return System.Text.Encoding.UTF8.GetBytes("{ malformed");
            return System.Text.Encoding.UTF8.GetBytes("{\"version\":\"5.0.0\"}");
        }
    }
}
