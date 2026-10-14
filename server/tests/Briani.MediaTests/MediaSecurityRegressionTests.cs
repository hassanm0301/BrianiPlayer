using Briani.Api.Infrastructure.Persistence;
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

public sealed class MediaSecurityRegressionTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Blocked_image_copy_aborts_promptly_when_access_token_expires()
    {
        var bytes = Enumerable.Range(0, 4096).Select(x => (byte)x).ToArray();
        var rootName = "security-" + Guid.NewGuid().ToString("N");
        var rootPath = Path.Combine(fixture.Host.Root, "data", rootName);
        Directory.CreateDirectory(rootPath);
        var filePath = Path.Combine(rootPath, "poster.jpg");
        await File.WriteAllBytesAsync(filePath, bytes);
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var rootInfo = storage.ValidateLibraryRoot(rootName);
        var library = new Library { Id = Guid.NewGuid(), Name = rootName, RootPath = rootName, RootIdentity = rootInfo.Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        NodeIdentity stat;
        using (var dir = storage.OpenLibrary(library)) using (var file = dir.OpenFile("poster.jpg")) stat = ContainedDirectory.Inspect(file);
        var item = new MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "poster.jpg", DisplayName = "poster.jpg", SearchKey = "POSTER.JPG", Kind = "photo", Extension = ".jpg", MimeType = "image/jpeg", SizeBytes = stat.Length, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db => { db.Libraries.Add(library); db.MediaItems.Add(item); await db.SaveChangesAsync(); return 0; });

        using var source = fixture.Host.Services.GetRequiredService<MediaAccess>().Open(item, library);
        using var readers = fixture.Host.Services.GetRequiredService<MediaReaders>().Acquire(fixture.Admin.SessionId, item.Id, CancellationToken.None);
        var context = new DefaultHttpContext();
        var lifetime = new RequestLifetimeFeature();
        context.Features.Set<IHttpRequestLifetimeFeature>(lifetime);
        var output = new BlockingOutputStream();
        context.Response.Body = output;
        var actor = new Actor(fixture.Admin.User.Id, fixture.Admin.SessionId, fixture.Admin.User.Role, AccessTokenHash: Credentials.Hash(fixture.Admin.AccessToken));
        using var scope = fixture.Host.Services.CreateScope();
        var copy = MediaEndpoints.CopyAsync(context, source, "image/jpeg", actor, item, fixture.Host.Services.GetRequiredService<IServiceScopeFactory>(), fixture.Host.Clock, readers);
        try
        {
            await output.Entered.Task.WaitAsync(TimeSpan.FromSeconds(3));
            fixture.Host.Clock.Advance(TimeSpan.FromMinutes(16));
            await copy.WaitAsync(TimeSpan.FromSeconds(3));
            Assert.True(lifetime.Aborted);
            Assert.Equal(1, output.WriteCount);
        }
        finally { output.Release(); }
    }

    [Fact]
    public async Task Blocked_image_copy_aborts_when_source_is_replaced()
    {
        var bytes = Enumerable.Repeat((byte)21, 4096).ToArray();
        var rootName = "replace-" + Guid.NewGuid().ToString("N");
        var rootPath = Path.Combine(fixture.Host.Root, "data", rootName);
        Directory.CreateDirectory(rootPath);
        var filePath = Path.Combine(rootPath, "poster.jpg");
        await File.WriteAllBytesAsync(filePath, bytes);
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var rootInfo = storage.ValidateLibraryRoot(rootName);
        var library = new Library { Id = Guid.NewGuid(), Name = rootName, RootPath = rootName, RootIdentity = rootInfo.Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        NodeIdentity stat;
        using (var dir = storage.OpenLibrary(library)) using (var file = dir.OpenFile("poster.jpg")) stat = ContainedDirectory.Inspect(file);
        var item = new MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "poster.jpg", DisplayName = "poster.jpg", SearchKey = "POSTER.JPG", Kind = "photo", Extension = ".jpg", MimeType = "image/jpeg", SizeBytes = stat.Length, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db => { db.Libraries.Add(library); db.MediaItems.Add(item); await db.SaveChangesAsync(); return 0; });

        using var source = fixture.Host.Services.GetRequiredService<MediaAccess>().Open(item, library);
        using var readers = fixture.Host.Services.GetRequiredService<MediaReaders>().Acquire(fixture.Admin.SessionId, item.Id, CancellationToken.None);
        var context = new DefaultHttpContext();
        var lifetime = new RequestLifetimeFeature();
        context.Features.Set<IHttpRequestLifetimeFeature>(lifetime);
        var output = new BlockingOutputStream(); context.Response.Body = output;
        var actor = new Actor(fixture.Admin.User.Id, fixture.Admin.SessionId, fixture.Admin.User.Role, AccessTokenHash: Credentials.Hash(fixture.Admin.AccessToken));
        var copy = MediaEndpoints.CopyAsync(context, source, "image/jpeg", actor, item, fixture.Host.Services.GetRequiredService<IServiceScopeFactory>(), fixture.Host.Clock, readers);
        try
        {
            await output.Entered.Task.WaitAsync(TimeSpan.FromSeconds(3));
            var replacement = Path.Combine(rootPath, "replacement.jpg");
            await File.WriteAllBytesAsync(replacement, Enumerable.Repeat((byte)42, 8192).ToArray());
            File.Move(replacement, filePath, overwrite: true);
            await copy.WaitAsync(TimeSpan.FromSeconds(3));
            Assert.True(lifetime.Aborted);
            Assert.Equal(1, output.WriteCount);
        }
        finally { output.Release(); }
    }

    private sealed class BlockingOutputStream : Stream
    {
        private readonly TaskCompletionSource release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public TaskCompletionSource Entered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public int WriteCount { get; private set; }
        public void Release() => release.TrySetResult();
        public override async ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default)
        { WriteCount++; Entered.TrySetResult(); await release.Task.WaitAsync(cancellationToken); }
        public override bool CanRead => false; public override bool CanSeek => false; public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException(); public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() { } public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException(); public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }

    private sealed class RequestLifetimeFeature : IHttpRequestLifetimeFeature
    {
        private readonly CancellationTokenSource aborted = new();
        public CancellationToken RequestAborted { get => aborted.Token; set { } }
        public bool Aborted { get; private set; }
        public void Abort() { Aborted = true; aborted.Cancel(); }
    }
}
