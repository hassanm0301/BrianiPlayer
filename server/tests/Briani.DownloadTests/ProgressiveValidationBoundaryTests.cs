using System.Net;
using System.Net.Http.Json;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Playback;
using Briani.Api.Infrastructure.Security;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class ProgressiveValidationBoundaryTests
{
    [Theory]
    [InlineData("null")]
    [InlineData("kind")]
    [InlineData("mode")]
    [InlineData("position")]
    public async Task Service_boundary_rejects_malformed_create_before_persisting_authority(string invalid)
    {
        await using var f = await Ready();
        using var scope = f.Services.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<ProgressivePlayback>();
        var request = new PlaybackCreate(
            invalid == "null" ? null! : new PlaybackTarget(invalid == "kind" ? "arbitraryPath" : "downloadFile", f.Engine.FileId),
            invalid == "mode" ? "unsupported" : "internal", invalid == "position" ? -1 : 0);
        var error = await Assert.ThrowsAsync<ApiException>(() => service.CreateAsync(
            new(f.Admin.User.Id, f.Admin.SessionId, "admin"), request, new DefaultHttpContext()));
        Assert.Equal("invalid_playback_target", error.Code);
        Assert.Equal(0, await f.InDb(db => db.PlaybackSessions.CountAsync()));
    }
    [Theory]
    [InlineData("unwanted", "generation_changed")]
    [InlineData("retired", "generation_changed")]
    [InlineData("removed", "generation_changed")]
    [InlineData("removing", "generation_changed")]
    [InlineData("metadata", "metadata_pending")]
    [InlineData("piece-zero", "metadata_pending")]
    [InlineData("piece-too-large", "metadata_pending")]
    [InlineData("piece-negative-count", "metadata_pending")]
    [InlineData("file-zero", "metadata_pending")]
    [InlineData("negative-offset", "layout_unverified")]
    [InlineData("outside-torrent", "layout_unverified")]
    [InlineData("first-piece", "layout_unverified")]
    [InlineData("last-piece", "layout_unverified")]
    public async Task Invalid_live_target_never_creates_a_ticket_or_session(string mutation, string code)
    {
        await using var f = await Ready();
        await f.InDb(async db =>
        {
            var file = await db.DownloadFiles.SingleAsync(x => x.Id == f.Engine.FileId);
            var job = await db.TorrentJobs.SingleAsync(x => x.Id == f.Engine.JobId);
            switch (mutation)
            {
                case "unwanted": file.Wanted = false; break;
                case "retired": job.RetiredAt = f.Clock.GetUtcNow(); break;
                case "removed": job.PayloadRemoved = true; break;
                case "removing": job.DesiredState = "removing"; break;
                case "metadata": job.MetadataStatus = "pending"; break;
                case "piece-zero": job.PieceLength = 0; break;
                case "piece-too-large": job.PieceLength = 67108865; break;
                case "piece-negative-count": job.PieceCount = -1; break;
                case "file-zero": file.SizeBytes = 0; break;
                case "negative-offset": file.TorrentOffset = -1; break;
                case "outside-torrent": file.SizeBytes = (long)job.PieceCount * job.PieceLength + 1; break;
                case "first-piece": file.PieceFirst++; break;
                case "last-piece": file.PieceLast++; break;
            }
            await db.SaveChangesAsync();
            return 0;
        });
        using var response = await Create(f, "boundary-" + mutation);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        Assert.Contains(code, await response.Content.ReadAsStringAsync());
        Assert.Equal(0, await f.InDb(db => db.PlaybackSessions.CountAsync()));
        Assert.Equal(0, await f.InDb(db => db.Operations.CountAsync(x => x.Kind == "playback-create")));
    }

    [Fact]
    public async Task Retry_is_stable_but_changed_request_auth_or_generation_cannot_reissue_a_ticket()
    {
        await using var f = await Ready();
        using var initial = await Create(f, "stable-create");
        Assert.Equal(HttpStatusCode.Created, initial.StatusCode);
        var session = (await initial.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
        Assert.NotNull(session.StreamUrl);
        using var retry = await Create(f, "stable-create");
        Assert.Equal(HttpStatusCode.Created, retry.StatusCode);
        var repeated = (await retry.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
        Assert.Equal(session.Id, repeated.Id);
        Assert.Null(repeated.StreamUrl);
        Assert.Equal(1, await f.InDb(db => db.PlaybackSessions.CountAsync()));
        using var changed = await Create(f, "stable-create", mode: "external");
        Assert.Equal(HttpStatusCode.Conflict, changed.StatusCode);
        Assert.Contains("idempotency_conflict", await changed.Content.ReadAsStringAsync());
        await f.InDb(async db =>
        {
            var live = await db.PlaybackSessions.SingleAsync(x => x.Id == session.Id);
            live.TargetGeneration = "obsolete";
            await db.SaveChangesAsync();
            return 0;
        });
        using var fenced = await Create(f, "stable-create");
        var fencedView = (await fenced.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
        Assert.Equal("unavailable", fencedView.State);
        Assert.Null(fencedView.StreamUrl);
        await f.InDb(async db =>
        {
            (await db.PlaybackSessions.SingleAsync(x => x.Id == session.Id)).RevokedAt = f.Clock.GetUtcNow();
            await db.SaveChangesAsync(); return 0;
        });
        using var revoked = await Create(f, "stable-create");
        var revokedView = (await revoked.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
        Assert.Equal("revoked", revokedView.State);
        Assert.Null(revokedView.StreamUrl);
        await f.InDb(async db =>
        {
            var live = await db.PlaybackSessions.SingleAsync(x => x.Id == session.Id);
            live.RevokedAt = null; live.AbsoluteExpiresAt = f.Clock.GetUtcNow();
            await db.SaveChangesAsync(); return 0;
        });
        using var expired = await Create(f, "stable-create");
        var expiredView = (await expired.Content.ReadFromJsonAsync<PlaybackSessionView>())!;
        Assert.Equal("expired", expiredView.State);
        Assert.Null(expiredView.StreamUrl);
        var other = await f.CreateUser("another-owner");
        using var otherClient = other.Client;
        await f.InDb(async db =>
        {
            (await db.PlaybackSessions.SingleAsync(x => x.Id == session.Id)).AuthSessionId = other.Auth.SessionId;
            await db.SaveChangesAsync();
            return 0;
        });
        using var wrongAuth = await Create(f, "stable-create");
        Assert.Equal(HttpStatusCode.Conflict, wrongAuth.StatusCode);
        Assert.Contains("idempotency_session_changed", await wrongAuth.Content.ReadAsStringAsync());
    }

    private static Task<HttpResponseMessage> Create(LifecycleFixture f, string key, string mode = "internal")
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/playback/sessions")
        { Content = JsonContent.Create(new { target = new { kind = "downloadFile", id = f.Engine.FileId }, mode, initialPositionMs = 0 }) };
        request.Headers.Add("Idempotency-Key", key);
        return f.Client.SendAsync(request);
    }

    private static async Task<LifecycleFixture> Ready()
    {
        var f = await LifecycleFixture.Create();
        try
        {
            await f.SeedReadyDownload(f.Admin.User.Id, f.Admin.SessionId);
            f.Engine.ConfigureFiles(4, new EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3));
            f.Engine.RegisterExisting(LifecycleFixture.Hash, Path.Combine(f.LibraryPath, ".briani", "staging", f.Engine.JobId.ToString("N")));
            return f;
        }
        catch { await f.DisposeAsync(); throw; }
    }
}
