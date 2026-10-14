using System.Text.Json.Serialization;
namespace Briani.Api.Modules.Discovery;
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record DiscoveryQuery([property:JsonRequired]string Mode,string? Query=null,string[]? ProviderIds=null,long[]? Categories=null,string? Sort=null,string? Order=null,long? MinSizeBytes=null,long? MaxSizeBytes=null,long? MinSeeders=null);
public sealed class DiscoverySnapshot
{
    public Guid Id{get;set;}=Guid.NewGuid();public Guid UserId{get;set;}public Guid AuthSessionId{get;set;}public string PermissionStamp{get;set;}="";public string QueryKey{get;set;}="";public string QueryJson{get;set;}="{}";
    public string State{get;set;}="queued";public DateTimeOffset CreatedAt{get;set;}public DateTimeOffset ExpiresAt{get;set;}public DateTimeOffset? FetchedAt{get;set;}public bool Truncated{get;set;}public string WarningsJson{get;set;}="[]";
}
public sealed class DiscoveryResult
{
    public Guid Id{get;set;}=Guid.NewGuid();public Guid SnapshotId{get;set;}public string SourceId{get;set;}="";public string SourceName{get;set;}="";public string SourceGuid{get;set;}="";public string Title{get;set;}="";
    public long? Bytes{get;set;}public long? Seeders{get;set;}public long? Leechers{get;set;}public long? PeersTotal{get;set;}public DateTimeOffset? PublishedAt{get;set;}public DateTimeOffset ObservedAt{get;set;}
    public string? InfoHashV1{get;set;}public string? InfoHashV2{get;set;}public string CategoriesJson{get;set;}="[]";public string EncryptedResolutionJson{get;set;}="";public bool CanDownload{get;set;}
}
public sealed class TorrentUpload
{
    public Guid Id{get;set;}=Guid.NewGuid();public Guid UserId{get;set;}public string RelativePath{get;set;}="";public string FileIdentity{get;set;}="";public string Sha256{get;set;}="";public long Bytes{get;set;}public DateTimeOffset CreatedAt{get;set;}public DateTimeOffset ExpiresAt{get;set;}
}
