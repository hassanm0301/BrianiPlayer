using System.Text;
using Briani.Api.Integrations.Prowlarr;

namespace Briani.DiscoveryTests;

public sealed class ProwlarrClientTests
{
    [Fact]
    public async Task Providers_filters_usenet_and_maps_capabilities()
    {
        var transport = new FixtureTransport("""
        [
          {"id":4,"name":"Torrent source","enable":true,"supportsSearch":true,"supportsRss":true,"protocol":"torrent","capabilities":{"searchParams":["q"],"categories":[{"id":2000,"subCategories":[{"id":2010,"subCategories":[{"id":2011}]}]}]}},
          {"id":5,"name":"Usenet source","enable":true,"supportsSearch":true,"supportsRss":true,"protocol":"usenet","capabilities":{}},
          {"id":6,"name":"Disabled","enable":false,"supportsSearch":false,"supportsRss":false,"protocol":"torrent","capabilities":{"searchParams":[]}}
        ]
        """);
        var providers = await new ProwlarrClient(transport).ProvidersAsync();

        Assert.Equal(2, providers.Length);
        Assert.Equal("4", providers[0].Id);
        Assert.True(providers[0].SupportsSearch);
        Assert.True(providers[0].SupportsRecent);
        Assert.Equal(new long[] { 2000, 2010, 2011 }, providers[0].Categories);
        Assert.False(providers[1].Enabled);
        Assert.False(providers[1].SupportsRecent);
    }

    [Fact]
    public async Task Search_escapes_query_and_preserves_unknown_invalid_counts_as_null()
    {
        var transport = new FixtureTransport("""
        [{"guid":"fixture-guid","title":"  Καλημέρα release  ","size":1234,"seeders":-1,"leechers":"not-a-count","publishDate":"2026-01-02T03:04:05Z","categories":[{"id":2000}],"infoHash":"0123456789012345678901234567890123456789","protocol":"torrent","downloadUrl":"http://prowlarr.local/api/v1/search?apikey=secret","magnetUrl":"magnet:?xt=urn:btih:0123456789012345678901234567890123456789"}]
        """);
        var provider = new ProviderInfo("9", "Private source", true, true, true, [2000]);

        var result = await new ProwlarrClient(transport).SearchAsync(provider, new("search", "A & B", [2000]));

        Assert.Equal("/api/v1/search?type=search&query=A%20%26%20B&indexerIds=9&limit=501&categories=2000", transport.LastPath);
        var release = Assert.Single(result.Releases);
        Assert.Equal("Καλημέρα release", release.Title);
        Assert.Equal(1234, release.SizeBytes);
        Assert.Null(release.Seeders);
        Assert.Null(release.Leechers);
        Assert.Equal("0123456789012345678901234567890123456789", release.InfoHashV1);
        Assert.Null(release.InfoHashV2);
        Assert.Contains("secret", release.DownloadUrl);
        Assert.False(result.Truncated);
    }

    [Fact]
    public async Task Search_caps_at_500_results_and_marks_truncated()
    {
        var json = "[" + string.Join(',', Enumerable.Range(0, 501).Select(i =>
            "{\"guid\":\"g" + i + "\",\"title\":\"title " + i + "\",\"protocol\":\"torrent\"}")) + "]";
        var client = new ProwlarrClient(new FixtureTransport(json));
        var result = await client.SearchAsync(new("3", "src", true, true, true, []), new("search", "sample", []));
        Assert.Equal(500, result.Releases.Length);
        Assert.True(result.Truncated);
    }

    [Fact]
    public async Task Search_rejects_unsupported_recent_without_upstream_request()
    {
        var transport = new FixtureTransport("[]");
        var error = await Assert.ThrowsAsync<ProwlarrFailure>(() => new ProwlarrClient(transport)
            .SearchAsync(new("3", "src", true, true, false, []), new("latest", "", [])));
        Assert.Equal("recent_unsupported", error.Code);
        Assert.Null(transport.LastPath);
    }

    [Fact]
    public async Task Provider_health_uses_disabled_status_without_exposing_upstream_failure_text()
    {
        var transport = new FixtureTransport(path => path switch
        {
            "/api/v1/indexer" => "[{\"id\":4,\"name\":\"Source\",\"enable\":true,\"supportsSearch\":true,\"protocol\":\"torrent\",\"capabilities\":{}}]",
            "/api/v1/indexerstatus" => "[{\"indexerId\":4,\"disabledTill\":\"2999-01-01T00:00:00Z\",\"mostRecentFailure\":\"private URL and key\"}]",
            _ => "[]"
        });

        var provider = Assert.Single(await new ProwlarrClient(transport).ProvidersAsync());

        Assert.Equal("unavailable", provider.State);
        Assert.Equal("provider_temporarily_disabled", provider.Warning);
        Assert.DoesNotContain("private URL", provider.Warning);
    }

    [Fact]
    public async Task Empty_success_without_provider_status_preserves_unknown_health()
    {
        var transport = new FixtureTransport(path => path == "/api/v1/indexerstatus" ? "[]" : "[]");
        var provider = new ProviderInfo("4", "Source", true, true, true, []);

        var result = await new ProwlarrClient(transport).SearchAsync(provider, new("search", "empty", []));

        Assert.Empty(result.Releases);
        Assert.Equal("unknown", result.Provider.State);
    }

    [Fact]
    public async Task Malformed_response_has_safe_code_without_body_details()
    {
        var error = await Assert.ThrowsAsync<ProwlarrFailure>(() => new ProwlarrClient(new FixtureTransport("not-json"))
            .ProvidersAsync());
        Assert.Equal("invalid_response", error.Code);
        Assert.DoesNotContain("not-json", error.Message);
    }

    private sealed class FixtureTransport(Func<string, string> response) : IProwlarrTransport
    {
        public FixtureTransport(string response) : this(_ => response) { }
        public string? LastPath { get; private set; }
        public Task<byte[]> GetAsync(string relativePath, CancellationToken ct = default)
        {
            LastPath = relativePath;
            return Task.FromResult(Encoding.UTF8.GetBytes(response(relativePath)));
        }
    }
}
