using System.Buffers.Binary;
using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Media.Processing;
using Briani.Api.Modules.Playback;
using Microsoft.EntityFrameworkCore;
namespace Briani.DownloadTests;

/// Findings from the 2026-10-16 live check (docs/evidence/live-pi-2026-10-16.md):
/// MP4 eligibility, first/last-piece re-assertion, metadata detection, sidecars.
public sealed class ProgressiveReadinessTests
{
    private const int PieceSize = 16 * 1024;
    private const int Pieces = 1280;
    private const long Bytes = (long)Pieces * PieceSize;
    private const int MoovBytes = 4096;

    private static byte[] Box(string type, long size, int headerBytes = 8)
    {
        var header = new byte[headerBytes];
        BinaryPrimitives.WriteUInt32BigEndian(header, headerBytes == 16 ? 1u : (uint)size);
        Encoding.ASCII.GetBytes(type).CopyTo(header, 4);
        if (headerBytes == 16) BinaryPrimitives.WriteUInt64BigEndian(header.AsSpan(8), (ulong)size);
        return header;
    }

    /// ftyp, then mdat, then moov at the very end, like Sintel.mp4.
    private static Dictionary<long, byte[]> MoovAtEnd(long length) => new()
    {
        [0] = Box("ftyp", 32), [32] = Box("mdat", length - 32 - MoovBytes), [length - MoovBytes] = Box("moov", MoovBytes),
    };

    private static Mp4IndexResult Locate(Dictionary<long, byte[]> headers, long length, Func<long, long, bool> available) =>
        Mp4Index.Locate(length, available, (offset, buffer) =>
        {
            buffer.Span.Clear();
            foreach (var (at, bytes) in headers)
                if (offset >= at && offset < at + bytes.Length) bytes.AsSpan((int)(offset - at)).CopyTo(buffer.Span);
            return true;
        });

    [Fact]
    public void Mp4_index_waits_for_a_trailing_moov_and_locates_it_once_verified()
    {
        var headers = MoovAtEnd(Bytes);
        var headOnly = Locate(headers, Bytes, (offset, length) => offset + length <= 1024L * PieceSize);
        Assert.Equal(Mp4IndexStatus.Waiting, headOnly.Status);
        var all = Locate(headers, Bytes, (_, _) => true);
        Assert.Equal(new Mp4IndexResult(Mp4IndexStatus.Located, Bytes - MoovBytes, MoovBytes), all);
    }

    [Fact]
    public void Mp4_index_handles_faststart_large_boxes_and_rejects_non_mp4_bytes()
    {
        var faststart = new Dictionary<long, byte[]> { [0] = Box("ftyp", 24), [24] = Box("moov", 2000), [2024] = Box("mdat", Bytes - 2024, 16) };
        Assert.Equal(new Mp4IndexResult(Mp4IndexStatus.Located, 24, 2000), Locate(faststart, Bytes, (o, l) => o + l <= 4096));
        var large = new Dictionary<long, byte[]> { [0] = Box("ftyp", 24), [24] = Box("mdat", Bytes - 24 - MoovBytes, 16), [Bytes - MoovBytes] = Box("moov", MoovBytes) };
        Assert.Equal(Mp4IndexStatus.Located, Locate(large, Bytes, (_, _) => true).Status);
        var random = new Dictionary<long, byte[]> { [0] = Enumerable.Range(0, 16).Select(i => (byte)(i % 251)).ToArray() };
        Assert.Equal(Mp4IndexStatus.NotApplicable, Locate(random, Bytes, (_, _) => true).Status);
        var noMoov = new Dictionary<long, byte[]> { [0] = Box("ftyp", 24), [24] = Box("mdat", Bytes - 24) };
        Assert.Equal(Mp4IndexStatus.NotApplicable, Locate(noMoov, Bytes, (_, _) => true).Status);
        Assert.True(Mp4Index.Applies("Sintel.MP4"));
        Assert.False(Mp4Index.Applies("Tears of Steel.webm"));
    }

