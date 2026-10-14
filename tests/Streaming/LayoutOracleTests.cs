using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Downloads;

namespace Briani.StreamingTests;

public sealed class LayoutOracleTests
{
    private static readonly Guid Job = Guid.Parse("90c5f91f-d0e7-48a8-bad2-a8923ee18f17");

    [Fact]
    public void V1_non_aligned_files_include_padding_and_ignored_neighbor_in_global_piece_offsets()
    {
        var files = new[]
        {
            new MetainfoFile(0, "bundle/clip.mp4", 5, false),
            new MetainfoFile(1, "bundle/.pad/3", 3, true),
            new MetainfoFile(2, "bundle/readme.txt", 2, false)
        };
        AssertLayout(files, pieceLength: 4, v1: true, v2: false, expected: [
            new("bundle/clip.mp4", 0, 0, 1, 0),
            new("bundle/.pad/3", 5, 1, 1, -2),
            new("bundle/readme.txt", 8, 2, 2, 1)
        ]);
    }

    [Fact]
    public void V2_file_address_space_aligns_each_file_even_when_previous_length_is_unaligned()
    {
        const long piece = 16 * 1024;
        var files = new[]
        {
            new MetainfoFile(0, "bundle/first.mkv", piece + 1, false),
            new MetainfoFile(1, "bundle/second.mkv", 7, false)
        };
        AssertLayout(files, piece, v1: false, v2: true, expected: [
            new("bundle/first.mkv", 0, 0, 1, 0),
            new("bundle/second.mkv", 2 * piece, 2, 2, 1)
        ]);
    }

    [Fact]
    public void Hybrid_layout_uses_v1_offsets_and_explicit_padding_without_double_alignment()
    {
        var files = new[]
        {
            new MetainfoFile(0, "bundle/a.mkv", 3, false),
            new MetainfoFile(1, "bundle/.pad/1", 1, true),
            new MetainfoFile(2, "bundle/b.mkv", 2, false)
        };
        AssertLayout(files, pieceLength: 4, v1: true, v2: true, expected: [
            new("bundle/a.mkv", 0, 0, 0, 0),
            new("bundle/.pad/1", 3, 0, 0, -2),
            new("bundle/b.mkv", 4, 1, 1, 1)
        ]);
    }

    [Fact]
    public void Zero_length_file_keeps_empty_piece_interval_and_does_not_advance_offset()
    {
        var files = new[]
        {
            new MetainfoFile(0, "bundle/empty.bin", 0, false),
            new MetainfoFile(1, "bundle/after.mp4", 9, false)
        };
        AssertLayout(files, pieceLength: 4, v1: true, v2: false, expected: [
            new("bundle/empty.bin", 0, 0, -1, 0),
            new("bundle/after.mp4", 0, 0, 2, 1)
        ]);
    }

    [Fact]
    public void Offsets_remain_64_bit_past_four_gibibytes()
    {
        const long piece = 1024 * 1024;
        var files = new[]
        {
            new MetainfoFile(0, "bundle/large.dat", 4L * 1024 * 1024 * 1024 + 1, false),
            new MetainfoFile(1, "bundle/tail.bin", 3, false)
        };
        var mapped = Map(files, piece, v1: true, v2: false);
        Assert.Equal(4L * 1024 * 1024 * 1024 + 1, mapped[1].TorrentOffset);
        Assert.Equal(4096, mapped[1].PieceFirst);
        Assert.Equal(4096, mapped[1].PieceLast);
        Assert.Equal(4097, DownloadLayout.PieceCount(Descriptor(files, piece, true, false)));
    }

    [Fact]
    public void Deterministic_generated_v1_v2_hybrid_layouts_match_independent_offset_oracle()
    {
        var random = new Random(0xB12A);
        for (var sample = 0; sample < 200; sample++)
        {
            var isV2 = sample % 3 == 0;
            var isHybrid = sample % 3 == 1;
            var piece = isV2 ? 16 * 1024L : 128L;
            var files = new List<MetainfoFile>();
            var nextIndex = 0;
            var count = random.Next(1, 12);
            for (var i = 0; i < count; i++)
            {
                var length = random.Next(0, 5 * (int)piece + 1);
                files.Add(new(nextIndex++, $"bundle/item-{i:D2}.bin", length, false));
                if (isHybrid && i + 1 < count)
                {
                    var misalignment = length % piece;
                    if (misalignment != 0)
                        files.Add(new(nextIndex++, $"bundle/.pad/{i:D2}", piece - misalignment, true));
                }
            }
            AssertLayout(files.ToArray(), piece, v1: !isV2, v2: isV2 || isHybrid, expected: Oracle(files, piece, isV2));
        }
    }

