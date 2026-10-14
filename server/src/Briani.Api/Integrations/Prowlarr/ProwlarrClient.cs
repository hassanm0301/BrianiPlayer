using System.Globalization;
using System.Collections.Concurrent;
using System.Text.Json;

namespace Briani.Api.Integrations.Prowlarr;

/// <summary>Typed, bounded adapter for Prowlarr's v1 indexer and search APIs.</summary>
public sealed class ProwlarrClient(IProwlarrTransport transport, TimeProvider? clock = null) : IProwlarrClient
{
    private const int MaxProvidersBytes = 2 * 1024 * 1024;
    private const int MaxSearchBytes = 8 * 1024 * 1024;
    private const int MaxResults = 500;
    private const int MaxQueryLength = 200;
    private const int MaxHealthEntries = 500;
    private readonly ConcurrentDictionary<string, ProviderHealth> health = new(StringComparer.Ordinal);
    private readonly object healthGate = new();

    public async Task<ProviderInfo[]> ProvidersAsync(CancellationToken ct = default)
    {
        var data = await GetAsync("/api/v1/indexer", MaxProvidersBytes, ct);
        await RefreshHealthAsync(ct);
        try
        {
            using var document = JsonDocument.Parse(data, new JsonDocumentOptions { MaxDepth = 32 });
            if (document.RootElement.ValueKind != JsonValueKind.Array)
                throw new ProwlarrFailure("invalid_response");

            var output = new List<ProviderInfo>();
            foreach (var item in document.RootElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.Object || !TryId(item, out var id)) continue;
                if (!string.Equals(String(item, "protocol"), "torrent", StringComparison.OrdinalIgnoreCase)) continue;

                var capabilities = Property(item, "capabilities");
                var categories = ReadCategories(capabilities);
                var enabled = Bool(item, "enable") ?? Bool(item, "enabled") ?? false;
                var searchable = Bool(item, "supportsSearch") ?? SupportsSearch(capabilities);
                var recent = Bool(item, "supportsRss") ?? SupportsRecent(capabilities);
                var observed = enabled ? health.GetValueOrDefault(id) : null;
                output.Add(new ProviderInfo(id,
                    SafeText(String(item, "name"), 160) is { Length: > 0 } name ? name : "Indexer",
                    enabled, searchable, recent, categories,
                    enabled ? observed?.State ?? "unknown" : "unavailable",
                    !searchable ? "search_unsupported" : enabled ? observed?.Warning : "provider_disabled"));
                if (output.Count == 500) break;
            }
            return output.ToArray();
        }
        catch (JsonException) { throw new ProwlarrFailure("invalid_response"); }
    }

    public async Task<ProviderResults> SearchAsync(ProviderInfo provider, ProwlarrSearch query, CancellationToken ct = default)
    {
        ArgumentNullException.ThrowIfNull(provider);
        ArgumentNullException.ThrowIfNull(query);
        if (!provider.Enabled) throw new ProwlarrFailure("provider_disabled");
        if (!provider.SupportsSearch && !StringComparer.OrdinalIgnoreCase.Equals(query.Mode, "latest"))
            throw new ProwlarrFailure("search_unsupported");
        if (!long.TryParse(provider.Id, NumberStyles.None, CultureInfo.InvariantCulture, out var providerId) || providerId <= 0)
            throw new ProwlarrFailure("invalid_provider");

        var mode = query.Mode?.Trim().ToLowerInvariant();
        if (mode is not ("latest" or "search")) throw new ProwlarrFailure("invalid_query");
        var term = query.Query ?? string.Empty;
        if (term.Length > MaxQueryLength || term.Any(char.IsControl)) throw new ProwlarrFailure("invalid_query");
        if (mode == "search" && string.IsNullOrWhiteSpace(term)) throw new ProwlarrFailure("invalid_query");
        if (mode == "latest" && !provider.SupportsRecent) throw new ProwlarrFailure("recent_unsupported");
        if (query.Categories is { Length: > 100 }) throw new ProwlarrFailure("invalid_query");
        var categories = (query.Categories ?? []).Where(x => x > 0).Distinct().Take(100).ToArray();

        var parameters = new List<string>
        {
            "type=search", "query=" + Uri.EscapeDataString(mode == "latest" ? string.Empty : term),
            "indexerIds=" + providerId.ToString(CultureInfo.InvariantCulture),
            // One extra record establishes a truthful truncated flag without an unbounded response.
            "limit=" + (MaxResults + 1).ToString(CultureInfo.InvariantCulture)
        };
        if (categories.Length > 0)
            parameters.Add("categories=" + string.Join(',', categories.Select(x => x.ToString(CultureInfo.InvariantCulture))));

        byte[] data;
        try
        {
            data = await GetAsync("/api/v1/search?" + string.Join('&', parameters), MaxSearchBytes, ct);
        }
        catch (ProwlarrFailure)
        {
            await RefreshHealthAsync(ct);
            throw;
        }
        try
        {
            using var document = JsonDocument.Parse(data, new JsonDocumentOptions { MaxDepth = 48 });
            if (document.RootElement.ValueKind != JsonValueKind.Array) throw new ProwlarrFailure("invalid_response");
            var releases = new List<ProwlarrRelease>();
            var truncated = false;
            foreach (var item in document.RootElement.EnumerateArray())
            {
                if (item.ValueKind != JsonValueKind.Object || !IsTorrent(item)) continue;
                if (releases.Count == MaxResults) { truncated = true; break; }
                var title = SafeText(String(item, "title"), 512);
                var sourceGuid = SafeText(String(item, "guid"), 2048);
                if (title.Length == 0 || sourceGuid.Length == 0) continue;
                releases.Add(new ProwlarrRelease(
                    sourceGuid, title,
                    NonNegativeLong(item, "size"), NonNegativeLong(item, "seeders"), NonNegativeLong(item, "leechers"),
                    Date(item, "publishDate"), ReadCategories(item),
                    ParseHash(String(item, "infoHash"), 40), ParseHash(String(item, "infoHash"), 64),
                    SafeReference(String(item, "downloadUrl")), SafeReference(String(item, "magnetUrl"))));
            }
            if (releases.Count > 0)
                SetHealth(provider.Id, new ProviderHealth("healthy", "contact_verified"));
            else
                await RefreshHealthAsync(ct);
            var observed = health.GetValueOrDefault(provider.Id);
            return new ProviderResults(provider with
            {
                State = observed?.State ?? "unknown",
                Warning = observed?.Warning
            }, releases.ToArray(), truncated);
        }
        catch (JsonException)
        {
            await RefreshHealthAsync(ct);
            throw new ProwlarrFailure("invalid_response");
        }
    }

    private async Task RefreshHealthAsync(CancellationToken ct)
    {
        try
        {
            var payload = await GetAsync("/api/v1/indexerstatus", 2 * 1024 * 1024, ct);
            using var document = JsonDocument.Parse(payload, new JsonDocumentOptions { MaxDepth = 24 });
            if (document.RootElement.ValueKind != JsonValueKind.Array) return;
            foreach (var entry in document.RootElement.EnumerateArray())
            {
                var providerId = Property(entry, "indexerId");
                if (providerId.ValueKind != JsonValueKind.Number || !providerId.TryGetInt64(out var rawId) || rawId <= 0) continue;
                var id = rawId.ToString(CultureInfo.InvariantCulture);
                if (health.Count >= MaxHealthEntries && !health.ContainsKey(id)) continue;
                var disabledTill = Date(entry, "disabledTill");
                var failed = HasText(entry, "mostRecentFailure") || HasText(entry, "initialFailure");
                if (disabledTill > (clock?.GetUtcNow() ?? DateTimeOffset.UtcNow))
                    SetHealth(id, new ProviderHealth("unavailable", "provider_temporarily_disabled"));
                else if (failed)
                    SetHealth(id, new ProviderHealth("degraded", "provider_recent_failure"));
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (ProwlarrFailure) { }
        catch (JsonException) { }
    }

    private void SetHealth(string id, ProviderHealth value)
    {
        lock (healthGate)
            if (health.ContainsKey(id) || health.Count < MaxHealthEntries) health[id] = value;
    }

    private sealed record ProviderHealth(string State, string? Warning);

    private async Task<byte[]> GetAsync(string path, int maxBytes, CancellationToken ct)
    {
        try
        {
            var bytes = await transport.GetAsync(path, ct);
            if (bytes.Length > maxBytes) throw new ProwlarrFailure("response_too_large");
            return bytes;
        }
        catch (ProwlarrFailure) { throw; }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new ProwlarrFailure("timeout"); }
        catch (OperationCanceledException) { throw; }
        catch (HttpRequestException) { throw new ProwlarrFailure("unavailable"); }
        catch (TimeoutException) { throw new ProwlarrFailure("timeout"); }
    }

    private static bool IsTorrent(JsonElement item) =>
        string.Equals(String(item, "protocol"), "torrent", StringComparison.OrdinalIgnoreCase);

    private static bool SupportsSearch(JsonElement capabilities)
    {
        if (capabilities.ValueKind != JsonValueKind.Object) return true;
        if (Bool(capabilities, "supportsSearch") is { } supports) return supports;
        var searches = Property(capabilities, "searchParams");
        return searches.ValueKind == JsonValueKind.Array && searches.GetArrayLength() > 0;
    }

    private static bool SupportsRecent(JsonElement capabilities)
    {
        if (capabilities.ValueKind != JsonValueKind.Object) return false;
        // In Prowlarr's v1 indexer model supportsRss represents the recent/empty-query feed.
        return Bool(capabilities, "supportsRss") == true;
    }

    private static long[] ReadCategories(JsonElement element)
    {
        var categories = Property(element, "categories");
        if (categories.ValueKind != JsonValueKind.Array) return [];
        var values = new SortedSet<long>();
        CollectCategories(categories, values, 0);
        return values.ToArray();
    }

    private static void CollectCategories(JsonElement categories, SortedSet<long> values, int depth)
    {
        if (categories.ValueKind != JsonValueKind.Array || depth > 8 || values.Count >= 100) return;
        foreach (var item in categories.EnumerateArray())
        {
            long? id = item.ValueKind == JsonValueKind.Object ? NonNegativeLong(item, "id") :
                item.TryGetInt64(out var raw) && raw >= 0 ? raw : null;
            if (id is > 0) values.Add(id.Value);
            CollectCategories(Property(item, "subCategories"), values, depth + 1);
            if (values.Count >= 100) break;
        }
    }

    private static bool TryId(JsonElement item, out string id)
    {
        id = string.Empty;
        var value = Property(item, "id");
        if (!value.TryGetInt64(out var parsed) || parsed <= 0) return false;
        id = parsed.ToString(CultureInfo.InvariantCulture);
        return true;
    }

    private static string? ParseHash(string? value, int length)
    {
        if (value is null) return null;
        var hash = value.Trim();
        return hash.Length == length && hash.All(Uri.IsHexDigit) ? hash.ToLowerInvariant() : null;
    }

    private static string? SafeReference(string? value) => value is { Length: > 0 and <= 4096 } && !value.Any(char.IsControl) ? value : null;
    private static DateTimeOffset? Date(JsonElement item, string name) =>
        DateTimeOffset.TryParse(String(item, name), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var date) ? date : null;
    private static long? NonNegativeLong(JsonElement item, string name)
    {
        var value = Property(item, name);
        if (value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var number)) return number >= 0 ? number : null;
        if (value.ValueKind == JsonValueKind.String && long.TryParse(value.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out number)) return number >= 0 ? number : null;
        return null;
    }
    private static bool? Bool(JsonElement item, string name)
    {
        var value = Property(item, name);
        return value.ValueKind is JsonValueKind.True or JsonValueKind.False ? value.GetBoolean() : null;
    }
    private static bool HasText(JsonElement item, string name)
    {
        var value = Property(item, name);
        return value.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(value.GetString());
    }
    private static string? String(JsonElement item, string name)
    {
        var value = Property(item, name);
        return value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    }
    private static JsonElement Property(JsonElement item, string name)
    {
        if (item.ValueKind != JsonValueKind.Object) return default;
        foreach (var property in item.EnumerateObject())
            if (property.Name.Equals(name, StringComparison.OrdinalIgnoreCase)) return property.Value;
        return default;
    }
    private static string SafeText(string? value, int max)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        var builder = new System.Text.StringBuilder(Math.Min(value.Length, max));
        foreach (var rune in value.EnumerateRunes())
        {
            if (System.Text.Rune.IsControl(rune)) continue;
            if (builder.Length + rune.Utf16SequenceLength > max) break;
            builder.Append(rune.ToString());
        }
        return builder.ToString().Trim();
    }
}
