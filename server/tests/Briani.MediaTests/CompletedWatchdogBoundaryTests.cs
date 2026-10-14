using System.Net.Http.Json;
using System.Text.Json;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.MediaTests;

public sealed class CompletedWatchdogBoundaryTests
{
    [Theory]
    [InlineData("session-deleted")] [InlineData("session-revoked")] [InlineData("session-expired")]
    [InlineData("user-disabled")] [InlineData("password-change")] [InlineData("auth-revoked")]
    [InlineData("library-disabled")] [InlineData("media-generation")]
    [InlineData("path-replaced")] [InlineData("file-grown")] [InlineData("mtime-changed")]
    public async Task Open_completed_stream_aborts_after_session_authorization_or_file_changes(string change)
    {
        var fixture = new IdentityFixture(); await fixture.InitializeAsync();
        try
        {
            var relative = "watchdog-" + Guid.NewGuid().ToString("N");
            var directory = Path.Combine(fixture.Host.Root, "data", relative); Directory.CreateDirectory(directory);
            var path = Path.Combine(directory, "movie.mp4"); var bytes = new byte[1024 * 1024]; new Random(6182).NextBytes(bytes); await File.WriteAllBytesAsync(path, bytes);
            var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
            var library = new Library { Name = "Watchdog", RootPath = relative, RootIdentity = storage.ValidateLibraryRoot(relative).Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
            NodeIdentity stat; using (var root = storage.OpenLibrary(library)) using (var file = root.OpenFile("movie.mp4")) stat = ContainedDirectory.Inspect(file);
            var media = new MediaItem { LibraryId = library.Id, RelativePath = "movie.mp4", DisplayName = "movie.mp4", SearchKey = "MOVIE.MP4", Kind = "video", MimeType = "video/mp4", Extension = ".mp4", SizeBytes = stat.Length, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, Lifecycle = "available", CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow() };
            await fixture.Host.InDb(async db => { db.AddRange(library, media); db.MediaMetadata.Add(new MediaMetadata { MediaItemId = media.Id, ProbeStatus = "ready", ContentGeneration = 1, TracksJson = "[]" }); return await db.SaveChangesAsync(); });
            using var client = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
            using var created = await client.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "media", id = media.Id }, mode = "internal" }); created.EnsureSuccessStatusCode();
            var view = await created.Content.ReadFromJsonAsync<JsonElement>(); var sessionId = view.GetProperty("id").GetGuid();
            var ticket = new Uri(view.GetProperty("streamUrl").GetString()!).AbsolutePath.Split('/')[2];
            using var scope = fixture.Host.Services.CreateScope(); var response = new BlockedResponse(); var lifetime = new RequestLifetime();
            var context = new DefaultHttpContext { RequestServices = scope.ServiceProvider }; context.Features.Set<IHttpRequestLifetimeFeature>(lifetime);
            context.Request.Method = "GET"; context.Request.Host = new HostString("localhost"); context.Response.Body = response;
            var readers = fixture.Host.Services.GetRequiredService<MediaReaders>(); var playback = scope.ServiceProvider.GetRequiredService<CompletedPlayback>();
            var running = playback.StreamAsync(ticket, "movie.mp4", context);
            try
            {
                await response.Blocked.WaitAsync(TimeSpan.FromSeconds(3)); Assert.Equal(bytes[..262144], response.FirstBytes); Assert.True(readers.HasReaders(media.Id));
                if (change == "session-revoked")
                {
                    // The fixture's wall clock is fixed, but watchdog timers use the real one-second period.
                    await Task.Delay(TimeSpan.FromMilliseconds(1200));
                    Assert.False(lifetime.Aborted); Assert.True(readers.HasReaders(media.Id)); Assert.Equal(1, response.WriteCount);
                }
                if (change == "path-replaced") { File.Move(path, path + ".retained"); await File.WriteAllBytesAsync(path, bytes); }
                else if (change == "file-grown") { using var append = new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.ReadWrite); append.WriteByte(42); append.Flush(true); }
                else if (change == "mtime-changed") File.SetLastWriteTimeUtc(path, File.GetLastWriteTimeUtc(path).AddSeconds(5));
                else await fixture.Host.InDb(async db =>
                {
                    var live = await db.PlaybackSessions.SingleAsync(s => s.Id == sessionId);
                    switch (change)
                    {
                        case "session-deleted": db.PlaybackSessions.Remove(live); break;
                        case "session-revoked": live.RevokedAt = fixture.Host.Clock.GetUtcNow(); break;
                        case "session-expired": live.AbsoluteExpiresAt = fixture.Host.Clock.GetUtcNow(); break;
                        case "user-disabled": (await db.Users.SingleAsync(u => u.Id == fixture.Admin.User.Id)).Enabled = false; break;
                        case "password-change": (await db.Users.SingleAsync(u => u.Id == fixture.Admin.User.Id)).MustChangePassword = true; break;
                        case "auth-revoked": (await db.AuthSessions.SingleAsync(s => s.Id == fixture.Admin.SessionId)).RevokedAt = fixture.Host.Clock.GetUtcNow(); break;
                        case "library-disabled": (await db.Libraries.SingleAsync(l => l.Id == library.Id)).Enabled = false; break;
                        case "media-generation": (await db.MediaItems.SingleAsync(m => m.Id == media.Id)).Version++; break;
                    }
                    return await db.SaveChangesAsync();
                });
                await running.WaitAsync(TimeSpan.FromSeconds(4)); Assert.True(lifetime.Aborted); Assert.True(response.Cancelled); Assert.Equal(1, response.WriteCount); Assert.False(readers.HasReaders(media.Id));
            }
            finally { lifetime.Abort(); await running.WaitAsync(TimeSpan.FromSeconds(3)); }
        }
        finally { await fixture.DisposeAsync(); }
    }

    private sealed class BlockedResponse : Stream
    {
        private readonly TaskCompletionSource blocked = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task Blocked => blocked.Task; public byte[] FirstBytes { get; private set; } = []; public int WriteCount { get; private set; } public bool Cancelled { get; private set; }
        public override async ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default)
        { WriteCount++; FirstBytes = buffer.ToArray(); blocked.TrySetResult(); try { await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); } catch (OperationCanceledException) { Cancelled = true; throw; } }
        public override bool CanRead => false; public override bool CanSeek => false; public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException(); public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() { } public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException(); public override void SetLength(long value) => throw new NotSupportedException(); public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }
    private sealed class RequestLifetime : IHttpRequestLifetimeFeature
    {
        private readonly CancellationTokenSource source = new(); public bool Aborted { get; private set; }
        public CancellationToken RequestAborted { get => source.Token; set { } }
        public void Abort() { Aborted = true; source.Cancel(); }
    }
}
