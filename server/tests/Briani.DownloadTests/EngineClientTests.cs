using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class EngineClientTests
{
    [Fact]
    public async Task MetadataOnlyAddUsesPinnedStopConditionAndManagedFields()
    {
        await using var host = new TestHost();
        using var app = host.CreateClient();
        var port = FreePort();
        var origin = new Uri($"http://127.0.0.1:{port}/");
        const string username = "engine-test";
        var password = "fixture-" + Credentials.NewToken();
        var secretStore = host.Services.GetRequiredService<SecretStore>();
        await host.InDb(async db =>
        {
            db.Settings.Add(new Setting
            {
                Key = "integration.qbittorrent",
                ValueJson = JsonSerializer.Serialize(new ProtectedConnection(origin.AbsoluteUri, username, secretStore.Encrypt(password), 7)),
                UpdatedAt = host.Clock.GetUtcNow()
            });
            await db.SaveChangesAsync();
            return true;
        });

        using var listener = new HttpListener();
        listener.Prefixes.Add(origin.AbsoluteUri);
        listener.Start();
        var library = Guid.NewGuid();
        var job = Guid.NewGuid();
        var magnet = "magnet:?xt=urn:btih:" + new string('a', 40) + "&dn=" + new string('x', 65536 - 20 - 40 - 4);
        var server = Task.Run(async () =>
        {
            var requests = new List<(string Path, string Cookie, string Origin, string Referer, string Body)>();
            for (var i = 0; i < 3; i++)
            {
                var context = await listener.GetContextAsync();
                using var reader = new StreamReader(context.Request.InputStream, context.Request.ContentEncoding);
                var body = await reader.ReadToEndAsync();
                requests.Add((context.Request.Url!.AbsolutePath, context.Request.Headers["Cookie"] ?? "", context.Request.Headers["Origin"] ?? "", context.Request.Headers["Referer"] ?? "", body));
                if (context.Request.Url.AbsolutePath.EndsWith("/auth/login", StringComparison.Ordinal))
                {
                    Assert.Contains("username=engine-test", body);
                    Assert.Contains("password=" + password, body);
                    context.Response.Headers.Add("Set-Cookie", "QBT_SID=fixture-session; Path=/; HttpOnly");
                    await Reply(context, 200, "Ok.");
                }
                else if (context.Request.Headers["Cookie"]?.Contains("QBT_SID=fixture-session", StringComparison.Ordinal) == true)
                {
                    await Reply(context, 200, "Ok.");
                }
                else await Reply(context, 403, "Forbidden");
            }
            return requests;
        });

        var engine = new QBitTorrentClient(host.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        var savePath = $"/data/{library:D}/.briani/staging/{job:N}";
        await engine.AddAsync(new EngineAdd(null, magnet, savePath, $"briani-{job:N}", MetadataOnly: true));
        var captured = await server.WaitAsync(TimeSpan.FromSeconds(10));

        Assert.Equal(3, captured.Count);
        Assert.EndsWith("/torrents/add", captured[0].Path);
        Assert.Contains("/auth/login", captured[1].Path);
        Assert.EndsWith("/torrents/add", captured[2].Path);
        Assert.Contains("QBT_SID=fixture-session", captured[2].Cookie);
        Assert.All(captured, request => Assert.Equal(origin.GetLeftPart(UriPartial.Authority), request.Origin));
        Assert.All(captured, request => Assert.Equal(origin.AbsoluteUri, request.Referer));
        Assert.Contains("stopCondition", captured[2].Body);
        Assert.Contains("MetadataReceived", captured[2].Body);
        Assert.Contains("stopped", captured[2].Body);
        Assert.Contains("false", captured[2].Body);
        Assert.Contains("autoTMM", captured[2].Body);
        Assert.Contains("briani-" + job.ToString("N"), captured[2].Body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("category", captured[2].Body);
        Assert.Contains("savepath", captured[2].Body);
    }

    [Fact]
    public async Task ReadMappingsAreBoundedAndNeverReturnTrackerUrls()
    {
        await using var host = new TestHost();
        using var app = host.CreateClient();
        var port = FreePort();
        var origin = new Uri($"http://127.0.0.1:{port}/");
        await Configure(host, origin, "engine-test", "fixture-" + Credentials.NewToken(), 8);
        using var listener = new HttpListener(); listener.Prefixes.Add(origin.AbsoluteUri); listener.Start();
        const string hash = "0123456789abcdef0123456789abcdef01234567";
        byte[] export = [0x64, 0x34, 0x3a, 0x69, 0x6e, 0x66, 0x6f, 0x65];
        var server = Task.Run(async () =>
        {
            var count = 0;
            while (count < 10)
            {
                var context = await listener.GetContextAsync(); count++;
                var path = context.Request.Url!.AbsolutePath;
                if (path.EndsWith("/auth/login", StringComparison.Ordinal))
                {
                    context.Response.Headers.Add("Set-Cookie", "QBT_SID=read-session; Path=/; HttpOnly");
                    await Reply(context, 200, "Ok."); continue;
                }
                if (context.Request.Headers["Cookie"]?.Contains("QBT_SID=read-session", StringComparison.Ordinal) != true)
                {
                    await Reply(context, 403, "Forbidden"); continue;
                }
                if (path.EndsWith("/app/version", StringComparison.Ordinal)) await Reply(context, 200, "\"v5.2.4\"");
                else if (path.EndsWith("/app/webapiVersion", StringComparison.Ordinal)) await Reply(context, 200, "\"2.15.1\"");
                else if (path.EndsWith("/app/buildInfo", StringComparison.Ordinal)) await Reply(context, 200, "{\"libtorrent\":\"2.0.15.0\"}", "application/json");
                else if (path.EndsWith("/torrents/info", StringComparison.Ordinal)) await Reply(context, 200, "[{\"hash\":\"" + hash + "\",\"infohash_v1\":\"" + hash + "\",\"infohash_v2\":\"\",\"name\":\"synthetic.bin\",\"save_path\":\"/data/test/.briani/staging/job\",\"state\":\"stoppedUP\",\"size\":17,\"downloaded\":4,\"uploaded\":2,\"dlspeed\":3,\"upspeed\":1,\"progress\":0.25,\"availability\":1.5,\"seq_dl\":true,\"f_l_piece_prio\":true,\"tags\":\"briani:fixture\",\"eta\":-1,\"num_seeds\":0,\"num_leechs\":2,\"priority\":4}]");
                else if (path.EndsWith("/torrents/files", StringComparison.Ordinal)) await Reply(context, 200, "[{\"index\":0,\"name\":\"synthetic.bin\",\"size\":17,\"progress\":0.25,\"priority\":1,\"piece_range\":[0,2]}]");
                else if (path.EndsWith("/torrents/export", StringComparison.Ordinal)) await Reply(context, 200, export, "application/x-bittorrent");
                else if (path.EndsWith("/torrents/pieceStates", StringComparison.Ordinal)) await Reply(context, 200, "[0,1,2]");
                else if (path.EndsWith("/torrents/trackers", StringComparison.Ordinal)) await Reply(context, 200, "[{\"url\":\"https://tracker.example/announce/secret-passkey\",\"status\":\"Working\",\"num_seeds\":4,\"num_peers\":9}]");
                else await Reply(context, 404, "Not found");
            }
        });

        var engine = new QBitTorrentClient(host.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        var version = await engine.VersionAsync();
        Assert.Equal(new EngineVersion("v5.2.4", "2.15.1", "2.0.15.0"), version);
        var torrents = await engine.TorrentsAsync();
        Assert.Single(torrents);
        Assert.Equal(17, torrents[0].TotalBytes);
        Assert.Equal(4, torrents[0].QueuePosition);
        Assert.Equal(0, torrents[0].SeedersConnected);
        Assert.Equal("stoppedUP", torrents[0].State);
        var files = await engine.FilesAsync(hash);
        Assert.Equal(new EngineFile(0, "synthetic.bin", 17, 0.25, 1, 0, 2), Assert.Single(files));
        Assert.Equal(export, await engine.ExportAsync(hash));
        Assert.Equal(new byte[] { 0, 1, 2 }, await engine.PiecesAsync(hash));
        var tracker = Assert.Single(await engine.TrackersAsync(hash));
        Assert.Equal("tracker.example", tracker.Host);
        Assert.DoesNotContain("passkey", tracker.Host, StringComparison.OrdinalIgnoreCase);
        await server.WaitAsync(TimeSpan.FromSeconds(10));
    }

    [Theory]
    [InlineData("/data/not-a-library/.briani/staging/1234", "invalid_add_request")]
    [InlineData("/data/00000000-0000-0000-0000-000000000000/.briani/staging/00000000-0000-0000-0000-000000000000", "invalid_add_request")]
    public async Task AddRejectsUnsafePathsAndOwnershipTags(string savePath, string expectedCode)
    {
        await using var host = new TestHost();
        using var app = host.CreateClient();
        var engine = new QBitTorrentClient(host.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        var error = await Assert.ThrowsAsync<EngineFailure>(() => engine.AddAsync(new EngineAdd([1], null, savePath, "briani:bad", false)));
        Assert.Equal(expectedCode, error.Code);
    }

    [Fact]
    public async Task ApplyLimitsRejectsInvalidTagsBeforeAnyUpstreamMutation()
    {
        await using var host = new TestHost();
        using var app = host.CreateClient();
        var engine = new QBitTorrentClient(host.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        var hash = "0123456789abcdef0123456789abcdef01234567";
        var cases = new[]
        {
            new EngineLimits(DownloadLimitBytesPerSecond: 1024, Tags: Enumerable.Range(0, 52).Select(i => "tag" + i).ToArray()),
            new EngineLimits(UploadLimitBytesPerSecond: 1024, Tags: ["tag,smuggled"]),
            new EngineLimits(RatioLimit: double.NaN, Tags: ["safe"])
        };

        foreach (var limits in cases)
        {
            var error = await Assert.ThrowsAsync<EngineFailure>(() => engine.ApplyLimitsAsync(hash, limits));
            Assert.Equal("invalid_limits", error.Code);
        }
    }

    [Fact]
    public async Task ApplyLimitsAcceptsFiftyUserTagsAndTheReservedOwnershipTag()
    {
        await using var host = new TestHost();
        using var app = host.CreateClient();
        var origin = new Uri($"http://127.0.0.1:{FreePort()}/");
        await Configure(host, origin, "engine-test", "fixture-" + Credentials.NewToken(), 23);
        using var listener = new HttpListener();
        listener.Prefixes.Add(origin.AbsoluteUri);
        listener.Start();
        var hash = "0123456789abcdef0123456789abcdef01234567";
        var tags = Enumerable.Range(0, 50).Select(i => "user-tag-" + i).Append("briani-" + Guid.NewGuid().ToString("N")).ToArray();
        var server = Task.Run(async () =>
        {
            var seen = new List<(string Path, string Body)>();
            for (var i = 0; i < 3; i++)
            {
                var context = await listener.GetContextAsync();
                using var reader = new StreamReader(context.Request.InputStream, context.Request.ContentEncoding);
                seen.Add((context.Request.Url!.AbsolutePath, await reader.ReadToEndAsync()));
                if (context.Request.Url.AbsolutePath.EndsWith("/auth/login", StringComparison.Ordinal))
                {
                    context.Response.Headers.Add("Set-Cookie", "QBT_SID=tag-session; Path=/; HttpOnly");
                    await Reply(context, 204, "");
                }
                else if (context.Request.Headers["Cookie"]?.Contains("QBT_SID=tag-session", StringComparison.Ordinal) == true)
                    await Reply(context, 200, "Ok.");
                else await Reply(context, 403, "Forbidden");
            }
            return seen;
        });

        var engine = new QBitTorrentClient(host.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        await engine.ApplyLimitsAsync(hash, new EngineLimits(Tags: tags));
        var requests = await server.WaitAsync(TimeSpan.FromSeconds(10));
        var mutation = requests.Last(x => x.Path.EndsWith("/torrents/addTags", StringComparison.Ordinal));
        Assert.Equal(51, Uri.UnescapeDataString(mutation.Body).Split("tags=", StringSplitOptions.None)[1].Split(',').Length);
    }

    [Fact]
    [Trait("Category", "EngineIntegration")]
    public async Task PinnedEngineLiveSmokeWhenConfigured()
    {
        var baseUrl = Environment.GetEnvironmentVariable("BRIANI_M05_QBIT_URL");
        var username = Environment.GetEnvironmentVariable("BRIANI_M05_QBIT_USERNAME");
        var password = Environment.GetEnvironmentVariable("BRIANI_M05_QBIT_PASSWORD");
        var torrentPath = Environment.GetEnvironmentVariable("BRIANI_M05_TORRENT");
        var libraryValue = Environment.GetEnvironmentVariable("BRIANI_M05_LIBRARY_ID");
        var dataRoot = Environment.GetEnvironmentVariable("BRIANI_M05_DATA_ROOT");
        if (string.IsNullOrWhiteSpace(baseUrl) || string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password) || string.IsNullOrWhiteSpace(torrentPath) || !Guid.TryParse(libraryValue, out var library) || string.IsNullOrWhiteSpace(dataRoot))
            throw Xunit.Sdk.SkipException.ForSkip("Set the BRIANI_M05_QBIT_* and generated-fixture variables through the isolated engine harness.");
        var job = Guid.NewGuid();
        await using var host = new TestHost();
        using var app = host.CreateClient();
        var origin = ServiceConnections.ValidateOrigin(baseUrl);
        await Configure(host, origin, username, password, 9);
        var engine = new QBitTorrentClient(host.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        Assert.Equal(new EngineVersion("v5.2.4", "2.15.1", "2.0.15.0"), await engine.VersionAsync());
        try { await engine.ConfigureManagedAsync(); }
        catch (EngineFailure error) when (error.Code == "engine_configuration_unverified")
        {
            Assert.Fail("Pinned qBittorrent preference verification failed for: " + error.Data["preferenceKeys"] + " (" + error.Data["safeValues"] + ")");
        }
        var bytes = await File.ReadAllBytesAsync(torrentPath);
        var tag = $"briani-{job:N}";
        await engine.AddAsync(new EngineAdd(bytes, null, $"{dataRoot.TrimEnd('/')}/{library:D}/.briani/staging/{job:N}", tag, false));
        var added = await WaitForTorrent(engine, t => t.Tags.Contains(tag, StringComparer.Ordinal) && t.State.StartsWith("stopped", StringComparison.OrdinalIgnoreCase), TimeSpan.FromSeconds(10));
        Assert.Contains("stopped", added.State, StringComparison.OrdinalIgnoreCase);
        Assert.True(added.Sequential);
        Assert.True(added.MetadataAssist);
        Assert.NotEmpty(await engine.FilesAsync(added.Hash));
        Assert.NotEmpty(await engine.ExportAsync(added.Hash));
        await engine.EnsureSequentialAsync(added.Hash, true);
        await engine.EnsureMetadataAssistAsync(added.Hash, true);
        await engine.SetFilePriorityAsync(added.Hash, [0], 1);
        try { await engine.ApplyLimitsAsync(added.Hash, new EngineLimits(UploadLimitBytesPerSecond: 4096, RatioLimit: 1.5, SeedTimeMinutes: 90)); }
        catch (EngineFailure error) { Assert.Fail("ApplyLimits failed: " + error.Code + " " + error.Data["apiPath"] + " HTTP " + error.Data["status"]); }
        await engine.StartAsync(added.Hash);
        await engine.StopAsync(added.Hash);
        var stopped = await WaitForTorrent(engine, t => t.Hash == added.Hash && t.State.StartsWith("stopped", StringComparison.OrdinalIgnoreCase), TimeSpan.FromSeconds(10));
        Assert.Equal(added.Hash, stopped.Hash);
        await engine.RemoveAsync(added.Hash, false);
        Assert.Empty(await engine.TorrentsAsync(added.Hash));

        var metadataJob = Guid.NewGuid();
        var magnet = "magnet:?xt=urn:btih:" + new string('b', 40) + "&dn=synthetic-metadata-only";
        await engine.AddAsync(new EngineAdd(null, magnet, $"{dataRoot.TrimEnd('/')}/{library:D}/.briani/staging/{metadataJob:N}", $"briani-{metadataJob:N}", true));
        var metadata = await WaitForTorrent(engine, t => t.Tags.Contains($"briani-{metadataJob:N}", StringComparer.Ordinal), TimeSpan.FromSeconds(10));
        Assert.Equal(0, metadata.DownloadedBytes);
        await engine.RemoveAsync(metadata.Hash, false);
    }

    [Fact]
    [Trait("Category", "EngineIntegration")]
    public async Task LocalSeedMetadataMagnetsMapV1V2HybridAndZeroLengthWithoutPayload()
    {
        var seedUrl = Environment.GetEnvironmentVariable("BRIANI_M05_SEED_URL");
        var seedUser = Environment.GetEnvironmentVariable("BRIANI_M05_SEED_USERNAME");
        var seedPassword = Environment.GetEnvironmentVariable("BRIANI_M05_SEED_PASSWORD");
        var downloadUrl = Environment.GetEnvironmentVariable("BRIANI_M05_DOWNLOAD_URL");
        var downloadUser = Environment.GetEnvironmentVariable("BRIANI_M05_DOWNLOAD_USERNAME");
        var downloadPassword = Environment.GetEnvironmentVariable("BRIANI_M05_DOWNLOAD_PASSWORD");
        var seedPeer = Environment.GetEnvironmentVariable("BRIANI_M05_SEED_PEER");
        var seedLibraryValue = Environment.GetEnvironmentVariable("BRIANI_M05_SEED_LIBRARY");
        var seedJobValue = Environment.GetEnvironmentVariable("BRIANI_M05_SEED_JOB");
        var fixtureRoot = Environment.GetEnvironmentVariable("BRIANI_M05_FIXTURE_ROOT");
        var privateFixtureRoot = Environment.GetEnvironmentVariable("BRIANI_M05_PRIVATE_FIXTURE_ROOT");
        var nonprivateRoot = Environment.GetEnvironmentVariable("BRIANI_M05_NONPRIVATE_FIXTURE_ROOT");
        var zeroTorrentPath = Environment.GetEnvironmentVariable("BRIANI_M05_ZERO_TORRENT");
        if (string.IsNullOrWhiteSpace(seedUrl) || string.IsNullOrWhiteSpace(seedUser) || string.IsNullOrWhiteSpace(seedPassword) ||
            string.IsNullOrWhiteSpace(downloadUrl) || string.IsNullOrWhiteSpace(downloadUser) || string.IsNullOrWhiteSpace(downloadPassword) ||
            string.IsNullOrWhiteSpace(seedPeer) || !Guid.TryParse(seedLibraryValue, out var seedLibrary) || !Guid.TryParse(seedJobValue, out var seedJob) ||
            string.IsNullOrWhiteSpace(fixtureRoot) || string.IsNullOrWhiteSpace(privateFixtureRoot) || string.IsNullOrWhiteSpace(nonprivateRoot) || string.IsNullOrWhiteSpace(zeroTorrentPath))
            throw Xunit.Sdk.SkipException.ForSkip("Set the local seeder and downloader variables through the isolated M05 transfer harness.");

        AssertPrivateBridgeUrl(seedUrl);
        AssertPrivateBridgeUrl(downloadUrl);
        AssertPrivateBridgeAddress(seedPeer);
        await using var seedHost = new TestHost();
        await using var downloadHost = new TestHost();
        using var seedApp = seedHost.CreateClient();
        using var downloadApp = downloadHost.CreateClient();
        var seedOrigin = ServiceConnections.ValidateOrigin(seedUrl);
        var downloadOrigin = ServiceConnections.ValidateOrigin(downloadUrl);
        await Configure(seedHost, seedOrigin, seedUser, seedPassword, 21);
        await Configure(downloadHost, downloadOrigin, downloadUser, downloadPassword, 22);
        var seeder = new QBitTorrentClient(seedHost.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        var downloader = new QBitTorrentClient(downloadHost.Services.GetRequiredService<ServiceConnections>(), new SystemSafeDns());
        await seeder.ConfigureManagedAsync();
        await downloader.ConfigureManagedAsync();
        var hashObservations = new List<object>();

        var fixtures = new[]
        {
            Path.Combine(privateFixtureRoot, "fixture-v1.torrent"),
            Path.Combine(privateFixtureRoot, "fixture-v2.torrent"),
            Path.Combine(privateFixtureRoot, "fixture-hybrid.torrent"),
            zeroTorrentPath
        };
        foreach (var torrentPath in fixtures)
        {
            var torrentBytes = await File.ReadAllBytesAsync(torrentPath);
            MetainfoDescriptor metadata;
            try { metadata = Metainfo.Parse(torrentBytes); }
            catch (ApiException error) { throw new InvalidOperationException($"Original fixture failed parser validation: {Path.GetFileName(torrentPath)} ({error.Code})", error); }
            Assert.Empty(metadata.Trackers);
            var seedPath = $"/data/{seedLibrary:D}/.briani/staging/{seedJob:N}";
            var uploadTag = $"briani-{Guid.NewGuid():N}";
            await seeder.AddAsync(new EngineAdd(torrentBytes, null, seedPath, uploadTag, false));
            var uploaded = await WaitForTorrent(seeder, t => t.Tags.Contains(uploadTag, StringComparer.Ordinal),
                TimeSpan.FromSeconds(15));
            var originalFiles = await seeder.FilesAsync(uploaded.Hash);
            DownloadFile[] originalLayout;
            try { originalLayout = DownloadLayout.Map(Guid.NewGuid(), metadata, originalFiles); }
            catch (ApiException error)
            {
                var metadataRows = string.Join(";", metadata.Files.Select(f => $"{f.Index}:{f.Path}:{f.Bytes}:{f.Padding}"));
                var engineRows = string.Join(";", originalFiles.Select(f => $"{f.Index}:{f.Path}:{f.Bytes}:{f.FirstPiece}-{f.LastPiece}"));
                throw new InvalidOperationException($"Engine layout mapping failed for {Path.GetFileName(torrentPath)} ({error.Code}); metadata=[{metadataRows}]; engine=[{engineRows}]", error);
            }
            Assert.Equal(metadata.Files.Length, originalLayout.Length);
            Assert.Equal(metadata.Files.Select(f => f.Path), originalLayout.Select(f => f.RelativePath));
            Assert.Equal(DownloadLayout.PieceCount(metadata), (await seeder.PiecesAsync(uploaded.Hash)).Length);
            await seeder.RemoveAsync(uploaded.Hash, false);

            var variantPath = Path.Combine(nonprivateRoot, Path.GetFileName(torrentPath));
            var variantBytes = await File.ReadAllBytesAsync(variantPath);
            var magnetMetadata = Metainfo.Parse(variantBytes);
            Assert.Empty(magnetMetadata.Trackers);
            var torrentHash = magnetMetadata.InfoHashV1 ?? magnetMetadata.InfoHashV2;
            Assert.NotNull(torrentHash);
            var seedTag = $"briani-{Guid.NewGuid():N}";
            await seeder.AddAsync(new EngineAdd(variantBytes, null, seedPath, seedTag, false));
            var seeded = await WaitForTorrent(seeder, t => t.Hash == torrentHash || t.InfoHashV1 == magnetMetadata.InfoHashV1 && t.InfoHashV2 == magnetMetadata.InfoHashV2,
                TimeSpan.FromSeconds(15));
            await seeder.StartAsync(seeded.Hash);
            seeded = await WaitForTorrent(seeder, t => t.Hash == seeded.Hash && t.Progress >= 0.999999,
                TimeSpan.FromSeconds(60));
            var seededFiles = await seeder.FilesAsync(seeded.Hash);
            Assert.Equal(DownloadLayout.PieceCount(magnetMetadata), (await seeder.PiecesAsync(seeded.Hash)).Length);
            Assert.Equal(DownloadLayout.PieceCount(magnetMetadata), seededFiles.Max(f => f.LastPiece) + 1);

            var downloadLibrary = Guid.NewGuid();
            var downloadJob = Guid.NewGuid();
            var downloadPath = $"/data/{downloadLibrary:D}/.briani/staging/{downloadJob:N}";
            var magnetHash = magnetMetadata.InfoHashV1 is not null
                ? $"magnet:?xt=urn:btih:{magnetMetadata.InfoHashV1}&dn=synthetic-local-{downloadJob:N}"
                : $"magnet:?xt=urn:btmh:1220{magnetMetadata.InfoHashV2}&dn=synthetic-local-{downloadJob:N}";
            await downloader.AddAsync(new EngineAdd(null, magnetHash, downloadPath, $"briani-{downloadJob:N}", true));
            var pending = await WaitForTorrent(downloader, t => magnetMetadata.InfoHashV1 is not null
                    ? t.InfoHashV1 == magnetMetadata.InfoHashV1
                    : t.InfoHashV2 == magnetMetadata.InfoHashV2,
                TimeSpan.FromSeconds(15));
            var filteredBefore = await downloader.TorrentsAsync(pending.Hash);
            var peerPort = await AddPeerAsync(downloadOrigin, downloadUser, downloadPassword, pending.Hash, seedOrigin, seedUser, seedPassword, seedPeer);
            var received = await WaitForMetadata(downloader, seeder, pending.Hash, seeded.Hash, TimeSpan.FromSeconds(45), peerPort);
            Assert.Equal(0, received.DownloadedBytes);
            Assert.Contains("stopped", received.State, StringComparison.OrdinalIgnoreCase);
            Assert.True(received.Sequential);
            var resolved = Assert.Single(await downloader.TorrentsAsync(received.Hash));
            Assert.Equal(magnetMetadata.InfoHashV1, resolved.InfoHashV1);
            Assert.Equal(magnetMetadata.InfoHashV2, resolved.InfoHashV2);
            var filteredAfter = await downloader.TorrentsAsync(received.Hash);
            hashObservations.Add(new
            {
                fixture = Path.GetFileName(torrentPath),
                seed = new { seeded.Hash, seeded.InfoHashV1, seeded.InfoHashV2 },
                downloadBeforeMetadata = new { pending.Hash, pending.InfoHashV1, pending.InfoHashV2, filteredCount = filteredBefore.Length },
                downloadAfterMetadata = new { resolved.Hash, resolved.InfoHashV1, resolved.InfoHashV2, filteredCount = filteredAfter.Length }
            });
            var observationPath = Environment.GetEnvironmentVariable("BRIANI_M05_OBSERVATIONS");
            if (!string.IsNullOrWhiteSpace(observationPath))
                await File.WriteAllTextAsync(observationPath, JsonSerializer.Serialize(hashObservations));

            var engineFiles = await downloader.FilesAsync(received.Hash);
            Assert.NotEmpty(engineFiles);
            Assert.Empty(await downloader.TrackersAsync(received.Hash));
            Assert.All(engineFiles.Where(x => x.Bytes > 0), file => Assert.Equal(0, file.Progress));
            var mapped = DownloadLayout.Map(downloadJob, magnetMetadata, engineFiles);
            Assert.Empty(await downloader.PiecesAsync(received.Hash));
            Assert.Equal(DownloadLayout.PieceCount(magnetMetadata), engineFiles.Max(f => f.LastPiece) + 1);
            Assert.Equal(magnetMetadata.Files.Length, mapped.Length);
            Assert.Equal(magnetMetadata.Files.Select(f => f.Index), mapped.Select(f => f.MetadataFileIndex));
            foreach (var expected in magnetMetadata.Files)
            {
                var actual = Assert.Single(mapped, x => x.MetadataFileIndex == expected.Index);
                Assert.Equal(expected.Path, actual.RelativePath);
                Assert.Equal(expected.Bytes, actual.SizeBytes);
                Assert.Equal(expected.Padding, actual.Padding);
                var engineFile = engineFiles.SingleOrDefault(x => x.Path == expected.Path);
                Assert.Equal(engineFile?.Index ?? (expected.Padding ? -expected.Index - 1 : throw new InvalidOperationException("real payload file was absent from the qBittorrent files list")), actual.UpstreamFileIndex);
            }
            if (!string.Equals(torrentPath, zeroTorrentPath, StringComparison.Ordinal))
            {
                using var manifest = JsonDocument.Parse(await File.ReadAllBytesAsync(Path.Combine(fixtureRoot, "manifest.json")));
                var oracle = manifest.RootElement.GetProperty("torrent").GetProperty("generated").EnumerateArray()
                    .Single(x => x.GetProperty("path").GetString() == Path.GetFileName(torrentPath))
                    .GetProperty("layout_oracle").GetProperty("files").EnumerateArray().ToArray();
                var payloadOracle = oracle.Where(x => !x.GetProperty("padding").GetBoolean()).ToArray();
                var expectedOracle = magnetMetadata.Files.Any(f => f.Padding) ? oracle : payloadOracle;
                Assert.Equal(expectedOracle.Length, mapped.Length);
                for (var i = 0; i < expectedOracle.Length; i++)
                {
                    if (expectedOracle[i].GetProperty("padding").GetBoolean())
                        Assert.Equal(magnetMetadata.Files[i].Path, mapped[i].RelativePath);
                    else
                        Assert.Equal(expectedOracle[i].GetProperty("path").GetString(), mapped[i].RelativePath);
                    Assert.Equal(expectedOracle[i].GetProperty("length").GetInt64(), mapped[i].SizeBytes);
                    Assert.Equal(expectedOracle[i].GetProperty("torrent_offset").GetInt64(), mapped[i].TorrentOffset);
                    Assert.Equal(expectedOracle[i].GetProperty("first_piece").GetInt32(), mapped[i].PieceFirst);
                    Assert.Equal(expectedOracle[i].GetProperty("last_piece").GetInt32(), mapped[i].PieceLast);
                    Assert.Equal(expectedOracle[i].GetProperty("padding").GetBoolean(), mapped[i].Padding);
                }
            }
            else
            {
                Assert.Equal(0, mapped[0].SizeBytes);
                Assert.Equal(0, mapped[0].PieceFirst);
                Assert.Equal(-1, mapped[0].PieceLast);
                Assert.Equal(0, mapped[1].TorrentOffset);
                Assert.Equal(1, mapped[1].PieceLast);
            }
            Assert.All(await downloader.PiecesAsync(received.Hash), state => Assert.NotEqual((byte)2, state));
            await downloader.RemoveAsync(received.Hash, false);
            await seeder.RemoveAsync(seeded.Hash, false);
        }
    }

    private static async Task<int> AddPeerAsync(Uri origin, string username, string password, string hash, Uri seedOrigin, string seedUsername, string seedPassword, string peerHost)
    {
        var (client, login) = await ApiClientAsync(origin, username, password);
        using var clientLifetime = client;
        using var loginLifetime = login;
        Assert.True(login.StatusCode is HttpStatusCode.OK or HttpStatusCode.NoContent);
        var (seedClient, seedLogin) = await ApiClientAsync(seedOrigin, seedUsername, seedPassword);
        using var seedClientLifetime = seedClient;
        using var seedLoginLifetime = seedLogin;
        Assert.True(seedLogin.StatusCode is HttpStatusCode.OK or HttpStatusCode.NoContent);
        using var preferencesResponse = await seedClient.GetAsync("api/v2/app/preferences");
        Assert.Equal(HttpStatusCode.OK, preferencesResponse.StatusCode);
        using var preferences = JsonDocument.Parse(await preferencesResponse.Content.ReadAsByteArrayAsync());
        var port = preferences.RootElement.GetProperty("listen_port").GetInt32();
        Assert.InRange(port, 1, 65535);
        using var response = await client.PostAsync("api/v2/torrents/addPeers", new FormUrlEncodedContent(new Dictionary<string, string> { ["hashes"] = hash, ["peers"] = $"{peerHost}:{port}" }));
        Assert.True(response.StatusCode is HttpStatusCode.OK or HttpStatusCode.NoContent);
        return port;
    }

    private static async Task<(HttpClient Client, HttpResponseMessage Login)> ApiClientAsync(Uri origin, string username, string password)
    {
        var cookies = new CookieContainer();
        var handler = new HttpClientHandler { CookieContainer = cookies, UseCookies = true, UseProxy = false, AllowAutoRedirect = false };
        var client = new HttpClient(handler) { BaseAddress = origin, Timeout = TimeSpan.FromSeconds(10) };
        client.DefaultRequestHeaders.Add("Origin", origin.GetLeftPart(UriPartial.Authority));
        client.DefaultRequestHeaders.Referrer = origin;
        var login = await client.PostAsync("api/v2/auth/login", new FormUrlEncodedContent(new Dictionary<string, string> { ["username"] = username, ["password"] = password }));
        return (client, login);
    }

    private static async Task<EngineTorrent> WaitForMetadata(ITorrentEngine downloader, ITorrentEngine seeder, string downloadHash, string seedHash, TimeSpan timeout, int peerPort)
    {
        var deadline = DateTimeOffset.UtcNow + timeout;
        EngineTorrent? lastDownload = null;
        EngineTorrent? lastSeed = null;
        while (DateTimeOffset.UtcNow < deadline)
        {
            var downloadTorrents = await downloader.TorrentsAsync();
            lastDownload = downloadTorrents.FirstOrDefault(t => string.Equals(t.Hash, downloadHash, StringComparison.OrdinalIgnoreCase))
                ?? (downloadTorrents.Length == 1 ? downloadTorrents[0] : null);
            if (lastDownload is { TotalBytes: > 0, Progress: 0 } && lastDownload.State.StartsWith("stopped", StringComparison.OrdinalIgnoreCase)) return lastDownload;
            var seedTorrents = await seeder.TorrentsAsync();
            lastSeed = seedTorrents.FirstOrDefault(t => string.Equals(t.Hash, seedHash, StringComparison.OrdinalIgnoreCase))
                ?? (seedTorrents.Length == 1 ? seedTorrents[0] : null);
            await Task.Delay(TimeSpan.FromMilliseconds(250));
        }
        var downloadState = lastDownload is null ? "missing" : $"hash={lastDownload.Hash},v1={lastDownload.InfoHashV1},v2={lastDownload.InfoHashV2},state={lastDownload.State},size={lastDownload.TotalBytes},progress={lastDownload.Progress:R},downloaded={lastDownload.DownloadedBytes},seeds={lastDownload.SeedersConnected},peers={lastDownload.PeersConnected}";
        var seedState = lastSeed is null ? "missing" : $"hash={lastSeed.Hash},v1={lastSeed.InfoHashV1},v2={lastSeed.InfoHashV2},state={lastSeed.State},size={lastSeed.TotalBytes},progress={lastSeed.Progress:R},downloaded={lastSeed.DownloadedBytes},seeds={lastSeed.SeedersConnected},peers={lastSeed.PeersConnected}";
        var downloaderPeers = await PeerSummaryAsync(Environment.GetEnvironmentVariable("BRIANI_M05_DOWNLOAD_URL")!, Environment.GetEnvironmentVariable("BRIANI_M05_DOWNLOAD_USERNAME")!, Environment.GetEnvironmentVariable("BRIANI_M05_DOWNLOAD_PASSWORD")!, lastDownload?.Hash ?? downloadHash);
        var seederPeers = await PeerSummaryAsync(Environment.GetEnvironmentVariable("BRIANI_M05_SEED_URL")!, Environment.GetEnvironmentVariable("BRIANI_M05_SEED_USERNAME")!, Environment.GetEnvironmentVariable("BRIANI_M05_SEED_PASSWORD")!, lastSeed?.Hash ?? seedHash);
        throw new TimeoutException($"local metadata exchange not observed after addPeers seedPort={peerPort}; downloader[{downloadState};peerDetails={downloaderPeers}]; seeder[{seedState};peerDetails={seederPeers}]");
    }

    private static async Task<string> PeerSummaryAsync(string baseUrl, string username, string password, string hash)
    {
        try
        {
            var (client, login) = await ApiClientAsync(new Uri(baseUrl), username, password);
            using (client)
            using (login)
            {
                if (login.StatusCode is not (HttpStatusCode.OK or HttpStatusCode.NoContent)) return "auth-failed";
                using var response = await client.GetAsync("api/v2/sync/torrentPeers?hash=" + Uri.EscapeDataString(hash));
                if (!response.IsSuccessStatusCode) return "unavailable";
                using var doc = JsonDocument.Parse(await response.Content.ReadAsByteArrayAsync());
                if (!doc.RootElement.TryGetProperty("peers", out var peers) || peers.ValueKind != JsonValueKind.Object) return "no-peer-details";
                var summaries = new List<string>();
                foreach (var peer in peers.EnumerateObject().Take(4))
                {
                    var p = peer.Value;
                    var clientName = p.TryGetProperty("client", out var c) && c.ValueKind == JsonValueKind.String ? c.GetString() : "?";
                    var flags = p.TryGetProperty("flags_desc", out var f) && f.ValueKind == JsonValueKind.String ? f.GetString() : "?";
                    var progress = p.TryGetProperty("progress", out var pr) && pr.TryGetDouble(out var d) ? d.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture) : "?";
                    var up = p.TryGetProperty("up_speed", out var us) && us.TryGetInt64(out var u) ? u : -1;
                    var down = p.TryGetProperty("dl_speed", out var ds) && ds.TryGetInt64(out var dl) ? dl : -1;
                    summaries.Add($"client={SafeDiagnostic(clientName)},flags={SafeDiagnostic(flags)},progress={progress},up={up},down={down}");
                }
                return summaries.Count == 0 ? "empty" : string.Join(';', summaries);
            }
        }
        catch { return "diagnostic-failed"; }
    }

    private static string SafeDiagnostic(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return "?";
        var safe = new string(value.Where(ch => !char.IsControl(ch)).Take(80).ToArray());
        return safe.Replace(';', '_').Replace(',', '_');
    }

    private static void AssertPrivateBridgeUrl(string value)
    {
        var uri = new Uri(value);
        Assert.Equal("http", uri.Scheme);
        Assert.True(IPAddress.TryParse(uri.Host, out var address));
        AssertPrivateBridgeAddress(address!.ToString());
    }

    private static void AssertPrivateBridgeAddress(string value)
    {
        Assert.True(IPAddress.TryParse(value, out var address));
        var bytes = address!.GetAddressBytes();
        Assert.True(IPAddress.IsLoopback(address) || bytes[0] == 10 || bytes[0] == 192 && bytes[1] == 168 || bytes[0] == 172 && bytes[1] is >= 16 and <= 31,
            "local peer harness must use an RFC1918 or loopback address");
    }

    private static int FreePort()
    {
        using var socket = new TcpListener(IPAddress.Loopback, 0);
        socket.Start();
        return ((IPEndPoint)socket.LocalEndpoint).Port;
    }

    private static async Task Configure(TestHost host, Uri origin, string username, string password, long version)
    {
        var secretStore = host.Services.GetRequiredService<SecretStore>();
        await host.InDb(async db =>
        {
            db.Settings.Add(new Setting { Key = "integration.qbittorrent", ValueJson = JsonSerializer.Serialize(new ProtectedConnection(origin.AbsoluteUri, username, secretStore.Encrypt(password), version)), UpdatedAt = host.Clock.GetUtcNow() });
            await db.SaveChangesAsync(); return true;
        });
    }

    private static async Task<EngineTorrent> WaitForTorrent(ITorrentEngine engine, Func<EngineTorrent, bool> predicate, TimeSpan timeout)
    {
        var until = DateTimeOffset.UtcNow + timeout;
        while (DateTimeOffset.UtcNow < until)
        {
            var found = (await engine.TorrentsAsync()).FirstOrDefault(predicate);
            if (found is not null) return found;
            await Task.Delay(TimeSpan.FromMilliseconds(100));
        }
        throw new TimeoutException("bounded qBittorrent fixture state was not observed");
    }

    private static async Task Reply(HttpListenerContext context, int status, string body)
        => await Reply(context, status, Encoding.UTF8.GetBytes(body), "text/plain");

    private static async Task Reply(HttpListenerContext context, int status, string body, string contentType)
        => await Reply(context, status, Encoding.UTF8.GetBytes(body), contentType);

    private static async Task Reply(HttpListenerContext context, int status, byte[] bytes, string contentType)
    {
        context.Response.StatusCode = status;
        context.Response.ContentType = contentType;
        context.Response.ContentLength64 = bytes.Length;
        await context.Response.OutputStream.WriteAsync(bytes);
        context.Response.Close();
    }
}
