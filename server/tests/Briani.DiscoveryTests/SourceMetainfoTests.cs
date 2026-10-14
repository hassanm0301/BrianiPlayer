using System.Security.Cryptography;
using System.Text;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Discovery.Sources;

namespace Briani.DiscoveryTests;

public sealed class SourceMetainfoTests
{
    [Fact]
    public void V1_v2_and_hybrid_infohashes_are_hashes_of_original_bencoded_info_dictionary()
    {
        var v1 = TorrentFixture.CreateV1("sample.mkv", [1, 2, 3]);
        var v1Parsed = Metainfo.Parse(v1.Bytes);
        Assert.Equal(Convert.ToHexString(SHA1.HashData(v1.InfoBytes)).ToLowerInvariant(), v1Parsed.InfoHashV1);
        Assert.Null(v1Parsed.InfoHashV2);
        Assert.Equal("sample.mkv", Assert.Single(v1Parsed.Files).Path);

        var v2 = TorrentFixture.CreateV2("sample.mkv", [1, 2, 3]);
        var v2Parsed = Metainfo.Parse(v2.Bytes);
        Assert.Equal(Convert.ToHexString(SHA256.HashData(v2.InfoBytes)).ToLowerInvariant(), v2Parsed.InfoHashV2);
        Assert.Null(v2Parsed.InfoHashV1);

        var hybrid = TorrentFixture.CreateHybrid("sample.mkv", [1, 2, 3]);
        var parsedHybrid = Metainfo.Parse(hybrid.Bytes);
        Assert.Equal(Convert.ToHexString(SHA1.HashData(hybrid.InfoBytes)).ToLowerInvariant(), parsedHybrid.InfoHashV1);
        Assert.Equal(Convert.ToHexString(SHA256.HashData(hybrid.InfoBytes)).ToLowerInvariant(), parsedHybrid.InfoHashV2);
        Assert.Equal("sample.mkv", Assert.Single(parsedHybrid.Files).Path);
    }

    [Fact]
    public void Valid_multifile_paths_preserve_unicode_and_padding_metadata()
    {
        var torrent = TorrentFixture.CreateV1Multi("Collection", [("日本語/film.mkv", [1, 2], ""), (".pad/16382", new byte[16382], "p")]);
        var parsed = Metainfo.Parse(torrent.Bytes);
        Assert.Equal(2, parsed.Files.Length);
        Assert.Contains(parsed.Files, f => f.Path == "Collection/日本語/film.mkv" && !f.Padding);
        Assert.Contains(parsed.Files, f => f.Padding && f.Bytes == 16382);
    }

    [Theory]
    [InlineData("traversal")]
    [InlineData("device")]
    [InlineData("trailing-dot")]
    [InlineData("symlink")]
    [InlineData("duplicate-case")]
    [InlineData("duplicate-unicode")]
    [InlineData("piece-length")]
    [InlineData("pieces-length")]
    [InlineData("deep-path")]
    [InlineData("oversized")]
    [InlineData("web-seed")]
    public void Unsafe_or_inconsistent_v1_metainfo_is_rejected(string kind)
    {
        byte[] bytes = kind switch
        {
            "traversal" => TorrentFixture.CreateV1("../escape.mkv", [1]).Bytes,
            "device" => TorrentFixture.CreateV1("CON.mkv", [1]).Bytes,
            "trailing-dot" => TorrentFixture.CreateV1("trailing..", [1]).Bytes,
            "symlink" => TorrentFixture.CreateV1Symlink().Bytes,
            "duplicate-case" => TorrentFixture.CreateV1Multi("set", [("Movie.mkv", [1]), ("movie.mkv", [2])]).Bytes,
            "duplicate-unicode" => TorrentFixture.CreateV1Multi("set", [("é.mkv", [1]), ("e\u0301.mkv", [2])]).Bytes,
            "piece-length" => TorrentFixture.CreateV1("movie.mkv", [1], pieceLength: 0, pieceBytes: []).Bytes,
            "pieces-length" => TorrentFixture.CreateV1("movie.mkv", [1], pieceBytes: new byte[40]).Bytes,
            "deep-path" => TorrentFixture.CreateV1Multi("set", [(string.Join('/', Enumerable.Repeat("dir", 65)) + "/movie.mkv", [1])]).Bytes,
            "oversized" => TorrentFixture.CreateV1("movie.mkv", [1], length: 1L << 34).Bytes,
            "web-seed" => TorrentFixture.CreateV1("movie.mkv", [1], webSeed: "https://example.org/file").Bytes,
            _ => throw new ArgumentOutOfRangeException(nameof(kind))
        };
        var error = Assert.Throws<ApiException>(() => Metainfo.Parse(bytes));
        Assert.Equal(kind == "web-seed" ? "unsafe_metainfo_source" : "invalid_metainfo", error.Code);
    }

