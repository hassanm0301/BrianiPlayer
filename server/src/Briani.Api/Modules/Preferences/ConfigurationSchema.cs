using System.Text.Json;
using System.Text.Json.Nodes;
using Briani.Api.Infrastructure.Security;
namespace Briani.Api.Modules.Preferences;

// Frozen OpenAPI-derived schemas are embedded with the authoritative defaults.
// No filesystem path or user-supplied schema can change the setting allowlist.
public static class ConfigurationSchema
{
    private static readonly JsonObject Schemas = Resource("Briani.settings.schemas.json");
    public static readonly JsonObject Defaults = Resource("Briani.defaults.json");
    private static JsonObject Resource(string name)
    {
        using var stream=typeof(ConfigurationSchema).Assembly.GetManifestResourceStream(name) ?? throw new InvalidOperationException("Missing configuration resource.");
        return JsonNode.Parse(stream)!.AsObject();
    }
    public static void Validate(string name,JsonElement value) {
        ValidateNode(Schemas[name]!.AsObject(),value,0,"These settings");
        if(name=="UserPreferences" && value.TryGetProperty("discoveryViews",out var views)) {
            var modes=new HashSet<string>();
            foreach(var view in views.EnumerateArray()) {
                if(!modes.Add(view.GetProperty("mode").GetString()!))throw Invalid("Each discovery view mode can only be saved once.");
                if(view.TryGetProperty("minSizeBytes",out var min) && min.ValueKind!=JsonValueKind.Null && view.TryGetProperty("maxSizeBytes",out var max) && max.ValueKind!=JsonValueKind.Null && min.GetInt64()>max.GetInt64())throw Invalid("The minimum size cannot be larger than the maximum size.");
            }
        }
    }
    private static void ValidateNode(JsonObject schema,JsonElement value,int depth,string field)
    {
        if(depth>8)throw Invalid($"{field} is nested too deeply.");
        if(value.ValueKind==JsonValueKind.Null && schema["nullable"]?.GetValue<bool>()==true)return;
        switch(schema["type"]?.GetValue<string>())
        {
            case "object":
                if(value.ValueKind!=JsonValueKind.Object)throw Invalid($"{field} must be an object.");
                var properties=schema["properties"]!.AsObject();var names=new HashSet<string>(StringComparer.Ordinal);
                foreach(var p in value.EnumerateObject())
                {if(!names.Add(p.Name)||!properties.TryGetPropertyValue(p.Name,out var child)||child is null)throw Invalid(System.Text.RegularExpressions.Regex.IsMatch(p.Name,"\\A[A-Za-z0-9_]{1,64}\\z")?$"'{p.Name}' is not a recognised setting.":"A setting name is not recognised.");ValidateNode(child.AsObject(),p.Value,depth+1,Label(p.Name));}
                foreach(var required in schema["required"]?.AsArray() ?? [])if(!names.Contains(required!.GetValue<string>()))throw Invalid($"{Label(required!.GetValue<string>())} is required.");
                break;
            case "array":
                if(value.ValueKind!=JsonValueKind.Array)throw Invalid($"{field} must be a list.");if(value.GetArrayLength()>(schema["maxItems"]?.GetValue<int>()??1000))throw Invalid($"{field} can have at most {schema["maxItems"]?.GetValue<int>()??1000} items.");
                foreach(var item in value.EnumerateArray())ValidateNode(schema["items"]!.AsObject(),item,depth+1,field);
                break;
            case "string":
                if(value.ValueKind!=JsonValueKind.String)throw Invalid($"{field} must be text.");var text=value.GetString()!;
                var maxLength=schema["maxLength"]?.GetValue<int>()??4096;var minLength=schema["minLength"]?.GetValue<int>()??0;if(text.Length>maxLength||text.Length<minLength)throw Invalid($"{field} must be {minLength}–{maxLength} characters.");if(text.Any(char.IsControl))throw Invalid($"{field} cannot contain control characters.");
                if(schema["pattern"] is JsonNode pattern && !System.Text.RegularExpressions.Regex.IsMatch(text,pattern.GetValue<string>(),System.Text.RegularExpressions.RegexOptions.CultureInvariant,TimeSpan.FromMilliseconds(100)))throw Invalid($"{field} is not in the expected format.");
                if(schema["format"]?.GetValue<string>()=="uuid" && !Guid.TryParseExact(text,"D",out _))throw Invalid($"{field} must be a valid ID.");
                if(schema["enum"] is JsonArray choices && !choices.Any(x=>x!.GetValue<string>()==text))throw Invalid($"{field} must be one of: {string.Join(", ",choices.Select(x=>x!.GetValue<string>()))}.");
                break;
            case "boolean":if(value.ValueKind is not(JsonValueKind.True or JsonValueKind.False))throw Invalid($"{field} must be on or off.");break;
            case "integer":
                if(value.ValueKind!=JsonValueKind.Number || !value.TryGetInt64(out var integer))throw Invalid($"{field} must be a whole number.");Bounds(schema,integer,field);break;
            case "number":
                if(value.ValueKind!=JsonValueKind.Number || !value.TryGetDouble(out var number)||!double.IsFinite(number))throw Invalid($"{field} must be a number.");Bounds(schema,number,field);break;
            default:throw Invalid($"{field} has an unsupported type.");
        }
    }
    private static void Bounds(JsonObject schema,double value,string field)
    {
        var min=schema["minimum"]?.GetValue<double>();var max=schema["maximum"]?.GetValue<double>();
        if(value<min || value>max)throw Invalid(min is not null && max is not null?$"{field} must be between {min} and {max}.":min is not null?$"{field} must be at least {min}.":$"{field} must be at most {max}.");
    }
    // "downloadLimitBytesPerSecond" -> "Download limit bytes per second"
    public static string Label(string name)
    {
        var words=System.Text.RegularExpressions.Regex.Replace(name,"(?<=[a-z0-9])([A-Z])"," $1").ToLowerInvariant();
        return words.Length==0?name:char.ToUpperInvariant(words[0])+words[1..];
    }
    public static JsonObject UserDefaults()
    {
        var result=Defaults["ui"]!.DeepClone().AsObject();
        result["version"]=1;result["defaultSort"]="name";result["defaultSortOrder"]="asc";result["slideshowSeconds"]=Defaults["media"]!["slideshowSeconds"]!.DeepClone();
        result["folderPreferences"]=new JsonArray();result["discoveryViews"]=new JsonArray();return result;
    }
    public static JsonObject Merge(JsonObject old,JsonElement update,long version)
    {var fresh=old.DeepClone().AsObject();foreach(var p in update.EnumerateObject())if(p.Name!="version")fresh[p.Name]=JsonNode.Parse(p.Value.GetRawText());fresh["version"]=version;return fresh;}
    private static ApiException Invalid(string detail)=>new(400,"invalid_settings",detail);
}
