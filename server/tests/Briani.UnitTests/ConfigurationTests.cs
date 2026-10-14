using Briani.Api.Infrastructure;
using Xunit;
namespace Briani.Tests;
public sealed class ConfigurationTests
{
    [Theory]
    [InlineData("relative", "/data", false)]
    [InlineData("/config", "/config", false)]
    [InlineData("/config", "/data", true)]
    public void RootsMustBeDistinctAndAbsolute(string state, string data, bool expected)
        => Assert.Equal(expected, new ServerOptions { StateRoot = state, DataRoot = data }.Valid());
}