    [Fact]
    public void Duplicate_dictionary_keys_and_invalid_piece_layer_lengths_are_rejected()
    {
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(Encoding.ASCII.GetBytes("d4:infod4:name1:x4:name1:yee"))).Code);
        var large = new byte[16385];
        var missingLayer = TorrentFixture.CreateV2("large.mkv", large, includeLayer: false);
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(missingLayer.Bytes)).Code);
    }

    [Fact]
    public void Generated_libtorrent_v2_piece_layers_are_verified_against_merkle_root()
    {
        var fixturePath = Path.Combine(AppContext.BaseDirectory, "Fixtures", "Source-fixture-v2.torrent");
        if (!File.Exists(fixturePath)) fixturePath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../Fixtures/Source-fixture-v2.torrent"));
        var bytes = File.ReadAllBytes(fixturePath);
        var reader = new BencodeReader(bytes);
        var root = reader.Root();
        var info = root.Find("info")!;
        var expectedInfoHash = Convert.ToHexString(SHA256.HashData(bytes.AsSpan(info.Start, info.End - info.Start))).ToLowerInvariant();
        var valid = Metainfo.Parse(bytes);
        Assert.Equal(expectedInfoHash, valid.InfoHashV2);
        var layers = root.Find("piece layers")!.Map;
        Assert.NotEmpty(layers);

        foreach (var layer in layers.Values)
        {
            var mutated = bytes.ToArray();
            var colon = Array.IndexOf(mutated, (byte)':', layer.Start, layer.End - layer.Start);
            Assert.True(colon >= layer.Start);
            var payloadStart = colon + 1;
            mutated[payloadStart] ^= 0x01;
            Assert.Equal(expectedInfoHash, Convert.ToHexString(SHA256.HashData(mutated.AsSpan(info.Start, info.End - info.Start))).ToLowerInvariant());
            Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(mutated)).Code);
        }
    }

    [Fact]
    public void Actual_libtorrent_single_file_v1_v2_hybrid_fixtures_keep_paths_and_hashes()
    {
        foreach (var (name, expectV1, expectV2) in new[] { ("Source-single-64.torrent", true, false), ("Source-single-32.torrent", false, true), ("Source-single-0.torrent", true, true) })
        {
            var bytes = ReadFixture(name);
            var reader = new BencodeReader(bytes);
            var info = reader.Root().Find("info")!;
            var parsed = Metainfo.Parse(bytes);
            Assert.Equal(expectV1 ? Convert.ToHexString(SHA1.HashData(bytes.AsSpan(info.Start, info.End - info.Start))).ToLowerInvariant() : null, parsed.InfoHashV1);
            Assert.Equal(expectV2 ? Convert.ToHexString(SHA256.HashData(bytes.AsSpan(info.Start, info.End - info.Start))).ToLowerInvariant() : null, parsed.InfoHashV2);
            Assert.Equal("single.mkv", Assert.Single(parsed.Files).Path);
        }

        var v1PieceProfile = TorrentFixture.CreateV1("piece-profile.mkv", [1, 2, 3], pieceLength: 12345);
        Assert.Equal(12345, Metainfo.Parse(v1PieceProfile.Bytes).PieceLength);
        var qbitMaximum = TorrentFixture.CreateV1("maximum-piece.mkv", [7], pieceLength: 67108864);
        Assert.Equal(67108864, Metainfo.Parse(qbitMaximum.Bytes).PieceLength);
    }

    [Fact]
    public void Actual_hybrid_piece_layer_tampering_is_rejected_without_changing_original_infohash()
    {
        var bytes = ReadFixture("Source-single-0.torrent");
        var parsed = Metainfo.Parse(bytes);
        var root = new BencodeReader(bytes).Root();
        var info = root.Find("info")!;
        var infoHash = Convert.ToHexString(SHA256.HashData(bytes.AsSpan(info.Start, info.End - info.Start))).ToLowerInvariant();
        Assert.Equal(infoHash, parsed.InfoHashV2);
        var layer = Assert.Single(root.Find("piece layers")!.Map.Values);
        var mutated = bytes.ToArray();
        var colon = Array.IndexOf(mutated, (byte)':', layer.Start, layer.End - layer.Start);
        Assert.True(colon >= layer.Start);
        mutated[colon + 1] ^= 0x80;
        Assert.Equal(infoHash, Convert.ToHexString(SHA256.HashData(mutated.AsSpan(info.Start, info.End - info.Start))).ToLowerInvariant());
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(mutated)).Code);
    }

    private static byte[] ReadFixture(string name)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Fixtures", name);
        if (!File.Exists(path)) path = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../Fixtures", name));
        return File.ReadAllBytes(path);
    }

    [Fact]
    public void V1_files_cannot_mix_with_single_file_length_and_nonadjacent_file_directory_collisions_fail()
    {
        var mixed = TorrentFixture.CreateV1MultiWithSingleLength();
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(mixed.Bytes)).Code);
        var prefixCollision = TorrentFixture.CreateV1Multi("set", [("a", [1]), ("a-/middle", [2]), ("a/child.mkv", [3])]);
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(prefixCollision.Bytes)).Code);
        var normalizedPrefix = TorrentFixture.CreateV1Multi("set", [("Dir", [1]), ("dir/file.mkv", [2])]);
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(normalizedPrefix.Bytes)).Code);
    }
}

