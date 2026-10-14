using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Security;

namespace Briani.Api.Integrations.QBittorrent;

/// <summary>Typed, bounded adapter for the pinned qBittorrent Web API.</summary>
public sealed class QBitTorrentClient(ServiceConnections connections, ISafeDns dns) : ITorrentEngine
{
    private long connectionGeneration;
    public long ConnectionGeneration => Interlocked.Read(ref connectionGeneration);
    private const int JsonLimit = 8 * 1024 * 1024;
    private const int MetainfoLimit = 16 * 1024 * 1024;
    private const int MaxTorrents = 500;
    private const int MaxPieces = 4_000_000;
    private static readonly Version RequiredApplication = new(5, 2, 4);
    private static readonly Version RequiredApi = new(2, 15, 1);
    private static readonly Version RequiredLibtorrent = new(2, 0, 15);
    private static readonly SemaphoreSlim ManagedConfiguration = new(1,1);
    private static readonly SemaphoreSlim Requests = new(2, 2);
    private static readonly SemaphoreSlim[] TorrentLocks = Enumerable.Range(0, 64).Select(_ => new SemaphoreSlim(1, 1)).ToArray();
    private readonly object sessionSync = new();
    private Session? session;

    private sealed class Session(ServiceConnection connection)
    {
        public ServiceConnection Connection { get; } = connection;
        public CookieContainer Cookies { get; set; } = new();
        public SemaphoreSlim Gate { get; } = new(1, 1);
        public bool LoggedIn { get; set; }
    }

    public async Task<EngineVersion> VersionAsync(CancellationToken ct = default)
    {
        var app = await TextAsync("app/version", ct);
        var api = await TextAsync("app/webapiVersion", ct);
        using var build = await JsonAsync("app/buildInfo", ct);
        var libtorrent = Str(build.RootElement, "libtorrent");
        if (!Compatible(app, RequiredApplication) || !Compatible(api, RequiredApi) || !Compatible(libtorrent, RequiredLibtorrent))
            throw new EngineFailure("engine_incompatible");
        return new EngineVersion(app, api, libtorrent);
    }

