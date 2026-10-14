using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Infrastructure.Storage;
// Restrict a fresh OS thread, never a reusable pool thread. Existing descriptors do
// not by themselves ensure containment after an external parent-directory move.
internal static class MutationSandbox
{
    [StructLayout(LayoutKind.Sequential)] private struct Ruleset {public ulong Handled;}
    [StructLayout(LayoutKind.Sequential,Pack=1)] private struct PathRule {public ulong Allowed;public int ParentFd;}
    [DllImport("libc",EntryPoint="syscall",SetLastError=true)] private static extern long Version(long n,IntPtr attr,nuint size,uint flags);
    [DllImport("libc",EntryPoint="syscall",SetLastError=true)] private static extern long Create(long n,ref Ruleset attr,nuint size,uint flags);
    [DllImport("libc",EntryPoint="syscall",SetLastError=true)] private static extern long Add(long n,int fd,int ruleType,ref PathRule attr,uint flags);
    [DllImport("libc",EntryPoint="syscall",SetLastError=true)] private static extern long Restrict(long n,int fd,uint flags);
    [DllImport("libc",SetLastError=true)] private static extern int prctl(int option,ulong a,ulong b,ulong c,ulong d);
    private static readonly SemaphoreSlim Slots=new(2,2);
    internal static void Run(SafeFileHandle root,Action operation,SafeFileHandle? scope=null,ulong allowed=4|8|2|16|32|128|256|8192|16384)
    {
        Slots.Wait();Exception? failure=null;
        try
        {
            var thread=new Thread(()=>
            {
                try
                {
                    var abi=Version(444,IntPtr.Zero,0,1);var errata=Version(444,IntPtr.Zero,0,2);if(abi<2 || errata<0 || (errata&4)==0)throw new ApiException(503,"mutation_containment_unavailable");
                    const ulong writes=4|8|2|16|32|64|128|256|512|1024|2048|4096|8192;
                    var handled=writes|(abi>=3?16384UL:0);
                    foreach(var boundary in scope is null?new[]{root}:new[]{root,scope}){
                    var rules=new Ruleset{Handled=handled};var fd=Create(444,ref rules,8,0);
                    if(fd<0)throw new ApiException(503,"mutation_containment_unavailable");
                    using var handle=new SafeFileHandle((IntPtr)fd,true);
                    var rule=new PathRule{Allowed=(allowed|4|8)&handled,ParentFd=boundary.DangerousGetHandle().ToInt32()};
                    if(Add(445,(int)fd,1,ref rule,0)!=0 || prctl(38,1,0,0,0)!=0 || Restrict(446,(int)fd,0)!=0)throw new ApiException(503,"mutation_containment_unavailable");
                    }
                    operation();
                }
                catch(Exception e){failure=e;}
            }) {IsBackground=true,Name="contained-filesystem-operation"};
            thread.Start();thread.Join();if(failure is not null)ExceptionDispatchInfo.Capture(failure).Throw();
        }
        finally{Slots.Release();}
    }
}