    [Theory]
    [InlineData("Sintel.en.srt", "en")]
    [InlineData("Tears of Steel.no.srt", "no")]
    [InlineData("Film.2012.eng.forced.srt", "eng")]
    [InlineData("Film.pt-BR.srt", "pt-BR")]
    [InlineData("Film.pt_br.sdh.vtt", "pt-BR")]
    [InlineData("Film.srt", null)]
    [InlineData("en.srt", null)]
    [InlineData("Film.2012.srt", null)]
    [InlineData("Film.xx.srt", null)]
    [InlineData("Film.part.srt", null)]
    public void Subtitle_language_comes_only_from_an_iso_639_suffix(string name, string? expected) =>
        Assert.Equal(expected, SubtitleLanguage.FromFileName(name));

    [Fact]
    public void Assist_span_matches_qbittorrent_first_last_piece_formula()
    {
        // TorrentImpl::applyFirstLastPiecePriority: ceil(1% of the file / piece length) at each end.
        var file = new DownloadFile { SizeBytes = 48L * 1024 * 1024 + 12345, PieceFirst = 0, PieceLast = 384 };
        Assert.Equal([0, 384, 1, 383, 2, 382, 3, 381], DownloadLayout.AssistPieces(file, 128 * 1024).ToArray());
        Assert.Empty(DownloadLayout.AssistPieces(new DownloadFile { SizeBytes = 0 }, 128 * 1024));
    }

    [Theory]
    [InlineData("magnet:?xt=urn:btih:209c8226b299b308beaf2b9cd3fb49212dbd13ec&dn=Tears+of+Steel", "Tears of Steel")]
    [InlineData("magnet:?xt=urn:btih:209c8226b299b308beaf2b9cd3fb49212dbd13ec&dn=%20%20", null)]
    [InlineData("magnet:?xt=urn:btih:209c8226b299b308beaf2b9cd3fb49212dbd13ec", null)]
    public void Magnet_display_name_is_kept_as_a_provisional_name(string magnet, string? expected) =>
        Assert.Equal(expected, Briani.Api.Modules.Discovery.Sources.SourceValidation.Magnet(magnet).DisplayName);

    [Theory]
    [InlineData(-1L, null)]
    [InlineData(0L, 0L)]
    [InlineData(448L, 448L)]
    [InlineData(8639999L, 8639999L)]
    [InlineData(8640000L, null)]
    public void Unbounded_engine_eta_is_reported_as_unknown(long eta, long? expected) =>
        Assert.Equal(expected, QBitTorrentClient.Eta(eta));

    [Fact]
    public void Video_thumbnail_is_taken_a_tenth_in_and_capped()
    {
        Assert.Equal(TimeSpan.Zero, ProbeService.ThumbnailPosition(null));
        Assert.Equal(TimeSpan.FromMilliseconds(88806), ProbeService.ThumbnailPosition(888064));
        Assert.Equal(TimeSpan.FromMinutes(10), ProbeService.ThumbnailPosition((long)TimeSpan.FromHours(3).TotalMilliseconds));
    }

    [Theory]
    [InlineData("queuedDL", false, false)]
    [InlineData("metaDL", false, false)]
    [InlineData("stoppedDL", true, true)]
    [InlineData("queuedDL", null, false)]
    [InlineData("checkingResumeData", null, false)]
    [InlineData("stoppedDL", null, true)]
    public void Fresh_magnets_are_not_treated_as_having_metadata(string state, bool? hasMetadata, bool expected)
    {
        var torrent = new EngineTorrent(new string('a', 40), null, null, "x", "/data", state, 0, 0, 0, 0, 0, 0, 0, true, true, [], null, null, null, 0, hasMetadata);
        Assert.Equal(expected, DownloadWorker.MetadataReceived(torrent));
    }

