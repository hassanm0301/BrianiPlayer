using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Preferences;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Discovery;
using Briani.Api.Modules.Downloads;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
namespace Briani.Api.Infrastructure.Persistence;
public sealed class SchemaState
{
    public string Id { get; set; } = "application";
    public string PlanVersion { get; set; } = "1.0";
    public string CompatibilityLockHash { get; set; } = "unverified";
}
public sealed class BrianiDb(DbContextOptions<BrianiDb> options) : DbContext(options)
{
    public DbSet<SchemaState> SchemaState => Set<SchemaState>();
    public DbSet<User> Users => Set<User>(); public DbSet<AuthSession> AuthSessions => Set<AuthSession>();
    public DbSet<AccessToken> AccessTokens => Set<AccessToken>(); public DbSet<RefreshReplay> RefreshReplays => Set<RefreshReplay>();
    public DbSet<DevicePairing> DevicePairings => Set<DevicePairing>(); public DbSet<Library> Libraries => Set<Library>();
    public DbSet<LibraryGrant> LibraryGrants => Set<LibraryGrant>(); public DbSet<Setting> Settings => Set<Setting>();
    public DbSet<UserPreference> UserPreferences => Set<UserPreference>();
    public DbSet<AuditEvent> AuditEvents => Set<AuditEvent>();
    public DbSet<MediaItem> MediaItems=>Set<MediaItem>();public DbSet<MediaMetadata> MediaMetadata=>Set<MediaMetadata>();public DbSet<ThumbnailEntry> ThumbnailEntries=>Set<ThumbnailEntry>();
    public DbSet<PlaybackProgress> PlaybackProgress=>Set<PlaybackProgress>();public DbSet<WorkJob> Jobs=>Set<WorkJob>();public DbSet<Operation> Operations=>Set<Operation>();public DbSet<PlaybackSession> PlaybackSessions=>Set<PlaybackSession>();
    public DbSet<DiscoverySnapshot> DiscoverySnapshots=>Set<DiscoverySnapshot>();public DbSet<DiscoveryResult> DiscoveryResults=>Set<DiscoveryResult>();public DbSet<TorrentUpload> TorrentUploads=>Set<TorrentUpload>();
    public DbSet<DownloadRequest> DownloadRequests=>Set<DownloadRequest>();public DbSet<TorrentJob> TorrentJobs=>Set<TorrentJob>();public DbSet<DownloadFile> DownloadFiles=>Set<DownloadFile>();public DbSet<DownloadOwnership> DownloadOwnerships=>Set<DownloadOwnership>();
    public DbSet<DownloadRequestFile> DownloadRequestFiles=>Set<DownloadRequestFile>();
    protected override void ConfigureConventions(ModelConfigurationBuilder config) => config.Properties<DateTimeOffset>().HaveConversion<UtcTicks>();
    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<SchemaState>(b => { b.ToTable("schema_state"); b.HasKey(x => x.Id); });
        model.Entity<User>(b => { b.ToTable("users"); b.HasIndex(x => x.NormalizedUsername).IsUnique(); b.Property(x=>x.Version).IsConcurrencyToken(); });
        model.Entity<AuthSession>(b => { b.ToTable("auth_sessions"); b.HasIndex(x=>x.RefreshHash).IsUnique(); b.HasOne<User>().WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Restrict); b.HasIndex(x=>x.RefreshExpiresAt); });
        model.Entity<AccessToken>(b => { b.ToTable("access_tokens"); b.HasKey(x=>x.TokenHash); b.HasIndex(x=>x.ExpiresAt); b.HasOne<AuthSession>().WithMany().HasForeignKey(x=>x.SessionId); });
        model.Entity<RefreshReplay>(b => { b.ToTable("refresh_replays"); b.HasKey(x=>x.ConsumedHash); b.HasOne<AuthSession>().WithMany().HasForeignKey(x=>x.SessionId); });
        model.Entity<DevicePairing>(b => { b.ToTable("device_pairings"); b.HasIndex(x=>x.DeviceSecretHash).IsUnique(); b.HasIndex(x=>x.HumanCodeHash).IsUnique(); b.HasIndex(x=>x.ExpiresAt); });
        model.Entity<Library>(b => { b.ToTable("libraries"); b.HasIndex(x=>x.RootPath).IsUnique(); b.Property(x=>x.Version).IsConcurrencyToken(); });
        model.Entity<LibraryGrant>(b => { b.ToTable("library_grants"); b.HasKey(x=>new{x.UserId,x.LibraryId}); b.HasOne<User>().WithMany().HasForeignKey(x=>x.UserId); b.HasOne<Library>().WithMany().HasForeignKey(x=>x.LibraryId); });
        model.Entity<UserPreference>(b=>{b.ToTable("user_preferences");b.HasKey(x=>x.UserId);b.HasOne<User>().WithOne().HasForeignKey<UserPreference>(x=>x.UserId);b.Property(x=>x.Version).IsConcurrencyToken();});
        model.Entity<Setting>(b => { b.ToTable("settings"); b.HasKey(x=>x.Key); b.Property(x=>x.Version).IsConcurrencyToken(); });
        model.Entity<MediaItem>(b=>{b.ToTable("media_items");b.HasIndex(x=>new{x.LibraryId,x.RelativePath}).IsUnique();b.HasIndex(x=>new{x.LibraryId,x.ParentId,x.SearchKey});b.HasOne<Library>().WithMany().HasForeignKey(x=>x.LibraryId).OnDelete(DeleteBehavior.Restrict);b.Property(x=>x.Version).IsConcurrencyToken();});
        model.Entity<MediaMetadata>(b=>{b.ToTable("media_metadata");b.HasKey(x=>x.MediaItemId);b.HasOne<MediaItem>().WithOne().HasForeignKey<MediaMetadata>(x=>x.MediaItemId);});
        model.Entity<ThumbnailEntry>(b=>{b.ToTable("thumbnail_entries");b.HasKey(x=>new{x.MediaItemId,x.Generation,x.Variant});b.HasOne<MediaItem>().WithMany().HasForeignKey(x=>x.MediaItemId);});
        model.Entity<PlaybackProgress>(b=>{b.ToTable("playback_progress");b.HasKey(x=>new{x.UserId,x.MediaItemId});b.HasOne<User>().WithMany().HasForeignKey(x=>x.UserId);b.HasOne<MediaItem>().WithMany().HasForeignKey(x=>x.MediaItemId);b.Property(x=>x.Version).IsConcurrencyToken();b.HasIndex(x=>new{x.UserId,x.UpdatedAt});});
        model.Entity<WorkJob>(b=>{b.ToTable("jobs");b.HasIndex(x=>x.DedupKey).IsUnique();b.HasIndex(x=>new{x.State,x.NextAttemptAt});});
        model.Entity<Operation>(b=>{b.ToTable("operations");b.HasIndex(x=>new{x.UserId,x.Kind,x.IdempotencyKey}).IsUnique();});
        model.Entity<PlaybackSession>(b=>{b.ToTable("playback_sessions");b.Property(x=>x.TicketIssued).HasDefaultValue(true);b.HasIndex(x=>x.TicketHash).IsUnique();b.HasIndex(x=>x.AbsoluteExpiresAt);b.HasOne<AuthSession>().WithMany().HasForeignKey(x=>x.AuthSessionId).OnDelete(DeleteBehavior.Restrict);b.HasOne<User>().WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Restrict);b.HasOne<MediaItem>().WithMany().HasForeignKey(x=>x.MediaItemId).OnDelete(DeleteBehavior.Restrict);});
        model.Entity<DiscoverySnapshot>(b=>{b.ToTable("discovery_snapshots");b.HasIndex(x=>new{x.UserId,x.QueryKey});b.HasIndex(x=>x.ExpiresAt);b.HasOne<User>().WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Restrict);});
        model.Entity<DiscoveryResult>(b=>{b.ToTable("discovery_results");b.HasIndex(x=>x.SnapshotId);b.HasOne<DiscoverySnapshot>().WithMany().HasForeignKey(x=>x.SnapshotId);});
        model.Entity<TorrentUpload>(b=>{b.ToTable("torrent_uploads");b.HasIndex(x=>x.ExpiresAt);b.HasOne<User>().WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Restrict);});
        model.Entity<DownloadRequest>(b=>{b.ToTable("download_requests");b.HasIndex(x=>new{x.OwnerId,x.LibraryId,x.State});b.HasIndex(x=>new{x.OwnerId,x.IdempotencyKey}).IsUnique();b.Property(x=>x.Version).IsConcurrencyToken();b.HasOne<User>().WithMany().HasForeignKey(x=>x.OwnerId).OnDelete(DeleteBehavior.Restrict);b.HasOne<Library>().WithMany().HasForeignKey(x=>x.LibraryId).OnDelete(DeleteBehavior.Restrict);b.HasOne<TorrentJob>().WithMany().HasForeignKey(x=>x.TorrentJobId).OnDelete(DeleteBehavior.Restrict);});
        model.Entity<TorrentJob>(b=>{b.ToTable("torrent_jobs");b.Property(x=>x.Revision).HasDefaultValue(1L).IsConcurrencyToken();b.HasIndex(x=>x.UpstreamId).IsUnique().HasFilter("\"RetiredAt\" IS NULL AND \"UpstreamId\" IS NOT NULL");b.HasIndex(x=>x.InfoHashV1).IsUnique().HasFilter("\"RetiredAt\" IS NULL AND \"InfoHashV1\" IS NOT NULL");b.HasIndex(x=>x.InfoHashV2).IsUnique().HasFilter("\"RetiredAt\" IS NULL AND \"InfoHashV2\" IS NOT NULL");b.HasOne<Library>().WithMany().HasForeignKey(x=>x.LibraryId).OnDelete(DeleteBehavior.Restrict);});
        model.Entity<DownloadFile>(b=>{b.ToTable("download_files");b.HasIndex(x=>new{x.TorrentJobId,x.UpstreamFileIndex}).IsUnique();b.HasOne<TorrentJob>().WithMany().HasForeignKey(x=>x.TorrentJobId).OnDelete(DeleteBehavior.Restrict);b.Property(x=>x.Version).IsConcurrencyToken();});
        model.Entity<DownloadRequestFile>(b=>{b.ToTable("download_request_files");b.HasKey(x=>new{x.DownloadRequestId,x.DownloadFileId});b.HasOne<DownloadRequest>().WithMany().HasForeignKey(x=>x.DownloadRequestId);b.HasOne<DownloadFile>().WithMany().HasForeignKey(x=>x.DownloadFileId).OnDelete(DeleteBehavior.Restrict);});
        model.Entity<DownloadOwnership>(b=>{b.ToTable("download_ownerships");b.HasKey(x=>new{x.OwnerId,x.DownloadFileId});b.HasIndex(x=>new{x.OwnerId,x.LibraryId});b.HasOne<User>().WithMany().HasForeignKey(x=>x.OwnerId).OnDelete(DeleteBehavior.Restrict);b.HasOne<Library>().WithMany().HasForeignKey(x=>x.LibraryId).OnDelete(DeleteBehavior.Restrict);b.HasOne<DownloadFile>().WithMany().HasForeignKey(x=>x.DownloadFileId).OnDelete(DeleteBehavior.Restrict);});
        model.Entity<AuditEvent>(b => { b.ToTable("audit_events"); b.HasIndex(x=>x.CreatedAt); });
    }
    private void AdvanceTorrentRevisions()
    {
        ChangeTracker.DetectChanges();foreach(var entry in ChangeTracker.Entries<TorrentJob>().Where(x=>x.State==EntityState.Modified))
            entry.Entity.Revision=checked(entry.Property(x=>x.Revision).OriginalValue+1);
    }
    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {AdvanceTorrentRevisions();return base.SaveChanges(acceptAllChangesOnSuccess);}
    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess,CancellationToken cancellationToken=default)
    {AdvanceTorrentRevisions();return base.SaveChangesAsync(acceptAllChangesOnSuccess,cancellationToken);}

}
public sealed class UtcTicks() : ValueConverter<DateTimeOffset,long>(x=>x.UtcTicks,x=>new DateTimeOffset(x,TimeSpan.Zero));
