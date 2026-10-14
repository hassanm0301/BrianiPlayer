using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
namespace Briani.Api.Modules.Playback;

// Only subscribed playback targets retain bitmaps. Ordinary download polling uses the
// same fetch when subscribed; it never starts a second piece-state poller.
public sealed class TorrentAvailability(IServiceScopeFactory scopes,ITorrentEngine engine,DownloadJobLocks jobLocks,ContainedStorage storage,TimeProvider clock):BackgroundService
{
    private readonly object sync=new();private readonly Dictionary<Guid,Entry> active=new();
    private readonly string epoch=Guid.NewGuid().ToString("N");
    public AvailabilitySnapshot? Peek(Guid id){lock(sync)return active.TryGetValue(id,out var entry)?entry.Current:null;}
    public sealed class Entry(Guid id,ITorrentEngine engine):IAvailabilitySource
    {
        internal readonly string Incarnation=Guid.NewGuid().ToString("N");
        internal Guid Id=id;internal int Users;internal long Invalidations;internal long Connection=-1;
        internal readonly SemaphoreSlim Fetch=new(1,1);internal readonly SharedAvailability Source=new();
        public AvailabilitySnapshot? Current
        {get{var s=Source.Current;return s is {Healthy:true} && s.EngineGeneration!=engine.ConnectionGeneration?Source.ReplaceIfCurrent(s,new($"invalid-connection:{engine.ConnectionGeneration}",s.ObservedAt,false,[])):s;}}
        public Task WaitForChangeAsync(AvailabilitySnapshot? previous,CancellationToken ct)=>Source.WaitForChangeAsync(previous,ct);
    }
    public sealed class Subscription(TorrentAvailability owner,Entry entry):IDisposable
    {private int disposed;public Entry Source=>entry;public void Dispose(){if(Interlocked.Exchange(ref disposed,1)!=0)return;lock(owner.sync){if(--entry.Users==0 && entry.Current is { } old)entry.Source.Publish(new(old.Generation,old.ObservedAt,false,[]));}}}
    public Subscription Subscribe(Guid id)
    {lock(sync){if(active.Values.Count(x=>x.Users>0)>=16 && (!active.TryGetValue(id,out var existing)||existing.Users==0))throw new ApiException(429,"reader_limit");if(!active.TryGetValue(id,out var e)){if(active.Count>=512){var unused=active.Values.FirstOrDefault(x=>x.Users==0)??throw new ApiException(429,"reader_limit");active.Remove(unused.Id);}e=new(id,engine);active.Add(id,e);}e.Users++;return new(this,e);}}
    public string Generation(TorrentJob job,Entry e,long? connection=null)=>$"{epoch}:{e.Incarnation}:{job.Id:N}:{job.Generation}:{e.Invalidations}:{connection??engine.ConnectionGeneration}";
    public async Task<byte[]> GetPiecesAsync(TorrentJob job,CancellationToken ct)
    {
        Entry? e;lock(sync)active.TryGetValue(job.Id,out e);
        if(e is null || e.Users==0)return await engine.PiecesAsync(job.UpstreamId??throw new EngineFailure("torrent_not_found"),ct);
        await RefreshAsync(e,ct);var value=e.Current;
        if(value is null || !value.Healthy || value.Generation!=Generation(job,e))throw new EngineFailure("engine_unavailable");
        return value.CopyStates();
    }
    public async Task RefreshAsync(Entry e,CancellationToken ct)
    {
        await e.Fetch.WaitAsync(ct);
        try
        {
            if(e.Current is {Healthy:true} cached && e.Connection==engine.ConnectionGeneration && clock.GetUtcNow()-cached.ObservedAt<TimeSpan.FromMilliseconds(500))return;
            using var scope=scopes.CreateScope();var db=scope.ServiceProvider.GetRequiredService<BrianiDb>();
            var job=await db.TorrentJobs.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==e.Id,ct);
            if(job is null || job.RetiredAt is not null || job.MetadataStatus!="ready" || job.UpstreamId is null || job.DesiredState=="removing" || await PendingAsync(db,e.Id,ct))throw new IOException("generation_changed");
            var library=await db.Libraries.AsNoTracking().SingleAsync(x=>x.Id==job.LibraryId,ct);
            var files=await db.DownloadFiles.AsNoTracking().Where(x=>x.TorrentJobId==job.Id).ToArrayAsync(ct);
            await engine.VersionAsync(ct);var connection=engine.ConnectionGeneration;
            var torrent=(await engine.TorrentsAsync(job.UpstreamId,ct)).SingleOrDefault();
            var path=storage.RootPath.TrimEnd('/')+"/"+library.RootPath+"/"+job.ManagedPath;
            if(torrent is null || torrent.SavePath.TrimEnd('/')!=path || !torrent.Tags.Contains(job.OwnershipTag,StringComparer.Ordinal) || (job.InfoHashV1 is not null && torrent.InfoHashV1!=job.InfoHashV1) || (job.InfoHashV2 is not null && torrent.InfoHashV2!=job.InfoHashV2))throw new IOException("torrent_binding_changed");
            if(torrent.State.StartsWith("checking",StringComparison.Ordinal) || torrent.State is "moving" or "error" or "missingFiles" or "unknown" or "metaDL" or "forcedMetaDL")throw new IOException("availability_invalidated");
            var actual=await engine.FilesAsync(job.UpstreamId,ct);
            if(files.Where(x=>!x.Padding).Any(f=>!actual.Any(x=>x.Index==f.UpstreamFileIndex && x.Path==f.RelativePath && x.Bytes==f.SizeBytes && x.FirstPiece==f.PieceFirst && x.LastPiece==f.PieceLast && x.Priority==f.FilePriority)) || actual.Any(x=>!files.Any(f=>f.UpstreamFileIndex==x.Index)) || !torrent.Sequential || !torrent.MetadataAssist)throw new IOException("layout_unverified");
            using(var root=storage.OpenLibrary(library)){using var stage=root.Directory(job.ManagedPath);if(stage.Identity!=job.ManagedRootIdentity)throw new IOException("file_identity_changed");}
            var pieces=await engine.PiecesAsync(job.UpstreamId,ct);
            if(pieces.Length!=job.PieceCount || connection!=engine.ConnectionGeneration)throw new IOException("availability_invalidated");
            var current=await db.TorrentJobs.AsNoTracking().SingleAsync(x=>x.Id==e.Id,ct);
            if(current.Generation!=job.Generation || current.RetiredAt is not null || current.DesiredState=="removing" || await PendingAsync(db,e.Id,ct))throw new IOException("generation_changed");
            if(connection!=engine.ConnectionGeneration)throw new IOException("availability_invalidated");
            Interlocked.Exchange(ref e.Connection,connection);e.Source.Publish(new(Generation(job,e,connection),clock.GetUtcNow(),true,pieces,connection));
        }
        catch(OperationCanceledException)when(ct.IsCancellationRequested){throw;}
        catch
        {
            // Even an uncertain storage/API transition fences existing URLs. It does
            // not imply deleting payload or accepting the last successful bitmap.
            if(e.Current is null || e.Current.Healthy)e.Invalidations++;
            e.Source.Publish(new($"{epoch}:{e.Id:N}:invalid:{e.Invalidations}",clock.GetUtcNow(),false,[]));
        }
        finally{e.Fetch.Release();}
    }
    internal static Task<bool> PendingAsync(BrianiDb db,Guid id,CancellationToken ct)=>db.Operations.AnyAsync(o=>o.InvalidatesPlayback && (o.State=="pending"||o.State=="running") && db.DownloadRequests.Any(r=>r.Id==o.TargetId && r.TorrentJobId==id),ct);
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while(!ct.IsCancellationRequested)
        {
            Entry[] entries;lock(sync)entries=active.Values.Where(x=>x.Users>0).ToArray();
            foreach(var e in entries){using var held=await jobLocks.EnterAsync(e.Id,ct);await RefreshAsync(e,ct);}
            await Task.Delay(TimeSpan.FromMilliseconds(500),clock,ct);
        }
    }
}
