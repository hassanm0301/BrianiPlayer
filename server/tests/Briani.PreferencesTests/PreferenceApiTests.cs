using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json.Nodes;
using Briani.IdentityTests;
using Briani.Api.Modules.Preferences;
using Microsoft.EntityFrameworkCore;
namespace Briani.PreferencesTests;
public sealed class PreferenceApiTests:IAsyncLifetime
{
    private readonly IdentityFixture fixture=new();private HttpClient Client=>fixture.Client;
    public async Task InitializeAsync(){await fixture.InitializeAsync();IdentityFixture.As(Client,fixture.Admin.AccessToken);}
    public Task DisposeAsync()=>fixture.DisposeAsync();
    private async Task<JsonObject> ReadAsync(){var response=await Client.GetAsync("/api/v1/me/preferences");response.EnsureSuccessStatusCode();return (await response.Content.ReadFromJsonAsync<JsonObject>())!;}
    [Fact] public async Task Defaults_are_effective_and_partial_updates_preserve_other_sections()
    {
        var initial=await ReadAsync();Assert.Equal("system",initial["theme"]!.GetValue<string>());Assert.Equal("grid",initial["libraryLayout"]!.GetValue<string>());
        Assert.Equal(5,initial["slideshowSeconds"]!.GetValue<int>());Assert.Equal(1,initial["version"]!.GetValue<long>());
        var change=await Client.PutAsJsonAsync("/api/v1/me/preferences",new{version=1,theme="dark",defaultPlaybackSpeed=1.25});change.EnsureSuccessStatusCode();
        var updated=await ReadAsync();Assert.Equal("dark",updated["theme"]!.GetValue<string>());Assert.Equal(1.25,updated["defaultPlaybackSpeed"]!.GetValue<double>());
        Assert.Equal("grid",updated["libraryLayout"]!.GetValue<string>());Assert.Equal(2,updated["version"]!.GetValue<long>());
        Assert.Equal(HttpStatusCode.Conflict,(await Client.PutAsJsonAsync("/api/v1/me/preferences",new{version=1,density="compact"})).StatusCode);
    }
    [Theory]
    [InlineData("{\"version\":1,\"role\":\"administrator\"}")]
    [InlineData("{\"version\":1,\"cacheBytes\":999999999}")]
    [InlineData("{\"version\":1,\"theme\":\"script\"}")]
    [InlineData("{\"version\":1,\"defaultPlaybackSpeed\":5}")]
    [InlineData("{\"version\":1,\"subtitleScale\":0.1}")]
    [InlineData("{\"version\":1,\"slideshowSeconds\":0}")]
    [InlineData("{\"version\":1,\"showContinueWatching\":\"yes\"}")]
    [InlineData("{\"version\":1,\"pinnedLibraryIds\":[\"/etc/passwd\"]}")]
    [InlineData("{\"version\":1,\"folderPreferences\":[{\"libraryId\":\"11111111-1111-1111-1111-111111111111\",\"folderId\":null,\"layout\":\"grid\",\"sort\":\"name\",\"order\":\"asc\",\"path\":\"/etc\"}]}")]
    [InlineData("{\"version\":1,\"theme\":\"dark\",\"theme\":\"light\"}")]
    public async Task Unrecognized_or_invalid_values_are_rejected_without_write(string json)
    {
        var response=await Client.PutAsync("/api/v1/me/preferences",new StringContent(json,Encoding.UTF8,"application/json"));
        Assert.Equal(HttpStatusCode.BadRequest,response.StatusCode);Assert.Equal(1,(await ReadAsync())["version"]!.GetValue<long>());
    }
    [Fact] public async Task Concurrent_changes_have_one_winner_and_version_conflict()
    {
        var changes=await Task.WhenAll(Client.PutAsJsonAsync("/api/v1/me/preferences",new{version=1,theme="dark"}),Client.PutAsJsonAsync("/api/v1/me/preferences",new{version=1,theme="light"}));
        Assert.Single(changes,x=>x.StatusCode==HttpStatusCode.OK);Assert.Single(changes,x=>x.StatusCode==HttpStatusCode.Conflict);
        Assert.Equal(2,(await ReadAsync())["version"]!.GetValue<long>());
    }
    [Fact] public async Task Reset_is_versioned_idempotent_and_does_not_revoke_credentials()
    {
        (await Client.PutAsJsonAsync("/api/v1/me/preferences",new{version=1,theme="dark"})).EnsureSuccessStatusCode();
        Client.DefaultRequestHeaders.Add("Idempotency-Key","same-reset");
        var first=await Client.PostAsJsonAsync("/api/v1/me/preferences/reset",new{version=2});first.EnsureSuccessStatusCode();
        var repeated=await Client.PostAsJsonAsync("/api/v1/me/preferences/reset",new{version=2});repeated.EnsureSuccessStatusCode();
        Assert.Equal(await first.Content.ReadAsStringAsync(),await repeated.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.Conflict,(await Client.PostAsJsonAsync("/api/v1/me/preferences/reset",new{version=3})).StatusCode);
        var after=await ReadAsync();Assert.Equal("system",after["theme"]!.GetValue<string>());Assert.Equal(3,after["version"]!.GetValue<long>());
        Assert.Equal(HttpStatusCode.OK,(await Client.GetAsync("/api/v1/me")).StatusCode);
    }
    [Fact] public async Task Preferences_are_isolated_by_authenticated_user_and_do_not_grant_admin_access()
    {
        var created=await Client.PostAsJsonAsync("/api/v1/admin/users",new{username="prefmember",displayName="Member",password=TestPasswords.Member,confirmPassword=TestPasswords.Member,role="member"});created.EnsureSuccessStatusCode();
        var login=await Client.PostAsJsonAsync("/api/v1/auth/login",new{username="prefmember",password=TestPasswords.Member,deviceName="Test"});
        var tokens=(await login.Content.ReadFromJsonAsync<AuthReply>())!;
        (await Client.PutAsJsonAsync("/api/v1/me/preferences",new{version=1,theme="dark"})).EnsureSuccessStatusCode();
        using var member=IdentityFixture.As(fixture.Host.CreateClient(),tokens.AccessToken);
        var own=(await (await member.GetAsync("/api/v1/me/preferences")).Content.ReadFromJsonAsync<JsonObject>())!;
        Assert.Equal("system",own["theme"]!.GetValue<string>());
        Assert.Equal(HttpStatusCode.Forbidden,(await member.GetAsync("/api/v1/admin/users")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest,(await member.PutAsJsonAsync("/api/v1/me/preferences",new{version=1,userId=fixture.Admin.User.Id,theme="light"})).StatusCode);
        Assert.Equal("dark",(await ReadAsync())["theme"]!.GetValue<string>());
    }
    [Fact] public async Task Damaged_saved_preferences_fail_safely_and_explicit_reset_repairs_them()
    {
        await fixture.Host.InDb(async db=>{db.UserPreferences.Add(new(){UserId=fixture.Admin.User.Id,SettingsJson="{not-json",Version=1});await db.SaveChangesAsync();return true;});
        Assert.Equal(HttpStatusCode.ServiceUnavailable,(await Client.GetAsync("/api/v1/me/preferences")).StatusCode);
        (await Client.PostAsJsonAsync("/api/v1/me/preferences/reset",new{version=1})).EnsureSuccessStatusCode();
        Assert.Equal("system",(await ReadAsync())["theme"]!.GetValue<string>());
    }
}
