namespace Briani.Api.Modules.Media;
public sealed class MediaItem
{
    public Guid Id {get;set;}=Guid.NewGuid();public Guid LibraryId {get;set;}public Guid? ParentId {get;set;}
    public string ParentRelativePath {get;set;}="";public string RelativePath {get;set;}="";public string DisplayName {get;set;}="";public string SearchKey {get;set;}="";
    public string Kind {get;set;}="video";public string Extension {get;set;}="";public string MimeType {get;set;}="application/octet-stream";
    public long? SizeBytes {get;set;}public long MtimeNs {get;set;}public string FileIdentity {get;set;}="";
    public string SourceKind {get;set;}="physical";public Guid? DownloadFileId {get;set;}public string Lifecycle {get;set;}="available";
    public DateTimeOffset? MissingSince {get;set;}public DateTimeOffset CreatedAt {get;set;}public DateTimeOffset IndexedAt {get;set;}public long Version {get;set;}=1;
}
public sealed class MediaMetadata
{
    public Guid MediaItemId {get;set;}public long? DurationMs {get;set;}public int? Width {get;set;}public int? Height {get;set;}public int? Rotation {get;set;}
    public int? ExifOrientation {get;set;}public string? VideoCodec {get;set;}public string TracksJson {get;set;}="[]";
    public string Container {get;set;}="";public string ProbeVersion {get;set;}="";public string ProbeStatus {get;set;}="pending";public string? ProbeErrorCode {get;set;}
    public long ContentGeneration {get;set;}=1;
}
public sealed class ThumbnailEntry
{
    public Guid MediaItemId {get;set;}public long Generation {get;set;}public string Variant {get;set;}="default";public string CacheRelativePath {get;set;}="";
    public string FileIdentity {get;set;}="";public long Bytes {get;set;}public DateTimeOffset CreatedAt {get;set;}public DateTimeOffset LastAccessedAt {get;set;}
}
public sealed class PlaybackProgress
{
    public Guid UserId {get;set;}public Guid MediaItemId {get;set;}public long PositionMs {get;set;}public long? DurationMs {get;set;}public bool Completed {get;set;}
    public DateTimeOffset UpdatedAt {get;set;}public Guid ClientEventId {get;set;}public long Version {get;set;}=1;
}
public sealed class WorkJob
{
    public Guid Id {get;set;}=Guid.NewGuid();public string Kind {get;set;}="scan";public Guid TargetId {get;set;}public string PayloadJson {get;set;}="{}";
    public string? DedupKey {get;set;}public string State {get;set;}="queued";public int Attempt {get;set;}public DateTimeOffset NextAttemptAt {get;set;}
    public string? LeaseOwner {get;set;}public DateTimeOffset? LeaseUntil {get;set;}public string? LastErrorCode {get;set;}
    public DateTimeOffset CreatedAt {get;set;}public DateTimeOffset UpdatedAt {get;set;}public double? Progress {get;set;}
}
public sealed class Operation
{
    public Guid Id {get;set;}=Guid.NewGuid();public Guid UserId {get;set;}public string Kind {get;set;}="";public Guid TargetId {get;set;}
    public string? IdempotencyKey {get;set;}public string RequestHash {get;set;}="";public string State {get;set;}="queued";
    public DateTimeOffset UpdatedAt {get;set;}public string? ErrorCode {get;set;}public bool InvalidatesPlayback {get;set;}
    public string ResultJson {get;set;}="{}";public string PayloadJson {get;set;}="{}";public DateTimeOffset CreatedAt {get;set;}public DateTimeOffset ExpiresAt {get;set;}
}
public sealed class PlaybackSession
{
    public Guid Id {get;set;}=Guid.NewGuid();public Guid UserId {get;set;}public Guid AuthSessionId {get;set;}public Guid? MediaItemId {get;set;}public Guid? DownloadFileId {get;set;}
    public string TargetGeneration {get;set;}="";public string TicketHash {get;set;}="";public string Mode {get;set;}="internal";
    public DateTimeOffset CreatedAt {get;set;}public DateTimeOffset FirstUseDeadline {get;set;}public DateTimeOffset AbsoluteExpiresAt {get;set;}
    public DateTimeOffset? ActivatedAt {get;set;}public DateTimeOffset? LastActivityAt {get;set;}public DateTimeOffset? RevokedAt {get;set;}public long InitialPositionMs {get;set;}public bool TicketIssued {get;set;}=true;
}
public sealed record MediaTrack(string Id,string Kind,string? Language,string? Title,string? Codec,bool Default=false);
