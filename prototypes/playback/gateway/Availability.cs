using System.Collections;

namespace Briani.PlaybackProof;

public sealed class AvailabilitySnapshot(long generation, DateTimeOffset observedAt,
    bool healthy, BitArray readable)
{
    public long Generation { get; } = generation;
    public DateTimeOffset ObservedAt { get; } = observedAt;
    public bool Healthy { get; } = healthy;
    private readonly BitArray bits = new(readable);
    public bool Contains(int piece) => piece >= 0 && piece < bits.Length && bits[piece];
}

public interface IAvailabilitySource
{
    AvailabilitySnapshot? Current { get; }
    Task WaitForChangeAsync(AvailabilitySnapshot? previous, CancellationToken cancellation);
}

public sealed class SharedAvailability : IAvailabilitySource
{
    private readonly object gate = new();
    private AvailabilitySnapshot? current;
    private TaskCompletionSource changed = NewSignal();
    private static TaskCompletionSource NewSignal() => new(TaskCreationOptions.RunContinuationsAsynchronously);
    public AvailabilitySnapshot? Current { get { lock (gate) return current; } }
    public void Publish(AvailabilitySnapshot snapshot)
    {
        TaskCompletionSource old;
        lock (gate)
        {
            if (current is not null && snapshot.Generation < current.Generation) return;
            current = snapshot; old = changed; changed = NewSignal();
        }
        old.TrySetResult();
    }
    public long Invalidate()
    {
        TaskCompletionSource old;
        long next;
        lock (gate)
        {
            next = (current?.Generation ?? 1) + 1;
            current = new(next, DateTimeOffset.UtcNow, false, new BitArray(0));
            old = changed; changed = NewSignal();
        }
        old.TrySetResult();
        return next;
    }
    public Task WaitForChangeAsync(AvailabilitySnapshot? previous, CancellationToken cancellation)
    {
        lock (gate) return !ReferenceEquals(previous, current) ? Task.CompletedTask : changed.Task.WaitAsync(cancellation);
    }
}

public sealed class GenerationException() : IOException("generation_changed");
public sealed class DataWaitException() : IOException("waiting_for_data");

public sealed class ProgressiveReader(TorrentLayout layout, FileLayout file,
    IAvailabilitySource availability, TimeProvider clock)
{
    public async ValueTask<int> ReadAsync(FileStream stream, long offset, Memory<byte> buffer,
        TimeSpan idleTimeout, CancellationToken cancellation)
    {
        var (piece, count) = layout.Slice(file, offset, buffer.Length);
        using var deadline = new CancellationTokenSource(idleTimeout, clock);
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellation, deadline.Token);
        while (true)
        {
            cancellation.ThrowIfCancellationRequested();
            var snapshot = availability.Current;
            if (snapshot is not null && snapshot.Generation != layout.Generation) throw new GenerationException();
            if (snapshot is not null && snapshot.Healthy &&
                clock.GetUtcNow() - snapshot.ObservedAt <= TimeSpan.FromSeconds(2) && snapshot.Contains(piece))
            {
                var got = 0;
                while (got < count)
                {
                    var n = await RandomAccess.ReadAsync(stream.SafeFileHandle, buffer.Slice(got, count - got),
                        checked(offset + got), cancellation);
                    if (n == 0) throw new IOException("short_disk_read");
                    got += n;
                }
                var after = availability.Current;
                if (after is null || after.Generation != layout.Generation) throw new GenerationException();
                if (!after.Healthy || clock.GetUtcNow() - after.ObservedAt > TimeSpan.FromSeconds(2) || !after.Contains(piece))
                    throw new IOException("availability_invalidated");
                return got;
            }
            try { await availability.WaitForChangeAsync(snapshot, linked.Token); }
            catch (OperationCanceledException) when (!cancellation.IsCancellationRequested) { throw new DataWaitException(); }
        }
    }
}
