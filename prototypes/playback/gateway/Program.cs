using System.Buffers;
using Briani.PlaybackProof;

var configPath = Environment.GetEnvironmentVariable("BRIANI_PROOF_CONFIG")
    ?? throw new InvalidOperationException("Set BRIANI_PROOF_CONFIG to a validated fixture config");
var config = ProofConfig.Load(configPath);
var layout = new TorrentLayout(config.Generation, config.PieceLength, config.PieceCount, config.Files);
var file = layout.Files.Single(f => f.Id == config.TargetId && !f.Padding);
var ticketWindow = new TicketWindow(config.Token, file.Id, layout.Generation, TimeProvider.System);
var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders(); // The proof ticket must never enter request-path logs.
builder.WebHost.ConfigureKestrel(options => { options.Limits.MinResponseDataRate = null; });
builder.Services.AddSingleton(config);
builder.Services.AddSingleton<SharedAvailability>();
builder.Services.AddSingleton<ProofReaders>();
builder.Services.AddHostedService<QBitAvailability>();
var app = builder.Build();
app.MapGet("/healthz", () => Results.Ok(new { status = "alive", prototype = true }));
app.MapGet("/proof/state", (SharedAvailability source, ProofReaders readers) => Results.Ok(new {
    generation = source.Current?.Generation, healthy = source.Current?.Healthy,
    ageMs = source.Current is null ? (double?)null : (DateTimeOffset.UtcNow - source.Current.ObservedAt).TotalMilliseconds,
    activeReaders = readers.Active
}));
app.MapPost("/proof/fence", (HttpContext http, SharedAvailability source) =>
    http.Request.Headers["X-Proof-Key"] == config.Token ? Results.Ok(new { generation = source.Invalidate() }) : Results.NotFound());
app.MapMethods("/stream/{ticket}/{name}", ["GET", "HEAD"], async (HttpContext http, SharedAvailability source, ProofReaders readers,
    string ticket, string name) =>
{
    if (!ticketWindow.Authorize(ticket, file.Id, layout.Generation) ||
        name != Path.GetFileName(file.Path)) { http.Response.StatusCode = 404; return; }
    http.Response.Headers.AcceptRanges = "bytes";
    http.Response.Headers.CacheControl = "private, no-store";
    http.Response.ContentType = file.Path.EndsWith(".mkv", StringComparison.OrdinalIgnoreCase) ? "video/x-matroska" : "video/mp4";
    if (HttpMethods.IsHead(http.Request.Method))
    { http.Response.ContentLength = file.Length; http.Response.StatusCode = 200; return; }
    ByteRange range;
    try { range = ByteRange.Parse(http.Request.Headers.Range.ToString(), file.Length); }
    catch (RangeException error)
    {
        http.Response.StatusCode = error.Unsatisfiable ? 416 : 400;
        if (error.Unsatisfiable) http.Response.Headers.ContentRange = $"bytes */{file.Length}";
        http.Response.ContentType = "application/problem+json";
        await http.Response.WriteAsJsonAsync(new { code = "range_invalid", status = http.Response.StatusCode }, http.RequestAborted);
        return;
    }
    if (range.Length == 0) { http.Response.ContentLength = 0; return; }
    if (!readers.TryEnter()) { http.Response.StatusCode = 503; return; }
    var buffer = ArrayPool<byte>.Shared.Rent(256 * 1024);
    try
    {
        if (config.Identity is null) throw new IOException("file_identity_unavailable");
        await using var stream = ContainedFile.Open(config.Root, file.Path, file.Length, config.Identity);
        var reader = new ProgressiveReader(layout, file, source, TimeProvider.System);
        var offset = range.Start;
        var count = await reader.ReadAsync(stream, offset, buffer.AsMemory(0, (int)Math.Min(buffer.Length, range.Length)),
            TimeSpan.FromSeconds(60), http.RequestAborted);
        http.Response.StatusCode = range.Partial ? 206 : 200;
        http.Response.ContentLength = range.Length;
        if (range.Partial) http.Response.Headers.ContentRange = $"bytes {range.Start}-{range.End}/{file.Length}";
        while (true)
        {
            await http.Response.Body.WriteAsync(buffer.AsMemory(0, count), http.RequestAborted);
            await http.Response.Body.FlushAsync(http.RequestAborted);
            offset += count;
            if (offset > range.End) break;
            count = await reader.ReadAsync(stream, offset, buffer.AsMemory(0, (int)Math.Min(buffer.Length, range.End - offset + 1)),
                TimeSpan.FromSeconds(120), http.RequestAborted);
        }
    }
    catch (Exception e) when (e is IOException or OperationCanceledException)
    {
        if (http.Response.HasStarted) http.Abort();
        else if (!http.RequestAborted.IsCancellationRequested)
        {
            http.Response.StatusCode = 503;
            http.Response.Headers.RetryAfter = "2";
            http.Response.ContentLength = null;
            http.Response.ContentType = "application/problem+json";
            await http.Response.WriteAsJsonAsync(new { code = e is DataWaitException ? "waiting_for_data" : "unavailable", status = 503 }, http.RequestAborted);
        }
    }
    finally { ArrayPool<byte>.Shared.Return(buffer); readers.Exit(); }
});
await app.RunAsync("http://127.0.0.1:18088");

public sealed class ProofReaders
{
    private readonly SemaphoreSlim slots = new(4);
    private int active;
    public int Active => Volatile.Read(ref active);
    public bool TryEnter() { if (!slots.Wait(0)) return false; Interlocked.Increment(ref active); return true; }
    public void Exit() { Interlocked.Decrement(ref active); slots.Release(); }
}
