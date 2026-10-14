using System.Collections;
using Briani.PlaybackProof;

var checks = 0;
void Check(bool condition, string scenario) { checks++; if (!condition) throw new Exception(scenario); }
void Range(string? header, long length, long start, long end, bool partial)
{ Check(ByteRange.Parse(header, length) == new ByteRange(start, end, partial), "range " + header); }
Range(null, 100, 0, 99, false); Range("bytes=4-7", 100, 4, 7, true);
Range("bytes=4-", 100, 4, 99, true); Range("bytes=-7", 100, 93, 99, true);
Range("bytes=-700", 100, 0, 99, true); Range("bytes=0-999", 100, 0, 99, true);
Range("bytes=0-1,5-6", 100, 0, 99, false); Range("bytes=4294967300-", 5000000000, 4294967300, 4999999999, true);
foreach (var bad in new[] { "bytes=100-", "bytes=9-4", "bytes=-0", "bytes=9223372036854775808-", "bytes=0-+4", "bytes=1-2-3", "items=1-2" })
{ try { ByteRange.Parse(bad, 100); throw new Exception("accepted malformed range"); } catch (RangeException) { checks++; } }
var random = new Random(12345);
for (var i = 0; i < 10000; i++)
{
    var origin = random.NextInt64(1, 8L << 30); var length = random.NextInt64(1, 10000000);
    var f = new FileLayout("target", 1, "file.mp4", length, origin);
    var layout = new TorrentLayout(1, 262144, checked((int)((origin + length + 262143) / 262144)), [f]);
    var offset = random.NextInt64(length); var requested = random.Next(1, 262145);
    var (piece, count) = layout.Slice(f, offset, requested);
    Check(piece == (origin + offset) / 262144 && count <= requested && count > 0 &&
        offset + count <= length && (origin + offset + count - 1) / 262144 == piece, "slice arithmetic");
}
foreach (var path in new[] { "../escape", "/escape", "a/../b", "a//b", "a\\b", ".briani/private", "a:b" })
{ try { TorrentLayout.ValidatePath(path); throw new Exception("accepted path"); } catch (ArgumentException) { checks++; } }
var root = Path.Combine(Path.GetTempPath(), "briani-reader-" + Guid.NewGuid());
Directory.CreateDirectory(root);
try
{
    var bytes = Enumerable.Range(0, 65536).Select(i => (byte)(i % 251 + 1)).ToArray();
    File.WriteAllBytes(Path.Combine(root, "file.mp4"), bytes);
    using var stream = ContainedFile.Open(root, "file.mp4", bytes.Length);
    var f = new FileLayout("target", 0, "file.mp4", bytes.Length, 0);
    var layout = new TorrentLayout(1, 16384, 4, [f]);
    var availability = new SharedAvailability();
    var reader = new ProgressiveReader(layout, f, availability, TimeProvider.System);
    var buffer = new byte[32768];
    void Publish(long generation, params bool[] pieces) => availability.Publish(new(generation, DateTimeOffset.UtcNow, true, new BitArray(pieces)));
    Publish(1, true, false, true, true);
    var count = await reader.ReadAsync(stream, 0, buffer, TimeSpan.FromSeconds(1), default);
    Check(count == 16384 && bytes.AsSpan(0, count).SequenceEqual(buffer.AsSpan(0, count)), "exact first piece");
    using var cancel = new CancellationTokenSource();
    var waiting = reader.ReadAsync(stream, 16384, buffer, TimeSpan.FromSeconds(10), cancel.Token).AsTask();
    Check(!waiting.IsCompleted, "must wait for middle gap even with full allocated file");
    cancel.Cancel();
    try { await waiting; throw new Exception("cancel ignored"); } catch (OperationCanceledException) { checks++; }
    var resumed = reader.ReadAsync(stream, 16384, buffer, TimeSpan.FromSeconds(10), default).AsTask();
    Publish(1, true, true, true, true);
    count = await resumed;
    Check(count == 16384 && bytes.AsSpan(16384, count).SequenceEqual(buffer.AsSpan(0, count)), "gap resumes exact bytes");
    Publish(2, true, true, true, true);
    try { await reader.ReadAsync(stream, 0, buffer, TimeSpan.FromSeconds(1), default); throw new Exception("stale generation accepted"); }
    catch (GenerationException) { checks++; }
    var outside = Path.Combine(root, "link.mp4"); File.CreateSymbolicLink(outside, "/etc/passwd");
    try { using var escaped = ContainedFile.Open(root, "link.mp4", 0); throw new Exception("symlink followed"); }
    catch (IOException) { checks++; }
    var timerClock = new ManualClock();
    var timedAvailability = new SharedAvailability();
    timedAvailability.Publish(new(1, timerClock.GetUtcNow(), true, new BitArray(4)));
    var timedReader = new ProgressiveReader(layout, f, timedAvailability, timerClock);
    var timeout = timedReader.ReadAsync(stream, 0, buffer, TimeSpan.FromSeconds(60), default).AsTask();
    timerClock.Advance(TimeSpan.FromSeconds(60));
    try { await timeout; throw new Exception("first data deadline ignored"); } catch (DataWaitException) { checks++; }
    timedAvailability.Publish(new(1, timerClock.GetUtcNow(), true, new BitArray(4)));
    var idle = timedReader.ReadAsync(stream, 0, buffer, TimeSpan.FromSeconds(120), default).AsTask();
    timerClock.Advance(TimeSpan.FromSeconds(120));
    try { await idle; throw new Exception("midstream deadline ignored"); } catch (DataWaitException) { checks++; }
    var binding = ContainedFile.Identity(stream);
    File.Move(Path.Combine(root, "file.mp4"), Path.Combine(root, "original.mp4"));
    File.WriteAllBytes(Path.Combine(root, "file.mp4"), bytes);
    try { using var replacement = ContainedFile.Open(root, "file.mp4", bytes.Length, binding); throw new Exception("same-length inode replacement accepted"); }
    catch (IOException) { checks++; }
    // A declared available piece with a short backing file must fail, never pad or return early EOF.
    File.WriteAllBytes(Path.Combine(root, "short.mp4"), [1]);
    using var shortStream = new FileStream(Path.Combine(root, "short.mp4"), FileMode.Open, FileAccess.Read);
    Publish(1, true, true, true, true);
    try { await reader.ReadAsync(shortStream, 0, buffer, TimeSpan.FromSeconds(1), default); throw new Exception("short read accepted"); }
    catch (IOException) { checks++; }
}
finally { Directory.Delete(root, true); }
var clock = new ManualClock();
var ticket = new TicketWindow("a-scoped-test-capability-with-enough-bytes", "one-file", 1, clock);
Check(ticket.Authorize("a-scoped-test-capability-with-enough-bytes", "one-file", 1), "ticket initial activation");
for (var i = 0; i < 8; i++)
{ clock.Advance(TimeSpan.FromMinutes(15)); Check(ticket.Authorize("a-scoped-test-capability-with-enough-bytes", "one-file", 1), "ticket later movie range"); }
Check(!ticket.Authorize("a-scoped-test-capability-with-enough-bytes", "other-file", 1), "ticket cannot grant a second file");
ticket.Revoke(); Check(!ticket.Authorize("a-scoped-test-capability-with-enough-bytes", "one-file", 1), "revoked ticket");
Console.WriteLine($"PASS: {checks} arithmetic, range, containment, availability, cancellation, ticket and exact-read assertions (fake source; not real engine evidence)");

