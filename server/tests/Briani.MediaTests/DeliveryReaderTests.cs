using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Playback;

namespace Briani.MediaTests;

public sealed class DeliveryReaderTests
{
    [Fact]
    public void Reader_limits_are_four_per_session_and_sixteen_global()
    {
        var readers = new MediaReaders();
        var session = Guid.NewGuid();
        var leases = Enumerable.Range(0, 4).Select(_ => readers.Acquire(session, Guid.NewGuid(), CancellationToken.None)).ToArray();
        var sessionLimit = Assert.Throws<ApiException>(() => readers.Acquire(session, Guid.NewGuid(), CancellationToken.None));
        Assert.Equal(429, sessionLimit.Status);
        foreach (var lease in leases) lease.Dispose();

        var global = Enumerable.Range(0, 16).Select(_ => readers.Acquire(Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None)).ToArray();
        var globalLimit = Assert.Throws<ApiException>(() => readers.Acquire(Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));
        Assert.Equal(429, globalLimit.Status);
        foreach (var lease in global) lease.Dispose();
    }

    [Fact]
    public void Cancelling_a_session_does_not_cancel_another_session_reading_the_same_media()
    {
        var readers = new MediaReaders();
        var media = Guid.NewGuid();
        using var first = readers.Acquire(Guid.NewGuid(), media, CancellationToken.None);
        using var second = readers.Acquire(Guid.NewGuid(), media, CancellationToken.None);

        readers.CancelSession(first.SessionId);

        Assert.True(first.Token.IsCancellationRequested);
        Assert.False(second.Token.IsCancellationRequested);
        Assert.True(readers.HasReaders(media));
    }
}
