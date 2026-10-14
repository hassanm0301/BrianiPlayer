using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json.Nodes;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Preferences;
using Briani.IdentityTests;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
namespace Briani.PreferencesTests;
[System.Runtime.Versioning.SupportedOSPlatform("linux")]
public sealed class AdministratorConfigurationTests:IAsyncLifetime
{
    private readonly IdentityFixture fixture=new();private HttpClient Client=>fixture.Client;
    public async Task InitializeAsync(){await fixture.InitializeAsync();IdentityFixture.As(Client,fixture.Admin.AccessToken);}
    public Task DisposeAsync()=>fixture.DisposeAsync();
    [Fact] public async Task Saves_finish_without_nested_gate_and_apply_curated_policy_and_server_name()
    {
        using var bound=new CancellationTokenSource(TimeSpan.FromSeconds(5));
        var saved=await Client.PutAsJsonAsync("/api/v1/admin/settings",new{version=1,serverName="Local fixtures",activeDownloads=12,activeDownloadsPerUser=10,activeSeeds=0,lowDiskFloorBytes=0,lowDiskFloorFraction=0.0},bound.Token);
        saved.EnsureSuccessStatusCode();Assert.Equal(2,(await saved.Content.ReadFromJsonAsync<JsonObject>())!["version"]!.GetValue<int>());
        var server=(await Client.GetFromJsonAsync<JsonObject>("/api/v1/server",bound.Token))!;Assert.Equal("Local fixtures",server["name"]!.GetValue<string>());
        using var scope=fixture.Host.Services.CreateScope();var policy=await scope.ServiceProvider.GetRequiredService<DownloadAdmission>().PolicyAsync(bound.Token);
        Assert.Equal(12,policy.ActiveGlobal);Assert.Equal(10,policy.ActivePerUser);Assert.Equal(0,policy.ActiveSeeds);Assert.Equal(0,policy.DiskFloorBytes);Assert.Equal(0,policy.DiskFloorFraction);
        var integration=await Client.PutAsJsonAsync("/api/v1/admin/integrations/qbittorrent",new{version=1,baseUrl="http://qbittorrent:8080",username="admin",secret="isolated-test-credential"},bound.Token);
        integration.EnsureSuccessStatusCode();Assert.DoesNotContain("isolated-test-credential",await integration.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.Conflict,(await Client.PutAsJsonAsync("/api/v1/admin/settings",new{version=1,serverName="stale"},bound.Token)).StatusCode);
        Assert.Equal(HttpStatusCode.OK,(await Client.GetAsync("/api/v1/me/preferences",bound.Token)).StatusCode);
    }
    [Theory]
    [InlineData("{\"version\":1,\"publicBaseUrl\":\"https://example.test/path\"}")]
    [InlineData("{\"version\":1,\"uploadLimitBytesPerSecond\":1073741825}")]
    [InlineData("{\"version\":1,\"globalConnections\":5001}")]
    [InlineData("{\"version\":1,\"enabledCategoryIds\":[-1]}")]
    [InlineData("{\"version\":1,\"activeSeeds\":-1}")]
    [InlineData("{\"version\":1,\"rawEngineConfig\":{}}")]
    public async Task Invalid_admin_configuration_cannot_be_saved(string json)
    {
        var response=await Client.PutAsync("/api/v1/admin/settings",new StringContent(json,Encoding.UTF8,"application/json"));Assert.Equal(HttpStatusCode.BadRequest,response.StatusCode);
        Assert.Equal(1,(await Client.GetFromJsonAsync<JsonObject>("/api/v1/admin/settings"))!["version"]!.GetValue<int>());
    }
    [Fact] public async Task Mounted_credentials_are_redacted_rotated_and_preserved_by_origin_update()
    {
        var folder=Path.Combine(fixture.Host.Root,"private-secrets");Directory.CreateDirectory(folder);
        fixture.Host.Services.GetRequiredService<ServerOptions>().SecretsRoot=folder;
        var path=Path.Combine(folder,"qbittorrent-webui-password");await File.WriteAllTextAsync(path,"credential-one\n");File.SetUnixFileMode(path,UnixFileMode.UserRead|UnixFileMode.UserWrite);
        var connections=fixture.Host.Services.GetRequiredService<ServiceConnections>();
        Assert.Equal("credential-one",(await connections.RequiredAsync("qbittorrent")).Secret);
        var exposed=await Client.GetStringAsync("/api/v1/admin/integrations");Assert.DoesNotContain("credential-one",exposed);Assert.Contains("\"credentialConfigured\":true",exposed);
        await File.WriteAllTextAsync(path,"credential-two");Assert.Equal("credential-two",(await connections.RequiredAsync("qbittorrent")).Secret);
        (await Client.PutAsJsonAsync("/api/v1/admin/integrations/qbittorrent",new{version=1,baseUrl="http://qbittorrent:8081"})).EnsureSuccessStatusCode();
        await File.WriteAllTextAsync(path,"credential-three");Assert.Equal("credential-two",(await connections.RequiredAsync("qbittorrent")).Secret);
    }
    [Fact] public async Task Unsafe_mounted_secret_files_never_supply_a_credential()
    {
        var folder=Path.Combine(fixture.Host.Root,"private-secrets");Directory.CreateDirectory(folder);fixture.Host.Services.GetRequiredService<ServerOptions>().SecretsRoot=folder;
        var path=Path.Combine(folder,"prowlarr-api-key");var connections=fixture.Host.Services.GetRequiredService<ServiceConnections>();
        await File.WriteAllTextAsync(path,"private-secret");File.SetUnixFileMode(path,UnixFileMode.UserRead|UnixFileMode.OtherRead);
        Assert.Equal("integration_credential_file_invalid",(await Assert.ThrowsAsync<ApiException>(()=>connections.RequiredAsync("prowlarr"))).Code);
        File.Delete(path);var target=Path.Combine(fixture.Host.Root,"outside-secret");await File.WriteAllTextAsync(target,"never-follow");File.CreateSymbolicLink(path,target);
        await Assert.ThrowsAsync<ApiException>(()=>connections.RequiredAsync("prowlarr"));File.Delete(path);
        await File.WriteAllBytesAsync(path,[0xff,0xfe,0xff]);File.SetUnixFileMode(path,UnixFileMode.UserRead|UnixFileMode.UserWrite);
        Assert.Equal("integration_credential_file_invalid",(await Assert.ThrowsAsync<ApiException>(()=>connections.RequiredAsync("prowlarr"))).Code);
    }
    [Fact] public async Task Reset_keys_are_bounded_and_expired_keys_are_pruned_before_new_reset()
    {
        var prefix=$"preferences-reset:{fixture.Admin.User.Id:D}:";
        await fixture.Host.InDb(async db=>{for(var i=0;i<128;i++)db.Settings.Add(new Setting{Key=prefix+i,ValueJson="{}",UpdatedAt=fixture.Host.Clock.GetUtcNow()});await db.SaveChangesAsync();return true;});
        Client.DefaultRequestHeaders.Add("Idempotency-Key","bounded-reset");
        Assert.Equal(HttpStatusCode.TooManyRequests,(await Client.PostAsJsonAsync("/api/v1/me/preferences/reset",new{version=1})).StatusCode);
        await fixture.Host.InDb(async db=>{await db.Settings.Where(x=>x.Key.StartsWith(prefix)).ExecuteUpdateAsync(x=>x.SetProperty(s=>s.UpdatedAt,fixture.Host.Clock.GetUtcNow().AddDays(-2)));return true;});
        (await Client.PostAsJsonAsync("/api/v1/me/preferences/reset",new{version=1})).EnsureSuccessStatusCode();
        Assert.Equal(1,await fixture.Host.InDb(db=>db.Settings.CountAsync(x=>x.Key.StartsWith(prefix))));
    }
}
