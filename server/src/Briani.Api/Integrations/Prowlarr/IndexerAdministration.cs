using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Security;

namespace Briani.Api.Integrations.Prowlarr;

// Wire shapes for the administrator indexer page. Configured indexers are returned
// without any field values: Prowlarr 2.6.5 hands back Cardigann credentials (passwords,
// cookies, passkeys) in plain text, and its own privacy flag does not mark most of them.
public sealed record AdminIndexer(string Id, string Name, string Definition, bool Enabled, string Privacy, int Priority,
    bool SupportsSearch, bool SupportsRecent, string State, string? StateDetail);
public sealed record IndexerDefinitionSummary(string Key, string Name, string Description, string Language, string Privacy,
    bool SupportsSearch, bool SupportsRecent, bool Addable, string? SetupNote);
public sealed record IndexerSettingOption(string Value, string Label);
public sealed record IndexerSettingField(string Name, string Label, string Kind, bool Advanced, string? HelpText, string? Unit,
    string? Value, IReadOnlyList<IndexerSettingOption>? Options);
public sealed record IndexerDefinitionDetail(string Key, string Name, string Description, string Privacy, bool Addable,
    string? SetupNote, IReadOnlyList<IndexerSettingField> Fields);
public sealed record IndexerTestResult(string Id, string State, string Detail, DateTimeOffset CheckedAt);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record IndexerCreateRequest([property: JsonRequired] string Definition, string? Name, bool? Enabled,
    Dictionary<string, string>? Settings);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record IndexerPatchRequest([property: JsonRequired] bool Enabled);
// Prowlarr was sent a change but did not confirm it in time, so it may still apply it.
public sealed class UnconfirmedIndexerChange() : Exception("indexer_timeout");

/// <summary>
/// Narrow administrator view of Prowlarr's torrent indexers: list, add from a definition,
/// enable/disable, test and remove. Only the fixed <see cref="ProwlarrCall"/> operations are used.
/// </summary>
public sealed class IndexerAdministration(IProwlarrAdminTransport transport, ServiceConnections connections, TimeProvider clock)
{
    private const int MaxDefinitions = 2000;
    private const int MaxFields = 48;
    private const int MaxSettingLength = 4096;
    private static readonly TimeSpan CatalogLifetime = TimeSpan.FromMinutes(10);
    private static readonly Regex KeyPattern = new("\\A[A-Za-z0-9._-]{1,100}\\z");
    private static readonly Regex SecretName = new("pass|key|cookie|token|secret|2fa|otp|session|auth|hash|\\Apid\\z|\\Auid\\z|\\Apin\\z", RegexOptions.IgnoreCase);
    private static readonly Regex Address = new("[A-Za-z][A-Za-z0-9+.-]{1,20}://[^\\s\\]\\)\"'<>]+");
    private static readonly string[] RenderedTypes = ["textbox", "password", "number", "checkbox", "select", "info"];
    private const string AddressNote = "This indexer uses a site address you type in yourself, so it is set up in Prowlarr's own page.";
    private const string UnsupportedNote = "This indexer needs settings Briani does not show (such as a CAPTCHA), so it is set up in Prowlarr's own page.";
    private const string FlareSolverrNote = "This indexer needs FlareSolverr, which is set up in Prowlarr's own page.";
    private const string DuplicateNote = "This indexer type is set up in Prowlarr's own page.";

    private readonly SemaphoreSlim catalogGate = new(1, 1);
    // Upstream changes are serialized so an observe/compare/act toggle never interleaves with another change.
    // Tests share it, so this page's slow Prowlarr calls hold at most one of SafeHttp's two connection slots.
    private readonly SemaphoreSlim mutations = new(1, 1);
    private Catalog? catalog;

    private sealed record Catalog(long Version, DateTimeOffset LoadedAt, IndexerDefinitionSummary[] Summaries, Dictionary<string, byte[]> Entries);
    private sealed record FieldRule(IndexerSettingField Field, bool NumericOptions);
    private sealed record Health(DateTimeOffset? DisabledTill, bool Failed);

