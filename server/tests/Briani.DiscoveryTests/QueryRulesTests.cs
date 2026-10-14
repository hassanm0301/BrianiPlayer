using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Discovery;
using Briani.Api.Modules.Discovery.Queries;

namespace Briani.DiscoveryTests;

public sealed class QueryRulesTests
{
    [Fact]
    public void Normalize_canonicalizes_filters_and_defaults_most_seeded()
    {
        var normalized = QueryRules.Normalize(new DiscoveryQuery("mostSeeded", ProviderIds: ["z", "a"], Categories: [7, 2]));

        Assert.Equal(["a", "z"], normalized.ProviderIds!);
        Assert.Equal([2L, 7L], normalized.Categories!);
        Assert.Equal("seeders", normalized.Sort);
        Assert.Equal("desc", normalized.Order);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("  ")]
    public void Normalize_rejects_search_without_text(string? text)
    {
        var error = Assert.Throws<ApiException>(() => QueryRules.Normalize(new DiscoveryQuery("search", text)));
        Assert.Equal(400, error.Status);
        Assert.Equal("validation_failed", error.Code);
    }

    [Fact]
    public void Sort_keeps_null_metrics_last_in_ascending_and_descending_order()
    {
        var query = QueryRules.Normalize(new DiscoveryQuery("search", "x", Sort: "seeders", Order: "asc"));
        var present = Release(3);
        var missing = Release(null);

        Assert.Equal([present.Id, missing.Id], QueryRules.Sort([missing, present], query).Select(x => x.Id));
        query = query with { Order = "desc" };
        Assert.Equal([present.Id, missing.Id], QueryRules.Sort([missing, present], query).Select(x => x.Id));
    }

    [Fact]
    public void Peers_total_preserves_unknown_and_rejects_overflow()
    {
        Assert.Null(QueryRules.PeersTotal(1, null));
        Assert.Null(QueryRules.PeersTotal(long.MaxValue, 1));
        Assert.Equal(8, QueryRules.PeersTotal(3, 5));
    }

    private static NormalizedRelease Release(long? seeders) => new(Guid.NewGuid(), "p", "P", "g",
        "title", null, seeders, null, null, null, DateTimeOffset.UnixEpoch, null, null, [], "", false);
}
