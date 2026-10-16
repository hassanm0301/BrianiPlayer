using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;

namespace Briani.DownloadTests;

public sealed class SubtitleApiTests
{
    private static readonly byte[] VideoFixture = Enumerable.Range(0, 4096).Select(x => (byte)(x % 251)).ToArray();
    private const string Subtitle = "1\n00:00:01,000 --> 00:00:02,000\ncafé\n";

    [Fact]
    public async Task Physical_sidecar_uses_independent_ticket_and_serves_exact_utf8_ranges_and_head()
    {
        await using var fixture = await LifecycleFixture.Create();
        var seeded = await SeedPhysicalVideo(fixture, Encoding.UTF8.GetBytes(Subtitle), addSecond: true);
        var playback = await CreateMediaSession(fixture, seeded.MediaId);
        Assert.NotNull(playback.MainUrl);
        var english = Assert.Single(playback.Sidecars, x => x.Name == "video.en.srt");
        var expected = Encoding.UTF8.GetBytes(Subtitle);
        var subtitleUrl = new Uri(english.Url);
        var sidecarToken = Token(english.Url);
        Assert.StartsWith("s.", sidecarToken, StringComparison.Ordinal);

        using (var full = await fixture.Client.GetAsync(english.Url))
        {
            Assert.Equal(HttpStatusCode.OK, full.StatusCode);
            Assert.Equal(expected, await full.Content.ReadAsByteArrayAsync());
            Assert.True(full.Headers.CacheControl?.Private);
            Assert.True(full.Headers.CacheControl?.NoStore);
            Assert.Equal("nosniff", full.Headers.GetValues("X-Content-Type-Options").Single());
        }
        using (var closed = await SendSidecar(fixture, english.Url, "bytes=0-5"))
        {
            Assert.Equal(HttpStatusCode.PartialContent, closed.StatusCode);
            Assert.Equal(expected[..6], await closed.Content.ReadAsByteArrayAsync());
            Assert.Equal($"bytes 0-5/{expected.Length}", closed.Content.Headers.ContentRange?.ToString());
        }
        using (var open = await SendSidecar(fixture, english.Url, $"bytes={expected.Length - 4}-"))
            Assert.Equal(expected[^4..], await open.Content.ReadAsByteArrayAsync());
        using (var suffix = await SendSidecar(fixture, english.Url, "bytes=-3"))
            Assert.Equal(expected[^3..], await suffix.Content.ReadAsByteArrayAsync());
        using (var head = await SendSidecar(fixture, english.Url, "bytes=0-1", HttpMethod.Head))
        {
            Assert.Equal(HttpStatusCode.OK, head.StatusCode);
            Assert.Equal(expected.Length, head.Content.Headers.ContentLength);
            Assert.Empty(await head.Content.ReadAsByteArrayAsync());
        }

        // The main media ticket is scoped to the video target, even when its suffix
        // is changed to the name of a discovered sidecar.
        using var mainTicketAsSubtitle = await fixture.Client.GetAsync(Replace(Assert.IsType<string>(playback.MainUrl), "video.en.srt"));
        Assert.Equal(HttpStatusCode.NotFound, mainTicketAsSubtitle.StatusCode);
        Assert.Equal(subtitleUrl.AbsolutePath, new Uri(english.Url).AbsolutePath);
    }