    public async Task<EngineTorrent[]> TorrentsAsync(string? hash = null, CancellationToken ct = default)
    {
        var path = "torrents/info?limit=" + (string.IsNullOrWhiteSpace(hash) ? "501" : "2") + (string.IsNullOrWhiteSpace(hash) ? "" : "&hashes=" + Uri.EscapeDataString(ValidHash(hash)));
        using var doc = await JsonAsync(path, ct);
        if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() > MaxTorrents)
            throw new EngineFailure("engine_response_invalid");
        return doc.RootElement.EnumerateArray().Select(MapTorrent).ToArray();
    }

    public async Task<EngineFile[]> FilesAsync(string hash, CancellationToken ct = default)
    {
        using var doc = await JsonAsync("torrents/files?hash=" + Uri.EscapeDataString(ValidHash(hash)), ct);
        if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() > 10000)
            throw new EngineFailure("engine_response_invalid");
        var result = new List<EngineFile>(doc.RootElement.GetArrayLength());
        foreach (var item in doc.RootElement.EnumerateArray())
        {
            var index = Int(item, "index", -1); var path = Str(item, "name"); var bytes = Long(item, "size", -1);
            var range = item.TryGetProperty("piece_range", out var r) && r.ValueKind == JsonValueKind.Array ? r : default;
            var first = range.ValueKind == JsonValueKind.Array && range.GetArrayLength() == 2 ? range[0].GetInt32() : -1;
            var last = range.ValueKind == JsonValueKind.Array && range.GetArrayLength() == 2 ? range[1].GetInt32() : -1;
            if (index < 0 || bytes < 0 || path.Length > 4096 || first < -1 || last < -1) throw new EngineFailure("engine_response_invalid");
            result.Add(new(index, path, bytes, Double(item, "progress"), Int(item, "priority", 0), first, last));
        }
        return result.ToArray();
    }

    public Task<byte[]> ExportAsync(string hash, CancellationToken ct = default) => BytesAsync("torrents/export?hash=" + Uri.EscapeDataString(ValidHash(hash)), MetainfoLimit, ct);

    public async Task<byte[]> PiecesAsync(string hash, CancellationToken ct = default)
    {
        using var doc = await JsonAsync("torrents/pieceStates?hash=" + Uri.EscapeDataString(ValidHash(hash)), ct);
        if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() > MaxPieces) throw new EngineFailure("engine_response_invalid");
        var bytes = new byte[doc.RootElement.GetArrayLength()]; var i = 0;
        foreach (var value in doc.RootElement.EnumerateArray())
        {
            if (!value.TryGetInt32(out var state) || state is < 0 or > 2) throw new EngineFailure("engine_response_invalid");
            bytes[i++] = (byte)state;
        }
        return bytes;
    }

    public async Task<EngineTracker[]> TrackersAsync(string hash, CancellationToken ct = default)
    {
        using var doc = await JsonAsync("torrents/trackers?hash=" + Uri.EscapeDataString(ValidHash(hash)), ct);
        if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() > 256) throw new EngineFailure("engine_response_invalid");
        var trackers = new List<EngineTracker>();
        foreach (var item in doc.RootElement.EnumerateArray())
        {
            var url = Str(item, "url");
            if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Host.Length > 253) continue;
            trackers.Add(new(uri.IdnHost, SafeStatus(Str(item, "status")), NullableInt(item, "num_seeds"), NullableInt(item, "num_peers")));
        }
        return trackers.ToArray();
    }

    public async Task AddAsync(EngineAdd add, CancellationToken ct = default)
    {
        if (add is null || !SafeSavePath(add.SavePath) || !ValidOwnershipTag(add.OwnershipTag)) throw new EngineFailure("invalid_add_request");
        var isMagnet = !string.IsNullOrWhiteSpace(add.Magnet);
        if (isMagnet == (add.Torrent is { Length: > 0 }) || (add.Torrent?.Length ?? 0) > MetainfoLimit || (add.Magnet?.Length ?? 0) > 65536)
            throw new EngineFailure("invalid_add_request");
        if (isMagnet && !add.Magnet!.StartsWith("magnet:?", StringComparison.OrdinalIgnoreCase)) throw new EngineFailure("invalid_add_request");
        if (add.MetadataOnly && !isMagnet) throw new EngineFailure("invalid_add_request");
        var fields = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["savepath"] = add.SavePath, ["autoTMM"] = "false", ["category"] = "briani",
            ["tags"] = add.OwnershipTag, ["sequentialDownload"] = "true", ["firstLastPiecePrio"] = "true"
        };
        if (isMagnet)
        {
            fields["urls"] = add.Magnet!;
            if (add.MetadataOnly) { fields["stopCondition"] = "MetadataReceived"; fields["stopped"] = "false"; }
            else fields["stopped"] = "true";
        }
        else
        {
            fields["stopped"] = "true";
        }
        await SendAsync("torrents/add", HttpMethod.Post, fields, add.Torrent, ct);
    }

    public Task StopAsync(string hash, CancellationToken ct = default) => ActionAsync("torrents/stop", hash, ct);
    public Task StartAsync(string hash, CancellationToken ct = default) => ActionAsync("torrents/start", hash, ct);

    public Task EnsureSequentialAsync(string hash, bool enabled, CancellationToken ct = default) => EnsureToggleAsync(hash, "seq_dl", "torrents/toggleSequentialDownload", enabled, ct);
    public Task EnsureMetadataAssistAsync(string hash, bool enabled, CancellationToken ct = default) => EnsureToggleAsync(hash, "f_l_piece_prio", "torrents/toggleFirstLastPiecePrio", enabled, ct);

    public async Task SetFilePriorityAsync(string hash, int[] indexes, int priority, CancellationToken ct = default)
    {
        if (indexes is null || indexes.Length is < 1 or > 10000 || indexes.Any(x => x < 0) || indexes.Distinct().Count() != indexes.Length || priority is not (0 or 1 or 6 or 7))
            throw new EngineFailure("invalid_file_priority");
        await PostAsync("torrents/filePrio", new() { ["hash"] = ValidHash(hash), ["id"] = string.Join('|', indexes), ["priority"] = priority.ToString(CultureInfo.InvariantCulture) }, ct);
    }

    public async Task ApplyLimitsAsync(string hash, EngineLimits limits, CancellationToken ct = default)
    {
        var valid = ValidHash(hash);
        if (limits.DownloadLimitBytesPerSecond is < 0 or > 1_073_741_824 || limits.UploadLimitBytesPerSecond is < 0 or > 1_073_741_824 ||
            limits.RatioLimit is < 0 or > 10000 || limits.RatioLimit.HasValue && !double.IsFinite(limits.RatioLimit.Value) ||
            limits.SeedTimeMinutes is < 0 or > 525600 || limits.QueuePosition is < 0 or > 500 ||
            limits.Tags is { } tags && (tags.Length > 51 || tags.Any(t => string.IsNullOrWhiteSpace(t) || t.Length > 100 || t.Contains(',') || t.Any(char.IsControl)) ||
                tags.Count(ValidOwnershipTag) > 1))
            throw new EngineFailure("invalid_limits");
        if (limits.DownloadLimitBytesPerSecond.HasValue) await PostAsync("torrents/setDownloadLimit", new() { ["hashes"] = valid, ["limit"] = Number(limits.DownloadLimitBytesPerSecond.Value) }, ct);
        if (limits.UploadLimitBytesPerSecond.HasValue) await PostAsync("torrents/setUploadLimit", new() { ["hashes"] = valid, ["limit"] = Number(limits.UploadLimitBytesPerSecond.Value) }, ct);
        if (limits.RatioLimit.HasValue || limits.SeedTimeMinutes.HasValue)
            await PostAsync("torrents/setShareLimits", new() { ["hashes"] = valid, ["ratioLimit"] = limits.RatioLimit?.ToString(CultureInfo.InvariantCulture) ?? "-2", ["seedingTimeLimit"] = limits.SeedTimeMinutes?.ToString(CultureInfo.InvariantCulture) ?? "-2", ["inactiveSeedingTimeLimit"] = "-2", ["shareLimitAction"] = "Stop" }, ct);
        if (limits.QueuePosition.HasValue) await PostAsync("torrents/queuePosition", new() { ["hashes"] = valid, ["pos"] = limits.QueuePosition.Value.ToString(CultureInfo.InvariantCulture) }, ct);
        if (limits.Tags is not null)
            await PostAsync("torrents/addTags", new() { ["hashes"] = valid, ["tags"] = string.Join(',', limits.Tags) }, ct);
    }

    public Task RecheckAsync(string hash, CancellationToken ct = default) => ActionAsync("torrents/recheck", hash, ct);
    public Task ReannounceAsync(string hash, CancellationToken ct = default) => ActionAsync("torrents/reannounce", hash, ct);
    public async Task RemoveAsync(string hash, bool deleteFiles, CancellationToken ct = default) => await PostAsync("torrents/delete", new() { ["hashes"] = ValidHash(hash), ["deleteFiles"] = deleteFiles ? "true" : "false" }, ct);

    public async Task ConfigureManagedAsync(CancellationToken ct = default)
    {
        await ManagedConfiguration.WaitAsync(ct);
        try {
        using var doc = await JsonAsync("app/preferences", ct);
        if (doc.RootElement.ValueKind != JsonValueKind.Object) throw new EngineFailure("engine_response_invalid");
        var settings = await connections.AdministratorSettingsAsync(ct);
        var prefs = new Dictionary<string, object?>
        {
            ["upnp"] = false, ["web_ui_upnp"] = false, ["max_connec"] = settings["globalConnections"]!.GetValue<int>(), ["max_connec_per_torrent"] = settings["connectionsPerTorrent"]!.GetValue<int>(),
            ["max_active_downloads"] = settings["activeDownloads"]!.GetValue<int>(), ["max_active_uploads"] = settings["activeSeeds"]!.GetValue<int>(), ["max_active_torrents"] = settings["activeDownloads"]!.GetValue<int>() + settings["activeSeeds"]!.GetValue<int>(), ["queueing_enabled"] = true,
            ["web_ui_csrf_protection_enabled"] = true, ["web_ui_host_header_validation_enabled"] = true,
            ["web_ui_clickjacking_protection_enabled"] = true
        };
        await SendJsonAsync("app/setPreferences", prefs, ct);
        using var verify = await JsonAsync("app/preferences", ct);
        var mismatches = new List<string>();
        foreach (var pair in prefs)
            if (!verify.RootElement.TryGetProperty(pair.Key, out var actual) || !JsonEqual(actual, pair.Value)) mismatches.Add(pair.Key);
        if (mismatches.Count > 0)
        {
            var failure = new EngineFailure("engine_configuration_unverified");
            failure.Data["preferenceKeys"] = string.Join(',', mismatches);
            failure.Data["safeValues"] = string.Join(',', mismatches.Select(key =>
                verify.RootElement.TryGetProperty(key, out var value) ? key + "=" + value.ValueKind + ":" + value.ToString() : key + "=<missing>"));
            throw failure;
        }
        var desiredUpload = settings["uploadLimitBytesPerSecond"]?.GetValue<long>() ?? 0;
        await PostAsync("transfer/setUploadLimit", new() { ["limit"] = desiredUpload.ToString(CultureInfo.InvariantCulture) }, ct);
        var uploadLimit = await TextAsync("transfer/uploadLimit", ct);
        if (!long.TryParse(uploadLimit, NumberStyles.None, CultureInfo.InvariantCulture, out var appliedLimit) || appliedLimit != desiredUpload / 1024 * 1024)
            throw new EngineFailure("engine_configuration_unverified");
        var desiredDownload = settings["downloadLimitBytesPerSecond"]?.GetValue<long>() ?? 0;
        await PostAsync("transfer/setDownloadLimit", new() { ["limit"] = desiredDownload.ToString(CultureInfo.InvariantCulture) }, ct);
        var downloadLimit = await TextAsync("transfer/downloadLimit", ct);
        if (!long.TryParse(downloadLimit, NumberStyles.None, CultureInfo.InvariantCulture, out var downloadedLimit) || downloadedLimit != desiredDownload / 1024 * 1024)
            throw new EngineFailure("engine_configuration_unverified");
        } finally { ManagedConfiguration.Release(); }
    }

    private async Task EnsureToggleAsync(string hash, string field, string endpoint, bool enabled, CancellationToken ct)
    {
        hash = ValidHash(hash); var gate = TorrentLocks[int.Parse(hash.AsSpan(0, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture) & (TorrentLocks.Length - 1)]; await gate.WaitAsync(ct);
        try
        {
            var current = await FindTorrentAsync(hash, ct) ?? throw new EngineFailure("torrent_not_found");
            if (Bool(current, field) == enabled) return;
            try { await PostAsync(endpoint, new() { ["hashes"] = hash }, ct); }
            catch (EngineFailure e) when (e.Code == "engine_timeout")
            {
                // A toggle is not safe to repeat after an uncertain outcome; reconcile by observation.
                var observed = await FindTorrentAsync(hash, ct);
                if (observed is not null && Bool(observed.Value, field) == enabled) return;
                throw;
            }
            var after = await FindTorrentAsync(hash, ct);
            if (after is null || Bool(after.Value, field) != enabled) throw new EngineFailure("engine_action_unverified");
        }
        finally { gate.Release(); }
    }

    private async Task<JsonElement?> FindTorrentAsync(string hash, CancellationToken ct)
    {
        using var doc = await JsonAsync("torrents/info?hashes=" + Uri.EscapeDataString(hash) + "&limit=2", ct);
        if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() > 1) throw new EngineFailure("engine_response_invalid");
        return doc.RootElement.GetArrayLength() == 0 ? null : doc.RootElement[0].Clone();
    }

    private async Task ActionAsync(string endpoint, string hash, CancellationToken ct) => await PostAsync(endpoint, new() { ["hashes"] = ValidHash(hash) }, ct);
    private async Task<string> TextAsync(string path, CancellationToken ct)
    {
        var bytes = await BytesAsync(path, 4096, ct);
        try
        {
            var text = Encoding.UTF8.GetString(bytes).Trim();
            if (text.StartsWith('"')) return JsonSerializer.Deserialize<string>(text) ?? "";
            return text;
        }
        catch { throw new EngineFailure("engine_response_invalid"); }
    }
    private async Task<JsonDocument> JsonAsync(string path, CancellationToken ct)
    {
        try { return JsonDocument.Parse(await BytesAsync(path, JsonLimit, ct), new JsonDocumentOptions { MaxDepth = 16 }); }
        catch (JsonException) { throw new EngineFailure("engine_response_invalid"); }
    }
    private async Task<byte[]> BytesAsync(string path, int max, CancellationToken ct) => await SendAsync(path, HttpMethod.Get, null, null, ct, max);
    private Task PostAsync(string path, Dictionary<string, string> fields, CancellationToken ct) => SendAsync(path, HttpMethod.Post, fields, null, ct, 65536);
    private Task SendJsonAsync(string path, Dictionary<string, object?> values, CancellationToken ct)
    {
        var json = JsonSerializer.Serialize(values);
        return SendAsync(path, HttpMethod.Post, new() { ["json"] = json }, null, ct, 65536);
    }

    private async Task<byte[]> SendAsync(string path, HttpMethod method, Dictionary<string, string>? fields, byte[]? torrent, CancellationToken ct, int max = JsonLimit)
    {
        ValidatePath(path);
        HttpContent? content = null;
        if (fields is not null)
        {
            if (torrent is null) content = new FormUrlEncodedContent(fields);
            else
            {
                var form = new MultipartFormDataContent();
                foreach (var field in fields) form.Add(new StringContent(field.Value, Encoding.UTF8), field.Key);
                var file = new ByteArrayContent(torrent); file.Headers.ContentType = new MediaTypeHeaderValue("application/x-bittorrent");
                form.Add(file, "torrents", "managed.torrent"); content = form;
            }
        }
        return await SendRawAsync(path, method, content, ct, max);
    }

    private async Task<byte[]> SendRawAsync(string path, HttpMethod method, HttpContent? content, CancellationToken ct, int max)
    {
        byte[]? contentBytes = null;
        Dictionary<string, string[]>? contentHeaders = null;
        if (content is not null)
        {
            contentBytes = await content.ReadAsByteArrayAsync(ct);
            contentHeaders = content.Headers.ToDictionary(h => h.Key, h => h.Value.ToArray(), StringComparer.OrdinalIgnoreCase);
        }
        var service = await connections.RequiredAsync("qbittorrent", ct);
        if (service.Username is null || service.Username.Length > 200 || service.Secret.Length > 10000) throw new EngineFailure("engine_credentials_missing");
        if (!SafeOrigin(service.Origin)) throw new EngineFailure("engine_origin_invalid");
        var current = GetSession(service);
        await current.Gate.WaitAsync(ct);
        try
        {
            var result = await SendOnceAsync(current, path, method, NewContent(contentBytes, contentHeaders), max, ct, login: false);
            if (result.Status == 403 || result.Status == 401)
            {
                if (current.LoggedIn) Interlocked.Increment(ref connectionGeneration);
                current.LoggedIn = false; current.Cookies = new CookieContainer();
                await LoginAsync(current, ct);
                result = await SendOnceAsync(current, path, method, NewContent(contentBytes, contentHeaders), max, ct, login: false);
            }
            if (result.Status is < 200 or >= 300)
            {
                var failure = MapStatus(result.Status);
                failure.Data["apiPath"] = path;
                failure.Data["status"] = result.Status;
                throw failure;
            }
            current.LoggedIn = true;
            return result.Body;
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new EngineFailure("engine_timeout"); }
        catch (HttpRequestException) { throw new EngineFailure("engine_unavailable"); }
        finally { current.Gate.Release(); }
    }

    private static HttpContent? NewContent(byte[]? bytes, Dictionary<string, string[]>? headers)
    {
        if (bytes is null) return null;
        var copy = new ByteArrayContent(bytes);
        if (headers is not null)
            foreach (var h in headers) copy.Headers.TryAddWithoutValidation(h.Key, h.Value);
        return copy;
    }

    private Session GetSession(ServiceConnection service)
    {
        lock (sessionSync)
        {
            if (session is null || session.Connection.Version != service.Version || session.Connection.Origin != service.Origin || session.Connection.Username != service.Username || session.Connection.Secret != service.Secret)
            { if (session is not null) Interlocked.Increment(ref connectionGeneration); session = new Session(service); }
            return session;
        }
    }

    private async Task LoginAsync(Session current, CancellationToken ct)
    {
        using var content = new FormUrlEncodedContent(new Dictionary<string, string> { ["username"] = current.Connection.Username!, ["password"] = current.Connection.Secret });
        var response = await SendOnceAsync(current, "auth/login", HttpMethod.Post, content, 4096, ct, login: true);
        if (response.Status is not (200 or 204) || (response.Body.Length != 0 && !response.Body.AsSpan().SequenceEqual("Ok."u8)))
            throw new EngineFailure(response.Status is 401 or 403 ? "engine_credentials_rejected" : "engine_login_failed");
        var cookie = current.Cookies.GetCookies(current.Connection.Origin).Cast<Cookie>().Any(x => (x.Name == "SID" || x.Name == "QBT_SID" || x.Name.StartsWith("QBT_SID_", StringComparison.Ordinal)) && x.Value.Length > 0);
        if (!cookie) throw new EngineFailure("engine_login_failed");
        current.LoggedIn = true;
    }

    private async Task<(int Status, byte[] Body)> SendOnceAsync(Session current, string path, HttpMethod method, HttpContent? content, int max, CancellationToken ct, bool login)
    {
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct); deadline.CancelAfter(TimeSpan.FromSeconds(20));
        await Requests.WaitAsync(deadline.Token);
        try
        {
            using var handler = new SocketsHttpHandler { AllowAutoRedirect = false, UseCookies = true, CookieContainer = current.Cookies, UseProxy = false, ConnectTimeout = TimeSpan.FromSeconds(5), MaxResponseHeadersLength = 64, MaxConnectionsPerServer = 2, PooledConnectionLifetime = TimeSpan.Zero };
            var baseUri = current.Connection.Origin;
            handler.ConnectCallback = async (context, token) =>
            {
                var addresses = await dns.ResolveAsync(baseUri.DnsSafeHost, token);
                if (addresses.Length is < 1 or > 16 || addresses.Any(a => !NetworkAddressPolicy.ApprovedService(a))) throw new HttpRequestException("service_address_rejected");
                Exception? last = null;
                foreach (var ip in addresses.Distinct())
                {
                    var socket = new Socket(ip.AddressFamily, SocketType.Stream, ProtocolType.Tcp) { NoDelay = true };
                    try { await socket.ConnectAsync(new IPEndPoint(ip, context.DnsEndPoint.Port), token); return new NetworkStream(socket, ownsSocket: true); }
                    catch (Exception e) { socket.Dispose(); last = e; if (token.IsCancellationRequested) throw; }
                }
                throw new HttpRequestException("service_connection_failed", last);
            };
            using var client = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
            var uri = new Uri(baseUri, "api/v2/" + path);
            using var request = new HttpRequestMessage(method, uri) { Version = HttpVersion.Version11, VersionPolicy = HttpVersionPolicy.RequestVersionExact, Content = content };
            request.Headers.UserAgent.ParseAdd("Briani/1");
            request.Headers.Add("Origin", baseUri.GetLeftPart(UriPartial.Authority));
            request.Headers.Referrer = new Uri(baseUri, "./");
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, deadline.Token);
            if (response.Headers.Location is not null) throw new EngineFailure("engine_redirect_rejected");
            if (response.Content.Headers.ContentLength > max) throw new EngineFailure("engine_response_too_large");
            await using var stream = await response.Content.ReadAsStreamAsync(deadline.Token);
            using var output = new MemoryStream(); var buffer = new byte[65536]; int count;
            while ((count = await stream.ReadAsync(buffer, deadline.Token)) > 0)
            {
                if (output.Length + count > max) throw new EngineFailure("engine_response_too_large");
                output.Write(buffer, 0, count);
            }
            return ((int)response.StatusCode, output.ToArray());
        }
        finally { Requests.Release(); }
    }

    private static EngineFailure MapStatus(int status) => status switch { 401 or 403 => new("engine_credentials_rejected"), 404 => new("torrent_not_found"), 429 or >= 500 => new("engine_unavailable"), _ => new("engine_request_failed") };
    private static bool SafeOrigin(Uri u) => u.IsAbsoluteUri && u.Scheme is "http" or "https" && u.UserInfo == "" && u.Query == "" && u.Fragment == "" && u.AbsolutePath.EndsWith('/') && u.Port is > 0 and <= 65535;
    private static void ValidatePath(string p) { if (p.Length > 4096 || p.StartsWith('/') || p.Contains("..", StringComparison.Ordinal) || p.Contains('\\') || p.Any(char.IsControl)) throw new EngineFailure("invalid_api_path"); }
    private static string ValidHash(string h) { if (h.Length is not (40 or 64) || h.Any(c => !Uri.IsHexDigit(c))) throw new EngineFailure("invalid_torrent_hash"); return h.ToLowerInvariant(); }
    private static bool SafeSavePath(string p)
    {
        if (p.Length is 0 or > 4096 || p.Contains('\\') || p.Any(char.IsControl)) return false;
        var parts = p.Split('/');
        if (parts.Length < 6 || parts[0] != "" || parts[1] != "data" || parts[^3] != ".briani" || parts[^2] != "staging" ||
            !Guid.TryParseExact(parts[^1], "N", out _)) return false;
        var rootParts = parts.AsSpan(2, parts.Length - 5);
        if (rootParts.Length < 1) return false;
        foreach (var part in rootParts)
            if (part.Length is 0 or > 255 || part is "." or ".." or ".briani") return false;
        return true;
    }
    private static bool ValidOwnershipTag(string t) => t.StartsWith("briani-", StringComparison.Ordinal) && Guid.TryParseExact(t.AsSpan(7), "N", out _);
    private static string Number(long n) => n.ToString(CultureInfo.InvariantCulture);
    private static bool Compatible(string actual, Version required)
    {
        var value = actual.Trim().TrimStart('v', 'V').Split(' ', '-', '+')[0];
        if (!Version.TryParse(value, out var parsed)) return false;
        return parsed.Major == required.Major && parsed.Minor == required.Minor && parsed.Build == required.Build && (required.Revision < 0 || parsed.Revision == required.Revision);
    }
    private static string SafeStatus(string value) => value.Length <= 64 && value.All(c => char.IsLetterOrDigit(c) || c is ' ' or '-' or '_') ? value : "unknown";
    private static bool JsonEqual(JsonElement actual, object? expected) => expected switch { bool b => actual.ValueKind == JsonValueKind.True && b || actual.ValueKind == JsonValueKind.False && !b, int n => actual.TryGetInt32(out var i) && i == n, long n => actual.TryGetInt64(out var i) && i == n, _ => false };
    private static string Str(JsonElement e, string key) => e.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";
    private static long Long(JsonElement e, string key, long fallback) => e.TryGetProperty(key, out var v) && v.TryGetInt64(out var n) ? n : fallback;
    private static int Int(JsonElement e, string key, int fallback) => e.TryGetProperty(key, out var v) && v.TryGetInt32(out var n) ? n : fallback;
    private static int? NullableInt(JsonElement e, string key) => e.TryGetProperty(key, out var v) && v.TryGetInt32(out var n) && n >= 0 ? n : null;
    private static double Double(JsonElement e, string key) => e.TryGetProperty(key, out var v) && v.TryGetDouble(out var n) && double.IsFinite(n) ? Math.Clamp(n, 0, 1) : 0;
    private static bool Bool(JsonElement e, string key) => e.TryGetProperty(key, out var v) && v.ValueKind is JsonValueKind.True;
    private static EngineTorrent MapTorrent(JsonElement e)
    {
        var hash = Str(e, "hash"); if (hash.Length is not (40 or 64)) throw new EngineFailure("engine_response_invalid");
        var tags = Str(e, "tags").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Take(64).ToArray();
        var state = SafeStatus(Str(e, "state"));
        return new(hash.ToLowerInvariant(), EmptyNull(Str(e, "infohash_v1")), EmptyNull(Str(e, "infohash_v2")), Str(e, "name"), Str(e, "save_path"), state,
            Math.Max(0, Long(e, "total_size", Long(e, "size", 0))), Math.Max(0, Long(e, "downloaded", 0)), Math.Max(0, Long(e, "uploaded", 0)), Math.Max(0, Long(e, "dlspeed", 0)), Math.Max(0, Long(e, "upspeed", 0)),
            Double(e, "progress"), Double(e, "availability"), Bool(e, "seq_dl"), Bool(e, "f_l_piece_prio"), tags,
            Nonnegative(Long(e, "eta", -1)), NullableInt(e, "num_seeds"), NullableInt(e, "num_leechs"), Int(e, "priority", -1));
    }
    private static string? EmptyNull(string value) => value.Length == 0 ? null : value;
    private static long? Nonnegative(long value) => value < 0 ? null : value;
}
