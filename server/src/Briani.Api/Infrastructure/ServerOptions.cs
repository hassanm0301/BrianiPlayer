namespace Briani.Api.Infrastructure;
public sealed class ServerOptions
{
    public bool BackgroundDownloads {get;set;}=true;
    public bool BackgroundDiscovery {get;set;}=true;
    public bool BackgroundMediaOperations {get;set;}=true;
    public string SecretsRoot { get; set; } = "/run/briani-secrets";
    public string StateRoot { get; set; } = "/config";
    public string DataRoot { get; set; } = "/data";
    public bool Valid()
    {
        if(!Path.IsPathFullyQualified(SecretsRoot)||SecretsRoot=="/"||Path.GetFullPath(SecretsRoot)!=SecretsRoot)return false;
        if(!Path.IsPathFullyQualified(StateRoot)||!Path.IsPathFullyQualified(DataRoot))return false;
        var a=Path.TrimEndingDirectorySeparator(Path.GetFullPath(StateRoot));var b=Path.TrimEndingDirectorySeparator(Path.GetFullPath(DataRoot));
        return a!="/" && b!="/" && a!=b && !a.StartsWith(b+"/",StringComparison.Ordinal) && !b.StartsWith(a+"/",StringComparison.Ordinal) && a==Path.TrimEndingDirectorySeparator(StateRoot) && b==Path.TrimEndingDirectorySeparator(DataRoot);
    }
}
