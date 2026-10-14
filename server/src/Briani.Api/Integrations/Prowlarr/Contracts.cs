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
