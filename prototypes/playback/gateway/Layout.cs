namespace Briani.PlaybackProof;

public sealed record FileLayout(string Id, int UpstreamIndex, string Path,
    long Length, long TorrentOffset, bool Padding = false, int Priority = 1);

public sealed class TorrentLayout
{
    public long Generation { get; }
    public int PieceLength { get; }
    public int PieceCount { get; }
    public IReadOnlyList<FileLayout> Files { get; }
    public TorrentLayout(long generation, int pieceLength, int pieceCount, IReadOnlyList<FileLayout> files)
    {
        if (generation < 1 || pieceLength < 16384 || pieceLength > 64 * 1024 * 1024 || pieceCount < 1)
            throw new ArgumentException("layout_unverified");
        var ids = new HashSet<string>();
        long previousEnd = 0;
        foreach (var f in files)
        {
            var end = checked(f.TorrentOffset + f.Length);
            if (!ids.Add(f.Id) || f.Length < 0 || f.TorrentOffset < previousEnd ||
                end > checked((long)pieceLength * pieceCount)) throw new ArgumentException("layout_unverified");
            ValidatePath(f.Path);
            previousEnd = end;
        }
        Generation = generation; PieceLength = pieceLength; PieceCount = pieceCount;
        Files = Array.AsReadOnly(files.ToArray());
    }
    public static void ValidatePath(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || path.Length > 4096 || path.StartsWith('/') ||
            path.Contains('\\') || path.Contains('\0') || path.Contains(':') ||
            path.Split('/').Any(p => p.Length == 0 || p is "." or ".." || p == ".briani"))
            throw new ArgumentException("path_invalid");
    }
    public (int Piece, int Count) Slice(FileLayout file, long offset, int requested)
    {
        if (offset < 0 || offset >= file.Length || requested < 1) throw new ArgumentOutOfRangeException(nameof(offset));
        var global = checked(file.TorrentOffset + offset);
        var piece = checked((int)(global / PieceLength));
        var count = (int)Math.Min(Math.Min((long)requested, file.Length - offset), PieceLength - global % PieceLength);
        return (piece, count);
    }
}
