using System.Collections.Concurrent;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Briani.DiscoveryTests;

/// <summary>
/// Loopback stand-in for the indexer API of Prowlarr 2.6.5.5623. Response codes and bodies
/// follow responses captured from that image: 201/202 resources, 400 validation-failure
/// arrays that echo attempted values, 404 bodies with internal detail, a text/plain "{}" for
/// a passed test, 200 for deleting an unknown ID, and only native password/API-key fields
/// masked as ******** while Cardigann extra fields come back in plain text.
/// </summary>
public sealed class FakeProwlarr : IDisposable
{
    public const string GoodKey = "fixture-secret-123";
    private const string Mask = "********";
    private readonly HttpListener listener = new();
    private readonly object gate = new();
    private readonly Dictionary<int, JsonObject> indexers = new();
    private int nextId = 1;

    public FakeProwlarr()
    {
        var probe = new TcpListener(IPAddress.Loopback, 0);
        probe.Start();
        var port = ((IPEndPoint)probe.LocalEndpoint).Port;
        probe.Stop();
        Origin = new Uri($"http://127.0.0.1:{port}/");
        listener.Prefixes.Add(Origin.AbsoluteUri);
        listener.Start();
        _ = Task.Run(LoopAsync);
        Schema = JsonNode.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Fixtures", "prowlarr-indexer-schema.json")))!.AsArray();
    }

    public sealed record Received(string Method, string Path, string Body, string? ApiKey);
    public Uri Origin { get; }
    public string ApiKey { get; } = "prowlarr-api-" + Guid.NewGuid().ToString("N");
    public JsonArray Schema { get; }
    public JsonArray Status { get; } = new();
    public string Profiles { get; set; } = "[{\"name\":\"Archive\",\"id\":7},{\"name\":\"Standard\",\"enableRss\":true,\"minimumSeeders\":1,\"id\":3}]";
    public ConcurrentQueue<Received> Requests { get; } = new();
    public ConcurrentQueue<string> Unexpected { get; } = new();
    public TaskCompletionSource? Pause { get; set; }
    public TaskCompletionSource Entered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

    public IEnumerable<Received> Calls(string method, string pathPrefix) =>
        Requests.Where(x => x.Method == method && x.Path.StartsWith(pathPrefix, StringComparison.Ordinal));

    public JsonObject Stored(int id) { lock (gate) return (JsonObject)indexers[id].DeepClone(); }
    public bool Exists(int id) { lock (gate) return indexers.ContainsKey(id); }

    /// <summary>Adds an indexer from a schema entry, setting the given field values.</summary>
    public int Seed(string definition, string name, bool enabled, IDictionary<string, JsonNode?> values, string protocol = "torrent")
    {
        var entry = (JsonObject)Schema.OfType<JsonObject>().First(x => (string?)x["definitionName"] == definition).DeepClone();
        foreach (var field in entry["fields"]!.AsArray().OfType<JsonObject>())
            if (values.TryGetValue((string)field["name"]!, out var value)) field["value"] = value?.DeepClone();
        entry["name"] = name;
        entry["enable"] = enabled;
        entry["protocol"] = protocol;
        entry["appProfileId"] = 3;
        lock (gate) return Store(entry);
    }

    private int Store(JsonObject resource)
    {
        var id = nextId++;
        resource["id"] = id;
        resource["added"] = "2026-10-17T00:00:00Z";
        indexers[id] = resource;
        return id;
    }

    private async Task LoopAsync()
    {
        while (listener.IsListening)
        {
            HttpListenerContext context;
            try { context = await listener.GetContextAsync(); }
            catch (Exception) { return; }
            _ = Task.Run(() => HandleAsync(context));
        }
    }

    private async Task HandleAsync(HttpListenerContext context)
    {
        try
        {
            using var reader = new StreamReader(context.Request.InputStream, Encoding.UTF8);
            var body = await reader.ReadToEndAsync();
            var method = context.Request.HttpMethod;
            var path = context.Request.Url!.AbsolutePath;
            var key = context.Request.Headers["X-Api-Key"];
            Requests.Enqueue(new(method, context.Request.RawUrl ?? path, body, key));
            if (Pause is { } pause) { Entered.TrySetResult(); await pause.Task; }
            var (status, type, text) = key == ApiKey ? Respond(method, path, body) : (401, "text/plain", "Unauthorized");
            var bytes = Encoding.UTF8.GetBytes(text);
            context.Response.StatusCode = status;
            context.Response.ContentType = type;
            context.Response.ContentLength64 = bytes.Length;
            await context.Response.OutputStream.WriteAsync(bytes);
            context.Response.Close();
        }
        catch (Exception) { try { context.Response.Abort(); } catch (Exception) { } }
    }

