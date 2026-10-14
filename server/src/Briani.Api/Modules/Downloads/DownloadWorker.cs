using System.Text.Json;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;
using Briani.Api.Integrations.QBittorrent;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Downloads;
public sealed class DownloadWorker(IServiceScopeFactory scopes,ITorrentEngine engine,WriteGate gate,ContainedStorage storage,SecretStore secrets,ServerOptions options,TimeProvider clock,ISafeDns dns,MediaReaders readers,DownloadJobLocks jobLocks,TorrentAvailability availability):BackgroundService
{
    private readonly SemaphoreSlim execution=new(1,1),pollExecution=new(1,1);private readonly string leaseOwner=Guid.NewGuid().ToString("N");
    internal TimeSpan MetadataOperationTimeout {get;set;}=TimeSpan.FromSeconds(120);
    public Action<string>? TransactionBoundary{get;set;}
    protected override async Task ExecuteAsync(CancellationToken ct)
    {if(!options.BackgroundDownloads)return;await Task.WhenAll(CommandLoopAsync(ct),PollLoopAsync(ct));}
    private async Task CommandLoopAsync(CancellationToken ct)
    {while(!ct.IsCancellationRequested)try{if(!await RunOnceAsync(ct))await Task.Delay(TimeSpan.FromSeconds(1),clock,ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}catch(Exception){await Task.Delay(TimeSpan.FromSeconds(2),clock,ct);}}
    private async Task PollLoopAsync(CancellationToken ct)
    {while(!ct.IsCancellationRequested)try{await PollOnceAsync(ct);await Task.Delay(TimeSpan.FromSeconds(2),clock,ct);}catch(OperationCanceledException)when(ct.IsCancellationRequested){break;}catch(Exception){await Task.Delay(TimeSpan.FromSeconds(2),clock,ct);}}
    public async Task<bool> RunOnceAsync(CancellationToken ct=default)
    {
        await execution.WaitAsync(ct);try{return await RunCoreAsync(ct);}finally{execution.Release();}
    }
    private async Task<bool> RunCoreAsync(CancellationToken ct)
    {
        using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<BrianiDb>();WorkJob? work;
        using(await gate.EnterAsync(ct))
        {
            var now=clock.GetUtcNow();work=await db.Jobs.Where(x=>x.Kind=="download" && x.NextAttemptAt<=now && (x.State=="queued" || x.State=="running" && x.LeaseUntil<now)).OrderBy(x=>x.CreatedAt).FirstOrDefaultAsync(ct);if(work is null)return false;
            work.State="running";work.LeaseOwner=leaseOwner;work.LeaseUntil=now.AddMinutes(2);work.Attempt++;work.UpdatedAt=now;await db.SaveChangesAsync(ct);
        }
        var op=await db.Operations.SingleAsync(x=>x.Id==work.TargetId,ct);if(op.State=="completed" || op.State=="failed"){using(await gate.EnterAsync(ct)){work.State="completed";await db.SaveChangesAsync(ct);}return true;}
        var request=await db.DownloadRequests.SingleAsync(x=>x.Id==op.TargetId,ct);using var jobGuard=await jobLocks.EnterAsync(request.TorrentJobId??throw new ApiException(409,"metadata_unavailable"),ct);var job=await db.TorrentJobs.SingleAsync(x=>x.Id==request.TorrentJobId,ct);var command=JsonSerializer.Deserialize<DownloadCommand>(op.PayloadJson,DownloadCommands.Json)??throw new ApiException(409,"invalid_download_command");
        var commandAuthorizationDenied=false;
        try
        {
            var permissions=scope.ServiceProvider.GetRequiredService<PermissionService>();var access=scope.ServiceProvider.GetRequiredService<DownloadAccess>();var user=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==op.UserId && x.Enabled && !x.MustChangePassword,ct);if(user is null){commandAuthorizationDenied=true;throw new ApiException(403,"permission_changed");}var actor=new Actor(user.Id,command.SessionId,user.Role);
            var library=await permissions.RequireLibraryAsync(actor,request.LibraryId,ct:ct);
            async Task Reauthorize(){try{await access.RequireCommandAsync(actor,request,command,ct);}catch(ApiException error)when(error.Code is "not_found" or "forbidden" or "permission_changed"){commandAuthorizationDenied=true;throw;}}
            await Reauthorize();
            if(command.Action is "add" or "retry" && (job.ManagedRootIdentity is null || job.EncryptedMetainfo is not null))await InitializeStageAsync(db,job,library,ct);
            if(command.Action!="remove" || job.ManagedRootIdentity is not null){using var root=storage.OpenLibrary(library);using var staged=root.Directory(job.ManagedPath);if(staged.Identity!=job.ManagedRootIdentity)throw new ApiException(409,"file_identity_changed");}
            using(await gate.EnterAsync(ct)){op.State="running";op.UpdatedAt=clock.GetUtcNow();await db.SaveChangesAsync(ct);}TransactionBoundary?.Invoke("intent_committed");
            if(command.Action is "add" or "retry" && job.MetadataStatus!="ready")await AddOrRecoverAsync(db,request,job,library,Reauthorize,ct);
            else if(command.Action=="retry" && job.MetadataStatus=="ready" && (await FindCandidatesAsync(job,job.UpstreamId??job.InfoHashV1??job.InfoHashV2![..40],ct)).Length==0)
            {await RequireNoReadersAsync(db,job,ct);job.UpstreamId=null;await AddOrRecoverAsync(db,request,job,library,Reauthorize,ct);await ApplySelectionAsync(db,job,library,Reauthorize,ct);}
            else if(command.Action=="remove")
            {await RemoveAsync(db,request,job,library,actor,permissions,command,Reauthorize,ct);}
            else
            {
                var upstream=await RequireOwnedAsync(job,library,ct);job.UpstreamId=upstream.Hash;
                switch(command.Action)
                {
                    case "select":if(!command.PreserveTransfer){await RequireNoReadersAsync(db,job,ct);await ApplySelectionAsync(db,job,library,Reauthorize,ct);}break;
                    case "pause":await Reauthorize();await engine.StopAsync(upstream.Hash,ct);break;
                    case "resume":case "retry":await ApplySelectionAsync(db,job,library,Reauthorize,ct);break;
                    case "settings":await Reauthorize();var s=JsonSerializer.Deserialize<DownloadSettings>(job.SettingsJson,DownloadCommands.Json)!;await engine.ApplyLimitsAsync(upstream.Hash,new(s.DownloadLimitBytesPerSecond,s.UploadLimitBytesPerSecond,s.RatioLimit,s.SeedTimeMinutes,s.QueuePosition,(s.Tags??[]).Append(job.OwnershipTag).ToArray()),ct);break;
                    case "reannounce":await Reauthorize();await engine.ReannounceAsync(upstream.Hash,ct);break;
                    case "recheck":await Reauthorize();await RequireNoReadersAsync(db,job,ct);await StopSettledAsync(upstream.Hash,ct);await RequireNoReadersAsync(db,job,ct);await ClearAvailabilityAsync(db,job,ct);await Reauthorize();await engine.RecheckAsync(upstream.Hash,ct);job.EngineState="checking";break;
                    case "remove":await RemoveAsync(db,request,job,library,actor,permissions,command,Reauthorize,ct);break;
                    default:throw new ApiException(400,"invalid_download_action");
                }
            }
            TransactionBoundary?.Invoke("upstream_applied");
            using(await gate.EnterAsync(ct)){op.State="completed";op.UpdatedAt=clock.GetUtcNow();work.State="completed";work.LeaseUntil=null;work.UpdatedAt=op.UpdatedAt;request.UpdatedAt=op.UpdatedAt;job.UpdatedAt=op.UpdatedAt;await db.SaveChangesAsync(ct);}return true;
        }
        catch(OperationCanceledException)when(ct.IsCancellationRequested){throw;}
        catch(Exception error)when(error is ApiException or EngineFailure or IOException or DbUpdateConcurrencyException)
        {
            var code=error is ApiException api?api.Code:error is EngineFailure upstream?upstream.Code:error is DbUpdateConcurrencyException?"download_conflict":"disk_unavailable";
            using(await gate.EnterAsync(ct))
            {db.ChangeTracker.Clear();op=await db.Operations.SingleAsync(x=>x.Id==work.TargetId,ct);work=await db.Jobs.SingleAsync(x=>x.Id==work.Id,ct);request=await db.DownloadRequests.SingleAsync(x=>x.Id==op.TargetId,ct);job=await db.TorrentJobs.SingleAsync(x=>x.Id==request.TorrentJobId,ct);
                var retry=(error is EngineFailure or DbUpdateConcurrencyException) && work.Attempt<3;work.State=retry?"queued":"failed";work.NextAttemptAt=clock.GetUtcNow().AddSeconds(5);work.LeaseUntil=null;work.LastErrorCode=code;op.State=retry?"pending":"failed";op.ErrorCode=code;op.UpdatedAt=clock.GetUtcNow();
                if(!retry)
                {
                    if((commandAuthorizationDenied || code=="not_found") && op.UserId!=request.OwnerId && await LiveSelectionsAuthorizedAsync(db,job,ct))
                    {if(job.RetiredAt is null)job.DesiredState=command.PreviousDesiredState??(job.EngineState is "downloading" or "seeding" or "queued"?"running":"stopped");}
                    else{job.ErrorCode=code;job.DesiredState="stopped";request.ErrorCode=code;request.State=code=="metadata_timeout"?"stalled":"failed";request.SourceState=job.MetadataStatus=="ready"?"ready":"failed";request.Version++;request.UpdatedAt=clock.GetUtcNow();}
                }
                await db.SaveChangesAsync(ct);}
            return true;
        }
    }
    private async Task InitializeStageAsync(BrianiDb db,TorrentJob job,Library library,CancellationToken ct)
    {
        using var held=await gate.EnterAsync(ct);using var root=storage.OpenLibrary(library);DownloadCommands.EnsureDirectory(root,".briani");DownloadCommands.EnsureDirectory(root,".briani/staging");DownloadCommands.EnsureDirectory(root,job.ManagedPath);using var stage=root.Directory(job.ManagedPath);
        if(job.ManagedRootIdentity is null && stage.Names().Count!=0 || job.ManagedRootIdentity is not null && job.ManagedRootIdentity!=stage.Identity)throw new ApiException(409,"stage_identity_unknown");job.ManagedRootIdentity=stage.Identity;await db.SaveChangesAsync(ct);TransactionBoundary?.Invoke("stage_committed");
        if(job.EncryptedMetainfo is not null)
        {
            var bytes=Convert.FromBase64String(secrets.Decrypt(job.EncryptedMetainfo));if(bytes.Length>16777216)throw new ApiException(409,"invalid_metainfo");ValidateHashes(job,Metainfo.Parse(bytes));using var state=new ContainedDirectory(options.StateRoot);DownloadCommands.EnsureDirectory(state,"torrent-metainfo");var path=$"torrent-metainfo/{job.Id:N}.torrent";
            if(state.Volume().FreeBytes<2L*bytes.Length+33554432L)throw new ApiException(507,"disk_full");
            FileStream output;
            if(job.MetadataFileIdentity is not null)output=state.OpenFile(path,job.MetadataFileIdentity,true);
            else
            {
                try{output=state.CreateFile(path);}
                catch(ApiException e)when(e.Code=="path_unavailable")
                {output=state.OpenFile(path);if(output.Length!=0){output.Dispose();throw new ApiException(409,"metadata_storage_conflict");}output.Dispose();output=state.OpenFile(path,write:true);}
                job.MetadataFileIdentity=ContainedDirectory.Inspect(output).Key;job.MetadataRelativePath=path;await db.SaveChangesAsync(ct);TransactionBoundary?.Invoke("metadata_identity_committed");
            }
            using(output){output.SetLength(0);await output.WriteAsync(bytes,ct);output.Flush(true);}TransactionBoundary?.Invoke("metadata_written");
            job.MetadataRelativePath=path;job.EncryptedMetainfo=null;await db.SaveChangesAsync(ct);
        }
    }
    private string SavePath(Library library,TorrentJob job)=>Path.Combine(options.DataRoot,library.RootPath,job.ManagedPath);
    private static bool HashMatches(TorrentJob job,EngineTorrent t)=> (job.InfoHashV1 is null || job.InfoHashV1.Equals(t.InfoHashV1,StringComparison.OrdinalIgnoreCase)) && (job.InfoHashV2 is null || job.InfoHashV2.Equals(t.InfoHashV2,StringComparison.OrdinalIgnoreCase));
    private bool Owned(TorrentJob job,Library library,EngineTorrent t)=>HashMatches(job,t)&&t.Tags.Contains(job.OwnershipTag,StringComparer.Ordinal)&&Path.TrimEndingDirectorySeparator(t.SavePath)==SavePath(library,job);
    private async Task<EngineTorrent> RequireOwnedAsync(TorrentJob job,Library library,CancellationToken ct)
    {
        var hash=job.UpstreamId??job.InfoHashV1??job.InfoHashV2![..40];var found=await FindCandidatesAsync(job,hash,ct);if(found.Length>1)throw new ApiException(409,"torrent_not_owned");var t=found.SingleOrDefault()??throw new EngineFailure("engine_job_missing");if(!Owned(job,library,t))throw new ApiException(409,"torrent_not_owned");job.UpstreamId=t.Hash;return t;
    }
    private async Task<EngineTorrent[]> FindCandidatesAsync(TorrentJob job,string hash,CancellationToken ct)
    {
        var found=await engine.TorrentsAsync(hash,ct);if(found.Length>0)return found;
        // Hybrid magnets initially use v1, then adopt the engine's truncated v2 ID after metadata. Preserve full typed identities.
        return (await engine.TorrentsAsync(ct:ct)).Where(t=>t.Hash==hash || job.InfoHashV1 is not null && t.InfoHashV1==job.InfoHashV1 || job.InfoHashV2 is not null && t.InfoHashV2==job.InfoHashV2).ToArray();
    }
    private async Task AddOrRecoverAsync(BrianiDb db,DownloadRequest request,TorrentJob job,Library library,Func<Task> reauthorize,CancellationToken ct)
    {
        await engine.VersionAsync(ct);await engine.ConfigureManagedAsync(ct);var hash=job.UpstreamId??job.InfoHashV1??job.InfoHashV2![..40];var found=await FindCandidatesAsync(job,hash,ct);
        if(found.Length>0){if(found.Length!=1 || !Owned(job,library,found[0]))throw new ApiException(409,"torrent_not_owned");job.UpstreamId=found[0].Hash;}
        else
        {
            byte[]? torrent=null;if(job.MetadataRelativePath is not null){using var root=new ContainedDirectory(options.StateRoot);using var input=root.OpenFile(job.MetadataRelativePath,job.MetadataFileIdentity);if(input.Length>16777216)throw new ApiException(409,"invalid_metainfo");torrent=new byte[(int)input.Length];await input.ReadExactlyAsync(torrent,ct);ValidateHashes(job,Metainfo.Parse(torrent));}
            await reauthorize();
            try{await engine.AddAsync(new(torrent,job.EncryptedMagnet is null?null:secrets.Decrypt(job.EncryptedMagnet),SavePath(library,job),job.OwnershipTag,torrent is null),ct);}catch(EngineFailure){var recovered=await FindCandidatesAsync(job,hash,ct);if(recovered.Length!=1 || !Owned(job,library,recovered[0]))throw;job.UpstreamId=recovered[0].Hash;}
            if(job.UpstreamId is null){var added=await RequireOwnedAsync(job,library,ct);job.UpstreamId=added.Hash;}
        }
        var managedLimits=JsonSerializer.Deserialize<DownloadSettings>(job.SettingsJson,DownloadCommands.Json);
        if(managedLimits is not null && (managedLimits.RatioLimit is not null || managedLimits.SeedTimeMinutes is not null))
        {await reauthorize();await engine.ApplyLimitsAsync(job.UpstreamId!,new(RatioLimit:managedLimits.RatioLimit,SeedTimeMinutes:managedLimits.SeedTimeMinutes),ct);}
        TransactionBoundary?.Invoke("after_add");using(await gate.EnterAsync(ct)){await db.SaveChangesAsync(ct);}
        if(job.MetadataRelativePath is not null)await FetchMetadataAsync(db,job,library,ct);
    }
    private static void ValidateHashes(TorrentJob job,MetainfoDescriptor metadata)
    {if(job.InfoHashV1 is not null && job.InfoHashV1!=metadata.InfoHashV1 || job.InfoHashV2 is not null && job.InfoHashV2!=metadata.InfoHashV2)throw new ApiException(409,"source_identity_changed");DownloadLayout.PieceCount(metadata);}
    private async Task FetchMetadataAsync(BrianiDb db,TorrentJob job,Library library,CancellationToken ct)
    {
        var remaining=job.MetadataDeadline is DateTimeOffset deadline?deadline-clock.GetUtcNow():MetadataOperationTimeout;
        var timeout=remaining<MetadataOperationTimeout?remaining:MetadataOperationTimeout;if(timeout<=TimeSpan.Zero)timeout=TimeSpan.FromMilliseconds(1);
        using var timer=new CancellationTokenSource(timeout,clock);using var cancel=CancellationTokenSource.CreateLinkedTokenSource(ct,timer.Token);
        try{await FetchMetadataCoreAsync(db,job,library,cancel.Token);}
        catch(OperationCanceledException)when(!ct.IsCancellationRequested)
        {
            using var cleanupTimer=new CancellationTokenSource(TimeSpan.FromSeconds(20),clock);using var cleanup=CancellationTokenSource.CreateLinkedTokenSource(ct,cleanupTimer.Token);var released=false;
            try{var owned=await RequireOwnedAsync(job,library,cleanup.Token);await StopSettledAsync(owned.Hash,cleanup.Token);if(job.MetadataStatus!="ready"){await engine.RemoveAsync(owned.Hash,false,cleanup.Token);released=true;}}catch(Exception error)when(error is EngineFailure or ApiException or OperationCanceledException){}
            using var h=await gate.EnterAsync(ct);job.ErrorCode="metadata_timeout";job.DesiredState="stopped";if(job.MetadataStatus!="ready"){job.MetadataStatus="failed";job.MetadataDeadline=null;if(released){job.UpstreamId=null;job.ReservedBytes=0;}foreach(var request in await db.DownloadRequests.Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).ToArrayAsync(ct)){request.State="stalled";request.SourceState="failed";request.ErrorCode="metadata_timeout";if(released)request.ReservedBytes=0;request.Version++;request.UpdatedAt=clock.GetUtcNow();}}await db.SaveChangesAsync(ct);throw new ApiException(503,"metadata_timeout");
        }
    }
    private async Task FetchMetadataCoreAsync(BrianiDb db,TorrentJob job,Library library,CancellationToken ct)
    {
        var upstream=await RequireOwnedAsync(job,library,ct);if(upstream.State is "metaDL" or "forcedMetaDL")return;await StopSettledAsync(upstream.Hash,ct);
        var bytes=await engine.ExportAsync(upstream.Hash,ct);var metadata=Metainfo.Parse(bytes);ValidateHashes(job,metadata);await SourceValidation.ValidateTrackerDnsAsync(metadata.Trackers,dns,ct);
        var layout=DownloadLayout.Map(job.Id,metadata,await engine.FilesAsync(upstream.Hash,ct));
        await engine.SetFilePriorityAsync(upstream.Hash,layout.Where(x=>x.UpstreamFileIndex>=0).Select(x=>x.UpstreamFileIndex).ToArray(),0,ct);
        if((await engine.FilesAsync(upstream.Hash,ct)).Any(x=>x.Priority!=0))throw new ApiException(409,"engine_priority_mismatch");
        if(job.MetadataRelativePath is null || job.EncryptedMetainfo is not null)
        {
            if(job.EncryptedMetainfo is null){using var h=await gate.EnterAsync(ct);using var state=new ContainedDirectory(options.StateRoot);if(state.Volume().FreeBytes<6L*bytes.Length+67108864L)throw new ApiException(507,"disk_full");job.EncryptedMetainfo=secrets.Encrypt(Convert.ToBase64String(bytes));await db.SaveChangesAsync(ct);}
            await InitializeStageAsync(db,job,library,ct);
        }
        using var held=await gate.EnterAsync(ct);var current=await db.TorrentJobs.AsNoTracking().SingleAsync(x=>x.Id==job.Id,ct);if(current.Generation!=job.Generation || current.RetiredAt is not null)throw new ApiException(409,"generation_changed");var live=await db.Libraries.AsNoTracking().SingleAsync(x=>x.Id==job.LibraryId,ct);if(!live.Enabled || !live.Online || live.ReadOnly)throw new ApiException(409,"disk_unavailable");
        if(!await db.DownloadFiles.AnyAsync(x=>x.TorrentJobId==job.Id,ct))db.DownloadFiles.AddRange(layout);
        job.InfoHashV1=metadata.InfoHashV1;job.InfoHashV2=metadata.InfoHashV2;job.Name=metadata.Name;job.TotalBytes=metadata.Files.Where(x=>!x.Padding).Sum(x=>x.Bytes);job.PieceLength=metadata.PieceLength;job.PieceCount=DownloadLayout.PieceCount(metadata);job.MetadataStatus="ready";job.EngineState="stopped";job.MetadataDeadline=null;
        foreach(var request in await db.DownloadRequests.Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).ToArrayAsync(ct)){request.SourceState="ready";request.State="awaitingSelection";request.Version++;request.UpdatedAt=clock.GetUtcNow();}
        job.UpdatedAt=clock.GetUtcNow();await db.SaveChangesAsync(ct);
    }
    private async Task StopSettledAsync(string hash,CancellationToken ct)
    {
        await engine.StopAsync(hash,ct);var start=clock.GetTimestamp();for(int i=0;i<40;i++)
        {var rows=await engine.TorrentsAsync(hash,ct);if(rows.Length==0)return;if(rows[0].State.StartsWith("stopped",StringComparison.Ordinal)||rows[0].State.StartsWith("paused",StringComparison.Ordinal))return;await Task.Delay(TimeSpan.FromMilliseconds(250),clock,ct);}throw new EngineFailure("engine_stop_timeout");
    }
    private async Task ApplySelectionAsync(BrianiDb db,TorrentJob job,Library library,Func<Task> reauthorize,CancellationToken ct)
    {
        if(job.MetadataStatus!="ready" || job.UpstreamId is null)throw new ApiException(409,"metadata_unavailable");await reauthorize();await StopSettledAsync(job.UpstreamId,ct);await reauthorize();
        var files=await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).ToArrayAsync(ct);var selected=await db.DownloadRequestFiles.Where(x=>x.Selected && db.DownloadRequests.Any(r=>r.Id==x.DownloadRequestId && r.TorrentJobId==job.Id && r.RemovedAt==null)).ToArrayAsync(ct);
        foreach(var file in files){var choices=selected.Where(x=>x.DownloadFileId==file.Id).ToArray();file.Wanted=!file.Padding && choices.Length>0;file.FilePriority=file.Wanted?choices.Max(x=>x.Priority):0;file.PlaybackState=file.Wanted?"waitingForData":"notSelected";}
        foreach(var group in files.Where(x=>x.UpstreamFileIndex>=0).GroupBy(x=>x.FilePriority)){await reauthorize();await engine.SetFilePriorityAsync(job.UpstreamId,group.Select(x=>x.UpstreamFileIndex).ToArray(),group.Key,ct);}
        var observed=await engine.FilesAsync(job.UpstreamId,ct);foreach(var file in files.Where(x=>x.UpstreamFileIndex>=0))if(observed.SingleOrDefault(x=>x.Index==file.UpstreamFileIndex)?.Priority!=file.FilePriority)throw new ApiException(409,"engine_priority_mismatch");
        await reauthorize();await engine.EnsureSequentialAsync(job.UpstreamId,true,ct);await reauthorize();await engine.EnsureMetadataAssistAsync(job.UpstreamId,true,ct);var t=await RequireOwnedAsync(job,library,ct);if(!t.Sequential || !t.MetadataAssist)throw new ApiException(409,"engine_sequential_mismatch");job.Sequential=true;job.MetadataAssist=true;
        using(await gate.EnterAsync(ct)){await reauthorize();if(job.DesiredState=="running" && await scopesAdmission(db,job,ct)){job.EngineState="starting";await db.SaveChangesAsync(ct);}else{job.EngineState=job.DesiredState=="running"?"queued":"paused";await db.SaveChangesAsync(ct);return;}}
        await reauthorize();await RequireReservationsAsync(db,job,library,ct);await reauthorize();await engine.StartAsync(job.UpstreamId,ct);job.EngineState="downloading";
    }
    private async Task<bool> scopesAdmission(BrianiDb db,TorrentJob job,CancellationToken ct)=>await new DownloadAdmission(db,storage).SlotAvailableAsync(job,ct);
    private async Task RequireNoReadersAsync(BrianiDb db,TorrentJob job,CancellationToken ct)
    {using var h=await gate.EnterAsync(ct);var ids=await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).Select(x=>x.Id).ToArrayAsync(ct);var media=await db.MediaItems.Where(x=>ids.Contains(x.DownloadFileId??Guid.Empty)).Select(x=>x.Id).ToArrayAsync(ct);if(media.Concat(ids).Any(readers.HasReaders))throw new ApiException(409,"active_reader_conflict");}
    private async Task ClearAvailabilityAsync(BrianiDb db,TorrentJob job,CancellationToken ct)
    {
        using var held=await gate.EnterAsync(ct);foreach(var file in await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).ToArrayAsync(ct)){file.Completed=false;file.PlaybackState="unavailable";file.DownloadedBytes=0;file.ContiguousBytes=0;}
        job.SelectedComplete=false;job.Imported=false;await DownloadCommands.FenceAsync(db,job.Id,ct,readers);await db.SaveChangesAsync(ct);
    }
    private async Task RemoveAsync(BrianiDb db,DownloadRequest request,TorrentJob job,Library library,Actor actor,PermissionService permissions,DownloadCommand command,Func<Task> reauthorize,CancellationToken ct)
    {
        await reauthorize();var others=await db.DownloadRequests.AnyAsync(x=>x.TorrentJobId==job.Id && x.Id!=request.Id && x.RemovedAt==null,ct);
        if(others && !command.DeleteData)
        {
            var remaining=await db.DownloadRequestFiles.Where(x=>x.Selected && x.DownloadRequestId!=request.Id && db.DownloadRequests.Any(r=>r.Id==x.DownloadRequestId && r.TorrentJobId==job.Id && r.RemovedAt==null)).ToArrayAsync(ct);
            var allFiles=await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).ToArrayAsync(ct);var changed=new List<DownloadFile>();
            foreach(var file in allFiles){var selected=remaining.Where(x=>x.DownloadFileId==file.Id).ToArray();var priority=file.Padding||selected.Length==0?0:selected.Max(x=>x.Priority);if(priority!=file.FilePriority){file.FilePriority=priority;file.Wanted=priority>0;file.PlaybackState=file.Wanted?(file.Completed?"complete":"waitingForData"):"notSelected";file.Version++;changed.Add(file);}}
            if(changed.Count>0){job.Generation++;await DownloadCommands.FenceAsync(db,job.Id,ct,readers);using(var h=await gate.EnterAsync(ct))await db.SaveChangesAsync(ct);}
            var upstream=await RequireOwnedAsync(job,library,ct);await reauthorize();foreach(var group in allFiles.Where(x=>x.UpstreamFileIndex>=0).GroupBy(x=>x.FilePriority)){await reauthorize();await engine.SetFilePriorityAsync(upstream.Hash,group.Select(x=>x.UpstreamFileIndex).ToArray(),group.Key,ct);}var observed=await engine.FilesAsync(upstream.Hash,ct);if(allFiles.Any(f=>f.UpstreamFileIndex>=0 && observed.SingleOrDefault(x=>x.Index==f.UpstreamFileIndex)?.Priority!=f.FilePriority))throw new ApiException(409,"engine_priority_mismatch");
            await reauthorize();request.RemovedAt=clock.GetUtcNow();request.EncryptedSourceReference="";request.State="removed";request.ReservedBytes=0;job.ReservedBytes=allFiles.Where(x=>x.Wanted).Sum(x=>Math.Max(0,x.SizeBytes-x.DownloadedBytes)+(x.Completed?0:2*job.PieceLength));return;
        }
        var files=await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id && !x.Padding).ToArrayAsync(ct);var media=await db.MediaItems.Where(x=>files.Select(f=>f.Id).Contains(x.DownloadFileId??Guid.Empty)).ToArrayAsync(ct);
        if(command.DeleteData && media.Select(x=>x.Id).Concat(files.Select(x=>x.Id)).Any(readers.HasReaders)){if(!command.Force)throw new ApiException(409,"active_reader_conflict");foreach(var id in media.Select(x=>x.Id).Concat(files.Select(x=>x.Id)))readers.Cancel(id);if(media.Select(x=>x.Id).Concat(files.Select(x=>x.Id)).Any(readers.HasReaders))throw new EngineFailure("readers_closing");}
        var removalHash=job.UpstreamId??job.InfoHashV1??job.InfoHashV2?[..40];if(removalHash is not null){var found=await FindCandidatesAsync(job,removalHash,ct);if(found.Length>0){if(found.Length!=1 || !Owned(job,library,found[0]))throw new ApiException(409,"torrent_not_owned");await reauthorize();await StopSettledAsync(found[0].Hash,ct);if(command.DeleteData)await CaptureDeletionIdentitiesAsync(db,job,library,files,ct);await reauthorize();await engine.RemoveAsync(found[0].Hash,false,ct);}}TransactionBoundary?.Invoke("engine_removed");
        if(command.DeleteData)
        {
            await permissions.RequireLibraryAsync(actor,library.Id,"manage",ct);using var root=storage.OpenLibrary(library);using var staged=root.Directory(job.ManagedPath);if(staged.Identity!=job.ManagedRootIdentity)throw new ApiException(409,"file_identity_changed");
            foreach(var file in files)
            {try{var node=staged.Inspect(file.RelativePath);if(!node.IsFile || file.FileIdentity is null || node.Key!=file.FileIdentity)throw new ApiException(409,"payload_identity_unknown");await permissions.RequireLibraryAsync(actor,library.Id,"manage",ct);staged.Unlink(file.RelativePath);}catch(ApiException e)when(e.Code=="path_unavailable"){} }
            foreach(var item in media.Where(x=>x.SourceKind=="virtual")){item.Lifecycle="deleted";item.Version++;}
            foreach(var item in media.Where(x=>x.SourceKind=="hardlink" && x.Lifecycle is "available" or "trashed")){var file=files.Single(x=>x.Id==item.DownloadFileId);try{var node=root.Inspect(item.RelativePath);if(node.IsFile && node.Key==item.FileIdentity && node.Length==item.SizeBytes && node.MtimeNs==item.MtimeNs && file.DownloadedBytes==file.SizeBytes){file.Completed=true;file.PlaybackState="complete";}}catch(ApiException){}}
            job.PayloadRemoved=true;
        }
        await reauthorize();await RemoveMetadataCacheAsync(job,ct);await reauthorize();job.RetiredAt=clock.GetUtcNow();job.EncryptedMetainfo=null;job.EncryptedMagnet=null;job.UpstreamId=null;job.ReservedBytes=0;job.EngineState="stopped";job.DesiredState="removed";
        foreach(var r in await db.DownloadRequests.Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).ToArrayAsync(ct)){r.State="removed";r.RemovedAt=clock.GetUtcNow();r.EncryptedSourceReference="";r.ReservedBytes=0;r.Version++;}
    }
    private Task RemoveMetadataCacheAsync(TorrentJob job,CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();if(job.MetadataRelativePath is not null)
        {
            if(job.MetadataRelativePath!=$"torrent-metainfo/{job.Id:N}.torrent" || job.MetadataFileIdentity is null)throw new ApiException(409,"metadata_identity_unknown");
            using var root=new ContainedDirectory(options.StateRoot);try{var node=root.Inspect(job.MetadataRelativePath);if(!node.IsFile || node.Key!=job.MetadataFileIdentity)throw new ApiException(409,"metadata_identity_unknown");root.Unlink(job.MetadataRelativePath);}catch(ApiException e)when(e.Code=="path_unavailable"){}
            job.MetadataRelativePath=null;job.MetadataFileIdentity=null;
        }
        TransactionBoundary?.Invoke("metadata_cache_removed");return Task.CompletedTask;
    }
    private async Task PruneRetiredCachesAsync(BrianiDb db,CancellationToken ct)
    {
        using var h=await gate.EnterAsync(ct);var now=clock.GetUtcNow();var old=await db.Jobs.Where(x=>x.Kind=="download" && (x.State=="completed" || x.State=="failed") && !db.Operations.Any(o=>o.Id==x.TargetId && o.ExpiresAt>now)).OrderBy(x=>x.UpdatedAt).Take(500).ToArrayAsync(ct);db.Jobs.RemoveRange(old);foreach(var job in await db.TorrentJobs.Where(x=>x.RetiredAt!=null && x.MetadataRelativePath!=null).OrderBy(x=>x.RetiredAt).Take(32).ToArrayAsync(ct))try{await RemoveMetadataCacheAsync(job,ct);}catch(ApiException){/* Preserve uncertain entries for an administrator; never delete a replacement. */}await db.SaveChangesAsync(ct);db.ChangeTracker.Clear();
    }
    private async Task CaptureDeletionIdentitiesAsync(BrianiDb db,TorrentJob job,Library library,DownloadFile[] files,CancellationToken ct)
    {
        using var h=await gate.EnterAsync(ct);using var root=storage.OpenLibrary(library);using var stage=root.Directory(job.ManagedPath);if(stage.Identity!=job.ManagedRootIdentity)throw new ApiException(409,"file_identity_changed");
        foreach(var file in files)try{var node=stage.Inspect(file.RelativePath);if(!node.IsFile || file.FileIdentity is not null && file.FileIdentity!=node.Key || node.Length>file.SizeBytes)throw new ApiException(409,"payload_identity_unknown");file.FileIdentity=node.Key;file.MtimeNs=node.MtimeNs;}catch(ApiException e)when(e.Code=="path_unavailable"){}
        await db.SaveChangesAsync(ct);TransactionBoundary?.Invoke("deletion_identities_committed");
    }
    public async Task PollOnceAsync(CancellationToken ct=default)
    {
        await pollExecution.WaitAsync(ct);try{await PollCoreAsync(ct);}finally{pollExecution.Release();}
    }
    private async Task PollCoreAsync(CancellationToken ct)
    {
        using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<BrianiDb>();await PruneRetiredCachesAsync(db,ct);var pendingProbe=await (from item in db.MediaItems.AsNoTracking() join meta in db.MediaMetadata.AsNoTracking() on item.Id equals meta.MediaItemId
            where item.DownloadFileId!=null && item.Lifecycle=="available" && (meta.ProbeStatus=="pending" || meta.ContentGeneration!=item.Version) && db.DownloadFiles.Any(f=>f.Id==item.DownloadFileId && f.Completed) && db.Libraries.Any(l=>l.Id==item.LibraryId && l.Enabled && l.Online)
            orderby item.IndexedAt select (Guid?)item.Id).FirstOrDefaultAsync(ct);
        var importBudget=1;if(pendingProbe is Guid pending){if(await scope.ServiceProvider.GetRequiredService<DownloadImport>().ProbePendingAsync(pending,ct))importBudget--;}
        var jobs=await db.TorrentJobs.AsNoTracking().Where(x=>x.RetiredAt==null).OrderBy(x=>x.CreatedAt).Take(512).ToArrayAsync(ct);if(jobs.Length==0)return;
        EngineTorrent[] upstream;try{await engine.VersionAsync(ct);upstream=await engine.TorrentsAsync(ct:ct);}catch(EngineFailure){using var h=await gate.EnterAsync(ct);foreach(var job in jobs){var row=await db.TorrentJobs.SingleAsync(x=>x.Id==job.Id,ct);row.ErrorCode="engine_unavailable";row.LastContactAt=null;if(!row.SelectedComplete){row.Generation++;await ClearAvailabilityInGateAsync(db,row,ct);}}await db.SaveChangesAsync(ct);return;}
        foreach(var snapshot in jobs)
        {
            ct.ThrowIfCancellationRequested();db.ChangeTracker.Clear();var job=await db.TorrentJobs.SingleAsync(x=>x.Id==snapshot.Id,ct);var library=await db.Libraries.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==job.LibraryId,ct);if(library is null)continue;
            var t=upstream.SingleOrDefault(x=>x.Hash==job.UpstreamId || HashMatches(job,x));IDisposable? observationGuard=null;var observedRevision=job.Revision;var observationGeneration=job.Generation;
            try
            {
                observationGuard=await jobLocks.EnterAsync(job.Id,ct);
                var observedCurrent=await db.TorrentJobs.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==job.Id,ct);
                if(observedCurrent is null || observedCurrent.RetiredAt is not null || observedCurrent.Revision!=snapshot.Revision || observedCurrent.Revision!=job.Revision || await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && (x.State=="pending"||x.State=="running") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==job.Id),ct))continue;
                if(!await LiveSelectionsAuthorizedAsync(db,job,ct) && job.MetadataStatus=="ready"){if(t is not null && Owned(job,library,t))await engine.StopAsync(t.Hash,ct);throw new ApiException(403,"permission_changed");}
                if(t is null){if(job.UpstreamId is not null){using var h=await gate.EnterAsync(ct);job.ErrorCode="engine_job_missing";job.Generation++;if(!job.SelectedComplete)await ClearAvailabilityInGateAsync(db,job,ct);await db.SaveChangesAsync(ct);}continue;}
                if(!Owned(job,library,t))throw new ApiException(409,"torrent_not_owned");job.UpstreamId=t.Hash;
                using(var root=storage.OpenLibrary(library)){using var stage=root.Directory(job.ManagedPath);if(stage.Identity!=job.ManagedRootIdentity)throw new ApiException(409,"file_identity_changed");var v=root.Volume();var p=await new DownloadAdmission(db,storage).PolicyAsync(ct);if(!library.Enabled||!library.Online||library.ReadOnly||!v.Writable||v.FreeBytes<Math.Max(p.DiskFloorBytes,(long)(v.TotalBytes*p.DiskFloorFraction))){await engine.StopAsync(t.Hash,ct);throw new ApiException(507,"disk_full");}}
                if(await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && (x.State=="pending"||x.State=="running") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==job.Id),ct))continue;
                if(job.MetadataStatus=="pending")
                {
                    var fresh=await db.TorrentJobs.AsNoTracking().SingleAsync(x=>x.Id==job.Id,ct);if(fresh.RetiredAt is not null || fresh.Revision!=job.Revision || await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && (x.State=="pending"||x.State=="running") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==job.Id),ct))continue;
                    if(job.MetadataDeadline<=clock.GetUtcNow()){await StopSettledAsync(t.Hash,ct);await engine.RemoveAsync(t.Hash,false,ct);using var h=await gate.EnterAsync(ct);job.ErrorCode="metadata_timeout";job.MetadataStatus="failed";job.ReservedBytes=0;job.UpstreamId=null;foreach(var r in await db.DownloadRequests.Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).ToArrayAsync(ct)){r.State="stalled";r.ErrorCode="metadata_timeout";r.ReservedBytes=0;r.Version++;}await db.SaveChangesAsync(ct);continue;}
                    if(t.State is not("metaDL" or "forcedMetaDL"))await FetchMetadataAsync(db,job,library,ct);continue;
                }
                if(await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && (x.State=="pending"||x.State=="running") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==job.Id),ct))continue;
                if(t.State.StartsWith("checking",StringComparison.Ordinal) || t.State is "unknown" or "error" or "missingFiles")
                {using var h=await gate.EnterAsync(ct);job.EngineState=t.State.StartsWith("checking",StringComparison.Ordinal)?"checking":"failed";job.Generation++;await ClearAvailabilityInGateAsync(db,job,ct);await db.SaveChangesAsync(ct);continue;}
                var pieces=await availability.GetPiecesAsync(job,ct);if(pieces.Length!=0 && pieces.Length!=job.PieceCount)throw new ApiException(409,"engine_layout_mismatch");var actual=await engine.FilesAsync(t.Hash,ct);var files=await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).ToArrayAsync(ct);
                if(files.Any(x=>x.Wanted) && (!t.Sequential || !t.MetadataAssist || actual.Any(x=>files.SingleOrDefault(f=>f.UpstreamFileIndex==x.Index)?.FilePriority!=x.Priority))){await StopSettledAsync(t.Hash,ct);throw new ApiException(409,"engine_settings_changed");}
                using(await gate.EnterAsync(ct))
                {
                    var current=await db.TorrentJobs.AsNoTracking().SingleAsync(x=>x.Id==job.Id,ct);if(current.Generation!=snapshot.Generation || current.Revision!=job.Revision || await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && (x.State=="pending"||x.State=="running") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==job.Id),ct))continue;
                    foreach(var file in files)
                    {if(file.Padding)continue;var ef=actual.SingleOrDefault(x=>x.Index==file.UpstreamFileIndex);if(ef is null||ef.Path!=file.RelativePath||ef.Bytes!=file.SizeBytes||ef.FirstPiece!=file.PieceFirst||ef.LastPiece!=file.PieceLast)throw new ApiException(409,"engine_layout_mismatch");file.DownloadedBytes=DownloadLayout.Available(file,job.PieceLength,pieces);file.ContiguousBytes=DownloadLayout.Available(file,job.PieceLength,pieces,true);file.Completed=file.DownloadedBytes==file.SizeBytes;file.PlaybackState=!file.Wanted?"notSelected":file.Completed?"complete":file.Kind=="video" && file.SizeBytes>0 && file.ContiguousBytes>=Math.Min(file.SizeBytes,16777216)?"eligible":"waitingForData";
                        try{using var root=storage.OpenLibrary(library);var node=root.Inspect(job.ManagedPath+"/"+file.RelativePath);if(node.IsFile){if(file.FileIdentity is not null && file.FileIdentity!=node.Key)throw new ApiException(409,"file_identity_changed");file.FileIdentity=node.Key;file.MtimeNs=node.MtimeNs;}}catch(ApiException e)when(e.Code=="path_unavailable"){} }
                    job.SelectedComplete=files.Any(x=>x.Wanted)&&files.Where(x=>x.Wanted).All(x=>x.Completed);job.DownloadedBytes=t.DownloadedBytes;job.UploadedBytes=t.UploadedBytes;job.DownloadBps=t.DownloadBps;job.UploadBps=t.UploadBps;job.SeedersConnected=t.SeedersConnected;job.PeersConnected=t.PeersConnected;job.EtaSeconds=t.EtaSeconds;job.LastContactAt=clock.GetUtcNow();job.ErrorCode=null;job.Sequential=t.Sequential;job.MetadataAssist=t.MetadataAssist;job.EngineState=MapState(t.State,job.SelectedComplete);
                    job.ReservedBytes=files.Where(x=>x.Wanted).Sum(x=>Math.Max(0,x.SizeBytes-x.DownloadedBytes)+ (x.Completed?0:2*job.PieceLength));job.UpdatedAt=clock.GetUtcNow();
                    foreach(var r in await db.DownloadRequests.Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).ToArrayAsync(ct)){r.State=r.SelectedBytes is null?"awaitingSelection":job.SelectedComplete?"completeSelected":job.EngineState switch{"stopped"=>"paused","seeding"=>"seeding","failed"=>"failed",_=>job.EngineState};r.UpdatedAt=job.UpdatedAt;}
                    await db.SaveChangesAsync(ct);
                }
                observedRevision=job.Revision;observationGuard.Dispose();observationGuard=null;
                if(importBudget>0){var subtitleIds=files.Where(x=>x.Kind=="subtitle" && x.Wanted && x.Completed).Select(x=>x.Id).ToArray();var importedSubtitles=subtitleIds.Length==0?new HashSet<Guid>():await db.Operations.Where(o=>o.Kind=="download-import" && o.State=="completed" && subtitleIds.Contains(o.TargetId)).Select(o=>o.TargetId).ToHashSetAsync(ct);var next=files.Where(x=>x.Wanted && x.Completed && (x.Kind!="subtitle"?x.ImportedItemId==null:!importedSubtitles.Contains(x.Id))).OrderBy(x=>x.MetadataFileIndex).FirstOrDefault();if(next is not null){importBudget--;await scope.ServiceProvider.GetRequiredService<DownloadImport>().ImportAsync(job.Id,next.Id,ct);}}
                var observedGeneration=job.Generation;var observedSettings=job.SettingsVersion;
                using var effectGuard=await jobLocks.EnterAsync(job.Id,ct);
                using(await gate.EnterAsync(ct))
                {
                    db.ChangeTracker.Clear();job=await db.TorrentJobs.SingleAsync(x=>x.Id==job.Id,ct);
                    if(job.RetiredAt is not null || job.Generation!=observedGeneration || job.SettingsVersion!=observedSettings || await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && (x.State=="pending"||x.State=="running") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==job.Id),ct))continue;
                }
                if(job.DesiredState=="stopped" && t.State is not("stoppedDL" or "stoppedUP"))await engine.StopAsync(t.Hash,ct);
                else if(job.DesiredState=="running" && t.State is "stoppedDL" or "stoppedUP" && files.Any(x=>x.Wanted))
                {
                    var admitted=false;
                    using(await gate.EnterAsync(ct)) {
                        var admission=new DownloadAdmission(db,storage);
                        if(await admission.SlotAvailableAsync(job,ct) && t.Sequential && t.MetadataAssist && actual.All(x=>files.SingleOrDefault(f=>f.UpstreamFileIndex==x.Index)?.FilePriority==x.Priority)) {
                            job.EngineState="starting";await db.SaveChangesAsync(ct);admitted=true;
                        }
                    }
                    if(admitted) {await RequireReservationsAsync(db,job,library,ct);await engine.StartAsync(t.Hash,ct);}
                }

            }
            catch(Exception e)when(e is ApiException or EngineFailure or IOException)
            {
                observationGuard??=await jobLocks.EnterAsync(snapshot.Id,ct);
                using(await gate.EnterAsync(ct))
                {var current=await db.TorrentJobs.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==snapshot.Id,ct);if(current is null || current.RetiredAt is not null || current.Revision!=observedRevision || current.Generation!=observationGeneration || await db.Operations.AnyAsync(x=>x.Kind.StartsWith("download-") && (x.State=="pending"||x.State=="running") && db.DownloadRequests.Any(r=>r.Id==x.TargetId && r.TorrentJobId==snapshot.Id),ct))continue;}
                if(t is not null && Owned(job,library,t)){try{await engine.StopAsync(t.Hash,ct);}catch(EngineFailure){}}
                using var h=await gate.EnterAsync(ct);db.ChangeTracker.Clear();job=await db.TorrentJobs.SingleAsync(x=>x.Id==snapshot.Id,ct);job.ErrorCode=e is ApiException a?a.Code:e is EngineFailure f?f.Code:"disk_unavailable";job.EngineState="failed";job.Generation++;await ClearAvailabilityInGateAsync(db,job,ct);await db.SaveChangesAsync(ct);
            }
            finally{observationGuard?.Dispose();}

        }
    }
    private static async Task<bool> LiveSelectionsAuthorizedAsync(BrianiDb db,TorrentJob job,CancellationToken ct)
    {
        var requests=await db.DownloadRequests.AsNoTracking().Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).ToArrayAsync(ct);if(requests.Length==0)return false;
        foreach(var request in requests){var user=await db.Users.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==request.OwnerId && x.Enabled && !x.MustChangePassword,ct);if(user is null)return false;if(user.Role!="administrator" && !await db.LibraryGrants.AnyAsync(x=>x.UserId==user.Id && x.LibraryId==job.LibraryId && x.CanRead && x.CanDownload,ct))return false;}return true;
    }
    private async Task RequireReservationsAsync(BrianiDb db,TorrentJob job,Library library,CancellationToken ct)
    {
        using var held=await gate.EnterAsync(ct);library=await db.Libraries.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==job.LibraryId,ct)??throw new ApiException(409,"disk_unavailable");
        if(!library.Enabled || !library.Online || library.ReadOnly)throw new ApiException(409,"disk_unavailable");
        var admission=new DownloadAdmission(db,storage);if(!await LiveSelectionsAuthorizedAsync(db,job,ct))throw new ApiException(403,"permission_changed");
        foreach(var request in await db.DownloadRequests.AsNoTracking().Where(x=>x.TorrentJobId==job.Id && x.RemovedAt==null).ToArrayAsync(ct))
        {var ids=await db.DownloadRequestFiles.Where(x=>x.DownloadRequestId==request.Id && x.Selected).Select(x=>x.DownloadFileId).ToArrayAsync(ct);await admission.RequireAsync(new(request.OwnerId,Guid.Empty,"member"),library,job.Id,job.ReservedBytes,request.SelectedBytes??request.ReservedBytes,request.Id,ct,ids);}
    }
    private static string MapState(string state,bool complete)=>state switch{"downloading" or "forcedDL"=>"downloading","stalledDL"=>"stalled","stoppedDL" or "stoppedUP" or "pausedDL" or "pausedUP"=>"stopped","uploading" or "forcedUP" or "stalledUP" or "queuedUP"=>"seeding","queuedDL"=>"queued",_=>complete?"complete":"stopped"};
    private async Task ClearAvailabilityInGateAsync(BrianiDb db,TorrentJob job,CancellationToken ct)
    {foreach(var file in await db.DownloadFiles.Where(x=>x.TorrentJobId==job.Id).ToArrayAsync(ct)){file.Completed=false;file.PlaybackState="unavailable";file.DownloadedBytes=0;file.ContiguousBytes=0;}job.SelectedComplete=false;await DownloadCommands.FenceAsync(db,job.Id,ct,readers);}
}
