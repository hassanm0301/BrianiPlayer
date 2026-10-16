using System.Diagnostics;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media.Processing;
using Briani.Api.Modules.Media;
using Briani.MediaTests;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Xunit;

namespace Briani.Tests;

public sealed class ProcessingProbeTests
{
    [Fact]
    public async Task ProbeUsesContainedPhotoAndReturnsBoundedJpegThumbnail()
    {
        var root = NewTemp();
        try
        {
            var data = Path.Combine(root, "data"); var state = Path.Combine(root, "state");
            Directory.CreateDirectory(Path.Combine(data, "library")); Directory.CreateDirectory(state);
            var photoPath = Path.Combine(data, "library", "fixture.jpg");
            await RunFfmpegAsync("-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=64x32", "-frames:v", "1", "-threads", "1", photoPath);
            var server = new ServerOptions { DataRoot = data, StateRoot = state };
            using var storage = new ContainedStorage(server);
            var library = new Library { Id = Guid.NewGuid(), RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity };
            NodeIdentity stat; using (var opened = storage.OpenLibrary(library)) stat = opened.Inspect("fixture.jpg");
            var item = new Briani.Api.Modules.Media.MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "fixture.jpg", Extension = ".jpg", FileIdentity = stat.Key, SizeBytes = stat.Length, MtimeNs = stat.MtimeNs };
            var service = new ProbeService(storage, Options.Create(new MediaProcessingOptions()));
            var result = await service.ProbeAsync(item, library, CancellationToken.None);

            Assert.Equal("ready", result.ProbeStatus);
            Assert.Equal(64, result.Width);
            Assert.Equal(32, result.Height);
            Assert.NotNull(result.ThumbnailJpeg);
            Assert.True(result.ThumbnailJpeg!.Length <= 512 * 1024);
            Assert.Equal(0xff, result.ThumbnailJpeg[0]); Assert.Equal(0xd8, result.ThumbnailJpeg[1]);
        }
        finally { Directory.Delete(root, true); }
    }


    [Fact]
    public async Task ProbeReturnsSafePerItemErrorForCorruptPhoto()
    {
        var root = NewTemp();
        try
        {
            var data = Path.Combine(root, "data"); var state = Path.Combine(root, "state");
            Directory.CreateDirectory(Path.Combine(data, "library")); Directory.CreateDirectory(state);
            await File.WriteAllBytesAsync(Path.Combine(data, "library", "broken.jpg"), [1, 2, 3, 4]);
            var server = new ServerOptions { DataRoot = data, StateRoot = state };
            using var storage = new ContainedStorage(server);
            var library = new Library { Id = Guid.NewGuid(), RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity };
            NodeIdentity stat; using (var opened = storage.OpenLibrary(library)) stat = opened.Inspect("broken.jpg");
            var item = new Briani.Api.Modules.Media.MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "broken.jpg", Extension = ".jpg", FileIdentity = stat.Key, SizeBytes = stat.Length, MtimeNs = stat.MtimeNs };
            var service = new ProbeService(storage, Options.Create(new MediaProcessingOptions()));

            var result = await service.ProbeAsync(item, library, CancellationToken.None);

            Assert.Equal("failed", result.ProbeStatus);
            Assert.Null(result.ThumbnailJpeg);
            Assert.Contains(result.ProbeErrorCode, new[] { "probe_failed", "invalid_media" });
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public async Task Probe_marks_content_changed_after_indexing_as_pending()
    {
        var root = NewTemp();
        try
        {
            var data = Path.Combine(root, "data"); var state = Path.Combine(root, "state");
            Directory.CreateDirectory(Path.Combine(data, "library")); Directory.CreateDirectory(state);
            var path = Path.Combine(data, "library", "fixture.jpg");
            await RunFfmpegAsync("-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=64x32", "-frames:v", "1", "-threads", "1", path);
            var server = new ServerOptions { DataRoot = data, StateRoot = state };
            using var storage = new ContainedStorage(server);
            var library = new Library { Id = Guid.NewGuid(), RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity };
            NodeIdentity stat; using (var opened = storage.OpenLibrary(library)) stat = opened.Inspect("fixture.jpg");
            var item = new Briani.Api.Modules.Media.MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "fixture.jpg", Extension = ".jpg", FileIdentity = stat.Key, SizeBytes = stat.Length, MtimeNs = stat.MtimeNs };
            File.SetLastWriteTimeUtc(path, DateTime.UtcNow.AddSeconds(3));
            var service = new ProbeService(storage, Options.Create(new MediaProcessingOptions()));

            var result = await service.ProbeAsync(item, library, CancellationToken.None);

            Assert.Equal("pending", result.ProbeStatus);
            Assert.Equal("media_changed", result.ProbeErrorCode);
            Assert.Null(result.ThumbnailJpeg);
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public async Task Probe_translates_disappearing_source_to_pending_media_changed()
    {
        var root = NewTemp();
        try
        {
            var data = Path.Combine(root, "data"); var state = Path.Combine(root, "state");
            Directory.CreateDirectory(Path.Combine(data, "library")); Directory.CreateDirectory(state);
            var server = new ServerOptions { DataRoot = data, StateRoot = state };
            using var storage = new ContainedStorage(server);
            var library = new Library { Id = Guid.NewGuid(), RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity };
            var item = new Briani.Api.Modules.Media.MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "gone.jpg", Extension = ".jpg", FileIdentity = "1:1:1", SizeBytes = 10, MtimeNs = 1 };
            var service = new ProbeService(storage, Options.Create(new MediaProcessingOptions()));

            var result = await service.ProbeAsync(item, library, CancellationToken.None);

            Assert.Equal("pending", result.ProbeStatus);
            Assert.Equal("media_changed", result.ProbeErrorCode);
            Assert.Null(result.ThumbnailJpeg);
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public async Task Probe_applies_exif_orientation_to_thumbnail_pixels()
    {
        var root = NewTemp();
        try
        {
            var data = Path.Combine(root, "data"); var state = Path.Combine(root, "state");
            Directory.CreateDirectory(Path.Combine(data, "library")); Directory.CreateDirectory(state);
            var image = Path.Combine(data, "library", "oriented.jpg");
            await RunFfmpegAsync("-v", "error", "-f", "lavfi", "-i", "color=c=red:s=32x32", "-f", "lavfi", "-i", "color=c=blue:s=32x32", "-filter_complex", "[0:v][1:v]hstack=inputs=2", "-frames:v", "1", "-threads", "1", image);
            var jpeg = await File.ReadAllBytesAsync(image);
            var app1 = ExifOrientationSegment(6);
            await File.WriteAllBytesAsync(image, [.. jpeg.AsSpan(0, 2).ToArray(), .. app1, .. jpeg.AsSpan(2).ToArray()]);
            var server = new ServerOptions { DataRoot = data, StateRoot = state };
            using var storage = new ContainedStorage(server);
            var library = new Library { Id = Guid.NewGuid(), RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity };
            NodeIdentity stat; using (var opened = storage.OpenLibrary(library)) stat = opened.Inspect("oriented.jpg");
            var item = new Briani.Api.Modules.Media.MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "oriented.jpg", Extension = ".jpg", FileIdentity = stat.Key, SizeBytes = stat.Length, MtimeNs = stat.MtimeNs };
            var service = new ProbeService(storage, Options.Create(new MediaProcessingOptions()));

            var result = await service.ProbeAsync(item, library, CancellationToken.None);

            Assert.Equal("ready", result.ProbeStatus); Assert.Equal(6, result.ExifOrientation); Assert.NotNull(result.ThumbnailJpeg);
            var ppm = await DecodePpmAsync(result.ThumbnailJpeg!);
            var (width, height, pixels) = ParsePpm(ppm);
            Assert.Equal(240, width); Assert.Equal(480, height);
            var stride = width * 3;
            var top = (75 * stride) + 120 * 3; var bottom = (405 * stride) + 120 * 3;
            Assert.True(pixels.Span[top] > pixels.Span[top + 2] * 2, "EXIF orientation 6 should move the red left half to the top.");
            Assert.True(pixels.Span[bottom + 2] > pixels.Span[bottom] * 2, "EXIF orientation 6 should move the blue right half to the bottom.");
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public async Task Scanner_indexes_nested_folders_hides_internal_entries_and_keeps_stable_ids()
    {
        using var host = new TestHost();
        _ = host.Services;
        var dataRoot = Path.Combine(host.Root, "data");
        var libraryPath = Path.Combine(dataRoot, "library");
        var nested = Path.Combine(libraryPath, "Album", "Disc");
        var outside = Path.Combine(host.Root, "outside");
        Directory.CreateDirectory(nested); Directory.CreateDirectory(outside);
        Directory.CreateDirectory(Path.Combine(libraryPath, ".briani"));
        // Backslashes are legal Linux filename bytes but invalid in the contained relative-path API.
        // This malformed entry must not stop the scan from visiting valid entries beside it.
        await File.WriteAllBytesAsync(Path.Combine(libraryPath, "invalid\\name.jpg"), [1, 2, 3]);
        await File.WriteAllBytesAsync(Path.Combine(libraryPath, ".briani", "hidden.jpg"), [1, 2, 3]);
        await File.WriteAllBytesAsync(Path.Combine(libraryPath, ".secret.jpg"), [1, 2, 3]);
        await File.WriteAllBytesAsync(Path.Combine(outside, "escape.jpg"), [1, 2, 3]);
        Directory.CreateSymbolicLink(Path.Combine(libraryPath, "escaped"), outside);
        await RunFfmpegAsync("-v", "error", "-f", "lavfi", "-i", "color=c=green:s=80x40", "-frames:v", "1", "-threads", "1", Path.Combine(nested, "cover.jpg"));

        var storage = host.Services.GetRequiredService<ContainedStorage>();
        var library = new Library { Id = Guid.NewGuid(), Name = "fixture", RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity, CreatedAt = host.Clock.GetUtcNow() };
        await host.InDb(async db => { db.Libraries.Add(library); await db.SaveChangesAsync(); return 0; });
        var scanner = host.Services.GetRequiredService<ScanWorker>();
        var dedup = host.Services.GetRequiredService<SecretStore>().Digest($"scan-library:{library.Id:D}");
        var job = new WorkJob { Kind = "scan", TargetId = library.Id, DedupKey = dedup, PayloadJson = "{}", State = "queued", NextAttemptAt = host.Clock.GetUtcNow(), CreatedAt = host.Clock.GetUtcNow(), UpdatedAt = host.Clock.GetUtcNow() };
        await host.InDb(async db => { db.Jobs.Add(job); await db.SaveChangesAsync(); return 0; });
        Assert.True(await scanner.RunOnceAsync());
        var completed = await host.InDb(async db => await db.Jobs.AsNoTracking().SingleAsync(x => x.Id == job.Id));
        Assert.Equal("completed", completed.State); Assert.Null(completed.DedupKey);
        var first = await host.InDb(async db => await db.MediaItems.AsNoTracking().Where(x => x.LibraryId == library.Id).OrderBy(x => x.RelativePath).ToListAsync());
        var album = Assert.Single(first, x => x.RelativePath == "Album");
        Assert.Equal("folder", album.Kind); Assert.Null(album.ParentId);
        var disc = Assert.Single(first, x => x.RelativePath == "Album/Disc");
        Assert.Equal("folder", disc.Kind); Assert.Equal(album.Id, disc.ParentId);
        var media = Assert.Single(first, x => x.RelativePath == "Album/Disc/cover.jpg");
        Assert.Equal("photo", media.Kind); Assert.Equal(disc.Id, media.ParentId);
        Assert.DoesNotContain(first, x => x.RelativePath.Contains(".briani", StringComparison.Ordinal) || x.RelativePath.Contains(".secret", StringComparison.Ordinal) || x.RelativePath.StartsWith("escaped", StringComparison.Ordinal));
        Assert.DoesNotContain(first, x => x.RelativePath.Contains('\\'));

        var metadata = await host.InDb(async db => await db.MediaMetadata.AsNoTracking().SingleAsync(x => x.MediaItemId == media.Id));
        Assert.Equal("ready", metadata.ProbeStatus);
        var thumb = await host.InDb(async db => await db.ThumbnailEntries.AsNoTracking().SingleAsync(x => x.MediaItemId == media.Id));
        using var state = new ContainedDirectory(Path.Combine(host.Root, "state"));
        Assert.Equal(media.Version, metadata.ContentGeneration);
        Assert.Equal(thumb.FileIdentity, state.Inspect(thumb.CacheRelativePath).Key);
        Assert.NotEqual(media.FileIdentity, thumb.FileIdentity);

        await scanner.ScanLibraryAsync(library.Id);
        var second = await host.InDb(async db => await db.MediaItems.AsNoTracking().Where(x => x.LibraryId == library.Id).OrderBy(x => x.RelativePath).ToListAsync());
        Assert.Equal(first.Select(x => (x.Id, x.Version)), second.Select(x => (x.Id, x.Version)));
    }

    [Fact]
    public async Task Failed_scan_keeps_dedup_for_retries_then_clears_it_when_final()
    {
        using var host = new TestHost(); _ = host.Services;
        var library = new Library { Id = Guid.NewGuid(), Name = "offline", RootPath = "missing", RootIdentity = "missing-root", CreatedAt = host.Clock.GetUtcNow() };
        var dedup = host.Services.GetRequiredService<SecretStore>().Digest($"scan-library:{library.Id:D}");
        var job = new WorkJob { Kind = "scan", TargetId = library.Id, DedupKey = dedup, PayloadJson = "{}", State = "queued", NextAttemptAt = host.Clock.GetUtcNow(), CreatedAt = host.Clock.GetUtcNow(), UpdatedAt = host.Clock.GetUtcNow() };
        await host.InDb(async db => { db.Libraries.Add(library); db.Jobs.Add(job); await db.SaveChangesAsync(); return 0; });
        var scanner = host.Services.GetRequiredService<ScanWorker>();

        for (var attempt = 1; attempt <= 5; attempt++)
        {
            Assert.True(await scanner.RunOnceAsync());
            var current = await host.InDb(async db => await db.Jobs.AsNoTracking().SingleAsync(x => x.Id == job.Id));
            Assert.Equal(attempt, current.Attempt);
            if (attempt < 5) { Assert.Equal("queued", current.State); Assert.Equal(dedup, current.DedupKey); host.Clock.Advance(TimeSpan.FromMinutes(1)); }
            else { Assert.Equal("failed", current.State); Assert.Null(current.DedupKey); }
        }
    }

    [Fact]
    public async Task VideoThumbnailIsTakenPastAnOpeningBlackFrame()
    {
        var root = NewTemp();
        try
        {
            var data = Path.Combine(root, "data"); var state = Path.Combine(root, "state");
            Directory.CreateDirectory(Path.Combine(data, "library")); Directory.CreateDirectory(state);
            var videoPath = Path.Combine(data, "library", "opening.mp4");
            // Ten seconds of blue whose first half second is black, like many film openings.
            await RunFfmpegAsync("-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=64x32:d=10:r=10",
                "-vf", "drawbox=x=0:y=0:w=iw:h=ih:color=black:t=fill:enable='lt(t,0.5)'",
                "-c:v", "libx264", "-g", "5", "-pix_fmt", "yuv420p", "-threads", "1", videoPath);
            var server = new ServerOptions { DataRoot = data, StateRoot = state };
            using var storage = new ContainedStorage(server);
            var library = new Library { Id = Guid.NewGuid(), RootPath = "library", RootIdentity = storage.ValidateLibraryRoot("library").Identity };
            NodeIdentity stat; using (var opened = storage.OpenLibrary(library)) stat = opened.Inspect("opening.mp4");
            var item = new Briani.Api.Modules.Media.MediaItem { Id = Guid.NewGuid(), LibraryId = library.Id, RelativePath = "opening.mp4", Extension = ".mp4", Kind = "video", FileIdentity = stat.Key, SizeBytes = stat.Length, MtimeNs = stat.MtimeNs };
            var service = new ProbeService(storage, Options.Create(new MediaProcessingOptions()));
            var result = await service.ProbeAsync(item, library, CancellationToken.None);

            Assert.Equal("ready", result.ProbeStatus);
            var (_, _, pixels) = ParsePpm(await DecodePpmAsync(Assert.IsType<byte[]>(result.ThumbnailJpeg)));
            var rgb = pixels.ToArray();
            var blue = Enumerable.Range(0, rgb.Length / 3).Average(i => rgb[i * 3 + 2]);
            var red = Enumerable.Range(0, rgb.Length / 3).Average(i => rgb[i * 3]);
            Assert.True(blue > 150 && red < 60, $"thumbnail should be blue, not the black opening (r={red:F0}, b={blue:F0})");
        }
        finally { Directory.Delete(root, true); }
    }

    private static string NewTemp() { var path = Path.Combine(Path.GetTempPath(), "briani-media-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(path); return path; }
    private static byte[] ExifOrientationSegment(ushort orientation) =>
    [0xff, 0xe1, 0x00, 0x22, 0x45, 0x78, 0x69, 0x66, 0, 0,
     0x49, 0x49, 0x2a, 0, 0x08, 0, 0, 0, 0x01, 0, 0x12, 0x01,
     0x03, 0, 0x01, 0, 0, 0, (byte)orientation, (byte)(orientation >> 8), 0, 0, 0, 0, 0, 0];

    private static async Task<byte[]> DecodePpmAsync(byte[] jpeg)
    {
        var start = new ProcessStartInfo("/usr/bin/ffmpeg") { UseShellExecute = false, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var arg in new[] { "-v", "error", "-i", "pipe:0", "-frames:v", "1", "-f", "image2pipe", "-vcodec", "ppm", "pipe:1" }) start.ArgumentList.Add(arg);
        using var process = Process.Start(start) ?? throw new InvalidOperationException("ffmpeg unavailable");
        await process.StandardInput.BaseStream.WriteAsync(jpeg); process.StandardInput.Close();
        using var output = new MemoryStream(); await process.StandardOutput.BaseStream.CopyToAsync(output); await process.WaitForExitAsync();
        if (process.ExitCode != 0) throw new InvalidOperationException("thumbnail decode failed");
        return output.ToArray();
    }

    private static (int Width, int Height, ReadOnlyMemory<byte> Pixels) ParsePpm(byte[] ppm)
    {
        var pos = 0;
        string Token() { while (pos < ppm.Length && char.IsWhiteSpace((char)ppm[pos])) pos++; var begin = pos; while (pos < ppm.Length && !char.IsWhiteSpace((char)ppm[pos])) pos++; return System.Text.Encoding.ASCII.GetString(ppm, begin, pos - begin); }
        Assert.Equal("P6", Token()); var width = int.Parse(Token()); var height = int.Parse(Token()); Assert.Equal("255", Token());
        if (pos < ppm.Length && ppm[pos] == '\r') pos++;
        if (pos < ppm.Length && ppm[pos] == '\n') pos++;
        Assert.InRange(pos, 0, ppm.Length);
        return (width, height, ppm.AsMemory(pos));
    }
    private static async Task RunFfmpegAsync(params string[] args)
    {
        var start = new ProcessStartInfo("/usr/bin/ffmpeg") { UseShellExecute = false, RedirectStandardError = true, RedirectStandardOutput = true };
        foreach (var arg in args) start.ArgumentList.Add(arg);
        using var process = Process.Start(start) ?? throw new InvalidOperationException("ffmpeg unavailable");
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        await process.WaitForExitAsync(timeout.Token);
        if (process.ExitCode != 0) throw new InvalidOperationException("generated fixture failed");
    }
}
