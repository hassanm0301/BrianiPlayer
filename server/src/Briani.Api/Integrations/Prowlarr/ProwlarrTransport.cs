using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Integrations.Prowlarr;
public sealed class ProwlarrTransport(ServiceConnections connections,SafeHttp http):IProwlarrTransport
{
    public async Task<byte[]> GetAsync(string relativePath,CancellationToken ct=default)
    {
        try
        {
            var connection=await connections.RequiredAsync("prowlarr",ct);
            if(relativePath.Length>4096 || !relativePath.StartsWith("/api/v1/",StringComparison.Ordinal) || relativePath.Contains('\\') || relativePath.Any(char.IsControl) || relativePath.Contains("..",StringComparison.Ordinal))throw new ProwlarrFailure("invalid_api_path");
            var uri=new Uri(connection.Origin,relativePath.TrimStart('/'));if(!SafeHttp.SameOrigin(uri,connection.Origin))throw new ProwlarrFailure("invalid_api_path");
            var response=await http.GetAsync(uri,4194304,connection.Origin,connection.Secret,ct);if(response.Status is 401 or 403)throw new ProwlarrFailure("credentials_rejected");if(response.Status!=200)throw new ProwlarrFailure("provider_unavailable");return response.Body;
        }
        catch(ApiException error){throw new ProwlarrFailure(error.Code);}
    }
}
