namespace Briani.Api.Modules.Media.Processing;

public sealed class MediaProcessingOptions
{
    public string FfprobePath { get; init; } = "/usr/bin/ffprobe";
    public string FfmpegPath { get; init; } = "/usr/bin/ffmpeg";
    public TimeSpan Timeout { get; init; } = TimeSpan.FromSeconds(20);
    public int MaxOutputBytes { get; init; } = 1024 * 1024;
    public long MaxPixels { get; init; } = 40_000_000;
    public int MaxThumbnailEdge { get; init; } = 480;
    public int MaxThumbnailBytes { get; init; } = 512 * 1024;
    public long CacheBytes { get; init; } = 512L * 1024 * 1024;
    public bool BackgroundScansEnabled { get; init; } = true;
    public int DefaultScanIntervalSeconds { get; init; } = 3600;
    public long MaxAddressSpaceBytes { get; init; } = 1024L * 1024 * 1024;
    public int MaxProcessCpuSeconds { get; init; } = 20;
}
