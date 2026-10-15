using System.Net;
using System.Net.Http.Json;
using System.Net.Http.Headers;
using System.Text.Json;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Playback;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Briani.MediaTests;

public sealed class DeliveryApiTests : IAsyncLifetime
{
    private readonly IdentityFixture fixture = new();
    public Task InitializeAsync() => fixture.InitializeAsync();
    public Task DisposeAsync() => fixture.DisposeAsync();

    [Fact]
    public async Task Completed_stream_supports_head_byte_ranges_validators_and_exact_bytes()
    {
        var data = Enumerable.Range(0, 64).Select(x => (byte)(x * 3)).ToArray();
        var target = await AddMedia("movie.mp4", data);
        var playback = await CreateSession(target.MediaId);
        var stream = Anonymous();

        using var head = await stream.SendAsync(new HttpRequestMessage(HttpMethod.Head, playback.Path));
        Assert.Equal(HttpStatusCode.OK, head.StatusCode);
        Assert.Equal(data.Length, head.Content.Headers.ContentLength);
        Assert.Equal("bytes", head.Headers.AcceptRanges.Single());
        var etag = head.Headers.ETag!.Tag;

        AssertBytes(data, 2, 5, await Read(stream, playback.Path, "bytes=2-5"));
        AssertBytes(data, 0, 7, await Read(stream, playback.Path, "bytes=0-7"));
        AssertBytes(data, data.Length - 4, data.Length - 1, await Read(stream, playback.Path, "bytes=-4"));
        AssertBytes(data, 1, data.Length - 1, await Read(stream, playback.Path, "bytes=1-"));
        using (var multi = await SendRange(stream, playback.Path, "bytes=0-1,4-5"))
        {
            Assert.Equal(HttpStatusCode.OK, multi.StatusCode);
            Assert.Equal(data, await multi.Content.ReadAsByteArrayAsync());
        }
        using (var overflow = await SendRange(stream, playback.Path, "bytes=999999999999999999999999-"))
            Assert.Equal(HttpStatusCode.BadRequest, overflow.StatusCode);
        using (var unsatisfied = await SendRange(stream, playback.Path, $"bytes={data.Length}-"))
        {
            Assert.Equal(HttpStatusCode.RequestedRangeNotSatisfiable, unsatisfied.StatusCode);
            Assert.Equal($"bytes */{data.Length}", unsatisfied.Content.Headers.ContentRange!.ToString());
        }
        using (var ifRangeMismatch = await SendRange(stream, playback.Path, "bytes=1-2", "\"other\""))
        {
            Assert.Equal(HttpStatusCode.OK, ifRangeMismatch.StatusCode);
            Assert.Equal(data, await ifRangeMismatch.Content.ReadAsByteArrayAsync());
        }
        using (var ifRangeMatch = await SendRange(stream, playback.Path, "bytes=1-2", etag))
            AssertBytes(data, 1, 2, await ifRangeMatch.Content.ReadAsByteArrayAsync());
        using (var noRangeIfRange = await SendNoRange(stream, playback.Path, etag))
        {
            Assert.Equal(HttpStatusCode.OK, noRangeIfRange.StatusCode);
            Assert.Equal(data, await noRangeIfRange.Content.ReadAsByteArrayAsync());
        }
        using var notModifiedRequest = new HttpRequestMessage(HttpMethod.Get, playback.Path);
        notModifiedRequest.Headers.IfNoneMatch.Add(EntityTagHeaderValue.Parse(etag));
        using var notModified = await stream.SendAsync(notModifiedRequest);
        Assert.Equal(HttpStatusCode.NotModified, notModified.StatusCode);
        using (var weakMatch = await SendConditional(stream, playback.Path, "W/" + etag)) Assert.Equal(HttpStatusCode.NotModified, weakMatch.StatusCode);
        using (var listMatch = await SendConditional(stream, playback.Path, "\"other\", " + etag)) Assert.Equal(HttpStatusCode.NotModified, listMatch.StatusCode);
        using (var wildcardMatch = await SendConditional(stream, playback.Path, "*")) Assert.Equal(HttpStatusCode.NotModified, wildcardMatch.StatusCode);
        using (var precondition = await SendIfMatch(stream, playback.Path, "\"other\"")) Assert.Equal(HttpStatusCode.PreconditionFailed, precondition.StatusCode);
        var mismatchedName = playback.Path.Replace("movie.mp4", "second.mp4", StringComparison.Ordinal);
        using var mismatch = await SendHead(stream, mismatchedName);
        Assert.Equal(HttpStatusCode.NotFound, mismatch.StatusCode);
    }

