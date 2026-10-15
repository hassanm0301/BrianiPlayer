using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;

namespace Briani.PiContainmentProbe;

internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length == 1 && args[0] == "--mounted-libraries") return RunMountedLibraries();
        if (args.Length != 1 || !Path.IsPathFullyQualified(args[0]))
        {
            Console.Error.WriteLine("usage: Briani.PiContainmentProbe <new-empty-absolute-fixture-directory> | --mounted-libraries");
            return 2;
        }

        var fixture = Path.TrimEndingDirectorySeparator(args[0]);
        if (!Directory.Exists(fixture))
        {
            Console.Error.WriteLine("fixture directory does not exist");
            return 2;
        }

        try
        {
            // Constructor checks every path component without following links.
            using var checkedFixture = new ContainedDirectory(fixture);
            if (Directory.EnumerateFileSystemEntries(fixture).Any())
            {
                Console.Error.WriteLine("fixture directory must be empty");
                return 2;
            }
        }
        catch (Exception e)
        {
            Console.Error.WriteLine($"fixture rejected: {e.GetType().Name}: {e.Message}");
            return 2;
        }

        var normal = Path.Combine(fixture, "normal");
        var escape = Path.Combine(fixture, "escape");
        var moving = Path.Combine(fixture, "moving");
        var outside = Path.Combine(fixture, "outside");
        var fileLink = Path.Combine(escape, "link.bin");
        var result = 0;
        try
        {
            Directory.CreateDirectory(normal);
            Directory.CreateDirectory(escape);
            Directory.CreateDirectory(moving);
            Directory.CreateDirectory(outside);
            CheckNestedOperations(normal);
            Console.WriteLine("PASS nested create/read/link/rename/unlink");
            CheckSymlinkEscape(escape, outside, fileLink);
            Console.WriteLine("PASS symlink escape rejected");
            CheckMovedChild(moving, outside);
            Console.WriteLine("PASS retained child moved outside rejected");
        }
        catch (Exception e)
        {
            Console.Error.WriteLine($"FAIL {e.GetType().Name}: {e.Message}");
            result = 1;
        }
        finally
        {
            // These names were absent at entry and are the probe's only writes.
            // Remove the file symlink before recursively deleting its parent.
            try
            {
                File.Delete(fileLink);
                foreach (var path in new[] { normal, escape, moving, outside })
                    if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
            }
            catch (Exception e)
            {
                Console.Error.WriteLine($"FAIL cleanup {e.GetType().Name}: {e.Message}");
                result = 1;
            }
        }
        return result;
    }

    private static int RunMountedLibraries()
    {
        const string hassanPath = "/data/Hassan";
        const string familyPath = "/data/Family";
        const string configPath = "/config";
        var result = 0;
        var ownsGeneratedTrees = false;
        try
        {
            // Require the caller's dedicated empty binds before making any writes.
            foreach (var path in new[] { hassanPath, familyPath, configPath })
            {
                Require(Directory.Exists(path), $"missing mounted directory: {path}");
                using var checkedDirectory = new ContainedDirectory(path);
                Require(!Directory.EnumerateFileSystemEntries(path).Any(), $"mounted directory is not empty: {path}");
            }

            using var data = new ContainedDirectory("/data");
            using var hassan = new ContainedDirectory(hassanPath);
            using var family = new ContainedDirectory(familyPath);
            using var config = new ContainedDirectory(configPath);
            var dataMount = data.Inspect("").MountId;
            var hassanMount = hassan.Inspect("").MountId;
            var familyMount = family.Inspect("").MountId;
            var configMount = config.Inspect("").MountId;
            Require(dataMount != 0 && hassanMount != 0 && familyMount != 0 && configMount != 0,
                "mount IDs are unavailable");
            Require(hassanMount == dataMount && familyMount != dataMount &&
                    configMount != dataMount && configMount != familyMount,
                "expected Hassan on /data, Family on a nested bind, and separate state bind");

            using var storage = new ContainedStorage(new ServerOptions { DataRoot = "/data", StateRoot = configPath });
            var hassanRoot = storage.ValidateLibraryRoot("Hassan");
            var familyRoot = storage.ValidateLibraryRoot("Family");
            Require(!storage.Overlaps(hassanRoot, new[] { (Path: "Family", Identity: familyRoot.Identity) }),
                "Hassan overlaps Family");
            Require(!storage.Overlaps(familyRoot, new[] { (Path: "Hassan", Identity: hassanRoot.Identity) }),
                "Family overlaps Hassan");

            ownsGeneratedTrees = true;
            using (var library = storage.OpenLibrary(new Library { RootPath = "Hassan", RootIdentity = hassanRoot.Identity }))
                CheckNestedOperations(library, hassanPath);
            Console.WriteLine("PASS mounted /data/Hassan nested operations");
            using (var library = storage.OpenLibrary(new Library { RootPath = "Family", RootIdentity = familyRoot.Identity }))
                CheckNestedOperations(library, familyPath);
            Console.WriteLine("PASS mounted /data/Family nested operations");
        }
        catch (Exception e)
        {
            Console.Error.WriteLine($"FAIL mounted libraries {e.GetType().Name}: {e.Message}");
            result = 1;
        }
        finally
        {
            // Both roots were empty at entry; only the generated series trees are removed.
            if (ownsGeneratedTrees)
            {
                foreach (var path in new[] { Path.Combine(hassanPath, "series"), Path.Combine(familyPath, "series") })
                {
                    try { if (Directory.Exists(path)) Directory.Delete(path, recursive: true); }
                    catch (Exception e)
                    {
                        Console.Error.WriteLine($"FAIL cleanup {path} {e.GetType().Name}: {e.Message}");
                        result = 1;
                    }
                }
            }
        }
        return result;
    }

    private static void CheckNestedOperations(string path)
    {
        using var root = new ContainedDirectory(path);
        CheckNestedOperations(root, path);
    }

    private static void CheckNestedOperations(ContainedDirectory root, string path)
    {
        root.CreateDirectory("series");
        root.CreateDirectory("series/season");
        using (var file = root.CreateFile("series/season/original.bin"))
        {
            file.Write("generated fixture"u8);
            file.Flush(true);
        }
        using (var file = root.OpenFile("series/season/original.bin"))
        using (var reader = new StreamReader(file))
            Require(reader.ReadToEnd() == "generated fixture", "nested read mismatch");
        root.HardLink("series/season/original.bin", "series/season/linked.bin");
        root.Rename("series/season/linked.bin", "series/season/renamed.bin");
        using (var file = root.OpenFile("series/season/renamed.bin"))
        using (var reader = new StreamReader(file))
            Require(reader.ReadToEnd() == "generated fixture", "renamed hardlink mismatch");
        root.Unlink("series/season/renamed.bin");
        Require(!File.Exists(Path.Combine(path, "series", "season", "renamed.bin")), "unlink left destination");
    }

    private static void CheckSymlinkEscape(string path, string outside, string link)
    {
        var sentinel = Path.Combine(outside, "sentinel.bin");
        File.WriteAllText(sentinel, "outside generated fixture");
        File.CreateSymbolicLink(link, sentinel);
        using var root = new ContainedDirectory(path);
        ExpectRejected(() => root.OpenFile("link.bin").Dispose());
        Require(File.ReadAllText(sentinel) == "outside generated fixture", "outside sentinel changed");
    }

    private static void CheckMovedChild(string path, string outside)
    {
        var childPath = Path.Combine(path, "child");
        Directory.CreateDirectory(childPath);
        File.WriteAllText(Path.Combine(childPath, "source.bin"), "retained fixture");
        using var root = new ContainedDirectory(path);
        using var child = root.Directory("child");
        var movedPath = Path.Combine(outside, "child");
        Directory.Move(childPath, movedPath);
        ExpectRejected(() => child.CreateFile("created.bin").Dispose());
        Require(!File.Exists(Path.Combine(movedPath, "created.bin")), "moved child was mutated");
        Require(File.ReadAllText(Path.Combine(movedPath, "source.bin")) == "retained fixture", "moved source changed");
    }

    private static void ExpectRejected(Action action)
    {
        try { action(); }
        catch (ApiException e) when (e.Status == 409) { return; }
        throw new InvalidOperationException("contained operation did not reject the escape");
    }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
}
