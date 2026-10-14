using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;

namespace Briani.StreamingTests;

public sealed class ProgressiveReaderOracleTests
{
    [Fact]
    public async Task Only_state_two_is_readable_and_sparse_allocated_length_never_authorizes_holes()
    {
        using var fixture = new SparseFixture(32, pieceLength: 8);
        fixture.Write(0, [11, 12, 13, 14, 15, 16, 17, 18]);
        var availability = new SharedAvailability();
        availability.Publish(fixture.Snapshot([1, 0, 0, 0]));
        var reader = fixture.Reader(availability);

        var firstBytes = new byte[4];
        var waiting = reader.ReadAsync(fixture.Stream, 0, firstBytes, TimeSpan.FromSeconds(3), CancellationToken.None).AsTask();
        await Task.Delay(40);
        Assert.False(waiting.IsCompleted);
        availability.Publish(fixture.Snapshot([2, 0, 0, 0]));
        Assert.Equal(4, await waiting.WaitAsync(TimeSpan.FromSeconds(1)));
        Assert.Equal(new byte[] { 11, 12, 13, 14 }, firstBytes);

        var hole = await Assert.ThrowsAsync<DataWaitException>(() => reader.ReadAsync(
            fixture.Stream, 16, new byte[4], TimeSpan.FromMilliseconds(80), CancellationToken.None).AsTask());
        Assert.Equal("waiting_for_data", hole.Message);
    }

    [Fact]
    public async Task Stale_snapshot_is_not_served_until_a_fresh_observation_arrives()
    {
        using var fixture = new SparseFixture(16, pieceLength: 8);
        fixture.Write(0, [21, 22, 23, 24]);
        var availability = new SharedAvailability();
        availability.Publish(fixture.Snapshot([2, 0], observedAt: DateTimeOffset.UtcNow.AddSeconds(-3)));
        var bytes = new byte[4];
        var read = fixture.Reader(availability).ReadAsync(fixture.Stream, 0, bytes, TimeSpan.FromSeconds(2), CancellationToken.None).AsTask();
        await Task.Delay(40);
        Assert.False(read.IsCompleted);
        availability.Publish(fixture.Snapshot([2, 0]));
        Assert.Equal(4, await read.WaitAsync(TimeSpan.FromSeconds(1)));
        Assert.Equal(new byte[] { 21, 22, 23, 24 }, bytes);
    }

    [Fact]
    public async Task Missing_middle_piece_resumes_with_exact_oracle_bytes_after_publication()
    {
        using var fixture = new SparseFixture(24, pieceLength: 8);
        var expected = Enumerable.Range(0, 24).Select(i => (byte)(i * 7 + 3)).ToArray();
        fixture.Write(0, expected);
        var availability = new SharedAvailability();
        availability.Publish(fixture.Snapshot([2, 0, 2]));
        var reader = fixture.Reader(availability);

        var first = new byte[8];
        Assert.Equal(8, await reader.ReadAsync(fixture.Stream, 0, first, TimeSpan.FromSeconds(1), CancellationToken.None));
        Assert.Equal(expected[..8], first);
        var middleBytes = new byte[8];
        var middle = reader.ReadAsync(fixture.Stream, 8, middleBytes, TimeSpan.FromSeconds(2), CancellationToken.None).AsTask();
        await Task.Delay(40);
        Assert.False(middle.IsCompleted);
        availability.Publish(fixture.Snapshot([2, 2, 2]));
        Assert.Equal(8, await middle.WaitAsync(TimeSpan.FromSeconds(1)));
        Assert.Equal(expected[8..16], middleBytes);
        var last = new byte[8];
        Assert.Equal(8, await reader.ReadAsync(fixture.Stream, 16, last, TimeSpan.FromSeconds(1), CancellationToken.None));
        Assert.Equal(expected, first.Concat(middleBytes).Concat(last).ToArray());
    }

    [Fact]
    public async Task Generation_change_while_waiting_fails_without_reading_new_generation_bytes()
    {
        using var fixture = new SparseFixture(16, pieceLength: 8);
        fixture.Write(0, Enumerable.Repeat((byte)0xA5, 16).ToArray());
        var availability = new SharedAvailability();
        availability.Publish(fixture.Snapshot([0, 0]));
        var read = fixture.Reader(availability).ReadAsync(fixture.Stream, 0, new byte[8], TimeSpan.FromSeconds(2), CancellationToken.None).AsTask();
        await Task.Delay(40);
        availability.Publish(fixture.Snapshot([2, 2], generation: "generation-b"));
        await Assert.ThrowsAsync<GenerationException>(() => read);
    }

