namespace Briani.Api.Modules.Media.Processing;

public sealed record ProbeTrack(string Id, string Kind, string? Language, string? Title, string? Codec, bool Default);

public sealed record ProbeResult(
    long? DurationMs,
    int? Width,
    int? Height,
    int? Rotation,
    int? ExifOrientation,
    string? VideoCodec,
    IReadOnlyList<ProbeTrack> Tracks,
    string Container,
    string ProbeVersion,
    string ProbeStatus,
    string? ProbeErrorCode,
    byte[]? ThumbnailJpeg);