    public async Task<AdminIndexer[]> ListAsync(CancellationToken ct = default)
    {
        var reply = await SendAsync(ProwlarrCall.ListIndexers(), ct);
        Expect(reply, 200);
        var health = await HealthAsync(ct);
        using var document = Parse(reply.Body, 32);
        if (document.RootElement.ValueKind != JsonValueKind.Array) throw Invalid();
        var output = new List<AdminIndexer>();
        foreach (var item in document.RootElement.EnumerateArray())
        {
            if (Summary(item, health) is { } summary) output.Add(summary);
            if (output.Count == 500) break;
        }
        return output.ToArray();
    }

    public async Task<IndexerDefinitionSummary[]> DefinitionsAsync(CancellationToken ct = default) =>
        (await CatalogAsync(ct)).Summaries;

    public async Task<IndexerDefinitionDetail> DefinitionAsync(string key, CancellationToken ct = default)
    {
        var (summary, entry) = await EntryAsync(key, ct);
        using var document = Parse(entry, 32);
        var rules = Rules(document.RootElement);
        return new(summary.Key, summary.Name, summary.Description, summary.Privacy, summary.Addable, summary.SetupNote,
            summary.Addable ? rules.Values.Select(x => x.Field).ToArray() : []);
    }

    // Each change takes an authorize callback, run once the change holds the lock and just before the
    // write: a change can wait behind another one, and the administrator may be demoted meanwhile.
    public async Task<AdminIndexer> CreateAsync(IndexerCreateRequest request, Func<CancellationToken, Task> authorize, CancellationToken ct = default)
    {
        ArgumentNullException.ThrowIfNull(request);
        var (summary, entry) = await EntryAsync(request.Definition ?? string.Empty, ct);
        if (!summary.Addable) throw new ApiException(409, "indexer_setup_in_prowlarr", summary.SetupNote);
        var name = IdentityInput.Text(string.IsNullOrWhiteSpace(request.Name) ? summary.Name : request.Name.Trim(), 100, field: "Name");
        var settings = request.Settings ?? [];
        if (settings.Count > MaxFields) throw new ApiException(400, "invalid_indexer_settings");

        var resource = JsonNode.Parse(entry)?.AsObject() ?? throw Invalid();
        using var document = Parse(entry, 32);
        var rules = Rules(document.RootElement);
        var fields = resource["fields"] as JsonArray ?? throw Invalid();
        var secrets = new List<string>();
        foreach (var (key, value) in settings)
        {
            if (!rules.TryGetValue(key ?? string.Empty, out var rule) || rule.Field.Kind == "info")
                throw new ApiException(400, "invalid_indexer_settings", $"'{SafeText(key, 64)}' is not a setting of this indexer.");
            // A blank number keeps Prowlarr's default rather than sending null into a typed setting.
            if (rule.Field.Kind is "integer" or "decimal" && string.IsNullOrWhiteSpace(value)) continue;
            var target = fields.OfType<JsonObject>().First(x => x["name"] is JsonValue named && named.TryGetValue<string>(out var text) && text == key);
            target["value"] = Convert(rule, value);
            if (rule.Field.Kind is "text" or "secret" && value is { Length: >= 4 }) secrets.Add(value);
        }
        resource["name"] = name;
        resource["enable"] = request.Enabled ?? true;
        resource["appProfileId"] = await ProfileAsync(ct);
        resource["tags"] = new JsonArray();
        resource["presets"] = new JsonArray();
        resource.Remove("id");
        var body = Encoding.UTF8.GetBytes(resource.ToJsonString());
        if (body.Length > 1048576) throw new ApiException(400, "invalid_indexer_settings");

        await mutations.WaitAsync(ct);
        try
        {
            await authorize(ct);
            // Prowlarr tests an enabled indexer before saving it; a failed test saves nothing.
            var reply = await ChangeAsync(ProwlarrCall.CreateIndexer(body));
            if (reply.Status == 400)
                throw new ApiException(400, "indexer_rejected", "Prowlarr did not add this indexer: " + Reason(reply.Body, secrets));
            Expect(reply, 201, 200);
            using var created = Parse(reply.Body, 32);
            return Summary(created.RootElement, await HealthAsync(CancellationToken.None)) ?? throw Invalid();
        }
        finally { mutations.Release(); }
    }

