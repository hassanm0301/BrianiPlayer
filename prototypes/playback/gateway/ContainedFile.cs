using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace Briani.PlaybackProof;

public static class ContainedFile
{
    // Linux proof host: walk using dir descriptors, never resolve symlinks between checks/open.
    private const int ReadOnly = 0, Directory = 0x10000, NoFollow = 0x20000, CloseExec = 0x80000;
    [DllImport("libc", SetLastError = true)] private static extern int open(string path, int flags);
    [DllImport("libc", SetLastError = true)] private static extern int openat(int dirfd, string path, int flags);
    [DllImport("libc")] private static extern int close(int fd);
    [DllImport("libc", SetLastError = true)] private static extern int statx(int fd, string path, int flags, uint mask, IntPtr buffer);
    public static FileIdentity Identity(FileStream stream)
    {
        var memory = Marshal.AllocHGlobal(256);
        try
        {
            if (statx(stream.SafeFileHandle.DangerousGetHandle().ToInt32(), "", 0x1000, 0x7ff, memory) != 0)
                throw new IOException("file_identity_unavailable");
            var mask = Marshal.ReadInt32(memory, 0);
            if ((mask & 0x103) != 0x103 || (Marshal.ReadInt16(memory, 28) & 0xf000) != 0x8000)
                throw new IOException("regular_file_required");
            return new(Marshal.ReadInt32(memory, 136), Marshal.ReadInt32(memory, 140), Marshal.ReadInt64(memory, 32));
        }
        finally { Marshal.FreeHGlobal(memory); }
    }
    public static FileStream Open(string root, string relative, long expectedLength, FileIdentity? expectedIdentity = null)
    {
        if (!OperatingSystem.IsLinux()) throw new PlatformNotSupportedException("Linux proof only");
        TorrentLayout.ValidatePath(relative);
        var fd = open(root, ReadOnly | Directory | NoFollow | CloseExec);
        if (fd < 0) throw new IOException("disk_unavailable");
        try
        {
            var parts = relative.Split('/');
            for (var i = 0; i < parts.Length; i++)
            {
                var next = openat(fd, parts[i], ReadOnly | NoFollow | CloseExec | 0x800 /* O_NONBLOCK: refuse FIFO hangs */ |
                    (i < parts.Length - 1 ? Directory : 0));
                if (next < 0) throw new IOException("path_unavailable");
                close(fd); fd = next;
            }
            var handle = new SafeFileHandle((IntPtr)fd, ownsHandle: true);
            fd = -1;
            var result = new FileStream(handle, FileAccess.Read, 1, isAsync: false);
            try
            {
                var identity = Identity(result);
                if (expectedIdentity is not null && identity != expectedIdentity || result.Length > expectedLength)
                    throw new IOException("file_identity_changed");
            }
            catch { result.Dispose(); throw; }
            return result;
        }
        finally { if (fd >= 0) close(fd); }
    }
}

public sealed record FileIdentity(int DeviceMajor, int DeviceMinor, long Inode);
