using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text.Json;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;

namespace Briani.ResourceFaults;

internal static class Probe
{
    private static readonly byte[] Payload = Enumerable.Range(0, 32768).Select(i => (byte)(i % 251)).ToArray();
    private static readonly string Expected = Hash(Payload);
    private static string Hash(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes));
    private static void Check(bool condition, string message) { if (!condition) throw new InvalidOperationException(message); }
    public static async Task<int> Main(string[] args)
    {
        try
        {
            object result = args[0] switch
            {
                "disk-full" => await DiskFull(), "prepare" => await Prepare(), "readonly" => await ReadOnly(),
                "missing" => await Missing(), "recovered" => await Recovered(),
                "network-client" => await NetworkClient(args[1], args[2] == "failure"),
                "network-server" => await NetworkServer(), "idle" => await Idle(),
                _ => throw new ArgumentException("Unknown probe mode")
            };
            Console.WriteLine(JsonSerializer.Serialize(result)); return 0;
        }
        catch (Exception error) { Console.WriteLine(JsonSerializer.Serialize(new { passed = false, exception = error.GetType().Name, message = error.Message })); return 1; }
    }
    private static BrianiDb Database() => new(new DbContextOptionsBuilder<BrianiDb>().UseSqlite("Data Source=/state/probe.db").Options);
    private static ContainedStorage Storage() => new(new ServerOptions { DataRoot = "/data", StateRoot = "/state" });
    private static async Task<object> Prepare()
    {
        Directory.CreateDirectory("/data/library"); await File.WriteAllBytesAsync("/data/library/retained.bin", Payload);
        using var storage = Storage(); var identity = storage.ValidateLibraryRoot("library");
        using var db = Database(); await db.Database.EnsureCreatedAsync();
        var library = new Library { Name = "Resource fault fixture", RootPath = "library", RootIdentity = identity.Identity, CreatedAt = DateTimeOffset.UtcNow };
        db.Libraries.Add(library); await db.SaveChangesAsync();
        return new { passed = true, mode = "prepare", libraryIdentity = identity.Identity, retainedSha256 = Hash(await File.ReadAllBytesAsync("/data/library/retained.bin")) };
    }
    private static async Task<object> Denied(BrianiDb db, ContainedStorage storage, Library library, int status, string code)
    {
        var before = (await db.TorrentJobs.CountAsync(), await db.DownloadRequests.CountAsync());
        ApiException? failure = null;
        try { await new DownloadAdmission(db, storage).RequireAsync(new(Guid.NewGuid(), Guid.NewGuid(), "member"), library, null, 1, 1, null, CancellationToken.None); }
        catch (ApiException error) { failure = error; }
        Check(failure is not null && failure.Status == status && failure.Code == code, "Admission did not return required storage denial");
        Check(before == (await db.TorrentJobs.CountAsync(), await db.DownloadRequests.CountAsync()), "Admission changed durable requests or jobs");
        return new { status = failure!.Status, code = failure.Code, jobs = before.Item1, requests = before.Item2 };
    }
    private static async Task<object> DiskFull()
    {
        await Prepare(); using var storage = Storage(); using var db = Database(); var library = await db.Libraries.SingleAsync(); using var root = storage.OpenLibrary(library);
        var initial = root.Volume(); Check(initial.TotalBytes <= 16 * 1024 * 1024 && initial.TotalBytes > 0, "Refuse to fill an unbounded filesystem");
        IOException? fault = null; long written = 0;
        using (var fill = root.CreateFile("filler.bin"))
        {
            try { while (written < 16 * 1024 * 1024) { fill.Write(Payload); fill.Flush(true); written += Payload.Length; } }
            catch (IOException error) { fault = error; }
        }
        var full = root.Volume(); Check(fault is not null && full.FreeBytes < Payload.Length, "No actual bounded full-filesystem failure observed");
        var denied = await Denied(db, storage, library, 507, "disk_full");
        using (var retained = root.OpenFile("retained.bin")) { var bytes = new byte[Payload.Length]; retained.ReadExactly(bytes); Check(Hash(bytes) == Expected, "Disk-full changed retained bytes"); }
        root.Unlink("filler.bin"); using (var recovered = root.CreateFile("recovered.bin")) { recovered.Write(Payload); recovered.Flush(true); }
        Check(Hash(await File.ReadAllBytesAsync("/data/library/recovered.bin")) == Expected, "Write recovery bytes differ");
        return new { passed = true, mode = "disk-full", initial.TotalBytes, writtenBytesBeforeFailure = written, freeBytesAtFailure = full.FreeBytes, exception = fault!.GetType().Name, hresult = fault.HResult, denial = denied, retainedSha256 = Expected, recoveredSha256 = Expected, reservationPolicyPreserved = true };
    }
    private static async Task<object> ReadOnly()
    {
        using var storage = Storage(); using var db = Database(); var library = await db.Libraries.SingleAsync(); using var root = storage.OpenLibrary(library);
        Check(!root.Volume().Writable, "Read-only mount is unexpectedly writable");
        var denial = await Denied(db, storage, library, 409, "disk_unavailable");
        ApiException? writeFailure = null; try { using var output = root.CreateFile("forbidden.bin"); } catch (ApiException error) { writeFailure = error; }
        Check(writeFailure is not null && !File.Exists("/data/library/forbidden.bin"), "Read-only creation unexpectedly succeeded");
        var retained = Hash(await File.ReadAllBytesAsync("/data/library/retained.bin")); Check(retained == Expected, "Read-only phase changed bytes");
        return new { passed = true, mode = "readonly", denial, creationError = writeFailure!.Code, retainedSha256 = retained };
    }
    private static async Task<object> Missing()
    {
        using var storage = Storage(); using var db = Database(); var library = await db.Libraries.SingleAsync();
        var denial = await Denied(db, storage, library, 409, "path_unavailable");
        Check(!Directory.Exists("/data/library"), "Missing mount unexpectedly has the old library");
        return new { passed = true, mode = "missing", denial, absentLibrary = true };
    }
    private static async Task<object> Recovered()
    {
        using var storage = Storage(); using var db = Database(); var library = await db.Libraries.SingleAsync(); using var root = storage.OpenLibrary(library);
        using var descriptor = root.OpenFile("retained.bin"); var bytes = new byte[Payload.Length]; descriptor.ReadExactly(bytes); Check(Hash(bytes) == Expected, "Restored mount bytes differ");
        using (var output = root.CreateFile("post-fault.bin")) { output.Write(bytes); output.Flush(true); }
        Check(Hash(await File.ReadAllBytesAsync("/data/library/post-fault.bin")) == Expected, "Restored mount write differs");
        return new { passed = true, mode = "recovered", retainedSha256 = Expected, recoveredWriteSha256 = Expected, jobs = await db.TorrentJobs.CountAsync(), requests = await db.DownloadRequests.CountAsync() };
    }
    private static async Task<object> NetworkServer()
    {
        var listener = new TcpListener(IPAddress.Any, 9090); listener.Start(); Console.WriteLine("fixture-listener-ready");
        while (true) { using var client = await listener.AcceptTcpClientAsync(); await client.GetStream().WriteAsync(Payload); }
    }
    private static async Task<object> Idle() { await Task.Delay(Timeout.InfiniteTimeSpan); return new { }; }
    private static async Task<object> NetworkClient(string address, bool expectedFailure)
    {
        using var client = new TcpClient(); using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        try
        {
            await client.ConnectAsync(IPAddress.Parse(address), 9090, timeout.Token); var bytes = new byte[Payload.Length]; await client.GetStream().ReadExactlyAsync(bytes, timeout.Token);
            Check(!expectedFailure, "Disconnected network unexpectedly delivered bytes"); Check(Hash(bytes) == Expected, "Network fixture bytes differ");
            return new { passed = true, mode = "network-client", expectedFailure = false, receivedBytes = bytes.Length, sha256 = Expected };
        }
        catch (Exception error) when (expectedFailure && error is SocketException or OperationCanceledException or IOException)
        { return new { passed = true, mode = "network-client", expectedFailure = true, exception = error.GetType().Name, receivedBytes = 0 }; }
    }
}
