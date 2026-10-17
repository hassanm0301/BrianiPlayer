using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Integrations.Prowlarr;
public sealed class ProwlarrTransport(ServiceConnections connections,SafeHttp http):IProwlarrTransport,IProwlarrAdminTransport
{
    // Indexer tests run inside Prowlarr; answer before the client's 20-second receive timeout.
    private static readonly TimeSpan AdminDeadline=TimeSpan.FromSeconds(18);
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
    public async Task<ProwlarrReply> SendAsync(ProwlarrCall call,CancellationToken ct=default)
    {
        try
        {
            if(!ProwlarrCall.Permits(call.Method,call.Path))throw new ProwlarrFailure("invalid_api_path");
            var connection=await connections.RequiredAsync("prowlarr",ct);
            var uri=new Uri(connection.Origin,call.Path.TrimStart('/'));if(!SafeHttp.SameOrigin(uri,connection.Origin))throw new ProwlarrFailure("invalid_api_path");
            var response=await http.SendAsync(call.Method,uri,call.Body,call.MaxResponseBytes,connection.Origin,connection.Secret,AdminDeadline,ct);
            if(response.Status is 401 or 403)throw new ProwlarrFailure("credentials_rejected");
            // 400 carries Prowlarr's validation failures and 404 an unknown indexer; both are mapped by the caller.
            if(response.Status is not (200 or 201 or 202 or 400 or 404))throw new ProwlarrFailure("provider_unavailable");
            return new(response.Status,response.Body);
        }
        catch(ApiException error){throw new ProwlarrFailure(error.Code);}
    }
}
