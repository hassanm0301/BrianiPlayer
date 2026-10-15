using System.Text.Json;
using Briani.Api.Infrastructure.Security;

namespace Briani.Api.Modules.Discovery.Queries;

public static class QueryRules
{
    public const int MaxPageSize = 200;
    public const int DefaultPageSize = 50;
    public const int MaxSnapshotResults = 500;
    public const int MaxProviders = 100;
    public const int MaxCategories = 100;
    public const int MaxSnapshotsPerUser = 64;
    public const int MaxSnapshotsGlobal = 256;
    public const int MaxOperationsPerUser = 256;
    public const int MaxOperationsGlobal = 4096;
    public const int MaxResolutionPlaintextBytes = 32 * 1024;
    public const int MaxResolutionAlternatives = 100;
    public static readonly TimeSpan SearchCache = TimeSpan.FromMinutes(5);
    public static readonly TimeSpan RecentCache = TimeSpan.FromMinutes(15);
    public static readonly TimeSpan SnapshotLifetime = TimeSpan.FromHours(24);

    public static DiscoveryQuery Normalize(DiscoveryQuery? query)
    {
        if (query is null) throw new ApiException(400, "validation_failed");
        var mode = query.Mode switch
        {
            "latest" => "latest",
            "mostSeeded" => "mostSeeded",
            "search" => "search",
            _ => throw new ApiException(400, "validation_failed")
        };
        var text = query.Query?.Trim();
        if (text?.Length > 200 || text?.Any(char.IsControl) == true) throw new ApiException(400, "validation_failed", "Search text must be at most 200 characters without control characters.");
        if (mode == "search" && string.IsNullOrWhiteSpace(text)) throw new ApiException(400, "validation_failed", "Enter something to search for.");
        if (mode == "latest") text = null;

        var providerIds = query.ProviderIds ?? [];
        if (providerIds.Length > MaxProviders || providerIds.Any(id => string.IsNullOrWhiteSpace(id) || id.Length > 128 || id.Any(char.IsControl)))
            throw new ApiException(400, "validation_failed");
        if (providerIds.Distinct(StringComparer.Ordinal).Count() != providerIds.Length)
            throw new ApiException(400, "validation_failed");

        var categories = query.Categories ?? [];
        if (categories.Length > MaxCategories || categories.Any(id => id < 0) || categories.Distinct().Count() != categories.Length)
            throw new ApiException(400, "validation_failed");

        if (query.MinSizeBytes < 0 || query.MaxSizeBytes < 0 || query.MinSeeders < 0 ||
            (query.MinSizeBytes is not null && query.MaxSizeBytes is not null && query.MinSizeBytes > query.MaxSizeBytes))
            throw new ApiException(400, "validation_failed");

        var sort = query.Sort ?? (mode == "mostSeeded" ? "seeders" : "publishedAt");
        if (sort is not ("publishedAt" or "seeders" or "leechers" or "peers" or "sizeBytes" or "title"))
            throw new ApiException(400, "validation_failed");
        var order = query.Order ?? (mode == "mostSeeded" || sort != "title" ? "desc" : "asc");
        if (order is not ("asc" or "desc")) throw new ApiException(400, "validation_failed");

        return new DiscoveryQuery(mode, text, providerIds.Order(StringComparer.Ordinal).ToArray(),
            categories.Order().ToArray(), sort, order, query.MinSizeBytes, query.MaxSizeBytes, query.MinSeeders);
    }

    public static string CanonicalJson(DiscoveryQuery query) => JsonSerializer.Serialize(query);

    public static bool Matches(DiscoveryQuery query, NormalizedRelease result)
    {
        if (query.MinSizeBytes is long min && (result.Bytes is null || result.Bytes < min)) return false;
        if (query.MaxSizeBytes is long max && (result.Bytes is null || result.Bytes > max)) return false;
        if (query.MinSeeders is long seeders && (result.Seeders is null || result.Seeders < seeders)) return false;
        return query.Categories is not { Length: > 0 } || result.Categories.Intersect(query.Categories).Any();
    }

    public static NormalizedRelease[] Sort(IEnumerable<NormalizedRelease> items, DiscoveryQuery query)
    {
        var descending = query.Order == "desc";
        return items.OrderBy(x => x, Comparer<NormalizedRelease>.Create((a, b) =>
        {
            var compare = ComparePrimary(a, b, query.Sort ?? "publishedAt", descending);
            if (compare == 0 && query.Mode == "mostSeeded" && query.Sort == "seeders")
                compare = CompareNullable(a.PublishedAt, b.PublishedAt, descending: true);
            if (compare == 0) compare = string.CompareOrdinal(a.Id.ToString("N"), b.Id.ToString("N"));
            return compare;
        })).ToArray();
    }

    private static int ComparePrimary(NormalizedRelease a, NormalizedRelease b, string sort, bool descending) => sort switch
    {
        "seeders" => CompareNullable(a.Seeders, b.Seeders, descending),
        "leechers" => CompareNullable(a.Leechers, b.Leechers, descending),
        "peers" => CompareNullable(a.Peers, b.Peers, descending),
        "sizeBytes" => CompareNullable(a.Bytes, b.Bytes, descending),
        "title" => CompareNullable(a.Title, b.Title, descending, StringComparer.OrdinalIgnoreCase),
        _ => CompareNullable(a.PublishedAt, b.PublishedAt, descending)
    };

    private static int CompareNullable<T>(T? a, T? b, bool descending, IComparer<T>? comparer = null) where T : struct
    {
        if (!a.HasValue) return b.HasValue ? 1 : 0;
        if (!b.HasValue) return -1;
        var value = (comparer ?? Comparer<T>.Default).Compare(a.Value, b.Value);
        return descending ? -value : value;
    }

    private static int CompareNullable(string? a, string? b, bool descending, StringComparer comparer)
    {
        if (a is null) return b is null ? 0 : 1;
        if (b is null) return -1;
        var value = comparer.Compare(a, b);
        return descending ? -value : value;
    }

    public static long? PeersTotal(long? seeders, long? leechers)
    {
        if (seeders is null or < 0 || leechers is null or < 0) return null;
        try { return checked(seeders.Value + leechers.Value); }
        catch (OverflowException) { return null; }
    }
}

public sealed record NormalizedRelease(Guid Id, string SourceId, string SourceName, string SourceGuid,
    string Title, long? Bytes, long? Seeders, long? Leechers, long? Peers, DateTimeOffset? PublishedAt,
    DateTimeOffset ObservedAt, string? InfoHashV1, string? InfoHashV2, long[] Categories,
    string EncryptedResolutionJson, bool CanDownload);
