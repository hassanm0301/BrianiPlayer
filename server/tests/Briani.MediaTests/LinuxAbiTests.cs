using System.Runtime.InteropServices;
using Briani.Api.Infrastructure.Storage;

namespace Briani.MediaTests;

public class LinuxAbiTests
{
    [Fact]
    public void OpenDirectoryAndNoFollowFlagsMatchEachSupportedKernelAbi()
    {
        Assert.Equal((0x10000,0x20000), LinuxFs.OpenFlags(Architecture.X64));
        Assert.Equal((0x4000,0x8000), LinuxFs.OpenFlags(Architecture.Arm64));
        Assert.Throws<PlatformNotSupportedException>(() => LinuxFs.OpenFlags(Architecture.X86));
    }

    [Fact]
    public void CurrentNativeAbiCanOpenAndInspectRoot()
    {
        using var root = new ContainedDirectory(Path.GetTempPath());
        Assert.True(root.RootNode().IsDirectory);
    }
}
