using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Modules.Discovery.Sources;
internal sealed record BNode(object Value,int Start,int End)
{
    internal Dictionary<string,BNode> Map=>Value as Dictionary<string,BNode>??throw Metainfo.Invalid();
    internal List<BNode> List=>Value as List<BNode>??throw Metainfo.Invalid();
    internal byte[] Bytes=>Value as byte[]??throw Metainfo.Invalid();
    internal long Integer=>Value is long number?number:throw Metainfo.Invalid();
    internal BNode? Find(string name)=>Map.GetValueOrDefault(name);
}
internal sealed class BencodeReader(byte[] input)
{
    private int position,nodes;
    internal BNode Read(int depth=0)
    {
        if(depth>64 || ++nodes>100000 || position>=input.Length)throw Metainfo.Invalid();int start=position;object value;
        var prefix=input[position++];
        if(prefix==(byte)'i')
        {
            var end=Array.IndexOf(input,(byte)'e',position);if(end<0 || end-position>20)throw Metainfo.Invalid();var text=Encoding.ASCII.GetString(input,position,end-position);
            if(!long.TryParse(text,NumberStyles.AllowLeadingSign,CultureInfo.InvariantCulture,out var number) || text!=number.ToString(CultureInfo.InvariantCulture))throw Metainfo.Invalid();position=end+1;value=number;
        }
        else if(prefix==(byte)'l')
        {var list=new List<BNode>();while(position<input.Length && input[position]!=(byte)'e')list.Add(Read(depth+1));if(position>=input.Length)throw Metainfo.Invalid();position++;value=list;}
        else if(prefix==(byte)'d')
        {
            var map=new Dictionary<string,BNode>(StringComparer.Ordinal);string? previous=null;
            while(position<input.Length && input[position]!=(byte)'e')
            {var key=Encoding.Latin1.GetString(Read(depth+1).Bytes);if(previous is not null && StringComparer.Ordinal.Compare(previous,key)>=0)throw Metainfo.Invalid();previous=key;map.Add(key,Read(depth+1));}
            if(position>=input.Length)throw Metainfo.Invalid();position++;value=map;
        }
        else if(prefix>=(byte)'0' && prefix<=(byte)'9')
        {
            position--;var end=Array.IndexOf(input,(byte)':',position);if(end<0 || end-position>8)throw Metainfo.Invalid();var text=Encoding.ASCII.GetString(input,position,end-position);
            if(!int.TryParse(text,NumberStyles.None,CultureInfo.InvariantCulture,out var length) || text!=length.ToString(CultureInfo.InvariantCulture) || length>16777216 || length>input.Length-end-1)throw Metainfo.Invalid();position=end+1;value=input.AsSpan(position,length).ToArray();position+=length;
        }
        else throw Metainfo.Invalid();return new(value,start,position);
    }
    internal BNode Root(){var root=Read();if(position!=input.Length)throw Metainfo.Invalid();return root;}
}
public sealed record MetainfoFile(int Index,string Path,long Bytes,bool Padding,bool Executable=false);
public sealed record MetainfoDescriptor(string Name,string? InfoHashV1,string? InfoHashV2,long PieceLength,MetainfoFile[] Files,string[] Trackers);
public static class Metainfo
{
    private static readonly UTF8Encoding Utf8=new(false,true);
    internal static ApiException Invalid()=>new(400,"invalid_metainfo");
    private static string Text(BNode node){try{return Utf8.GetString(node.Bytes);}catch(DecoderFallbackException){throw Invalid();}}
    internal static string Component(string value)
    {
        if(value.Length==0 || Encoding.UTF8.GetByteCount(value)>255 || value is "." or ".." || value.EndsWith('.') || value.EndsWith(' ') || value.IndexOfAny(['/', '\\', ':'])>=0 || value.Any(char.IsControl) || value.Equals(".briani",StringComparison.OrdinalIgnoreCase))throw Invalid();
        var stem=value.Split('.')[0].ToUpperInvariant();if(stem is "CON" or "PRN" or "AUX" or "NUL" || stem.Length==4 && stem[..3] is "COM" or "LPT" && stem[3] is >= '1' and <= '9')throw Invalid();return value;
    }
    private static bool VerifyPieceLayer(byte[] layer,byte[] root,long pieceLength)
    {
        var padding=new byte[32];for(long block=16384;block<pieceLength;block*=2){var pair=new byte[64];padding.CopyTo(pair,0);padding.CopyTo(pair,32);padding=SHA256.HashData(pair);}
        int count=layer.Length/32,capacity=1;while(capacity<count)capacity*=2;var hashes=new byte[capacity][];
        for(int i=0;i<capacity;i++)hashes[i]=i<count?layer.AsSpan(i*32,32).ToArray():padding;
        while(capacity>1){for(int i=0;i<capacity/2;i++){var pair=new byte[64];hashes[2*i].CopyTo(pair,0);hashes[2*i+1].CopyTo(pair,32);hashes[i]=SHA256.HashData(pair);}capacity/=2;}
        return CryptographicOperations.FixedTimeEquals(hashes[0],root);
    }
    public static MetainfoDescriptor Parse(byte[] bytes)
    {
        if(bytes.Length is <2 or >16777216)throw Invalid();var root=new BencodeReader(bytes).Root();var info=root.Find("info")??throw Invalid();var name=Component(Text(info.Find("name.utf-8")??info.Find("name")??throw Invalid()));
        var piece=info.Find("piece length")?.Integer??throw Invalid();if(piece is <1 or >67108864)throw Invalid();
        bool v1=info.Find("pieces") is not null;var version=info.Find("meta version")?.Integer;if(version is not null && version!=2)throw Invalid();bool v2=version==2;if(!v1 && !v2 || v2 && (piece<16384 || (piece&(piece-1))!=0))throw Invalid();
        var first=new List<MetainfoFile>();var second=new List<MetainfoFile>();long total=0;
        void Add(List<MetainfoFile> files,string path,BNode properties)
        {
            if(files.Count>=10000 || Encoding.UTF8.GetByteCount(path)>4096)throw Invalid();var size=properties.Find("length")?.Integer??throw Invalid();if(size<0)throw Invalid();
            var attributes=properties.Find("attr") is BNode attr?Text(attr):"";if(attributes.Contains('l') || properties.Find("symlink path") is not null)throw Invalid();files.Add(new(files.Count,path,size,attributes.Contains('p'),attributes.Contains('x')));
        }
        if(v1)
        {
            if(info.Find("files") is BNode files)
            {if(info.Find("length") is not null)throw Invalid();foreach(var file in files.List){var path=file.Find("path.utf-8")??file.Find("path")??throw Invalid();var parts=path.List.Select(x=>Component(Text(x))).ToArray();if(parts.Length is <1 or >64)throw Invalid();Add(first,name+"/"+string.Join('/',parts),file);}}
            else Add(first,name,info);
            try{foreach(var file in first)total=checked(total+file.Bytes);}catch(OverflowException){throw Invalid();}
            var hashes=info.Find("pieces")!.Bytes;if(hashes.Length%20!=0 || hashes.Length/20!=total/piece+(total%piece==0?0:1))throw Invalid();
        }
        if(v2)
        {
            var layers=root.Find("piece layers");var verifiedLayers=new HashSet<string>(StringComparer.Ordinal);
            void Walk(BNode tree,string prefix,int depth)
            {
                if(depth>64)throw Invalid();foreach(var (key,value) in tree.Map)
                {
                    if(key=="")
                    {
                        if(tree.Map.Count!=1)throw Invalid();Add(second,prefix,value);var length=second[^1].Bytes;var hash=value.Find("pieces root");if(length>0 && (hash is null || hash.Bytes.Length!=32))throw Invalid();
                        if(length>piece){var layer=layers?.Find(Encoding.Latin1.GetString(hash!.Bytes))??throw Invalid();if(layer.Bytes.LongLength!=(length/piece+(length%piece==0?0:1))*32)throw Invalid();var cacheKey=Convert.ToHexString(hash!.Bytes)+":"+layer.Bytes.Length;if(!verifiedLayers.Contains(cacheKey)){if(!VerifyPieceLayer(layer.Bytes,hash.Bytes,piece))throw Invalid();verifiedLayers.Add(cacheKey);}}
                    }
                    else{string part;try{part=Utf8.GetString(Encoding.Latin1.GetBytes(key));}catch(DecoderFallbackException){throw Invalid();}Walk(value,prefix==""?Component(part):prefix+"/"+Component(part),depth+1);}
                }
            }
            var tree=info.Find("file tree")??throw Invalid();if(tree.Map.ContainsKey(""))throw Invalid();Walk(tree,"",0);
            if(v1 && info.Find("files") is not null || !v1 && second.Count>1)for(int i=0;i<second.Count;i++)second[i]=second[i] with{Path=name+"/"+second[i].Path};
        }
        if(v1 && v2)
        {long offset=0,expectedOffset=0;foreach(var file in first){if(!file.Padding){if(offset!=expectedOffset)throw Invalid();expectedOffset=checked(((offset+file.Bytes)/piece+((offset+file.Bytes)%piece==0?0:1))*piece);}offset=checked(offset+file.Bytes);}if(offset>expectedOffset)throw Invalid();var actual=first.Where(x=>!x.Padding).Select(x=>(x.Path,x.Bytes)).ToArray();var expected=second.Where(x=>!x.Padding).Select(x=>(x.Path,x.Bytes)).ToArray();if(!actual.SequenceEqual(expected))throw Invalid();}
        var selected=v1?first:second;if(selected.Count==0)throw Invalid();var paths=new HashSet<string>(StringComparer.Ordinal);
        foreach(var file in selected)if(!paths.Add(file.Path.Normalize(NormalizationForm.FormC).ToUpperInvariant()))throw Invalid();
        foreach(var path in paths){for(int slash=path.IndexOf('/');slash>=0;slash=path.IndexOf('/',slash+1))if(paths.Contains(path[..slash]))throw Invalid();}
        var trackers=new List<string>();if(root.Find("announce") is BNode announce)trackers.Add(Text(announce));if(root.Find("announce-list") is BNode tiers)foreach(var tier in tiers.List)foreach(var tracker in tier.List){if(trackers.Count>=100)throw Invalid();trackers.Add(Text(tracker));}
        if(root.Find("url-list") is not null || root.Find("httpseeds") is not null || root.Find("nodes") is not null || info.Find("nodes") is not null)throw new ApiException(400,"unsafe_metainfo_source");
        foreach(var tracker in trackers)SourceValidation.Tracker(tracker);
        var original=bytes.AsSpan(info.Start,info.End-info.Start);return new(name,v1?Convert.ToHexString(SHA1.HashData(original)).ToLowerInvariant():null,v2?Convert.ToHexString(SHA256.HashData(original)).ToLowerInvariant():null,piece,selected.ToArray(),trackers.Distinct(StringComparer.Ordinal).ToArray());
    }
}