    public async Task<(AdminIndexer Indexer, bool Changed)> SetEnabledAsync(int id, bool enabled, Func<CancellationToken, Task> authorize, CancellationToken ct = default)
    {
        await mutations.WaitAsync(ct);
        try
        {
            var (resource, raw) = await IndexerAsync(id, ct);
            if (resource["enable"]?.GetValueKind() is JsonValueKind.True or JsonValueKind.False && resource["enable"]!.GetValue<bool>() == enabled)
            {
                using var unchanged = Parse(raw, 32);
                return (Summary(unchanged.RootElement, await HealthAsync(ct)) ?? throw Invalid(), false);
            }
            resource["enable"] = enabled;
            await authorize(ct);
            // Without forceSave Prowlarr tests the indexer when it is being enabled and keeps it disabled on failure.
            var reply = await ChangeAsync(ProwlarrCall.UpdateIndexer(id, Encoding.UTF8.GetBytes(resource.ToJsonString())));
            if (reply.Status == 404) throw new ApiException(404, "not_found");
            if (reply.Status == 400)
                throw new ApiException(400, "indexer_rejected",
                    (enabled ? "Prowlarr did not enable this indexer: " : "Prowlarr did not save this change: ") + Reason(reply.Body, Secrets(raw)));
            Expect(reply, 202, 200);
            using var updated = Parse(reply.Body, 32);
            return (Summary(updated.RootElement, await HealthAsync(CancellationToken.None)) ?? throw Invalid(), true);
        }
        finally { mutations.Release(); }
    }

    public async Task<IndexerTestResult> TestAsync(int id, CancellationToken ct = default)
    {
        await mutations.WaitAsync(ct);
        try { return await TestLockedAsync(id, ct); }
        finally { mutations.Release(); }
    }

    private async Task<IndexerTestResult> TestLockedAsync(int id, CancellationToken ct)
    {
        var (_, raw) = await IndexerAsync(id, ct);
        var identifier = id.ToString(CultureInfo.InvariantCulture);
        try
        {
            var reply = await SendAsync(ProwlarrCall.TestIndexer(raw), ct);
            if (reply.Status == 404) throw new ApiException(404, "not_found");
            if (reply.Status == 400) return new(identifier, "unavailable", Reason(reply.Body, Secrets(raw)), clock.GetUtcNow());
            Expect(reply, 200);
            return new(identifier, "healthy", "Prowlarr reached this indexer and it returned results.", clock.GetUtcNow());
        }
        catch (ApiException error) when (error.Code == "indexer_timeout")
        {
            return new(identifier, "unknown", "Prowlarr did not finish the test in time. Try again, or check Prowlarr's own page.", clock.GetUtcNow());
        }
    }

    public async Task DeleteAsync(int id, Func<CancellationToken, Task> authorize, CancellationToken ct = default)
    {
        await mutations.WaitAsync(ct);
        try
        {
            // Prowlarr answers 200 for unknown IDs too, so existence and protocol are checked first.
            await IndexerAsync(id, ct);
            await authorize(ct);
            var reply = await ChangeAsync(ProwlarrCall.DeleteIndexer(id));
            if (reply.Status == 404) throw new ApiException(404, "not_found");
            Expect(reply, 200);
        }
        finally { mutations.Release(); }
    }

    private async Task<(JsonObject Resource, byte[] Raw)> IndexerAsync(int id, CancellationToken ct)
    {
        var reply = await SendAsync(ProwlarrCall.GetIndexer(id), ct);
        if (reply.Status == 404) throw new ApiException(404, "not_found");
        Expect(reply, 200);
        var resource = ParseNode(reply.Body);
        // Usenet indexers are outside Briani's scope and stay untouched.
        if (!string.Equals((string?)resource["protocol"], "torrent", StringComparison.OrdinalIgnoreCase)) throw new ApiException(404, "not_found");
        return (resource, reply.Body);
    }

