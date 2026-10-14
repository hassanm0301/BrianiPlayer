using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
namespace Briani.Tests;
public sealed class TestHost : WebApplicationFactory<Program>
{
    public string Root { get; } = Path.Combine(Path.GetTempPath(), "briani-tests-" + Guid.NewGuid());
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Briani:StateRoot"] = Path.Combine(Root, "state"), ["Briani:DataRoot"] = Path.Combine(Root, "data")
        }));
    }
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(Root)) Directory.Delete(Root, true);
    }
}