    private (int, string, string) Respond(string method, string path, string body)
    {
        const string json = "application/json; charset=utf-8";
        lock (gate)
        {
            var parts = path.Split('/', StringSplitOptions.RemoveEmptyEntries);
            int? id = parts.Length == 4 && parts[2] == "indexer" && int.TryParse(parts[3], out var parsed) ? parsed : null;
            switch (method, path)
            {
                case ("GET", "/api/v1/indexer"):
                    return (200, json, new JsonArray(indexers.Values.OrderBy(x => (string?)x["name"]).Select(Masked).ToArray<JsonNode?>()).ToJsonString());
                case ("GET", "/api/v1/indexer/schema"):
                    return (200, json, Schema.ToJsonString());
                case ("GET", "/api/v1/indexerstatus"):
                    return (200, json, Status.ToJsonString());
                case ("GET", "/api/v1/appprofile"):
                    return (200, json, Profiles);
                case ("POST", "/api/v1/indexer"):
                {
                    var resource = JsonNode.Parse(body)!.AsObject();
                    if (Duplicate(resource, null) is { } duplicate) return (400, "application/json", duplicate);
                    if ((bool?)resource["enable"] == true && Failure(resource) is { } failure) return (400, "application/json", failure);
                    var created = Store(resource);
                    return (201, json, Masked(indexers[created]).ToJsonString());
                }
                case ("POST", "/api/v1/indexer/test"):
                {
                    var resource = Restore(JsonNode.Parse(body)!.AsObject());
                    return Failure(resource) is { } failure ? (400, "application/json", failure) : (200, "text/plain; charset=utf-8", "{}");
                }
            }
            if (id is { } known)
            {
                if (method == "DELETE") { indexers.Remove(known); return (200, json, "{}"); }
                if (!indexers.TryGetValue(known, out var existing))
                    return (404, "application/json", $"{{\"message\":\"IndexerDefinition with ID {known} does not exist\",\"description\":\"NzbDrone.Core.Datastore.ModelNotFoundException at BasicRepository.cs:line 128\"}}");
                if (method == "GET") return (200, json, Masked(existing).ToJsonString());
                if (method == "PUT")
                {
                    var resource = Restore(JsonNode.Parse(body)!.AsObject(), existing);
                    if ((bool?)resource["enable"] == true && Failure(resource) is { } failure) return (400, "application/json", failure);
                    resource["id"] = known;
                    indexers[known] = resource;
                    return (202, json, Masked(resource).ToJsonString());
                }
            }
            Unexpected.Enqueue(method + " " + path);
            return (500, "text/plain", "unexpected");
        }
    }

    private string? Duplicate(JsonObject resource, int? self) =>
        indexers.Any(x => x.Key != self && (string?)x.Value["name"] == (string?)resource["name"])
            ? new JsonArray(new JsonObject { ["propertyName"] = "Name", ["errorMessage"] = "Should be unique", ["attemptedValue"] = (string?)resource["name"], ["severity"] = "error", ["errorCode"] = "PredicateValidator" }).ToJsonString()
            : null;

    // The fixture site accepts only GoodKey; Prowlarr's failure text quotes the request URL.
    private static string? Failure(JsonObject resource)
    {
        var key = Field(resource, "apikey") ?? Field(resource, "cookie");
        if (key is null || key == GoodKey) return null;
        return new JsonArray(new JsonObject
        {
            ["isWarning"] = false, ["propertyName"] = "",
            ["errorMessage"] = $"Unable to connect to indexer. HTTP request failed: [401:Unauthorized] [GET] at [https://brianifixture.invalid/api/torrents?passkey={key}]",
            ["attemptedValue"] = key, ["severity"] = "error"
        }).ToJsonString();
    }

    private static string? Field(JsonObject resource, string name) =>
        resource["fields"]?.AsArray().OfType<JsonObject>().FirstOrDefault(x => (string?)x["name"] == name)?["value"] is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;

    private static bool Private(JsonObject field) => (string?)field["privacy"] is "password" or "apiKey";

    private static JsonObject Masked(JsonObject resource)
    {
        var copy = (JsonObject)resource.DeepClone();
        foreach (var field in copy["fields"]!.AsArray().OfType<JsonObject>())
            if (Private(field) && field["value"] is JsonValue value && value.TryGetValue<string>(out var text) && text.Length > 0) field["value"] = Mask;
        return copy;
    }

    private JsonObject Restore(JsonObject resource, JsonObject? existing = null)
    {
        existing ??= (int?)resource["id"] is { } id && indexers.TryGetValue(id, out var found) ? found : null;
        if (existing is null) return resource;
        foreach (var field in resource["fields"]!.AsArray().OfType<JsonObject>())
            if (field["value"] is JsonValue value && value.TryGetValue<string>(out var text) && text == Mask)
                field["value"] = existing["fields"]!.AsArray().OfType<JsonObject>().First(x => (string?)x["name"] == (string?)field["name"])["value"]?.DeepClone();
        return resource;
    }

    public void Dispose()
    {
        Pause?.TrySetResult();
        listener.Close();
    }
}
