using System.Text.Json;
using Xunit;
namespace Briani.Tests;
public sealed class ContractTests
{
    [Fact]
    public async Task ServerInfoMatchesFrozenWireShape()
    {
        using var host = new TestHost(); using var client = host.CreateClient();
        using var json = JsonDocument.Parse(await client.GetStringAsync("/api/v1/server"));
        var data = json.RootElement;
        Assert.Equal("Briani Player", data.GetProperty("name").GetString());
        Assert.Equal(1, data.GetProperty("apiMajor").GetInt64());
        Assert.NotEmpty(data.GetProperty("version").GetString()!);
        Assert.Equal(JsonValueKind.True, data.GetProperty("bootstrapRequired").ValueKind);
        Assert.Equal(JsonValueKind.Array, data.GetProperty("capabilities").ValueKind);
        Assert.False(data.TryGetProperty("serverVersion", out _));
    }
}
