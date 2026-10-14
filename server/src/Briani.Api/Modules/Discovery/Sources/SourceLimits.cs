using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Modules.Discovery.Sources;
public sealed class SourceLimits
{
    private readonly SemaphoreSlim resolutions=new(2,2);
    public IDisposable Enter()
    {if(!resolutions.Wait(0))throw new ApiException(429,"source_resolution_limit");return new Lease(resolutions);}
    private sealed class Lease(SemaphoreSlim semaphore):IDisposable{public void Dispose()=>semaphore.Release();}
}
