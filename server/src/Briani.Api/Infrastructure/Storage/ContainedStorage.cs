using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using Briani.Api.Modules.Identity;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Infrastructure.Storage;
public sealed record VolumeInfo(long FreeBytes,long TotalBytes,bool Writable,string Identity);
public sealed record StorageDirectory(string RelativePath,string Name,bool Writable,bool AlreadyAssigned=false);
public sealed record ContainedRoot(string RelativePath,string Identity,IReadOnlyList<string> AncestorIdentities);
public sealed record NodeIdentity(uint DeviceMajor,uint DeviceMinor,ulong Inode,ushort Mode,long Length,long MtimeNs=0,ulong MountId=0)
{ public string Key=>$"{DeviceMajor}:{DeviceMinor}:{Inode}"; public bool IsDirectory=>(Mode&0xf000)==0x4000; public bool IsFile=>(Mode&0xf000)==0x8000; }
internal static class LinuxFs
{
    // AArch64 overrides these two asm-generic flags for AArch32 ABI support.
    // Passing x86 O_DIRECTORY on ARM64 requests O_DIRECT and fails on "/".
    internal static (int Directory, int NoFollow) OpenFlags(Architecture architecture) => architecture switch
    {
        Architecture.X64 => (0x10000, 0x20000),
        Architecture.Arm64 => (0x4000, 0x8000),
        _ => throw new PlatformNotSupportedException("Linux amd64/arm64 required"),
    };
    internal static readonly int Directory=OpenFlags(RuntimeInformation.ProcessArchitecture).Directory;
    internal static readonly int NoFollow=OpenFlags(RuntimeInformation.ProcessArchitecture).NoFollow;
    internal const int CloseExec=0x80000, NonBlock=0x800;
    [StructLayout(LayoutKind.Sequential)] internal struct OpenHow { public ulong Flags,Mode,Resolve; }
    [DllImport("libc",EntryPoint="syscall",SetLastError=true)] internal static extern long Access(long number,int fd,string path,int mode,int flags);
    [DllImport("libc",SetLastError=true)] internal static extern int fstatvfs(int fd,IntPtr buffer);
    [DllImport("libc",SetLastError=true)] internal static extern int fchmod(int fd,uint mode);
    [DllImport("libc",SetLastError=true)] internal static extern int open(string path,int flags);
    [DllImport("libc",SetLastError=true)] internal static extern long syscall(long number,int fd,string path,ref OpenHow how,nuint size);
    [DllImport("libc",SetLastError=true)] internal static extern int statx(int fd,string path,int flags,uint mask,IntPtr buffer);
    [DllImport("libc",SetLastError=true)] internal static extern int mkdirat(int fd,string path,uint mode);
    [DllImport("libc",SetLastError=true)] internal static extern int unlinkat(int fd,string path,int flags);
    [DllImport("libc",SetLastError=true)] internal static extern int renameat2(int oldfd,string oldname,int newfd,string newname,uint flags);
    [DllImport("libc",SetLastError=true)] internal static extern int linkat(int oldfd,string oldname,int newfd,string newname,int flags);
    [DllImport("libc",SetLastError=true)] private static extern int fcntl(int fd,int command,int argument);
    // Atomically retain close-on-exec when copying a handle: media subprocesses
    // must not inherit the server's retained directory descriptors.
    internal static int Duplicate(int fd)=>fcntl(fd,1030,0); // F_DUPFD_CLOEXEC
    [DllImport("libc",SetLastError=true)] internal static extern IntPtr fdopendir(int fd);
    [DllImport("libc",SetLastError=true)] internal static extern IntPtr readdir(IntPtr dir);
    [DllImport("libc")] internal static extern int closedir(IntPtr dir);
    internal static SafeFileHandle Resolve(SafeFileHandle root,string path,int flags,ulong mode=0)
    {
        var how=new OpenHow {Flags=(ulong)(flags|NoFollow|CloseExec|((flags & 0x200000)==0?NonBlock:0)),Mode=mode,Resolve=0x08|0x04}; // BENEATH | NO_SYMLINKS (includes magic links).
        var fd=syscall(437,root.DangerousGetHandle().ToInt32(),path,ref how,24);
        if(fd<0)throw new ApiException(409,Marshal.GetLastPInvokeError()==38?"containment_unavailable":"path_unavailable");
        return new SafeFileHandle((IntPtr)fd,true);
    }
    internal static SafeFileHandle Parent(SafeFileHandle directory)
    {
        var how=new OpenHow {Flags=(ulong)(0x200000|Directory|NoFollow|CloseExec),Resolve=0x04}; // O_PATH: ancestry needs traversal, not directory listing.
        var fd=syscall(437,directory.DangerousGetHandle().ToInt32(),"..",ref how,24);
        if(fd<0)throw new ApiException(409,"path_unavailable");
        return new SafeFileHandle((IntPtr)fd,true);
    }
    internal static NodeIdentity Stat(SafeFileHandle handle)
    {
        var m=Marshal.AllocHGlobal(256);
        try { if(statx(handle.DangerousGetHandle().ToInt32(),"",0x1000,0x1fff,m)!=0)throw new ApiException(409,"disk_unavailable");
            // Type/mode, inode, size, mtime and mount ID are used below. Never
            // compare absent mount IDs as zero and accidentally accept aliases.
            const uint required=0x1343;
            if((unchecked((uint)Marshal.ReadInt32(m,0))&required)!=required)throw new ApiException(409,"containment_unavailable");
            return new(unchecked((uint)Marshal.ReadInt32(m,136)),unchecked((uint)Marshal.ReadInt32(m,140)),unchecked((ulong)Marshal.ReadInt64(m,32)),unchecked((ushort)Marshal.ReadInt16(m,28)),Marshal.ReadInt64(m,40),checked(Marshal.ReadInt64(m,112)*1000000000L+unchecked((uint)Marshal.ReadInt32(m,120))),unchecked((ulong)Marshal.ReadInt64(m,144))); }
        finally{Marshal.FreeHGlobal(m);}
    }
    internal static IEnumerable<string> Names(SafeFileHandle handle)
    {
        int fd=Duplicate(handle.DangerousGetHandle().ToInt32()); if(fd<0)throw new ApiException(409,"disk_unavailable");
        var d=fdopendir(fd);if(d==IntPtr.Zero){new SafeFileHandle((IntPtr)fd,true).Dispose();throw new ApiException(409,"disk_unavailable");}
        try { for(var p=readdir(d);p!=IntPtr.Zero;p=readdir(d)) { var name=Marshal.PtrToStringUTF8(IntPtr.Add(p,19));if(name is not null and not "." and not "..")yield return name; } }
        finally{closedir(d);}
    }
}
public sealed class ContainedDirectory : IDisposable
{
    private readonly SafeFileHandle root;
    private readonly SafeFileHandle boundary;
    private readonly SafeFileHandle? scope;
    private readonly string boundaryPath;
    private readonly string prefix="";
    private readonly string scopeBase="";
    public string Identity {get;}
    internal Action? BeforeMutation {get;set;}

