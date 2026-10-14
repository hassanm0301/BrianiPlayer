using System.Collections;
using System.Net;
using System.Text.Json;

namespace Briani.PlaybackProof;

public sealed class QBitAvailability : BackgroundService
{
    private readonly HttpClient client;
    private readonly SharedAvailability source;
    private readonly ProofConfig config;
    private string? previousState;
    private long generation;
    public QBitAvailability(ProofConfig config, SharedAvailability source)
    {
        this.config = config; this.source = source; generation = config.Generation;
        var origin = new Uri(config.QBitUrl);
        if (!origin.IsLoopback && Environment.GetEnvironmentVariable("BRIANI_PROOF_PRIVATE_API") != "1")
            throw new ArgumentException("Proof adapter requires loopback or explicit isolated Compose API");
        client = new HttpClient(new HttpClientHandler { CookieContainer = new CookieContainer(), UseProxy = false })
        { BaseAddress = origin, Timeout = TimeSpan.FromSeconds(2) };
        client.DefaultRequestHeaders.Referrer = origin;
    }
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var password = Environment.GetEnvironmentVariable("BRIANI_PROOF_QBIT_PASSWORD")
            ?? throw new InvalidOperationException("Set BRIANI_PROOF_QBIT_PASSWORD");
        using var login = await client.PostAsync("api/v2/auth/login", new FormUrlEncodedContent(
            new Dictionary<string, string> { ["username"] = config.QBitUser, ["password"] = password }), stoppingToken);
        if (!login.IsSuccessStatusCode || login.StatusCode != HttpStatusCode.NoContent &&
            await login.Content.ReadAsStringAsync(stoppingToken) != "Ok.")
            throw new InvalidOperationException("qbit_auth_failed");
        var failed = false;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var response = await client.GetAsync("api/v2/torrents/info?hashes=" + config.Hash, stoppingToken);
                response.EnsureSuccessStatusCode();
                using var info = JsonDocument.Parse(await response.Content.ReadAsStringAsync(stoppingToken));
                if (info.RootElement.GetArrayLength() != 1) throw new IOException("torrent_missing");
                var state = info.RootElement[0].GetProperty("state").GetString() ?? "unknown";
                if (info.RootElement[0].GetProperty("save_path").GetString() != config.SavePath)
                    throw new IOException("storage_binding_changed");
                var maintenance = state.Contains("checking", StringComparison.OrdinalIgnoreCase) ||
                    state.Contains("moving", StringComparison.OrdinalIgnoreCase) || state is "error" or "missingFiles" or "unknown";
                if (failed || maintenance && previousState != state) generation++;
                previousState = state; failed = false;
                var pieces = await client.GetFromJsonAsync<int[]>("api/v2/torrents/pieceStates?hash=" + config.Hash, stoppingToken)
                    ?? throw new IOException("pieces_missing");
                if (pieces.Length != config.PieceCount) throw new IOException("layout_unverified");
                using var filesResponse = await client.GetAsync("api/v2/torrents/files?hash=" + config.Hash, stoppingToken);
                filesResponse.EnsureSuccessStatusCode();
                using var files = JsonDocument.Parse(await filesResponse.Content.ReadAsStringAsync(stoppingToken));
                foreach (var expected in config.Files)
                {
                    var match = files.RootElement.EnumerateArray().SingleOrDefault(f => f.GetProperty("index").GetInt32() == expected.UpstreamIndex);
                    if (match.ValueKind == JsonValueKind.Undefined || match.GetProperty("name").GetString() != expected.Path ||
                        match.GetProperty("size").GetInt64() != expected.Length || match.GetProperty("priority").GetInt32() != expected.Priority)
                        throw new IOException("selection_changed");
                }
                generation = Math.Max(generation, source.Current?.Generation ?? config.Generation);
                source.Publish(new(generation, DateTimeOffset.UtcNow, !maintenance, new BitArray(pieces.Select(p => p == 2).ToArray())));
            }
            catch (Exception e) when (e is HttpRequestException or IOException or JsonException or TaskCanceledException)
            {
                if (!failed) generation++;
                failed = true;
                source.Publish(new(generation, DateTimeOffset.UtcNow, false, new BitArray(config.PieceCount)));
            }
            await Task.Delay(TimeSpan.FromMilliseconds(500), stoppingToken);
        }
    }
    public override void Dispose() { client.Dispose(); base.Dispose(); }
}

public sealed record ProofConfig(string Root, string QBitUrl, string QBitUser, string Hash,
    long Generation, int PieceLength, int PieceCount, FileLayout[] Files, string TargetId, string Token,
    FileIdentity? Identity, string SavePath)
{
    public static ProofConfig Load(string path)
    {
        var config = JsonSerializer.Deserialize<ProofConfig>(File.ReadAllText(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new ArgumentException("config_invalid");
        if (config.Hash.Length is not (40 or 64) || config.Hash.Any(c => !Uri.IsHexDigit(c)) || config.Token.Length < 32)
            throw new ArgumentException("config_invalid");
        return config;
    }
}
