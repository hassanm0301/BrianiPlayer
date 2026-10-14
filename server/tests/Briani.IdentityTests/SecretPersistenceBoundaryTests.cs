using System.Security.Cryptography;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Security;

namespace Briani.IdentityTests;

public sealed class SecretPersistenceBoundaryTests : IDisposable
{
    private readonly string root = Path.Combine(Path.GetTempPath(), "briani-secret-boundary-" + Guid.NewGuid());
    private ServerOptions Options => new() { StateRoot = root };
    public SecretPersistenceBoundaryTests() => Directory.CreateDirectory(root);

    [Theory]
    [InlineData(0)] [InlineData(31)] [InlineData(33)]
    public void Malformed_existing_key_fails_closed_without_replacing_it(int length)
    {
        var original = Enumerable.Repeat((byte)37, length).ToArray();
        var path = Path.Combine(root, "secret.key"); File.WriteAllBytes(path, original);
        Assert.Equal("secret_store_unavailable", Assert.Throws<ApiException>(() => new SecretStore(Options)).Code);
        Assert.Equal(original, File.ReadAllBytes(path));
    }

    [Fact]
    public void Retained_key_decrypts_after_reopen_and_is_restricted_to_its_owner()
    {
        string envelope, digest;
        using (var first = new SecretStore(Options))
        {
            envelope = first.Encrypt("private upstream credential"); digest = first.Digest("request");
            first.WriteBootstrap("first"); first.WriteBootstrap("replacement"); Assert.Equal("replacement", first.ReadBootstrap());
            first.RemoveBootstrap(); first.RemoveBootstrap();
        }
        var keyPath = Path.Combine(root, "secret.key");
        var key = File.ReadAllBytes(keyPath); Assert.Equal(32, key.Length);
        if (OperatingSystem.IsLinux()) File.SetUnixFileMode(keyPath, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.GroupRead);
        using (var reopened = new SecretStore(Options))
        {
            Assert.Equal("private upstream credential", reopened.Decrypt(envelope)); Assert.Equal(digest, reopened.Digest("request"));
            Assert.NotEqual(envelope, reopened.Encrypt("private upstream credential"));
        }
        Assert.Equal(key, File.ReadAllBytes(keyPath));
        if (OperatingSystem.IsLinux()) Assert.Equal(UnixFileMode.UserRead | UnixFileMode.UserWrite, File.GetUnixFileMode(keyPath));
    }

    [Theory]
    [InlineData(0)] [InlineData(11)] [InlineData(27)]
    public void Truncated_envelope_does_not_return_plaintext(int length)
    {
        using var secrets = new SecretStore(Options);
        Assert.Equal("secret_store_unavailable", Assert.Throws<ApiException>(() => secrets.Decrypt(Convert.ToBase64String(new byte[length]))).Code);
        Assert.Throws<FormatException>(() => secrets.Decrypt("invalid base64"));
    }

    [Theory]
    [InlineData(0)] [InlineData(12)] [InlineData(28)]
    public void Changes_to_nonce_tag_or_ciphertext_are_rejected(int byteIndex)
    {
        using var secrets = new SecretStore(Options);
        var envelope = Convert.FromBase64String(secrets.Encrypt("private upstream credential")); envelope[byteIndex] ^= 1;
        Assert.Throws<AuthenticationTagMismatchException>(() => secrets.Decrypt(Convert.ToBase64String(envelope)));
    }

    public void Dispose() => Directory.Delete(root, true);
}
