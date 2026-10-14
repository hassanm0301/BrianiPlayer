using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Integrations.QBittorrent;
namespace Briani.Api.Modules.Downloads;
public static class DownloadLayout
{
    public static DownloadFile[] Map(Guid jobId,MetainfoDescriptor metadata,EngineFile[] engine)
    {
        if(engine.Length>10000 || engine.Select(x=>x.Index).Distinct().Count()!=engine.Length)throw new ApiException(409,"engine_layout_mismatch");
        var remaining=engine.ToDictionary(x=>x.Path,StringComparer.Ordinal);var files=new List<DownloadFile>();long offset=0;
        foreach(var file in metadata.Files)
        {
            if(metadata.InfoHashV1 is null && offset%metadata.PieceLength!=0)offset=checked(offset+metadata.PieceLength-offset%metadata.PieceLength);
            var first=file.Bytes==0?0:checked((int)(offset/metadata.PieceLength));var last=file.Bytes==0?-1:checked((int)((offset+file.Bytes-1)/metadata.PieceLength));
            var index=-file.Index-1;
            if(remaining.Remove(file.Path,out var actual))
            {if(actual.Index<0 || actual.Bytes!=file.Bytes || actual.FirstPiece!=first || actual.LastPiece!=last)throw new ApiException(409,"engine_layout_mismatch");index=actual.Index;}
            else if(!file.Padding)throw new ApiException(409,"engine_layout_mismatch");
            files.Add(new(){TorrentJobId=jobId,UpstreamFileIndex=index,MetadataFileIndex=file.Index,RelativePath=file.Path,DisplayName=Path.GetFileName(file.Path),SizeBytes=file.Bytes,TorrentOffset=offset,PieceFirst=first,PieceLast=last,Padding=file.Padding,Kind=file.Executable?"other":Kind(file.Path),PlaybackState="notSelected",FilePriority=0});
            offset=checked(offset+file.Bytes);
        }
        if(remaining.Count!=0)throw new ApiException(409,"engine_layout_mismatch");return files.ToArray();
    }
    public static int PieceCount(MetainfoDescriptor metadata)
    {
        long total=0;foreach(var file in metadata.Files){if(metadata.InfoHashV1 is null && total%metadata.PieceLength!=0)total=checked(total+metadata.PieceLength-total%metadata.PieceLength);total=checked(total+file.Bytes);}
        var count=total/metadata.PieceLength+(total%metadata.PieceLength==0?0:1);if(count>4000000)throw new ApiException(400,"metainfo_too_many_pieces");return (int)count;
    }
    public static string Kind(string path)=>Path.GetExtension(path).ToLowerInvariant() switch
    {".mp4" or ".m4v" or ".mkv" or ".webm" or ".mov" or ".avi" or ".mpeg" or ".mpg" or ".ts" or ".m2ts" or ".ogv" or ".3gp"=>"video", ".jpg" or ".jpeg" or ".png" or ".webp" or ".gif" or ".bmp" or ".tif" or ".tiff" or ".avif"=>"photo", ".srt" or ".ass" or ".ssa" or ".vtt"=>"subtitle",_=>"other"};
    public static long Available(DownloadFile file,long pieceLength,byte[] pieces,bool contiguous=false)
    {
        long bytes=0;for(var p=file.PieceFirst;p<=file.PieceLast && file.SizeBytes>0;p++)
        {if(p<0 || p>=pieces.Length || pieces[p]!=2){if(contiguous)break;continue;}var start=Math.Max(file.TorrentOffset,(long)p*pieceLength);var end=Math.Min(file.TorrentOffset+file.SizeBytes,((long)p+1)*pieceLength);bytes=checked(bytes+Math.Max(0,end-start));}return bytes;
    }
}
