using System.Text.Json.Serialization;
namespace Briani.Api.Modules.Downloads;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DownloadSource([property:JsonRequired]string Kind,[property:JsonRequired]string Value);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DownloadCreate([property:JsonRequired]Guid LibraryId,[property:JsonRequired]DownloadSource Source);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record FileChoice([property:JsonRequired]Guid FileId,[property:JsonRequired]bool Selected,[property:JsonRequired]string Priority="normal");
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DownloadSelection([property:JsonRequired]FileChoice[] Files,[property:JsonRequired]bool AutoStart,[property:JsonRequired]long Version);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DownloadAction([property:JsonRequired]string Action,[property:JsonRequired]long Version,bool DeleteData=false,bool Force=false,string? Confirmation=null);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DownloadSettings([property:JsonRequired]long Version,long? DownloadLimitBytesPerSecond=null,long? UploadLimitBytesPerSecond=null,double? RatioLimit=null,long? SeedTimeMinutes=null,int? QueuePosition=null,string[]? Tags=null);
public sealed class DownloadRequest
{
    public Guid Id{get;set;}=Guid.NewGuid();public Guid OwnerId{get;set;}public Guid AuthSessionId{get;set;}public Guid LibraryId{get;set;}public Guid? TorrentJobId{get;set;}
    public string SourceKind{get;set;}="";public string EncryptedSourceReference{get;set;}="";public string SourceDigest{get;set;}="";public string SourceState{get;set;}="resolving";
    public string State{get;set;}="resolving";public string? ErrorCode{get;set;}public long? SelectedBytes{get;set;}public long ReservedBytes{get;set;}public string VolumeIdentity{get;set;}="";
    public string? IdempotencyKey{get;set;}public string RequestHash{get;set;}="";public DateTimeOffset CreatedAt{get;set;}public DateTimeOffset UpdatedAt{get;set;}public DateTimeOffset? RemovedAt{get;set;}public long Version{get;set;}=1;
}
public sealed class TorrentJob
{
    public Guid Id{get;set;}=Guid.NewGuid();public string? UpstreamId{get;set;}public string? InfoHashV1{get;set;}public string? InfoHashV2{get;set;}public Guid LibraryId{get;set;}
    public string ManagedPath{get;set;}="";public string? MetadataRelativePath{get;set;}public string? MetadataFileIdentity{get;set;}public string? EncryptedMagnet{get;set;}public string OwnershipTag{get;set;}="";
    public string? EncryptedMetainfo{get;set;}
    public string VolumeIdentity{get;set;}="";public long ReservedBytes{get;set;}public string? ManagedRootIdentity{get;set;}public DateTimeOffset? RetiredAt{get;set;}public bool PayloadRemoved{get;set;}
    public long Revision{get;set;}=1;public long Generation{get;set;}=1;public string MetadataStatus{get;set;}="pending";public string EngineState{get;set;}="metadata";public string DesiredState{get;set;}="stopped";public string ImportState{get;set;}="notReady";
    public bool Sequential{get;set;}public bool MetadataAssist{get;set;}public bool SelectedComplete{get;set;}public bool Imported{get;set;}public bool RemovalDeleteData{get;set;}
    public long PieceLength{get;set;}public int PieceCount{get;set;}public long? TotalBytes{get;set;}public string Name{get;set;}="";public string? ErrorCode{get;set;}
    public long DownloadedBytes{get;set;}public long UploadedBytes{get;set;}public long DownloadBps{get;set;}public long UploadBps{get;set;}public long? SeedersConnected{get;set;}public long? PeersConnected{get;set;}public long? EtaSeconds{get;set;}
    public string SettingsJson{get;set;}="{}";public string TagsJson{get;set;}="[]";public long SettingsVersion{get;set;}=1;
    public DateTimeOffset CreatedAt{get;set;}public DateTimeOffset UpdatedAt{get;set;}public DateTimeOffset? LastContactAt{get;set;}public DateTimeOffset? MetadataDeadline{get;set;}public DateTimeOffset? LastReannounceAt{get;set;}
}
public sealed class DownloadFile
{
    public Guid Id{get;set;}=Guid.NewGuid();public Guid TorrentJobId{get;set;}public int UpstreamFileIndex{get;set;}public int MetadataFileIndex{get;set;}public string RelativePath{get;set;}="";public string DisplayName{get;set;}="";
    public long SizeBytes{get;set;}public long TorrentOffset{get;set;}public int PieceFirst{get;set;}public int PieceLast{get;set;}public bool Padding{get;set;}
    public bool Wanted{get;set;}public int FilePriority{get;set;}=1;public string Kind{get;set;}="other";public bool Completed{get;set;}public long DownloadedBytes{get;set;}public long ContiguousBytes{get;set;}
    public Guid? ImportedItemId{get;set;}public string? FileIdentity{get;set;}public long? MtimeNs{get;set;}public string PlaybackState{get;set;}="notSelected";public long Version{get;set;}=1;
}

public sealed class DownloadRequestFile
{
    public Guid DownloadRequestId{get;set;}public Guid DownloadFileId{get;set;}public bool Selected{get;set;}public int Priority{get;set;}=1;
}

public sealed class DownloadOwnership
{public Guid OwnerId{get;set;}public Guid LibraryId{get;set;}public Guid DownloadFileId{get;set;}public long Bytes{get;set;}}
