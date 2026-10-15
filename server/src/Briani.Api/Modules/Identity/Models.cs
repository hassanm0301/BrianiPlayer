using System.Text.Json.Serialization;
namespace Briani.Api.Modules.Identity;
public sealed class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Username { get; set; } = "";
    public string NormalizedUsername { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string Role { get; set; } = "member";
    public bool Enabled { get; set; } = true;
    public bool MustChangePassword { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public long Version { get; set; } = 1;
}
public sealed class AuthSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string DeviceId { get; set; } = Guid.NewGuid().ToString();
    public string DeviceName { get; set; } = "";
    public string Platform { get; set; } = "native";
    public string RefreshHash { get; set; } = "";
    public DateTimeOffset RefreshExpiresAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset LastSeenAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
    public long RefreshGeneration { get; set; }
}
public sealed class AccessToken { public string TokenHash { get; set; } = ""; public Guid SessionId { get; set; } public DateTimeOffset ExpiresAt { get; set; } }
public sealed class RefreshReplay { public string ConsumedHash { get; set; } = ""; public Guid SessionId { get; set; } public DateTimeOffset ExpiresAt { get; set; } }
public sealed class DevicePairing
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string DeviceSecretHash { get; set; } = "";
    public string HumanCodeHash { get; set; } = "";
    public string DeviceName { get; set; } = "";
    public DateTimeOffset ExpiresAt { get; set; }
    public Guid? ApprovedBy { get; set; }
    public Guid? ApprovedSessionId {get;set;}
    public DateTimeOffset? ApprovedAt { get; set; }
    public DateTimeOffset? ConsumedAt { get; set; }
    public DateTimeOffset? LastPolledAt { get; set; }
    public int PollCount { get; set; }
}
public sealed class Library
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public string RootPath { get; set; } = "";
    public string RootIdentity { get; set; } = "";
    public bool Enabled { get; set; } = true;
    public bool Online { get; set; } = true;
    public bool ReadOnly { get; set; }
    public bool Managed { get; set; } = true;
    public int? ScanIntervalSeconds { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public long Version { get; set; } = 1;
}
public sealed class LibraryGrant
{
    public Guid UserId { get; set; }
    public Guid LibraryId { get; set; }
    public bool CanRead { get; set; }
    public bool CanDownload { get; set; }
    public bool CanManage { get; set; }
    public long? QuotaBytes { get; set; }
}
public sealed class Setting { public string Key { get; set; } = ""; public string ValueJson { get; set; } = ""; public long Version { get; set; } = 1; public DateTimeOffset UpdatedAt { get; set; } }
public sealed class AuditEvent
{
    public Guid Id { get; set; } = Guid.NewGuid(); public Guid? ActorId { get; set; } public string Action { get; set; } = "";
    public string TargetType { get; set; } = ""; public string TargetId { get; set; } = ""; public string Result { get; set; } = "success";
    public string SafeDetailsJson { get; set; } = "{}"; public string TraceId { get; set; } = ""; public DateTimeOffset CreatedAt { get; set; }
}
public sealed record UserView(Guid Id, string Username, string DisplayName, string Role, bool Enabled, long Version, bool MustChangePassword)
{ public static UserView Of(User u) => new(u.Id,u.Username,u.DisplayName,u.Role,u.Enabled,u.Version,u.MustChangePassword); }
public sealed record AuthTokens(string AccessToken, DateTimeOffset AccessExpiresAt, string RefreshToken, DateTimeOffset RefreshExpiresAt, Guid SessionId, UserView User);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record BootstrapRequest([property: JsonRequired] string Code,[property: JsonRequired] string Username,[property: JsonRequired] string DisplayName,[property: JsonRequired] string Password,[property: JsonRequired] string ConfirmPassword);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record LoginRequest([property: JsonRequired] string Username,[property: JsonRequired] string Password,[property: JsonRequired] string DeviceName);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record RefreshRequest([property: JsonRequired] string RefreshToken);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record PasswordChange([property: JsonRequired] string CurrentPassword,[property: JsonRequired] string NewPassword,[property: JsonRequired] string ConfirmNewPassword);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record PasswordReset([property: JsonRequired] string NewPassword,[property: JsonRequired] string ConfirmNewPassword,[property: JsonRequired] long Version);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DeviceCodeRequest([property: JsonRequired] string DeviceName);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DeviceCodePoll([property: JsonRequired] string DeviceSecret);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)] public sealed record DeviceCodeApprove([property: JsonRequired] string UserCode);
