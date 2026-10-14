using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Discovery.Sources;

namespace Briani.DiscoveryTests;

public sealed class MetainfoBoundaryTests
{
    private const long PieceLength = 16384;

    [Theory]
    [InlineData("root-leaf")] [InlineData("leaf-and-child")] [InlineData("empty-tree")]
    [InlineData("missing-root")] [InlineData("short-root")] [InlineData("negative-length")]
    public void Malformed_v2_tree_or_leaf_is_rejected(string defect)
    {
        var leaf = Leaf(3);
        var tree = Map(("movie.mkv", Map(("", leaf))));
        switch (defect)
        {
            case "root-leaf": tree = Map(("", leaf)); break;
            case "leaf-and-child": tree = Map(("movie.mkv", Map(("", leaf), ("child.mkv", Map(("", Leaf(1))))))); break;
            case "empty-tree": tree.Clear(); break;
            case "missing-root": leaf.Remove("pieces root"); break;
            case "short-root": leaf["pieces root"] = new byte[31]; break;
            case "negative-length": leaf["length"] = -1L; break;
        }
        var error = Assert.Throws<ApiException>(() => Metainfo.Parse(Encode(Map(("info", V2(tree))))));
        Assert.Equal(400, error.Status); Assert.Equal("invalid_metainfo", error.Code);
    }

    [Theory]
    [InlineData("missing-padding")] [InlineData("excess-padding")] [InlineData("mismatched-length")]
    [InlineData("mismatched-name")] [InlineData("trailing-overpadding")]
    public void Hybrid_file_order_and_padding_cannot_disagree_with_v2_layout(string defect)
    {
        var pad = defect == "missing-padding" ? 0L : defect == "excess-padding" ? PieceLength - 2 : PieceLength - 3;
        var files = new List<object> { File("a.mkv", 3) };
        if (pad > 0) files.Add(File(".pad/" + pad, pad, "p"));
        files.Add(File("b.mkv", 4));
        if (defect == "trailing-overpadding") files.Add(File(".pad/tail", PieceLength, "p"));
        var total = 7 + pad + (defect == "trailing-overpadding" ? PieceLength : 0);
        var tree = Map(("a.mkv", Map(("", Leaf(3)))), (defect == "mismatched-name" ? "c.mkv" : "b.mkv", Map(("", Leaf(defect == "mismatched-length" ? 5 : 4)))));
        var info = V2(tree); info["files"] = files; info["pieces"] = new byte[(int)((total + PieceLength - 1) / PieceLength) * 20];
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(Encode(Map(("info", info))))).Code);
    }

    [Fact]
    public void Valid_hybrid_padding_preserves_nonpadding_file_order_and_sizes()
    {
        var tree = Map(("a.mkv", Map(("", Leaf(3)))), ("b.mkv", Map(("", Leaf(4)))));
        var info = V2(tree); info["files"] = new List<object> { File("a.mkv", 3), File(".pad/16381", 16381, "p"), File("b.mkv", 4) }; info["pieces"] = new byte[40];
        var parsed = Metainfo.Parse(Encode(Map(("info", info))));
        Assert.Equal(new[] { "set/a.mkv", "set/b.mkv" }, parsed.Files.Where(f => !f.Padding).Select(f => f.Path));
        Assert.Equal(new long[] { 3, 4 }, parsed.Files.Where(f => !f.Padding).Select(f => f.Bytes));
        Assert.Equal(16381, Assert.Single(parsed.Files, f => f.Padding).Bytes);
    }

    [Fact]
    public void Reused_v2_piece_layer_verification_retains_both_distinct_files()
    {
        var layer = Enumerable.Range(0, 64).Select(i => (byte)i).ToArray();
        var root = SHA256.HashData(layer);
        var leaf = Map(("length", PieceLength + 1), ("pieces root", root));
        var tree = Map(("a.mkv", Map(("", leaf))), ("b.mkv", Map(("", leaf))), ("empty.mkv", Map(("", Map(("length", 0L))))));
        var metainfo = Map(("info", V2(tree)), ("piece layers", Map(("\0RAW" + Convert.ToHexString(root), layer))));
        var parsed = Metainfo.Parse(Encode(metainfo));
        Assert.Equal(new[] { "set/a.mkv", "set/b.mkv", "set/empty.mkv" }, parsed.Files.Select(f => f.Path));
        Assert.Equal(new long[] { PieceLength + 1, PieceLength + 1, 0 }, parsed.Files.Select(f => f.Bytes));
        layer[0] ^= 1;
        Assert.Equal("invalid_metainfo", Assert.Throws<ApiException>(() => Metainfo.Parse(Encode(metainfo))).Code);
    }

    private static SortedDictionary<string, object> V2(SortedDictionary<string, object> tree) => Map(("file tree", tree), ("meta version", 2L), ("name", "set"), ("piece length", PieceLength));
    private static SortedDictionary<string, object> Leaf(long size) => Map(("length", size), ("pieces root", new byte[32]));
    private static SortedDictionary<string, object> File(string path, long size, string attr = "") => Map(("attr", attr), ("length", size), ("path", path.Split('/').Cast<object>().ToList()));
    private static SortedDictionary<string, object> Map(params (string Key, object Value)[] pairs) => new(pairs.ToDictionary(p => p.Key, p => p.Value), StringComparer.Ordinal);
    private static byte[] Encode(object value)
    {
        using var stream = new MemoryStream();
        void Write(object current)
        {
            switch (current)
            {
                case byte[] bytes: stream.Write(Encoding.ASCII.GetBytes(bytes.Length.ToString(CultureInfo.InvariantCulture) + ":")); stream.Write(bytes); break;
                case string text: Write(Encoding.UTF8.GetBytes(text)); break;
                case long number: stream.Write(Encoding.ASCII.GetBytes("i" + number.ToString(CultureInfo.InvariantCulture) + "e")); break;
                case List<object> list: stream.WriteByte((byte)'l'); foreach (var item in list) Write(item); stream.WriteByte((byte)'e'); break;
                case SortedDictionary<string, object> map:
                    stream.WriteByte((byte)'d');
                    foreach (var (key, entry) in map) { if (key.StartsWith("\0RAW", StringComparison.Ordinal)) Write(Convert.FromHexString(key[4..])); else Write(key); Write(entry); }
                    stream.WriteByte((byte)'e'); break;
                default: throw new ArgumentException("Unsupported fixture value");
            }
        }
        Write(value); return stream.ToArray();
    }
}
