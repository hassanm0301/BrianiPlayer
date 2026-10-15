using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;

namespace Briani.MediaTests;

public sealed class QueryApiTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Theory]
    [InlineData("name")]
    [InlineData("date")]
    [InlineData("size")]
    public async Task Empty_catalog_supports_all_folder_sorts(string sort)
    {
        var library = await AddLibraryWithItems();
        var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        var response = await client.GetAsync($"/api/v1/libraries/{library:D}/entries?sort={sort}");
        response.EnsureSuccessStatusCode();
        using var page = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Empty(page.RootElement.GetProperty("items").EnumerateArray());
        Assert.Equal(0, page.RootElement.GetProperty("totalKnown").GetInt64());
        Assert.Equal(JsonValueKind.Null, page.RootElement.GetProperty("nextCursor").ValueKind);
    }

    [Fact]
    public async Task Entry_search_is_unicode_normalized_and_treats_like_wildcards_literally()
    {
        var library = await AddLibraryWithItems(
            ("100% Café.mkv", "video", "100% CAFÉ.MKV"),
            ("100x Café.mkv", "video", "100X CAFÉ.MKV"));
        var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);

        var response = await client.GetAsync($"/api/v1/libraries/{library:D}/entries?query=100%25%20cafe%CC%81");
        response.EnsureSuccessStatusCode();
        using var page = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var items = page.RootElement.GetProperty("items").EnumerateArray().ToArray();
        Assert.Single(items);
        Assert.Equal("100% Café.mkv", items[0].GetProperty("name").GetString());
        Assert.Equal("video", items[0].GetProperty("kind").GetString());
        Assert.Equal(items[0].GetProperty("id").GetGuid(), items[0].GetProperty("mediaId").GetGuid());
    }

    [Fact]
    public async Task Cursor_is_bound_to_user_query_and_catalog_and_rejects_tampering()
    {
        var library = await AddLibraryWithItems(("a.mkv", "video", "A.MKV"), ("b.mkv", "video", "B.MKV"));
        var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        var first = await client.GetFromJsonAsync<JsonElement>($"/api/v1/libraries/{library:D}/entries?limit=1");
        var cursor = first.GetProperty("nextCursor").GetString();
        Assert.NotNull(cursor);

        var second = await client.GetAsync($"/api/v1/libraries/{library:D}/entries?limit=1&cursor={Uri.EscapeDataString(cursor!)}");
        second.EnsureSuccessStatusCode();
        var changedQuery = await client.GetAsync($"/api/v1/libraries/{library:D}/entries?limit=1&query=a&cursor={Uri.EscapeDataString(cursor!)}");
        Assert.Equal(HttpStatusCode.BadRequest, changedQuery.StatusCode);
        var forged = cursor![..^1] + (cursor[^1] == 'A' ? 'B' : 'A');
        var tampered = await client.GetAsync($"/api/v1/libraries/{library:D}/entries?limit=1&cursor={Uri.EscapeDataString(forged)}");
        Assert.Equal(HttpStatusCode.BadRequest, tampered.StatusCode);

        await fixture.Host.InDb(async db =>
        {
            var added = Item(library, "c.mkv", "video", "C.MKV");
            db.MediaItems.Add(added);
            await db.SaveChangesAsync();
            return 0;
        });
        var stale = await client.GetAsync($"/api/v1/libraries/{library:D}/entries?limit=1&cursor={Uri.EscapeDataString(cursor!)}");
        Assert.Equal(HttpStatusCode.BadRequest, stale.StatusCode);
    }

    [Fact]
    public async Task Media_metadata_exposes_tracks_and_no_server_path()
    {
        var library = Guid.NewGuid();
        var media = Item(library, "private/Feature.mkv", "video", "FEATURE.MKV");
        media.DisplayName = "Feature.mkv";
        await fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(Lib(library));
            db.MediaItems.Add(media);
            db.MediaMetadata.Add(new MediaMetadata
            {
                MediaItemId = media.Id, ProbeStatus = "ready", DurationMs = 12_345, Width = 1920, Height = 1080,
                TracksJson = JsonSerializer.Serialize(new[] { new MediaTrack("0", "video", "en", "Main", "h264", true) })
            });
            await db.SaveChangesAsync();
            return 0;
        });
        var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);

        var response = await client.GetAsync($"/api/v1/media/{media.Id:D}");
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadAsStringAsync();
        using var json = JsonDocument.Parse(body);
        var root = json.RootElement;
        Assert.Equal("ready", root.GetProperty("probeState").GetString());
        Assert.Equal("video", root.GetProperty("tracks")[0].GetProperty("kind").GetString());
        Assert.True(root.GetProperty("tracks")[0].GetProperty("default").GetBoolean());
        Assert.DoesNotContain("private/Feature.mkv", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Scan_is_idempotent_and_job_is_readable_only_while_library_access_is_granted()
    {
        var library = await AddLibraryWithItems();
        var client = IdentityFixture.As(fixture.Client, fixture.Admin.AccessToken);
        using var request = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/libraries/{library:D}/scan");
        request.Headers.Add("Idempotency-Key", "scan-test-1");
        var firstResponse = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Accepted, firstResponse.StatusCode);
        var first = await firstResponse.Content.ReadFromJsonAsync<JsonElement>();
        var jobId = first.GetProperty("id").GetGuid();

        using var retry = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/libraries/{library:D}/scan");
        retry.Headers.Add("Idempotency-Key", "scan-test-1");
        var retryResponse = await client.SendAsync(retry);
        Assert.Equal(HttpStatusCode.Accepted, retryResponse.StatusCode);
        var repeated = await retryResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(jobId, repeated.GetProperty("id").GetGuid());
        var job = await client.GetFromJsonAsync<JsonElement>($"/api/v1/jobs/{jobId:D}");
        Assert.Equal("scan", job.GetProperty("kind").GetString());
        Assert.Equal("queued", job.GetProperty("state").GetString());

        await fixture.Host.InDb(async db =>
        {
            var live = await db.Libraries.SingleAsync(x => x.Id == library);
            live.Enabled = false;
            await db.SaveChangesAsync();
            return 0;
        });
        var denied = await client.GetAsync($"/api/v1/jobs/{jobId:D}");
        Assert.Equal(HttpStatusCode.NotFound, denied.StatusCode);
    }

    private Task<Guid> AddLibraryWithItems(params (string Name, string Kind, string Search)[] entries)
    {
        var id = Guid.NewGuid();
        return fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(Lib(id));
            foreach (var (name, kind, search) in entries) db.MediaItems.Add(Item(id, name, kind, search));
            await db.SaveChangesAsync();
            return id;
        });
    }

    private static Library Lib(Guid id) => new()
    {
        Id = id, Name = "Test library", RootPath = "test-root", RootIdentity = "fixture-root", CreatedAt = DateTimeOffset.UtcNow
    };

    private static MediaItem Item(Guid library, string name, string kind, string search) => new()
    {
        Id = Guid.NewGuid(), LibraryId = library, RelativePath = name, ParentRelativePath = "", DisplayName = name,
        SearchKey = search, Kind = kind, Extension = ".mkv", MimeType = "video/x-matroska", SizeBytes = 100,
        FileIdentity = "fixture-node", Lifecycle = "available", MtimeNs = 1_767_000_000_000_000_000,
        CreatedAt = DateTimeOffset.UtcNow, IndexedAt = DateTimeOffset.UtcNow, Version = 1
    };
}
