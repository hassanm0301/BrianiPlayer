using System.Security.Cryptography;
using System.Text;

namespace Briani.PlaybackProof;

// M00's isolated one-file capability policy. Production identity/grants are M02/M06.
public sealed class TicketWindow(string raw, string fileId, long generation, TimeProvider clock)
{
    private readonly byte[] digest = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
    private readonly DateTimeOffset created = clock.GetUtcNow();
    private readonly object gate = new();
    private DateTimeOffset? lastActivity;
    private bool revoked;
    public bool Authorize(string candidate, string targetFile, long targetGeneration)
    {
        if (candidate.Length > 128 || targetFile != fileId || targetGeneration != generation ||
            !CryptographicOperations.FixedTimeEquals(digest, SHA256.HashData(Encoding.UTF8.GetBytes(candidate)))) return false;
        lock (gate)
        {
            var now = clock.GetUtcNow();
            if (revoked || now >= created.AddHours(24) ||
                lastActivity is null && now >= created.AddMinutes(10) ||
                lastActivity is not null && now >= lastActivity.Value.AddMinutes(30)) return false;
            lastActivity = now;
            return true;
        }
    }
    public void Revoke() { lock (gate) revoked = true; }
}
