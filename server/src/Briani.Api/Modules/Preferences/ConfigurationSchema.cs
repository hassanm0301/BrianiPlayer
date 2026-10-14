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
        ValidateNode(Schemas[name]!.AsObject(),value,0);
        if(name=="UserPreferences" && value.TryGetProperty("discoveryViews",out var views)) {
            var modes=new HashSet<string>();
            foreach(var view in views.EnumerateArray()) {
                if(!modes.Add(view.GetProperty("mode").GetString()!))throw Invalid();
                if(view.TryGetProperty("minSizeBytes",out var min) && min.ValueKind!=JsonValueKind.Null && view.TryGetProperty("maxSizeBytes",out var max) && max.ValueKind!=JsonValueKind.Null && min.GetInt64()>max.GetInt64())throw Invalid();
            }
        }
    }
    private static void ValidateNode(JsonObject schema,JsonElement value,int depth)
    {
        if(depth>8)throw Invalid();
        if(value.ValueKind==JsonValueKind.Null && schema["nullable"]?.GetValue<bool>()==true)return;
        switch(schema["type"]?.GetValue<string>())
        {
            case "object":
                if(value.ValueKind!=JsonValueKind.Object)throw Invalid();
                var properties=schema["properties"]!.AsObject();var names=new HashSet<string>(StringComparer.Ordinal);
                foreach(var p in value.EnumerateObject())
                {if(!names.Add(p.Name)||!properties.TryGetPropertyValue(p.Name,out var child)||child is null)throw Invalid();ValidateNode(child.AsObject(),p.Value,depth+1);}
                foreach(var required in schema["required"]?.AsArray() ?? [])if(!names.Contains(required!.GetValue<string>()))throw Invalid();
                break;
            case "array":
                if(value.ValueKind!=JsonValueKind.Array || value.GetArrayLength()>(schema["maxItems"]?.GetValue<int>()??1000))throw Invalid();
                foreach(var item in value.EnumerateArray())ValidateNode(schema["items"]!.AsObject(),item,depth+1);
                break;
            case "string":
                if(value.ValueKind!=JsonValueKind.String)throw Invalid();var text=value.GetString()!;
                if(text.Length>(schema["maxLength"]?.GetValue<int>()??4096)||text.Length<(schema["minLength"]?.GetValue<int>()??0)||text.Any(char.IsControl))throw Invalid();
                if(schema["pattern"] is JsonNode pattern && !System.Text.RegularExpressions.Regex.IsMatch(text,pattern.GetValue<string>(),System.Text.RegularExpressions.RegexOptions.CultureInvariant,TimeSpan.FromMilliseconds(100)))throw Invalid();
                if(schema["format"]?.GetValue<string>()=="uuid" && !Guid.TryParseExact(text,"D",out _))throw Invalid();
                if(schema["enum"] is JsonArray choices && !choices.Any(x=>x!.GetValue<string>()==text))throw Invalid();
                break;
            case "boolean":if(value.ValueKind is not(JsonValueKind.True or JsonValueKind.False))throw Invalid();break;
            case "integer":
                if(value.ValueKind!=JsonValueKind.Number || !value.TryGetInt64(out var integer))throw Invalid();Bounds(schema,integer);break;
            case "number":
                if(value.ValueKind!=JsonValueKind.Number || !value.TryGetDouble(out var number)||!double.IsFinite(number))throw Invalid();Bounds(schema,number);break;
            default:throw Invalid();
        }
    }
    private static void Bounds(JsonObject schema,double value)
    {if(schema["minimum"] is JsonNode min && value<min.GetValue<double>() || schema["maximum"] is JsonNode max && value>max.GetValue<double>())throw Invalid();}
    public static JsonObject UserDefaults()
    {
        var result=Defaults["ui"]!.DeepClone().AsObject();
        result["version"]=1;result["defaultSort"]="name";result["defaultSortOrder"]="asc";result["slideshowSeconds"]=Defaults["media"]!["slideshowSeconds"]!.DeepClone();
        result["folderPreferences"]=new JsonArray();result["discoveryViews"]=new JsonArray();return result;
    }
    public static JsonObject Merge(JsonObject old,JsonElement update,long version)
    {var fresh=old.DeepClone().AsObject();foreach(var p in update.EnumerateObject())if(p.Name!="version")fresh[p.Name]=JsonNode.Parse(p.Value.GetRawText());fresh["version"]=version;return fresh;}
    private static ApiException Invalid()=>new(400,"invalid_settings");
}
