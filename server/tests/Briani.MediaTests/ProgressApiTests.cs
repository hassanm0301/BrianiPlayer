using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.MediaTests;

public sealed class ProgressApiTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Unknown_duration_does_not_auto_mark_watched_and_progress_is_versioned()
    {
        var media = await AddMedia("unknown-duration.mkv", duration: null);
        var client = AdminClient();
        var initial = await client.GetFromJsonAsync<JsonElement>($"/api/v1/media/{media.MediaId:D}/progress");
        Assert.Equal(0, initial.GetProperty("positionMs").GetInt64());
        Assert.False(initial.GetProperty("watched").GetBoolean());
        Assert.Equal(1, initial.GetProperty("version").GetInt64());

        using var updateResponse = await client.PutAsJsonAsync($"/api/v1/media/{media.MediaId:D}/progress", new { positionMs = 9000L, durationMs = (long?)null, version = 1 });
        updateResponse.EnsureSuccessStatusCode();
        var updated = await updateResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(9000, updated.GetProperty("positionMs").GetInt64());
        Assert.True(updated.GetProperty("durationMs").ValueKind == JsonValueKind.Null);
        Assert.False(updated.GetProperty("watched").GetBoolean());
        Assert.Equal(2, updated.GetProperty("version").GetInt64());

        using var stale = await client.PutAsJsonAsync($"/api/v1/media/{media.MediaId:D}/progress", new { positionMs = 9100L, durationMs = (long?)null, version = 1 });
        Assert.Equal(HttpStatusCode.Conflict, stale.StatusCode);
    }

    [Fact]
    public async Task Duration_plausibility_and_auto_or_manual_watched_rules_are_applied()
    {
        var media = await AddMedia("known-duration.mp4", duration: 10_000);
        var client = AdminClient();
        using var implausible = await client.PutAsJsonAsync($"/api/v1/media/{media.MediaId:D}/progress", new { positionMs = 8000L, durationMs = 15_001L, version = 1 });
        Assert.Equal(HttpStatusCode.BadRequest, implausible.StatusCode);
        Assert.Equal("invalid_duration", await Code(implausible));

        using var plausible = await client.PutAsJsonAsync($"/api/v1/media/{media.MediaId:D}/progress", new { positionMs = 9500L, durationMs = 14_900L, version = 1 });
        plausible.EnsureSuccessStatusCode();
        var autoWatched = await plausible.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(autoWatched.GetProperty("watched").GetBoolean());
        Assert.Equal(10_000, autoWatched.GetProperty("durationMs").GetInt64());

        var explicitFalseMedia = await AddMedia("manual-unwatched.mp4", duration: 10_000);
        using var explicitFalse = await client.PutAsJsonAsync($"/api/v1/media/{explicitFalseMedia.MediaId:D}/progress", new { positionMs = 9900L, durationMs = 10_000L, version = 1, watched = false });
        explicitFalse.EnsureSuccessStatusCode();
        Assert.False((await explicitFalse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("watched").GetBoolean());

        var explicitTrueMedia = await AddMedia("manual-watched.mp4", duration: 10_000);
        using var explicitTrue = await client.PutAsJsonAsync($"/api/v1/media/{explicitTrueMedia.MediaId:D}/progress", new { positionMs = 100L, durationMs = 10_000L, version = 1, watched = true });
        explicitTrue.EnsureSuccessStatusCode();
        Assert.True((await explicitTrue.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("watched").GetBoolean());
    }

    [Fact]
    public async Task Progress_is_user_scoped_and_continue_watching_has_stable_paginated_schema()
    {
        var first = await AddMedia("one.mp4", duration: 20_000);
        var second = await AddMedia("two.mp4", duration: 30_000);
        var third = await AddMedia("three.mp4", duration: null);
        var hidden = await AddMedia("hidden.mp4", duration: 10_000, separateLibrary: true);
        var member = await CreateMemberWithGrant(first.LibraryId, second.LibraryId, third.LibraryId);
        var memberClient = IdentityFixture.As(fixture.Host.CreateClient(), member.Tokens.AccessToken);
        var admin = AdminClient();

        using (var adminProgress = await admin.PutAsJsonAsync($"/api/v1/media/{first.MediaId:D}/progress", new { positionMs = 11_000L, durationMs = 20_000L, version = 1 }))
            adminProgress.EnsureSuccessStatusCode();
        var memberInitial = await memberClient.GetFromJsonAsync<JsonElement>($"/api/v1/media/{first.MediaId:D}/progress");
        Assert.Equal(0, memberInitial.GetProperty("positionMs").GetInt64());

        using (var p1 = await memberClient.PutAsJsonAsync($"/api/v1/media/{first.MediaId:D}/progress", new { positionMs = 1000L, durationMs = 20_000L, version = 1 })) p1.EnsureSuccessStatusCode();
        fixture.Host.Clock.Advance(TimeSpan.FromSeconds(1));
        using (var p2 = await memberClient.PutAsJsonAsync($"/api/v1/media/{second.MediaId:D}/progress", new { positionMs = 2000L, durationMs = 30_000L, version = 1 })) p2.EnsureSuccessStatusCode();
        using (var p3 = await memberClient.PutAsJsonAsync($"/api/v1/media/{third.MediaId:D}/progress", new { positionMs = 3000L, durationMs = (long?)null, version = 1 })) p3.EnsureSuccessStatusCode();
        await fixture.Host.InDb(async db =>
        {
            db.PlaybackProgress.Add(new PlaybackProgress { UserId = member.User.Id, MediaItemId = hidden.MediaId, PositionMs = 500, DurationMs = 10000, Completed = false, UpdatedAt = fixture.Host.Clock.GetUtcNow() });
            await db.SaveChangesAsync(); return 0;
        });

        using var pageOneResponse = await memberClient.GetAsync("/api/v1/me/continue-watching?limit=1");
        pageOneResponse.EnsureSuccessStatusCode();
        using var pageOne = JsonDocument.Parse(await pageOneResponse.Content.ReadAsStringAsync());
        var root = pageOne.RootElement;
        Assert.Equal(new[] { "items", "nextCursor", "totalKnown", "truncated", "warnings" }, root.EnumerateObject().Select(x => x.Name).OrderBy(x => x).ToArray());
        Assert.Single(root.GetProperty("items").EnumerateArray());
        var firstItem = root.GetProperty("items")[0];
        Assert.Equal(new[] { "media", "progress" }, firstItem.EnumerateObject().Select(x => x.Name).OrderBy(x => x).ToArray());
        var mediaShape = firstItem.GetProperty("media");
        Assert.Equal(new[] { "complete", "durationMs", "entryId", "height", "id", "kind", "libraryId", "mimeType", "name", "probeState", "sizeBytes", "tracks", "version", "width" }, mediaShape.EnumerateObject().Select(x => x.Name).OrderBy(x => x).ToArray());
        var progressShape = firstItem.GetProperty("progress");
        Assert.Equal(new[] { "durationMs", "positionMs", "updatedAt", "version", "watched" }, progressShape.EnumerateObject().Select(x => x.Name).OrderBy(x => x).ToArray());
        Assert.NotEqual(Guid.Empty, mediaShape.GetProperty("id").GetGuid());
        Assert.True(progressShape.GetProperty("positionMs").GetInt64() > 0);
        Assert.DoesNotContain(hidden.MediaId.ToString("D"), pageOne.RootElement.GetRawText(), StringComparison.Ordinal);
        var cursor = root.GetProperty("nextCursor").GetString(); Assert.NotNull(cursor);

        using var pageTwoResponse = await memberClient.GetAsync($"/api/v1/me/continue-watching?limit=1&cursor={Uri.EscapeDataString(cursor!)}");
        pageTwoResponse.EnsureSuccessStatusCode();
        using var pageTwo = JsonDocument.Parse(await pageTwoResponse.Content.ReadAsStringAsync());
        var pageTwoItems = pageTwo.RootElement.GetProperty("items").EnumerateArray().ToArray();
        Assert.Single(pageTwoItems);
        var ids = new[] { mediaShape.GetProperty("id").GetGuid(), pageTwoItems[0].GetProperty("media").GetProperty("id").GetGuid() };
        Assert.Equal(2, ids.Distinct().Count());
        Assert.DoesNotContain(hidden.MediaId, ids);
        using var wrongUserCursor = await admin.GetAsync($"/api/v1/me/continue-watching?limit=1&cursor={Uri.EscapeDataString(cursor!)}");
        Assert.Equal(HttpStatusCode.BadRequest, wrongUserCursor.StatusCode);
    }

    private async Task<MediaTarget> AddMedia(string filename, long? duration, bool separateLibrary = false)
    {
        var libraryName = "progress-" + Guid.NewGuid().ToString("N");
        var directoryPath = Path.Combine(fixture.Host.Root, "data", libraryName); Directory.CreateDirectory(directoryPath);
        var bytes = new byte[] { 0, 1, 2, 3, 0xff, 0xfe };
        var path = Path.Combine(directoryPath, filename); await File.WriteAllBytesAsync(path, bytes);
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var contained = storage.ValidateLibraryRoot(libraryName); var libraryId = Guid.NewGuid(); var mediaId = Guid.NewGuid();
        var library = new Library { Id = libraryId, Name = libraryName, RootPath = libraryName, RootIdentity = contained.Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        NodeIdentity stat; using (var root = storage.OpenLibrary(library)) using (var file = root.OpenFile(filename)) stat = ContainedDirectory.Inspect(file);
        var media = new MediaItem { Id = mediaId, LibraryId = libraryId, RelativePath = filename, DisplayName = filename, SearchKey = filename.ToUpperInvariant(), Kind = "video", Extension = Path.GetExtension(filename), MimeType = "video/mp4", SizeBytes = stat.Length, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, Lifecycle = "available", CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow(), Version = 1 };
        await fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(library); db.MediaItems.Add(media);
            db.MediaMetadata.Add(new MediaMetadata { MediaItemId = mediaId, ProbeStatus = duration is null ? "pending" : "ready", ContentGeneration = 1, DurationMs = duration, TracksJson = "[]" });
            await db.SaveChangesAsync(); return 0;
        });
        return new(libraryId, mediaId);
    }

    private async Task<Member> CreateMemberWithGrant(params Guid[] libraryIds)
    {
        var password = Credentials.NewToken();
        using var created = await AdminClient().PostAsJsonAsync("/api/v1/admin/users", new { username = "progressmember", displayName = "Progress Member", password, role = "member" });
        created.EnsureSuccessStatusCode(); var user = (await created.Content.ReadFromJsonAsync<UserView>())!;
        await fixture.Host.InDb(async db =>
        {
            foreach (var libraryId in libraryIds) db.LibraryGrants.Add(new LibraryGrant { UserId = user.Id, LibraryId = libraryId, CanRead = true });
            await db.SaveChangesAsync(); return 0;
        });
        using var login = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = "progressmember", password, deviceName = "test" });
        return new(user, (await login.Content.ReadFromJsonAsync<AuthReply>())!);
    }

    private HttpClient AdminClient() => IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
    private static async Task<string?> Code(HttpResponseMessage response) => (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString();
    private sealed record MediaTarget(Guid LibraryId, Guid MediaId);
    private sealed record Member(UserView User, AuthReply Tokens);
}
