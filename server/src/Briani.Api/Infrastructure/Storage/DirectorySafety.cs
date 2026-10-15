using Microsoft.Win32.SafeHandles;
using Briani.Api.Infrastructure.Security;

namespace Briani.Api.Infrastructure.Storage;

// The host and managed engine are trusted writers. Stop the stack before an
// external process moves directories in a writable library. These checks catch
// stale handles; they cannot lock the host's directory topology across syscalls.
internal static class DirectorySafety
{
    // All filesystem mutations in this process share this gate, including
    // callers outside the HTTP WriteGate (scans, imports, secrets and cleanup).
    internal static readonly object Gate = new();

    internal static bool Same(NodeIdentity left, NodeIdentity right) =>
        left.Key == right.Key && left.MountId == right.MountId;

    internal static SafeFileHandle Copy(SafeFileHandle source)
    {
        var fd = LinuxFs.Duplicate(source.DangerousGetHandle().ToInt32());
        if (fd < 0) throw new ApiException(409, "disk_unavailable");
        return new((IntPtr)fd, true);
    }

    internal static SafeFileHandle AbsoluteDirectory(string absolute)
    {
        using var slash = new SafeFileHandle((IntPtr)LinuxFs.open("/", LinuxFs.Directory | LinuxFs.NoFollow | LinuxFs.CloseExec), true);
        if (slash.IsInvalid) throw new ApiException(409, "disk_unavailable");
        return LinuxFs.Resolve(slash, absolute.TrimStart('/'), LinuxFs.Directory);
    }

    internal static void RequireDescendant(SafeFileHandle directory, SafeFileHandle boundary)
    {
        var expected = LinuxFs.Stat(boundary);
        var current = Copy(directory);
        try
        {
            // Bound work even on a hostile/deep mount topology. This is a fixed
            // parent lookup, never a client-supplied path or a symlink traversal.
            for (var depth = 0; depth < 512; depth++)
            {
                var node = LinuxFs.Stat(current);
                if (Same(node, expected)) return;
                SafeFileHandle? parent = LinuxFs.Parent(current);
                try
                {
                    if (Same(node, LinuxFs.Stat(parent))) break;
                    current.Dispose();
                    current = parent;
                    parent = null;
                }
                finally { parent?.Dispose(); }
            }
        }
        finally { current.Dispose(); }
        throw new ApiException(409, "path_unavailable");
    }
}
