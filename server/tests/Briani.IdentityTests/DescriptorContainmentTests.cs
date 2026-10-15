using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;

namespace Briani.IdentityTests;

public sealed class DescriptorContainmentTests
{
    [Fact]
    public void Nested_descriptor_operations_work_and_reject_symlink_components()
    {
        using var tree = new TemporaryTree();
        var outside = Path.Combine(tree.Root, "outside.txt");
        File.WriteAllText(outside, "outside");
        using var root = new ContainedDirectory(tree.Data);
        root.CreateDirectory("library");
        using var libraryDirectory = root.Directory("library");
        using var library = libraryDirectory.WithLibraryScope();
        library.CreateDirectory("season");
        library.CreateDirectory("season/one");
        using (var created = library.CreateFile("season/one/episode.mkv")) created.Write("inside"u8);
        library.HardLink("season/one/episode.mkv", "season/one/linked.mkv");
        library.Rename("season/one/linked.mkv", "season/one/renamed.mkv");
        using (var opened = library.OpenFile("season/one/renamed.mkv"))
        using (var reader = new StreamReader(opened)) Assert.Equal("inside", reader.ReadToEnd());
        library.Unlink("season/one/renamed.mkv");
        Assert.False(File.Exists(Path.Combine(tree.Data, "library", "season", "one", "renamed.mkv")));

        File.CreateSymbolicLink(Path.Combine(tree.Data, "library", "file-link"), outside);
        Directory.CreateSymbolicLink(Path.Combine(tree.Data, "library", "dir-link"), tree.Root);
        Assert.Throws<ApiException>(() => library.OpenFile("file-link"));
        Assert.Throws<ApiException>(() => library.Directory("dir-link"));
        Assert.Throws<ApiException>(() => library.CreateFile("dir-link/created.txt"));
        Assert.Equal("outside", File.ReadAllText(outside));
        Assert.False(File.Exists(Path.Combine(tree.Root, "created.txt")));
    }

    [Fact]
    public void Deep_valid_path_works_and_oversized_components_are_rejected()
    {
        using var tree = new TemporaryTree();
        using var root = new ContainedDirectory(tree.Data);
        var path = "";
        for (var i = 0; i < 12; i++)
        {
            path = path.Length == 0 ? $"segment-{i:D2}-{new string('x', 42)}" : $"{path}/segment-{i:D2}-{new string('x', 42)}";
            root.CreateDirectory(path);
        }
        using (var file = root.CreateFile(path + "/end.bin")) file.WriteByte(23);
        using (var file = root.OpenFile(path + "/end.bin")) Assert.Equal(23, file.ReadByte());
        Assert.Throws<ApiException>(() => ContainedDirectory.Validate(new string('x', 256)));
        Assert.Throws<ApiException>(() => ContainedDirectory.Validate(new string('x', 4097)));
    }

    [Fact]
    public void Retained_child_rejects_replacement_at_the_same_relative_path()
    {
        using var tree = new TemporaryTree();
        var original = Path.Combine(tree.Data, "library", "child");
        Directory.CreateDirectory(original);
        File.WriteAllText(Path.Combine(original, "original.txt"), "original");
        using var root = new ContainedDirectory(tree.Data);
        using var libraryDirectory = root.Directory("library");
        using var library = libraryDirectory.WithLibraryScope();
        using var child = library.Directory("child");

        Directory.Move(original, Path.Combine(tree.Data, "library", "retired"));
        Directory.CreateDirectory(original);
        File.WriteAllText(Path.Combine(original, "replacement.txt"), "replacement");

        AssertConflict(() => child.OpenFile("replacement.txt").Dispose());
        AssertConflict(() => child.CreateFile("created.txt").Dispose());
        Assert.Equal("replacement", File.ReadAllText(Path.Combine(original, "replacement.txt")));
        Assert.False(File.Exists(Path.Combine(original, "created.txt")));
    }