public sealed class ManualClock : TimeProvider
{
    private DateTimeOffset now = new(2026, 10, 12, 0, 0, 0, TimeSpan.Zero);
    public override DateTimeOffset GetUtcNow() => now;
    private readonly List<ManualTimer> timers = [];
    public override ITimer CreateTimer(TimerCallback callback, object? state, TimeSpan dueTime, TimeSpan period)
    {
        var timer = new ManualTimer(this, callback, state, dueTime, period);
        timers.Add(timer); return timer;
    }
    public void Advance(TimeSpan amount)
    {
        now += amount;
        foreach (var timer in timers.ToArray()) timer.Tick();
    }
    private sealed class ManualTimer(ManualClock clock, TimerCallback callback, object? state, TimeSpan due, TimeSpan period) : ITimer
    {
        private DateTimeOffset? next = due == Timeout.InfiniteTimeSpan ? null : clock.GetUtcNow() + due;
        private bool disposed;
        public bool Change(TimeSpan dueTime, TimeSpan repeat)
        {
            if (disposed) return false;
            next = dueTime == Timeout.InfiniteTimeSpan ? null : clock.GetUtcNow() + dueTime;
            period = repeat; return true;
        }
        public void Tick()
        {
            if (disposed || next is null || next > clock.GetUtcNow()) return;
            next = period == Timeout.InfiniteTimeSpan ? null : clock.GetUtcNow() + period;
            callback(state);
        }
        public void Dispose() { disposed = true; }
        public ValueTask DisposeAsync() { Dispose(); return ValueTask.CompletedTask; }
    }
}
