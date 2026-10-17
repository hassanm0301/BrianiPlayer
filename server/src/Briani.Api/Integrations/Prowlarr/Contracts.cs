using System.Globalization;
using System.Text.RegularExpressions;
namespace Briani.Api.Integrations.Prowlarr;
public sealed record ProviderInfo(string Id,string Name,bool Enabled,bool SupportsSearch,bool SupportsRecent,long[] Categories,string State="unknown",string? Warning=null);
public sealed record ProwlarrSearch(string Mode,string Query,long[] Categories);
public sealed record ProwlarrRelease(string SourceGuid,string Title,long? SizeBytes,long? Seeders,long? Leechers,DateTimeOffset? PublishedAt,long[] Categories,string? InfoHashV1,string? InfoHashV2,string? DownloadUrl,string? MagnetUri);
public sealed record ProviderResults(ProviderInfo Provider,ProwlarrRelease[] Releases,bool Truncated,string? Warning=null);
public interface IProwlarrClient
{
    Task<ProviderInfo[]> ProvidersAsync(CancellationToken ct=default);
    Task<ProviderResults> SearchAsync(ProviderInfo provider,ProwlarrSearch query,CancellationToken ct=default);
}
// Transport is parent-owned: bounded payload, configured-origin credentials,
// no automatic redirects, protected connection settings, and safe failures.
public interface IProwlarrTransport {Task<byte[]> GetAsync(string relativePath,CancellationToken ct=default);}
public sealed class ProwlarrFailure(string code):Exception(code){public string Code {get;}=code;}

// Indexer administration reaches Prowlarr only through these fixed operations; a call
// cannot be built for any other method or path, and the transport re-checks the pair.
public sealed class ProwlarrCall
{
    private static readonly (HttpMethod Method,Regex Path)[] Allowed=
    [
        (HttpMethod.Get,new("\\A/api/v1/indexer\\z")),(HttpMethod.Get,new("\\A/api/v1/indexer/[1-9][0-9]{0,9}\\z")),
        (HttpMethod.Get,new("\\A/api/v1/indexer/schema\\z")),(HttpMethod.Get,new("\\A/api/v1/indexerstatus\\z")),(HttpMethod.Get,new("\\A/api/v1/appprofile\\z")),
        (HttpMethod.Post,new("\\A/api/v1/indexer\\z")),(HttpMethod.Put,new("\\A/api/v1/indexer/[1-9][0-9]{0,9}\\z")),
        (HttpMethod.Post,new("\\A/api/v1/indexer/test\\z")),(HttpMethod.Delete,new("\\A/api/v1/indexer/[1-9][0-9]{0,9}\\z")),
    ];
    private ProwlarrCall(HttpMethod method,string path,byte[]? body,int maxResponseBytes){Method=method;Path=path;Body=body;MaxResponseBytes=maxResponseBytes;}
    public HttpMethod Method {get;}
    public string Path {get;}
    public byte[]? Body {get;}
    public int MaxResponseBytes {get;}
    public static ProwlarrCall ListIndexers()=>new(HttpMethod.Get,"/api/v1/indexer",null,4194304);
    public static ProwlarrCall GetIndexer(int id)=>new(HttpMethod.Get,"/api/v1/indexer/"+Id(id),null,1048576);
    // The full schema of every definition is several MiB in Prowlarr 2.6.5.
    public static ProwlarrCall IndexerSchema()=>new(HttpMethod.Get,"/api/v1/indexer/schema",null,16777216);
    public static ProwlarrCall IndexerStatus()=>new(HttpMethod.Get,"/api/v1/indexerstatus",null,2097152);
    public static ProwlarrCall AppProfiles()=>new(HttpMethod.Get,"/api/v1/appprofile",null,262144);
    public static ProwlarrCall CreateIndexer(byte[] body)=>new(HttpMethod.Post,"/api/v1/indexer",Bounded(body),1048576);
    public static ProwlarrCall UpdateIndexer(int id,byte[] body)=>new(HttpMethod.Put,"/api/v1/indexer/"+Id(id),Bounded(body),1048576);
    public static ProwlarrCall TestIndexer(byte[] body)=>new(HttpMethod.Post,"/api/v1/indexer/test",Bounded(body),262144);
    public static ProwlarrCall DeleteIndexer(int id)=>new(HttpMethod.Delete,"/api/v1/indexer/"+Id(id),null,65536);
    public static bool Permits(HttpMethod method,string path)=>path.Length<=64 && Allowed.Any(x=>x.Method==method && x.Path.IsMatch(path));
    private static string Id(int id)=>id>0?id.ToString(CultureInfo.InvariantCulture):throw new ArgumentOutOfRangeException(nameof(id));
    private static byte[] Bounded(byte[] body)=>body is {Length:>0 and <=1048576}?body:throw new ArgumentOutOfRangeException(nameof(body));
}
public sealed record ProwlarrReply(int Status,byte[] Body);
public interface IProwlarrAdminTransport {Task<ProwlarrReply> SendAsync(ProwlarrCall call,CancellationToken ct=default);}