    [Fact]
    public async Task Sidecar_hmac_is_bound_to_file_and_session_and_revocation_invalidates_it()
    {
        await using var fixture = await LifecycleFixture.Create();
        var seeded = await SeedPhysicalVideo(fixture, Encoding.UTF8.GetBytes(Subtitle), addSecond: true);
        var playback = await CreateMediaSession(fixture, seeded.MediaId);
        var english = Assert.Single(playback.Sidecars, x => x.Name == "video.en.srt");
        var french = Assert.Single(playback.Sidecars, x => x.Name == "video.fr.srt");

        using (var wrongSuffix = await fixture.Client.GetAsync(Replace(english.Url, "video.fr.srt")))
            Assert.Equal(HttpStatusCode.NotFound, wrongSuffix.StatusCode);
        using (var tampered = await fixture.Client.GetAsync(ReplaceToken(english.Url, Tamper(Token(english.Url)))))
            Assert.Equal(HttpStatusCode.NotFound, tampered.StatusCode);
        using (var crossFile = await fixture.Client.GetAsync(ReplaceTokenAndName(english.Url, TokenForDifferentFile(Token(english.Url), Token(french.Url)), "video.fr.srt")))
            Assert.Equal(HttpStatusCode.NotFound, crossFile.StatusCode);

        var unauthenticated = await fixture.CreateUser("subtitleoutsider");
        using (var denied = await unauthenticated.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "media", id = seeded.MediaId }, mode = "internal", initialPositionMs = 0
        })) Assert.Equal(HttpStatusCode.NotFound, denied.StatusCode);

        await File.WriteAllBytesAsync(Path.Combine(fixture.LibraryPath, seeded.SubtitlePath), Encoding.UTF8.GetBytes(Subtitle + "replacement\n"));
        using (var replaced = await fixture.Client.GetAsync(english.Url))
            Assert.Equal(HttpStatusCode.NotFound, replaced.StatusCode);

        using (var revoked = await fixture.Client.DeleteAsync($"/api/v1/playback/sessions/{playback.SessionId}"))
            Assert.Equal(HttpStatusCode.NoContent, revoked.StatusCode);
        using var afterRevoke = await fixture.Client.GetAsync(french.Url);
        Assert.Equal(HttpStatusCode.NotFound, afterRevoke.StatusCode);
    }

    [Theory]
    [InlineData("invalidUtf8")]
    [InlineData("nul")]
    public async Task Malformed_subtitle_bytes_return_bounded_safe_error(string kind)
    {
        var bytes = kind == "nul" ? new byte[] { (byte)'x', 0, (byte)'y' } : new byte[] { 0xc3, 0x28 };
        await using var fixture = await LifecycleFixture.Create();
        var seeded = await SeedPhysicalVideo(fixture, bytes, addSecond: false);
        var playback = await CreateMediaSession(fixture, seeded.MediaId);
        var sidecar = Assert.Single(playback.Sidecars);

        using var response = await fixture.Client.GetAsync(sidecar.Url);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var problem = await response.Content.ReadAsStringAsync();
        Assert.Contains("subtitle_invalid", problem, StringComparison.Ordinal);
        Assert.DoesNotContain(Convert.ToBase64String(bytes), problem, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Download_sidecars_list_only_completed_subtitle_files()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var stagePath = Path.Combine(fixture.LibraryPath, ".briani", "staging", fixture.Engine.JobId.ToString("N"));
        Directory.CreateDirectory(stagePath);
        var completedBytes = Encoding.UTF8.GetBytes(Subtitle);
        var pendingBytes = Encoding.UTF8.GetBytes("1\nwaiting\n");
        await File.WriteAllBytesAsync(Path.Combine(stagePath, "fixture.en.srt"), completedBytes);
        await File.WriteAllBytesAsync(Path.Combine(stagePath, "fixture.fr.srt"), pendingBytes);
        var englishNode = Inspect(fixture.LibraryPath, $".briani/staging/{fixture.Engine.JobId:N}/fixture.en.srt");
        var frenchNode = Inspect(fixture.LibraryPath, $".briani/staging/{fixture.Engine.JobId:N}/fixture.fr.srt");
        var englishId = Guid.NewGuid();
        var frenchId = Guid.NewGuid();
        await fixture.InDb(async db =>
        {
            var job = await db.TorrentJobs.SingleAsync(x => x.Id == fixture.Engine.JobId);
            job.TotalBytes = LifecycleFixture.FileBytes + completedBytes.Length + pendingBytes.Length;
            job.PieceCount = 5;
            db.DownloadFiles.AddRange(
                SubtitleFile(englishId, job.Id, "fixture.en.srt", completedBytes.Length, englishNode, true),
                SubtitleFile(frenchId, job.Id, "fixture.fr.srt", pendingBytes.Length, frenchNode, false));
            await db.SaveChangesAsync();
            return 0;
        });
        fixture.Engine.ConfigureFiles(5,
            new Briani.Api.Integrations.QBittorrent.EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3),
            new Briani.Api.Integrations.QBittorrent.EngineFile(1, "fixture.en.srt", completedBytes.Length, 1, 7, 4, 4),
            new Briani.Api.Integrations.QBittorrent.EngineFile(2, "fixture.fr.srt", pendingBytes.Length, 1, 7, 4, 4));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, stagePath);

        var response = await fixture.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "downloadFile", id = fixture.Engine.FileId }, mode = "internal", initialPositionMs = 0
        });
        using (response)
        {
            Assert.Equal(HttpStatusCode.Created, response.StatusCode);
            using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            var sidecars = document.RootElement.GetProperty("sidecars").EnumerateArray().ToArray();
            var sidecar = Assert.Single(sidecars);
            Assert.Equal("fixture.en.srt", sidecar.GetProperty("name").GetString());
            Assert.Equal(englishId, sidecar.GetProperty("id").GetGuid());
            Assert.DoesNotContain(sidecars, x => x.GetProperty("id").GetGuid() == frenchId);
        }
    }

    [Fact]
    public async Task Imported_video_lists_each_subtitle_once_with_its_language()
    {
        await using var fixture = await LifecycleFixture.Create();
        await fixture.SeedReadyDownload(fixture.Admin.User.Id, fixture.Admin.SessionId);
        var stageRelative = $".briani/staging/{fixture.Engine.JobId:N}";
        var stagePath = Path.Combine(fixture.LibraryPath, stageRelative);
        Directory.CreateDirectory(stagePath);
        var subtitle = Encoding.UTF8.GetBytes(Subtitle);
        await File.WriteAllBytesAsync(Path.Combine(stagePath, "fixture.en.srt"), subtitle);
        var stagedNode = Inspect(fixture.LibraryPath, stageRelative + "/fixture.en.srt");
        // The import placed the same files in the library folder.
        var importedDirectory = "Downloads/fixture--" + fixture.Engine.JobId.ToString("N")[..8];
        Directory.CreateDirectory(Path.Combine(fixture.LibraryPath, importedDirectory));
        await File.WriteAllBytesAsync(Path.Combine(fixture.LibraryPath, importedDirectory, "fixture.mp4"), VideoFixture);
        await File.WriteAllBytesAsync(Path.Combine(fixture.LibraryPath, importedDirectory, "fixture.en.srt"), subtitle);
        var videoNode = Inspect(fixture.LibraryPath, importedDirectory + "/fixture.mp4");
        var mediaId = Guid.NewGuid();
        await fixture.InDb(async db =>
        {
            var job = await db.TorrentJobs.SingleAsync(x => x.Id == fixture.Engine.JobId);
            job.TotalBytes = LifecycleFixture.FileBytes + subtitle.Length;
            job.PieceCount = 5;
            db.DownloadFiles.Add(SubtitleFile(Guid.NewGuid(), job.Id, "fixture.en.srt", subtitle.Length, stagedNode, true));
            var item = new MediaItem
            {
                Id = mediaId, LibraryId = fixture.LibraryId, ParentRelativePath = importedDirectory, RelativePath = importedDirectory + "/fixture.mp4",
                DisplayName = "fixture.mp4", SearchKey = "fixture.mp4", Kind = "video", Extension = ".mp4", MimeType = "video/mp4",
                SizeBytes = VideoFixture.Length, MtimeNs = videoNode.MtimeNs, FileIdentity = videoNode.Key, SourceKind = "hardlink",
                DownloadFileId = fixture.Engine.FileId, Lifecycle = "available", Version = 1, CreatedAt = fixture.Clock.GetUtcNow(), IndexedAt = fixture.Clock.GetUtcNow()
            };
            db.MediaItems.Add(item);
            db.MediaMetadata.Add(new MediaMetadata { MediaItemId = item.Id, ProbeStatus = "ready", ContentGeneration = item.Version, Container = "mp4", ProbeVersion = "fixture" });
            await db.SaveChangesAsync();
            return 0;
        });
        fixture.Engine.ConfigureFiles(5,
            new Briani.Api.Integrations.QBittorrent.EngineFile(0, "fixture.mp4", LifecycleFixture.FileBytes, 1, 7, 0, 3),
            new Briani.Api.Integrations.QBittorrent.EngineFile(1, "fixture.en.srt", subtitle.Length, 1, 7, 4, 4));
        fixture.Engine.RegisterExisting(LifecycleFixture.Hash, stagePath);

        using var response = await fixture.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "media", id = mediaId }, mode = "internal", initialPositionMs = 0
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var sidecar = Assert.Single(document.RootElement.GetProperty("sidecars").EnumerateArray());
        Assert.Equal("fixture.en.srt", sidecar.GetProperty("name").GetString());
        Assert.Equal("en", sidecar.GetProperty("language").GetString());
    }

    private static async Task<SeededMedia> SeedPhysicalVideo(LifecycleFixture fixture, byte[] subtitleBytes, bool addSecond)
    {
        var directory = "subtitle-fixture-" + Guid.NewGuid().ToString("N");
        Directory.CreateDirectory(Path.Combine(fixture.LibraryPath, directory));
        var videoRelative = directory + "/video.mp4";
        var subtitleRelative = directory + "/video.en.srt";
        await File.WriteAllBytesAsync(Path.Combine(fixture.LibraryPath, videoRelative), VideoFixture);
        await File.WriteAllBytesAsync(Path.Combine(fixture.LibraryPath, subtitleRelative), subtitleBytes);
        if (addSecond) await File.WriteAllTextAsync(Path.Combine(fixture.LibraryPath, directory, "video.fr.srt"), "2\n00:00:03,000 --> 00:00:04,000\nBonjour\n", new UTF8Encoding(false));
        var node = Inspect(fixture.LibraryPath, videoRelative);
        var mediaId = Guid.NewGuid();
        var item = new MediaItem
        {
            Id = mediaId, LibraryId = fixture.LibraryId, ParentRelativePath = directory, RelativePath = videoRelative,
            DisplayName = "video.mp4", SearchKey = "video.mp4", Kind = "video", Extension = ".mp4", MimeType = "video/mp4",
            SizeBytes = VideoFixture.Length, MtimeNs = node.MtimeNs, FileIdentity = node.Key, SourceKind = "physical",
            Lifecycle = "available", Version = 1, CreatedAt = fixture.Clock.GetUtcNow(), IndexedAt = fixture.Clock.GetUtcNow()
        };
        await fixture.InDb(async db =>
        {
            db.MediaItems.Add(item);
            db.MediaMetadata.Add(new MediaMetadata { MediaItemId = item.Id, ProbeStatus = "ready", ContentGeneration = item.Version, Container = "mp4", ProbeVersion = "fixture" });
            await db.SaveChangesAsync();
            return 0;
        });
        return new(mediaId, subtitleRelative);
    }

    private static async Task<CreatedPlayback> CreateMediaSession(LifecycleFixture fixture, Guid mediaId)
    {
        using var response = await fixture.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "media", id = mediaId }, mode = "internal", initialPositionMs = 0
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        var root = document.RootElement;
        var sidecars = root.GetProperty("sidecars").EnumerateArray()
            .Select(x => new Sidecar(x.GetProperty("id").GetGuid(), x.GetProperty("name").GetString()!, x.GetProperty("url").GetString()!)).ToArray();
        return new(root.GetProperty("id").GetGuid(), root.GetProperty("streamUrl").GetString(), sidecars);
    }

    private static NodeIdentity Inspect(string rootPath, string relative)
    {
        using var directory = new ContainedDirectory(rootPath);
        using var file = directory.OpenFile(relative);
        return ContainedDirectory.Inspect(file);
    }

    private static DownloadFile SubtitleFile(Guid id, Guid jobId, string path, long bytes, NodeIdentity node, bool completed) => new()
    {
        Id = id, TorrentJobId = jobId, UpstreamFileIndex = path.EndsWith("en.srt", StringComparison.Ordinal) ? 1 : 2,
        MetadataFileIndex = path.EndsWith("en.srt", StringComparison.Ordinal) ? 1 : 2, RelativePath = path, DisplayName = path,
        SizeBytes = bytes, TorrentOffset = LifecycleFixture.FileBytes, PieceFirst = 4, PieceLast = 4, Kind = "subtitle",
        Wanted = true, FilePriority = 7, Completed = completed, PlaybackState = completed ? "complete" : "waitingForData",
        FileIdentity = node.Key, MtimeNs = node.MtimeNs
    };

    private static async Task<HttpResponseMessage> SendSidecar(LifecycleFixture fixture, string url, string? range, HttpMethod? method = null)
    {
        using var request = new HttpRequestMessage(method ?? HttpMethod.Get, url);
        if (range is not null) request.Headers.Range = RangeHeaderValue.Parse(range);
        return await fixture.Client.SendAsync(request);
    }

    private static string Token(string url) => new Uri(url).AbsolutePath.Split('/')[2];
    private static string Replace(string url, string name) => ReplaceTokenAndName(url, Token(url), name);
    private static string ReplaceToken(string url, string token) => ReplaceTokenAndName(url, token, Uri.UnescapeDataString(new Uri(url).AbsolutePath.Split('/')[3]));
    private static string ReplaceTokenAndName(string url, string token, string name)
    {
        var uri = new Uri(url);
        return $"{uri.GetLeftPart(UriPartial.Authority)}/stream/{token}/{Uri.EscapeDataString(name)}";
    }
    private static string Tamper(string token) => token[..^1] + (token[^1] == '0' ? "1" : "0");
    private static string TokenForDifferentFile(string first, string second)
    {
        var a = first.Split('.'); var b = second.Split('.');
        return $"{a[0]}.{a[1]}.{b[2]}.{a[3]}";
    }

    private sealed record SeededMedia(Guid MediaId, string SubtitlePath);
    private sealed record CreatedPlayback(Guid SessionId, string? MainUrl, Sidecar[] Sidecars);
    private sealed record Sidecar(Guid Id, string Name, string Url);
}
