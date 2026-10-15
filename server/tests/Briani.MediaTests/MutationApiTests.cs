using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Runtime.InteropServices;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Media.Operations;
using Briani.Api.Modules.Media.Processing;
using Briani.Api.Modules.Playback;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.MediaTests;

public sealed class MutationApiTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    private string? lastProblemCode;
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Rename_and_same_library_move_preserve_media_identity_and_progress()
    {
        var source = await AddLibrary("move", [("films/one.mkv", new byte[] { 1, 2, 3, 4 })], withFolder: true, withMetadata: true);
        await fixture.Host.InDb(async db =>
        {
            db.PlaybackProgress.Add(new PlaybackProgress { UserId = fixture.Admin.User.Id, MediaItemId = source.MediaId, PositionMs = 2100, DurationMs = 9000, UpdatedAt = fixture.Host.Clock.GetUtcNow(), Version = 4 });
            await db.SaveChangesAsync(); return 0;
        });
        var rename = await ScheduleRename(source.MediaId, "renamed.mkv", 1);
        Assert.Equal(HttpStatusCode.Accepted, rename.Status);
        await RunOnce();
        var moved = await ReadMedia(source.MediaId);
        Assert.Equal(source.MediaId, moved.Id);
        Assert.Equal("films/renamed.mkv", moved.RelativePath);
        Assert.Equal(2, moved.Version);
        Assert.Equal("renamed.mkv", moved.DisplayName);
        var progress = await fixture.Host.InDb(db => db.PlaybackProgress.AsNoTracking().SingleAsync(x => x.UserId == fixture.Admin.User.Id && x.MediaItemId == source.MediaId));
        Assert.Equal(2100, progress.PositionMs);
        Assert.Equal(4, progress.Version);

        var move = await ScheduleMove(source.MediaId, source.DestinationFolderId, 2);
        Assert.Equal(HttpStatusCode.Accepted, move.Status);
        await RunOnce();
        moved = await ReadMedia(source.MediaId);
        Assert.Equal(source.MediaId, moved.Id);
        Assert.Equal("archive/renamed.mkv", moved.RelativePath);
        Assert.Equal(3, moved.Version);
        var metadataGeneration = await fixture.Host.InDb(db => db.MediaMetadata.AsNoTracking().Where(x => x.MediaItemId == source.MediaId).Select(x => x.ContentGeneration).SingleAsync());
        Assert.Equal(moved.Version, metadataGeneration);
    }

    [Fact]
    public async Task Invalid_version_collision_traversal_internal_name_and_foreign_folder_are_denied()
    {
        var source = await AddLibrary("invalid", [("source.mkv", new byte[] { 1, 2, 3 }), ("collision.mkv", new byte[] { 4, 5, 6 })], withFolder: true);
        Assert.Equal(HttpStatusCode.Conflict, (await ScheduleRename(source.MediaId, "new.mkv", 9)).Status);
        Assert.Equal(HttpStatusCode.BadRequest, (await ScheduleRename(source.MediaId, "../escape.mkv", 1)).Status);
        Assert.Equal(HttpStatusCode.BadRequest, (await ScheduleRename(source.MediaId, ".briani", 1)).Status);
        var foreign = await AddLibrary("foreign", [], withFolder: true);
        Assert.Equal(HttpStatusCode.NotFound, (await ScheduleMove(source.MediaId, foreign.FolderId, 1)).Status);

        var collision = await ScheduleRename(source.MediaId, "collision.mkv", 1);
        Assert.Equal(HttpStatusCode.Accepted, collision.Status);
        await RunOnce();
        var operation = await GetOperation(collision.Id);
        Assert.Equal("failed", operation.GetProperty("state").GetString());
        Assert.Equal("destination_exists", operation.GetProperty("error").GetProperty("code").GetString());
        Assert.Equal(new byte[] { 1, 2, 3 }, await File.ReadAllBytesAsync(Path.Combine(source.Root, "source.mkv")));
        Assert.Equal(new byte[] { 4, 5, 6 }, await File.ReadAllBytesAsync(Path.Combine(source.Root, "collision.mkv")));
    }

    [Fact]
    public async Task Readers_block_rename_and_default_trash_while_forced_trash_cancels_reader()
    {
        var source = await AddLibrary("readers", [("film.mkv", new byte[] { 1, 2, 3 })]);
        var readers = fixture.Host.Services.GetRequiredService<MediaReaders>();
        using var cancellation = new CancellationTokenSource();
        var reader = readers.Acquire(fixture.Admin.SessionId, source.MediaId, cancellation.Token);
        Assert.Equal(HttpStatusCode.Conflict, (await ScheduleRename(source.MediaId, "renamed.mkv", 1)).Status);
        Assert.Equal("active_reader_conflict", await LastProblemCode());
        Assert.Equal(HttpStatusCode.Conflict, (await ScheduleDelete(source.MediaId, version: 1, mode: null, force: false)).Status);
        Assert.Equal("active_reader_conflict", await LastProblemCode());

        var forced = await ScheduleDelete(source.MediaId, version: 1, mode: "trash", force: true);
        Assert.Equal(HttpStatusCode.Accepted, forced.Status);
        Assert.True(reader.Token.IsCancellationRequested);
        reader.Dispose();
        await RunOnce();
        var item = await ReadMediaIncludingTrashed(source.MediaId);
        Assert.Equal("trashed", item.Lifecycle);
    }

    [Fact]
    public async Task Trash_and_permanent_delete_are_distinct_and_preserve_seeding_hardlink()
    {
        var source = await AddLibrary("trash", [("visible/movie.mkv", new byte[] { 9, 8, 7, 6 })], withFolder: true, seedingPath: "seed/movie.mkv");
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var library = await fixture.Host.InDb(db => db.Libraries.AsNoTracking().SingleAsync(x => x.Id == source.LibraryId));
        NodeIdentity originalIdentity;
        using (var directory = storage.OpenLibrary(library)) originalIdentity = directory.Inspect("seed/movie.mkv");

        var trash = await ScheduleDelete(source.MediaId, version: 1, mode: null, force: false);
        Assert.Equal(HttpStatusCode.Accepted, trash.Status);
        await RunOnce();
        Assert.Equal("trashed", (await ReadMediaIncludingTrashed(source.MediaId)).Lifecycle);
        using (var directory = storage.OpenLibrary(library))
        {
            Assert.Equal(originalIdentity.Key, directory.Inspect("seed/movie.mkv").Key);
            Assert.Equal(".briani", directory.Names().Single(x => x == ".briani"));
            Assert.Contains("trash", directory.Names(".briani"));
        }
        var trashBytes = Directory.GetFiles(Path.Combine(source.Root, ".briani", "trash"));
        Assert.Single(trashBytes);
        Assert.False(File.Exists(source.FirstFile));
        Assert.Equal(new byte[] { 9, 8, 7, 6 }, await File.ReadAllBytesAsync(Path.Combine(source.Root, "seed/movie.mkv")));

        var permanentSource = await AddLibrary("permanent", [("doomed.mkv", new byte[] { 5, 4, 3 })]);
        var permanent = await ScheduleDelete(permanentSource.MediaId, version: 1, mode: "permanent", force: false);
        Assert.Equal(HttpStatusCode.Accepted, permanent.Status);
        await RunOnce();
        Assert.Equal("deleted", (await ReadMediaIncludingTrashed(permanentSource.MediaId)).Lifecycle);
        Assert.False(File.Exists(Path.Combine(permanentSource.Root, "doomed.mkv")));
        Assert.Empty(Directory.GetFiles(Path.Combine(permanentSource.Root, ".briani", "removing")));
    }

    [Fact]
    public async Task Virtual_trash_changes_catalog_without_touching_backing_payload()
    {
        var source = await AddLibrary("virtual", [("payload/item.mkv", new byte[] { 3, 1, 4 })]);
        await fixture.Host.InDb(async db =>
        {
            var media = await db.MediaItems.SingleAsync(x => x.Id == source.MediaId);
            media.SourceKind = "virtual";
            await db.SaveChangesAsync(); return 0;
        });
        var op = await ScheduleDelete(source.MediaId, version: 1, mode: "trash", force: false);
        Assert.Equal(HttpStatusCode.Accepted, op.Status);
        await RunOnce();
        Assert.Equal("trashed", (await ReadMediaIncludingTrashed(source.MediaId)).Lifecycle);
        Assert.Equal(new byte[] { 3, 1, 4 }, await File.ReadAllBytesAsync(Path.Combine(source.Root, "payload/item.mkv")));
    }

    [Fact]
    public async Task Revoked_owner_grant_between_enqueue_and_run_prevents_filesystem_mutation()
    {
        var source = await AddLibrary("grant-revoke", [("film.mkv", new byte[] { 7, 7, 7 })]);
        var member = await AddMember(source.LibraryId, canManage: true);
        var request = IdentityFixture.As(fixture.Host.CreateClient(), member.Tokens.AccessToken);
        using var queued = await request.PostAsJsonAsync($"/api/v1/media/{source.MediaId:D}/rename", new { name = "changed.mkv", version = 1 });
        Assert.Equal(HttpStatusCode.Accepted, queued.StatusCode);
        var operation = (await queued.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        await fixture.Host.InDb(async db =>
        {
            db.LibraryGrants.RemoveRange(await db.LibraryGrants.Where(x => x.UserId == member.User.Id && x.LibraryId == source.LibraryId).ToListAsync());
            await db.SaveChangesAsync(); return 0;
        });
        await RunOnce();
        var state = await fixture.Host.InDb(db => db.Operations.AsNoTracking().Where(x => x.Id == operation).Select(x => new { x.State, x.ErrorCode }).SingleAsync());
        Assert.Equal("failed", state.State);
        Assert.Equal("not_found", state.ErrorCode);
        Assert.Equal(new byte[] { 7, 7, 7 }, await File.ReadAllBytesAsync(Path.Combine(source.Root, "film.mkv")));
        Assert.False(File.Exists(Path.Combine(source.Root, "changed.mkv")));
    }

    [Fact]
    public async Task Disabled_owner_between_enqueue_and_run_prevents_filesystem_mutation()
    {
        var source = await AddLibrary("owner-disabled", [("film.mkv", new byte[] { 8, 8, 8 })]);
        var member = await AddMember(source.LibraryId, canManage: true);
        var request = IdentityFixture.As(fixture.Host.CreateClient(), member.Tokens.AccessToken);
        using var queued = await request.PostAsJsonAsync($"/api/v1/media/{source.MediaId:D}/rename", new { name = "changed.mkv", version = 1 });
        Assert.Equal(HttpStatusCode.Accepted, queued.StatusCode);
        var operation = (await queued.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        using var disabled = await Authorized().PatchAsJsonAsync($"/api/v1/admin/users/{member.User.Id}", new { version = member.User.Version, enabled = false });
        Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
        await RunOnce();
        var state = await fixture.Host.InDb(db => db.Operations.AsNoTracking().Where(x => x.Id == operation).Select(x => new { x.State, x.ErrorCode }).SingleAsync());
        Assert.Equal("failed", state.State);
        Assert.Equal("forbidden", state.ErrorCode);
        Assert.Equal(new byte[] { 8, 8, 8 }, await File.ReadAllBytesAsync(Path.Combine(source.Root, "film.mkv")));
        Assert.False(File.Exists(Path.Combine(source.Root, "changed.mkv")));
    }

    [Fact]
    public async Task Idempotency_reuses_same_mutation_and_rejects_different_body()
    {
        var source = await AddLibrary("idempotency", [("original.mkv", new byte[] { 2, 4, 6 })]);
        using var same = await SendRename(source.MediaId, "first.mkv", 1, "mutation-key-1");
        using var repeat = await SendRename(source.MediaId, "first.mkv", 1, "mutation-key-1");
        Assert.Equal(HttpStatusCode.Accepted, same.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, repeat.StatusCode);
        var id = (await same.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        Assert.Equal(id, (await repeat.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid());
        using var conflict = await SendRename(source.MediaId, "second.mkv", 1, "mutation-key-1");
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Equal("idempotency_conflict", await ProblemCode(conflict));
        Assert.Equal(1, await fixture.Host.InDb(db => db.Operations.CountAsync(x => x.TargetId == source.MediaId)));
    }

    [Fact]
    public async Task Interrupted_after_physical_move_recovers_catalog_once_without_losing_progress()
    {
        var source = await AddLibrary("journal", [("before.mkv", new byte[] { 0, 255, 3, 10 })], withMetadata: true);
        await fixture.Host.InDb(async db =>
        {
            db.PlaybackProgress.Add(new PlaybackProgress { UserId = fixture.Admin.User.Id, MediaItemId = source.MediaId, PositionMs = 4200, DurationMs = 20000, UpdatedAt = fixture.Host.Clock.GetUtcNow(), Version = 3 });
            db.ThumbnailEntries.Add(new ThumbnailEntry { MediaItemId = source.MediaId, Generation = 1, Variant = "default", CacheRelativePath = "cache/cover.jpg", FileIdentity = "thumbnail-id", Bytes = 2, CreatedAt = fixture.Host.Clock.GetUtcNow(), LastAccessedAt = fixture.Host.Clock.GetUtcNow() });
            await db.SaveChangesAsync(); return 0;
        });
        var scheduled = await ScheduleRename(source.MediaId, "after.mkv", 1);
        var operations = fixture.Host.Services.CreateScope();
        using (operations)
        {
            var service = operations.ServiceProvider.GetRequiredService<MediaOperations>();
            var threw = false;
            service.BeforeCatalogCommit = () => { if (!threw) { threw = true; throw new IOException("simulated journal interruption"); } };
            Assert.False(await service.RunOnceAsync());
        }
        Assert.Equal(new byte[] { 0, 255, 3, 10 }, await File.ReadAllBytesAsync(Path.Combine(source.Root, "after.mkv")));
        Assert.False(File.Exists(Path.Combine(source.Root, "before.mkv")));
        Assert.True(await RunOnce());

        var media = await ReadMedia(source.MediaId);
        Assert.Equal("after.mkv", media.RelativePath);
        Assert.Equal(2, media.Version);
        Assert.Equal(1, await fixture.Host.InDb(db => db.MediaItems.CountAsync(x => x.Id == source.MediaId)));
        var progress = await fixture.Host.InDb(db => db.PlaybackProgress.AsNoTracking().SingleAsync(x => x.MediaItemId == source.MediaId && x.UserId == fixture.Admin.User.Id));
        Assert.Equal(4200, progress.PositionMs); Assert.Equal(3, progress.Version);
        Assert.Equal(2, await fixture.Host.InDb(db => db.MediaMetadata.AsNoTracking().Where(x => x.MediaItemId == source.MediaId).Select(x => x.ContentGeneration).SingleAsync()));
        Assert.Equal(2, await fixture.Host.InDb(db => db.ThumbnailEntries.AsNoTracking().Where(x => x.MediaItemId == source.MediaId).Select(x => x.Generation).SingleAsync()));
        Assert.Equal("completed", (await GetOperation(scheduled.Id)).GetProperty("state").GetString());
    }

    [Fact]
    public async Task Permanent_journal_recovery_rechecks_authority_before_unlinking_private_file()
    {
        var source = await AddLibrary("permanent-recovery", [("movie.mkv", new byte[] { 2, 3, 5, 7 })]);
        var library = await fixture.Host.InDb(db => db.Libraries.AsNoTracking().SingleAsync(x => x.Id == source.LibraryId));
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var privatePath = ".briani/removing/recovery.mkv";
        var command = await fixture.Host.InDb(async db =>
        {
            var item = await db.MediaItems.AsNoTracking().SingleAsync(x => x.Id == source.MediaId);
            var identity = item.FileIdentity;
            using (var root = storage.OpenLibrary(library))
            {
                root.CreateDirectory(".briani"); root.CreateDirectory(".briani/removing"); root.Rename(item.RelativePath, privatePath);
            }
            var op = new Operation { Id = Guid.NewGuid(), UserId = fixture.Admin.User.Id, Kind = "permanent", TargetId = item.Id,
                State = "running", CreatedAt = fixture.Host.Clock.GetUtcNow(), UpdatedAt = fixture.Host.Clock.GetUtcNow(), ExpiresAt = fixture.Host.Clock.GetUtcNow().AddDays(1),
                PayloadJson = JsonSerializer.Serialize(new MutationCommand(fixture.Admin.SessionId, source.LibraryId, item.Version, item.RelativePath, privatePath,
                    identity, item.SizeBytes!.Value, item.MtimeNs, item.DisplayName, item.ParentId, item.ParentRelativePath, false, Stage: "moved")) };
            db.Operations.Add(op); await db.SaveChangesAsync(); return op;
        });
        using (var client = Authorized())
        using (var logout = await client.PostAsync("/api/v1/auth/logout", null)) Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);

        Assert.True(await RunOnce());
        var path = Path.Combine(source.Root, privatePath.Replace('/', Path.DirectorySeparatorChar));
        Assert.True(File.Exists(path));
        Assert.Equal(new byte[] { 2, 3, 5, 7 }, await File.ReadAllBytesAsync(path));
        var failed = await fixture.Host.InDb(db => db.Operations.AsNoTracking().SingleAsync(x => x.Id == command.Id));
        Assert.Equal("failed", failed.State);
        Assert.Equal("not_found", failed.ErrorCode);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Revoked_session_cannot_complete_same_path_noop_rename(bool movedMarker)
    {
        var source = await AddLibrary("noop-revoked", [("same.mkv", new byte[] { 1, 4, 9 })]);
        var queued = await ScheduleRename(source.MediaId, "same.mkv", 1);
        Assert.Equal(HttpStatusCode.Accepted, queued.Status);
        if(movedMarker)await fixture.Host.InDb(async db=>{var op=await db.Operations.SingleAsync(x=>x.Id==queued.Id);var command=JsonSerializer.Deserialize<MutationCommand>(op.PayloadJson,new JsonSerializerOptions(JsonSerializerDefaults.Web))!;op.PayloadJson=JsonSerializer.Serialize(command with{Stage="moved"},new JsonSerializerOptions(JsonSerializerDefaults.Web));op.State="running";await db.SaveChangesAsync();return 0;});
        using (var logout = await Authorized().PostAsync("/api/v1/auth/logout", null)) Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.True(await RunOnce());
        var state = await fixture.Host.InDb(db => db.Operations.AsNoTracking().Where(x => x.Id == queued.Id).Select(x => new { x.State, x.ErrorCode }).SingleAsync());
        Assert.Equal("failed", state.State); Assert.Equal("not_found", state.ErrorCode);
        Assert.Equal("same.mkv", (await ReadMedia(source.MediaId)).RelativePath);
        Assert.Equal(new byte[] { 1, 4, 9 }, await File.ReadAllBytesAsync(source.FirstFile));
    }

    [Fact]
    public async Task Revoked_session_cannot_apply_virtual_moved_stage_without_physical_change()
    {
        var source = await AddLibrary("virtual-resume-revoked", [("virtual.mkv", new byte[] { 4, 8, 12 })]);
        await fixture.Host.InDb(async db => { (await db.MediaItems.SingleAsync(x => x.Id == source.MediaId)).SourceKind = "virtual"; await db.SaveChangesAsync(); return 0; });
        var queued = await ScheduleDelete(source.MediaId, version: 1, mode: "trash", force: false);
        Assert.Equal(HttpStatusCode.Accepted, queued.Status);
        await fixture.Host.InDb(async db =>
        {
            var op = await db.Operations.SingleAsync(x => x.Id == queued.Id);
            var command = JsonSerializer.Deserialize<MutationCommand>(op.PayloadJson, new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
            op.PayloadJson = JsonSerializer.Serialize(command with { Stage = "moved" }, new JsonSerializerOptions(JsonSerializerDefaults.Web));
            op.State = "running"; await db.SaveChangesAsync(); return 0;
        });
        using (var logout = await Authorized().PostAsync("/api/v1/auth/logout", null)) Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        Assert.True(await RunOnce());
        var state = await fixture.Host.InDb(db => db.Operations.AsNoTracking().Where(x => x.Id == queued.Id).Select(x => new { x.State, x.ErrorCode }).SingleAsync());
        Assert.Equal("failed", state.State); Assert.Equal("not_found", state.ErrorCode);
        Assert.Equal("available", (await ReadMedia(source.MediaId)).Lifecycle);
        Assert.Equal(new byte[] { 4, 8, 12 }, await File.ReadAllBytesAsync(source.FirstFile));
    }

    [Fact]
    public async Task Scan_defers_during_interrupted_rename_then_reconciles_without_duplicate_media()
    {
        var source = await AddLibrary("scan-journal-race", [("before.mkv", new byte[] { 0, 255, 3, 10 })], withMetadata: true);
        await fixture.Host.InDb(async db =>
        {
            db.PlaybackProgress.Add(new PlaybackProgress { UserId = fixture.Admin.User.Id, MediaItemId = source.MediaId, PositionMs = 7300, DurationMs = 18000, UpdatedAt = fixture.Host.Clock.GetUtcNow(), Version = 6 });
            await db.SaveChangesAsync(); return 0;
        });
        var queued = await ScheduleRename(source.MediaId, "after.mkv", 1);
        Assert.Equal(HttpStatusCode.Accepted, queued.Status);
        using (var scope = fixture.Host.Services.CreateScope())
        {
            var operations = scope.ServiceProvider.GetRequiredService<MediaOperations>();
            operations.BeforeCatalogCommit = () => throw new IOException("simulated interruption after physical move");
            Assert.False(await operations.RunOnceAsync());
        }
        Assert.True(File.Exists(Path.Combine(source.Root, "after.mkv")));
        Assert.False(File.Exists(Path.Combine(source.Root, "before.mkv")));
        using (var scope = fixture.Host.Services.CreateScope())
        {
            var scanner = scope.ServiceProvider.GetRequiredService<ScanWorker>();
            await Assert.ThrowsAsync<ScanWorker.ScanDeferredException>(() => scanner.ScanLibraryAsync(source.LibraryId));
        }

        Assert.True(await RunOnce());
        using (var scope = fixture.Host.Services.CreateScope())
            await scope.ServiceProvider.GetRequiredService<ScanWorker>().ScanLibraryAsync(source.LibraryId);

        var catalog = await fixture.Host.InDb(db => db.MediaItems.AsNoTracking().Where(x => x.LibraryId == source.LibraryId && x.Kind == "video").ToListAsync());
        var media = Assert.Single(catalog);
        Assert.Equal(source.MediaId, media.Id);
        Assert.Equal("after.mkv", media.RelativePath);
        Assert.Equal("available", media.Lifecycle);
        var progress = await fixture.Host.InDb(db => db.PlaybackProgress.AsNoTracking().SingleAsync(x => x.UserId == fixture.Admin.User.Id && x.MediaItemId == source.MediaId));
        Assert.Equal(7300, progress.PositionMs); Assert.Equal(6, progress.Version);
        var operation = await fixture.Host.InDb(db => db.Operations.AsNoTracking().SingleAsync(x => x.Id == queued.Id));
        Assert.Equal("completed", operation.State);
        Assert.Equal(2, await fixture.Host.InDb(db => db.MediaMetadata.AsNoTracking().Where(x => x.MediaItemId == source.MediaId).Select(x => x.ContentGeneration).SingleAsync()));
    }

    [Fact]
    public async Task Library_removal_rejects_active_readers_then_clears_catalog_and_tickets_without_deleting_files()
    {
        var source = await AddLibrary("library-removal", [("movie.mkv", new byte[] { 11, 12, 13 })]);
        var readers = fixture.Host.Services.GetRequiredService<MediaReaders>();
        using var requestLifetime = new CancellationTokenSource();
        using var reader = readers.Acquire(fixture.Admin.SessionId, source.MediaId, requestLifetime.Token);
        await fixture.Host.InDb(async db =>
        {
            db.PlaybackSessions.Add(new PlaybackSession { UserId = fixture.Admin.User.Id, AuthSessionId = fixture.Admin.SessionId, MediaItemId = source.MediaId,
                TicketHash = "regression-ticket-hash", TargetGeneration = "generation", CreatedAt = fixture.Host.Clock.GetUtcNow(),
                FirstUseDeadline = fixture.Host.Clock.GetUtcNow().AddMinutes(5), AbsoluteExpiresAt = fixture.Host.Clock.GetUtcNow().AddHours(1) });
            db.Jobs.Add(new WorkJob { Kind = "scan", TargetId = source.LibraryId, DedupKey = "library-removal-scan", State = "queued", PayloadJson = "{}",
                CreatedAt = fixture.Host.Clock.GetUtcNow(), UpdatedAt = fixture.Host.Clock.GetUtcNow(), NextAttemptAt = fixture.Host.Clock.GetUtcNow() });
            await db.SaveChangesAsync(); return 0;
        });
        using (var rejected = await Authorized().DeleteAsync($"/api/v1/libraries/{source.LibraryId:D}?version=1"))
        {
            Assert.Equal(HttpStatusCode.Conflict, rejected.StatusCode);
            Assert.Equal("library_in_use", await ProblemCode(rejected));
        }
        reader.Dispose();
        using (var removed = await Authorized().DeleteAsync($"/api/v1/libraries/{source.LibraryId:D}?version=1")) Assert.Equal(HttpStatusCode.NoContent, removed.StatusCode);
        Assert.True(File.Exists(source.FirstFile));
        Assert.Equal(new byte[] { 11, 12, 13 }, await File.ReadAllBytesAsync(source.FirstFile));
        Assert.Equal(0, await fixture.Host.InDb(db => db.MediaItems.CountAsync(x => x.LibraryId == source.LibraryId)));
        Assert.False(await fixture.Host.InDb(db => db.Libraries.AnyAsync(x => x.Id == source.LibraryId)));
        var ticket = await fixture.Host.InDb(db => db.PlaybackSessions.AsNoTracking().SingleAsync(x => x.TicketHash == "regression-ticket-hash"));
        Assert.Null(ticket.MediaItemId); Assert.NotNull(ticket.RevokedAt);
        var job = await fixture.Host.InDb(db => db.Jobs.AsNoTracking().SingleAsync(x => x.TargetId == source.LibraryId));
        Assert.Equal("cancelled", job.State); Assert.Null(job.DedupKey);
    }

    private async Task<MediaTarget> AddLibrary(string slug, (string Path, byte[] Bytes)[] files, bool withFolder = false, string? seedingPath = null, bool withMetadata = false)
    {
        var name = "mut-" + slug + "-" + Guid.NewGuid().ToString("N");
        var root = Path.Combine(fixture.Host.Root, "data", name); Directory.CreateDirectory(root);
        if (withFolder)
        {
            Directory.CreateDirectory(Path.Combine(root, "films"));
            Directory.CreateDirectory(Path.Combine(root, "archive"));
        }
        var fileIndex = 0;
        foreach (var file in files)
        {
            var path = Path.Combine(root, file.Path.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(path)!); await File.WriteAllBytesAsync(path, file.Bytes);
            if (seedingPath is not null)
            {
                var seed = Path.Combine(root, seedingPath.Replace('/', Path.DirectorySeparatorChar));
                Directory.CreateDirectory(Path.GetDirectoryName(seed)!); if (Link(path, seed) != 0) throw new IOException("Unable to create generated hard-link fixture.");
            }
        }
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var contained = storage.ValidateLibraryRoot(name); var libraryId = Guid.NewGuid();
        var library = new Library { Id = libraryId, Name = name, RootPath = name, RootIdentity = contained.Identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        var mediaId = Guid.NewGuid(); var folderId = Guid.NewGuid(); var destinationFolderId = Guid.NewGuid();
        var dbItems = new List<MediaItem>();
        if (withFolder)
        {
            using var dir = storage.OpenLibrary(library);
            var folderStat = dir.Inspect("films");
            dbItems.Add(new MediaItem { Id = folderId, LibraryId = libraryId, RelativePath = "films", ParentRelativePath = "", DisplayName = "films", SearchKey = "FILMS", Kind = "folder", SizeBytes = null, FileIdentity = folderStat.Key, MtimeNs = folderStat.MtimeNs, CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow() });
            var destinationStat = dir.Inspect("archive");
            dbItems.Add(new MediaItem { Id = destinationFolderId, LibraryId = libraryId, RelativePath = "archive", ParentRelativePath = "", DisplayName = "archive", SearchKey = "ARCHIVE", Kind = "folder", SizeBytes = null, FileIdentity = destinationStat.Key, MtimeNs = destinationStat.MtimeNs, CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow() });
        }
        foreach (var file in files)
        {
            NodeIdentity stat;
            using (var directory = storage.OpenLibrary(library)) using (var stream = directory.OpenFile(file.Path)) stat = ContainedDirectory.Inspect(stream);
            var parentPath = Path.GetDirectoryName(file.Path)?.Replace(Path.DirectorySeparatorChar, '/') ?? "";
            var itemId = fileIndex++ == 0 ? mediaId : Guid.NewGuid();
            dbItems.Add(new MediaItem { Id = itemId, LibraryId = libraryId, ParentId = withFolder && parentPath == "films" ? folderId : null, ParentRelativePath = parentPath,
                RelativePath = file.Path, DisplayName = Path.GetFileName(file.Path), SearchKey = Path.GetFileName(file.Path).ToUpperInvariant(), Kind = "video", Extension = Path.GetExtension(file.Path), MimeType = "video/x-matroska",
                SizeBytes = stat.Length, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, Lifecycle = "available", CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow(), Version = 1 });
        }
        await fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(library); db.MediaItems.AddRange(dbItems);
            if (withMetadata && files.Length > 0) db.MediaMetadata.Add(new MediaMetadata { MediaItemId = mediaId, ProbeStatus = "ready", ContentGeneration = 1, DurationMs = 20000, TracksJson = "[]" });
            await db.SaveChangesAsync(); return 0;
        });
        return new(libraryId, mediaId, folderId, destinationFolderId, root, files.Length == 0 ? root : Path.Combine(root, files[0].Path.Replace('/', Path.DirectorySeparatorChar)));
    }

    private async Task<Member> AddMember(Guid libraryId, bool canManage)
    {
        var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var password = Credentials.NewToken();
        using var created = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "mutmember", displayName = "Mutation Member", password, confirmPassword = password, role = "member" });
        created.EnsureSuccessStatusCode(); var user = (await created.Content.ReadFromJsonAsync<UserView>())!;
        await fixture.Host.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = user.Id, LibraryId = libraryId, CanRead = true, CanManage = canManage });
            await db.SaveChangesAsync(); return 0;
        });
        using var login = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = "mutmember", password, deviceName = "test" });
        return new(user, (await login.Content.ReadFromJsonAsync<AuthReply>())!);
    }

    private async Task<(HttpStatusCode Status, Guid Id)> ScheduleRename(Guid id, string name, long version)
    {
        using var response = await Authorized().PostAsJsonAsync($"/api/v1/media/{id:D}/rename", new { name, version });
        lastProblemCode = response.IsSuccessStatusCode ? null : await ProblemCode(response);
        return (response.StatusCode, response.IsSuccessStatusCode ? (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid() : Guid.Empty);
    }
    private async Task<(HttpStatusCode Status, Guid Id)> ScheduleMove(Guid id, Guid? folder, long version)
    {
        using var response = await Authorized().PostAsJsonAsync($"/api/v1/media/{id:D}/move", new { targetFolderId = folder, version });
        lastProblemCode = response.IsSuccessStatusCode ? null : await ProblemCode(response);
        return (response.StatusCode, response.IsSuccessStatusCode ? (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid() : Guid.Empty);
    }
    private async Task<(HttpStatusCode Status, Guid Id)> ScheduleDelete(Guid id, long version, string? mode, bool force)
    {
        var suffix = $"?version={version}&force={force}" + (mode is null ? "" : $"&mode={mode}");
        using var response = await Authorized().DeleteAsync($"/api/v1/media/{id:D}{suffix}");
        lastProblemCode = response.IsSuccessStatusCode ? null : await ProblemCode(response);
        return (response.StatusCode, response.IsSuccessStatusCode ? (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid() : Guid.Empty);
    }
    private async Task<HttpResponseMessage> SendRename(Guid id, string name, long version, string key)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/media/{id:D}/rename") { Content = JsonContent.Create(new { name, version }) };
        request.Headers.Add("Idempotency-Key", key); return await Authorized().SendAsync(request);
    }
    private Task<string?> LastProblemCode() => Task.FromResult(lastProblemCode);
    private HttpClient Authorized() => IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
    private async Task<JsonElement> GetOperation(Guid id) => await Authorized().GetFromJsonAsync<JsonElement>($"/api/v1/operations/{id:D}");
    private async Task<bool> RunOnce()
    { using var scope = fixture.Host.Services.CreateScope(); return await scope.ServiceProvider.GetRequiredService<MediaOperations>().RunOnceAsync(); }
    private Task<MediaItem> ReadMedia(Guid id) => fixture.Host.InDb(db => db.MediaItems.AsNoTracking().SingleAsync(x => x.Id == id));
    private Task<MediaItem> ReadMediaIncludingTrashed(Guid id) => fixture.Host.InDb(db => db.MediaItems.IgnoreQueryFilters().AsNoTracking().SingleAsync(x => x.Id == id));
    private static async Task<string?> ProblemCode(HttpResponseMessage response) => (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString();
    [DllImport("libc", EntryPoint = "link", SetLastError = true)] private static extern int Link(string existingPath, string newPath);

    private sealed record MediaTarget(Guid LibraryId, Guid MediaId, Guid FolderId, Guid DestinationFolderId, string Root, string FirstFile);
    private sealed record Member(UserView User, AuthReply Tokens);
}
