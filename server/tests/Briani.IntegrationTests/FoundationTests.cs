using Microsoft.Data.Sqlite;
using Xunit;
namespace Briani.Tests;
public sealed class FoundationTests
{
    [Fact]
    public async Task RealSqliteMigrationAndReadiness()
    {
        using var host = new TestHost();
        using var client = host.CreateClient();
        var response = await client.GetAsync("/readyz");
        Assert.True(response.IsSuccessStatusCode);
        using var connection = new SqliteConnection($"Data Source={Path.Combine(host.Root, "state/briani.db")}");
        await connection.OpenAsync();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM __EFMigrationsHistory";
        Assert.Equal(12L, await command.ExecuteScalarAsync());
        command.CommandText = "SELECT COUNT(*) FROM __EFMigrationsHistory WHERE MigrationId='20261012183905_UserPreferences'";
        Assert.Equal(1L, await command.ExecuteScalarAsync());
        command.CommandText = "SELECT PlanVersion FROM schema_state";
        Assert.Equal("1.0", await command.ExecuteScalarAsync());
        command.CommandText = "PRAGMA journal_mode";
        Assert.Equal("wal", await command.ExecuteScalarAsync());
        Assert.True(response.Headers.Contains("X-Correlation-Id"));
    }
    [Fact]
    public async Task ErrorsAreSafeProblemResponses()
    {
        using var host = new TestHost(); using var client = host.CreateClient();
        var response = await client.GetAsync("/unknown");
        Assert.Equal(404, (int)response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("traceId", body); Assert.Contains("code", body); Assert.DoesNotContain("Exception", body);
    }
}
