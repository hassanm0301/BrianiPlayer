using System.Net;
using System.Text;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Modules.Discovery.Sources;
public sealed record ValidatedMagnet(string Uri,string? InfoHashV1,string? InfoHashV2,string[] Trackers);
public static class SourceValidation
{
    public static void Tracker(string value)
    {
        if(value.Length>2048 || !Uri.TryCreate(value,UriKind.Absolute,out var uri) || uri.Scheme is not ("http" or "https" or "udp") || uri.UserInfo!="" || uri.Fragment!="" || uri.Port is <1 or >65535 || uri.Host.Contains('%') || uri.HostNameType==UriHostNameType.Unknown)throw new ApiException(400,"unsafe_tracker");
        if(IPAddress.TryParse(uri.Host.Trim('[',']'),out var ip)){if(!NetworkAddressPolicy.IsPublic(ip))throw new ApiException(400,"unsafe_tracker");}
        else if(!uri.IdnHost.Contains('.') || uri.IdnHost.EndsWith(".local",StringComparison.OrdinalIgnoreCase) || uri.IdnHost.EndsWith(".localhost",StringComparison.OrdinalIgnoreCase) || uri.IdnHost.EndsWith(".internal",StringComparison.OrdinalIgnoreCase))throw new ApiException(400,"unsafe_tracker");
    }
    public static ValidatedMagnet Magnet(string value)
    {
        if(value.Length is <1 or >65536 || value.Any(char.IsControl) || !value.StartsWith("magnet:?",StringComparison.OrdinalIgnoreCase) || value.Contains('#'))throw new ApiException(400,"invalid_magnet");
        string? v1=null,v2=null;var trackers=new List<string>();int parameters=0;
        foreach(var field in value[8..].Split('&'))
        {
            if(++parameters>128)throw new ApiException(400,"invalid_magnet");var pair=field.Split('=',2);if(pair.Length!=2 || pair[0]=="")throw new ApiException(400,"invalid_magnet");string argument;
            try{argument=Uri.UnescapeDataString(pair[1].Replace('+',' '));}catch(UriFormatException){throw new ApiException(400,"invalid_magnet");}
            if(argument.Any(char.IsControl))throw new ApiException(400,"invalid_magnet");
            switch(pair[0])
            {
                case "xt":
                    if(argument.StartsWith("urn:btih:",StringComparison.OrdinalIgnoreCase))
                    {var hash=argument[9..];if(hash.Length==32)hash=Base32(hash);if(hash.Length!=40 || !hash.All(Uri.IsHexDigit) || v1 is not null && !v1.Equals(hash,StringComparison.OrdinalIgnoreCase))throw new ApiException(400,"invalid_magnet");v1=hash.ToLowerInvariant();}
                    else if(argument.StartsWith("urn:btmh:1220",StringComparison.OrdinalIgnoreCase))
                    {var hash=argument[13..];if(hash.Length!=64 || !hash.All(Uri.IsHexDigit) || v2 is not null && !v2.Equals(hash,StringComparison.OrdinalIgnoreCase))throw new ApiException(400,"invalid_magnet");v2=hash.ToLowerInvariant();}
                    else throw new ApiException(400,"invalid_magnet");break;
                case "tr":Tracker(argument);if(trackers.Count>=100)throw new ApiException(400,"invalid_magnet");trackers.Add(argument);break;
                case "dn":if(argument.Length>512)throw new ApiException(400,"invalid_magnet");break;
                case "xl":if(!long.TryParse(argument,out var length) || length<0)throw new ApiException(400,"invalid_magnet");break;
                default:throw new ApiException(400,"unsafe_magnet_field");
            }
        }
        if(v1 is null && v2 is null)throw new ApiException(400,"invalid_magnet");return new(value,v1,v2,trackers.Distinct(StringComparer.Ordinal).ToArray());
    }
    private static string Base32(string text)
    {
        const string alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";var data=new byte[20];int buffer=0,bits=0,index=0;
        foreach(var symbol in text.ToUpperInvariant()){var digit=alphabet.IndexOf(symbol);if(digit<0)throw new ApiException(400,"invalid_magnet");buffer=(buffer<<5)|digit;bits+=5;if(bits>=8){bits-=8;data[index++]=(byte)(buffer>>bits);}}
        return Convert.ToHexString(data).ToLowerInvariant();
    }
    public static async Task ValidateTrackerDnsAsync(IEnumerable<string> trackers,ISafeDns dns,CancellationToken ct)
    {
        foreach(var tracker in trackers.Take(101)){Tracker(tracker);var uri=new Uri(tracker);var addresses=await dns.ResolveAsync(uri.DnsSafeHost,ct);if(addresses.Length is <1 or >16 || addresses.Any(x=>!NetworkAddressPolicy.IsPublic(x)))throw new ApiException(400,"unsafe_tracker");}
    }
}
