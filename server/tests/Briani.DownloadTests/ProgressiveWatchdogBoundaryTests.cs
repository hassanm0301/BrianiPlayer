using System.Net;
using System.Net.Http.Json;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Playback;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DownloadTests;

public sealed class ProgressiveWatchdogBoundaryTests
{
    [Theory]
    [InlineData("session-revoked")] [InlineData("session-expired")] [InlineData("session-generation")]
    [InlineData("ticket-replaced")] [InlineData("user-disabled")] [InlineData("password-change")]
    [InlineData("auth-revoked")] [InlineData("grant-revoked")] [InlineData("job-generation")]
    [InlineData("file-identity")] [InlineData("file-size")] [InlineData("path-replaced")]
    [InlineData("descriptor-grown")] [InlineData("source-recheck")]
    public async Task Open_progressive_stream_aborts_when_live_binding_changes(string change)
    {
        await using var fixture = await LifecycleFixture.Create();
        var user = await fixture.CreateUser("watchdogreader"); using var member = user.Client;
        await fixture.Grant(user.User.Id);
        await fixture.SeedReadyDownload(user.User.Id, user.Auth.SessionId);
        fixture.Engine.ConfigureFiles(4, new EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3));
        var stage = Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, stage);
        using var created = await member.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "downloadFile", id = fixture.Engine.FileId }, mode = "internal" });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var session = (await created.Content.ReadFromJsonAsync<PlaybackSessionView>())!; Assert.NotNull(session.StreamUrl);
        using var scope = fixture.Services.CreateScope();
        var response = new BlockedResponse(); var lifetime = new RequestLifetime();
        var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider };
        context.Features.Set<IHttpRequestLifetimeFeature>(lifetime); context.Request.Method = "GET"; context.Request.Host = new HostString("localhost"); context.Response.Body = response;
        var playback = scope.ServiceProvider.GetRequiredService<ProgressivePlayback>();
        var ticket = new Uri(session.StreamUrl!).AbsolutePath.Split('/')[2];
        var running = playback.StreamAsync(ticket, "fixture.mp4", context);
        try
        {
            await response.Blocked.WaitAsync(TimeSpan.FromSeconds(3));
            Assert.Equal(Enumerable.Range(0, 16384).Select(i => (byte)(i % 251)), response.FirstBytes);
            Assert.True(fixture.Services.GetRequiredService<MediaReaders>().HasReaders(fixture.Engine.FileId));
            if (change == "session-revoked")
            {
                // Let one healthy watchdog tick persist activity before revocation.
                fixture.Clock.Advance(TimeSpan.FromSeconds(16));
                using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(3));
                while (await fixture.InDb(db => db.PlaybackSessions.AsNoTracking().Where(s => s.Id == session.Id).Select(s => s.LastActivityAt).SingleAsync(deadline.Token)) != fixture.Clock.GetUtcNow())
                    await Task.Delay(20, deadline.Token);
                Assert.False(lifetime.Aborted); Assert.Equal(1, response.WriteCount);
            }
            if (change == "path-replaced")
            {
                File.Move(Path.Combine(stage, "fixture.mp4"), Path.Combine(stage, "retained-original"));
                await File.WriteAllBytesAsync(Path.Combine(stage, "fixture.mp4"), new byte[LifecycleFixture.FileBytes]);
            }
            else if (change == "descriptor-grown")
            {
                using var append = new FileStream(Path.Combine(stage, "fixture.mp4"), FileMode.Append, FileAccess.Write, FileShare.ReadWrite);
                append.WriteByte(42); append.Flush(true);
            }
            else if (change == "source-recheck")
            {
                fixture.Engine.RegisterExisting(LifecycleFixture.Hash, stage, "checkingDL"); fixture.Clock.Advance(TimeSpan.FromSeconds(1));
                var availability = fixture.Services.GetRequiredService<TorrentAvailability>(); using var subscription = availability.Subscribe(fixture.Engine.JobId);
                await availability.RefreshAsync(subscription.Source, CancellationToken.None);
            }
            else await fixture.InDb(async db =>
            {
                var live = await db.PlaybackSessions.SingleAsync(s => s.Id == session.Id);
                switch (change)
                {
                    case "session-revoked": live.RevokedAt = fixture.Clock.GetUtcNow(); break;
                    case "session-expired": live.AbsoluteExpiresAt = fixture.Clock.GetUtcNow(); break;
                    case "session-generation": live.TargetGeneration = "changed"; break;
                    case "ticket-replaced": live.TicketHash = Credentials.Hash("replacement"); break;
                    case "user-disabled": (await db.Users.SingleAsync(u => u.Id == user.User.Id)).Enabled = false; break;
                    case "password-change": (await db.Users.SingleAsync(u => u.Id == user.User.Id)).MustChangePassword = true; break;
                    case "auth-revoked": (await db.AuthSessions.SingleAsync(s => s.Id == user.Auth.SessionId)).RevokedAt = fixture.Clock.GetUtcNow(); break;
                    case "grant-revoked": (await db.LibraryGrants.SingleAsync(g => g.UserId == user.User.Id)).CanRead = false; break;
                    case "job-generation": (await db.TorrentJobs.SingleAsync(j => j.Id == fixture.Engine.JobId)).Generation++; break;
                    case "file-identity": (await db.DownloadFiles.SingleAsync(f => f.Id == fixture.Engine.FileId)).FileIdentity = "changed"; break;
                    case "file-size": (await db.DownloadFiles.SingleAsync(f => f.Id == fixture.Engine.FileId)).SizeBytes--; break;
                }
                return await db.SaveChangesAsync();
            });
            await running.WaitAsync(TimeSpan.FromSeconds(4));
            Assert.True(lifetime.Aborted); Assert.True(response.Cancelled); Assert.Equal(1, response.WriteCount);
            Assert.False(fixture.Services.GetRequiredService<MediaReaders>().HasReaders(fixture.Engine.FileId));
        }
        finally { lifetime.Abort(); await running.WaitAsync(TimeSpan.FromSeconds(3)); }
    }

    private sealed class BlockedResponse : Stream
    {
        private readonly TaskCompletionSource blocked = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task Blocked => blocked.Task;
        public byte[] FirstBytes { get; private set; } = [];
        public int WriteCount { get; private set; }
        public bool Cancelled { get; private set; }
        public override async ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default)
        {
            WriteCount++; FirstBytes = buffer.ToArray(); blocked.TrySetResult();
            try { await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); } catch (OperationCanceledException) { Cancelled = true; throw; }
        }
        public override bool CanRead => false; public override bool CanSeek => false; public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException(); public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() { }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }
    private sealed class RequestLifetime : IHttpRequestLifetimeFeature
    {
        private readonly CancellationTokenSource source = new();
        public bool Aborted { get; private set; }
        public CancellationToken RequestAborted { get => source.Token; set { } }
        public void Abort() { Aborted = true; source.Cancel(); }
    }
}
