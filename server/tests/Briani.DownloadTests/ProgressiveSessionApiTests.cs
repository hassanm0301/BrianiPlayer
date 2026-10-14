using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Modules.Playback;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class ProgressiveSessionApiTests
{
    [Fact]
    public async Task Pending_session_issues_ticket_only_after_verified_prefix_and_stores_only_ticket_hash()
    {
        await using var fixture = await ReadyFixture(completePieces: false);
        var pending = await CreateSession(fixture);
        Assert.Null(pending.StreamUrl);
        Assert.Equal("buffering", pending.State);
        Assert.False(await fixture.InDb(db => db.PlaybackSessions.AsNoTracking().Where(x => x.Id == pending.Id).Select(x => x.TicketIssued).SingleAsync()));

        fixture.Engine.CompletePieces = true;
        fixture.Clock.Advance(TimeSpan.FromSeconds(1));
        var ready = await Status(fixture, pending.Id);
        Assert.Equal("complete", ready.State);
        Assert.NotNull(ready.StreamUrl);
        var ticket = Ticket(ready.StreamUrl);
        var hash = Credentials.Hash(ticket);
        var stored = await fixture.InDb(db => db.PlaybackSessions.AsNoTracking().Where(x => x.Id == pending.Id).Select(x => x.TicketHash).SingleAsync());
        Assert.Equal(hash, stored);
        Assert.NotEqual(ticket, stored);
    }

    [Fact]
    public async Task Ticket_stream_obeys_ranges_head_multirange_and_rejects_wrong_name_and_invalid_ranges()
    {
        await using var fixture = await ReadyFixture();
        var session = await CreateSession(fixture);
        Assert.NotNull(session.StreamUrl);
        var expected = Enumerable.Range(0, (int)LifecycleFixture.FileBytes).Select(i => (byte)(i % 251)).ToArray();

        using (var closed = await SendStream(fixture, session.StreamUrl!, "bytes=10-20"))
        {
            Assert.Equal(HttpStatusCode.PartialContent, closed.StatusCode);
            Assert.Equal(expected[10..21], await closed.Content.ReadAsByteArrayAsync());
            Assert.Equal("bytes 10-20/65536", closed.Content.Headers.ContentRange?.ToString());
        }
        using (var full = await SendStream(fixture, session.StreamUrl!, null))
        {
            Assert.Equal(HttpStatusCode.OK, full.StatusCode);
            Assert.Equal(expected, await full.Content.ReadAsByteArrayAsync());
        }
        using (var open = await SendStream(fixture, session.StreamUrl!, "bytes=65530-"))
            Assert.Equal(expected[65530..], await open.Content.ReadAsByteArrayAsync());
        using (var suffix = await SendStream(fixture, session.StreamUrl!, "bytes=-11"))
            Assert.Equal(expected[^11..], await suffix.Content.ReadAsByteArrayAsync());
        using (var multiple = await SendStream(fixture, session.StreamUrl!, "bytes=0-1,4-5"))
        {
            Assert.Equal(HttpStatusCode.OK, multiple.StatusCode);
            Assert.Equal(expected, await multiple.Content.ReadAsByteArrayAsync());
        }
        using (var head = await SendStream(fixture, session.StreamUrl!, "bytes=0-1", HttpMethod.Head))
        {
            Assert.Equal(HttpStatusCode.OK, head.StatusCode);
            Assert.Equal(LifecycleFixture.FileBytes, head.Content.Headers.ContentLength);
            Assert.Empty(await head.Content.ReadAsByteArrayAsync());
        }
        using (var ifRange = await SendStream(fixture, session.StreamUrl!, "bytes=0-1", ifRange: "\"old-generation\""))
        {
            Assert.Equal(HttpStatusCode.OK, ifRange.StatusCode);
            Assert.Equal(expected, await ifRange.Content.ReadAsByteArrayAsync());
        }
        using (var unsatisfiable = await SendStream(fixture, session.StreamUrl!, "bytes=65536-"))
            Assert.Equal(HttpStatusCode.RequestedRangeNotSatisfiable, unsatisfiable.StatusCode);
        using (var malformed = await SendStream(fixture, session.StreamUrl!, "bytes=+1-2"))
            Assert.Equal(HttpStatusCode.BadRequest, malformed.StatusCode);
        var wrongName = ReplaceName(session.StreamUrl!, "wrong.mp4");
        using (var wrong = await fixture.Client.GetAsync(wrongName)) Assert.Equal(HttpStatusCode.NotFound, wrong.StatusCode);
    }

    [Fact]
    public async Task Playback_session_is_owner_scoped_revocable_and_long_movie_ticket_survives_activation_window()
    {
        await using var fixture = await ReadyFixture();
        var session = await CreateSession(fixture);
        Assert.NotNull(session.StreamUrl);
        using (var first = await SendStream(fixture, session.StreamUrl!, "bytes=0-9"))
            Assert.Equal(HttpStatusCode.PartialContent, first.StatusCode);

        var other = await fixture.CreateUser("playbackother");
        using (var foreign = await other.Client.GetAsync($"/api/v1/playback/sessions/{session.Id}"))
            Assert.Equal(HttpStatusCode.NotFound, foreign.StatusCode);

        fixture.Clock.Advance(TimeSpan.FromMinutes(20));
        using (var reopened = await SendStream(fixture, session.StreamUrl!, "bytes=10-19"))
        {
            Assert.Equal(HttpStatusCode.PartialContent, reopened.StatusCode);
            Assert.Equal(Enumerable.Range(10, 10).Select(i => (byte)(i % 251)), await reopened.Content.ReadAsByteArrayAsync());
        }

        fixture.Clock.Advance(TimeSpan.FromMinutes(31));
        using (var refreshed = await fixture.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = fixture.Admin.RefreshToken }))
        {
            Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
            var auth = (await refreshed.Content.ReadFromJsonAsync<AuthReply>())!;
            IdentityFixture.As(fixture.Client, auth.AccessToken);
        }
        var idleExpired = await Status(fixture, session.Id);
        Assert.Equal("expired", idleExpired.State);
        using (var expired = await fixture.Client.GetAsync(session.StreamUrl))
            Assert.Equal(HttpStatusCode.NotFound, expired.StatusCode);

        var revocable = await CreateSession(fixture);
        Assert.NotNull(revocable.StreamUrl);
        using (var revoke = await fixture.Client.DeleteAsync($"/api/v1/playback/sessions/{revocable.Id}"))
            Assert.Equal(HttpStatusCode.NoContent, revoke.StatusCode);
        using var denied = await fixture.Client.GetAsync(revocable.StreamUrl);
        Assert.Equal(HttpStatusCode.NotFound, denied.StatusCode);
    }

    [Fact]
    public async Task Missing_first_piece_times_out_with_retryable_response_and_active_reader_blocks_selection_without_mutation()
    {
        await using var fixture = await ReadyFixture();
        var session = await CreateSession(fixture);
        Assert.NotNull(session.StreamUrl);
        await fixture.InDb(async db =>
        {
            var file = await db.DownloadFiles.SingleAsync(x => x.Id == fixture.Engine.FileId);
            file.FilePriority = 6;
            var choice = await db.DownloadRequestFiles.SingleAsync(x => x.DownloadFileId == file.Id);
            choice.Priority = 6;
            await db.SaveChangesAsync();
            return 0;
        });
        fixture.Engine.ConfigureFiles(4, new EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 6, 0, 3));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
        fixture.Engine.CompletePieces = false;
        fixture.Clock.Advance(TimeSpan.FromSeconds(1));
        using (var scope = fixture.Services.CreateScope())
        {
            var playback = scope.ServiceProvider.GetRequiredService<ProgressivePlayback>();
            playback.FirstByteTimeout = TimeSpan.FromMilliseconds(100);
            var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
            context.Request.Method = "GET";
            context.Request.Headers.Range = "bytes=0-10";
            context.Request.Scheme = "http";
            context.Request.Host = new HostString("localhost");
            context.Response.Body = new MemoryStream();
            var ticket = Ticket(session.StreamUrl!);
            var name = Uri.UnescapeDataString(new Uri(session.StreamUrl!).AbsolutePath.Split('/')[3]);
            var error = await Assert.ThrowsAsync<ApiException>(() => playback.StreamAsync(ticket, name, context));
            Assert.Equal(503, error.Status);
        }

        var lease = fixture.Services.GetRequiredService<MediaReaders>().Acquire(Guid.NewGuid(), fixture.Engine.FileId, CancellationToken.None);
        using (lease)
        {
            var baseline = await fixture.InDb(async db =>
            {
                var request = await db.DownloadRequests.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.RequestId);
                var job = await db.TorrentJobs.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.JobId);
                return (request.Version, job.Generation);
            });
            using var conflict = await fixture.Client.PutAsJsonAsync($"/api/v1/downloads/{fixture.Engine.RequestId}/selection", new
            {
                files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "maximum" } },
                autoStart = true,
                version = baseline.Version
            });
            Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
            Assert.Contains("active_reader_conflict", await conflict.Content.ReadAsStringAsync(), StringComparison.Ordinal);
            Assert.False(lease.Token.IsCancellationRequested);
            Assert.Equal(baseline, await fixture.InDb(async db =>
            {
                var request = await db.DownloadRequests.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.RequestId);
                var job = await db.TorrentJobs.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.JobId);
                return (request.Version, job.Generation);
            }));
            Assert.Equal(0, await fixture.InDb(db => db.Operations.CountAsync(x => x.TargetId == fixture.Engine.RequestId)));
        }
    }

    [Fact]
    public async Task Pause_resume_keeps_the_same_playback_ticket_and_availability_generation_healthy()
    {
        await using var fixture = await ReadyFixture();
        var session = await CreateSession(fixture);
        Assert.NotNull(session.StreamUrl);
        var availability = fixture.Services.GetRequiredService<TorrentAvailability>();
        using var subscription = availability.Subscribe(fixture.Engine.JobId);
        await availability.RefreshAsync(subscription.Source, CancellationToken.None);
        var initial = subscription.Source.Current;
        Assert.NotNull(initial);
        Assert.True(initial.Healthy);

        var download = await GetDownload(fixture);
        using (var pause = await SubmitAction(fixture, download.Id, download.Version, "pause", "playback-pause"))
            Assert.Equal(HttpStatusCode.Accepted, pause.StatusCode);
        // A pending pause is safe: it must not invalidate the current piece snapshot.
        await availability.RefreshAsync(subscription.Source, CancellationToken.None);
        var duringPause = subscription.Source.Current;
        Assert.NotNull(duringPause);
        Assert.True(duringPause.Healthy);
        Assert.Equal(initial.Generation, duringPause.Generation);

        Assert.True(await fixture.Worker.RunOnceAsync());
        using (var pausedRange = await SendStream(fixture, session.StreamUrl!, "bytes=100-109"))
        {
            Assert.Equal(HttpStatusCode.PartialContent, pausedRange.StatusCode);
            Assert.Equal(Enumerable.Range(100, 10).Select(i => (byte)(i % 251)), await pausedRange.Content.ReadAsByteArrayAsync());
        }

        download = await GetDownload(fixture);
        using (var resume = await SubmitAction(fixture, download.Id, download.Version, "resume", "playback-resume"))
            Assert.Equal(HttpStatusCode.Accepted, resume.StatusCode);
        Assert.True(await fixture.Worker.RunOnceAsync());
        using var resumedRange = await SendStream(fixture, session.StreamUrl!, "bytes=200-209");
        Assert.Equal(HttpStatusCode.PartialContent, resumedRange.StatusCode);
        Assert.Equal(Enumerable.Range(200, 10).Select(i => (byte)(i % 251)), await resumedRange.Content.ReadAsByteArrayAsync());
        Assert.Equal(initial.Generation, subscription.Source.Current!.Generation);
    }

    [Fact]
    public async Task Compatible_shared_selection_preserves_active_owner_ticket_while_operation_waits()
    {
        await using var fixture = await ReadyFixture();
        var session = await CreateSession(fixture);
        Assert.NotNull(session.StreamUrl);
        var availability = fixture.Services.GetRequiredService<TorrentAvailability>();
        using var subscription = availability.Subscribe(fixture.Engine.JobId);
        await availability.RefreshAsync(subscription.Source, CancellationToken.None);
        var initial = subscription.Source.Current;
        Assert.NotNull(initial);
        Assert.True(initial.Healthy);

        var contributor = await fixture.CreateUser("playbackcontributor");
        await fixture.Grant(contributor.User.Id);
        var attached = await fixture.CreateDownload(contributor.Client, fixture.LibraryId);
        using (var selection = await contributor.Client.PutAsJsonAsync($"/api/v1/downloads/{attached.Id}/selection", new
        {
            files = new[] { new { fileId = fixture.Engine.FileId, selected = true, priority = "normal" } },
            autoStart = false,
            version = attached.Version
        }))
            Assert.Equal(HttpStatusCode.Accepted, selection.StatusCode);

        var invalidatesPlayback = await fixture.InDb(db => db.Operations.AsNoTracking()
            .Where(x => x.TargetId == attached.Id && x.Kind == "download-select")
            .Select(x => x.InvalidatesPlayback).SingleAsync());
        Assert.False(invalidatesPlayback);
        await Task.Delay(TimeSpan.FromMilliseconds(650));
        await availability.RefreshAsync(subscription.Source, CancellationToken.None);
        var pending = subscription.Source.Current;
        Assert.NotNull(pending);
        Assert.True(pending.Healthy);
        Assert.Equal(initial.Generation, pending.Generation);
        Assert.False(fixture.Services.GetRequiredService<MediaReaders>().HasReaders(fixture.Engine.FileId));

        using (var whilePending = await SendStream(fixture, session.StreamUrl!, "bytes=300-309"))
        {
            Assert.Equal(HttpStatusCode.PartialContent, whilePending.StatusCode);
            Assert.Equal(Enumerable.Range(300, 10).Select(i => (byte)(i % 251)), await whilePending.Content.ReadAsByteArrayAsync());
        }
        Assert.True(await fixture.Worker.RunOnceAsync());
        using var afterWorker = await SendStream(fixture, session.StreamUrl!, "bytes=400-409");
        Assert.Equal(HttpStatusCode.PartialContent, afterWorker.StatusCode);
        Assert.Equal(Enumerable.Range(400, 10).Select(i => (byte)(i % 251)), await afterWorker.Content.ReadAsByteArrayAsync());
        Assert.Equal(initial.Generation, subscription.Source.Current!.Generation);
    }

    [Fact]
    public async Task Retry_rejects_active_reader_then_fences_ticket_and_clears_completed_before_worker_effect()
    {
        await using var fixture = await ReadyFixture();
        var session = await CreateSession(fixture);
        Assert.NotNull(session.StreamUrl);
        var before = await GetDownload(fixture);
        var generationBefore = await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.Id == fixture.Engine.JobId).Select(x => x.Generation).SingleAsync());

        using (var lease = fixture.Services.GetRequiredService<MediaReaders>().Acquire(Guid.NewGuid(), fixture.Engine.FileId, CancellationToken.None))
        {
            using var rejected = await SubmitAction(fixture, before.Id, before.Version, "retry", "retry-reader-conflict");
            Assert.Equal(HttpStatusCode.Conflict, rejected.StatusCode);
            Assert.Contains("active_reader_conflict", await rejected.Content.ReadAsStringAsync(), StringComparison.Ordinal);
            Assert.False(lease.Token.IsCancellationRequested);
            Assert.Equal(generationBefore, await fixture.InDb(db => db.TorrentJobs.AsNoTracking().Where(x => x.Id == fixture.Engine.JobId).Select(x => x.Generation).SingleAsync()));
            Assert.True(await fixture.InDb(db => db.DownloadFiles.AsNoTracking().Where(x => x.Id == fixture.Engine.FileId).Select(x => x.Completed).SingleAsync()));
        }

        using (var accepted = await SubmitAction(fixture, before.Id, before.Version, "retry", "retry-after-reader-release"))
            Assert.Equal(HttpStatusCode.Accepted, accepted.StatusCode);
        Assert.True(await fixture.InDb(db => db.Operations.AsNoTracking()
            .Where(x => x.TargetId == before.Id && x.Kind == "download-retry")
            .Select(x => x.InvalidatesPlayback).SingleAsync()));
        var fenced = await fixture.InDb(async db =>
        {
            var job = await db.TorrentJobs.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.JobId);
            var file = await db.DownloadFiles.AsNoTracking().SingleAsync(x => x.Id == fixture.Engine.FileId);
            return (job.Generation, file.Completed, file.PlaybackState);
        });
        Assert.Equal(generationBefore + 1, fenced.Generation);
        Assert.False(fenced.Completed);
        Assert.Equal("unavailable", fenced.PlaybackState);
        using var oldTicket = await fixture.Client.GetAsync(session.StreamUrl);
        Assert.Equal(HttpStatusCode.Conflict, oldTicket.StatusCode);
    }

    private static async Task<LifecycleFixture> ReadyFixture(bool completePieces = true)
    {
        var fixture = await LifecycleFixture.Create();
        try
        {
            fixture.Engine.CompletePieces = completePieces;
            await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
            fixture.Engine.ConfigureFiles(4, new EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3));
            fixture.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N")));
            return fixture;
        }
        catch { await fixture.DisposeAsync(); throw; }
    }

    private static async Task<PlaybackSessionView> CreateSession(LifecycleFixture fixture)
    {
        using var response = await fixture.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "downloadFile", id = fixture.Engine.FileId }, mode = "internal", initialPositionMs = 0
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
    }

    private static async Task<PlaybackSessionView> Status(LifecycleFixture fixture, Guid id)
    {
        using var response = await fixture.Client.GetAsync($"/api/v1/playback/sessions/{id}");
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
    }

    private static async Task<DownloadView> GetDownload(LifecycleFixture fixture)
    {
        using var response = await fixture.Client.GetAsync($"/api/v1/downloads/{fixture.Engine.RequestId}");
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<DownloadView>())!;
    }

    private static Task<HttpResponseMessage> SubmitAction(LifecycleFixture fixture, Guid id, long version, string action, string key)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/downloads/{id}/actions")
        { Content = JsonContent.Create(new { action, version }) };
        request.Headers.Add("Idempotency-Key", key);
        return fixture.Client.SendAsync(request);
    }

    private static async Task<HttpResponseMessage> SendStream(LifecycleFixture fixture, string url, string? range, HttpMethod? method = null, string? ifRange = null)
    {
        using var request = new HttpRequestMessage(method ?? HttpMethod.Get, url);
        if (range is not null)
        {
            if (range.Contains('+') || range.Any(char.IsLetter)) request.Headers.TryAddWithoutValidation("Range", range);
            else request.Headers.Range = RangeHeaderValue.Parse(range);
        }
        if (ifRange is not null) request.Headers.TryAddWithoutValidation("If-Range", ifRange);
        return await fixture.Client.SendAsync(request);
    }

    private static string Ticket(string streamUrl) => new Uri(streamUrl).AbsolutePath.Split('/')[2];
    private static string ReplaceName(string streamUrl, string name)
    {
        var uri = new Uri(streamUrl);
        return $"{uri.GetLeftPart(UriPartial.Authority)}/stream/{Ticket(streamUrl)}/{Uri.EscapeDataString(name)}";
    }
}
