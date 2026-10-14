using System.Text;
using System.Text.Json;
namespace Briani.Api.Infrastructure.Security;
public sealed class PageCursor(SecretStore secrets)
{
    private sealed record Cursor(string Scope,int Offset);
    public string Encode(string scope,int offset){var body=Convert.ToBase64String(JsonSerializer.SerializeToUtf8Bytes(new Cursor(scope,offset))).TrimEnd('=').Replace('+','-').Replace('/','_');return body+"."+secrets.Digest(body);}
    public int Decode(string? token,string scope)
    {
        if(token is null)return 0;if(token.Length>2048)throw new ApiException(400,"invalid_cursor");var parts=token.Split('.');if(parts.Length!=2 || !Credentials.EqualHash(secrets.Digest(parts[0]),parts[1]))throw new ApiException(400,"invalid_cursor");
        try{var value=parts[0].Replace('-','+').Replace('_','/');value+=new string('=',(4-value.Length%4)%4);var c=JsonSerializer.Deserialize<Cursor>(Convert.FromBase64String(value));if(c is null || c.Scope!=scope || c.Offset is <0 or >10000)throw new ApiException(400,"invalid_cursor");return c.Offset;}catch(FormatException){throw new ApiException(400,"invalid_cursor");}catch(JsonException){throw new ApiException(400,"invalid_cursor");}
    }
}