    [Fact]
    public async Task Caller_cancellation_interrupts_wait_promptly_and_never_becomes_a_data_timeout()
    {
        using var fixture = new SparseFixture(8, pieceLength: 8);
        var availability = new SharedAvailability();
        availability.Publish(fixture.Snapshot([0]));
        using var cancel = new CancellationTokenSource();
        var read = fixture.Reader(availability).ReadAsync(fixture.Stream, 0, new byte[4], TimeSpan.FromSeconds(20), cancel.Token).AsTask();
        cancel.CancelAfter(50);
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => read.WaitAsync(TimeSpan.FromMilliseconds(500)));
    }

    [Fact]
    public async Task Short_descriptor_is_an_error_even_when_piece_bitmap_claims_readable()
    {
        using var fixture = new SparseFixture(4, pieceLength: 8);
        var layout = new ProgressiveLayout("generation-a", 8, 1, 0, 8, ContainedDirectory.Inspect(fixture.Stream).Key);
        var availability = new SharedAvailability();
        availability.Publish(fixture.Snapshot([2]));
        var error = await Assert.ThrowsAsync<IOException>(() => new ProgressiveReader(layout, availability, TimeProvider.System)
            .ReadAsync(fixture.Stream, 0, new byte[8], TimeSpan.FromSeconds(1), CancellationToken.None).AsTask());
        Assert.Equal("short_disk_read", error.Message);
    }

    [Fact]
    public async Task Torrent_global_offset_above_four_gibibytes_maps_to_the_correct_piece()
    {
        const long start = 4L * 1024 * 1024 * 1024 + 37;
        using var fixture = new SparseFixture(16, pieceLength: 1024 * 1024);
        byte[] expected = [0xDE, 0xAD, 0xBE, 0xEF, 0x42];
        fixture.Write(0, expected);
        var layout = fixture.Layout(fileOffset: start, fileLength: 16);
        var availability = new SharedAvailability();
        var absolutePiece = checked((int)((layout.FileOffset + 3) / layout.PieceLength));
        var states = new byte[absolutePiece + 1];
        states[absolutePiece] = 2;
        availability.Publish(fixture.Snapshot(states));
        var result = new byte[expected.Length];
        Assert.Equal(expected.Length, await new ProgressiveReader(layout, availability, TimeProvider.System)
            .ReadAsync(fixture.Stream, 0, result, TimeSpan.FromSeconds(1), CancellationToken.None));
        Assert.Equal(expected, result);
    }

    [Fact]
    public async Task Descriptor_file_offset_above_four_gibibytes_is_read_without_truncation()
    {
        const long offset = 4L * 1024 * 1024 * 1024 + 37;
        using var fixture = new SparseFixture(offset + 16, pieceLength: 1024 * 1024);
        byte[] expected = [0x31, 0x42, 0x53, 0x64, 0x75];
        fixture.Write(offset, expected);
        var layout = fixture.Layout(fileLength: fixture.Stream.Length);
        var availability = new SharedAvailability();
        var piece = checked((int)(offset / layout.PieceLength));
        var states = new byte[layout.PieceCount];
        states[piece] = 2;
        availability.Publish(fixture.Snapshot(states));
        var result = new byte[expected.Length];

        Assert.Equal(expected.Length, await new ProgressiveReader(layout, availability, TimeProvider.System)
            .ReadAsync(fixture.Stream, offset, result, TimeSpan.FromSeconds(1), CancellationToken.None));
        Assert.Equal(expected, result);
    }

    [Fact]
    public void Playback_ticket_activation_idle_and_hard_expiry_allow_long_movie_range_reopens()
    {
        var clock = new TestClock(new DateTimeOffset(2026, 10, 12, 0, 0, 0, TimeSpan.Zero));
        var session = new PlaybackSession
        {
            CreatedAt = clock.GetUtcNow(),
            FirstUseDeadline = clock.GetUtcNow().AddMinutes(10),
            AbsoluteExpiresAt = clock.GetUtcNow().AddHours(24)
        };

        clock.Advance(TimeSpan.FromMinutes(9));
        Assert.False(PlaybackExpiry.Expired(session, clock.GetUtcNow()));
        session.ActivatedAt = clock.GetUtcNow();
        session.LastActivityAt = clock.GetUtcNow();

        // Simulate a later Range reopen during a long movie. Each accepted request refreshes activity.
        for (var interval = 1; interval <= 48; interval++)
        {
            clock.Advance(TimeSpan.FromMinutes(15));
            Assert.False(PlaybackExpiry.Expired(session, clock.GetUtcNow()));
            session.LastActivityAt = clock.GetUtcNow();
        }

        clock.Advance(TimeSpan.FromMinutes(30));
        Assert.True(PlaybackExpiry.Expired(session, clock.GetUtcNow()));
        // A URL whose idle window elapsed cannot be revived by a later attempted reopen.
        Assert.True(PlaybackExpiry.Expired(session, clock.GetUtcNow()));
        var activeAtHardBound = new PlaybackSession
        {
            ActivatedAt = session.ActivatedAt,
            LastActivityAt = session.AbsoluteExpiresAt.AddMinutes(-1),
            FirstUseDeadline = session.FirstUseDeadline,
            AbsoluteExpiresAt = session.AbsoluteExpiresAt
        };
        clock.Set(activeAtHardBound.AbsoluteExpiresAt.AddMinutes(-1));
        Assert.False(PlaybackExpiry.Expired(activeAtHardBound, clock.GetUtcNow()));
        clock.Set(session.AbsoluteExpiresAt);
        Assert.True(PlaybackExpiry.Expired(activeAtHardBound, clock.GetUtcNow()));
    }

    [Fact]
    public void Unactivated_ticket_expires_at_ten_minute_deadline_and_activated_session_requires_activity()
    {
        var clock = new TestClock(new DateTimeOffset(2026, 10, 12, 0, 0, 0, TimeSpan.Zero));
        var session = new PlaybackSession
        {
            FirstUseDeadline = clock.GetUtcNow().AddMinutes(10),
            AbsoluteExpiresAt = clock.GetUtcNow().AddHours(24)
        };
        clock.Advance(TimeSpan.FromMinutes(10));
        Assert.True(PlaybackExpiry.Expired(session, clock.GetUtcNow()));

        session.ActivatedAt = clock.GetUtcNow();
        Assert.True(PlaybackExpiry.Expired(session, clock.GetUtcNow()));
        session.LastActivityAt = clock.GetUtcNow();
        Assert.False(PlaybackExpiry.Expired(session, clock.GetUtcNow()));
        clock.Advance(TimeSpan.FromMinutes(30));
        Assert.True(PlaybackExpiry.Expired(session, clock.GetUtcNow()));
    }

    private sealed class SparseFixture : IDisposable
    {
        private readonly string path = Path.Combine(Path.GetTempPath(), $"briani-stream-{Guid.NewGuid():N}.bin");
        private readonly long pieceLength;
        public SparseFixture(long length, long pieceLength)
        {
            this.pieceLength = pieceLength;
            Stream = new FileStream(path, FileMode.CreateNew, FileAccess.ReadWrite, FileShare.ReadWrite, 4096, FileOptions.RandomAccess);
            Stream.SetLength(length);
        }
        public FileStream Stream { get; }
        public void Write(long offset, byte[] bytes) => RandomAccess.Write(Stream.SafeFileHandle, bytes, offset);
        public ProgressiveLayout Layout(long? fileOffset = null, long? fileLength = null)
        {
            var start = fileOffset ?? 0;
            var length = fileLength ?? Stream.Length;
            var pieces = checked((int)((start + length + pieceLength - 1) / pieceLength));
            return new("generation-a", pieceLength, pieces, start, length, ContainedDirectory.Inspect(Stream).Key);
        }
        public ProgressiveReader Reader(IAvailabilitySource source) => new(Layout(), source, TimeProvider.System);
        public AvailabilitySnapshot Snapshot(byte[] states, string generation = "generation-a", DateTimeOffset? observedAt = null) =>
            new(generation, observedAt ?? DateTimeOffset.UtcNow, true, states);
        public void Dispose() { Stream.Dispose(); File.Delete(path); }
    }

    private sealed class TestClock(DateTimeOffset now) : TimeProvider
    {
        private DateTimeOffset current = now;
        public override DateTimeOffset GetUtcNow() => current;
        public void Advance(TimeSpan amount) => current = current.Add(amount);
        public void Set(DateTimeOffset value) => current = value;
    }
}