    public ContainedDirectory(string absolute)
    {
        if(!OperatingSystem.IsLinux() || RuntimeInformation.ProcessArchitecture is not (Architecture.X64 or Architecture.Arm64))throw new PlatformNotSupportedException("Linux amd64/arm64 required");
        if(!Path.IsPathFullyQualified(absolute))throw new ApiException(400,"validation_failed");
        boundaryPath=Path.TrimEndingDirectorySeparator(absolute);
        root=DirectorySafety.AbsoluteDirectory(boundaryPath);
        try { boundary=DirectorySafety.Copy(root); Identity=LinuxFs.Stat(root).Key; }
        catch { root.Dispose(); boundary?.Dispose(); throw; }
    }
    internal ContainedDirectory(SafeFileHandle handle,SafeFileHandle boundary,string boundaryPath,string prefix,SafeFileHandle? scope=null,string scopeBase="")
    {
        root=handle;this.boundaryPath=boundaryPath;this.prefix=prefix;this.scopeBase=scopeBase;
        try { this.boundary=DirectorySafety.Copy(boundary);this.scope=scope is null?null:DirectorySafety.Copy(scope);Identity=LinuxFs.Stat(root).Key; }
        catch { root.Dispose();this.boundary?.Dispose();this.scope?.Dispose();throw; }
    }
    internal ContainedDirectory WithLibraryScope()
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();
            return new(DirectorySafety.Copy(root),boundary,boundaryPath,prefix,root,prefix);
        }
    }
    private string Location(string path){var local=scope is null?prefix:prefix==scopeBase?"":prefix[(scopeBase.Length+1)..];return local==""?path:(path=="."?local:local+"/"+path);}
    private SafeFileHandle ResolutionRoot=>scope??boundary;
    private void VerifyHandle()
    {
        using var mounted=DirectorySafety.AbsoluteDirectory(boundaryPath);
        if(!DirectorySafety.Same(LinuxFs.Stat(mounted),LinuxFs.Stat(boundary)))throw new ApiException(409,"disk_unavailable");
        if(scope is not null)DirectorySafety.RequireDescendant(scope,boundary);
        using var current=LinuxFs.Resolve(ResolutionRoot,Location("."),LinuxFs.Directory);
        if(!DirectorySafety.Same(LinuxFs.Stat(current),LinuxFs.Stat(root)))throw new ApiException(409,"file_identity_changed");
    }
    public static string Validate(string? relative,bool allowRoot=false)
    {
        if(relative=="" && allowRoot)return ".";
        if(relative is null || relative.Length is 0 or >4096 || relative.StartsWith('/') || relative.Contains('\\'))throw new ApiException(400,"invalid_path");
        foreach(var character in relative)if(char.IsControl(character))throw new ApiException(400,"invalid_path");
        foreach(var part in relative.Split('/'))if(part is "" or "." or ".." || part.Length>255)throw new ApiException(400,"invalid_path");
        return relative;
    }
    public ContainedDirectory Directory(string relative)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();var valid=Validate(relative,true);
            var handle=LinuxFs.Resolve(ResolutionRoot,Location(valid),LinuxFs.Directory);
            var full=valid=="."?prefix:(prefix==""?valid:prefix+"/"+valid);
            return new(handle,boundary,boundaryPath,full,scope,scopeBase);
        }
    }
    public NodeIdentity Inspect(string relative)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();using var handle=LinuxFs.Resolve(ResolutionRoot,Location(Validate(relative,true)),0x200000);
            return LinuxFs.Stat(handle);
        }
    }
    public static NodeIdentity Inspect(FileStream stream)=>LinuxFs.Stat(stream.SafeFileHandle);
    public FileStream OpenFile(string relative,string? expectedIdentity=null,bool write=false)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();
            var handle=LinuxFs.Resolve(ResolutionRoot,Location(Validate(relative)),write?2:0);
            try
            {
                var stat=LinuxFs.Stat(handle);
                if(!stat.IsFile || (expectedIdentity is not null && stat.Key!=expectedIdentity))throw new ApiException(409,"file_identity_changed");
                return new(handle,write?FileAccess.ReadWrite:FileAccess.Read,4096,false);
            }
            catch{handle.Dispose();throw;}
        }
    }
    public FileStream CreateFile(string relative)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();
            // The complete path is resolved and created by one openat2 call.
            var handle=LinuxFs.Resolve(ResolutionRoot,Location(Validate(relative)),2|0x40|0x80,0x180);
            try{if(!LinuxFs.Stat(handle).IsFile)throw new ApiException(409,"path_unavailable");return new(handle,FileAccess.ReadWrite,4096,false);}
            catch{handle.Dispose();throw;}
        }
    }
    public IReadOnlyList<string> Names(string relative="")
    {
        lock(DirectorySafety.Gate)
        {
            using var dir=Directory(relative);
            return LinuxFs.Names(dir.root).Where(n=>n.Length<=255 && !n.Any(char.IsControl)).Take(10001).ToArray();
        }
    }
    private (ContainedDirectory Parent,string Leaf) ParentOf(string relative)
    {
        Validate(relative);var i=relative.LastIndexOf('/');
        return(Directory(i<0?"":relative[..i]),relative[(i+1)..]);
    }
    private void RevalidateMutation(params ContainedDirectory[] parents)
    {
        BeforeMutation?.Invoke();
        VerifyHandle();
        foreach(var parent in parents)parent.VerifyHandle();
    }
    private static SafeFileHandle RegularNode(ContainedDirectory parent,string leaf)
    {
        var handle=LinuxFs.Resolve(parent.root,leaf,0x200000);
        try
        {
            if(!LinuxFs.Stat(handle).IsFile)throw new ApiException(409,"regular_file_required");
            return handle;
        }
        catch{handle.Dispose();throw;}
    }
    private static void RequireSameSource(ContainedDirectory parent,string leaf,SafeFileHandle expected)
    {
        using var current=RegularNode(parent,leaf);
        if(!DirectorySafety.Same(LinuxFs.Stat(current),LinuxFs.Stat(expected)))throw new ApiException(409,"file_identity_changed");
    }
    public void CreateDirectory(string relative)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();var(parent,leaf)=ParentOf(relative);using(parent)
            {
                RevalidateMutation(parent);
                if(LinuxFs.mkdirat(parent.root.DangerousGetHandle().ToInt32(),leaf,0x1c0)!=0)throw new ApiException(409,"path_unavailable");
            }
        }
    }
    public void Rename(string source,string destination)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();var(s,sn)=ParentOf(source);using(s)
            {
                var(d,dn)=ParentOf(destination);using(d)using(var original=RegularNode(s,sn))
                {
                    RevalidateMutation(s,d);RequireSameSource(s,sn,original);
                    if(LinuxFs.renameat2(s.root.DangerousGetHandle().ToInt32(),sn,d.root.DangerousGetHandle().ToInt32(),dn,1)!=0)throw new ApiException(409,"path_unavailable");
                }
            }
        }
    }
    public void HardLink(string source,string destination)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();var(s,sn)=ParentOf(source);using(s)
            {
                var(d,dn)=ParentOf(destination);using(d)using(var original=RegularNode(s,sn))
                {
                    RevalidateMutation(s,d);RequireSameSource(s,sn,original);
                    if(LinuxFs.linkat(s.root.DangerousGetHandle().ToInt32(),sn,d.root.DangerousGetHandle().ToInt32(),dn,0)!=0)throw new ApiException(409,Marshal.GetLastPInvokeError() is 18 or 1 or 95?"hardlink_unavailable":"path_unavailable");
                }
            }
        }
    }
    public void Unlink(string relative)
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();var(parent,leaf)=ParentOf(relative);using(parent)using(var original=RegularNode(parent,leaf))
            {
                RevalidateMutation(parent);RequireSameSource(parent,leaf,original);
                if(LinuxFs.unlinkat(parent.root.DangerousGetHandle().ToInt32(),leaf,0)!=0)throw new ApiException(409,"path_unavailable");
            }
        }
    }
    internal NodeIdentity RootNode(){lock(DirectorySafety.Gate){VerifyHandle();return LinuxFs.Stat(root);}}
    public VolumeInfo Volume()
    {
        lock(DirectorySafety.Gate)
        {
            VerifyHandle();var m=Marshal.AllocHGlobal(128);
            try
            {
                if(LinuxFs.fstatvfs(root.DangerousGetHandle().ToInt32(),m)!=0)throw new ApiException(409,"disk_unavailable");
                var fragment=Marshal.ReadInt64(m,8);
                return new(checked(fragment*Marshal.ReadInt64(m,32)),checked(fragment*Marshal.ReadInt64(m,16)),(Marshal.ReadInt64(m,72)&1)==0 && LinuxFs.Access(439,root.DangerousGetHandle().ToInt32(),"",3,0x1000|0x200)==0,Identity.Split(':')[0]+":"+Identity.Split(':')[1]);
            }
            finally{Marshal.FreeHGlobal(m);}
        }
    }
    public void RestrictPermissions(){lock(DirectorySafety.Gate){VerifyHandle();if(LinuxFs.fchmod(root.DangerousGetHandle().ToInt32(),0x1c0)!=0)throw new ApiException(503,"state_permissions_unavailable");}}
    public void Dispose(){lock(DirectorySafety.Gate){root.Dispose();boundary.Dispose();scope?.Dispose();}}
}
public sealed class ContainedStorage(ServerOptions options) : IDisposable
{
    private readonly ContainedDirectory data=new(options.DataRoot);
    public string RootId {get;set;}="";
    public string RootPath=>options.DataRoot;
    public VolumeInfo Volume()=>data.Volume();
    private void VerifyMount(){using var current=new ContainedDirectory(options.DataRoot);using var state=new ContainedDirectory(options.StateRoot);if(current.Identity!=data.Identity)throw new ApiException(409,"disk_unavailable");if(MountLocation.Resolve(options.DataRoot,current.RootNode()).Overlaps(MountLocation.Resolve(options.StateRoot,state.RootNode())))throw new ApiException(503,"storage_roots_overlap");}
    public ContainedRoot ValidateLibraryRoot(string relative)
    {
        VerifyMount();
        ContainedDirectory.Validate(relative);if(relative.Split('/').Contains(".briani",StringComparer.Ordinal))throw new ApiException(400,"invalid_library_root");
        var ancestors=new List<string>{data.Identity}; string path="";
        foreach(var part in relative.Split('/')){path=path==""?part:path+"/"+part;using var d=data.Directory(path);ancestors.Add(d.Identity);}
        return new(relative,ancestors[^1],ancestors);
    }
    public bool Overlaps(ContainedRoot candidate,IEnumerable<(string Path,string Identity)> existing)
    {
        using var c=data.Directory(candidate.RelativePath);var physical=MountLocation.Resolve(Path.Combine(options.DataRoot,candidate.RelativePath),c.RootNode());
        using var state=new ContainedDirectory(options.StateRoot);if(physical.Overlaps(MountLocation.Resolve(options.StateRoot,state.RootNode())))return true;
        foreach(var (path,identity) in existing)
        {
            if(candidate.AncestorIdentities.Contains(identity))return true;
            try{var original=ValidateLibraryRoot(path);using var d=data.Directory(path);if(original.Identity!=identity || original.AncestorIdentities.Contains(candidate.Identity) || physical.Overlaps(MountLocation.Resolve(Path.Combine(options.DataRoot,path),d.RootNode())))return true;}
            catch(ApiException){return true;} // Unknown/offline roots still reserve their scope; cannot prove separation.
        }
        return false;
    }
    public ContainedDirectory OpenLibrary(Library library)
    {VerifyMount();using var d=data.Directory(library.RootPath);if(d.Identity!=library.RootIdentity)throw new ApiException(409,"disk_unavailable");return d.WithLibraryScope();}
    public IReadOnlyList<StorageDirectory> DescribeDirectories(string relative="")
    {var list=new List<StorageDirectory>();foreach(var name in data.Names(relative)){if(name==".briani")continue;var path=relative==""?name:relative+"/"+name;try{using var d=data.Directory(path);list.Add(new(path,name,d.Volume().Writable));}catch(ApiException){}}return list;}
    public void Dispose()=>data.Dispose();
}