    /// Stages a 20 MiB fixture.mp4 whose moov follows the media data, with the
    /// given pieces verified, and polls once.
    private static async Task<LifecycleFixture> MoovAtEndDownload(Func<int, bool> verified)
    {
        var f = await LifecycleFixture.Create();
        await f.SeedReadyDownload(f.Admin.User.Id, f.Admin.SessionId);
        var path = Path.Combine(f.LibraryPath, ".briani", "staging", f.Engine.JobId.ToString("N"), "fixture.mp4");
        using (var file = new FileStream(path, FileMode.Open, FileAccess.Write, FileShare.None))
        {
            file.SetLength(Bytes);
            foreach (var (at, bytes) in MoovAtEnd(Bytes)) { file.Position = at; file.Write(bytes); }
        }
        await f.InDb(async db =>
        {
            var job = await db.TorrentJobs.SingleAsync(x => x.Id == f.Engine.JobId); job.PieceCount = Pieces; job.TotalBytes = Bytes; job.SelectedComplete = false;
            var row = await db.DownloadFiles.SingleAsync(x => x.Id == f.Engine.FileId); row.SizeBytes = Bytes; row.PieceLast = Pieces - 1; row.Completed = false;
            row.DownloadedBytes = 0; row.ContiguousBytes = 0; row.PlaybackState = "waitingForData"; row.FileIdentity = null;
            var request = await db.DownloadRequests.SingleAsync(x => x.Id == f.Engine.RequestId); request.SelectedBytes = Bytes;
            return await db.SaveChangesAsync();
        });
        f.Engine.ConfigureFiles(Pieces, new EngineFile(0, "fixture.mp4", Bytes, 0, 7, 0, Pieces - 1));
        f.Engine.CompletePieces = false;
        f.Engine.PieceStatesOverride = Enumerable.Range(0, Pieces).Select(i => (byte)(verified(i) ? 2 : 0)).ToArray();
        f.Engine.RegisterExisting(LifecycleFixture.Hash, Path.GetDirectoryName(path)!);
        await f.Worker.PollOnceAsync();
        return f;
    }

    private static async Task<string> PlaybackState(LifecycleFixture f) =>
        Assert.Single((await f.Client.GetFromJsonAsync<DownloadFileView[]>($"/api/v1/downloads/{f.Engine.RequestId}/files"))!).PlaybackState;

    [Fact]
    public async Task Mp4_with_trailing_index_is_not_eligible_until_the_index_is_verified()
    {
        await using (var headOnly = await MoovAtEndDownload(i => i < 1024))
            Assert.Equal("waitingForData", await PlaybackState(headOnly));
        await using var withTail = await MoovAtEndDownload(i => i < 1024 || i == Pieces - 1);
        Assert.Equal("eligible", await PlaybackState(withTail));
    }

    [Fact]
    public async Task Progressive_session_stays_buffering_until_the_mp4_index_is_verified()
    {
        await using var f = await MoovAtEndDownload(i => i < 1024);
        using var response = await f.Client.PostAsJsonAsync("/api/v1/playback/sessions", new
        {
            target = new { kind = "downloadFile", id = f.Engine.FileId }, mode = "internal", initialPositionMs = 0
        });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("buffering", document.RootElement.GetProperty("state").GetString());
        Assert.Equal(JsonValueKind.Null, document.RootElement.GetProperty("streamUrl").ValueKind);
    }

    [Fact]
    public async Task Worker_reasserts_first_last_priority_until_the_assist_pieces_arrive()
    {
        // 20 MiB at 16 KiB pieces: the assist span is 13 pieces at each end.
        await using var f = await MoovAtEndDownload(i => i < 1024);
        Assert.Equal(1, f.Engine.AssistReasserts);
        await f.Worker.PollOnceAsync();
        Assert.Equal(1, f.Engine.AssistReasserts);
        f.Worker.AssistReassertInterval = TimeSpan.Zero;
        await f.Worker.PollOnceAsync();
        Assert.Equal(2, f.Engine.AssistReasserts);
        f.Engine.PieceStatesOverride = Enumerable.Range(0, Pieces).Select(i => (byte)(i < 1024 || i >= Pieces - 13 ? 2 : 0)).ToArray();
        await f.Worker.PollOnceAsync();
        Assert.Equal(2, f.Engine.AssistReasserts);
    }
}
