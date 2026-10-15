using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;

namespace Briani.DownloadTests;

public sealed class QueryApiTests
{
    [Fact]
    public async Task Owner_reads_summary_files_and_curated_settings_without_filesystem_or_tracker_secrets()
    {
        await using var fixture = await QueryFixture.Create();
        var ids = await fixture.SeedRequest(fixture.Admin.User.Id, fixture.Admin.SessionId, "downloading", includeFiles: true);

        using var summaryResponse = await fixture.AdminClient.GetAsync($"/api/v1/downloads/{ids.RequestId}");
        Assert.Equal(HttpStatusCode.OK, summaryResponse.StatusCode);
        var summary = await summaryResponse.Content.ReadFromJsonAsync<DownloadView>();
        Assert.NotNull(summary);
        Assert.Equal(900, summary.SelectedBytes);
        Assert.Equal(480, summary.DownloadedSelectedBytes);
        Assert.Equal(1000, summary.TorrentBytes);
        Assert.Equal("downloading", summary.State);
        Assert.Equal("ready", summary.SourceState);
        Assert.Equal("downloading", summary.TransferState);
        Assert.Equal("pending", summary.ImportState);
        Assert.Equal(ids.JobId.ToString("N") + ":7", summary.Generation);
        Assert.DoesNotContain("/private/staging", JsonSerializer.Serialize(summary), StringComparison.Ordinal);
        Assert.DoesNotContain("passkey", JsonSerializer.Serialize(summary), StringComparison.OrdinalIgnoreCase);

        using var filesResponse = await fixture.AdminClient.GetAsync($"/api/v1/downloads/{ids.RequestId}/files");
        var files = await filesResponse.Content.ReadFromJsonAsync<DownloadFileView[]>();
        Assert.NotNull(files);
        Assert.Equal(3, files.Length);
        Assert.DoesNotContain(files, x => x.Name == "padding.bin");
        var video = Assert.Single(files, x => x.Name == "episode.mkv");
        Assert.True(video.Selected);
        Assert.Equal("high", video.Priority);
        Assert.Equal("eligible", video.PlaybackState); // persisted value, not calculated from progress
        Assert.Equal(ids.RequestId, video.DownloadId);
        Assert.Equal("folder/episode.mkv", video.RelativePath);
        Assert.Equal("subtitle.srt", Assert.Single(files, x => x.Name == "subtitle.srt").RelativePath);

        using var settingsResponse = await fixture.AdminClient.GetAsync($"/api/v1/downloads/{ids.RequestId}/settings");
        var settings = await settingsResponse.Content.ReadFromJsonAsync<DownloadSettings>();
        Assert.NotNull(settings);
        Assert.Equal(3, settings.Version);
        Assert.Equal(123_000, settings.DownloadLimitBytesPerSecond);
        Assert.Equal(0.75, settings.RatioLimit);
        Assert.Equal(["fixture"], settings.Tags!);
        Assert.DoesNotContain("passkey", JsonSerializer.Serialize(settings), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Listing_filters_pages_and_scopes_cursors_to_actor_and_filter()
    {
        await using var fixture = await QueryFixture.Create();
        var first = await fixture.SeedRequest(fixture.Admin.User.Id, fixture.Admin.SessionId, "queued");
        fixture.Advance(TimeSpan.FromSeconds(1));
        var second = await fixture.SeedRequest(fixture.Admin.User.Id, fixture.Admin.SessionId, "paused");

        using var pageResponse = await fixture.AdminClient.GetAsync("/api/v1/downloads?limit=1&state=queued");
        Assert.Equal(HttpStatusCode.OK, pageResponse.StatusCode);
        var page = await pageResponse.Content.ReadFromJsonAsync<DownloadPageView>();
        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal(first.RequestId, item.Id);
        Assert.Null(page.NextCursor);
        Assert.Equal(1, page.TotalKnown);

        using var allResponse = await fixture.AdminClient.GetAsync("/api/v1/downloads?limit=1");
        var all = await allResponse.Content.ReadFromJsonAsync<DownloadPageView>();
        Assert.NotNull(all);
        Assert.NotNull(all.NextCursor);
        using var nextResponse = await fixture.AdminClient.GetAsync("/api/v1/downloads?limit=1&cursor=" + Uri.EscapeDataString(all.NextCursor));
        var next = await nextResponse.Content.ReadFromJsonAsync<DownloadPageView>();
        Assert.NotNull(next);
        Assert.Equal(first.RequestId, Assert.Single(next.Items).Id);

        using var wrongFilter = await fixture.AdminClient.GetAsync("/api/v1/downloads?limit=1&state=paused&cursor=" + Uri.EscapeDataString(all.NextCursor));
        Assert.Equal(HttpStatusCode.BadRequest, wrongFilter.StatusCode);
    }

    [Fact]
    public async Task Manager_can_read_shared_request_but_viewer_cannot_and_revoked_grant_hides_it()
    {
        await using var fixture = await QueryFixture.Create();
        var owner = await fixture.CreateUser("downloadowner", "member");
        var viewer = await fixture.CreateUser("downloadviewer", "member");
        var manager = await fixture.CreateUser("downloadmanager", "member");
        await fixture.Grant(viewer.User.Id, canRead: true, canDownload: false, canManage: false);
        await fixture.Grant(manager.User.Id, canRead: true, canDownload: true, canManage: true);
        var ids = await fixture.SeedRequest(owner.User.Id, owner.Auth.SessionId, "seeding");

        using var managerRead = await manager.Client.GetAsync($"/api/v1/downloads/{ids.RequestId}");
        Assert.Equal(HttpStatusCode.OK, managerRead.StatusCode);
        using var viewerRead = await viewer.Client.GetAsync($"/api/v1/downloads/{ids.RequestId}");
        Assert.Equal(HttpStatusCode.NotFound, viewerRead.StatusCode);
        using var viewerList = await viewer.Client.GetAsync("/api/v1/downloads");
        var hidden = await viewerList.Content.ReadFromJsonAsync<DownloadPageView>();
        Assert.NotNull(hidden);
        Assert.Empty(hidden.Items);

        await fixture.Revoke(viewer.User.Id);
        using var revoked = await viewer.Client.GetAsync($"/api/v1/downloads/{ids.RequestId}");
        Assert.Equal(HttpStatusCode.NotFound, revoked.StatusCode);
    }

    [Fact]
    public async Task Events_stream_emits_only_authenticated_download_hints()
    {
        await using var fixture = await QueryFixture.Create();
        var ids = await fixture.SeedRequest(fixture.Admin.User.Id, fixture.Admin.SessionId, "downloading", includeFiles: true);
        using var response = await fixture.AdminClient.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.StartsWith("text/event-stream", response.Content.Headers.ContentType?.ToString(), StringComparison.OrdinalIgnoreCase);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        await using var stream = await response.Content.ReadAsStreamAsync(timeout.Token);
        using var reader = new StreamReader(stream);
        string? line;
        do { line = await reader.ReadLineAsync(timeout.Token); } while (line is not null && !line.StartsWith("data: ", StringComparison.Ordinal));
        Assert.NotNull(line);
        var json = line[6..];
        Assert.DoesNotContain("passkey", json, StringComparison.OrdinalIgnoreCase);
        using var envelope = JsonDocument.Parse(json);
        Assert.Equal("download.updated", envelope.RootElement.GetProperty("type").GetString());
        Assert.Equal(ids.RequestId.ToString(), envelope.RootElement.GetProperty("payload").GetProperty("id").GetString());
        Assert.True(envelope.RootElement.GetProperty("payload").GetProperty("progress").GetDouble() is >= 0 and <= 1);
    }

    [Fact]
    public async Task Events_stream_rechecks_manager_grant_before_each_poll()
    {
        await using var fixture = await QueryFixture.Create();
        var owner = await fixture.CreateUser("eventowner", "member");
        var manager = await fixture.CreateUser("eventmanager", "member");
        await fixture.Grant(manager.User.Id, canRead: true, canDownload: true, canManage: true);
        var ids = await fixture.SeedRequest(owner.User.Id, owner.Auth.SessionId, "downloading", includeFiles: true);
        using var response = await manager.Client.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using var initialTimeout = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        await using var stream = await response.Content.ReadAsStreamAsync(initialTimeout.Token);
        using var reader = new StreamReader(stream);
        string? line;
        do { line = await reader.ReadLineAsync(initialTimeout.Token); } while (line is not null && !line.StartsWith("data: ", StringComparison.Ordinal));
        Assert.NotNull(line);
        using (var envelope = JsonDocument.Parse(line[6..]))
            Assert.Equal(ids.RequestId.ToString(), envelope.RootElement.GetProperty("payload").GetProperty("id").GetString());
        Assert.Equal("", await reader.ReadLineAsync(initialTimeout.Token));

        await fixture.Revoke(manager.User.Id);
        await fixture.ChangeDownloadRate(ids.JobId, 999);
        using var noFurtherEvents = new CancellationTokenSource(TimeSpan.FromMilliseconds(1500));
        var stopped = await Record.ExceptionAsync(async () => await reader.ReadLineAsync(noFurtherEvents.Token));
        Assert.True(stopped is null || stopped is OperationCanceledException || stopped is IOException { InnerException: OperationCanceledException });
    }

    [Fact]
    public async Task Events_stream_admission_is_bounded_per_user_and_released_on_disconnect()
    {
        await using var fixture = await QueryFixture.Create();
        using var first = await fixture.AdminClient.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead);
        using var second = await fixture.AdminClient.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead);
        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);