internal sealed record BuiltTorrent(byte[] Bytes, byte[] InfoBytes);

internal static class TorrentFixture
{
    private static readonly byte[] Piece = new byte[20];
    private const int PieceLength = 16384;

    public static BuiltTorrent CreateV1(string name, byte[] data, long pieceLength = PieceLength, byte[]? pieceBytes = null, long? length = null, string? webSeed = null, string? announce = null)
    {
        var info = Dict(("length", length ?? data.LongLength), ("name", name), ("piece length", pieceLength), ("pieces", pieceBytes ?? Enumerable.Repeat((byte)0, checked((int)((data.Length + (long)pieceLength - 1) / pieceLength) * 20)).ToArray()));
        var root = new SortedDictionary<string, object>(StringComparer.Ordinal) { ["info"] = info };
        if (webSeed is not null) root["url-list"] = webSeed;
        if (announce is not null) root["announce"] = announce;
        return Build(root, info);
    }

    public static BuiltTorrent CreateV1Multi(string name, (string Path, byte[] Bytes)[] files)
        => CreateV1Multi(name, files.Select(f => (f.Path, f.Bytes, "")).ToArray());

    public static BuiltTorrent CreateV1Multi(string name, (string Path, byte[] Bytes, string Attr)[] files)
    {
        var encoded = files.Select(f => (object)Dict(("attr", f.Attr), ("length", (long)f.Bytes.LongLength), ("path", f.Path.Split('/').Cast<object>().ToList()))).ToList();
        var total = files.Sum(x => x.Bytes.LongLength);
        var info = Dict(("files", encoded), ("name", name), ("piece length", PieceLength), ("pieces", new byte[checked((int)((total + PieceLength - 1) / PieceLength) * 20)]));
        return Build(Dict(("info", info)), info);
    }

