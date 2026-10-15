using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Discovery;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.DiscoveryTests;

public sealed class SourceRetentionTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Pruning_old_uploads_and_orphans_allows_second_four_upload_batch_after_refresh()
    {
        await AddAccessibleLibrary();
        using var firstClient = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var payload = TorrentFixture.CreateV1("batch.mkv", [1, 3, 5]).Bytes;
        var initialUploads = new List<Guid>();
        for (var i = 0; i < 4; i++) initialUploads.Add(await Upload(firstClient, payload));
        using (var fifth = await UploadResponse(firstClient, payload)) Assert.Equal(HttpStatusCode.TooManyRequests, fifth.StatusCode);
        var expiredRows = await fixture.Host.InDb(db => db.TorrentUploads.AsNoTracking().Where(x => initialUploads.Contains(x.Id)).ToListAsync());
        Assert.Equal(4, expiredRows.Count);
        Assert.All(expiredRows, row => Assert.True(File.Exists(StateFile(row.RelativePath))));

        var orphanPath = "uploads/" + Guid.NewGuid().ToString("N") + ".torrent";
        using (var state = new ContainedDirectory(Path.Combine(fixture.Host.Root, "state")))
        using (var orphan = state.CreateFile(orphanPath)) { orphan.WriteByte(1); orphan.Flush(true); }

        fixture.Host.Clock.Advance(TimeSpan.FromMinutes(31));
        using var refresh = await fixture.Client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = fixture.Admin.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refresh.StatusCode);
        var refreshed = await refresh.Content.ReadFromJsonAsync<AuthReply>();
        Assert.NotNull(refreshed);
        await fixture.Host.Services.GetRequiredService<SourceHousekeeping>().PruneAsync();
        Assert.Equal(0, await fixture.Host.InDb(db => db.TorrentUploads.CountAsync()));
        Assert.All(expiredRows, row => Assert.False(File.Exists(StateFile(row.RelativePath))));
        using (var state = new ContainedDirectory(Path.Combine(fixture.Host.Root, "state"))) Assert.Throws<ApiException>(() => state.Inspect(orphanPath));

        using var refreshedClient = IdentityFixture.As(fixture.Host.CreateClient(), refreshed.AccessToken);
        var secondBatch = new List<Guid>();
        for (var i = 0; i < 4; i++) secondBatch.Add(await Upload(refreshedClient, payload));
        Assert.Equal(4, await fixture.Host.InDb(db => db.TorrentUploads.CountAsync()));
        Assert.Equal(4, await fixture.Host.InDb(db => db.TorrentUploads.CountAsync(x => x.UserId == fixture.Admin.User.Id)));
        var currentRows = await fixture.Host.InDb(db => db.TorrentUploads.AsNoTracking().Where(x => secondBatch.Contains(x.Id)).ToListAsync());
        Assert.Equal(4, currentRows.Count);
        Assert.All(currentRows, row => Assert.True(File.Exists(StateFile(row.RelativePath))));
    }

    [Fact]
    public async Task Thirty_two_retained_uploads_across_users_hit_global_file_and_row_cap()
    {
        await AddAccessibleLibrary();
        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var userIds = new List<Guid> { fixture.Admin.User.Id };
        for (var i = 0; i < 7; i++)
        {
            var password = Credentials.NewToken();
            using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "cap-user-" + i + Guid.NewGuid().ToString("N")[..6], displayName = "Cap User", password, confirmPassword = password, role = "member" });
            created.EnsureSuccessStatusCode();
            userIds.Add((await created.Content.ReadFromJsonAsync<UserReply>())!.Id);
        }
        var payload = TorrentFixture.CreateV1("global-cap.mkv", [4, 4, 4]).Bytes;
        var now = fixture.Host.Clock.GetUtcNow();
        Directory.CreateDirectory(Path.Combine(fixture.Host.Root, "state", "uploads"));
        var seeded = new List<TorrentUpload>();
        using (var root = new ContainedDirectory(Path.Combine(fixture.Host.Root, "state")))
        {
            for (var userIndex = 0; userIndex < userIds.Count; userIndex++)
            for (var uploadIndex = 0; uploadIndex < 4; uploadIndex++)
            {
                var id = Guid.NewGuid();
                var upload = new TorrentUpload { Id = id, UserId = userIds[userIndex], RelativePath = $"uploads/{id:N}.torrent", Bytes = payload.Length,
                    Sha256 = Convert.ToHexString(SHA256.HashData(payload)), CreatedAt = now, ExpiresAt = now.AddMinutes(30) };
                using (var file = root.CreateFile(upload.RelativePath)) { await file.WriteAsync(payload); file.Flush(true); upload.FileIdentity = ContainedDirectory.Inspect(file).Key; }
                seeded.Add(upload);
            }
        }
        await fixture.Host.InDb(async db => { db.TorrentUploads.AddRange(seeded); await db.SaveChangesAsync(); return 0; });
        Assert.Equal(32, await fixture.Host.InDb(db => db.TorrentUploads.CountAsync()));
        using (var rejected = await UploadResponse(admin, payload)) Assert.Equal(HttpStatusCode.TooManyRequests, rejected.StatusCode);
        Assert.Equal(32, await fixture.Host.InDb(db => db.TorrentUploads.CountAsync()));
        Assert.Equal(32, Directory.GetFiles(Path.Combine(fixture.Host.Root, "state", "uploads"), "*.torrent").Length);
        Assert.All(seeded, row => Assert.True(File.Exists(StateFile(row.RelativePath))));
    }

    private async Task AddAccessibleLibrary()
    {
        var rootName = "retention-" + Guid.NewGuid().ToString("N");
        Directory.CreateDirectory(Path.Combine(fixture.Host.Root, "data", rootName));
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var library = new Library { Id = Guid.NewGuid(), Name = rootName, RootPath = rootName, RootIdentity = storage.ValidateLibraryRoot(rootName).Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db => { db.Libraries.Add(library); await db.SaveChangesAsync(); return 0; });
    }

    private async Task<Guid> Upload(HttpClient client, byte[] payload)
    {
        using var response = await UploadResponse(client, payload);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>()).GetProperty("id").GetGuid();
    }

    private static async Task<HttpResponseMessage> UploadResponse(HttpClient client, byte[] payload)
    {
        using var form = new MultipartFormDataContent();
        form.Add(new ByteArrayContent(payload), "file", "batch.torrent");
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/torrent-uploads") { Content = form };
        return await client.SendAsync(request);
    }

    private string StateFile(string relative) => Path.Combine(fixture.Host.Root, "state", relative.Replace('/', Path.DirectorySeparatorChar));
}
