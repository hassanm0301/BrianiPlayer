using System.Text.Json;
using Briani.Api.Modules.Preferences;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Downloads;
public sealed record DownloadPolicy(int ActiveGlobal=2,int ActivePerUser=1,int ActiveSeeds=2,int MetadataConcurrency=1,long ProvisionalBytes=268435456,long DiskFloorBytes=5368709120,double DiskFloorFraction=0.05);
public sealed class DownloadAdmission(BrianiDb db,ContainedStorage storage)
{
    public async Task<DownloadPolicy> PolicyAsync(CancellationToken ct)
    {
        if(await db.Settings.AsNoTracking().AnyAsync(x=>x.Key==AdministratorConfiguration.Key,ct)) {
            var configured=await AdministratorConfiguration.ReadAsync(db,ct);
            return new(configured["activeDownloads"]!.GetValue<int>(),configured["activeDownloadsPerUser"]!.GetValue<int>(),configured["activeSeeds"]!.GetValue<int>(),
                DiskFloorBytes:configured["lowDiskFloorBytes"]!.GetValue<long>(),DiskFloorFraction:configured["lowDiskFloorFraction"]!.GetValue<double>());
        }
        var setting=await db.Settings.AsNoTracking().SingleOrDefaultAsync(x=>x.Key=="downloads.policy",ct);if(setting is null)return new();
        try{var p=JsonSerializer.Deserialize<DownloadPolicy>(setting.ValueJson,new JsonSerializerOptions(JsonSerializerDefaults.Web))??new();return new(Math.Clamp(p.ActiveGlobal,1,8),Math.Clamp(p.ActivePerUser,1,4),Math.Clamp(p.ActiveSeeds,1,8),Math.Clamp(p.MetadataConcurrency,1,2),Math.Clamp(p.ProvisionalBytes,16777216,1073741824),Math.Max(5368709120,p.DiskFloorBytes),Math.Max(.05,Math.Min(.5,p.DiskFloorFraction)));}catch(JsonException){throw new ApiException(503,"invalid_download_policy");}
    }
    // Call under WriteGate. Reservations are charged once per physical job, and quotas once per user's distinct selected files.
    public async Task<(string Volume,long Bytes)> RequireAsync(Actor actor,Library library,Guid? excludedJob,long physicalBytes,long quotaBytes,Guid? excludedRequest,CancellationToken ct,Guid[]? selectedFileIds=null)
    {
        if(!library.Enabled || !library.Online || library.ReadOnly)throw new ApiException(409,"disk_unavailable");using var root=storage.OpenLibrary(library);var volume=root.Volume();if(!volume.Writable)throw new ApiException(409,"disk_unavailable");var policy=await PolicyAsync(ct);
        var reserved=await db.TorrentJobs.Where(x=>x.VolumeIdentity==volume.Identity && x.RetiredAt==null && x.Id!=excludedJob).SumAsync(x=>(long?)x.ReservedBytes,ct)??0;
        var floor=Math.Max(policy.DiskFloorBytes,(long)Math.Ceiling(volume.TotalBytes*policy.DiskFloorFraction));if(physicalBytes<0 || reserved>volume.FreeBytes || physicalBytes>volume.FreeBytes-reserved || floor>volume.FreeBytes-reserved-physicalBytes)throw new ApiException(507,"disk_full");
        var grant=await db.LibraryGrants.AsNoTracking().SingleOrDefaultAsync(x=>x.UserId==actor.UserId && x.LibraryId==library.Id,ct);
        var defaults=await AdministratorConfiguration.ReadAsync(db,ct);
        var defaultQuota=defaults["defaultUserQuotaBytes"]?.GetValue<long>();
        var quotaScopeLibrary=grant?.QuotaBytes is not null;
        if((grant?.QuotaBytes ?? defaultQuota) is long quota)
        {
            var attributed=await (from owner in db.DownloadOwnerships where owner.OwnerId==actor.UserId && (!quotaScopeLibrary || owner.LibraryId==library.Id)
                join file in db.DownloadFiles on owner.DownloadFileId equals file.Id
                where db.TorrentJobs.Any(j=>j.Id==file.TorrentJobId && !j.PayloadRemoved) || db.MediaItems.Any(m=>m.DownloadFileId==file.Id && m.Lifecycle!="deleted")
                select new{file.Id,file.SizeBytes}).ToArrayAsync(ct);
            // Legacy rows from an upgrade are attributed only to their recorded requester, never arbitrary pre-existing library files.
            var prior=await (from r in db.DownloadRequests where r.OwnerId==actor.UserId && (!quotaScopeLibrary || r.LibraryId==library.Id)
                join choice in db.DownloadRequestFiles on r.Id equals choice.DownloadRequestId where choice.Selected
                join file in db.DownloadFiles on choice.DownloadFileId equals file.Id
                where db.TorrentJobs.Any(j=>j.Id==file.TorrentJobId && !j.PayloadRemoved) || db.MediaItems.Any(m=>m.DownloadFileId==file.Id && m.Lifecycle!="deleted")
                select new{file.Id,file.SizeBytes}).Distinct().ToArrayAsync(ct);
            var retained=attributed.Concat(prior).DistinctBy(x=>x.Id).ToArray();
            long charged=0;foreach(var file in retained)charged=checked(charged+file.SizeBytes);
            if(selectedFileIds is not null)foreach(var file in retained.Where(x=>selectedFileIds.Contains(x.Id)))quotaBytes=Math.Max(0,quotaBytes-file.SizeBytes);
            charged=checked(charged+(await db.DownloadRequests.Where(x=>x.OwnerId==actor.UserId && (!quotaScopeLibrary || x.LibraryId==library.Id) && x.Id!=excludedRequest && x.RemovedAt==null && x.SelectedBytes==null).SumAsync(x=>(long?)x.ReservedBytes,ct)??0));
            if(quotaBytes<0 || quotaBytes>quota || charged>quota-quotaBytes)throw new ApiException(409,"quota_exceeded");
        }
        return(volume.Identity,physicalBytes);
    }
    public async Task<bool> SlotAvailableAsync(TorrentJob job,CancellationToken ct)
    {
        var p=await PolicyAsync(ct);if(job.SelectedComplete)return await db.TorrentJobs.CountAsync(x=>x.Id!=job.Id && x.RetiredAt==null && (x.EngineState=="seeding" || x.SelectedComplete && x.EngineState=="starting"),ct)<p.ActiveSeeds;var active=await db.TorrentJobs.AsNoTracking().Where(x=>x.Id!=job.Id && x.RetiredAt==null && x.DesiredState=="running" && !x.SelectedComplete && (x.EngineState=="downloading" || x.EngineState=="stalled" || x.EngineState=="starting")).Select(x=>x.Id).ToArrayAsync(ct);
        if(active.Length>=p.ActiveGlobal)return false;
        var owners=await db.DownloadRequests.Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).Select(x=>x.OwnerId).Distinct().ToArrayAsync(ct);
        foreach(var owner in owners)if(await db.DownloadRequests.Where(x=>active.Contains(x.TorrentJobId??Guid.Empty) && x.OwnerId==owner && x.RemovedAt==null).Select(x=>x.TorrentJobId).Distinct().CountAsync(ct)>=p.ActivePerUser)return false;return true;
    }
}
