using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Briani.StreamingTests;

public sealed class PlaybackEventTests
{
    [Fact]
    public async Task Loader_filters_owner_revocation_expiry_and_current_library_grant_and_reports_metadata_state()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<BrianiDb>().UseSqlite(connection).Options;
        await using var db = new BrianiDb(options);
        await db.Database.EnsureCreatedAsync();

        var now = new DateTimeOffset(2026, 10, 12, 5, 0, 0, TimeSpan.Zero);
        var clock = new TestClock(now);
        var owner = new User { Username = "owner", NormalizedUsername = "OWNER", PasswordHash = "x" };
        var other = new User { Username = "other", NormalizedUsername = "OTHER", PasswordHash = "x" };
        var ownerAuth = Auth(owner, now);
        var eventAuth = Auth(owner, now);
        var otherAuth = Auth(other, now);
        var library = new Library { Name = "Videos", RootPath = "/media", RootIdentity = "root" };
        var item = new MediaItem
        {
            LibraryId = library.Id, RelativePath = "movie.mp4", DisplayName = "movie.mp4", SearchKey = "movie.mp4",
            Kind = "video", Extension = ".mp4", MimeType = "video/mp4", SizeBytes = 1234,
            FileIdentity = "file-id", MtimeNs = 42, SourceKind = "physical", Lifecycle = "available", Version = 3
        };
        var generation = MediaAccess.Generation(item);
        var valid = Session(owner, ownerAuth, item, generation, now);
        var revoked = Session(owner, ownerAuth, item, generation, now); revoked.RevokedAt = now.AddSeconds(-1);
        var expired = Session(owner, ownerAuth, item, generation, now); expired.AbsoluteExpiresAt = now;
        var wrongGeneration = Session(owner, ownerAuth, item, "stale", now);
        var otherUser = Session(other, otherAuth, item, generation, now);
        db.AddRange(owner, other, ownerAuth, eventAuth, otherAuth, library,
            new LibraryGrant { UserId = owner.Id, LibraryId = library.Id, CanRead = true },
            item, new MediaMetadata { MediaItemId = item.Id, ProbeStatus = "pending", ContentGeneration = item.Version },
            valid, revoked, expired, wrongGeneration, otherUser);
        await db.SaveChangesAsync();

        var permissions = new PermissionService(db, clock);
        var result = await PlaybackEvents.LoadAsync(db, permissions, null!, new Actor(owner.Id, eventAuth.Id, owner.Role), clock, CancellationToken.None);

        var hint = Assert.Single(result.Items);
        Assert.Equal(valid.Id, hint.SessionId);
        Assert.Equal("metadataPending", hint.State);
        Assert.Equal(generation, hint.Generation);
        Assert.Equal(0, hint.ContiguousBytes);
        Assert.Equal(1234, hint.TotalBytes);
        Assert.False(result.Truncated);
    }

    [Fact]
    public async Task Loader_drops_a_session_after_its_read_grant_is_revoked()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<BrianiDb>().UseSqlite(connection).Options;
        await using var db = new BrianiDb(options);
        await db.Database.EnsureCreatedAsync();
        var now = new DateTimeOffset(2026, 10, 12, 5, 0, 0, TimeSpan.Zero);
        var clock = new TestClock(now);
        var user = new User { Username = "member", NormalizedUsername = "MEMBER", PasswordHash = "x" };
        var auth = Auth(user, now);
        var library = new Library { Name = "Videos", RootPath = "/media", RootIdentity = "root" };
        var item = new MediaItem
        {
            LibraryId = library.Id, RelativePath = "movie.mkv", DisplayName = "movie.mkv", SearchKey = "movie.mkv",
            Kind = "video", Extension = ".mkv", MimeType = "video/x-matroska", SizeBytes = 100,
            FileIdentity = "file-id", MtimeNs = 7, SourceKind = "physical", Lifecycle = "available"
        };
        var session = Session(user, auth, item, MediaAccess.Generation(item), now);
        db.AddRange(user, auth, library, item,
            new LibraryGrant { UserId = user.Id, LibraryId = library.Id, CanRead = true },
            new MediaMetadata { MediaItemId = item.Id, ProbeStatus = "ready", ContentGeneration = item.Version }, session);
        await db.SaveChangesAsync();

        var permissions = new PermissionService(db, clock);
        var actor = new Actor(user.Id, auth.Id, user.Role);
        var visible = await PlaybackEvents.LoadAsync(db, permissions, null!, actor, clock, CancellationToken.None);
        Assert.Single(visible.Items);
        var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == user.Id && x.LibraryId == library.Id);
        grant.CanRead = false;
        await db.SaveChangesAsync();

        var revokedGrant = await PlaybackEvents.LoadAsync(db, permissions, null!, actor, clock, CancellationToken.None);
        Assert.Empty(revokedGrant.Items);
    }

    private static AuthSession Auth(User user, DateTimeOffset now) => new()
    {
        UserId = user.Id, DeviceName = "test", RefreshHash = Guid.NewGuid().ToString("N"),
        CreatedAt = now.AddHours(-1), LastSeenAt = now, RefreshExpiresAt = now.AddDays(1)
    };

    private static PlaybackSession Session(User user, AuthSession auth, MediaItem item, string generation, DateTimeOffset now) => new()
    {
        UserId = user.Id, AuthSessionId = auth.Id, MediaItemId = item.Id, TargetGeneration = generation,
        TicketHash = Guid.NewGuid().ToString("N"), CreatedAt = now.AddMinutes(-1),
        FirstUseDeadline = now.AddMinutes(9), AbsoluteExpiresAt = now.AddHours(23)
    };

    private sealed class TestClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