    [Fact]
    public async Task Empty_or_nonvideo_media_cannot_create_a_playback_session()
    {
        var empty = await AddMedia("empty.mp4", []);
        var unsupported = await AddMedia("still.jpg", [1, 2, 3], kind: "photo");
        Assert.Equal(HttpStatusCode.Conflict, await CreateResponse(empty.MediaId));
        Assert.Equal(HttpStatusCode.Conflict, await CreateResponse(unsupported.MediaId));
    }

    [Fact]
    public async Task Stale_metadata_generation_cannot_create_a_playback_session()
    {
        var target = await AddMedia("movie.mp4", [1, 2, 3]);
        await fixture.Host.InDb(async db =>
        {
            var metadata = await db.MediaMetadata.SingleAsync(x => x.MediaItemId == target.MediaId);
            metadata.ContentGeneration = 0;
            await db.SaveChangesAsync(); return 0;
        });
        Assert.Equal(HttpStatusCode.Conflict, await CreateResponse(target.MediaId));
    }

    [Fact]
    public async Task Image_and_thumbnail_require_current_generation_and_library_access()
    {
        var target = await AddMedia("poster.jpg", [11, 22, 33, 44], "photo");
        const string thumbPath = "cache/media/poster.jpg";
        var stateRoot = Path.Combine(fixture.Host.Root, "state");
        Directory.CreateDirectory(Path.GetDirectoryName(Path.Combine(stateRoot, thumbPath))!);
        await File.WriteAllBytesAsync(Path.Combine(stateRoot, thumbPath), [90, 91, 92]);
        var state = new ContainedDirectory(stateRoot);
        NodeIdentity thumbnailIdentity;
        using (var thumb = state.OpenFile(thumbPath)) thumbnailIdentity = ContainedDirectory.Inspect(thumb);
        state.Dispose();
        await fixture.Host.InDb(async db =>
        {
            var item = await db.MediaItems.SingleAsync(x => x.Id == target.MediaId);
            var metadata = await db.MediaMetadata.SingleAsync(x => x.MediaItemId == target.MediaId);
            metadata.Width = 2; metadata.Height = 2; metadata.ContentGeneration = item.Version;
            db.ThumbnailEntries.Add(new ThumbnailEntry { MediaItemId = item.Id, Generation = item.Version, Variant = "default",
                CacheRelativePath = thumbPath, FileIdentity = thumbnailIdentity.Key, Bytes = 3,
                CreatedAt = fixture.Host.Clock.GetUtcNow(), LastAccessedAt = fixture.Host.Clock.GetUtcNow() });
            await db.SaveChangesAsync(); return 0;
        });
        var owner = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        using (var image = await owner.GetAsync($"/api/v1/media/{target.MediaId:D}/image"))
        {
            Assert.Equal(HttpStatusCode.OK, image.StatusCode);
            Assert.Equal(new byte[] { 11, 22, 33, 44 }, await image.Content.ReadAsByteArrayAsync());
        }
        using (var thumb = await owner.GetAsync($"/api/v1/media/{target.MediaId:D}/thumbnail"))
        {
            Assert.Equal(HttpStatusCode.OK, thumb.StatusCode);
            Assert.Equal(new byte[] { 90, 91, 92 }, await thumb.Content.ReadAsByteArrayAsync());
        }
        await fixture.Host.InDb(async db =>
        {
            var metadata = await db.MediaMetadata.SingleAsync(x => x.MediaItemId == target.MediaId);
            metadata.ContentGeneration = 0;
            var thumbnail = await db.ThumbnailEntries.SingleAsync(x => x.MediaItemId == target.MediaId);
            db.ThumbnailEntries.Remove(thumbnail);
            db.ThumbnailEntries.Add(new ThumbnailEntry { MediaItemId = thumbnail.MediaItemId, Generation = 0, Variant = thumbnail.Variant,
                CacheRelativePath = thumbnail.CacheRelativePath, FileIdentity = thumbnail.FileIdentity, Bytes = thumbnail.Bytes,
                CreatedAt = thumbnail.CreatedAt, LastAccessedAt = thumbnail.LastAccessedAt });
            await db.SaveChangesAsync(); return 0;
        });
        using (var staleImage = await owner.GetAsync($"/api/v1/media/{target.MediaId:D}/image"))
            Assert.Equal(HttpStatusCode.Conflict, staleImage.StatusCode);
        using (var staleThumb = await owner.GetAsync($"/api/v1/media/{target.MediaId:D}/thumbnail"))
            Assert.Equal(HttpStatusCode.NotFound, staleThumb.StatusCode);

        var password = Credentials.NewToken();
        using var userCreated = await IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken)
            .PostAsJsonAsync("/api/v1/admin/users", new { username = "image-reader", displayName = "Image Reader", password, confirmPassword = password, role = "member" });
        userCreated.EnsureSuccessStatusCode();
        using var loginResponse = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = "image-reader", password, deviceName = "test" });
        var login = (await loginResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        var otherUser = IdentityFixture.As(fixture.Host.CreateClient(), login.AccessToken);
        using (var deniedImage = await otherUser.GetAsync($"/api/v1/media/{target.MediaId:D}/image"))
            Assert.Equal(HttpStatusCode.NotFound, deniedImage.StatusCode);
        using (var deniedThumb = await otherUser.GetAsync($"/api/v1/media/{target.MediaId:D}/thumbnail"))
            Assert.Equal(HttpStatusCode.NotFound, deniedThumb.StatusCode);
    }

    [Fact]
    public async Task Ticket_activation_idle_and_absolute_deadlines_are_enforced()
    {
        var target = await AddMedia("movie.mp4", [1, 2, 3, 4]);
        var first = await CreateSession(target.MediaId);
        fixture.Host.Clock.Advance(TimeSpan.FromMinutes(10));
        using (var expired = await SendHead(Anonymous(), first.Path)) Assert.Equal(HttpStatusCode.NotFound, expired.StatusCode);

        var idle = await CreateSession(target.MediaId);
        using (var active = await SendHead(Anonymous(), idle.Path)) Assert.Equal(HttpStatusCode.OK, active.StatusCode);
        fixture.Host.Clock.Advance(TimeSpan.FromMinutes(31));
        using (var expired = await SendHead(Anonymous(), idle.Path)) Assert.Equal(HttpStatusCode.NotFound, expired.StatusCode);

    }

    [Fact]
    public async Task Activated_ticket_expires_at_the_hard_24_hour_deadline()
    {
        var target = await AddMedia("movie.mp4", [1, 2, 3, 4]);
        var playback = await CreateSession(target.MediaId);
        using (var active = await SendHead(Anonymous(), playback.Path)) Assert.Equal(HttpStatusCode.OK, active.StatusCode);
        fixture.Host.Clock.Advance(TimeSpan.FromHours(24));
        using var expired = await SendHead(Anonymous(), playback.Path);
        Assert.Equal(HttpStatusCode.NotFound, expired.StatusCode);
    }

    [Fact]
    public async Task Access_token_expiry_preserves_activated_ticket()
    {
        var target = await AddMedia("movie.mp4", [9, 8, 7]);
        var playback = await CreateSession(target.MediaId);
        using (var active = await SendHead(Anonymous(), playback.Path)) Assert.Equal(HttpStatusCode.OK, active.StatusCode);
        fixture.Host.Clock.Advance(TimeSpan.FromMinutes(16));
        using (var stillWorks = await SendHead(Anonymous(), playback.Path)) Assert.Equal(HttpStatusCode.OK, stillWorks.StatusCode);

    }

    [Fact]
    public async Task Logout_revokes_an_activated_ticket()
    {
        var target = await AddMedia("movie.mp4", [9, 8, 7]);
        var playback = await CreateSession(target.MediaId);
        using (var active = await SendHead(Anonymous(), playback.Path)) Assert.Equal(HttpStatusCode.OK, active.StatusCode);
        using (var logout = await IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken).PostAsync("/api/v1/auth/logout", null))
            Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        using (var revoked = await SendHead(Anonymous(), playback.Path)) Assert.Equal(HttpStatusCode.NotFound, revoked.StatusCode);
    }

    [Fact]
    public async Task Logout_then_new_login_reports_old_ticket_as_revoked()
    {
        var target = await AddMedia("movie.mp4", [1, 2, 3]);
        var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var password = Credentials.NewToken();
        using var createdUser = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "delivery-status", displayName = "Delivery Status", password, confirmPassword = password, role = "member" });
        createdUser.EnsureSuccessStatusCode();
        using var firstLoginResponse = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = "delivery-status", password, deviceName = "first" });
        var firstLogin = (await firstLoginResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        await fixture.Host.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = firstLogin.User.Id, LibraryId = target.LibraryId, CanRead = true });
            await db.SaveChangesAsync(); return 0;
        });
        var firstClient = IdentityFixture.As(fixture.Host.CreateClient(), firstLogin.AccessToken);
        using var created = await firstClient.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "media", id = target.MediaId }, mode = "internal" });
        created.EnsureSuccessStatusCode();
        using var responseBody = JsonDocument.Parse(await created.Content.ReadAsStringAsync());
        var sessionId = responseBody.RootElement.GetProperty("id").GetGuid();
        var streamPath = new Uri(responseBody.RootElement.GetProperty("streamUrl").GetString()!).PathAndQuery;
        using (var active = await SendHead(Anonymous(), streamPath)) Assert.Equal(HttpStatusCode.OK, active.StatusCode);
        using (var logout = await firstClient.PostAsync("/api/v1/auth/logout", null)) Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        using var secondLoginResponse = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = "delivery-status", password, deviceName = "second" });
        var secondLogin = (await secondLoginResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        var secondClient = IdentityFixture.As(fixture.Host.CreateClient(), secondLogin.AccessToken);
        using var status = await secondClient.GetAsync($"/api/v1/playback/sessions/{sessionId:D}");
        Assert.Equal(HttpStatusCode.OK, status.StatusCode);
        using var statusJson = JsonDocument.Parse(await status.Content.ReadAsStringAsync());
        Assert.Equal("revoked", statusJson.RootElement.GetProperty("state").GetString());
    }

    [Fact]
    public async Task Ticket_and_status_are_owned_by_the_creating_user_and_library_access_is_rechecked()
    {
        var target = await AddMedia("movie.mp4", [1, 2, 3]);
        var playback = await CreateSession(target.MediaId);
        var created = await fixture.Host.InDb(async db => await db.PlaybackSessions.AsNoTracking().SingleAsync(x => x.MediaItemId == target.MediaId));
        var statusPath = $"/api/v1/playback/sessions/{created.Id:D}";

        using var memberAdmin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var password = Credentials.NewToken();
        using var userResponse = await memberAdmin.PostAsJsonAsync("/api/v1/admin/users", new { username = "delivery-member", displayName = "Delivery Member", password, confirmPassword = password, role = "member" });
        userResponse.EnsureSuccessStatusCode();
        using var loginResponse = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = "delivery-member", password, deviceName = "test" });
        var login = (await loginResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        var member = IdentityFixture.As(fixture.Host.CreateClient(), login.AccessToken);
        using var deniedStatus = await member.GetAsync(statusPath);
        Assert.Equal(HttpStatusCode.NotFound, deniedStatus.StatusCode);
        using var deniedCreate = await member.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "media", id = target.MediaId }, mode = "internal" });
        Assert.Equal(HttpStatusCode.NotFound, deniedCreate.StatusCode);
        using var allowedOwnerStatus = await IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken).GetAsync(statusPath);
        Assert.Equal(HttpStatusCode.OK, allowedOwnerStatus.StatusCode);

        await fixture.Host.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = login.User.Id, LibraryId = target.LibraryId, CanRead = true });
            await db.SaveChangesAsync();
            return 0;
        });
        using var nowAllowed = await member.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "media", id = target.MediaId }, mode = "internal" });
        Assert.Equal(HttpStatusCode.Created, nowAllowed.StatusCode);
        var own = (await nowAllowed.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();
        using var ownStatus = await member.GetAsync($"/api/v1/playback/sessions/{own:D}");
        Assert.Equal(HttpStatusCode.OK, ownStatus.StatusCode);
    }

    [Fact]
    public async Task Revoking_library_read_grant_aborts_an_active_stream()
    {
        const int payloadLength = 2 * 1024 * 1024;
        var payload = new byte[payloadLength];
        new Random(7).NextBytes(payload);
        var target = await AddMedia("movie.mp4", payload);
        var admin = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        var password = Credentials.NewToken();
        using var createdUser = await admin.PostAsJsonAsync("/api/v1/admin/users", new { username = "delivery-reader", displayName = "Delivery Reader", password, confirmPassword = password, role = "member" });
        createdUser.EnsureSuccessStatusCode();
        using var loginResponse = await fixture.Host.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new { username = "delivery-reader", password, deviceName = "test" });
        var login = (await loginResponse.Content.ReadFromJsonAsync<AuthReply>())!;
        await fixture.Host.InDb(async db =>
        {
            db.LibraryGrants.Add(new LibraryGrant { UserId = login.User.Id, LibraryId = target.LibraryId, CanRead = true });
            await db.SaveChangesAsync(); return 0;
        });
        var member = IdentityFixture.As(fixture.Host.CreateClient(), login.AccessToken);
        using var createdSession = await member.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "media", id = target.MediaId }, mode = "internal" });
        createdSession.EnsureSuccessStatusCode();
        using var sessionJson = JsonDocument.Parse(await createdSession.Content.ReadAsStringAsync());
        var streamPath = new Uri(sessionJson.RootElement.GetProperty("streamUrl").GetString()!).PathAndQuery;

        using var scope = fixture.Host.Services.CreateScope();
        var readers = fixture.Host.Services.GetRequiredService<MediaReaders>();
        var body = new GatedWriteStream();
        var context = new DefaultHttpContext();
        var lifetime = new TestRequestLifetimeFeature();
        context.Features.Set<IHttpRequestLifetimeFeature>(lifetime);
        context.Request.Method = HttpMethods.Get;
        context.Request.Headers.Host = "localhost";
        context.Response.Body = body;
        var service = scope.ServiceProvider.GetRequiredService<CompletedPlayback>();
        var ticket = new Uri(sessionJson.RootElement.GetProperty("streamUrl").GetString()!).Segments[^2].TrimEnd('/');
        var streamTask = service.StreamAsync(ticket, "movie.mp4", context);
        await body.Blocked.WaitAsync(TimeSpan.FromSeconds(3));
        Assert.True(readers.HasReaders(target.MediaId));
        await fixture.Host.InDb(async db =>
        {
            var grant = await db.LibraryGrants.SingleAsync(x => x.UserId == login.User.Id && x.LibraryId == target.LibraryId);
            grant.CanRead = false;
            await db.SaveChangesAsync(); return 0;
        });
        await body.Cancelled.WaitAsync(TimeSpan.FromSeconds(3));
        await streamTask.WaitAsync(TimeSpan.FromSeconds(3));
        Assert.False(readers.HasReaders(target.MediaId));
        Assert.True(lifetime.Aborted);
        Assert.Equal(1, body.WriteCount);
    }

    [Fact]
    public async Task Playback_creation_retry_preserves_single_session_without_persisting_raw_ticket()
    {
        var target=await AddMedia("retry.mp4",[1,2,3]);var client=IdentityFixture.As(fixture.Host.CreateClient(),fixture.Admin.AccessToken);var key=Guid.NewGuid().ToString();
        async Task<HttpResponseMessage> Send(string mode="internal"){var request=new HttpRequestMessage(HttpMethod.Post,"/api/v1/playback/sessions"){Content=JsonContent.Create(new{target=new{kind="media",id=target.MediaId},mode})};request.Headers.Add("Idempotency-Key",key);return await client.SendAsync(request);}
        using var first=await Send();Assert.Equal(HttpStatusCode.Created,first.StatusCode);var created=await first.Content.ReadFromJsonAsync<JsonElement>();var id=created.GetProperty("id").GetGuid();Assert.Equal(JsonValueKind.String,created.GetProperty("streamUrl").ValueKind);
        using var retry=await Send();var replay=await retry.Content.ReadFromJsonAsync<JsonElement>();Assert.Equal(id,replay.GetProperty("id").GetGuid());Assert.Equal(JsonValueKind.Null,replay.GetProperty("streamUrl").ValueKind);
        using var conflict=await Send("external");Assert.Equal(HttpStatusCode.Conflict,conflict.StatusCode);
        using var revoke=await client.DeleteAsync($"/api/v1/playback/sessions/{id}");revoke.EnsureSuccessStatusCode();using var after=await Send();Assert.Equal("revoked",(await after.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("state").GetString());
        Assert.Equal(1,await fixture.Host.InDb(db=>db.PlaybackSessions.CountAsync(x=>x.MediaItemId==target.MediaId)));
        var operation=await fixture.Host.InDb(db=>db.Operations.AsNoTracking().SingleAsync(x=>x.Kind=="playback-create"));Assert.Equal("{}",operation.ResultJson);Assert.DoesNotContain("/stream/",operation.PayloadJson);
    }

    private sealed record MediaTarget(Guid LibraryId, Guid MediaId);
    private async Task<MediaTarget> AddMedia(string name, byte[] bytes, string kind = "video")
    {
        var rootName = "delivery-" + Guid.NewGuid().ToString("N");
        var rootPath = Path.Combine(fixture.Host.Root, "data", rootName);
        Directory.CreateDirectory(rootPath);
        await File.WriteAllBytesAsync(Path.Combine(rootPath, name), bytes);
        var storage = fixture.Host.Services.GetRequiredService<ContainedStorage>();
        var identity = storage.ValidateLibraryRoot(rootName).Identity;
        var libraryId = Guid.NewGuid();
        var library = new Library { Id = libraryId, Name = "Delivery", RootPath = rootName, RootIdentity = identity, CreatedAt = fixture.Host.Clock.GetUtcNow() };
        NodeIdentity stat;
        using (var directory = storage.OpenLibrary(library))
        using (var file = directory.OpenFile(name)) stat = ContainedDirectory.Inspect(file);
        var media = new MediaItem { Id = Guid.NewGuid(), LibraryId = libraryId, RelativePath = name, DisplayName = name,
            SearchKey = name.ToUpperInvariant(), Kind = kind, Extension = Path.GetExtension(name), MimeType = kind == "video" ? "video/mp4" : "image/jpeg",
            SizeBytes = stat.Length, MtimeNs = stat.MtimeNs, FileIdentity = stat.Key, Lifecycle = "available", CreatedAt = fixture.Host.Clock.GetUtcNow(), IndexedAt = fixture.Host.Clock.GetUtcNow() };
        await fixture.Host.InDb(async db =>
        {
            db.Libraries.Add(library); db.MediaItems.Add(media);
            db.MediaMetadata.Add(new MediaMetadata { MediaItemId = media.Id, ProbeStatus = "ready", ContentGeneration = 1, TracksJson = "[]" });
            await db.SaveChangesAsync(); return 0;
        });
        return new(libraryId, media.Id);
    }

    private async Task<(Guid Id, string Path)> CreateSession(Guid mediaId)
    {
        var client = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        using var response = await client.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "media", id = mediaId }, mode = "internal" });
        response.EnsureSuccessStatusCode();
        using var body = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return (body.RootElement.GetProperty("id").GetGuid(), new Uri(body.RootElement.GetProperty("streamUrl").GetString()!).PathAndQuery);
    }

    private async Task<HttpStatusCode> CreateResponse(Guid mediaId)
    {
        var client = IdentityFixture.As(fixture.Host.CreateClient(), fixture.Admin.AccessToken);
        using var response = await client.PostAsJsonAsync("/api/v1/playback/sessions", new { target = new { kind = "media", id = mediaId }, mode = "internal" });
        return response.StatusCode;
    }

    private HttpClient Anonymous() => fixture.Host.CreateClient();
    private static Task<HttpResponseMessage> SendHead(HttpClient client, string path) => client.SendAsync(new HttpRequestMessage(HttpMethod.Head, path));
    private static async Task<byte[]> Read(HttpClient client, string path, string range)
    { using var response = await SendRange(client, path, range); Assert.Equal(HttpStatusCode.PartialContent, response.StatusCode); return await response.Content.ReadAsByteArrayAsync(); }
    private static async Task<HttpResponseMessage> SendRange(HttpClient client, string path, string range, string? ifRange = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, path); request.Headers.TryAddWithoutValidation("Range", range);
        if (ifRange is not null) request.Headers.TryAddWithoutValidation("If-Range", ifRange);
        return await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
    }
    private static Task<HttpResponseMessage> SendNoRange(HttpClient client, string path, string ifRange)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, path); request.Headers.TryAddWithoutValidation("If-Range", ifRange);
        return client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
    }
    private static Task<HttpResponseMessage> SendConditional(HttpClient client, string path, string ifNoneMatch)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, path); request.Headers.TryAddWithoutValidation("If-None-Match", ifNoneMatch);
        return client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
    }
    private static Task<HttpResponseMessage> SendIfMatch(HttpClient client, string path, string ifMatch)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, path); request.Headers.TryAddWithoutValidation("If-Match", ifMatch);
        return client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
    }
    private static void AssertBytes(byte[] source, int start, int end, byte[] actual) => Assert.Equal(source[start..(end + 1)], actual);

    private sealed class GatedWriteStream : Stream
    {
        private readonly TaskCompletionSource blocked = new(TaskCreationOptions.RunContinuationsAsynchronously);
        private readonly TaskCompletionSource cancelled = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task Blocked => blocked.Task;
        public Task Cancelled => cancelled.Task;
        public int WriteCount { get; private set; }
        public override async ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default)
        {
            WriteCount++;
            Assert.Equal(262144, buffer.Length);
            blocked.TrySetResult();
            using var registration = cancellationToken.Register(() => cancelled.TrySetResult());
            await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
        }
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override bool CanRead => false;
        public override bool CanSeek => false;
        public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() { }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
    }

    private sealed class TestRequestLifetimeFeature : IHttpRequestLifetimeFeature
    {
        private readonly CancellationTokenSource aborted = new();
        public CancellationToken RequestAborted { get => aborted.Token; set { } }
        public bool Aborted { get; private set; }
        public void Abort() { Aborted = true; aborted.Cancel(); }
    }
}
