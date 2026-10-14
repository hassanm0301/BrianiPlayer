using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Microsoft.EntityFrameworkCore;

namespace Briani.Api.Modules.Playback;

public sealed record PlaybackEventBatch(PlaybackStateHint[] Items, bool Truncated);

/// <summary>Builds a bounded, permission-filtered snapshot for playback.state SSE hints.</summary>
public static class PlaybackEvents
{
    private const int MaxItems = 64;
    private const long StartupPrefixBytes = 16L * 1024 * 1024;

    public static async Task<PlaybackEventBatch> LoadAsync(
        BrianiDb db,
        PermissionService permissions,
        TorrentAvailability availability,
        Actor actor,
        TimeProvider clock,
        CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        // Join the original auth session and user in the query. A playback session is
        // visible only while its owner and the exact session that created it are live.
        var rows = await (from playback in db.PlaybackSessions.AsNoTracking()
                          join auth in db.AuthSessions.AsNoTracking() on playback.AuthSessionId equals auth.Id
                          join user in db.Users.AsNoTracking() on playback.UserId equals user.Id
                          where playback.UserId == actor.UserId && auth.UserId == playback.UserId
                                && auth.RevokedAt == null && auth.RefreshExpiresAt > now
                                && user.Enabled && !user.MustChangePassword
                                && playback.RevokedAt == null && playback.AbsoluteExpiresAt > now
                                && (playback.ActivatedAt == null
                                    ? playback.FirstUseDeadline > now
                                    : playback.LastActivityAt != null && playback.LastActivityAt > now.AddMinutes(-30))
                          orderby playback.CreatedAt descending
                          select new { Session = playback, User = user })
            .Take(MaxItems + 1).ToArrayAsync(ct);

        var truncated = rows.Length > MaxItems;
        if (truncated) rows = rows[..MaxItems];
        if (rows.Length == 0) return new([], truncated);

        var mediaIds = rows.Where(x => x.Session.MediaItemId != null).Select(x => x.Session.MediaItemId!.Value).Distinct().ToArray();
        var downloadFileIds = rows.Where(x => x.Session.DownloadFileId != null).Select(x => x.Session.DownloadFileId!.Value).Distinct().ToArray();
        var media = await db.MediaItems.AsNoTracking().Where(x => mediaIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        var metadata = await db.MediaMetadata.AsNoTracking().Where(x => mediaIds.Contains(x.MediaItemId))
            .ToDictionaryAsync(x => x.MediaItemId, ct);
        var files = await db.DownloadFiles.AsNoTracking().Where(x => downloadFileIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        var jobIds = files.Values.Select(x => x.TorrentJobId).Distinct().ToArray();
        var jobs = await db.TorrentJobs.AsNoTracking().Where(x => jobIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        var requestIds = await db.DownloadRequests.AsNoTracking().Where(x => x.TorrentJobId != null && jobIds.Contains(x.TorrentJobId.Value))
            .Select(x => new { x.Id, JobId = x.TorrentJobId!.Value }).ToArrayAsync(ct);
        var operationTargets = requestIds.Select(x => x.Id).ToArray();
        var pendingTargets = await db.Operations.AsNoTracking()
            .Where(x => x.InvalidatesPlayback && (x.State == "pending" || x.State == "running")
                        && operationTargets.Contains(x.TargetId))
            .Select(x => x.TargetId).Distinct().ToArrayAsync(ct);
        var pendingJobs = requestIds.Where(x => pendingTargets.Contains(x.Id)).Select(x => x.JobId).ToHashSet();

        var result = new List<PlaybackStateHint>(Math.Min(rows.Length, MaxItems));
        foreach (var row in rows)
        {
            ct.ThrowIfCancellationRequested();
            var session = row.Session;
            if (PlaybackExpiry.Expired(session, now)) continue;
            var sessionActor = new Actor(row.User.Id, session.AuthSessionId, row.User.Role);
            Guid libraryId;
            if (session.MediaItemId is Guid mediaId && media.TryGetValue(mediaId, out var item))
                libraryId = item.LibraryId;
            else if (session.DownloadFileId is Guid fileId && files.TryGetValue(fileId, out var resolvedFile)
                     && jobs.TryGetValue(resolvedFile.TorrentJobId, out var resolvedJob))
                libraryId = resolvedJob.LibraryId;
            else continue;

            try { await permissions.RequireLibraryAsync(sessionActor, libraryId, "read", ct); }
            catch (ApiException) { continue; }

            if (session.MediaItemId is Guid targetMediaId && media.TryGetValue(targetMediaId, out item))
            {
                if (item.Lifecycle != "available" || item.Kind != "video" || item.SizeBytes is not > 0
                    || session.TargetGeneration != MediaAccess.Generation(item)) continue;
                var total = item.SizeBytes.Value;
                // Completed imports are safe only after the current probe generation
                // is ready; an incomplete download is handled via DownloadFile below.
                var state = metadata.TryGetValue(item.Id, out var probe)
                    && probe.ProbeStatus == "ready" && probe.ContentGeneration == item.Version
                    ? "complete" : "metadataPending";
                result.Add(new(session.Id, state, session.TargetGeneration,
                    state == "complete" ? total : 0, total));
                continue;
            }

            if (session.DownloadFileId is Guid targetFileId && files.TryGetValue(targetFileId, out var targetFile)
                && jobs.TryGetValue(targetFile.TorrentJobId, out var targetJob))
            {
                result.Add(DownloadHint(session, targetFile, targetJob, pendingJobs.Contains(targetJob.Id), availability, now));
            }
        }

        return new(result.ToArray(), truncated);
    }

    private static PlaybackStateHint DownloadHint(
        Briani.Api.Modules.Media.PlaybackSession session,
        DownloadFile file,
        TorrentJob job,
        bool pending,
        TorrentAvailability availability,
        DateTimeOffset now)
    {
        var total = file.SizeBytes;
        if (file.Padding || !file.Wanted || file.FilePriority <= 0 || file.Kind != "video"
            || total <= 0 || job.RetiredAt is not null || job.MetadataStatus != "ready"
            || job.DesiredState == "removing" || job.PieceLength <= 0 || job.PieceCount <= 0 || pending)
            return new(session.Id, "unavailable", session.TargetGeneration, 0, total > 0 ? total : null);

        var snapshot = availability.Peek(job.Id);
        if (snapshot is null || !snapshot.Healthy || snapshot.Generation != session.TargetGeneration
            || snapshot.PieceCount != job.PieceCount || now - snapshot.ObservedAt < TimeSpan.Zero
            || now - snapshot.ObservedAt > TimeSpan.FromSeconds(2))
            return new(session.Id, "unavailable", session.TargetGeneration, 0, total);

        try
        {
            var end = checked(file.TorrentOffset + total);
            var first = checked((int)(file.TorrentOffset / job.PieceLength));
            var last = checked((int)((end - 1) / job.PieceLength));
            if (file.TorrentOffset < 0 || end > checked((long)job.PieceCount * job.PieceLength)
                || first != file.PieceFirst || last != file.PieceLast || first < 0 || last >= snapshot.PieceCount)
                return new(session.Id, "unavailable", session.TargetGeneration, 0, total);

            long contiguous = 0;
            for (var piece = first; piece <= last; piece++)
            {
                if (!snapshot.Contains(piece)) break;
                var pieceStart = checked((long)piece * job.PieceLength);
                var pieceEnd = checked(pieceStart + job.PieceLength);
                var availableStart = Math.Max(file.TorrentOffset, pieceStart);
                var availableEnd = Math.Min(end, pieceEnd);
                contiguous = checked(contiguous + Math.Max(0, availableEnd - availableStart));
            }
            var state = file.Completed && contiguous == total ? "complete"
                : contiguous >= Math.Min(total, StartupPrefixBytes) ? "ready" : "waitingForData";
            return new(session.Id, state, session.TargetGeneration, contiguous, total);
        }
        catch (OverflowException)
        {
            return new(session.Id, "unavailable", session.TargetGeneration, 0, total);
        }
    }
}
