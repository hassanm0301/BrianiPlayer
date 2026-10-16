using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Microsoft.Extensions.Options;

namespace Briani.Api.Modules.Media.Processing;

public sealed class ProbeService(ContainedStorage storage, IOptions<MediaProcessingOptions> configured)
{
    private static readonly SemaphoreSlim ProbeSlots = new(1, 1);
    private static readonly SemaphoreSlim ThumbnailSlots = new(1, 1);
    private readonly MediaProcessingOptions options = configured.Value;
    private static readonly HashSet<string> VideoExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".mp4", ".m4v", ".mkv", ".webm", ".mov", ".avi", ".mpeg", ".mpg", ".ts", ".m2ts", ".ogv", ".3gp" };
    private static readonly HashSet<string> ImageExtensions = new(StringComparer.OrdinalIgnoreCase)
        { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".avif" };
    private static readonly string[] AllowedProtocols = ["file"];
    private static readonly string[] AllowedDemuxers = ["mov", "matroska", "webm", "avi", "mpeg", "mpegts", "ogg", "png_pipe", "jpeg_pipe", "webp_pipe", "bmp_pipe", "tiff_pipe", "gif"];
    private int PixelLimit => (int)Math.Clamp(options.MaxPixels, 1, 40_000_000);
    private int ThumbnailEdge => Math.Clamp(options.MaxThumbnailEdge, 1, 480);
    private int ProbeOutputLimit => Math.Clamp(options.MaxOutputBytes, 1, 1024 * 1024);
    private int ThumbnailOutputLimit => Math.Clamp(options.MaxThumbnailBytes, 1, 512 * 1024);
    private TimeSpan ProcessTimeout => options.Timeout <= TimeSpan.Zero || options.Timeout > TimeSpan.FromSeconds(20) ? TimeSpan.FromSeconds(20) : options.Timeout;
    private long AddressSpaceLimit => Math.Clamp(options.MaxAddressSpaceBytes, 64L * 1024 * 1024, 1024L * 1024 * 1024);
    private int CpuLimitSeconds => Math.Clamp(options.MaxProcessCpuSeconds, 1, 20);

    public async Task<ProbeResult> ProbeAsync(MediaItem item, Library library, CancellationToken cancellationToken)
    {
        var ext = Path.GetExtension(item.RelativePath);
        var video = VideoExtensions.Contains(ext);
        if (!video && !ImageExtensions.Contains(ext)) return Failed("unsupported_format", "unsupported");
        try
        {
            using var root = storage.OpenLibrary(library);
            FileStream source;
            try { source = root.OpenFile(item.RelativePath, item.FileIdentity); }
            catch (ApiException e) when (e.Code is "path_unavailable" or "file_identity_changed" or "invalid_path") { return Changed(); }
            using (source)
            {
            if (!MatchesCurrentNode(source, item)) return Changed();
            int? exifOrientation = null;
            if (ext.Equals(".jpg", StringComparison.OrdinalIgnoreCase) || ext.Equals(".jpeg", StringComparison.OrdinalIgnoreCase))
            {
                var header = new byte[64 * 1024]; var read = await source.ReadAsync(header, cancellationToken); source.Position = 0;
                exifOrientation = ReadExifOrientation(header.AsSpan(0, read));
            }
            var procPath = $"/proc/{Environment.ProcessId}/fd/{source.SafeFileHandle.DangerousGetHandle().ToInt32()}";
            await ProbeSlots.WaitAsync(cancellationToken);
            try
            {
                var args = new List<string> { "-v", "error", "-protocol_whitelist", string.Join(',', AllowedProtocols), "-format_whitelist", string.Join(',', AllowedDemuxers), "-max_pixels", PixelLimit.ToString(CultureInfo.InvariantCulture), "-threads", "1", "-show_entries", "format=format_name,duration:stream=index,codec_type,codec_name,width,height:stream_tags=language,title:stream_disposition=default:stream_side_data=rotation", "-of", "json", procPath };
                var result = await RunBoundedAsync(options.FfprobePath, args, ProbeOutputLimit, cancellationToken);
                if (!MatchesCurrentNode(source, item)) return Changed();
                if (result.ExitCode != 0) return Failed("probe_failed");
                var parsed = ParseProbe(result.Stdout, item, video);
                if (parsed.ProbeStatus != "ready") return parsed;
                byte[]? thumb = null;
                if (parsed.Width is > 0 && parsed.Height is > 0 && checked((long)parsed.Width * parsed.Height) <= PixelLimit)
                {
                    await ThumbnailSlots.WaitAsync(cancellationToken);
                    try { source.Position = 0; thumb = await MakeThumbnailAsync(procPath, video, exifOrientation, parsed.DurationMs, cancellationToken); }
                    catch (Exception e) when (e is InvalidDataException or IOException or JsonException or InvalidOperationException or TimeoutException) { }
                    finally { ThumbnailSlots.Release(); }
                }
                if (!MatchesCurrentNode(source, item)) return Changed();
                return parsed with { ThumbnailJpeg = thumb, ExifOrientation = exifOrientation };
            }
            finally { ProbeSlots.Release(); }
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
        catch (TimeoutException) { return Failed("probe_timeout"); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.ComponentModel.Win32Exception or InvalidDataException or JsonException or InvalidOperationException or OverflowException)
        { return Failed("probe_failed"); }
    }

    private static bool MatchesCurrentNode(FileStream source, MediaItem item)
    {
        var current = ContainedDirectory.Inspect(source);
        return current.IsFile && current.Key == item.FileIdentity && item.SizeBytes == current.Length && item.MtimeNs == current.MtimeNs;
    }

    private static ProbeResult ParseProbe(byte[] bytes, MediaItem item, bool video)
    {
        using var doc = JsonDocument.Parse(bytes, new JsonDocumentOptions { MaxDepth = 16 });
        var root = doc.RootElement;
        var format = root.TryGetProperty("format", out var f) ? f : default;
        var streams = root.TryGetProperty("streams", out var s) && s.ValueKind == JsonValueKind.Array ? s.EnumerateArray().Take(32).ToArray() : [];
        var selected = video ? streams.FirstOrDefault(x => GetString(x, "codec_type") == "video") : streams.FirstOrDefault();
        int? width = GetInt(selected, "width"), height = GetInt(selected, "height");
        if (width is <= 0 or > 20000 || height is <= 0 or > 20000) return Failed("invalid_media");
        var dur = ParseSeconds(GetString(format, "duration"));
        var tracks = streams.Select((x, i) => (Stream: x, Index: i, Kind: GetString(x, "codec_type")))
            .Where(x => x.Kind is "video" or "audio" or "subtitle")
            .Select(x => new ProbeTrack(
                BoundString(GetString(x.Stream, "index") ?? x.Index.ToString(CultureInfo.InvariantCulture), 64)!, x.Kind!,
                BoundString(GetNestedString(x.Stream, "tags", "language"), 64), BoundString(GetNestedString(x.Stream, "tags", "title"), 256),
                BoundString(GetString(x.Stream, "codec_name"), 128), GetNestedBool(x.Stream, "disposition", "default") ?? false)).ToArray();
        int? rotation = null;
        foreach (var stream in streams)
        {
            if (!stream.TryGetProperty("side_data_list", out var sides) || sides.ValueKind != JsonValueKind.Array) continue;
            foreach (var side in sides.EnumerateArray()) if (GetInt(side, "rotation") is int r) { rotation = ((r % 360) + 360) % 360; break; }
        }
        return new(dur, width, height, rotation, null, BoundString(GetString(selected, "codec_name"), 128), tracks,
            BoundString(GetString(format, "format_name") ?? item.Extension.TrimStart('.').ToLowerInvariant(), 128)!, "ffprobe", "ready", null, null);
    }

    /// Where a video thumbnail is taken: 10% in (at most ten minutes), because
    /// the first frame of many films is black. An input seek is keyframe-based,
    /// so the cost stays within the bounded thumbnail budget.
    internal static TimeSpan ThumbnailPosition(long? durationMs) =>
        durationMs is > 0 ? TimeSpan.FromMilliseconds(Math.Min(durationMs.Value / 10, 600_000)) : TimeSpan.Zero;

    private async Task<byte[]?> MakeThumbnailAsync(string procPath, bool video, int? exifOrientation, long? durationMs, CancellationToken ct)
    {
        var transforms = video ? "" : exifOrientation switch
        {
            2 => "hflip,", 3 => "hflip,vflip,", 4 => "vflip,", 5 => "transpose=clock,hflip,",
            6 => "transpose=clock,", 7 => "transpose=clock,vflip,", 8 => "transpose=cclock,", _ => ""
        };
        var filter = $"{transforms}scale={ThumbnailEdge}:{ThumbnailEdge}:force_original_aspect_ratio=decrease";
        var args = new List<string> { "-v", "error", "-nostdin", "-noautorotate", "-protocol_whitelist", string.Join(',', AllowedProtocols), "-format_whitelist", string.Join(',', AllowedDemuxers), "-max_pixels", PixelLimit.ToString(CultureInfo.InvariantCulture), "-threads", "1", "-filter_threads", "1", "-i", procPath, "-frames:v", "1", "-vf", filter, "-f", "image2pipe", "-vcodec", "mjpeg", "-threads", "1", "pipe:1" };
        var position = video ? ThumbnailPosition(durationMs) : TimeSpan.Zero;
        if (position > TimeSpan.Zero)
            args.InsertRange(args.IndexOf("-i"), ["-ss", position.TotalSeconds.ToString("0.###", CultureInfo.InvariantCulture)]);
        var p = await RunBoundedAsync(options.FfmpegPath, args, ThumbnailOutputLimit, ct);
        if (position > TimeSpan.Zero && (p.ExitCode != 0 || !IsJpeg(p.Stdout)))
        {
            // A damaged or unseekable file may still decode from the start.
            args.RemoveRange(args.IndexOf("-ss"), 2);
            p = await RunBoundedAsync(options.FfmpegPath, args, ThumbnailOutputLimit, ct);
        }
        if (p.ExitCode != 0 || !IsJpeg(p.Stdout)) return null;
        return p.Stdout;
    }

    private async Task<ProcessOutput> RunBoundedAsync(string executable, IReadOnlyList<string> args, int cap, CancellationToken ct)
    {
        var start = new ProcessStartInfo("/usr/bin/prlimit") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        start.Environment.Clear(); start.Environment["PATH"] = "/usr/bin:/bin"; start.Environment["LANG"] = "C";
        start.ArgumentList.Add($"--as={AddressSpaceLimit}");
        start.ArgumentList.Add($"--cpu={CpuLimitSeconds}");
        start.ArgumentList.Add("--");
        start.ArgumentList.Add(executable);
        foreach (var arg in args) start.ArgumentList.Add(arg);
        using var process = new Process { StartInfo = start, EnableRaisingEvents = true };
        if (!process.Start()) throw new InvalidOperationException();
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(ProcessTimeout);
        var stdout = ReadCappedAsync(process.StandardOutput.BaseStream, cap, timeout.Token);
        var stderr = DrainCappedAsync(process.StandardError.BaseStream, 64 * 1024, timeout.Token);
        try
        {
            var exit = process.WaitForExitAsync(timeout.Token);
            var outputDone = false; var errorDone = false;
            while (!exit.IsCompleted)
            {
                var pending = new List<Task> { exit };
                if (!outputDone) pending.Add(stdout);
                if (!errorDone) pending.Add(stderr);
                var completed = await Task.WhenAny(pending);
                if (completed == stdout) { _ = await stdout; outputDone = true; }
                if (completed == stderr) { await stderr; errorDone = true; }
            }
            await exit;
            var output = await stdout;
            await stderr;
            return new(output, process.ExitCode);
        }
        catch (OperationCanceledException)
        {
            try { process.Kill(true); } catch { }
            try { await process.WaitForExitAsync(CancellationToken.None); } catch (InvalidOperationException) { }
            await IgnoreAsync(stdout); await IgnoreAsync(stderr);
            if (ct.IsCancellationRequested) throw;
            throw new TimeoutException();
        }
        catch
        {
            try { if (!process.HasExited) process.Kill(true); } catch { }
            try { await process.WaitForExitAsync(CancellationToken.None); } catch (InvalidOperationException) { }
            await IgnoreAsync(stdout); await IgnoreAsync(stderr);
            throw;
        }
        finally { if (!process.HasExited) { try { process.Kill(true); } catch { } } }
    }

    private static async Task<byte[]> ReadCappedAsync(Stream stream, int cap, CancellationToken ct)
    {
        using var ms = new MemoryStream(Math.Min(cap, 65536)); var buf = new byte[8192];
        while (true) { var n = await stream.ReadAsync(buf, ct); if (n == 0) break; if (ms.Length + n > cap) throw new InvalidDataException("output_cap"); ms.Write(buf, 0, n); }
        return ms.ToArray();
    }
    private static async Task DrainCappedAsync(Stream stream, int cap, CancellationToken ct)
    {
        var buf = new byte[4096]; var total = 0;
        while (true) { var n = await stream.ReadAsync(buf, ct); if (n == 0) break; total += n; if (total > cap) throw new InvalidDataException("stderr_cap"); }
    }
    private static async Task IgnoreAsync(Task task) { try { await task; } catch { } }
    private static long? ParseSeconds(string? value) => double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var d) && d >= 0 && d <= long.MaxValue / 1000d ? (long)Math.Round(d * 1000) : null;
    private static string? GetString(JsonElement e, string name) => e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var p) && p.ValueKind == JsonValueKind.String ? p.GetString() : e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out p) && p.ValueKind == JsonValueKind.Number ? p.ToString() : null;
    private static int? GetInt(JsonElement e, string n) => e.ValueKind == JsonValueKind.Object && e.TryGetProperty(n, out var p) && p.TryGetInt32(out var i) ? i : null;
    private static string? GetNestedString(JsonElement e, string a, string b) => e.TryGetProperty(a, out var p) ? GetString(p, b) : null;
    private static bool? GetNestedBool(JsonElement e, string a, string b) => e.TryGetProperty(a, out var p) && p.TryGetProperty(b, out var q) && q.ValueKind == JsonValueKind.Number ? q.GetInt32() != 0 : null;
    private static string? BoundString(string? value, int max) => value is null ? null : new string(value.Where(c => !char.IsControl(c)).Take(max).ToArray());
    private static bool IsJpeg(byte[] b) => b.Length >= 4 && b[0] == 0xff && b[1] == 0xd8 && b[^2] == 0xff && b[^1] == 0xd9;
    private static int? ReadExifOrientation(ReadOnlySpan<byte> bytes)
    {
        if (bytes.Length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return null;
        var p = 2;
        while (p + 4 <= bytes.Length)
        {
            if (bytes[p++] != 0xff) return null;
            var marker = bytes[p++]; if (marker is 0xd9 or 0xda) return null;
            var length = (bytes[p] << 8) | bytes[p + 1]; if (length < 2 || p + length > bytes.Length) return null;
            var data = bytes.Slice(p + 2, length - 2);
            if (marker == 0xe1 && data.Length >= 14 && data[..6].SequenceEqual("Exif\0\0"u8))
            {
                var tiff = data[6..]; var little = tiff[0] == (byte)'I' && tiff[1] == (byte)'I';
                if (!little && !(tiff[0] == (byte)'M' && tiff[1] == (byte)'M')) return null;
                if (ReadU16(tiff, 2, little) != 42) return null;
                var ifd = ReadU32(tiff, 4, little); if (ifd > int.MaxValue || ifd + 2 > tiff.Length) return null;
                var at = (int)ifd; var count = Math.Min(ReadU16(tiff, at, little), (ushort)256); at += 2;
                for (var i = 0; i < count && at + 12 <= tiff.Length; i++, at += 12)
                    if (ReadU16(tiff, at, little) == 0x0112 && ReadU16(tiff, at + 2, little) == 3 && ReadU32(tiff, at + 4, little) == 1)
                    { var value = ReadU16(tiff, at + 8, little); return value is >= 1 and <= 8 ? value : null; }
                return null;
            }
            p += length;
        }
        return null;
    }
    private static ushort ReadU16(ReadOnlySpan<byte> data, int i, bool little) => little ? (ushort)(data[i] | data[i + 1] << 8) : (ushort)(data[i] << 8 | data[i + 1]);
    private static uint ReadU32(ReadOnlySpan<byte> data, int i, bool little) => little ? (uint)(data[i] | data[i + 1] << 8 | data[i + 2] << 16 | data[i + 3] << 24) : (uint)(data[i] << 24 | data[i + 1] << 16 | data[i + 2] << 8 | data[i + 3]);
    private static ProbeResult Failed(string code, string status = "failed") => new(null, null, null, null, null, null, [], "", "ffprobe", status, code, null);
    private static ProbeResult Changed() => new(null, null, null, null, null, null, [], "", "ffprobe", "pending", "media_changed", null);
    private sealed record ProcessOutput(byte[] Stdout, int ExitCode);
}
