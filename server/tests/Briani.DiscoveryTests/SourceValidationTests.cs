using System.Net;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Discovery.Sources;

namespace Briani.DiscoveryTests;

public sealed class SourceValidationTests
{
    private const string V1 = "0123456789abcdef0123456789abcdef01234567";
    private const string V2 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    [Fact]
    public void Magnet_accepts_v1_hex_base32_v2_hybrid_and_trackers()
    {
        var hex = SourceValidation.Magnet($"magnet:?xt=urn:btih:{V1}&dn=fixture&tr=https%3A%2F%2Ftracker.example%2Fannounce");
        Assert.Equal(V1, hex.InfoHashV1);
        Assert.Null(hex.InfoHashV2);
        Assert.Equal("https://tracker.example/announce", Assert.Single(hex.Trackers));

        var base32 = SourceValidation.Magnet($"magnet:?xt=urn:btih:{ToBase32(Convert.FromHexString(V1))}");
        Assert.Equal(V1, base32.InfoHashV1);

        var v2 = SourceValidation.Magnet($"magnet:?xt=urn:btmh:1220{V2}");
        Assert.Equal(V2, v2.InfoHashV2);
        Assert.Null(v2.InfoHashV1);

        var hybrid = SourceValidation.Magnet($"magnet:?xt=urn:btih:{V1}&xt=urn:btmh:1220{V2}");
        Assert.Equal(V1, hybrid.InfoHashV1);
        Assert.Equal(V2, hybrid.InfoHashV2);
    }

    [Theory]
    [InlineData("magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&xs=https%3A%2F%2Fevil.example%2Ffile", "unsafe_magnet_field")]
    [InlineData("magnet:?xt=urn:btih:bad", "invalid_magnet")]
    [InlineData("magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&tr=http%3A%2F%2F127.0.0.1%2Fannounce", "unsafe_tracker")]
    [InlineData("magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&tr=http%3A%2F%2F192.168.1.3%2Fannounce", "unsafe_tracker")]
    [InlineData("magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&tr=http%3A%2F%2Ftracker.local%2Fannounce", "unsafe_tracker")]
    public void Magnet_rejects_unknown_fields_malformed_hashes_and_private_trackers(string value, string code)
        => Assert.Equal(code, Assert.Throws<ApiException>(() => SourceValidation.Magnet(value)).Code);

    [Fact]
    public async Task Tracker_dns_rejects_mixed_public_and_private_answers()
    {
        var dns = new FixtureDns(IPAddress.Parse("8.8.8.8"), IPAddress.Parse("10.2.3.4"));
        var error = await Assert.ThrowsAsync<ApiException>(() => SourceValidation.ValidateTrackerDnsAsync(["https://tracker.example/announce"], dns, CancellationToken.None));
        Assert.Equal("unsafe_tracker", error.Code);
        Assert.Equal("tracker.example", Assert.Single(dns.Requested));
    }

    [Fact]
    public async Task Safe_http_resolves_again_inside_connect_callback_and_rejects_rebinding_before_connect()
    {
        var dns = new FixtureDns(IPAddress.Parse("93.184.216.34"), IPAddress.Parse("169.254.169.254"));
        var http = new SafeHttp(dns);
        var error = await Assert.ThrowsAsync<ApiException>(() => http.GetAsync(new Uri("http://rebind.example/file"), 1024));
        Assert.Equal("source_address_rejected", error.Code);
        Assert.Equal("rebind.example", Assert.Single(dns.Requested));
    }

    [Fact]
    public async Task Configured_origin_exception_allows_only_exact_host_scheme_and_port()
    {
        var origin = new Uri("http://prowlarr.internal:9696/");
        SafeHttp.ValidateContentUrl(new Uri("http://prowlarr.internal:9696/api/v1/download/3"), origin);
        var dns = new FixtureDns(IPAddress.Parse("10.0.0.12"));
        var safe = new SafeHttp(dns);
        var addresses = await safe.AddressesAsync(new Uri("http://prowlarr.internal:9696/api/v1/download/3"), origin, CancellationToken.None);
        Assert.Equal(IPAddress.Parse("10.0.0.12"), Assert.Single(addresses));
        Assert.Throws<ApiException>(() => SafeHttp.ValidateContentUrl(new Uri("http://other.internal:9696/api/v1/download/3"), origin));
        Assert.Throws<ApiException>(() => SafeHttp.ValidateContentUrl(new Uri("https://prowlarr.internal:9696/api/v1/download/3"), origin));
        Assert.Throws<ApiException>(() => SafeHttp.ValidateContentUrl(new Uri("http://prowlarr.internal:9697/api/v1/download/3"), origin));
        var defaultPort = await Assert.ThrowsAsync<ApiException>(() => safe.AddressesAsync(new Uri("http://prowlarr.internal/api/v1/download/3"), origin, CancellationToken.None));
        Assert.Equal("source_address_rejected", defaultPort.Code);
    }

    [Theory]
    [InlineData("0.0.0.0")]
    [InlineData("10.0.0.1")]
    [InlineData("100.64.0.1")]
    [InlineData("127.0.0.1")]
    [InlineData("169.254.169.254")]
    [InlineData("172.20.0.1")]
    [InlineData("192.0.2.1")]
    [InlineData("192.168.1.1")]
    [InlineData("198.18.0.1")]
    [InlineData("203.0.113.1")]
    [InlineData("224.0.0.1")]
    [InlineData("::1")]
    [InlineData("fc00::1")]
    [InlineData("fe80::1")]
    [InlineData("2001:db8::1")]
    [InlineData("2002:0808:0808::1")]
    [InlineData("::ffff:10.0.0.1")]
    public void Network_address_policy_denies_nonpublic_ipv4_ipv6_mapped_and_transition_addresses(string text)
        => Assert.False(NetworkAddressPolicy.IsPublic(IPAddress.Parse(text)));

    private static string ToBase32(byte[] bytes)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
        var output = new System.Text.StringBuilder(); int buffer = 0, bits = 0;
        foreach (var value in bytes)
        {
            buffer = (buffer << 8) | value; bits += 8;
            while (bits >= 5) { bits -= 5; output.Append(alphabet[(buffer >> bits) & 31]); }
        }
        if (bits > 0) output.Append(alphabet[(buffer << (5 - bits)) & 31]);
        return output.ToString();
    }

    private sealed class FixtureDns(params IPAddress[] answers) : ISafeDns
    {
        public List<string> Requested { get; } = [];
        public Task<IPAddress[]> ResolveAsync(string host, CancellationToken ct) { Requested.Add(host); return Task.FromResult(answers); }
    }
}