    private async Task<int> ProfileAsync(CancellationToken ct)
    {
        var reply = await SendAsync(ProwlarrCall.AppProfiles(), ct);
        Expect(reply, 200);
        using var document = Parse(reply.Body, 16);
        if (document.RootElement.ValueKind != JsonValueKind.Array) throw Invalid();
        var ids = document.RootElement.EnumerateArray()
            .Select(x => x.ValueKind == JsonValueKind.Object && x.TryGetProperty("id", out var id) && id.TryGetInt32(out var value) ? value : 0)
            .Where(x => x > 0).ToArray();
        // Prowlarr's own add dialog defaults to the first sync profile as well.
        return ids.Length > 0 ? ids.Min() : throw new ApiException(409, "indexer_profile_missing");
    }

    private async Task<Dictionary<long, Health>> HealthAsync(CancellationToken ct)
    {
        var output = new Dictionary<long, Health>();
        try
        {
            var reply = await SendAsync(ProwlarrCall.IndexerStatus(), ct);
            if (reply.Status != 200) return output;
            using var document = Parse(reply.Body, 16);
            if (document.RootElement.ValueKind != JsonValueKind.Array) return output;
            foreach (var entry in document.RootElement.EnumerateArray())
            {
                if (entry.ValueKind != JsonValueKind.Object || !entry.TryGetProperty("indexerId", out var raw) || !raw.TryGetInt64(out var id) || id <= 0) continue;
                output[id] = new(Date(entry, "disabledTill"), HasText(entry, "mostRecentFailure") || HasText(entry, "initialFailure"));
                if (output.Count == 500) break;
            }
        }
        catch (ApiException) { }
        return output;
    }

    private AdminIndexer? Summary(JsonElement item, Dictionary<long, Health> health)
    {
        if (item.ValueKind != JsonValueKind.Object || !item.TryGetProperty("id", out var rawId) || !rawId.TryGetInt32(out var id) || id <= 0) return null;
        if (!string.Equals(String(item, "protocol"), "torrent", StringComparison.OrdinalIgnoreCase)) return null;
        var enabled = Bool(item, "enable") ?? false;
        var priority = item.TryGetProperty("priority", out var rawPriority) && rawPriority.TryGetInt32(out var value) && value is >= 1 and <= 50 ? value : 25;
        var (state, detail) = !enabled ? ("unknown", (string?)null)
            : health.TryGetValue(id, out var observed) && observed.DisabledTill > clock.GetUtcNow() ? ("unavailable", "Prowlarr has paused this indexer after repeated failures.")
            : observed is { Failed: true } ? ("degraded", "This indexer failed recently in Prowlarr.")
            : ("healthy", "No recent failures in Prowlarr.");
        return new(id.ToString(CultureInfo.InvariantCulture), SafeText(String(item, "name"), 160) is { Length: > 0 } name ? name : "Indexer",
            SafeText(String(item, "definitionName"), 100), enabled, Privacy(String(item, "privacy")), priority,
            Bool(item, "supportsSearch") ?? true, Bool(item, "supportsRss") ?? false, state, detail);
    }

    private async Task<(IndexerDefinitionSummary Summary, byte[] Entry)> EntryAsync(string key, CancellationToken ct)
    {
        if (!KeyPattern.IsMatch(key)) throw new ApiException(404, "not_found");
        var current = await CatalogAsync(ct);
        if (!current.Entries.TryGetValue(key, out var entry)) throw new ApiException(404, "not_found");
        return (current.Summaries.First(x => x.Key == key), entry);
    }

