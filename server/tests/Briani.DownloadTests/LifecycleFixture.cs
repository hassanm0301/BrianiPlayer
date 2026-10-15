using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Modules.Identity;
using System.Net.Http.Json;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Briani.DownloadTests;

internal sealed class LifecycleFixture : IAsyncDisposable
{
    public static readonly byte[] TorrentBytes = BuildTorrent();
    public static readonly string Hash = Convert.ToHexString(SHA1.HashData(InfoBytes(TorrentBytes))).ToLowerInvariant();
    public const long FileBytes = 64 * 1024;
    private readonly TestHost root;
    private readonly WebApplicationFactory<Program> host;
    public HttpClient Client { get; }
    public AuthReply Admin { get; }
    public FakeTorrentEngine Engine { get; }
    public Guid LibraryId { get; }
    public string LibraryPath => Path.Combine(root.Root, "data", "library");
    public string StatePath => Path.Combine(root.Root, "state");
    public ManualClock Clock => root.Clock;
    public DownloadWorker Worker => host.Services.GetRequiredService<DownloadWorker>();
    public IServiceProvider Services => host.Services;

    private LifecycleFixture(TestHost root, WebApplicationFactory<Program> host, HttpClient client,
        AuthReply admin, FakeTorrentEngine engine, Guid libraryId)
    { this.root = root; this.host = host; Client = client; Admin = admin; Engine = engine; LibraryId = libraryId; }

