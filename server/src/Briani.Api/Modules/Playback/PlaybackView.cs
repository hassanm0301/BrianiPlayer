namespace Briani.Api.Modules.Playback;
public sealed record PlaybackSidecarView(Guid Id,string Name,string? Language,string MimeType,string Url);
public sealed record PlaybackSessionView(Guid Id,string State,string? StreamUrl,DateTimeOffset ActivationExpiresAt,DateTimeOffset? IdleExpiresAt,DateTimeOffset AbsoluteExpiresAt,string Generation,long ContiguousBytes,long? TotalBytes,string? MimeType,string? FileName,PlaybackSidecarView[] Sidecars,int? RetryAfterSeconds=null,Guid? ImportedMediaId=null);
public sealed record PlaybackStateHint(Guid SessionId,string State,string Generation,long ContiguousBytes,long? TotalBytes);
public static class PlaybackExpiry
{
    public static bool Expired(Briani.Api.Modules.Media.PlaybackSession s,DateTimeOffset now)=>now>=s.AbsoluteExpiresAt || (s.ActivatedAt is null?now>=s.FirstUseDeadline:s.LastActivityAt is null || now>=s.LastActivityAt.Value.AddMinutes(30));
}
