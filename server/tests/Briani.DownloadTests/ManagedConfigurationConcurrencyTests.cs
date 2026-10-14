using System.Collections.Concurrent;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Preferences;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class ManagedConfigurationConcurrencyTests
{
    [Fact]
    public async Task Concurrent_adapter_instances_apply_complete_latest_configuration_in_order()
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        var ct = timeout.Token;
        await using var host = new TestHost();
        using var app = host.CreateClient();
        await using var upstream = new ConfigurationServer();
        var gate = host.Services.GetRequiredService<WriteGate>();
        var secrets = host.Services.GetRequiredService<SecretStore>();
        var firstSettings = Settings(1, 1, 1, 40, 20, 32003, 64007);
        var latestSettings = Settings(2, 3, 2, 80, 30, 80009, 120011);
        using (await gate.EnterAsync(ct))
        {
            await host.InDb(async db =>
            {
                db.Settings.Add(new Setting { Key = "integration.qbittorrent", ValueJson = JsonSerializer.Serialize(
                    new ProtectedConnection(upstream.Origin.AbsoluteUri, "fixture-user", secrets.Encrypt("fixture-password"), 7)),
                    UpdatedAt = host.Clock.GetUtcNow() });
                db.Settings.Add(new Setting { Key = AdministratorConfiguration.Key, Version = 1,
                    ValueJson = firstSettings.ToJsonString(), UpdatedAt = host.Clock.GetUtcNow() });
                await db.SaveChangesAsync(ct); return true;
            });
        }
        var connections = host.Services.GetRequiredService<ServiceConnections>();
        var first = new QBitTorrentClient(connections, new SystemSafeDns());
        var second = new QBitTorrentClient(connections, new SystemSafeDns());
        // Authenticate the competing instance before the barrier. Its separate
        // session semaphore must not accidentally serialize it behind instance one.
        await second.VersionAsync(ct);
        var oldApply = first.ConfigureManagedAsync(ct);
        await upstream.FirstApplyEntered.Task.WaitAsync(ct);
        try
        {
            using (await gate.EnterAsync(ct))
            {
                await host.InDb(async db =>
                {
                    var row = await db.Settings.FindAsync([AdministratorConfiguration.Key], ct);
                    Assert.NotNull(row);
                    row.Version = 2; row.ValueJson = latestSettings.ToJsonString(); row.UpdatedAt = host.Clock.GetUtcNow();
                    await db.SaveChangesAsync(ct); return true;
                });
            }
            var readsAtBarrier = upstream.PreferenceReads;
            var latestApply = second.ConfigureManagedAsync(ct);
            // An actual network barrier holds V1's POST. Without whole-apply
            // serialization, instance two reads/posts V2 here and V1 later wins.
            var observed = await Task.WhenAny(upstream.SecondPreferenceRead.Task, Task.Delay(500, ct));
            Assert.NotSame(upstream.SecondPreferenceRead.Task, observed);
            Assert.Equal(readsAtBarrier, upstream.PreferenceReads);
            Assert.Equal(1, upstream.ApplyCount);
            Assert.False(latestApply.IsCompleted);
            upstream.ReleaseFirstApply.TrySetResult();
            await Task.WhenAll(oldApply, latestApply).WaitAsync(ct);

            Assert.Equal(2, upstream.ApplyCount);
            var captured = upstream.AppliedConfigurations.ToArray();
            Assert.Equal(new[] { 40, 80 }, captured.Select(x => x["max_connec"].GetInt32()));
            var final = upstream.CurrentPreferences;
            Assert.Equal(80, final["max_connec"].GetInt32());
            Assert.Equal(30, final["max_connec_per_torrent"].GetInt32());
            Assert.Equal(3, final["max_active_downloads"].GetInt32());
            Assert.Equal(2, final["max_active_uploads"].GetInt32());
            Assert.Equal(5, final["max_active_torrents"].GetInt32());
            Assert.True(final["queueing_enabled"].GetBoolean());
            Assert.False(final["upnp"].GetBoolean());
            Assert.False(final["web_ui_upnp"].GetBoolean());
            Assert.True(final["web_ui_csrf_protection_enabled"].GetBoolean());
            Assert.True(final["web_ui_host_header_validation_enabled"].GetBoolean());
            Assert.True(final["web_ui_clickjacking_protection_enabled"].GetBoolean());
            Assert.Equal(80009 / 1024 * 1024, upstream.UploadLimit);
            Assert.Equal(120011 / 1024 * 1024, upstream.DownloadLimit);
            Assert.Equal(new long[] { 32003, 80009 }, upstream.RequestedUploadLimits.ToArray());
            Assert.Equal(new long[] { 64007, 120011 }, upstream.RequestedDownloadLimits.ToArray());
        }
        finally { upstream.ReleaseFirstApply.TrySetResult(); }
    }

    private static JsonObject Settings(long version, int downloads, int seeds, int connections,
        int perTorrent, long upload, long download)
    {
        var value = AdministratorConfiguration.DefaultValues();
        value["version"] = version; value["activeDownloads"] = downloads; value["activeSeeds"] = seeds;
        value["globalConnections"] = connections; value["connectionsPerTorrent"] = perTorrent;
        value["uploadLimitBytesPerSecond"] = upload; value["downloadLimitBytesPerSecond"] = download;
        return value;
    }

    private sealed class ConfigurationServer : IAsyncDisposable
    {
        private readonly HttpListener listener = new();
        private readonly CancellationTokenSource stop = new(TimeSpan.FromSeconds(15));
        private readonly ConcurrentBag<Task> handlers = [];
        private readonly object sync = new();
        private Dictionary<string, JsonElement> preferences = [];
        private readonly Task accept;
        private int preferenceReads, applies;
        private long uploadLimit, downloadLimit;
        public Uri Origin { get; }
        public TaskCompletionSource FirstApplyEntered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource ReleaseFirstApply { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource SecondPreferenceRead { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public ConcurrentQueue<Dictionary<string, JsonElement>> AppliedConfigurations { get; } = new();
        public ConcurrentQueue<long> RequestedUploadLimits { get; } = new();
        public ConcurrentQueue<long> RequestedDownloadLimits { get; } = new();
        public int PreferenceReads => Volatile.Read(ref preferenceReads);
        public int ApplyCount => Volatile.Read(ref applies);
        public long UploadLimit => Interlocked.Read(ref uploadLimit);
        public long DownloadLimit => Interlocked.Read(ref downloadLimit);
        public Dictionary<string, JsonElement> CurrentPreferences { get { lock (sync) return new(preferences); } }

        public ConfigurationServer()
        {
            using var reserve = new TcpListener(IPAddress.Loopback, 0);
            reserve.Start(); var port = ((IPEndPoint)reserve.LocalEndpoint).Port; reserve.Stop();
            Origin = new Uri($"http://127.0.0.1:{port}/"); listener.Prefixes.Add(Origin.AbsoluteUri); listener.Start();
            accept = AcceptAsync();
        }
        private async Task AcceptAsync()
        {
            try
            {
                while (!stop.IsCancellationRequested)
                {
                    var context = await listener.GetContextAsync().WaitAsync(stop.Token);
                    handlers.Add(HandleAsync(context));
                }
            }
            catch (OperationCanceledException) when (stop.IsCancellationRequested) { }
            catch (HttpListenerException) when (stop.IsCancellationRequested) { }
            catch (ObjectDisposedException) when (stop.IsCancellationRequested) { }
        }
        private async Task HandleAsync(HttpListenerContext context)
        {
            try
            {
                var path = context.Request.Url!.AbsolutePath;
                if (path == "/api/v2/auth/login")
                {
                    context.Response.Headers.Add("Set-Cookie", "QBT_SID_8080=owned-fixture; Path=/; HttpOnly");
                    await Reply(context, "Ok."); return;
                }
                if (context.Request.Headers["Cookie"]?.Contains("QBT_SID_8080=owned-fixture", StringComparison.Ordinal) != true)
                { context.Response.StatusCode = 403; await Reply(context, "Forbidden"); return; }
                switch (path)
                {
                    case "/api/v2/app/version": await Reply(context, "v5.2.4"); break;
                    case "/api/v2/app/webapiVersion": await Reply(context, "2.15.1"); break;
                    case "/api/v2/app/buildInfo": await Reply(context, "{\"libtorrent\":\"2.0.15.0\"}"); break;
                    case "/api/v2/app/preferences":
                        if (Interlocked.Increment(ref preferenceReads) > 1) SecondPreferenceRead.TrySetResult();
                        await Reply(context, JsonSerializer.Serialize(CurrentPreferences)); break;
                    case "/api/v2/app/setPreferences":
                        var values = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>((await Form(context))["json"])!;
                        AppliedConfigurations.Enqueue(values);
                        if (Interlocked.Increment(ref applies) == 1)
                        { FirstApplyEntered.TrySetResult(); await ReleaseFirstApply.Task.WaitAsync(stop.Token); }
                        lock (sync) preferences = values;
                        await Reply(context, "Ok."); break;
                    case "/api/v2/transfer/setUploadLimit":
                        var upload = long.Parse((await Form(context))["limit"], CultureInfo.InvariantCulture);
                        RequestedUploadLimits.Enqueue(upload); Interlocked.Exchange(ref uploadLimit, upload / 1024 * 1024);
                        await Reply(context, "Ok."); break;
                    case "/api/v2/transfer/setDownloadLimit":
                        var download = long.Parse((await Form(context))["limit"], CultureInfo.InvariantCulture);
                        RequestedDownloadLimits.Enqueue(download); Interlocked.Exchange(ref downloadLimit, download / 1024 * 1024);
                        await Reply(context, "Ok."); break;
                    case "/api/v2/transfer/uploadLimit": await Reply(context, UploadLimit.ToString(CultureInfo.InvariantCulture)); break;
                    case "/api/v2/transfer/downloadLimit": await Reply(context, DownloadLimit.ToString(CultureInfo.InvariantCulture)); break;
                    default: throw new InvalidOperationException("Unexpected owned fixture API route.");
                }
            }
            catch (Exception) when (stop.IsCancellationRequested) { context.Response.Abort(); }
        }
        private static async Task<Dictionary<string, string>> Form(HttpListenerContext context)
        {
            using var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8);
            return (await reader.ReadToEndAsync()).Split('&').Select(x => x.Split('=', 2))
                .ToDictionary(x => Uri.UnescapeDataString(x[0].Replace('+', ' ')), x => Uri.UnescapeDataString(x[1].Replace('+', ' ')));
        }
        private static async Task Reply(HttpListenerContext context, string value)
        {
            var bytes = Encoding.UTF8.GetBytes(value); context.Response.ContentLength64 = bytes.Length;
            await context.Response.OutputStream.WriteAsync(bytes); context.Response.Close();
        }
        public async ValueTask DisposeAsync()
        {
            ReleaseFirstApply.TrySetResult(); stop.Cancel(); listener.Close();
            await accept; await Task.WhenAll(handlers).WaitAsync(TimeSpan.FromSeconds(2)); stop.Dispose();
        }
    }
}
