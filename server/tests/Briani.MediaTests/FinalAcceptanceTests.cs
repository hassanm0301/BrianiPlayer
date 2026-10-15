using System.Net;
using System.Net.Http.Json;
using System.Buffers.Binary;
using System.Runtime.Versioning;
using System.Text.Json;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Media.Processing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace Briani.MediaTests;

public sealed class FinalAcceptanceTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();

    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Revoked_read_grant_denies_photo_video_thumbnail_completed_ticket_and_derived_subtitle()
    {
        var rootName = "final-media-" + Guid.NewGuid().ToString("N");
        var libraryPath = Path.Combine(fixture.Host.Root, "data", rootName);
        Directory.CreateDirectory(libraryPath);
        await File.WriteAllBytesAsync(Path.Combine(libraryPath, "poster.jpg"), [11, 22, 33, 44]);
        await File.WriteAllBytesAsync(Path.Combine(libraryPath, "movie.mp4"), [1, 2, 3, 4, 5]);
        await File.WriteAllTextAsync(Path.Combine(libraryPath, "movie.en.srt"), "1\n00:00:01,000 --> 00:00:02,000\nhello\n");

        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var libraryIdentity = storage.ValidateLibraryRoot(rootName);
        var library = new Library
        {
            Id = Guid.NewGuid(), Name = "Final media authorization", RootPath = libraryIdentity.RelativePath,
            RootIdentity = libraryIdentity.Identity, CreatedAt = fixture.Host.Clock.GetUtcNow()
        };
        NodeIdentity photoNode;
        NodeIdentity videoNode;
        using (var directory = storage.OpenLibrary(library))
        {
            using (var photoFile = directory.OpenFile("poster.jpg")) photoNode = ContainedDirectory.Inspect(photoFile);
            using (var videoFile = directory.OpenFile("movie.mp4")) videoNode = ContainedDirectory.Inspect(videoFile);
        }
        var photo = new MediaItem
        {
            Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "poster.jpg", DisplayName = "poster.jpg",
            SearchKey = "POSTER.JPG", Kind = "photo", Extension = ".jpg", MimeType = "image/jpeg",
            SizeBytes = photoNode.Length, MtimeNs = photoNode.MtimeNs, FileIdentity = photoNode.Key,
            Lifecycle = "available", CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow()
        };
        var video = new MediaItem
        {
            Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "movie.mp4", DisplayName = "movie.mp4",
            SearchKey = "MOVIE.MP4", Kind = "video", Extension = ".mp4", MimeType = "video/mp4",
            SizeBytes = videoNode.Length, MtimeNs = videoNode.MtimeNs, FileIdentity = videoNode.Key,
            Lifecycle = "available", CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow()
        };

        const string thumbnailRelativePath = "cache/media/poster.jpg";
        var stateRoot = Path.Combine(fixture.Host.Root, "state");
        Directory.CreateDirectory(Path.Combine(stateRoot, "cache", "media"));
        await File.WriteAllBytesAsync(Path.Combine(stateRoot, thumbnailRelativePath), [90, 91, 92]);
        NodeIdentity thumbnailNode;
        using (var state = new ContainedDirectory(stateRoot))
        using (var thumbnail = state.OpenFile(thumbnailRelativePath)) thumbnailNode = ContainedDirectory.Inspect(thumbnail);

        var password = Credentials.NewToken();
        using var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new
        {
            username = "finalmediareader", displayName = "Final Media Reader", password, confirmPassword = password, role = "member"
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var user = (await created.Content.ReadFromJsonAsync<UserReply>())!;
        using var loginResponse = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new
        {
            username = user.Username, password, deviceName = "final-acceptance"
        });
        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
        var login = (await loginResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        using var member = IdentityFixture.As(fixture.Host.CreateClient(), login.AccessToken);
        using var otherCreated = await admin.PostAsJsonAsync("/api/v1/admin/users", new
        {
            username = "finalmediareader2", displayName = "Other Media Reader", password, confirmPassword = password, role = "member"
        });
        Assert.Equal(HttpStatusCode.Created, otherCreated.StatusCode);
        var otherUser = (await otherCreated.Content.ReadFromJsonAsync<UserReply>())!;
        using var otherLoginResponse = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = otherUser.Username, password, deviceName = "other-user" });
        Assert.Equal(HttpStatusCode.OK, otherLoginResponse.StatusCode);
        var otherLogin = (await otherLoginResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        using var otherMember = IdentityFixture.As(fixture.Host.CreateClient(), otherLogin.AccessToken);

        await fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(library);
            db.MediaItems.AddRange(photo, video);
            db.MediaMetadata.AddRange(
                new MediaMetadata { MediaItemId = photo.Id, ProbeStatus = "ready", ContentGeneration = photo.Version, Width = 2, Height = 2, TracksJson = "[]" },
                new MediaMetadata { MediaItemId = video.Id, ProbeStatus = "ready", ContentGeneration = video.Version, Width = 16, Height = 9, TracksJson = "[]" });
            db.ThumbnailEntries.Add(new ThumbnailEntry
            {
                MediaItemId = photo.Id, Generation = photo.Version, Variant = "default", CacheRelativePath = thumbnailRelativePath,
                FileIdentity = thumbnailNode.Key, Bytes = thumbnailNode.Length,
                CreatedAt = fixture.Host.Clock.GetUtcNow(), LastAccessedAt = fixture.Host.Clock.GetUtcNow()
            });
            db.LibraryGrants.AddRange(new LibraryGrant { UserId = user.Id, LibraryId = library.Id, CanRead = true }, new LibraryGrant { UserId = otherUser.Id, LibraryId = library.Id, CanRead = true });
            await db.SaveChangesAsync();
            return true;
        });

        using (var detail = await member.GetAsync($"/api/v1/media/{photo.Id:D}")) Assert.Equal(HttpStatusCode.OK, detail.StatusCode);
        using (var image = await member.GetAsync($"/api/v1/media/{photo.Id:D}/image")) Assert.Equal(HttpStatusCode.OK, image.StatusCode);
        using (var thumbnail = await member.GetAsync($"/api/v1/media/{photo.Id:D}/thumbnail")) Assert.Equal(HttpStatusCode.OK, thumbnail.StatusCode);
        using (var videoDetail = await member.GetAsync($"/api/v1/media/{video.Id:D}")) Assert.Equal(HttpStatusCode.OK, videoDetail.StatusCode);

        using var sessionResponse = await member.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "media", id = video.Id }, mode = "internal"
        });
        Assert.Equal(HttpStatusCode.Created, sessionResponse.StatusCode);
        using var sessionJson = JsonDocument.Parse(await sessionResponse.Content.ReadAsStringAsync());
        var sessionId = sessionJson.RootElement.GetProperty("id").GetGuid();
        var streamPath = new Uri(sessionJson.RootElement.GetProperty("streamUrl").GetString()!).PathAndQuery;
        var sidecar = Assert.Single(sessionJson.RootElement.GetProperty("sidecars").EnumerateArray().ToArray());
        Assert.Equal("movie.en.srt", sidecar.GetProperty("name").GetString());
        var subtitleUrl = sidecar.GetProperty("url").GetString()!;
        using (var foreignStatus = await otherMember.GetAsync($"/api/v1/playback/sessions/{sessionId:D}")) Assert.Equal(HttpStatusCode.NotFound, foreignStatus.StatusCode);
        using (var stream = await fixture.Host.CreateClient().GetAsync(streamPath)) Assert.Equal(HttpStatusCode.OK, stream.StatusCode);
        using (var subtitle = await fixture.Host.CreateClient().GetAsync(subtitleUrl)) Assert.Equal(HttpStatusCode.OK, subtitle.StatusCode);

        // The URLs are bearer-bound to this owner's session; these anonymous
        // requests test whether that owner's current library grant is still live.
        for (var bits = 0; bits < 8; bits++)
        {
            var canRead = (bits & 1) != 0;
            await fixture.Host.InDb(async db =>
            {
                var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == user.Id && x.LibraryId == library.Id);
                grant.CanRead = canRead; grant.CanDownload = (bits & 2) != 0; grant.CanManage = (bits & 4) != 0;
                await db.SaveChangesAsync(); return true;
            });
            var expected = canRead ? HttpStatusCode.OK : HttpStatusCode.NotFound;
            using (var photoDetail = await member.GetAsync($"/api/v1/media/{photo.Id:D}")) Assert.Equal(expected, photoDetail.StatusCode);
            using (var videoDetail = await member.GetAsync($"/api/v1/media/{video.Id:D}")) Assert.Equal(expected, videoDetail.StatusCode);
            using (var image = await member.GetAsync($"/api/v1/media/{photo.Id:D}/image")) Assert.Equal(expected, image.StatusCode);
            using (var thumbnail = await member.GetAsync($"/api/v1/media/{photo.Id:D}/thumbnail")) Assert.Equal(expected, thumbnail.StatusCode);
            using (var status = await member.GetAsync($"/api/v1/playback/sessions/{sessionId:D}")) Assert.Equal(expected, status.StatusCode);
            using (var stream = await fixture.Host.CreateClient().GetAsync(streamPath)) Assert.Equal(expected, stream.StatusCode);
            using (var subtitle = await fixture.Host.CreateClient().GetAsync(subtitleUrl)) Assert.Equal(expected, subtitle.StatusCode);
            using (var foreignStatus = await otherMember.GetAsync($"/api/v1/playback/sessions/{sessionId:D}")) Assert.Equal(HttpStatusCode.NotFound, foreignStatus.StatusCode);
        }

        await fixture.Host.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == user.Id && x.LibraryId == library.Id);
            grant.CanRead = false;
            await db.SaveChangesAsync();
            return true;
        });

        using (var photoDetail = await member.GetAsync($"/api/v1/media/{photo.Id:D}")) Assert.Equal(HttpStatusCode.NotFound, photoDetail.StatusCode);
        using (var videoDetail = await member.GetAsync($"/api/v1/media/{video.Id:D}")) Assert.Equal(HttpStatusCode.NotFound, videoDetail.StatusCode);
        using (var image = await member.GetAsync($"/api/v1/media/{photo.Id:D}/image")) Assert.Equal(HttpStatusCode.NotFound, image.StatusCode);
        using (var thumbnail = await member.GetAsync($"/api/v1/media/{photo.Id:D}/thumbnail")) Assert.Equal(HttpStatusCode.NotFound, thumbnail.StatusCode);
        using (var status = await member.GetAsync($"/api/v1/playback/sessions/{sessionId:D}")) Assert.Equal(HttpStatusCode.NotFound, status.StatusCode);
        using (var stream = await fixture.Host.CreateClient().GetAsync(streamPath)) Assert.Equal(HttpStatusCode.NotFound, stream.StatusCode);
        using (var subtitle = await fixture.Host.CreateClient().GetAsync(subtitleUrl)) Assert.Equal(HttpStatusCode.NotFound, subtitle.StatusCode);
    }

    [Fact]
    [SupportedOSPlatform("linux")]
    public async Task Oversized_image_header_is_bounded_before_thumbnail_decoder_runs()
    {
        var root = Path.Combine(Path.GetTempPath(), "briani-media-oversize-" + Guid.NewGuid().ToString("N"));
        var data = Path.Combine(root, "data");
        var state = Path.Combine(root, "state");
        var marker = Path.Combine(root, "thumbnail-process-started");
        var fakeFfmpeg = Path.Combine(root, "ffmpeg-marker.sh");
        try
        {
            Directory.CreateDirectory(Path.Combine(data, "library"));
            Directory.CreateDirectory(state);
            // Header-only PNG. The claimed dimensions exceed the 40-million-pixel
            // cap while the fixture remains only a few dozen bytes on disk.
            var header = OversizedPngHeader(20_001, 20_001);
            await File.WriteAllBytesAsync(Path.Combine(data, "library", "oversized.png"), header);
            var markerScript = $"#!/bin/sh\nprintf called > '{marker}'\nexit 0\n";
            await File.WriteAllTextAsync(fakeFfmpeg, markerScript);
            File.SetUnixFileMode(fakeFfmpeg, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);

            var options = new Briani.Api.Infrastructure.ServerOptions { DataRoot = data, StateRoot = state };
            using var storage = new ContainedStorage(options);
            var library = new Library { Id = Guid.NewGuid(), RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity };
            NodeIdentity stat;
            using (var opened = storage.OpenLibrary(library)) stat = opened.Inspect("oversized.png");
            var item = new MediaItem
            {
                Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "oversized.png", Extension = ".png",
                FileIdentity = stat.Key, SizeBytes = stat.Length, MtimeNs = stat.MtimeNs
            };
            var service = new ProbeService(storage, Options.Create(new MediaProcessingOptions { FfmpegPath = fakeFfmpeg }));

            var result = await service.ProbeAsync(item, library, CancellationToken.None);

            Assert.Equal("failed", result.ProbeStatus);
            Assert.Equal("invalid_media", result.ProbeErrorCode);
            Assert.Null(result.ThumbnailJpeg);
            Assert.False(File.Exists(marker), "oversized dimensions must stop before FFmpeg thumbnail decoding");
            Assert.Equal(header.Length, new FileInfo(Path.Combine(data, "library", "oversized.png")).Length);
        }
        finally
        {
            if (Directory.Exists(root)) Directory.Delete(root, true);
        }
    }

    private static byte[] OversizedPngHeader(uint width, uint height)
    {
        using var output = new MemoryStream();
        output.Write([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
        var ihdr = new byte[13];
        BinaryPrimitives.WriteUInt32BigEndian(ihdr.AsSpan(0, 4), width);
        BinaryPrimitives.WriteUInt32BigEndian(ihdr.AsSpan(4, 4), height);
        ihdr[8] = 8; // bit depth
        ihdr[9] = 2; // truecolor
        WritePngChunk(output, "IHDR", ihdr);
        WritePngChunk(output, "IEND", []);
        return output.ToArray();
    }

    private static void WritePngChunk(Stream output, string type, byte[] data)
    {
        Span<byte> length = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32BigEndian(length, checked((uint)data.Length));
        output.Write(length);
        var typeBytes = System.Text.Encoding.ASCII.GetBytes(type);
        output.Write(typeBytes);
        output.Write(data);
        var crc = 0xffffffffu;
        foreach (var value in typeBytes.Concat(data))
        {
            crc ^= value;
            for (var bit = 0; bit < 8; bit++) crc = (crc >> 1) ^ ((crc & 1) == 0 ? 0u : 0xedb88320u);
        }
        Span<byte> checksum = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32BigEndian(checksum, ~crc);
        output.Write(checksum);
    }
}
