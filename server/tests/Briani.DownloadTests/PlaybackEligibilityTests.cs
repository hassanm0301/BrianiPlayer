using System.Net.Http.Json;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Downloads.Queries;
using Microsoft.EntityFrameworkCore;
namespace Briani.DownloadTests;
public sealed class PlaybackEligibilityTests
{
    [Theory]
    [InlineData(1023,false,"waitingForData")]
    [InlineData(1024,false,"eligible")]
    [InlineData(1279,true,"waitingForData")]
    public async Task Poll_exposes_play_only_after_contiguous_verified_startup_prefix(int verified,bool missingFirst,string state)
    {
        await using var f=await LifecycleFixture.Create();await f.SeedReadyDownload(f.Admin.User.Id,f.Admin.SessionId);
        const int count=1280;const long bytes=20L*1024*1024;
        var path=Path.Combine(f.LibraryPath,".briani","staging",f.Engine.JobId.ToString("N"),"fixture.mp4");
        using(var file=new FileStream(path,FileMode.Open,FileAccess.Write,FileShare.None))file.SetLength(bytes);
        await f.InDb(async db=>{
            var job=await db.TorrentJobs.SingleAsync(x=>x.Id==f.Engine.JobId);job.PieceCount=count;job.TotalBytes=bytes;job.SelectedComplete=false;
            var file=await db.DownloadFiles.SingleAsync(x=>x.Id==f.Engine.FileId);file.SizeBytes=bytes;file.PieceLast=count-1;file.Completed=false;file.DownloadedBytes=0;file.ContiguousBytes=0;file.PlaybackState="waitingForData";
            var request=await db.DownloadRequests.SingleAsync(x=>x.Id==f.Engine.RequestId);request.SelectedBytes=bytes;
            return await db.SaveChangesAsync();});
        f.Engine.ConfigureFiles(count,new EngineFile(0,"fixture.mp4",bytes,0,7,0,count-1));
        f.Engine.CompletePieces=false;f.Engine.PieceStatesOverride=Enumerable.Range(0,count).Select(i=>(byte)(i<verified && !(missingFirst && i==0)?2:0)).ToArray();
        f.Engine.RegisterExisting(LifecycleFixture.Hash,Path.GetDirectoryName(path)!);
        await f.Worker.PollOnceAsync();
        var rows=(await f.Client.GetFromJsonAsync<DownloadFileView[]>($"/api/v1/downloads/{f.Engine.RequestId}/files"))!;
        var result=Assert.Single(rows);Assert.Equal(state,result.PlaybackState);
        Assert.Equal(missingFirst?0:verified*16384L,result.ContiguousBytes);
        Assert.True(result.DownloadedBytes<bytes);Assert.True(result.Selected);
    }
}
