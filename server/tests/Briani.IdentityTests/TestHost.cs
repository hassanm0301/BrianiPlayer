using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Briani.IdentityTests;

public sealed class TestHost : WebApplicationFactory<Program>
{
    public string Root { get; } = Path.Combine(Path.GetTempPath(), "briani-identity-" + Guid.NewGuid());
    public ManualClock Clock { get; } = new(new DateTimeOffset(2026, 1, 2, 3, 4, 5, TimeSpan.Zero));

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Briani:StateRoot"] = Path.Combine(Root, "state"), ["Briani:DataRoot"] = Path.Combine(Root, "data")
        }));
        builder.ConfigureTestServices(services => services.RemoveAll<TimeProvider>().AddSingleton<TimeProvider>(Clock));
    }

    public string BootstrapCode()
    {
        var path = Path.Combine(Root, "state", "bootstrap.code");
        return File.ReadAllText(path);
    }

    public async Task<T> InDb<T>(Func<BrianiDb, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<BrianiDb>());
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(Root)) Directory.Delete(Root, true);
    }
}

public sealed class ManualClock(DateTimeOffset now) : TimeProvider
{
    private DateTimeOffset current = now;
    public override DateTimeOffset GetUtcNow() => current;
    public void Advance(TimeSpan amount) => current = current.Add(amount);
}

public sealed class IdentityFixture : IAsyncLifetime
{
    public TestHost Host { get; } = new();
    public HttpClient Client { get; private set; } = null!;
    public AuthReply Admin { get; private set; } = null!;
    public async Task InitializeAsync()
    {
        Client = Host.CreateClient();
        Admin = await Bootstrap(Client, Host.BootstrapCode(), "rootuser", "Root User", TestPasswords.Root);
    }
    public Task DisposeAsync() { Client.Dispose(); Host.Dispose(); return Task.CompletedTask; }
    public static async Task<AuthReply> Bootstrap(HttpClient client, string code, string username, string display, string password)
    {
        using var response = await client.PostAsJsonAsync("/api/v1/bootstrap", new { code, username, displayName = display, password });
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<AuthReply>())!;
    }
    public static HttpClient As(HttpClient client, string token)
    {
        client.DefaultRequestHeaders.Authorization = new("Bearer", token);
        return client;
    }
}

public sealed record AuthReply(string AccessToken, DateTimeOffset AccessExpiresAt, string RefreshToken, DateTimeOffset RefreshExpiresAt, Guid SessionId, UserReply User);
public sealed record UserReply(Guid Id, string Username, string DisplayName, string Role, bool Enabled, long Version);

public static class TestPasswords
{
    public static readonly string Root = New();
    public static readonly string Replacement = New();
    public static readonly string Member = New();
    public static readonly string BootstrapRace = New();
    public static readonly string Initial = New();
    public static readonly string Reset = New();
    public static readonly string Wrong = New();
    public static readonly string OwnSession = New();
    public static readonly string Grant = New();
    private static string New() => "T-" + Credentials.NewToken();
}