    public static async Task<LifecycleFixture> Create(ISafeDns? safeDns = null, Action<IServiceCollection>? testServices = null)
    {
        var root = new TestHost();
        var engine = new FakeTorrentEngine();
        var host = root.WithWebHostBuilder(builder => builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<ITorrentEngine>().AddSingleton<ITorrentEngine>(engine);
            if (safeDns is not null) services.RemoveAll<ISafeDns>().AddSingleton(safeDns);
            testServices?.Invoke(services);
        }));
        var client = host.CreateClient();
        var password = "Lifecycle-Test-" + Credentials.NewToken();
        var admin = await IdentityFixture.Bootstrap(client, root.BootstrapCode(), "lifecycleadmin", "Lifecycle Admin", password);
        IdentityFixture.As(client, admin.AccessToken);
        var libraryId = Guid.NewGuid();
        Directory.CreateDirectory(Path.Combine(root.Root, "data", "library"));
        using (var scope = host.Services.CreateScope())
        {
            var storage = scope.ServiceProvider.GetRequiredService<ContainedStorage>();
            var identity = storage.ValidateLibraryRoot("library");
            var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
            db.Libraries.Add(new Library { Id = libraryId, Name = "Lifecycle", RootPath = identity.RelativePath, RootIdentity = identity.Identity, CreatedAt = root.Clock.GetUtcNow() });
            await db.SaveChangesAsync();
        }
        engine.DataRoot = Path.Combine(root.Root, "data");
        return new LifecycleFixture(root, host, client, admin, engine, libraryId);
    }

    private static byte[] InfoBytes(byte[] metainfo)
    {
        var marker = System.Text.Encoding.ASCII.GetBytes("4:info");
        // The outer dictionary's leading `d` precedes the `4:info` key.
        var start = marker.Length + 1;
        return metainfo.AsSpan(start, metainfo.Length - start - 1).ToArray();
    }

    private static byte[] BuildTorrent()
    {
        using var info = new MemoryStream();
        void Raw(string value) => info.Write(System.Text.Encoding.ASCII.GetBytes(value));
        void Bytes(string key, byte[] value)
        {
            Raw(key.Length.ToString(System.Globalization.CultureInfo.InvariantCulture) + ":" + key);
            Raw(value.Length.ToString(System.Globalization.CultureInfo.InvariantCulture) + ":");
            info.Write(value);
        }
        Raw("d");
        Raw("6:lengthi" + FileBytes.ToString(System.Globalization.CultureInfo.InvariantCulture) + "e");
        Bytes("name", System.Text.Encoding.UTF8.GetBytes("fixture.mp4"));
        Raw("12:piece lengthi16384e");
        Bytes("pieces", new byte[80]);
        Raw("e");
        var infoBytes = info.ToArray();
        using var torrent = new MemoryStream();
        torrent.Write(System.Text.Encoding.ASCII.GetBytes("d4:info"));
        torrent.Write(infoBytes);
        torrent.WriteByte((byte)'e');
        return torrent.ToArray();
    }

    public async Task<T> InDb<T>(Func<BrianiDb, Task<T>> action)
    {
        using var scope = host.Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<BrianiDb>());
    }

    public async Task<UserSession> CreateUser(string username)
    {
        var password = "Lifecycle-User-" + Credentials.NewToken();
        using var created = await Client.PostAsJsonAsync("/api/v1/admin/users", new { username, displayName = username, password, confirmPassword = password, role = "member" });
        created.EnsureSuccessStatusCode();
        var user = (await created.Content.ReadFromJsonAsync<UserReply>())!;
        using var login = await Client.PostAsJsonAsync("/api/v1/auth/login", new { username, password, deviceName = "lifecycle-test" });
        login.EnsureSuccessStatusCode();
        var auth = (await login.Content.ReadFromJsonAsync<AuthReply>())!;
        var client = host.CreateClient();
        IdentityFixture.As(client, auth.AccessToken);
        return new UserSession(user, auth, client);
    }

    public Task<int> Grant(Guid userId, long? quota = null) => InDb(async db =>
    {
        db.LibraryGrants.Add(new LibraryGrant { UserId = userId, LibraryId = LibraryId, CanRead = true, CanDownload = true, CanManage = false, QuotaBytes = quota });
        return await db.SaveChangesAsync();
    });

    public async Task<Guid> CreateLibrary(string name)
    {
        var rootPath = "library-" + Guid.NewGuid().ToString("N");
        Directory.CreateDirectory(Path.Combine(root.Root, "data", rootPath));
        using var scope = host.Services.CreateScope();
        var identity = scope.ServiceProvider.GetRequiredService<ContainedStorage>().ValidateLibraryRoot(rootPath);
        var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        var library = new Library { Name = name, RootPath = identity.RelativePath, RootIdentity = identity.Identity, CreatedAt = Clock.GetUtcNow() };
        db.Libraries.Add(library);
        await db.SaveChangesAsync();
        return library.Id;
    }

    public async Task<DownloadView> CreateDownload(HttpClient client, Guid libraryId, string? hash = null, string? idempotencyKey = null)
    {
        hash ??= Hash;
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/downloads")
        { Content = JsonContent.Create(new { libraryId, source = new { kind = "magnet", value = $"magnet:?xt=urn:btih:{hash}" } }) };
        if (idempotencyKey is not null) request.Headers.Add("Idempotency-Key", idempotencyKey);
        using var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<DownloadView>())!;
    }

    public Task<int> SeedReadyDownload(Guid ownerId, Guid sessionId, string state = "downloading", string? hash = null)
    {
        CreateStageFile();
        using var libraryRoot = new ContainedDirectory(LibraryPath);
        using var stage = libraryRoot.Directory($".briani/staging/{Engine.JobId:N}");
        var fileNode = stage.Inspect("fixture.mp4");
        var stageIdentity = stage.Identity;
        return InDb(async db =>
        {
        var now = Clock.GetUtcNow();
        var job = new TorrentJob
        {
            Id = Engine.JobId, LibraryId = LibraryId, ManagedPath = $".briani/staging/{Engine.JobId:N}",
            OwnershipTag = $"briani-{Engine.JobId:N}", VolumeIdentity = "test-volume", ReservedBytes = 0,
            ManagedRootIdentity = stageIdentity,
            UpstreamId = hash ?? Hash, InfoHashV1 = hash ?? Hash, MetadataStatus = "ready", EngineState = "downloading",
            DesiredState = "running", Sequential = true, MetadataAssist = true, PieceLength = 16 * 1024,
            PieceCount = (int)(FileBytes / (16 * 1024)), TotalBytes = FileBytes, Name = "fixture",
            CreatedAt = now, UpdatedAt = now
        };
        var request = new DownloadRequest
        {
            Id = Engine.RequestId, OwnerId = ownerId, AuthSessionId = sessionId, LibraryId = LibraryId,
            TorrentJobId = job.Id, SourceKind = "magnet", SourceDigest = "fixture", EncryptedSourceReference = "",
            State = state, SourceState = "ready", SelectedBytes = FileBytes, ReservedBytes = FileBytes,
            VolumeIdentity = "test-volume", CreatedAt = now, UpdatedAt = now, Version = 1
        };
        var file = new DownloadFile
        {
            Id = Engine.FileId, TorrentJobId = job.Id, UpstreamFileIndex = 0, MetadataFileIndex = 0,
            RelativePath = "fixture.mp4", DisplayName = "fixture.mp4", SizeBytes = FileBytes,
            TorrentOffset = 0, PieceFirst = 0, PieceLast = job.PieceCount - 1, Kind = "video", Wanted = true,
            FilePriority = 7, DownloadedBytes = FileBytes, ContiguousBytes = FileBytes,
            Completed = true, PlaybackState = "eligible", FileIdentity = fileNode.Key, MtimeNs = fileNode.MtimeNs, Version = 1
        };
        db.TorrentJobs.Add(job);
        db.DownloadRequests.Add(request);
        db.DownloadFiles.Add(file);
        db.DownloadRequestFiles.Add(new DownloadRequestFile { DownloadRequestId = request.Id, DownloadFileId = file.Id, Selected = true, Priority = 7 });
        await db.SaveChangesAsync();
        return 0;
        });
    }

    public async Task<Guid> AddSecondReadyFile()
    {
        var secondId = Guid.NewGuid();
        await InDb(async db =>
        {
            var job = await db.TorrentJobs.SingleAsync(x => x.Id == Engine.JobId);
            var request = await db.DownloadRequests.SingleAsync(x => x.Id == Engine.RequestId);
            var first = await db.DownloadFiles.SingleAsync(x => x.Id == Engine.FileId);
            job.TotalBytes = 2 * FileBytes; job.PieceCount = 8;
            first.PieceFirst = 0; first.PieceLast = 3;
            request.SelectedBytes = 2 * FileBytes; request.ReservedBytes = 2 * FileBytes;
            db.DownloadFiles.Add(new DownloadFile
            {
                Id = secondId, TorrentJobId = job.Id, UpstreamFileIndex = 1, MetadataFileIndex = 1,
                RelativePath = "second.mp4", DisplayName = "second.mp4", SizeBytes = FileBytes,
                TorrentOffset = FileBytes, PieceFirst = 4, PieceLast = 7, Kind = "video", Wanted = true,
                FilePriority = 7, DownloadedBytes = 0, ContiguousBytes = 0, Completed = false, PlaybackState = "waitingForData", Version = 1
            });
            db.DownloadRequestFiles.Add(new DownloadRequestFile { DownloadRequestId = request.Id, DownloadFileId = secondId, Selected = true, Priority = 7 });
            db.DownloadOwnerships.Add(new DownloadOwnership { OwnerId = request.OwnerId, LibraryId = LibraryId, DownloadFileId = secondId, Bytes = FileBytes });
            await db.SaveChangesAsync();
            return 0;
        });
        Engine.ConfigureFiles(8,
            new EngineFile(0, "fixture.mp4", FileBytes, 1, 7, 0, 3),
            new EngineFile(1, "second.mp4", FileBytes, 1, 7, 4, 7));
        Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(LibraryPath, ".briani", "staging", Engine.JobId.ToString("N")));
        return secondId;
    }

    public void CreateStageFile()
    {
        var directory = Path.Combine(LibraryPath, ".briani", "staging", Engine.JobId.ToString("N"));
        Directory.CreateDirectory(directory);
        File.WriteAllBytes(Path.Combine(directory, "fixture.mp4"), Enumerable.Range(0, (int)FileBytes).Select(i => (byte)(i % 251)).ToArray());
    }

    public ValueTask DisposeAsync()
    {
        Client.Dispose(); host.Dispose(); root.Dispose();
        return ValueTask.CompletedTask;
    }

    internal sealed record UserSession(UserReply User, AuthReply Auth, HttpClient Client);
}

