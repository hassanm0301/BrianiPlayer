using System.Text;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Infrastructure.Storage;
internal sealed record MountLocation(string Volume,string Path)
{
    internal static MountLocation Resolve(string absolute,NodeIdentity node)
    {
        // Kernel mount ID + device bind an already-contained descriptor to its
        // mountinfo mapping; this also recognizes nested bind aliases.
        using var file=File.OpenRead("/proc/self/mountinfo");using var reader=new StreamReader(file,Encoding.UTF8);int bytes=0;
        string? line;while((line=reader.ReadLine()) is not null)
        {
            bytes+=Encoding.UTF8.GetByteCount(line)+1;if(bytes>1048576)throw new ApiException(409,"mount_layout_unavailable");
            var fields=line.Split(' ');if(fields.Length<7 || !ulong.TryParse(fields[0],out var id) || id!=node.MountId)continue;
            var mount=Decode(fields[4]);var source=Decode(fields[3]);var volume=$"{node.DeviceMajor}:{node.DeviceMinor}";
            if(fields[2]!=volume || !System.IO.Path.IsPathFullyQualified(mount) || !System.IO.Path.IsPathFullyQualified(source))throw new ApiException(409,"mount_layout_unavailable");
            string suffix;if(mount=="/")suffix=absolute.TrimStart('/');else if(absolute==mount)suffix="";else if(absolute.StartsWith(mount+"/",StringComparison.Ordinal))suffix=absolute[(mount.Length+1)..];else throw new ApiException(409,"mount_layout_unavailable");
            return new(volume,System.IO.Path.TrimEndingDirectorySeparator(System.IO.Path.Combine(source,suffix)));
        }
        throw new ApiException(409,"mount_layout_unavailable");
    }
    internal bool Overlaps(MountLocation other)=>Volume==other.Volume && (Path==other.Path || Path.StartsWith(other.Path=="/"?"/":other.Path+"/",StringComparison.Ordinal) || other.Path.StartsWith(Path=="/"?"/":Path+"/",StringComparison.Ordinal));
    private static string Decode(string value)=>value.Replace("\\040"," ",StringComparison.Ordinal).Replace("\\011","\t",StringComparison.Ordinal).Replace("\\012","\n",StringComparison.Ordinal).Replace("\\134","\\",StringComparison.Ordinal);
}
