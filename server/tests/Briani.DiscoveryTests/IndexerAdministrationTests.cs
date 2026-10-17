using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Nodes;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.Prowlarr;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DiscoveryTests;

// Runs the real transport and SafeHttp against a loopback Prowlarr stand-in, so the API key,
// the operation allowlist and the redaction are exercised on the actual request path.
public sealed class IndexerAdministrationTests : IAsyncLifetime
{
    private const string CookieSecret = "cookie-secret-value-1";
    private const string PasswordSecret = "password-secret-value-2";
    private const string NativeSecret = "native-pid-secret-3";
    private readonly TestHost host = new();
    private readonly FakeProwlarr prowlarr = new();
    private HttpClient client = null!;
    private AuthReply admin = null!;

    public async Task InitializeAsync()
    {
        client = host.CreateClient();
        admin = await IdentityFixture.Bootstrap(client, host.BootstrapCode(), "indexer-admin", "Indexer Admin", TestPasswords.Root);
        IdentityFixture.As(client, admin.AccessToken);
        using var saved = await client.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = prowlarr.Origin.AbsoluteUri, version = 1, secret = prowlarr.ApiKey });
        saved.EnsureSuccessStatusCode();
    }

    public Task DisposeAsync()
    {
        client.Dispose(); prowlarr.Dispose(); host.Dispose();
        return Task.CompletedTask;
    }

    public static TheoryData<string, string> Routes => new()
    {
        { "GET", "/api/v1/admin/indexers" },
        { "POST", "/api/v1/admin/indexers" },
        { "PATCH", "/api/v1/admin/indexers/1" },
        { "DELETE", "/api/v1/admin/indexers/1" },
        { "POST", "/api/v1/admin/indexers/1/test" },
        { "GET", "/api/v1/admin/indexers/definitions" },
        { "GET", "/api/v1/admin/indexers/definitions/brianifixture" },
    };

    [Theory]
    [MemberData(nameof(Routes))]
    public async Task Members_get_forbidden_and_anonymous_callers_unauthorized_without_reaching_Prowlarr(string method, string path)
    {
        prowlarr.Seed("brianifixture", "Seeded", true, new Dictionary<string, JsonNode?> { ["apikey"] = FakeProwlarr.GoodKey });
        using var created = await client.PostAsJsonAsync("/api/v1/admin/users", new { username = "indexer-member", displayName = "Member", password = TestPasswords.Member, confirmPassword = TestPasswords.Member, role = "member" });
        created.EnsureSuccessStatusCode();
        using var anonymous = host.CreateClient();
        using var login = await anonymous.PostAsJsonAsync("/api/v1/auth/login", new { username = "indexer-member", password = TestPasswords.Member, deviceName = "test" });
        var member = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        Assert.Equal("member", member.User.Role);
        using var memberClient = IdentityFixture.As(host.CreateClient(), member.AccessToken);

        Func<HttpRequestMessage> request = () => new HttpRequestMessage(new HttpMethod(method), path)
        {
            Content = method is "POST" or "PATCH" ? JsonContent.Create(path.EndsWith("/test") ? new { } : method == "PATCH" ? (object)new { enabled = false } : new { definition = "brianifixture" }) : null
        };
        using var asMember = await memberClient.SendAsync(request());
        Assert.Equal(HttpStatusCode.Forbidden, asMember.StatusCode);
        using var asAnonymous = await anonymous.SendAsync(request());
        Assert.Equal(HttpStatusCode.Unauthorized, asAnonymous.StatusCode);
        Assert.Empty(prowlarr.Requests);
        Assert.True(prowlarr.Exists(1));
    }

    [Fact]
    public async Task List_returns_summaries_without_field_values_or_credentials()
    {
        var seeded = prowlarr.Seed("fixturecookie", "Cookie tracker", true, new Dictionary<string, JsonNode?>
        {
            ["cookie"] = CookieSecret, ["username"] = "tracker-user-name", ["password"] = PasswordSecret
        });
        var native = prowlarr.Seed("FixtureNative", "Native tracker", false, new Dictionary<string, JsonNode?> { ["pid"] = NativeSecret, ["password"] = PasswordSecret });
        prowlarr.Seed("fixtureusenet", "Usenet only", true, new Dictionary<string, JsonNode?>(), protocol: "usenet");
        prowlarr.Status.Add(new JsonObject { ["indexerId"] = seeded, ["disabledTill"] = "2099-01-01T00:00:00Z", ["mostRecentFailure"] = "2026-01-02T03:00:00Z" });

        using var response = await client.GetAsync("/api/v1/admin/indexers");
        var text = await response.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        foreach (var secret in new[] { CookieSecret, PasswordSecret, NativeSecret, "tracker-user-name", prowlarr.ApiKey, "fields", "********" })
            Assert.DoesNotContain(secret, text, StringComparison.Ordinal);
        using var document = JsonDocument.Parse(text);
        var items = document.RootElement.EnumerateArray().ToArray();
        Assert.Equal(new[] { "Cookie tracker", "Native tracker" }, items.Select(x => x.GetProperty("name").GetString()!).ToArray());
        var cookie = items[0];
        Assert.Equal(seeded.ToString(), cookie.GetProperty("id").GetString());
        Assert.Equal("fixturecookie", cookie.GetProperty("definition").GetString());
        Assert.Equal("private", cookie.GetProperty("privacy").GetString());
        Assert.Equal("unavailable", cookie.GetProperty("state").GetString());
        Assert.Equal("Prowlarr has paused this indexer after repeated failures.", cookie.GetProperty("stateDetail").GetString());
        Assert.False(items[1].GetProperty("enabled").GetBoolean());
        Assert.Equal(native.ToString(), items[1].GetProperty("id").GetString());
        Assert.All(prowlarr.Requests, x => Assert.Equal(prowlarr.ApiKey, x.ApiKey));
        Assert.Empty(prowlarr.Unexpected);
    }

    [Fact]
    public async Task Definitions_offer_only_plainly_renderable_torrent_definitions()
    {
        using var response = await client.GetAsync("/api/v1/admin/indexers/definitions");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var byKey = document.RootElement.EnumerateArray().ToDictionary(x => x.GetProperty("key").GetString()!);
        Assert.DoesNotContain("fixtureusenet", byKey.Keys);
        foreach (var key in new[] { "brianifixture", "fixturepublic", "fixturecookie", "FixtureNative" })
        {
            Assert.True(byKey[key].GetProperty("addable").GetBoolean(), key);
            Assert.Equal(JsonValueKind.Null, byKey[key].GetProperty("setupNote").ValueKind);
        }
        Assert.Equal("This indexer type is set up in Prowlarr's own page.", byKey["Torznab-1"].GetProperty("setupNote").GetString());
        Assert.False(byKey["Torznab-2"].GetProperty("addable").GetBoolean());
        Assert.Contains("CAPTCHA", byKey["fixturecaptcha"].GetProperty("setupNote").GetString());
        Assert.Contains("FlareSolverr", byKey["fixtureflare"].GetProperty("setupNote").GetString());
        Assert.Equal("public", byKey["fixturepublic"].GetProperty("privacy").GetString());
        // Native definitions are named after their implementation, spaces included.
        Assert.True(byKey["Fixture-Spaced-Native"].GetProperty("addable").GetBoolean());
        Assert.Equal("Fixture Spaced", byKey["Fixture-Spaced-Native"].GetProperty("name").GetString());
        Assert.Equal(byKey.Keys.Order(StringComparer.OrdinalIgnoreCase).Count(), byKey.Count);
    }

    [Fact]
    public async Task A_unique_free_form_address_definition_is_still_left_to_Prowlarr()
    {
        prowlarr.Schema.RemoveAt(prowlarr.Schema.Select((x, i) => (x, i)).Last(x => (string?)x.x!["definitionName"] == "Torznab").i);
        using var response = await client.GetFromJsonAsync<JsonDocument>("/api/v1/admin/indexers/definitions/Torznab");
        Assert.False(response!.RootElement.GetProperty("addable").GetBoolean());
        Assert.Equal("This indexer uses a site address you type in yourself, so it is set up in Prowlarr's own page.", response.RootElement.GetProperty("setupNote").GetString());
        Assert.Empty(response.RootElement.GetProperty("fields").EnumerateArray());
    }

    [Fact]
    public async Task Definition_detail_never_returns_secret_defaults_and_shows_html_as_plain_text()
    {
        var entry = prowlarr.Schema.OfType<JsonObject>().First(x => (string?)x["definitionName"] == "fixturecookie");
        entry["fields"]!.AsArray().OfType<JsonObject>().First(x => (string?)x["name"] == "cookie")["value"] = "schema-default-secret";

        using var cookie = await client.GetAsync("/api/v1/admin/indexers/definitions/fixturecookie");
        var text = await cookie.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.OK, cookie.StatusCode);
        Assert.DoesNotContain("schema-default-secret", text, StringComparison.Ordinal);
        Assert.DoesNotContain("<", text, StringComparison.Ordinal);
        using var document = JsonDocument.Parse(text);
        var fields = document.RootElement.GetProperty("fields").EnumerateArray().ToDictionary(x => x.GetProperty("name").GetString()!);
        Assert.Equal(new[] { "baseUrl", "cookie", "info_cookie", "username", "password" },
            document.RootElement.GetProperty("fields").EnumerateArray().Select(x => x.GetProperty("name").GetString()!).ToArray());
        Assert.Equal("secret", fields["cookie"].GetProperty("kind").GetString());
        Assert.Equal(JsonValueKind.Null, fields["cookie"].GetProperty("value").ValueKind);
        Assert.Equal("secret", fields["password"].GetProperty("kind").GetString());
        Assert.Equal("text", fields["username"].GetProperty("kind").GetString());
        Assert.Equal("info", fields["info_cookie"].GetProperty("kind").GetString());
        Assert.Equal("• Login to this tracker with your browser\n• Copy the cookie", fields["info_cookie"].GetProperty("value").GetString());
        Assert.Equal("select", fields["baseUrl"].GetProperty("kind").GetString());
        Assert.Equal("https://fixturecookie.invalid/", fields["baseUrl"].GetProperty("value").GetString());
        Assert.Equal(new[] { "https://fixturecookie.invalid/", "https://mirror.fixturecookie.invalid/" },
            fields["baseUrl"].GetProperty("options").EnumerateArray().Select(x => x.GetProperty("value").GetString()!).ToArray());

        using var native = await client.GetFromJsonAsync<JsonDocument>("/api/v1/admin/indexers/definitions/FixtureNative");
        var nativeFields = native!.RootElement.GetProperty("fields").EnumerateArray().ToDictionary(x => x.GetProperty("name").GetString()!);
        Assert.Equal("secret", nativeFields["pid"].GetProperty("kind").GetString());
        Assert.Equal("text", nativeFields["username"].GetProperty("kind").GetString());
        Assert.Equal("Site Username Only member rank and above can use the API on this indexer.", nativeFields["username"].GetProperty("helpText").GetString());
        Assert.Equal("checkbox", nativeFields["freeleechOnly"].GetProperty("kind").GetString());
        Assert.Equal("false", nativeFields["freeleechOnly"].GetProperty("value").GetString());
        Assert.Equal("decimal", nativeFields["minimumRatio"].GetProperty("kind").GetString());
        Assert.True(nativeFields["minimumRatio"].GetProperty("advanced").GetBoolean());
        Assert.DoesNotContain(nativeFields.Keys, x => x.StartsWith("baseSettings.") || x.StartsWith("torrentBaseSettings.") || x == "definitionFile");

        using var blocked = await client.GetFromJsonAsync<JsonDocument>("/api/v1/admin/indexers/definitions/fixturecaptcha");
        Assert.Empty(blocked!.RootElement.GetProperty("fields").EnumerateArray());
        using var missing = await client.GetAsync("/api/v1/admin/indexers/definitions/no-such-definition");
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Single(prowlarr.Calls("GET", "/api/v1/indexer/schema"));
    }

    [Fact]
    public async Task Create_sends_typed_values_with_the_first_sync_profile_and_returns_no_secret()
    {
        using var response = await client.PostAsJsonAsync("/api/v1/admin/indexers", new
        {
            definition = "brianifixture", name = "Local fixture", settings = new Dictionary<string, string> { ["apikey"] = FakeProwlarr.GoodKey, ["sort"] = "1", ["freeleech"] = "true" }
        });
        var text = await response.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.DoesNotContain(FakeProwlarr.GoodKey, text, StringComparison.Ordinal);
        using var document = JsonDocument.Parse(text);
        Assert.Equal("Local fixture", document.RootElement.GetProperty("name").GetString());
        Assert.True(document.RootElement.GetProperty("enabled").GetBoolean());
        var id = int.Parse(document.RootElement.GetProperty("id").GetString()!);
        Assert.Equal($"/api/v1/admin/indexers/{id}", response.Headers.Location?.OriginalString);

        var sent = JsonNode.Parse(prowlarr.Calls("POST", "/api/v1/indexer").Single().Body)!.AsObject();
        Assert.Equal(3, (int)sent["appProfileId"]!);
        Assert.Equal("Local fixture", (string?)sent["name"]);
        Assert.True((bool)sent["enable"]!);
        var fields = sent["fields"]!.AsArray().OfType<JsonObject>().ToDictionary(x => (string)x["name"]!);
        Assert.Equal(FakeProwlarr.GoodKey, (string?)fields["apikey"]["value"]);
        Assert.Equal(JsonValueKind.Number, fields["sort"]["value"]!.GetValueKind());
        Assert.Equal(1, (long)fields["sort"]["value"]!);
        Assert.True((bool)fields["freeleech"]["value"]!);
        Assert.Equal("brianifixture", (string?)fields["definitionFile"]["value"]);
        Assert.Null(fields["baseUrl"]["value"]);
        Assert.True(prowlarr.Exists(id));
        Assert.Equal(1, await host.InDb(db => db.AuditEvents.CountAsync(x => x.Action == "indexer.created" && x.TargetId == id.ToString())));
        Assert.Empty(prowlarr.Unexpected);
    }

    [Fact]
    public async Task Create_reports_Prowlarr_rejection_without_addresses_or_setting_values()
    {
        using var response = await client.PostAsJsonAsync("/api/v1/admin/indexers", new
        {
            definition = "brianifixture", settings = new Dictionary<string, string> { ["apikey"] = "wrong-key-typed-by-admin" }
        });
        var text = await response.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.DoesNotContain("wrong-key-typed-by-admin", text, StringComparison.Ordinal);
        Assert.DoesNotContain("https://", text, StringComparison.Ordinal);
        Assert.DoesNotContain("passkey=", text, StringComparison.Ordinal);
        using var problem = JsonDocument.Parse(text);
        Assert.Equal("indexer_rejected", problem.RootElement.GetProperty("code").GetString());
        Assert.Equal("Prowlarr did not add this indexer: Unable to connect to indexer. HTTP request failed: [401:Unauthorized] [GET] at [(address hidden)]",
            problem.RootElement.GetProperty("detail").GetString());

        prowlarr.Seed("fixturepublic", "Taken name", false, new Dictionary<string, JsonNode?>());
        using var duplicate = await client.PostAsJsonAsync("/api/v1/admin/indexers", new { definition = "fixturepublic", name = "Taken name" });
        using var duplicateProblem = JsonDocument.Parse(await duplicate.Content.ReadAsStringAsync());
        Assert.Equal("Prowlarr did not add this indexer: Name: Should be unique", duplicateProblem.RootElement.GetProperty("detail").GetString());
        Assert.Equal(0, await host.InDb(db => db.AuditEvents.CountAsync(x => x.Action == "indexer.created")));
    }

    public static TheoryData<string, string, string, int> InvalidCreates => new()
    {
        { "brianifixture", "bogus", "x", 400 },
        { "fixturecookie", "info_cookie", "x", 400 },
        { "fixturecookie", "definitionFile", "elsewhere", 400 },
        { "fixturecookie", "baseSettings.queryLimit", "5", 400 },
        { "fixturecookie", "baseUrl", "http://169.254.169.254/", 400 },
        { "brianifixture", "sort", "7", 400 },
        { "brianifixture", "freeleech", "yes", 400 },
        { "FixtureNative", "minimumRatio", "lots", 400 },
        { "brianifixture", "apikey", "line\nbreak", 400 },
        { "fixturecaptcha", "username", "x", 409 },
        { "Torznab-1", "baseUrl", "http://127.0.0.1:8080/", 409 },
        { "no-such-definition", "apikey", "x", 404 },
        { "../system", "apikey", "x", 404 },
    };

    [Theory]
    [MemberData(nameof(InvalidCreates))]
    public async Task Create_validates_definition_and_settings_before_writing_to_Prowlarr(string definition, string field, string value, int status)
    {
        using var response = await client.PostAsJsonAsync("/api/v1/admin/indexers", new { definition, settings = new Dictionary<string, string> { [field] = value } });
        Assert.Equal((HttpStatusCode)status, response.StatusCode);
        if (value.Length > 3) Assert.DoesNotContain(value, await response.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        Assert.Empty(prowlarr.Calls("POST", "/api/v1/indexer"));
        Assert.Empty(prowlarr.Unexpected);
    }

    [Fact]
    public async Task Create_rejects_unknown_request_members()
    {
        using var response = await client.PostAsJsonAsync("/api/v1/admin/indexers", new { definition = "brianifixture", path = "/api/v1/system/shutdown" });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Empty(prowlarr.Requests);
    }

    [Fact]
    public async Task Toggle_round_trips_the_stored_resource_and_leaves_unchanged_state_alone()
    {
        var id = prowlarr.Seed("FixtureNative", "Native tracker", true, new Dictionary<string, JsonNode?> { ["pid"] = NativeSecret, ["password"] = PasswordSecret, ["username"] = "someone" });

        using var disabled = await client.PatchAsJsonAsync($"/api/v1/admin/indexers/{id}", new { enabled = false });
        var text = await disabled.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
        Assert.False(JsonDocument.Parse(text).RootElement.GetProperty("enabled").GetBoolean());
        Assert.DoesNotContain(NativeSecret, text, StringComparison.Ordinal);
        var stored = prowlarr.Stored(id);
        Assert.False((bool)stored["enable"]!);
        // Prowlarr masks native secrets on read and restores them from ******** on write.
        Assert.Equal(NativeSecret, (string?)stored["fields"]!.AsArray().OfType<JsonObject>().First(x => (string?)x["name"] == "pid")["value"]);
        Assert.Single(prowlarr.Calls("PUT", $"/api/v1/indexer/{id}"));

        using var again = await client.PatchAsJsonAsync($"/api/v1/admin/indexers/{id}", new { enabled = false });
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Single(prowlarr.Calls("PUT", $"/api/v1/indexer/{id}"));
        Assert.Equal(1, await host.InDb(db => db.AuditEvents.CountAsync(x => x.Action == "indexer.disabled")));
    }

    [Fact]
    public async Task Enabling_a_failing_indexer_reports_the_scrubbed_reason_and_keeps_it_disabled()
    {
        var id = prowlarr.Seed("brianifixture", "Stale key", false, new Dictionary<string, JsonNode?> { ["apikey"] = "stored-stale-key-value" });
        using var response = await client.PatchAsJsonAsync($"/api/v1/admin/indexers/{id}", new { enabled = true });
        var text = await response.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.DoesNotContain("stored-stale-key-value", text, StringComparison.Ordinal);
        Assert.Contains("Prowlarr did not enable this indexer: Unable to connect to indexer.", text, StringComparison.Ordinal);
        Assert.False((bool)prowlarr.Stored(id)["enable"]!);
        Assert.Equal(0, await host.InDb(db => db.AuditEvents.CountAsync(x => x.Action == "indexer.enabled")));
    }

    [Fact]
    public async Task Test_reports_health_and_scrubs_stored_secrets()
    {
        var good = prowlarr.Seed("brianifixture", "Good", true, new Dictionary<string, JsonNode?> { ["apikey"] = FakeProwlarr.GoodKey });
        var bad = prowlarr.Seed("fixturecookie", "Bad cookie", true, new Dictionary<string, JsonNode?> { ["cookie"] = CookieSecret, ["password"] = PasswordSecret });

        using var passed = await client.PostAsync($"/api/v1/admin/indexers/{good}/test", null);
        using var passedBody = JsonDocument.Parse(await passed.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.OK, passed.StatusCode);
        Assert.Equal("healthy", passedBody.RootElement.GetProperty("state").GetString());
        Assert.Equal(good.ToString(), passedBody.RootElement.GetProperty("id").GetString());
        Assert.Equal(host.Clock.GetUtcNow(), passedBody.RootElement.GetProperty("checkedAt").GetDateTimeOffset());

        using var failed = await client.PostAsync($"/api/v1/admin/indexers/{bad}/test", null);
        var text = await failed.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.OK, failed.StatusCode);
        Assert.DoesNotContain(CookieSecret, text, StringComparison.Ordinal);
        Assert.DoesNotContain("https://", text, StringComparison.Ordinal);
        using var failedBody = JsonDocument.Parse(text);
        Assert.Equal("unavailable", failedBody.RootElement.GetProperty("state").GetString());
        Assert.StartsWith("Unable to connect to indexer.", failedBody.RootElement.GetProperty("detail").GetString());
        // The stored resource is sent back to Prowlarr's test endpoint, not reconstructed.
        Assert.Contains(CookieSecret, prowlarr.Calls("POST", "/api/v1/indexer/test").Last().Body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Delete_checks_existence_and_protocol_before_removing()
    {
        var torrent = prowlarr.Seed("fixturepublic", "Public", true, new Dictionary<string, JsonNode?>());
        var usenet = prowlarr.Seed("fixtureusenet", "Usenet", true, new Dictionary<string, JsonNode?>(), protocol: "usenet");

        using var unknown = await client.DeleteAsync("/api/v1/admin/indexers/999");
        Assert.Equal(HttpStatusCode.NotFound, unknown.StatusCode);
        Assert.DoesNotContain("ModelNotFoundException", await unknown.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        using var outOfScope = await client.DeleteAsync($"/api/v1/admin/indexers/{usenet}");
        Assert.Equal(HttpStatusCode.NotFound, outOfScope.StatusCode);
        Assert.Empty(prowlarr.Calls("DELETE", "/api/v1/indexer"));
        Assert.True(prowlarr.Exists(usenet));

        using var removed = await client.DeleteAsync($"/api/v1/admin/indexers/{torrent}");
        Assert.Equal(HttpStatusCode.NoContent, removed.StatusCode);
        Assert.False(prowlarr.Exists(torrent));
        Assert.Equal(1, await host.InDb(db => db.AuditEvents.CountAsync(x => x.Action == "indexer.deleted" && x.TargetId == torrent.ToString())));
    }

    [Theory]
    [InlineData("0")]
    [InlineData("-1")]
    [InlineData("abc")]
    [InlineData("1.0")]
    [InlineData("2147483648")]
    [InlineData("01234567890")]
    [InlineData("%2E%2E")]
    [InlineData("1%2F..%2F..%2Fsystem%2Fstatus")]
    public async Task Malformed_ids_are_not_found_without_upstream_calls(string id)
    {
        using var patch = await client.PatchAsJsonAsync($"/api/v1/admin/indexers/{id}", new { enabled = true });
        Assert.Equal(HttpStatusCode.NotFound, patch.StatusCode);
        using var test = await client.PostAsync($"/api/v1/admin/indexers/{id}/test", null);
        Assert.Equal(HttpStatusCode.NotFound, test.StatusCode);
        using var delete = await client.DeleteAsync($"/api/v1/admin/indexers/{id}");
        Assert.Equal(HttpStatusCode.NotFound, delete.StatusCode);
        Assert.Empty(prowlarr.Requests);
    }

    [Fact]
    public async Task List_rechecks_the_live_administrator_after_Prowlarr_answers()
    {
        prowlarr.Pause = new(TaskCreationOptions.RunContinuationsAsynchronously);
        var pending = client.GetAsync("/api/v1/admin/indexers");
        await prowlarr.Entered.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await host.InDb(async db =>
        {
            var user = await db.Users.SingleAsync(x => x.Id == admin.User.Id);
            user.Role = "member";
            return await db.SaveChangesAsync();
        });
        prowlarr.Pause.TrySetResult();
        using var response = await pending.WaitAsync(TimeSpan.FromSeconds(5));
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Rejected_Prowlarr_key_maps_to_a_safe_problem()
    {
        var wrongKey = "wrong-" + Credentials.NewToken();
        using var saved = await client.PutAsJsonAsync("/api/v1/admin/integrations/prowlarr", new { baseUrl = prowlarr.Origin.AbsoluteUri, version = 2, secret = wrongKey });
        saved.EnsureSuccessStatusCode();
        using var response = await client.GetAsync("/api/v1/admin/indexers");
        var text = await response.Content.ReadAsStringAsync();
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Contains("prowlarr_credentials_rejected", text, StringComparison.Ordinal);
        Assert.DoesNotContain(wrongKey, text, StringComparison.Ordinal);
        Assert.Equal(wrongKey, prowlarr.Requests.Last().ApiKey);
    }

    [Theory]
    [InlineData("GET", "/api/v1/indexer", true)]
    [InlineData("GET", "/api/v1/indexer/42", true)]
    [InlineData("GET", "/api/v1/indexer/schema", true)]
    [InlineData("GET", "/api/v1/indexerstatus", true)]
    [InlineData("GET", "/api/v1/appprofile", true)]
    [InlineData("POST", "/api/v1/indexer", true)]
    [InlineData("PUT", "/api/v1/indexer/42", true)]
    [InlineData("POST", "/api/v1/indexer/test", true)]
    [InlineData("DELETE", "/api/v1/indexer/42", true)]
    [InlineData("GET", "/api/v1/system/status", false)]
    [InlineData("GET", "/api/v1/config/host", false)]
    [InlineData("PUT", "/api/v1/config/host", false)]
    [InlineData("POST", "/api/v1/indexer/testall", false)]
    [InlineData("POST", "/api/v1/indexer/action/getUrls", false)]
    [InlineData("PUT", "/api/v1/indexer/bulk", false)]
    [InlineData("DELETE", "/api/v1/indexer/bulk", false)]
    [InlineData("DELETE", "/api/v1/indexer", false)]
    [InlineData("POST", "/api/v1/indexer/42", false)]
    [InlineData("GET", "/api/v1/indexer/0", false)]
    [InlineData("GET", "/api/v1/indexer/42/download", false)]
    [InlineData("GET", "/api/v1/indexer/42/newznab", false)]
    [InlineData("GET", "/api/v1/indexer/42/../../system/status", false)]
    [InlineData("GET", "/api/v1/indexer?apikey=x", false)]
    [InlineData("GET", "/api/v1/indexer/", false)]
    [InlineData("GET", "/API/V1/INDEXER", false)]
    [InlineData("PATCH", "/api/v1/indexer/42", false)]
    [InlineData("POST", "/api/v1/command", false)]
    public void Prowlarr_path_allowlist_permits_only_the_fixed_operations(string method, string path, bool allowed) =>
        Assert.Equal(allowed, ProwlarrCall.Permits(new HttpMethod(method), path));

    [Fact]
    public void Every_operation_factory_produces_an_allowlisted_call()
    {
        var body = "{}"u8.ToArray();
        ProwlarrCall[] calls =
        [
            ProwlarrCall.ListIndexers(), ProwlarrCall.GetIndexer(7), ProwlarrCall.IndexerSchema(), ProwlarrCall.IndexerStatus(), ProwlarrCall.AppProfiles(),
            ProwlarrCall.CreateIndexer(body), ProwlarrCall.UpdateIndexer(7, body), ProwlarrCall.TestIndexer(body), ProwlarrCall.DeleteIndexer(7)
        ];
        Assert.All(calls, x => Assert.True(ProwlarrCall.Permits(x.Method, x.Path), x.Method + " " + x.Path));
        Assert.Throws<ArgumentOutOfRangeException>(() => ProwlarrCall.GetIndexer(0));
        Assert.Throws<ArgumentOutOfRangeException>(() => ProwlarrCall.DeleteIndexer(-3));
        Assert.Throws<ArgumentOutOfRangeException>(() => ProwlarrCall.CreateIndexer([]));
        Assert.Empty(typeof(ProwlarrCall).GetConstructors());
    }
}
