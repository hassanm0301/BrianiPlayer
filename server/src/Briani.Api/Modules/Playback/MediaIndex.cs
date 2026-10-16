using System.Buffers.Binary;
using System.Collections.Concurrent;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
namespace Briani.Api.Modules.Playback;

public enum Mp4IndexStatus{NotApplicable,Waiting,Located}
public readonly record struct Mp4IndexResult(Mp4IndexStatus Status,long Offset=0,long Length=0);

/// Finds the ISO BMFF 'moov' box by walking top-level box headers. Players need
/// it before the first frame, and many MP4s keep it after the media data, so a
/// verified prefix alone does not make such a file playable.
public static class Mp4Index
{
    public static bool Applies(string fileName)=>Path.GetExtension(fileName).ToLowerInvariant() is ".mp4" or ".m4v" or ".mov";

    /// <paramref name="available"/> says whether a byte range is verified;
    /// <paramref name="read"/> is only called for verified ranges. Anything that
    /// is not a well-formed box sequence is NotApplicable, so callers fall back
    /// to the byte rule instead of waiting forever.
    public static Mp4IndexResult Locate(long length,Func<long,long,bool> available,Func<long,Memory<byte>,bool> read)
    {
        var header=new byte[16];long offset=0;
        for(var boxes=0;boxes<256 && offset<length;boxes++)
        {
            var want=(int)Math.Min(16,length-offset);
            if(want<8)return new(Mp4IndexStatus.NotApplicable);
            if(!available(offset,want) || !read(offset,header.AsMemory(0,want)))return new(Mp4IndexStatus.Waiting);
            long size=BinaryPrimitives.ReadUInt32BigEndian(header);var headerSize=8;
            if(!header.AsSpan(4,4).ToArray().All(b=>b is >=0x20 and <=0x7e))return new(Mp4IndexStatus.NotApplicable);
            if(size==1){if(want<16)return new(Mp4IndexStatus.NotApplicable);var large=BinaryPrimitives.ReadUInt64BigEndian(header.AsSpan(8,8));if(large>long.MaxValue)return new(Mp4IndexStatus.NotApplicable);size=(long)large;headerSize=16;}
            else if(size==0)size=length-offset;
            if(size<headerSize || size>length-offset)return new(Mp4IndexStatus.NotApplicable);
            if(header.AsSpan(4,4).SequenceEqual("moov"u8))return new(Mp4IndexStatus.Located,offset,size);
            offset+=size;
        }
        return new(Mp4IndexStatus.NotApplicable);
    }
}

/// Decides whether an incomplete video's container index is verified. Only MP4
/// and MOV files are gated; other containers keep the byte-prefix rule.
public sealed class MediaIndexProbe(ContainedStorage storage)
{
    private readonly ConcurrentDictionary<Guid,(string Key,long Offset,long Length)> located=new();

    public bool IndexReady(DownloadFile file,TorrentJob job,Library library,Func<int,bool> hasPiece)
    {
        if(!Mp4Index.Applies(file.DisplayName) || file.SizeBytes<=0 || job.PieceLength<=0)return true;
        bool Available(long offset,long length)=>RangeAvailable(file,job.PieceLength,hasPiece,offset,length);
        var key=$"{job.Generation}:{file.FileIdentity}";
        if(located.TryGetValue(file.Id,out var known) && known.Key==key)return Available(known.Offset,known.Length);
        if(file.FileIdentity is null)return false;
        try
        {
            using var root=storage.OpenLibrary(library);
            using var stream=root.OpenFile(job.ManagedPath+"/"+file.RelativePath,file.FileIdentity);
            var result=Mp4Index.Locate(file.SizeBytes,Available,(offset,buffer)=>RandomAccess.Read(stream.SafeFileHandle,buffer.Span,offset)==buffer.Length);
            if(result.Status==Mp4IndexStatus.Located){located[file.Id]=(key,result.Offset,result.Length);return Available(result.Offset,result.Length);}
            return result.Status==Mp4IndexStatus.NotApplicable;
        }
        catch(Exception e)when(e is ApiException or IOException or UnauthorizedAccessException){return false;}
    }

    public static bool RangeAvailable(DownloadFile file,long pieceLength,Func<int,bool> hasPiece,long offset,long length)
    {
        if(offset<0 || length<=0 || offset+length>file.SizeBytes)return false;
        var first=(file.TorrentOffset+offset)/pieceLength;var last=(file.TorrentOffset+offset+length-1)/pieceLength;
        for(var p=first;p<=last;p++)if(p>int.MaxValue || !hasPiece((int)p))return false;
        return true;
    }
}
