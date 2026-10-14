using System.Security.Cryptography;
using System.Text;
using Briani.Api.Infrastructure.Storage;
namespace Briani.Api.Infrastructure.Security;
// Standard AES-GCM envelope; key remains in the restricted persistent config mount.
public sealed class SecretStore : IDisposable
{
    private readonly ContainedDirectory state;private readonly byte[] key;
    public SecretStore(ServerOptions options)
    {
        if(!OperatingSystem.IsLinux())throw new PlatformNotSupportedException("Linux server required");
        state=new(options.StateRoot);
        try {using var f=state.OpenFile("secret.key");if(f.Length!=32)throw new ApiException(503,"secret_store_unavailable");key=new byte[32];f.ReadExactly(key);if(LinuxFs.fchmod(f.SafeFileHandle.DangerousGetHandle().ToInt32(),0x180)!=0)throw new ApiException(503,"secret_store_unavailable");}
        catch(ApiException e) when(e.Code=="path_unavailable") {key=RandomNumberGenerator.GetBytes(32);using var f=state.CreateFile("secret.key");f.Write(key);f.Flush(true);}

    }
    public string Digest(string value)=>Convert.ToHexString(HMACSHA256.HashData(key,Encoding.UTF8.GetBytes(value)));
    public string Encrypt(string value)
    {var plain=Encoding.UTF8.GetBytes(value);var nonce=RandomNumberGenerator.GetBytes(12);var cipher=new byte[plain.Length];var tag=new byte[16];using var aes=new AesGcm(key,16);aes.Encrypt(nonce,plain,cipher,tag);return Convert.ToBase64String(nonce.Concat(tag).Concat(cipher).ToArray());}
    public string Decrypt(string value)
    {var data=Convert.FromBase64String(value);if(data.Length<28)throw new ApiException(503,"secret_store_unavailable");var plain=new byte[data.Length-28];using var aes=new AesGcm(key,16);aes.Decrypt(data.AsSpan(0,12),data.AsSpan(28),data.AsSpan(12,16),plain);return Encoding.UTF8.GetString(plain);}
    public void WriteBootstrap(string code)
    {try{state.Unlink("bootstrap.code");}catch(ApiException e) when(e.Code=="path_unavailable"){}using var f=state.CreateFile("bootstrap.code");f.Write(Encoding.ASCII.GetBytes(code));f.Flush(true);}
    public string ReadBootstrap(){using var f=state.OpenFile("bootstrap.code");using var reader=new StreamReader(f);return reader.ReadToEnd();}
    public void RemoveBootstrap(){try{state.Unlink("bootstrap.code");}catch(ApiException e)when(e.Code=="path_unavailable"){} }
    public void Dispose(){CryptographicOperations.ZeroMemory(key);state.Dispose();}
}