    [Fact]
    public void Missing_piece_gaps_never_count_as_available_or_contiguous_bytes()
    {
        var file = new Briani.Api.Modules.Downloads.DownloadFile
        {
            SizeBytes = 3 * 8 + 2,
            TorrentOffset = 5,
            PieceFirst = 0,
            PieceLast = 3
        };
        byte[] bitmap = [2, 0, 2, 0];
        Assert.Equal(11, DownloadLayout.Available(file, 8, bitmap));
        Assert.Equal(3, DownloadLayout.Available(file, 8, bitmap, contiguous: true));
        Assert.Equal(11, OracleAvailable(file.TorrentOffset, file.SizeBytes, 8, bitmap, contiguous: false));
        Assert.Equal(3, OracleAvailable(file.TorrentOffset, file.SizeBytes, 8, bitmap, contiguous: true));
    }

    private static void AssertLayout(MetainfoFile[] files, long pieceLength, bool v1, bool v2, Expected[] expected)
    {
        var actual = Map(files, pieceLength, v1, v2);
        Assert.Equal(expected.Length, actual.Length);
        for (var i = 0; i < expected.Length; i++)
        {
            Assert.Equal(expected[i].Path, actual[i].RelativePath);
            Assert.Equal(expected[i].Offset, actual[i].TorrentOffset);
            Assert.Equal(expected[i].FirstPiece, actual[i].PieceFirst);
            Assert.Equal(expected[i].LastPiece, actual[i].PieceLast);
            Assert.Equal(expected[i].UpstreamIndex, actual[i].UpstreamFileIndex);
        }
    }

    private static Briani.Api.Modules.Downloads.DownloadFile[] Map(MetainfoFile[] files, long pieceLength, bool v1, bool v2)
    {
        var offsets = Oracle(files, pieceLength, !v1 && v2);
        var engine = files.Where(f => !f.Padding).Select((f, upstreamIndex) =>
        {
            var expected = offsets.Single(x => x.Path == f.Path);
            return new EngineFile(upstreamIndex, f.Path, f.Bytes, 0, 0, expected.FirstPiece, expected.LastPiece);
        }).ToArray();
        return DownloadLayout.Map(Job, Descriptor(files, pieceLength, v1, v2), engine);
    }

    private static MetainfoDescriptor Descriptor(MetainfoFile[] files, long pieceLength, bool v1, bool v2) =>
        new("bundle", v1 ? new string('a', 40) : null, v2 ? new string('b', 64) : null, pieceLength, files, []);

    // Oracle uses byte-address boundaries directly and never calls production layout helpers.
    private static Expected[] Oracle(IReadOnlyList<MetainfoFile> files, long pieceLength, bool alignFiles)
    {
        var result = new Expected[files.Count];
        long cursor = 0;
        for (var i = 0; i < files.Count; i++)
        {
            if (alignFiles && cursor % pieceLength != 0)
                cursor += pieceLength - cursor % pieceLength;
            var file = files[i];
            var first = file.Bytes == 0 ? 0 : (int)(cursor / pieceLength);
            var last = file.Bytes == 0 ? -1 : (int)((cursor + file.Bytes - 1) / pieceLength);
            var upstreamIndex = file.Padding ? -file.Index - 1 : files.Take(i + 1).Count(x => !x.Padding) - 1;
            result[i] = new(file.Path, cursor, first, last, upstreamIndex);
            cursor += file.Bytes;
        }
        return result;
    }

    private static long OracleAvailable(long offset, long length, long pieceLength, byte[] bitmap, bool contiguous)
    {
        long total = 0;
        for (long relative = 0; relative < length;)
        {
            var absolute = offset + relative;
            var piece = absolute / pieceLength;
            var take = Math.Min(length - relative, pieceLength - absolute % pieceLength);
            if (piece >= bitmap.Length || bitmap[piece] != 2)
            {
                if (contiguous) break;
            }
            else total += take;
            relative += take;
        }
        return total;
    }

    private sealed record Expected(string Path, long Offset, int FirstPiece, int LastPiece, int UpstreamIndex);
}