internal sealed class FakeTorrentEngine : ITorrentEngine
{
    private readonly object sync = new();
    private readonly Dictionary<string, EngineTorrent> torrents = new(StringComparer.OrdinalIgnoreCase);
    private int addCalls;
    private int recheckCalls;
    private int startCalls;
    private int stopCalls;
    private int priorityUpdateCalls;
    private int pieceCount = 4;
    private EngineFile[] fileDefinitions = [new(0, "fixture.mp4", LifecycleFixture.FileBytes, 1d, 1, 0, 3)];
    private readonly Dictionary<int, int> filePriorities = [];
    public List<(int[] Indexes, int Priority)> PriorityUpdates { get; } = [];
    public int AddCalls => Volatile.Read(ref addCalls);
    public int RecheckCalls => Volatile.Read(ref recheckCalls);
    public int StartCalls => Volatile.Read(ref startCalls);
    public int StopCalls => Volatile.Read(ref stopCalls);
    public int PriorityUpdateCalls => Volatile.Read(ref priorityUpdateCalls);
    public Func<int, CancellationToken, Task>? BeforePriorityUpdate { get; set; }
    public bool TimeoutAfterAddOnce { get; set; }
    public bool IncludeTrackerInExport { get; set; }
    public bool CompletePieces { get; set; } = true;
    public byte[]? PieceStatesOverride { get; set; }
    public string DataRoot { get; set; } = "";
    public Guid JobId { get; set; } = Guid.NewGuid();
    public Guid RequestId { get; set; } = Guid.NewGuid();
    public Guid FileId { get; set; } = Guid.NewGuid();
    public string? LastSavePath { get; private set; }
    public void ConfigureFiles(int pieces, params EngineFile[] files)
    {
        lock (sync)
        {
            pieceCount = pieces;
            fileDefinitions = files;
            filePriorities.Clear();
            foreach (var file in files) filePriorities[file.Index] = file.Priority;
        }
    }
    public int FilePriority(int index) { lock (sync) return filePriorities.GetValueOrDefault(index, priority); }
    public Task<EngineVersion> VersionAsync(CancellationToken ct = default) => Task.FromResult(new EngineVersion("test", "test", "test"));
    public Task<EngineTorrent[]> TorrentsAsync(string? hash = null, CancellationToken ct = default)
    { lock (sync) return Task.FromResult(torrents.Values.Where(x => hash is null || x.Hash.Equals(hash, StringComparison.OrdinalIgnoreCase)).ToArray()); }
    private int priority;
    public Task<EngineFile[]> FilesAsync(string hash, CancellationToken ct = default)
    { lock (sync) return Task.FromResult(fileDefinitions.Select(x => x with { Progress = CompletePieces ? 1d : 0d, Priority = filePriorities.GetValueOrDefault(x.Index, priority) }).ToArray()); }
    public Task<byte[]> ExportAsync(string hash, CancellationToken ct = default)
    {
        var bytes = LifecycleFixture.TorrentBytes;
        if (!IncludeTrackerInExport) return Task.FromResult(bytes.ToArray());
        var info = bytes.AsSpan(7, bytes.Length - 8).ToArray();
        var tracker = System.Text.Encoding.ASCII.GetBytes("https://tracker.example.test/announce");
        using var result = new MemoryStream();
        result.Write(System.Text.Encoding.ASCII.GetBytes("d8:announce"));
        result.Write(System.Text.Encoding.ASCII.GetBytes(tracker.Length.ToString(System.Globalization.CultureInfo.InvariantCulture) + ":"));
        result.Write(tracker);
        result.Write(System.Text.Encoding.ASCII.GetBytes("4:info"));
        result.Write(info);
        result.WriteByte((byte)'e');
        return Task.FromResult(result.ToArray());
    }
    public Task<byte[]> PiecesAsync(string hash, CancellationToken ct = default) => Task.FromResult(PieceStatesOverride?.ToArray() ?? Enumerable.Repeat((byte)(CompletePieces ? 2 : 0), pieceCount).ToArray());
    public Task<EngineTracker[]> TrackersAsync(string hash, CancellationToken ct = default) => Task.FromResult(Array.Empty<EngineTracker>());
    public Task AddAsync(EngineAdd add, CancellationToken ct = default)
    {
        Interlocked.Increment(ref addCalls);
        var hash = LifecycleFixture.Hash;
        LastSavePath = add.SavePath;
        var savePath = Path.IsPathFullyQualified(add.SavePath) ? add.SavePath : Path.Combine(DataRoot, "library", add.SavePath);
        Directory.CreateDirectory(savePath);
        if (!File.Exists(Path.Combine(savePath, "fixture.mp4"))) File.WriteAllBytes(Path.Combine(savePath, "fixture.mp4"), Enumerable.Range(0, (int)LifecycleFixture.FileBytes).Select(i => (byte)(i % 251)).ToArray());
        priority = 0;
        lock (sync) foreach (var file in fileDefinitions) filePriorities[file.Index] = 0;
        lock (sync) torrents[hash] = new(hash, hash, null, "fixture", savePath, "downloading", LifecycleFixture.FileBytes,
            CompletePieces ? LifecycleFixture.FileBytes : 0, 0, 0, 0, CompletePieces ? 1 : 0, 1, true, true, [add.OwnershipTag], null, 1, 1, 0);
        if (TimeoutAfterAddOnce) { TimeoutAfterAddOnce = false; throw new EngineFailure("engine_timeout"); }
        return Task.CompletedTask;
    }
    public void RegisterExisting(string hash, string savePath, string state = "downloading")
    {
        priority = 7;
        lock (sync) foreach (var file in fileDefinitions) filePriorities[file.Index] = 7;
        lock (sync) torrents[hash] = new(hash, hash, null, "fixture", savePath, state, LifecycleFixture.FileBytes,
            CompletePieces ? LifecycleFixture.FileBytes : 0, 0, 0, 0, CompletePieces ? 1 : 0, 1, true, true, [$"briani-{JobId:N}"], null, 1, 1, 0);
    }
    public void RegisterHybridRehashed(string originalV1, string expectedV2, string newEngineHash, string savePath)
    {
        priority = 7;
        lock (sync)
        {
            foreach (var file in fileDefinitions) filePriorities[file.Index] = 7;
            torrents[newEngineHash] = new(newEngineHash, originalV1, expectedV2, "fixture", savePath, "downloading", LifecycleFixture.FileBytes,
                CompletePieces ? LifecycleFixture.FileBytes : 0, 0, 0, 0, CompletePieces ? 1 : 0, 1, true, true, [$"briani-{JobId:N}"], null, 1, 1, 0);
        }
    }
    public Task StopAsync(string hash, CancellationToken ct = default) { Interlocked.Increment(ref stopCalls); return UpdateState(hash, "paused"); }
    public Func<string, CancellationToken, Task>? BeforeStart { get; set; }
    public async Task StartAsync(string hash, CancellationToken ct = default) {
        Interlocked.Increment(ref startCalls);
        if (BeforeStart is not null) await BeforeStart(hash, ct);
        await UpdateState(hash, "downloading");
    }
    public Task EnsureSequentialAsync(string hash, bool enabled, CancellationToken ct = default) => Task.CompletedTask;
    public Task EnsureMetadataAssistAsync(string hash, bool enabled, CancellationToken ct = default) => Task.CompletedTask;
    public async Task SetFilePriorityAsync(string hash, int[] indexes, int priority, CancellationToken ct = default)
    {
        var call = Interlocked.Increment(ref priorityUpdateCalls);
        if (BeforePriorityUpdate is not null) await BeforePriorityUpdate(call, ct);
        lock (sync) { this.priority = priority; foreach (var index in indexes) filePriorities[index] = priority; PriorityUpdates.Add((indexes.ToArray(), priority)); }
    }
    public Task ApplyLimitsAsync(string hash, EngineLimits limits, CancellationToken ct = default) => Task.CompletedTask;
    public Task RecheckAsync(string hash, CancellationToken ct = default) { Interlocked.Increment(ref recheckCalls); CompletePieces = false; return UpdateState(hash, "checking"); }
    public Task ReannounceAsync(string hash, CancellationToken ct = default) => Task.CompletedTask;
    public Task RemoveAsync(string hash, bool deleteFiles, CancellationToken ct = default)
    { lock (sync) torrents.Remove(hash); return Task.CompletedTask; }
    public Task ConfigureManagedAsync(CancellationToken ct = default) => Task.CompletedTask;
    private Task UpdateState(string hash, string state)
    {
        lock (sync) if (torrents.TryGetValue(hash, out var torrent)) torrents[hash] = torrent with { State = state };
        return Task.CompletedTask;
    }
}
