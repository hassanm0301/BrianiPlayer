#if BRIANI_FAULT_TEST
using System.Text.Json;
namespace Briani.Api.Infrastructure.Testing;

internal static class CrashBoundary
{
    internal static void Wait(string name)
    {
        if (!OperatingSystem.IsLinux()) throw new PlatformNotSupportedException("Linux fault fixture required");
        const string instruction = "/config/fault-test-boundary";
        if (!File.Exists(instruction) || File.ReadAllText(instruction).Trim() != name) return;
        var marker = "/config/fault-test-reached";
        using (var output = new FileStream(marker, FileMode.CreateNew, FileAccess.Write, FileShare.Read))
        {
            output.Write(JsonSerializer.SerializeToUtf8Bytes(new { boundary = name, processId = Environment.ProcessId }));
            output.Flush(true);
        }
        File.SetUnixFileMode(marker, UnixFileMode.UserRead | UnixFileMode.UserWrite);
        // The fixture supervisor kills the OS process here. No exception or
        // orderly transaction cleanup simulates that crash.
        Thread.Sleep(Timeout.Infinite);
    }
}
#endif
