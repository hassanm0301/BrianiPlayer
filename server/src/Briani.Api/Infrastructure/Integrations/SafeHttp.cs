using System.Net;
using System.Net.Sockets;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Infrastructure.Integrations;
public interface ISafeDns {Task<IPAddress[]> ResolveAsync(string host,CancellationToken ct);}
public sealed class SystemSafeDns:ISafeDns {public Task<IPAddress[]> ResolveAsync(string host,CancellationToken ct)=>Dns.GetHostAddressesAsync(host,ct);}
public static class NetworkAddressPolicy
{
    private static readonly string[] DeniedV4={"0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.88.99.0/24","192.168.0.0/16","198.18.0.0/15","198.51.100.0/24","203.0.113.0/24","224.0.0.0/4","240.0.0.0/4"};
    private static readonly string[] DeniedV6={"2001::/23","2001:db8::/32","2002::/16","3ffe::/16","3fff::/20"};
    internal static bool In(IPAddress address,string cidr)
    {
        var parts=cidr.Split('/');var prefix=IPAddress.Parse(parts[0]).GetAddressBytes();var bytes=address.GetAddressBytes();if(prefix.Length!=bytes.Length)return false;var bits=int.Parse(parts[1]);
        for(int i=0;i<bits/8;i++)if(prefix[i]!=bytes[i])return false;var rest=bits%8;return rest==0 || (prefix[bits/8]>>(8-rest))==(bytes[bits/8]>>(8-rest));
    }
    public static bool IsPublic(IPAddress address)
    {if(address.IsIPv4MappedToIPv6)address=address.MapToIPv4();if(address.AddressFamily==AddressFamily.InterNetwork)return !DeniedV4.Any(c=>In(address,c));return address.AddressFamily==AddressFamily.InterNetworkV6 && address.ScopeId==0 && In(address,"2000::/3") && !DeniedV6.Any(c=>In(address,c));}
    public static bool ApprovedService(IPAddress address)
    {if(address.IsIPv4MappedToIPv6)address=address.MapToIPv4();return IsPublic(address) || IPAddress.IsLoopback(address) || In(address,"10.0.0.0/8") || In(address,"172.16.0.0/12") || In(address,"192.168.0.0/16") || In(address,"100.64.0.0/10") || address.AddressFamily==AddressFamily.InterNetworkV6 && address.ScopeId==0 && In(address,"fc00::/7");}
}
public sealed record BoundedHttpResponse(int Status,byte[] Body,Uri? Location,string? ContentType);
public sealed class SafeHttp(ISafeDns dns)
{
    private readonly SemaphoreSlim concurrency=new(2,2);
    public static bool SameOrigin(Uri a,Uri b)=>a.Scheme==b.Scheme && a.IdnHost.Equals(b.IdnHost,StringComparison.OrdinalIgnoreCase) && a.Port==b.Port;
    public static void ValidateContentUrl(Uri uri,Uri? approvedOrigin=null)
    {
        if(uri.AbsoluteUri.Length>16384 || uri.Scheme is not ("http" or "https") || uri.UserInfo!="" || uri.Fragment!="" || uri.HostNameType==UriHostNameType.Unknown || uri.Host.Contains('%') || uri.Port is not (80 or 443) && (approvedOrigin is null || !SameOrigin(uri,approvedOrigin)))throw new ApiException(400,"source_url_rejected");
    }
    internal async Task<IPAddress[]> AddressesAsync(Uri uri,Uri? approvedOrigin,CancellationToken ct)
    {
        ValidateContentUrl(uri,approvedOrigin);var addresses=await dns.ResolveAsync(uri.DnsSafeHost,ct);var service=approvedOrigin is not null && SameOrigin(uri,approvedOrigin);
        if(addresses.Length is <1 or >16 || addresses.Any(ip=>!(service?NetworkAddressPolicy.ApprovedService(ip):NetworkAddressPolicy.IsPublic(ip))))throw new ApiException(400,"source_address_rejected");return addresses.Distinct().ToArray();
    }
    public Task<BoundedHttpResponse> GetAsync(Uri uri,int maxBytes,Uri? approvedOrigin=null,string? apiKey=null,CancellationToken ct=default)=>
        SendAsync(HttpMethod.Get,uri,null,maxBytes,approvedOrigin,apiKey,TimeSpan.FromSeconds(20),ct);
    // Request bodies only ever go to the configured service origin, never to a content URL.
    public async Task<BoundedHttpResponse> SendAsync(HttpMethod method,Uri uri,byte[]? jsonBody,int maxBytes,Uri? approvedOrigin,string? apiKey,TimeSpan timeout,CancellationToken ct=default)
    {
        if(maxBytes is <1 or >16777216)throw new ArgumentOutOfRangeException(nameof(maxBytes));if(timeout<=TimeSpan.Zero || timeout>TimeSpan.FromSeconds(20))throw new ArgumentOutOfRangeException(nameof(timeout));ValidateContentUrl(uri,approvedOrigin);
        if(method!=HttpMethod.Get && (approvedOrigin is null || !SameOrigin(uri,approvedOrigin)))throw new ArgumentException("Only the configured service accepts non-GET requests.",nameof(method));
        if(jsonBody is not null && (method==HttpMethod.Get || jsonBody.Length>1048576))throw new ArgumentException("Invalid request body.",nameof(jsonBody));
        var caller=ct;using var deadline=CancellationTokenSource.CreateLinkedTokenSource(ct);deadline.CancelAfter(timeout);ct=deadline.Token;await concurrency.WaitAsync(ct);
        try
        {
            using var handler=new SocketsHttpHandler{AllowAutoRedirect=false,UseCookies=false,UseProxy=false,ConnectTimeout=TimeSpan.FromSeconds(5),MaxResponseHeadersLength=64,MaxConnectionsPerServer=2,PooledConnectionLifetime=TimeSpan.Zero};
            handler.ConnectCallback=async(context,cancel)=>
            {
                var addresses=await AddressesAsync(uri,approvedOrigin,cancel);
                foreach(var address in addresses)
                {var socket=new Socket(address.AddressFamily,SocketType.Stream,ProtocolType.Tcp){NoDelay=true};try{await socket.ConnectAsync(new IPEndPoint(address,context.DnsEndPoint.Port),cancel);return new NetworkStream(socket,true);}catch{socket.Dispose();if(cancel.IsCancellationRequested)throw;}}
                throw new ApiException(503,"source_connection_failed");
            };
            using var client=new HttpClient(handler){Timeout=Timeout.InfiniteTimeSpan};using var request=new HttpRequestMessage(method,uri){Version=HttpVersion.Version11,VersionPolicy=HttpVersionPolicy.RequestVersionExact};
            if(jsonBody is not null){request.Content=new ByteArrayContent(jsonBody);request.Content.Headers.ContentType=new System.Net.Http.Headers.MediaTypeHeaderValue("application/json");}
            if(apiKey is not null && approvedOrigin is not null && SameOrigin(uri,approvedOrigin))request.Headers.Add("X-Api-Key",apiKey);
            request.Headers.UserAgent.ParseAdd("Briani/1");using var response=await client.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,ct);
            if(response.Content.Headers.ContentLength>maxBytes)throw new ApiException(400,"source_payload_too_large");
            if((int)response.StatusCode is 301 or 302 or 303 or 307 or 308)return new((int)response.StatusCode,[],response.Headers.Location,response.Content.Headers.ContentType?.MediaType);
            using var output=new MemoryStream();await using var input=await response.Content.ReadAsStreamAsync(ct);var buffer=new byte[65536];int count;
            while((count=await input.ReadAsync(buffer,ct))>0){if(output.Length+count>maxBytes)throw new ApiException(400,"source_payload_too_large");output.Write(buffer,0,count);}
            return new((int)response.StatusCode,output.ToArray(),null,response.Content.Headers.ContentType?.MediaType);
        }
        catch(OperationCanceledException)when(caller.IsCancellationRequested){throw;}
        catch(OperationCanceledException){throw new ApiException(503,"source_timeout");}
        catch(HttpRequestException error){if(error.GetBaseException() is ApiException rejected)throw rejected;throw new ApiException(503,"source_connection_failed");}
        finally{concurrency.Release();}
    }
}
