using System.Globalization;

namespace Briani.Api.Modules.Playback;

public readonly record struct ByteRange(long Start, long End, bool Partial)
{
    public long Length => checked(End - Start + 1);

    public static ByteRange Parse(string? header, long size)
    {
        if (size < 0) throw new ArgumentOutOfRangeException(nameof(size));
        if (string.IsNullOrEmpty(header)) return new(0, size - 1, false);
        if (header.Length > 1024 || !header.StartsWith("bytes=", StringComparison.Ordinal))
            throw new RangeException(false);
        var value = header[6..];
        // RFC 9110 permits ignoring ranges. v1 deliberately ignores multiranges.
        if (value.Contains(',')) return new(0, size - 1, false);
        var parts = value.Split('-');
        if (parts.Length != 2) throw new RangeException(false);
        static long Number(string s) => long.TryParse(s, NumberStyles.None,
            CultureInfo.InvariantCulture, out var n) ? n : throw new RangeException(false);
        if (size == 0) throw new RangeException(true);
        if (parts[0].Length == 0)
        {
            var suffix = Number(parts[1]);
            if (suffix == 0) throw new RangeException(true);
            return new(Math.Max(0, size - suffix), size - 1, true);
        }
        var start = Number(parts[0]);
        var end = parts[1].Length == 0 ? size - 1 : Number(parts[1]);
        if (start >= size || end < start) throw new RangeException(true);
        return new(start, Math.Min(end, size - 1), true);
    }
}

public sealed class RangeException(bool unsatisfiable) : Exception("range_invalid")
{
    public bool Unsatisfiable { get; } = unsatisfiable;
}