    private async Task<Catalog> CatalogAsync(CancellationToken ct)
    {
        var version = (await connections.ReadAsync("prowlarr", ct)).Version;
        if (Fresh(catalog, version) is { } cached) return cached;
        await catalogGate.WaitAsync(ct);
        try
        {
            if (Fresh(catalog, version) is { } loaded) return loaded;
            var reply = await SendAsync(ProwlarrCall.IndexerSchema(), ct);
            Expect(reply, 200);
            using var document = Parse(reply.Body, 64);
            if (document.RootElement.ValueKind != JsonValueKind.Array) throw Invalid();
            var torrent = document.RootElement.EnumerateArray()
                .Where(x => x.ValueKind == JsonValueKind.Object && string.Equals(String(x, "protocol"), "torrent", StringComparison.OrdinalIgnoreCase)
                    && String(x, "definitionName") is { Length: > 0 and <= 100 } name && !name.Any(char.IsControl))
                .Take(MaxDefinitions).ToArray();
            var repeated = torrent.GroupBy(x => String(x, "definitionName")!, StringComparer.OrdinalIgnoreCase)
                .Where(x => x.Count() > 1).Select(x => x.Key).ToHashSet(StringComparer.OrdinalIgnoreCase);
            var summaries = new List<IndexerDefinitionSummary>();
            var entries = new Dictionary<string, byte[]>(StringComparer.Ordinal);
            var ordinals = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in torrent)
            {
                var definition = String(item, "definitionName")!;
                var duplicate = repeated.Contains(definition);
                // Native definitions are named after their implementation and may contain spaces.
                var slug = Regex.Replace(definition, "[^A-Za-z0-9._-]+", "-").Trim('-');
                var key = duplicate ? $"{slug}-{ordinals[definition] = ordinals.GetValueOrDefault(definition) + 1}" : slug;
                if (!KeyPattern.IsMatch(key) || entries.ContainsKey(key)) continue;
                var note = duplicate ? DuplicateNote : SetupNote(item);
                summaries.Add(new(key, SafeText(String(item, "name"), 160) is { Length: > 0 } name ? name : definition,
                    SafeText(String(item, "description"), 300), SafeText(String(item, "language"), 20), Privacy(String(item, "privacy")),
                    Bool(item, "supportsSearch") ?? true, Bool(item, "supportsRss") ?? false, note is null, note));
                entries[key] = Encoding.UTF8.GetBytes(item.GetRawText());
            }
            var fresh = new Catalog(version, clock.GetUtcNow(),
                summaries.OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase).ThenBy(x => x.Key, StringComparer.Ordinal).ToArray(), entries);
            catalog = fresh;
            return fresh;
        }
        finally { catalogGate.Release(); }
    }

    private Catalog? Fresh(Catalog? value, long version) =>
        value is not null && value.Version == version && clock.GetUtcNow() - value.LoadedAt < CatalogLifetime ? value : null;

    // Briani renders a definition only when every setting it would show is one of the plain
    // kinds below and the site address is one of the definition's own links; anything else
    // (free-form addresses, CAPTCHA, dynamic options, FlareSolverr) stays in Prowlarr's page.
    private static string? SetupNote(JsonElement entry)
    {
        if (Urls(entry).Length == 0) return AddressNote;
        if (!entry.TryGetProperty("fields", out var fields) || fields.ValueKind != JsonValueKind.Array) return UnsupportedNote;
        var names = new HashSet<string>(StringComparer.Ordinal);
        var address = false;
        foreach (var field in fields.EnumerateArray())
        {
            var name = String(field, "name") ?? string.Empty;
            var type = String(field, "type");
            if (Kept(field, name)) continue;
            if (!names.Add(name) || names.Count > MaxFields) return UnsupportedNote;
            if (name == "baseUrl")
            {
                if (type != "select" || String(field, "selectOptionsProviderAction") != "getUrls") return AddressNote;
                address = true;
                continue;
            }
            if (name.Equals("info_flaresolverr", StringComparison.OrdinalIgnoreCase)) return FlareSolverrNote;
            if (!RenderedTypes.Contains(type) || String(field, "selectOptionsProviderAction") is not null) return UnsupportedNote;
            if (type == "select" && (!field.TryGetProperty("selectOptions", out var options) || options.ValueKind != JsonValueKind.Array || options.GetArrayLength() is 0 or > 200))
                return UnsupportedNote;
        }
        return address ? null : AddressNote;
    }

    // Prowlarr's own defaults are kept for the definition file, hidden fields and the
    // app-sync/limit settings, which Briani's discovery does not use.
    private static bool Kept(JsonElement field, string name) =>
        name is "definitionFile" || name.StartsWith("baseSettings.", StringComparison.Ordinal) || name.StartsWith("torrentBaseSettings.", StringComparison.Ordinal)
        || String(field, "hidden") is { Length: > 0 } hidden && !hidden.Equals("visible", StringComparison.OrdinalIgnoreCase);

    private static Dictionary<string, FieldRule> Rules(JsonElement entry)
    {
        var output = new Dictionary<string, FieldRule>(StringComparer.Ordinal);
        if (SetupNote(entry) is not null) return output;
        var urls = Urls(entry);
        foreach (var field in entry.GetProperty("fields").EnumerateArray())
        {
            var name = String(field, "name")!;
            if (Kept(field, name)) continue;
            var type = String(field, "type");
            var label = PlainText(String(field, "label"), 120) is { Length: > 0 } text ? text : name;
            var help = PlainText(String(field, "helpText"), 400);
            var warning = PlainText(String(field, "helpTextWarning"), 300);
            var helpText = string.Join(" ", new[] { help, warning }.Where(x => x.Length > 0)) is { Length: > 0 } joined ? joined : null;
            var advanced = Bool(field, "advanced") ?? false;
            var unit = SafeText(String(field, "unit"), 40) is { Length: > 0 } u ? u : null;
            field.TryGetProperty("value", out var value);
            IndexerSettingField setting;
            var numeric = false;
            if (name == "baseUrl")
                // An unset base address makes Prowlarr use the definition's first link.
                setting = new(name, label, "select", advanced, helpText, unit, urls[0], urls.Select(x => new IndexerSettingOption(x, x)).ToArray());
            else if (type == "select")
            {
                var options = field.GetProperty("selectOptions").EnumerateArray()
                    .Select(x => (Value: Scalar(Property(x, "value")), Label: PlainText(String(x, "name"), 120), Numeric: Property(x, "value").ValueKind == JsonValueKind.Number))
                    .Where(x => x.Value is not null).ToArray();
                numeric = options.Length > 0 && options.All(x => x.Numeric);
                var chosen = Scalar(value);
                setting = new(name, label, "select", advanced, helpText, unit, options.Any(x => x.Value == chosen) ? chosen : null,
                    options.Select(x => new IndexerSettingOption(x.Value!, x.Label.Length > 0 ? x.Label : x.Value!)).ToArray());
            }
            else if (type == "checkbox")
                setting = new(name, label, "checkbox", advanced, helpText, unit, value.ValueKind == JsonValueKind.True ? "true" : "false", null);
            else if (type == "number")
                setting = new(name, label, Bool(field, "isFloat") == true ? "decimal" : "integer", advanced, helpText, unit,
                    value.ValueKind == JsonValueKind.Number ? Scalar(value) : null, null);
            else if (type == "info")
            {
                var info = PlainText(value.ValueKind == JsonValueKind.String ? value.GetString() : null, 2000);
                if (info.Length == 0) continue;
                setting = new(name, label, "info", false, null, null, info, null);
            }
            else if (IsSecret(field, name, type))
                setting = new(name, label, "secret", advanced, helpText, unit, null, null);
            else
                setting = new(name, label, "text", advanced, helpText, unit,
                    value.ValueKind == JsonValueKind.String && SafeText(value.GetString(), MaxSettingLength) is { Length: > 0 } t ? t : null, null);
            output[name] = new(setting, numeric);
        }
        return output;
    }

    private static bool IsSecret(JsonElement field, string name, string? type) =>
        type == "password" || String(field, "privacy") is "password" or "apiKey" || SecretName.IsMatch(name);

    private static JsonNode? Convert(FieldRule rule, string? value)
    {
        var field = rule.Field;
        value ??= string.Empty;
        if (value.Length > MaxSettingLength) throw new ApiException(400, "invalid_indexer_settings", $"{field.Label} must be at most {MaxSettingLength} characters.");
        if (value.Any(char.IsControl)) throw new ApiException(400, "invalid_indexer_settings", $"{field.Label} cannot contain control characters.");
        switch (field.Kind)
        {
            case "text" or "secret":
                return JsonValue.Create(value);
            case "checkbox":
                return value.ToLowerInvariant() switch
                {
                    "true" => JsonValue.Create(true),
                    "false" => JsonValue.Create(false),
                    _ => throw new ApiException(400, "invalid_indexer_settings", $"{field.Label} must be on or off.")
                };
            case "integer":
                return int.TryParse(value.Trim(), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var whole)
                    ? JsonValue.Create(whole)
                    : throw new ApiException(400, "invalid_indexer_settings", $"{field.Label} must be a whole number.");
            case "decimal":
                return double.TryParse(value.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var number) && double.IsFinite(number)
                    ? JsonValue.Create(number)
                    : throw new ApiException(400, "invalid_indexer_settings", $"{field.Label} must be a number.");
            case "select":
                if (field.Options?.Any(x => x.Value == value) != true)
                    throw new ApiException(400, "invalid_indexer_settings", $"Choose one of the listed values for {field.Label}.");
                return rule.NumericOptions ? JsonValue.Create(long.Parse(value, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture)) : JsonValue.Create(value);
            default:
                throw new ApiException(400, "invalid_indexer_settings");
        }
    }

    // Prowlarr's validation messages can quote site responses and request URLs (which may
    // carry passkeys), and its failure objects echo attempted values. Only the message text
    // is used, with addresses and every known setting value removed.
    private static string Reason(byte[] body, IEnumerable<string> secrets)
    {
        var hidden = secrets.Where(x => x.Length >= 4).Distinct().OrderByDescending(x => x.Length).ToArray();
        var parts = new List<string>();
        try
        {
            using var document = Parse(body, 16);
            if (document.RootElement.ValueKind == JsonValueKind.Array)
                foreach (var failure in document.RootElement.EnumerateArray().Take(3))
                {
                    // The whole message is scrubbed before it is shortened, so a cut never leaves part of a value behind.
                    var message = SafeText(Scrub(SafeText(String(failure, "errorMessage"), int.MaxValue), hidden), 300);
                    if (message.Length == 0) continue;
                    var property = String(failure, "propertyName");
                    parts.Add(property is { Length: > 0 and <= 64 } && property.All(x => char.IsAsciiLetterOrDigit(x) || x == '.') ? $"{property}: {message}" : message);
                }
        }
        catch (ApiException) { }
        var text = string.Join(" ", parts);
        return text.Length > 0 ? text : "Prowlarr rejected the request.";
    }

    private static string Scrub(string text, string[] secrets)
    {
        text = Address.Replace(text, "(address hidden)");
        foreach (var secret in secrets) text = text.Replace(secret, "(hidden)", StringComparison.OrdinalIgnoreCase);
        return text;
    }

    private static string[] Secrets(byte[] raw)
    {
        try
        {
            using var document = Parse(raw, 32);
            if (!document.RootElement.TryGetProperty("fields", out var fields) || fields.ValueKind != JsonValueKind.Array) return [];
            return fields.EnumerateArray().Select(x => Property(x, "value")).Where(x => x.ValueKind == JsonValueKind.String)
                .Select(x => x.GetString()!).Where(x => x.Length >= 4).Take(200).ToArray();
        }
        catch (ApiException) { return []; }
    }

    // A change that has been sent is not cancelled with the request (the transport's deadline still applies),
    // so its outcome is known and audited even when the caller goes away. A late answer is unconfirmed.
    private async Task<ProwlarrReply> ChangeAsync(ProwlarrCall call)
    {
        try { return await SendAsync(call, CancellationToken.None); }
        catch (ApiException error) when (error.Code == "indexer_timeout") { throw new UnconfirmedIndexerChange(); }
    }

    private async Task<ProwlarrReply> SendAsync(ProwlarrCall call, CancellationToken ct)
    {
        try { return await transport.SendAsync(call, ct); }
        catch (ProwlarrFailure error)
        {
            throw error.Code switch
            {
                "credentials_missing" => new ApiException(503, "credentials_missing"),
                "credentials_rejected" => new ApiException(503, "prowlarr_credentials_rejected"),
                "source_timeout" or "timeout" => new ApiException(504, "indexer_timeout"),
                _ => new ApiException(503, "dependency_unavailable")
            };
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new ApiException(504, "indexer_timeout"); }
        catch (HttpRequestException) { throw new ApiException(503, "dependency_unavailable"); }
    }

    private static void Expect(ProwlarrReply reply, params int[] statuses)
    {
        if (!statuses.Contains(reply.Status)) throw new ApiException(503, "dependency_unavailable");
    }

    private static string[] Urls(JsonElement entry)
    {
        if (!entry.TryGetProperty("indexerUrls", out var urls) || urls.ValueKind != JsonValueKind.Array) return [];
        return urls.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.String).Select(x => x.GetString()!)
            .Where(x => x.Length <= 512 && Uri.TryCreate(x, UriKind.Absolute, out var uri) && uri.Scheme is "http" or "https" && uri.UserInfo.Length == 0 && !x.Any(char.IsControl))
            .Distinct(StringComparer.Ordinal).Take(20).ToArray();
    }

    private static string Privacy(string? value) => value switch
    {
        "public" => "public",
        "semiPrivate" => "semiPrivate",
        "private" => "private",
        _ => "unknown"
    };

    private static ApiException Invalid() => new(503, "dependency_unavailable");

    private static JsonDocument Parse(byte[] body, int depth)
    {
        try { return JsonDocument.Parse(body, new JsonDocumentOptions { MaxDepth = depth }); }
        catch (JsonException) { throw Invalid(); }
    }

    private static JsonObject ParseNode(byte[] body)
    {
        try { return JsonNode.Parse(body, documentOptions: new JsonDocumentOptions { MaxDepth = 32 }) as JsonObject ?? throw Invalid(); }
        catch (JsonException) { throw Invalid(); }
    }

    private static string? Scalar(JsonElement value) => value.ValueKind switch
    {
        JsonValueKind.Number => value.GetRawText(),
        JsonValueKind.String => SafeText(value.GetString(), MaxSettingLength),
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        _ => null
    };

    private static DateTimeOffset? Date(JsonElement item, string name) =>
        DateTimeOffset.TryParse(String(item, name), CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var date) ? date : null;

    private static bool? Bool(JsonElement item, string name)
    {
        var value = Property(item, name);
        return value.ValueKind is JsonValueKind.True or JsonValueKind.False ? value.GetBoolean() : null;
    }

    private static bool HasText(JsonElement item, string name) =>
        Property(item, name) is { ValueKind: JsonValueKind.String } value && !string.IsNullOrWhiteSpace(value.GetString());

    private static string? String(JsonElement item, string name) =>
        Property(item, name) is { ValueKind: JsonValueKind.String } value ? value.GetString() : null;

    private static JsonElement Property(JsonElement item, string name) =>
        item.ValueKind == JsonValueKind.Object && item.TryGetProperty(name, out var value) ? value : default;

    // Definition help and info texts contain HTML; they are shown as plain text only.
    private static string PlainText(string? html, int max)
    {
        if (string.IsNullOrEmpty(html)) return string.Empty;
        var text = Regex.Replace(html, "<\\s*(br|/li|/p|/div)\\s*/?>", "\n", RegexOptions.IgnoreCase);
        text = Regex.Replace(text, "<\\s*li\\s*>", "• ", RegexOptions.IgnoreCase);
        text = WebUtility.HtmlDecode(Regex.Replace(text, "<[^>]*>", string.Empty));
        var lines = text.Split('\n').Select(x => SafeText(Regex.Replace(x, "\\s+", " "), max)).Where(x => x.Length > 0);
        var joined = string.Join("\n", lines);
        return joined.Length <= max ? joined : joined[..max].TrimEnd();
    }

    private static string SafeText(string? value, int max)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        var builder = new StringBuilder(Math.Min(value.Length, max));
        foreach (var rune in value.EnumerateRunes())
        {
            if (Rune.IsControl(rune)) continue;
            if (builder.Length + rune.Utf16SequenceLength > max) break;
            builder.Append(rune.ToString());
        }
        return builder.ToString().Trim();
    }
}