    [Fact]
    public void Root_and_pinned_library_reject_access_after_move_outside_data()
    {
        using var tree = new TemporaryTree();
        var libraryPath = Path.Combine(tree.Data, "library");
        Directory.CreateDirectory(libraryPath);
        File.WriteAllText(Path.Combine(libraryPath, "owned.txt"), "owned");
        using var root = new ContainedDirectory(tree.Data);
        using var libraryDirectory = root.Directory("library");
        using var library = libraryDirectory.WithLibraryScope();

        var escaped = Path.Combine(tree.Root, "escaped-library");
        Directory.Move(libraryPath, escaped);
        AssertConflict(() => library.OpenFile("owned.txt").Dispose());
        AssertConflict(() => library.CreateFile("created.txt").Dispose());
        Assert.Equal("owned", File.ReadAllText(Path.Combine(escaped, "owned.txt")));
        Assert.False(File.Exists(Path.Combine(escaped, "created.txt")));

        var escapedData = Path.Combine(tree.Root, "escaped-data");
        Directory.Move(tree.Data, escapedData);
        AssertConflict(() => root.CreateFile("created-at-root.txt").Dispose());
        Assert.False(File.Exists(Path.Combine(escapedData, "created-at-root.txt")));
    }

    [Fact]
    public async Task Replaced_parent_at_mutation_hook_is_not_modified()
    {
        using var tree = new TemporaryTree();
        var parent = Path.Combine(tree.Data, "parent");
        Directory.CreateDirectory(parent);
        using var root = new ContainedDirectory(tree.Data);
        using var ready = new ManualResetEventSlim();
        using var release = new ManualResetEventSlim();
        root.BeforeMutation = () => { ready.Set(); if (!release.Wait(TimeSpan.FromSeconds(10))) throw new TimeoutException("mutation hook timed out"); };

        var task = Task.Run(() => root.CreateDirectory("parent/created"));
        try
        {
            Assert.True(ready.Wait(TimeSpan.FromSeconds(10)), "mutation did not reach its hook");
            Directory.Move(parent, Path.Combine(tree.Data, "retired"));
            Directory.CreateDirectory(parent);
        }
        finally { release.Set(); }

        await Assert.ThrowsAsync<ApiException>(async () => await task);
        Assert.False(Directory.Exists(Path.Combine(parent, "created")));
        Assert.False(Directory.Exists(Path.Combine(tree.Data, "retired", "created")));
    }

    [Fact]
    public async Task Replaced_regular_source_at_mutation_hook_is_not_renamed()
    {
        using var tree = new TemporaryTree();
        var source = Path.Combine(tree.Data, "source.txt");
        File.WriteAllText(source, "original");
        using var root = new ContainedDirectory(tree.Data);
        using var ready = new ManualResetEventSlim();
        using var release = new ManualResetEventSlim();
        root.BeforeMutation = () => { ready.Set(); if (!release.Wait(TimeSpan.FromSeconds(10))) throw new TimeoutException("mutation hook timed out"); };

        var task = Task.Run(() => root.Rename("source.txt", "destination.txt"));
        try
        {
            Assert.True(ready.Wait(TimeSpan.FromSeconds(10)), "mutation did not reach its hook");
            File.Move(source, Path.Combine(tree.Data, "retired.txt"));
            File.WriteAllText(source, "replacement");
        }
        finally { release.Set(); }

        await Assert.ThrowsAsync<ApiException>(async () => await task);
        Assert.Equal("replacement", File.ReadAllText(source));
        Assert.Equal("original", File.ReadAllText(Path.Combine(tree.Data, "retired.txt")));
        Assert.False(File.Exists(Path.Combine(tree.Data, "destination.txt")));
    }

    private static void AssertConflict(Action action)
    {
        var error = Assert.Throws<ApiException>(action);
        Assert.Equal(409, error.Status);
    }

    private sealed class TemporaryTree : IDisposable
    {
        public string Root { get; } = Path.Combine(Path.GetTempPath(), "briani-descriptor-" + Guid.NewGuid().ToString("N"));
        public string Data => Path.Combine(Root, "data");
        public TemporaryTree() => Directory.CreateDirectory(Data);
        public void Dispose() => Directory.Delete(Root, recursive: true);
    }
}