        using var rejected = await fixture.AdminClient.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead);
        Assert.Equal(HttpStatusCode.TooManyRequests, rejected.StatusCode);
        Assert.Contains("event_stream_limit", await rejected.Content.ReadAsStringAsync(), StringComparison.Ordinal);

        first.Dispose();
        using var afterDisconnect = await fixture.AdminClient.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead);
        Assert.Equal(HttpStatusCode.OK, afterDisconnect.StatusCode);
    }

    [Fact]
    public async Task Events_stream_admission_caps_global_connections_across_users()
    {
        await using var fixture = await QueryFixture.Create();
        var clients = new List<HttpClient> { fixture.AdminClient };
        for (var i = 0; i < 8; i++) clients.Add((await fixture.CreateUser($"eventcap{i}", "member")).Client);
        var opened = new List<HttpResponseMessage>();
        try
        {
            foreach (var client in clients.Take(8))
            {
                opened.Add(await client.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead));
                opened.Add(await client.GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead));
            }
            Assert.All(opened, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));
            using var globallyRejected = await clients[8].GetAsync("/api/v1/events", HttpCompletionOption.ResponseHeadersRead);
            Assert.Equal(HttpStatusCode.TooManyRequests, globallyRejected.StatusCode);
            Assert.Contains("event_stream_limit", await globallyRejected.Content.ReadAsStringAsync(), StringComparison.Ordinal);
        }
        finally
        {
            foreach (var response in opened) response.Dispose();
            foreach (var client in clients.Skip(1)) client.Dispose();
        }
    }

    [Fact]
    public async Task Events_write_cancels_a_blocked_body_when_access_is_revoked()
    {
        using var guard = new DownloadQueries.EventAccessGuard("initial");
        await using var body = new CancellationBlockedStream();
        var write = DownloadQueries.WriteEventBatchAsync(body, ["{}"u8.ToArray()], guard.Token);
        await Task.Delay(25);
        guard.Revoke();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => write);
    }

    private sealed class CancellationBlockedStream : Stream
    {
        public override bool CanRead => false;
        public override bool CanSeek => false;
        public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() => throw new NotSupportedException();
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default) => new(Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken));
        public override Task FlushAsync(CancellationToken cancellationToken) => Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
    }

    private sealed record UserSession(UserReply User, HttpClient Client, AuthReply Auth);
    private sealed record RequestIds(Guid RequestId, Guid JobId);

    private sealed class QueryFixture : IAsyncDisposable
    {
        private readonly TestHost host;
        public HttpClient AdminClient { get; }
        public AuthReply Admin { get; }
        public Guid LibraryId { get; }
        public void Advance(TimeSpan amount) => host.Clock.Advance(amount);

        private QueryFixture(TestHost host, HttpClient client, AuthReply admin, Guid libraryId)
        { this.host = host; AdminClient = client; Admin = admin; LibraryId = libraryId; }

        public static async Task<QueryFixture> Create()
        {
            var host = new TestHost();
            var client = host.CreateClient();
            var password = "Download-Query-" + Briani.Api.Infrastructure.Security.Credentials.NewToken();
            var admin = await IdentityFixture.Bootstrap(client, host.BootstrapCode(), "downloadadmin", "Download Admin", password);
            IdentityFixture.As(client, admin.AccessToken);
            var libraryId = Guid.NewGuid();
            await host.InDb(async db =>
            {
                db.Libraries.Add(new Library { Id = libraryId, Name = "Downloads", RootPath = "downloads", RootIdentity = "download-root", CreatedAt = host.Clock.GetUtcNow() });
                await db.SaveChangesAsync();
                return 0;
            });
            return new QueryFixture(host, client, admin, libraryId);
        }

        public async Task<UserSession> CreateUser(string username, string role)
        {
            var password = "Download-User-" + Briani.Api.Infrastructure.Security.Credentials.NewToken();
            using var created = await AdminClient.PostAsJsonAsync("/api/v1/admin/users", new
            { username, displayName = username, password, confirmPassword = password, role });
            created.EnsureSuccessStatusCode();
            var user = await created.Content.ReadFromJsonAsync<UserReply>() ?? throw new InvalidOperationException("Missing created user.");
            using var login = await AdminClient.PostAsJsonAsync("/api/v1/auth/login", new { username, password, deviceName = "query-test" });
            login.EnsureSuccessStatusCode();
            var auth = await login.Content.ReadFromJsonAsync<AuthReply>() ?? throw new InvalidOperationException("Missing login response.");
            var client = host.CreateClient();
            IdentityFixture.As(client, auth.AccessToken);
            return new UserSession(user, client, auth);
        }

        public Task<int> Grant(Guid userId, bool canRead, bool canDownload, bool canManage) => host.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = userId, LibraryId = LibraryId, CanRead = canRead, CanDownload = canDownload, CanManage = canManage });
            return await db.SaveChangesAsync();
        });

        public Task<int> Revoke(Guid userId) => host.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == userId && x.LibraryId == LibraryId);
            db.LibraryGrants.Remove(grant);
            return await db.SaveChangesAsync();
        });

        public Task<int> ChangeDownloadRate(Guid jobId, long rate) => host.InDb(async db =>
        {
            var job = await db.TorrentJobs.SingleAsync(x => x.Id == jobId);
            job.DownloadBps = rate;
            job.UpdatedAt = host.Clock.GetUtcNow().AddSeconds(1);
            return await db.SaveChangesAsync();
        });

        public async Task<RequestIds> SeedRequest(Guid ownerId, Guid ownerSessionId, string state, bool includeFiles = false)
        {
            var now = host.Clock.GetUtcNow();
            var requestId = Guid.NewGuid(); var jobId = Guid.NewGuid();
            await host.InDb(async db =>
            {
                var job = new TorrentJob
                {
                    Id = jobId, LibraryId = LibraryId, ManagedPath = "/private/staging/not-for-api",
                    Name = "Fixture torrent", TotalBytes = 1000, DownloadedBytes = 700, UploadedBytes = 20,
                    DownloadBps = 30, UploadBps = 4, SeedersConnected = 2, PeersConnected = 6, EtaSeconds = 20,
                    Sequential = true, MetadataAssist = false, Generation = 7, EngineState = state == "downloading" ? "downloadingDL" : state,
                    ImportState = "pending", SettingsVersion = 3,
                    SettingsJson = JsonSerializer.Serialize(new DownloadSettings(3, 123_000, 456_000, 0.75, 60, 4, ["fixture", "bad\nlabel"])),
                    TagsJson = "[\"fixture\",\"bad\\nlabel\"]", CreatedAt = now, UpdatedAt = now
                };
                db.TorrentJobs.Add(job);
                db.DownloadRequests.Add(new DownloadRequest
                {
                    Id = requestId, OwnerId = ownerId, AuthSessionId = ownerSessionId, LibraryId = LibraryId,
                    TorrentJobId = jobId, SourceKind = "magnet", SourceDigest = "digest", EncryptedSourceReference = "must-not-leak",
                    State = state, SourceState = "ready", SelectedBytes = 9999, CreatedAt = now, UpdatedAt = now, Version = 2
                });
                if (includeFiles)
                {
                    var video = new DownloadFile { TorrentJobId = jobId, UpstreamFileIndex = 0, MetadataFileIndex = 0, RelativePath = "folder/episode.mkv", DisplayName = "episode.mkv", SizeBytes = 800, DownloadedBytes = 400, ContiguousBytes = 300, Kind = "video", PlaybackState = "eligible", Version = 4 };
                    var subtitle = new DownloadFile { TorrentJobId = jobId, UpstreamFileIndex = 1, MetadataFileIndex = 1, RelativePath = "C:\\private\\episode.srt", DisplayName = "subtitle.srt", SizeBytes = 100, DownloadedBytes = 80, ContiguousBytes = 60, Kind = "subtitle", PlaybackState = "waitingForData" };
                    var unwanted = new DownloadFile { TorrentJobId = jobId, UpstreamFileIndex = 2, MetadataFileIndex = 2, RelativePath = "other.mkv", DisplayName = "other.mkv", SizeBytes = 1000, DownloadedBytes = 50, ContiguousBytes = 20, Kind = "video", PlaybackState = "notSelected" };
                    var padding = new DownloadFile { TorrentJobId = jobId, UpstreamFileIndex = 3, MetadataFileIndex = 3, RelativePath = "padding.bin", DisplayName = "padding.bin", SizeBytes = 20, Padding = true, Kind = "other" };
                    db.DownloadFiles.AddRange(video, subtitle, unwanted, padding);
                    await db.SaveChangesAsync();
                    db.DownloadRequestFiles.AddRange(
                        new DownloadRequestFile { DownloadRequestId = requestId, DownloadFileId = video.Id, Selected = true, Priority = 6 },
                        new DownloadRequestFile { DownloadRequestId = requestId, DownloadFileId = subtitle.Id, Selected = true, Priority = 7 },
                        new DownloadRequestFile { DownloadRequestId = requestId, DownloadFileId = unwanted.Id, Selected = false, Priority = 1 },
                        new DownloadRequestFile { DownloadRequestId = requestId, DownloadFileId = padding.Id, Selected = true, Priority = 7 });
                }
                await db.SaveChangesAsync();
                return 0;
            });
            return new RequestIds(requestId, jobId);
        }

        public ValueTask DisposeAsync()
        {
            AdminClient.Dispose(); host.Dispose();
            return ValueTask.CompletedTask;
        }
    }
}
