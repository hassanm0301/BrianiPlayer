namespace Briani.Api.Modules.Downloads;
// Fixed-size locks bound memory and serialize publication of a job intent with its upstream effects.
public sealed class DownloadJobLocks
{
    private readonly SemaphoreSlim[] locks=Enumerable.Range(0,64).Select(_=>new SemaphoreSlim(1,1)).ToArray();
    public async Task<IDisposable> EnterAsync(Guid jobId,CancellationToken ct=default)
    {var semaphore=locks[(jobId.GetHashCode()&int.MaxValue)%locks.Length];await semaphore.WaitAsync(ct);return new Lease(semaphore);}
    private sealed class Lease(SemaphoreSlim semaphore):IDisposable{public void Dispose()=>semaphore.Release();}
}
