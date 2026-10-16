namespace Briani.Api.Integrations.QBittorrent;
public sealed record EngineVersion(string Application,string WebApi,string Libtorrent);
public sealed record EngineTorrent(string Hash,string? InfoHashV1,string? InfoHashV2,string Name,string SavePath,string State,long TotalBytes,long DownloadedBytes,long UploadedBytes,long DownloadBps,long UploadBps,double Progress,double Availability,bool Sequential,bool MetadataAssist,string[] Tags,long? EtaSeconds,long? SeedersConnected,long? PeersConnected,int QueuePosition,bool? HasMetadata=null);
public sealed record EngineFile(int Index,string Path,long Bytes,double Progress,int Priority,int FirstPiece,int LastPiece);
public sealed record EngineTracker(string Host,string Status,int? Seeds,int? Peers);
public sealed record EngineAdd(byte[]? Torrent,string? Magnet,string SavePath,string OwnershipTag,bool MetadataOnly);
public sealed record EngineLimits(long? DownloadLimitBytesPerSecond=null,long? UploadLimitBytesPerSecond=null,double? RatioLimit=null,long? SeedTimeMinutes=null,int? QueuePosition=null,string[]? Tags=null);
public interface ITorrentEngine
{
    long ConnectionGeneration => 0;
    Task<EngineVersion> VersionAsync(CancellationToken ct=default);
    Task<EngineTorrent[]> TorrentsAsync(string? hash=null,CancellationToken ct=default);
    Task<EngineFile[]> FilesAsync(string hash,CancellationToken ct=default);
    Task<byte[]> ExportAsync(string hash,CancellationToken ct=default);
    Task<byte[]> PiecesAsync(string hash,CancellationToken ct=default);
    Task<EngineTracker[]> TrackersAsync(string hash,CancellationToken ct=default);
    Task AddAsync(EngineAdd add,CancellationToken ct=default);
    Task StopAsync(string hash,CancellationToken ct=default);
    Task StartAsync(string hash,CancellationToken ct=default);
    Task EnsureSequentialAsync(string hash,bool enabled,CancellationToken ct=default);
    Task EnsureMetadataAssistAsync(string hash,bool enabled,CancellationToken ct=default);
    /// Re-applies first/last-piece priority to a torrent that already has it enabled.
    Task ReassertMetadataAssistAsync(string hash,CancellationToken ct=default)=>EnsureMetadataAssistAsync(hash,true,ct);
    Task SetFilePriorityAsync(string hash,int[] indexes,int priority,CancellationToken ct=default);
    Task ApplyLimitsAsync(string hash,EngineLimits limits,CancellationToken ct=default);
    Task RecheckAsync(string hash,CancellationToken ct=default);
    Task ReannounceAsync(string hash,CancellationToken ct=default);
    Task RemoveAsync(string hash,bool deleteFiles,CancellationToken ct=default);
    Task ConfigureManagedAsync(CancellationToken ct=default);
}
public sealed class EngineFailure(string code):Exception(code){public string Code{get;}=code;}