    public static BuiltTorrent CreateV1Symlink()
    {
        var file = Dict(("length", 0L), ("path", new List<object> { "link" }), ("symlink path", new List<object> { "target" }));
        var info = Dict(("files", new List<object> { file }), ("name", "set"), ("piece length", PieceLength), ("pieces", Array.Empty<byte>()));
        return Build(Dict(("info", info)), info);
    }

    public static BuiltTorrent CreateV1MultiWithSingleLength()
    {
        var file = Dict(("length", 1L), ("path", new List<object> { "movie.mkv" }));
        var info = Dict(("files", new List<object> { file }), ("length", 1L), ("name", "set"), ("piece length", PieceLength), ("pieces", new byte[20]));
        return Build(Dict(("info", info)), info);
    }

    public static BuiltTorrent CreateV2(string name, byte[] data, bool includeLayer = false, int layerLength = 64)
    {
        var rootHash = SHA256.HashData(data);
        var leaf = Dict(("length", (long)data.Length), ("pieces root", rootHash));
        var info = Dict(("file tree", Dict((name, Dict(("", leaf))))), ("meta version", 2L), ("name", "root"), ("piece length", PieceLength));
        var root = Dict(("info", info));
        if (includeLayer && data.Length > PieceLength)
            root["piece layers"] = Dict(("\0RAW" + Convert.ToHexString(rootHash), new byte[layerLength]));
        return Build(root, info);
    }

    public static BuiltTorrent CreateHybrid(string name, byte[] data)
    {
        var rootHash = SHA256.HashData(data);
        var leaf = Dict(("length", (long)data.Length), ("pieces root", rootHash));
        var file = Dict(("length", (long)data.Length), ("path", new List<object> { name }));
        var info = Dict(("file tree", Dict((name, Dict(("", leaf))))), ("length", (long)data.Length),
            ("meta version", 2L), ("name", name), ("piece length", PieceLength), ("pieces", new byte[20]));
        return Build(Dict(("info", info)), info);
    }

    private static SortedDictionary<string, object> Dict(params (string Key, object Value)[] fields)
        => new(fields.ToDictionary(x => x.Key, x => x.Value), StringComparer.Ordinal);

    private static BuiltTorrent Build(SortedDictionary<string, object> root, SortedDictionary<string, object> info)
        => new(Encode(root), Encode(info));

    private static byte[] Encode(object value)
    {
        using var stream = new MemoryStream();
        void Write(object v)
        {
            switch (v)
            {
                case byte[] bytes: stream.Write(Encoding.ASCII.GetBytes(bytes.Length.ToString() + ":")); stream.Write(bytes); break;
                case string text: var raw = Encoding.UTF8.GetBytes(text); stream.Write(Encoding.ASCII.GetBytes(raw.Length.ToString() + ":")); stream.Write(raw); break;
                case int number: Write((long)number); break;
                case long number: stream.Write(Encoding.ASCII.GetBytes("i" + number + "e")); break;
                case List<object> list: stream.WriteByte((byte)'l'); foreach (var item in list) Write(item); stream.WriteByte((byte)'e'); break;
                case SortedDictionary<string, object> map:
                    stream.WriteByte((byte)'d'); foreach (var item in map)
                    {
                        if (item.Key.StartsWith("\0RAW", StringComparison.Ordinal)) Write(Convert.FromHexString(item.Key[4..])); else Write(item.Key);
                        Write(item.Value);
                    }
                    stream.WriteByte((byte)'e'); break;
                default: throw new ArgumentException("Unsupported bencode fixture value.");
            }
        }
        Write(value); return stream.ToArray();
    }
}
