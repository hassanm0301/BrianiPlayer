using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace Briani.Api.Modules.Media.Processing;

public sealed class ScanWorker(IServiceScopeFactory scopes, ContainedStorage storage, WriteGate gate, TimeProvider clock, ProbeService probe, ServerOptions serverOptions, IOptions<MediaProcessingOptions> configured, SecretStore secrets) : BackgroundService
{
    private const int MaxEntries = 10_000;
    private async Task<long> CacheBytesLimitAsync(BrianiDb db, CancellationToken ct) =>
        await db.Settings.AsNoTracking().AnyAsync(x=>x.Key==Briani.Api.Modules.Preferences.AdministratorConfiguration.Key,ct)
        ? (await Briani.Api.Modules.Preferences.AdministratorConfiguration.ReadAsync(db,ct))["thumbnailCacheMaxBytes"]!.GetValue<long>()
        : Math.Clamp(options.CacheBytes,0,512L*1024*1024);
    private static readonly HashSet<string> Videos = new(StringComparer.OrdinalIgnoreCase)
        { ".mp4", ".m4v", ".mkv", ".webm", ".mov", ".avi", ".mpeg", ".mpg", ".ts", ".m2ts", ".ogv", ".3gp" };
    private static readonly HashSet<string> Images = new(StringComparer.OrdinalIgnoreCase)
        { ".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".avif" };
    private readonly string leaseOwner = Guid.NewGuid().ToString("N");
    private readonly MediaProcessingOptions options = configured.Value;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (options.BackgroundScansEnabled) await EnqueueDueScansAsync(stoppingToken);
                if (!await RunOnceAsync(stoppingToken)) await Task.Delay(TimeSpan.FromSeconds(3), clock, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception) { try { await Task.Delay(TimeSpan.FromSeconds(5), clock, stoppingToken); } catch (OperationCanceledException) { break; } }
        }
    }

    public async Task<bool> RunOnceAsync(CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope(); var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        WorkJob? job;
        using (await gate.EnterAsync(ct))
        {
            var now = clock.GetUtcNow();
            job = await db.Jobs.Where(x => x.Kind == "scan" && (x.State == "queued" || x.State == "running" && x.LeaseUntil < now) && x.NextAttemptAt <= now)
                .OrderBy(x => x.NextAttemptAt).ThenBy(x => x.CreatedAt).FirstOrDefaultAsync(ct);
            if (job is null) return false;
            job.State = "running"; job.LeaseOwner = leaseOwner; job.LeaseUntil = now.AddMinutes(2); job.Attempt++; job.UpdatedAt = now;
            await db.SaveChangesAsync(ct);
        }
        try
        {
            using var leaseStop = CancellationTokenSource.CreateLinkedTokenSource(ct);
            var renewer = RenewLeaseAsync(job.Id, leaseStop.Token);
            try { await ScanLibraryAsync(job.TargetId, ct); }
            finally { leaseStop.Cancel(); await IgnoreAsync(renewer); }
            using (await gate.EnterAsync(ct))
            {
                var current = await db.Jobs.SingleOrDefaultAsync(x => x.Id == job.Id && x.LeaseOwner == leaseOwner, ct);
                if (current is not null) { current.State = "completed"; current.LeaseOwner = null; current.LeaseUntil = null; current.DedupKey = null; current.Progress = 1; current.UpdatedAt = clock.GetUtcNow(); await db.SaveChangesAsync(ct); }
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception failure)
        {
            using (await gate.EnterAsync(ct))
            {
                var current = await db.Jobs.SingleOrDefaultAsync(x => x.Id == job.Id && x.LeaseOwner == leaseOwner, ct);
                if (current is not null)
                {
                    if(failure is ScanDeferredException)current.Attempt=Math.Max(0,current.Attempt-1);
                    current.LastErrorCode = failure is ScanDeferredException?"catalog_operation_pending":"scan_failed"; current.LeaseOwner = null; current.LeaseUntil = null; current.UpdatedAt = clock.GetUtcNow();
                    if (current.Attempt >= 5) { current.State = "failed"; current.DedupKey = null; }
                    else { current.State = "queued"; current.NextAttemptAt = clock.GetUtcNow().AddMinutes(1); }
                    await db.SaveChangesAsync(ct);
                }
            }
        }
        return true;
    }

    private async Task RenewLeaseAsync(Guid jobId, CancellationToken ct)
    {
        while (true)
        {
            await Task.Delay(TimeSpan.FromSeconds(30), clock, ct);
            using var scope = scopes.CreateScope(); var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
            using (await gate.EnterAsync(ct))
            {
                var job = await db.Jobs.SingleOrDefaultAsync(x => x.Id == jobId && x.State == "running" && x.LeaseOwner == leaseOwner, ct);
                if (job is null) return;
                job.LeaseUntil = clock.GetUtcNow().AddMinutes(2); job.UpdatedAt = clock.GetUtcNow(); await db.SaveChangesAsync(ct);
            }
        }
    }

    private async Task EnqueueDueScansAsync(CancellationToken ct)
    {
        using var scope = scopes.CreateScope(); var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        using (await gate.EnterAsync(ct))
        {
            var now = clock.GetUtcNow();
            var defaultInterval=await db.Settings.AsNoTracking().AnyAsync(x=>x.Key==Briani.Api.Modules.Preferences.AdministratorConfiguration.Key,ct) ? (await Briani.Api.Modules.Preferences.AdministratorConfiguration.ReadAsync(db,ct))["libraryScanIntervalSeconds"]!.GetValue<int>() : options.DefaultScanIntervalSeconds;
            var libraries = await db.Libraries.Where(x => x.Enabled && x.Online).OrderBy(x => x.Id).Take(1000).ToListAsync(ct);
            foreach (var library in libraries)
            {
                var interval = TimeSpan.FromSeconds(Math.Clamp(library.ScanIntervalSeconds ?? defaultInterval, 60, 31_536_000));
                var last = await db.Jobs.Where(x => x.Kind == "scan" && x.TargetId == library.Id && (x.State == "completed" || x.State == "failed"))
                    .OrderByDescending(x => x.UpdatedAt).Select(x => (DateTimeOffset?)x.UpdatedAt).FirstOrDefaultAsync(ct);
                if (last is not null && now < last.Value + interval) continue;
                var dedup = secrets.Digest($"scan-library:{library.Id:D}");
                if (await db.Jobs.AnyAsync(x => x.DedupKey == dedup && (x.State == "queued" || x.State == "running"), ct)) continue;
                db.Jobs.Add(new WorkJob { Kind = "scan", TargetId = library.Id, DedupKey = dedup, PayloadJson = "{}", State = "queued", NextAttemptAt = now, CreatedAt = now, UpdatedAt = now });
            }
            await db.SaveChangesAsync(ct);
        }
    }

    private static async Task IgnoreAsync(Task task) { try { await task; } catch (OperationCanceledException) { } }

    internal sealed class ScanDeferredException:Exception;
    private static async Task RequireStableCatalogAsync(BrianiDb db,Guid libraryId,CancellationToken ct)
    {
        if(await db.Operations.AnyAsync(x=>x.Kind=="download-import" && (x.State=="pending" || x.State=="running") && db.DownloadFiles.Any(f=>f.Id==x.TargetId && db.TorrentJobs.Any(t=>t.Id==f.TorrentJobId && t.LibraryId==libraryId)),ct))throw new ScanDeferredException();
        if(await db.Operations.AnyAsync(x=>(x.Kind=="rename" || x.Kind=="move" || x.Kind=="trash" || x.Kind=="permanent") && (x.State=="pending" || x.State=="running") && db.MediaItems.Any(m=>m.LibraryId==libraryId && m.Id==x.TargetId),ct))throw new ScanDeferredException();
    }
    public async Task ScanLibraryAsync(Guid libraryId, CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope(); var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
        var library = await db.Libraries.SingleOrDefaultAsync(x => x.Id == libraryId && x.Enabled, ct);
        if (library is null) return;
        using(await gate.EnterAsync(ct))await RequireStableCatalogAsync(db,libraryId,ct);
        using var root = storage.OpenLibrary(library);
        var stack = new Stack<(ContainedDirectory Dir, string Relative, int Depth, Guid? ParentId)>();
        stack.Push((root.Directory(""), "", 0, null));
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var scanned = 0;
        var truncated = false;
        var incomplete = false;
        try
        {
            while (stack.Count > 0 && scanned < MaxEntries)
            {
                ct.ThrowIfCancellationRequested();
                var (dir, parent, depth, parentId) = stack.Pop();
                using (dir)
                {
                    IReadOnlyList<string> names;
                    try { names = dir.Names(""); }
                    catch (ApiException) { incomplete = true; continue; }
                    foreach (var name in names)
                    {
                        if (scanned >= MaxEntries) { truncated = true; break; }
                        scanned++;
                        if (name == ".briani" || name.StartsWith(".", StringComparison.Ordinal) || name.Any(char.IsControl)) continue;
                        var relative = parent.Length == 0 ? name : parent + "/" + name;
                        NodeIdentity identity;
                        try { identity = dir.Inspect(name); }
                        catch (ApiException) { incomplete = true; continue; }
                        if (identity.IsDirectory)
                        {
                            seen.Add(relative);
                            var folderId = await IndexFolderAsync(db, library, relative, parent, name, parentId, identity, ct);
                            if (depth < 63)
                            {
                                try { stack.Push((dir.Directory(name), relative, depth + 1, folderId)); }
                                catch (ApiException) { incomplete = true; }
                            }
                            else incomplete = true;
                            continue;
                        }
                        if (!identity.IsFile || IsExecutable(name) || (identity.Mode & 0x49) != 0) continue;
                        seen.Add(relative);
                        await IndexFileAsync(db, library, relative, parent, name, parentId, identity, ct);
                    }
                }
                if (truncated) break;
            }
            if (!truncated && !incomplete && stack.Count == 0) using (await gate.EnterAsync(ct))
            {
                await RequireStableCatalogAsync(db,libraryId,ct);
                var existing = await db.MediaItems.Where(x => x.LibraryId == libraryId && x.SourceKind == "physical").Select(x => new { x.Id, x.RelativePath, x.MissingSince }).Take(MaxEntries + 1).ToListAsync(ct);
                if (existing.Count <= MaxEntries)
                {
                    var now = clock.GetUtcNow(); var changed = false;
                    foreach (var item in existing) if (!seen.Contains(item.RelativePath) && item.MissingSince is null)
                    { var entity = await db.MediaItems.SingleAsync(x => x.Id == item.Id, ct); entity.MissingSince = now; entity.Lifecycle = "missing"; entity.Version++; entity.IndexedAt = now; changed = true; }
                    if (changed) library.Version++;
                    await db.SaveChangesAsync(ct);
                }
            }
        }
        finally { while (stack.TryPop(out var remaining)) remaining.Dir.Dispose(); }
    }

    private async Task<Guid> IndexFolderAsync(BrianiDb db, Library library, string relative, string parent, string name, Guid? parentId, NodeIdentity stat, CancellationToken ct)
    {
        using (await gate.EnterAsync(ct))
        {
            await RequireStableCatalogAsync(db,library.Id,ct);
            var item = await db.MediaItems.SingleOrDefaultAsync(x => x.LibraryId == library.Id && x.RelativePath == relative && (x.SourceKind == "physical" || x.SourceKind == "hardlink"), ct);
            if (item is not null && item.Kind == "folder" && item.FileIdentity == stat.Key && item.MtimeNs == stat.MtimeNs && item.MissingSince is null) return item.Id;
            var now = clock.GetUtcNow();
            if (item is null)
            {
                item = new MediaItem { LibraryId = library.Id, ParentId = parentId, RelativePath = relative, ParentRelativePath = parent, DisplayName = name, SearchKey = SearchKey(name), Kind = "folder", Extension = "", MimeType = "inode/directory", SizeBytes = null, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, SourceKind = "physical", Lifecycle = "available", CreatedAt = now, IndexedAt = now };
                db.MediaItems.Add(item);
            }
            else
            {
                item.ParentId = parentId; item.ParentRelativePath = parent; item.DisplayName = name; item.SearchKey = SearchKey(name); item.Kind = "folder"; item.Extension = ""; item.MimeType = "inode/directory"; item.SizeBytes = null; item.MtimeNs = stat.MtimeNs; item.FileIdentity = stat.Key; item.MissingSince = null; item.Lifecycle = "available"; item.IndexedAt = now; item.Version++;
            }
            library.Version++;
            await db.SaveChangesAsync(ct);
            return item.Id;
        }
    }

    private async Task IndexFileAsync(BrianiDb db, Library library, string relative, string parent, string name, Guid? parentId, NodeIdentity stat, CancellationToken ct, bool retryOnChange = true)
    {
        var ext = Path.GetExtension(name);
        var video = Videos.Contains(ext); var photo = Images.Contains(ext);
        if (!video && !photo) return;
        MediaItem? item;
        using (await gate.EnterAsync(ct))
        {
            await RequireStableCatalogAsync(db,library.Id,ct);
            item = await db.MediaItems.SingleOrDefaultAsync(x => x.LibraryId == library.Id && x.RelativePath == relative && (x.SourceKind == "physical" || x.SourceKind == "hardlink"), ct);
            if(item?.DownloadFileId is Guid downloadFileId && !await db.DownloadFiles.AnyAsync(x=>x.Id==downloadFileId && x.Completed,ct))return;
            if (item is not null && item.FileIdentity == stat.Key && item.SizeBytes == stat.Length && item.MtimeNs == stat.MtimeNs && item.MissingSince is null) return;
            var now = clock.GetUtcNow();
            if (item is null)
            {
                item = new MediaItem { LibraryId = library.Id, ParentId = parentId, RelativePath = relative, ParentRelativePath = parent, DisplayName = name, SearchKey = SearchKey(name), Kind = video ? "video" : "photo", Extension = ext.ToLowerInvariant(), MimeType = Mime(ext), SizeBytes = stat.Length, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, SourceKind = "physical", Lifecycle = "available", CreatedAt = now, IndexedAt = now };
                db.MediaItems.Add(item);
            }
            else
            {
                item.ParentId = parentId; item.ParentRelativePath = parent; item.DisplayName = name; item.SearchKey = SearchKey(name); item.Kind = video ? "video" : "photo"; item.Extension = ext.ToLowerInvariant(); item.MimeType = Mime(ext); item.SizeBytes = stat.Length; item.MtimeNs = stat.MtimeNs; item.FileIdentity = stat.Key; item.MissingSince = null; item.Lifecycle = "available"; item.IndexedAt = now; item.Version++;
            }
            library.Version++;
            var metadata = await db.MediaMetadata.SingleOrDefaultAsync(x => x.MediaItemId == item.Id, ct);
            if (metadata is null) { metadata = new MediaMetadata { MediaItemId = item.Id }; db.MediaMetadata.Add(metadata); }
            metadata.DurationMs = null; metadata.Width = null; metadata.Height = null; metadata.Rotation = null; metadata.ExifOrientation = null; metadata.VideoCodec = null;
            metadata.TracksJson = "[]"; metadata.Container = ""; metadata.ProbeVersion = ""; metadata.ProbeStatus = "pending"; metadata.ProbeErrorCode = null; metadata.ContentGeneration = item.Version;
            var oldThumbs = await db.ThumbnailEntries.Where(x => x.MediaItemId == item.Id).ToListAsync(ct); db.ThumbnailEntries.RemoveRange(oldThumbs);
            await db.SaveChangesAsync(ct);
        }

        var result = await probe.ProbeAsync(item!, library, ct);
        if (retryOnChange && result.ProbeStatus == "pending" && result.ProbeErrorCode == "media_changed")
        {
            try
            {
                using var currentRoot = storage.OpenLibrary(library);
                var latest = currentRoot.Inspect(relative);
                if (latest.IsFile && (latest.Key != stat.Key || latest.Length != stat.Length || latest.MtimeNs != stat.MtimeNs))
                    await IndexFileAsync(db, library, relative, parent, name, parentId, latest, ct, false);
            }
            catch (ApiException) { }
            return;
        }
        CachedThumbnail? thumbnail = null;
        if (result.ThumbnailJpeg is { Length: > 0 } jpeg) thumbnail = await SaveThumbnailAsync(db, jpeg, ct);
        using (await gate.EnterAsync(ct))
        {
            await RequireStableCatalogAsync(db,library.Id,ct);
            var current = await db.MediaItems.AsNoTracking().SingleOrDefaultAsync(x => x.Id == item!.Id && x.Version == item.Version && x.FileIdentity == item.FileIdentity, ct);
            if (current is null) return;
            var metadata = await db.MediaMetadata.SingleOrDefaultAsync(x => x.MediaItemId == item.Id, ct);
            if (metadata is null) { metadata = new MediaMetadata { MediaItemId = item.Id }; db.MediaMetadata.Add(metadata); }
            metadata.DurationMs = result.DurationMs; metadata.Width = result.Width; metadata.Height = result.Height; metadata.Rotation = result.Rotation; metadata.ExifOrientation = result.ExifOrientation; metadata.VideoCodec = result.VideoCodec;
            metadata.TracksJson = JsonSerializer.Serialize(result.Tracks); metadata.Container = result.Container; metadata.ProbeVersion = result.ProbeVersion; metadata.ProbeStatus = result.ProbeStatus; metadata.ProbeErrorCode = result.ProbeErrorCode; metadata.ContentGeneration = item.Version;
            if (thumbnail is not null)
            {
                var thumb = await db.ThumbnailEntries.SingleOrDefaultAsync(x => x.MediaItemId == item.Id && x.Generation == item.Version && x.Variant == "default", ct);
                if (thumb is null) db.ThumbnailEntries.Add(new ThumbnailEntry { MediaItemId = item.Id, Generation = item.Version, Variant = "default", CacheRelativePath = thumbnail.Path, FileIdentity = thumbnail.FileIdentity, Bytes = thumbnail.Bytes, CreatedAt = clock.GetUtcNow(), LastAccessedAt = clock.GetUtcNow() });
            }
            await db.SaveChangesAsync(ct);
        }
    }

    internal async Task<CachedThumbnail?> SaveThumbnailAsync(BrianiDb db, byte[] data, CancellationToken ct)
    {
        if (!data.AsSpan().StartsWith(new byte[] { 0xff, 0xd8 }) || data.Length > 512 * 1024) return null;
        using var writeLease = await gate.EnterAsync(ct);
        var cacheLimit=await CacheBytesLimitAsync(db,ct);
        using var state = new ContainedDirectory(serverOptions.StateRoot);
        try { state.CreateDirectory("cache"); } catch (ApiException) { }
        try { state.CreateDirectory("cache/media"); } catch (ApiException) { }
        using var cache = state.Directory("cache/media");
        var files = new List<(string Path, long Bytes, long Mtime)>(); long used = 0;
        var cacheNames = cache.Names();
        if (cacheNames.Count > MaxEntries) return null;
        foreach (var name in cacheNames)
        {
            try
            {
                var path = "cache/media/" + name; var stat = state.Inspect(path);
                if (!stat.IsFile || name.Contains('/', StringComparison.Ordinal)) continue;
                files.Add((path, Math.Max(0, stat.Length), stat.MtimeNs)); used += Math.Max(0, stat.Length);
            }
            catch (ApiException) { }
        }
        // Physical enumeration remains authoritative, including orphaned files.
        // Sorting is only needed when this write actually requires eviction.
        if (used + data.Length > cacheLimit)
        {
            foreach (var old in files.OrderBy(x => x.Mtime))
            {
                if (used + data.Length <= cacheLimit) break;
                try { state.Unlink(old.Path); } catch (ApiException) { }
                var rows = await db.ThumbnailEntries.Where(x => x.CacheRelativePath == old.Path).Take(16).ToListAsync(ct);
                db.ThumbnailEntries.RemoveRange(rows); used -= old.Bytes;
            }
        }
        if (used + data.Length > cacheLimit) return null;
        var relative = "cache/media/" + Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant() + ".jpg";
        try { using var file = state.CreateFile(relative); await file.WriteAsync(data, ct); await file.FlushAsync(ct); return new(relative, ContainedDirectory.Inspect(file).Key, data.LongLength); }
        catch (Exception e) when (e is ApiException or IOException) { return null; }
    }

    private static bool IsExecutable(string name) => Path.GetExtension(name) is var e && new[] { ".exe", ".dll", ".so", ".sh", ".bat", ".cmd", ".com", ".appimage", ".msi", ".apk", ".jar" }.Contains(e, StringComparer.OrdinalIgnoreCase);
    internal static string SearchKey(string value) => value.Normalize(NormalizationForm.FormKC).ToUpperInvariant();
    internal static string Mime(string ext) => ext.ToLowerInvariant() switch { ".jpg" or ".jpeg" => "image/jpeg", ".png" => "image/png", ".webp" => "image/webp", ".gif" => "image/gif", ".bmp" => "image/bmp", ".tif" or ".tiff" => "image/tiff", ".avif" => "image/avif", ".mp4" or ".m4v" => "video/mp4", ".mkv" => "video/x-matroska", ".webm" => "video/webm", ".mov" => "video/quicktime", ".avi" => "video/x-msvideo", ".mpeg" or ".mpg" => "video/mpeg", ".ts" or ".m2ts" => "video/mp2t", ".ogv" => "video/ogg", ".3gp" => "video/3gpp", _ => "application/octet-stream" };
    internal sealed record CachedThumbnail(string Path, string FileIdentity, long Bytes);
}
