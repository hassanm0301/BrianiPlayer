using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.Prowlarr;
using Briani.Api.Modules.Discovery;
using Briani.Api.Modules.Discovery.Queries;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Briani.DiscoveryTests;

public sealed class QueryApiTests
{
    [Fact]
    public async Task Post_is_queued_then_worker_persists_partial_deduplicated_results()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a"), Provider("b"), Provider("c")];
        fake.Results["a"] = [Release("a-guid", "first", long.MaxValue, 1)];
        fake.Results["b"] = [Release("b-guid", "second", long.MaxValue, 1)];
        fake.Failures.Add("c");
        await using var fixture = await QueryFixture.Create(fake);

        using var response = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "film" });

        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        Assert.Equal(0, fake.SearchCount);
        var queued = await response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(queued);
        Assert.Equal("queued", queued.State);
        Assert.Null(queued.TotalKnown);

        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Equal(3, fake.SearchCount);
        using var read = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{queued.Id}");
        Assert.Equal(HttpStatusCode.OK, read.StatusCode);
        var done = await read.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(done);
        Assert.Equal("partial", done.State);
        Assert.Contains(done.Warnings, x => x.StartsWith("Indexer 'c' ", StringComparison.Ordinal));
        var item = Assert.Single(done.Items);
        Assert.Equal("first", item.Title);
        Assert.Null(item.Peers); // overflowing and unknown-compatible aggregate counts remain null
        Assert.Equal(1, done.TotalKnown);
        var stored = await fixture.InDb(db => db.DiscoveryResults.AsNoTracking().SingleAsync());
        Assert.True(stored.CanDownload);
        Assert.DoesNotContain("secret", stored.EncryptedResolutionJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("example.test", stored.EncryptedResolutionJson, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Unavailable_empty_provider_marks_partial_but_other_provider_results_survive()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a"), Provider("b")];
        fake.ProviderResults["a"] = new ProviderResults(Provider("a") with
        { State = "unavailable", Warning = "provider_temporarily_disabled" }, [], false);
        fake.Results["b"] = [ReleaseUnique(1)];
        await using var fixture = await QueryFixture.Create(fake);

        var snapshot = await SubmitAndRun(fixture, new { mode = "search", query = "status" });
        using var response = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{snapshot.Id}");
        var view = await response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();

        Assert.NotNull(view);
        Assert.Equal("partial", view.State);
        Assert.Contains(ErrorMessages.Warning("provider_health:a:provider_temporarily_disabled"), view.Warnings);
        Assert.Equal("release-1", Assert.Single(view.Items).Title);
    }

    [Fact]
    public async Task All_unavailable_empty_providers_use_stale_results()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = [ReleaseUnique(1)];
        await using var fixture = await QueryFixture.Create(fake);
        var first = await SubmitAndRun(fixture, new { mode = "search", query = "same" });

        fixture.Clock.Advance(TimeSpan.FromMinutes(6));
        fake.ProviderResults["a"] = new ProviderResults(Provider("a") with
        { State = "unavailable", Warning = "provider_temporarily_disabled" }, [], false);
        var stale = await SubmitAndRun(fixture, new { mode = "search", query = "same" });
        using var response = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{stale.Id}");
        var view = await response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();

        Assert.NotEqual(first.Id, stale.Id);
        Assert.NotNull(view);
        Assert.Equal("partial", view.State);
        Assert.Contains(ErrorMessages.Warning("stale_results"), view.Warnings);
        Assert.Contains(ErrorMessages.Warning("provider_health:a:provider_temporarily_disabled"), view.Warnings);
        Assert.Equal("release-1", Assert.Single(view.Items).Title);
    }

    [Fact]
    public async Task Idempotency_returns_same_snapshot_and_rejects_changed_body()
    {
        var fake = new FakeProwlarr();
        await using var fixture = await QueryFixture.Create(fake);
        fixture.Client.DefaultRequestHeaders.Add("Idempotency-Key", "lookup-1");

        using var first = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "film" });
        using var repeated = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "film" });
        using var conflict = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "other" });

        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, repeated.StatusCode);
        var a = await first.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        var b = await repeated.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(a); Assert.NotNull(b);
        Assert.Equal(a.Id, b.Id);
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Equal(1, await fixture.InDb(db => db.DiscoverySnapshots.CountAsync()));
        Assert.Equal(0, fake.SearchCount);
        var storedKey = await fixture.InDb(db => db.Operations.Select(x => x.IdempotencyKey).SingleAsync());
        Assert.NotEqual("lookup-1", storedKey);

        using var created = await fixture.Client.PostAsJsonAsync("/api/v1/admin/users", new
        { username = "seconduser", displayName = "Second", password = TestPasswords.Member, confirmPassword = TestPasswords.Member, role = "member" });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var second = await created.Content.ReadFromJsonAsync<UserReply>();
        Assert.NotNull(second);
        var libraryId = await fixture.InDb(db => db.Libraries.Select(x => x.Id).SingleAsync());
        await fixture.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = second.Id, LibraryId = libraryId, CanRead = true, CanDownload = true });
            await db.SaveChangesAsync();
            return 0;
        });
        using var login = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new
        { username = "seconduser", password = TestPasswords.Member, deviceName = "test" });
        var secondAuth = await login.Content.ReadFromJsonAsync<AuthReply>();
        Assert.NotNull(secondAuth);
        fixture.Client.DefaultRequestHeaders.Authorization = new("Bearer", secondAuth.AccessToken);
        using var hidden = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{a.Id}");
        Assert.Equal(HttpStatusCode.NotFound, hidden.StatusCode);
    }

    [Fact]
    public async Task Deduplicated_counts_remain_a_coherent_provider_observation()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a"), Provider("b")];
        fake.Results["a"] = [Release("a-guid", "first", 5, null)];
        fake.Results["b"] = [Release("b-guid", "second", 10, 2)];
        await using var fixture = await QueryFixture.Create(fake);

        var snapshot = await SubmitAndRun(fixture, new { mode = "search", query = "film" });
        using var response = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{snapshot.Id}");
        var view = await response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        var result = Assert.Single(Assert.IsType<DiscoverySnapshotView>(view).Items);

        Assert.Equal("a", result.ProviderId);
        Assert.Equal(5, result.Seeders);
        Assert.Null(result.Leechers);
        Assert.Null(result.Peers);
    }

    [Fact]
    public async Task Snapshot_limit_blocks_new_query_but_allows_cached_reuse()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = [ReleaseUnique(1)];
        await using var fixture = await QueryFixture.Create(fake);
        var cached = await SubmitAndRun(fixture, new { mode = "search", query = "cached" });
        await fixture.InDb(async db =>
        {
            var source = await db.DiscoverySnapshots.SingleAsync(x => x.Id == cached.Id);
            for (var i = 1; i < QueryRules.MaxSnapshotsPerUser; i++)
            {
                db.DiscoverySnapshots.Add(new DiscoverySnapshot
                {
                    UserId = source.UserId, AuthSessionId = source.AuthSessionId,
                    PermissionStamp = source.PermissionStamp, QueryKey = "retained-" + i,
                    QueryJson = "{}", State = "complete", CreatedAt = source.CreatedAt,
                    ExpiresAt = source.ExpiresAt, FetchedAt = source.FetchedAt, WarningsJson = "[]"
                });
            }
            await db.SaveChangesAsync();
            return 0;
        });

        using var cachedAgain = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "cached" });
        var cachedView = await cachedAgain.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.Equal(HttpStatusCode.Accepted, cachedAgain.StatusCode);
        Assert.NotNull(cachedView);
        Assert.Equal(cached.Id, cachedView.Id);
        using var rejected = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "new" });
        Assert.Equal((HttpStatusCode)429, rejected.StatusCode);
        Assert.Equal(1, fake.SearchCount);
    }

    [Fact]
    public async Task Operation_limit_preserves_cached_reads_and_existing_idempotent_replay()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = [ReleaseUnique(1)];
        await using var fixture = await QueryFixture.Create(fake);
        fixture.Client.DefaultRequestHeaders.Add("Idempotency-Key", "original-key");
        var requestBody = new { mode = "search", query = "cached" };
        var original = await SubmitAndRun(fixture, requestBody);
        var userId = await fixture.InDb(db => db.DiscoverySnapshots.Where(x => x.Id == original.Id).Select(x => x.UserId).SingleAsync());

        await fixture.InDb(async db =>
        {
            for (var i = 1; i < QueryRules.MaxOperationsPerUser; i++)
                db.Operations.Add(new Operation
                {
                    UserId = userId, Kind = "discovery.query", TargetId = original.Id,
                    IdempotencyKey = "seeded-key-" + i, RequestHash = "seeded", State = "complete",
                    CreatedAt = fixture.Clock.GetUtcNow(), UpdatedAt = fixture.Clock.GetUtcNow(),
                    ExpiresAt = fixture.Clock.GetUtcNow().AddDays(1)
                });
            await db.SaveChangesAsync();
            return 0;
        });

        using var replay = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", requestBody);
        Assert.Equal(HttpStatusCode.Accepted, replay.StatusCode);
        fixture.Client.DefaultRequestHeaders.Remove("Idempotency-Key");
        using var cachedWithoutKey = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", requestBody);
        Assert.Equal(HttpStatusCode.Accepted, cachedWithoutKey.StatusCode);
        fixture.Client.DefaultRequestHeaders.Add("Idempotency-Key", "new-cached-key");
        using var blocked = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", requestBody);
        Assert.Equal((HttpStatusCode)429, blocked.StatusCode);
        Assert.Equal(QueryRules.MaxOperationsPerUser, await fixture.InDb(db => db.Operations.CountAsync(x => x.UserId == userId && x.Kind == "discovery.query")));
    }

    [Fact]
    public async Task Oversized_merged_resolution_alternative_is_omitted_and_reported()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a"), Provider("b")];
        fake.Results["a"] = [Release("a-guid", "first", 5, 1) with { DownloadUrl = "https://example.test/" + new string('a', 19000) }];
        fake.Results["b"] = [Release("b-guid", "second", 8, 2) with { DownloadUrl = "https://example.test/" + new string('b', 19000) }];
        await using var fixture = await QueryFixture.Create(fake);
        var snapshot = await SubmitAndRun(fixture, new { mode = "search", query = "film" });

        using var response = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{snapshot.Id}");
        var view = await response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(view);
        Assert.Contains(ErrorMessages.Warning("resolution_alternative_limit"), view.Warnings);
        Assert.True(Assert.Single(view.Items).Downloadable);
        var encrypted = await fixture.InDb(db => db.DiscoveryResults.AsNoTracking().Where(x => x.SnapshotId == snapshot.Id)
            .Select(x => x.EncryptedResolutionJson).SingleAsync());
        var plaintext = fixture.Decrypt(encrypted);
        Assert.True(System.Text.Encoding.UTF8.GetByteCount(plaintext) <= QueryRules.MaxResolutionPlaintextBytes);
        Assert.Contains("a-guid", plaintext);
        Assert.DoesNotContain("b-guid", plaintext);
    }

    [Fact]
    public async Task Expired_idempotency_key_is_reused_without_unique_constraint_failure()
    {
        var fake = new FakeProwlarr();
        await using var fixture = await QueryFixture.Create(fake);
        fixture.Client.DefaultRequestHeaders.Add("Idempotency-Key", "long-lived-key");
        var request = new { mode = "search", query = "film" };
        using var firstResponse = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", request);
        var first = await firstResponse.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(first);

        fixture.Clock.Advance(TimeSpan.FromHours(24).Add(TimeSpan.FromSeconds(1)));
        using var login = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new
        { username = "discoveryadmin", password = fixture.Password, deviceName = "test" });
        var auth = await login.Content.ReadFromJsonAsync<AuthReply>();
        Assert.NotNull(auth);
        fixture.Client.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);
        using var repeated = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", request);

        Assert.Equal(HttpStatusCode.Accepted, repeated.StatusCode);
        var second = await repeated.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(second);
        Assert.NotEqual(first.Id, second.Id);
        Assert.Equal(1, await fixture.InDb(db => db.Operations.CountAsync()));
    }

    [Fact]
    public async Task Worker_rechecks_download_permission_before_upstream_fetch()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        await using var fixture = await QueryFixture.Create(fake);
        using var accepted = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "film" });
        var snapshot = await accepted.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(snapshot);

        await fixture.InDb(async db =>
        {
            var library = await db.Libraries.SingleAsync();
            library.Enabled = false;
            await db.SaveChangesAsync();
            return 0;
        });

        Assert.True(await fixture.Worker.RunOnceAsync());
        Assert.Equal(0, fake.ProviderCount);
        var state = await fixture.InDb(db => db.DiscoverySnapshots.AsNoTracking().Where(x => x.Id == snapshot.Id).Select(x => x.State).SingleAsync());
        Assert.Equal("failed", state);
        var error = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{snapshot.Id}");
        Assert.Equal(HttpStatusCode.Forbidden, error.StatusCode);
    }

    [Fact]
    public async Task Worker_recovers_expired_lease_and_completes_job()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = [Release("only", "one", 7, 2)];
        await using var fixture = await QueryFixture.Create(fake);
        using var accepted = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "film" });
        var snapshot = await accepted.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(snapshot);
        await fixture.InDb(async db =>
        {
            var job = await db.Jobs.SingleAsync(x => x.TargetId == snapshot.Id);
            job.State = "running"; job.LeaseOwner = "expired-worker"; job.LeaseUntil = fixture.Clock.GetUtcNow().AddSeconds(-1);
            job.Attempt = 1;
            var row = await db.DiscoverySnapshots.SingleAsync(x => x.Id == snapshot.Id);
            row.State = "running";
            await db.SaveChangesAsync();
            return 0;
        });

        Assert.True(await fixture.Worker.RunOnceAsync());
        var jobState = await fixture.InDb(db => db.Jobs.AsNoTracking().SingleAsync(x => x.TargetId == snapshot.Id));
        Assert.Equal("completed", jobState.State);
        Assert.Equal(2, jobState.Attempt);
        Assert.Equal(1, fake.SearchCount);
    }

    [Fact]
    public async Task Most_seeded_without_text_uses_recent_feed_and_sorts_by_seeders()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = [Release("lower", "lower", 2, 1), Release("higher", "higher", 99, 1)];
        await using var fixture = await QueryFixture.Create(fake);

        using var accepted = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "mostSeeded" });
        Assert.Equal(HttpStatusCode.Accepted, accepted.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        using var response = await fixture.Client.GetAsync("/api/v1/discovery/queries/" + (await accepted.Content.ReadFromJsonAsync<DiscoverySnapshotView>())!.Id);
        var view = await response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();

        Assert.NotNull(view);
        Assert.Equal("higher", view.Items[0].Title);
        Assert.Equal("latest", Assert.Single(fake.SearchModes));
    }

    [Fact]
    public async Task Snapshot_cursor_is_bound_to_snapshot_and_pages_results()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = Enumerable.Range(1, 3).Select(ReleaseUnique).ToArray();
        await using var fixture = await QueryFixture.Create(fake);
        var first = await SubmitAndRun(fixture, new { mode = "search", query = "first" });
        using var page1Response = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{first.Id}?limit=1");
        var page1 = await page1Response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(page1);
        Assert.NotNull(page1.NextCursor);
        using var page2Response = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{first.Id}?limit=1&cursor={Uri.EscapeDataString(page1.NextCursor)}");
        var page2 = await page2Response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(page2);
        Assert.NotEqual(Assert.Single(page1.Items).Id, Assert.Single(page2.Items).Id);

        var other = await SubmitAndRun(fixture, new { mode = "search", query = "second" });
        using var replay = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{other.Id}?limit=1&cursor={Uri.EscapeDataString(page1.NextCursor)}");
        Assert.Equal(HttpStatusCode.BadRequest, replay.StatusCode);
    }

    [Theory]
    [InlineData("latest")]
    [InlineData("mostSeeded")]
    public async Task Recent_feed_cache_is_reused_for_fifteen_minutes_then_expires(string mode)
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = [ReleaseUnique(1)];
        await using var fixture = await QueryFixture.Create(fake);
        var request = mode == "latest" ? (object)new { mode } : new { mode };
        var first = await SubmitAndRun(fixture, request);
        using var cachedResponse = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", request);
        var cached = await cachedResponse.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(cached);
        Assert.Equal(first.Id, cached.Id);
        Assert.Equal(1, fake.SearchCount);

        fixture.Clock.Advance(TimeSpan.FromMinutes(15).Add(TimeSpan.FromSeconds(1)));
        using var expiredResponse = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", request);
        var expired = await expiredResponse.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(expired);
        Assert.NotEqual(first.Id, expired.Id);
    }

    [Fact]
    public async Task Search_outage_uses_previous_snapshot_as_stale_until_24_hour_expiry()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = [ReleaseUnique(1)];
        await using var fixture = await QueryFixture.Create(fake);
        var first = await SubmitAndRun(fixture, new { mode = "search", query = "same" });

        fixture.Clock.Advance(TimeSpan.FromMinutes(6));
        fake.Failures.Add("a");
        var stale = await SubmitAndRun(fixture, new { mode = "search", query = "same" });
        using var staleResponse = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{stale.Id}");
        var staleView = await staleResponse.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(staleView);
        Assert.Equal("partial", staleView.State);
        Assert.Contains(ErrorMessages.Warning("stale_results"), staleView.Warnings);
        Assert.True(Assert.Single(staleView.Items).Stale);
        Assert.NotEqual(first.Id, stale.Id);

        fixture.Clock.Advance(TimeSpan.FromHours(24));
        using var relogin = await fixture.Client.PostAsJsonAsync("/api/v1/auth/login", new
        { username = "discoveryadmin", password = fixture.Password, deviceName = "test" });
        var auth = await relogin.Content.ReadFromJsonAsync<AuthReply>();
        Assert.NotNull(auth);
        fixture.Client.DefaultRequestHeaders.Authorization = new("Bearer", auth.AccessToken);
        using var expiredResponse = await fixture.Client.GetAsync($"/api/v1/discovery/queries/{stale.Id}");
        Assert.Equal(HttpStatusCode.NotFound, expiredResponse.StatusCode);
    }

    [Fact]
    public async Task Active_query_per_user_is_limited_and_results_truncate_at_500()
    {
        var fake = new FakeProwlarr();
        fake.Providers = [Provider("a")];
        fake.Results["a"] = Enumerable.Range(1, 501).Select(ReleaseUnique).ToArray();
        await using var fixture = await QueryFixture.Create(fake);
        using var first = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "first" });
        using var conflict = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", new { mode = "search", query = "other" });
        Assert.Equal(HttpStatusCode.Accepted, first.StatusCode);
        Assert.Equal((HttpStatusCode)429, conflict.StatusCode);
        var snapshot = await first.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(snapshot);
        Assert.True(await fixture.Worker.RunOnceAsync());
        var complete = await fixture.InDb(db => db.DiscoverySnapshots.AsNoTracking().SingleAsync(x => x.Id == snapshot.Id));
        Assert.Equal(500, await fixture.InDb(db => db.DiscoveryResults.CountAsync(x => x.SnapshotId == snapshot.Id)));
        Assert.True(complete.Truncated);
    }

    [Fact]
    public async Task Worker_never_queries_more_than_two_providers_concurrently()
    {
        var fake = new FakeProwlarr();
        fake.Providers = Enumerable.Range(0, 5).Select(i => Provider("p" + i)).ToArray();
        await using var fixture = await QueryFixture.Create(fake);

        await SubmitAndRun(fixture, new { mode = "latest" });

        Assert.Equal(5, fake.SearchCount);
        Assert.Equal(2, fake.MaximumConcurrentSearches);
    }

    private static ProviderInfo Provider(string id) => new(id, id, true, true, true, []);

    private static ProwlarrRelease Release(string guid, string title, long? seeders, long? leechers) => new(
        guid, title, 1234, seeders, leechers, DateTimeOffset.Parse("2026-01-01T00:00:00Z"), [1],
        "0123456789012345678901234567890123456789", null,
        $"https://example.test/{guid}?apikey=secret", $"magnet:?xt=urn:btih:{guid}");

    private static ProwlarrRelease ReleaseUnique(int index) => new(
        "source-" + index, "release-" + index, 1000 + index, index, index / 2,
        DateTimeOffset.Parse("2026-01-01T00:00:00Z"), [], index.ToString("x40"), null,
        $"https://example.test/{index}?apikey=secret", $"magnet:?xt=urn:btih:{index}");

    private static async Task<DiscoverySnapshotView> SubmitAndRun(QueryFixture fixture, object request)
    {
        using var response = await fixture.Client.PostAsJsonAsync("/api/v1/discovery/queries", request);
        Assert.Equal(HttpStatusCode.Accepted, response.StatusCode);
        var snapshot = await response.Content.ReadFromJsonAsync<DiscoverySnapshotView>();
        Assert.NotNull(snapshot);
        Assert.True(await fixture.Worker.RunOnceAsync());
        return snapshot;
    }

    private sealed class FakeProwlarr : IProwlarrClient
    {
        private int providerCount;
        private int searchCount;
        private int activeSearches;
        private int maximumConcurrentSearches;
        private readonly List<string> searchModes = [];
        public ProviderInfo[] Providers { get; set; } = [];
        public Dictionary<string, ProwlarrRelease[]> Results { get; } = new(StringComparer.Ordinal);
        public Dictionary<string, ProviderResults> ProviderResults { get; } = new(StringComparer.Ordinal);
        public HashSet<string> Failures { get; } = new(StringComparer.Ordinal);
        public int ProviderCount => Volatile.Read(ref providerCount);
        public int SearchCount => Volatile.Read(ref searchCount);
        public int MaximumConcurrentSearches => Volatile.Read(ref maximumConcurrentSearches);
        public string[] SearchModes { get { lock (searchModes) return searchModes.ToArray(); } }
        public Task<ProviderInfo[]> ProvidersAsync(CancellationToken ct = default)
        {
            Interlocked.Increment(ref providerCount);
            return Task.FromResult(Providers);
        }
        public async Task<ProviderResults> SearchAsync(ProviderInfo provider, ProwlarrSearch query, CancellationToken ct = default)
        {
            Interlocked.Increment(ref searchCount);
            lock (searchModes) searchModes.Add(query.Mode);
            var active = Interlocked.Increment(ref activeSearches);
            UpdateMaximum(active);
            try
            {
                await Task.Delay(5, ct);
                if (Failures.Contains(provider.Id)) throw new ProwlarrFailure("provider_unavailable");
                return ProviderResults.GetValueOrDefault(provider.Id) ??
                    new ProviderResults(provider, Results.GetValueOrDefault(provider.Id, []), false);
            }
            finally { Interlocked.Decrement(ref activeSearches); }
        }
        private void UpdateMaximum(int value)
        {
            var current = Volatile.Read(ref maximumConcurrentSearches);
            while (value > current)
            {
                var observed = Interlocked.CompareExchange(ref maximumConcurrentSearches, value, current);
                if (observed == current) return;
                current = observed;
            }
        }
    }

    private sealed class QueryFixture : IAsyncDisposable
    {
        private readonly TestHost root;
        private readonly WebApplicationFactory<Program> host;
        public HttpClient Client { get; }
        public string Password { get; }
        public ManualClock Clock => root.Clock;
        public DiscoveryQueryWorker Worker => host.Services.GetRequiredService<DiscoveryQueryWorker>();
        private QueryFixture(TestHost root, WebApplicationFactory<Program> host, HttpClient client, string password) { this.root = root; this.host = host; Client = client; Password = password; }

        public static async Task<QueryFixture> Create(FakeProwlarr fake)
        {
            var root = new TestHost();
            var host = root.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
                services.RemoveAll<IProwlarrClient>().AddSingleton<IProwlarrClient>(fake)));
            var client = host.CreateClient();
            var password = "Discovery-Test-" + Credentials.NewToken();
            var auth = await IdentityFixture.Bootstrap(client, root.BootstrapCode(), "discoveryadmin", "Discovery Admin", password);
            IdentityFixture.As(client, auth.AccessToken);
            await InDb(host, db =>
            {
                db.Libraries.Add(new Library { Name = "Test", RootPath = "library", RootIdentity = "test-root", CreatedAt = root.Clock.GetUtcNow() });
                return db.SaveChangesAsync();
            });
            return new QueryFixture(root, host, client, password);
        }

        public Task<T> InDb<T>(Func<BrianiDb, Task<T>> action) => InDb(host, action);
        public string Decrypt(string value) => host.Services.GetRequiredService<SecretStore>().Decrypt(value);
        private static async Task<T> InDb<T>(WebApplicationFactory<Program> host, Func<BrianiDb, Task<T>> action)
        {
            using var scope = host.Services.CreateScope();
            return await action(scope.ServiceProvider.GetRequiredService<BrianiDb>());
        }
        public ValueTask DisposeAsync()
        {
            Client.Dispose(); host.Dispose(); root.Dispose();
            return ValueTask.CompletedTask;
        }
    }
}
