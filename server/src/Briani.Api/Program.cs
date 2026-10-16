using System.Text.Json;
using Briani.Api.Modules.Preferences;
using Briani.Api.Modules.Downloads;
using Briani.Api.Integrations.QBittorrent;
using Briani.Api.Modules.Downloads.Queries;
using Briani.Api.Infrastructure.Integrations;
using Briani.Api.Integrations.Prowlarr;
using Briani.Api.Modules.Discovery;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Discovery.Queries;
using Briani.Api.Modules.Identity;
using Briani.Api.Modules.Administration;
using Briani.Api.Modules.Libraries.Queries;
using Briani.Api.Modules.Media.Processing;
using Briani.Api.Modules.Media;
using Briani.Api.Modules.Media.Operations;
using Briani.Api.Modules.Playback;
using Briani.Api.Infrastructure.Security;
using Briani.Api.Infrastructure.Storage;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Briani.Api.Infrastructure;
using Briani.Api.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole();
// Exclude request-path loggers: stream paths carry capabilities.
builder.Logging.AddFilter("Microsoft.AspNetCore", LogLevel.Warning);
builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.Warning);
builder.Logging.AddFilter("Microsoft.EntityFrameworkCore", LogLevel.Warning);
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    context.ProblemDetails.Extensions["traceId"] = context.HttpContext.TraceIdentifier;
    if (!context.ProblemDetails.Extensions.ContainsKey("code")) context.ProblemDetails.Extensions["code"] = "request_failed";
    var code = context.ProblemDetails.Extensions["code"] as string;
    context.ProblemDetails.Title = ErrorMessages.For(code);
    context.ProblemDetails.Detail ??= ErrorMessages.For(code);
});
builder.Services.Configure<Microsoft.AspNetCore.Http.Features.FormOptions>(o=>{o.MultipartBodyLengthLimit=16777216;o.ValueLengthLimit=16384;o.ValueCountLimit=16;o.MultipartHeadersCountLimit=16;o.MultipartHeadersLengthLimit=16384;});
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase);
builder.Services.AddOptions<ServerOptions>().Bind(builder.Configuration.GetSection("Briani"))
    .Validate(o => o.Valid(), "Briani data and state roots must be distinct absolute paths").ValidateOnStart();
builder.Services.AddSingleton(sp => sp.GetRequiredService<IOptions<ServerOptions>>().Value);
builder.Services.AddDbContext<BrianiDb>((sp, o) => o.UseSqlite($"Data Source={Path.Combine(sp.GetRequiredService<ServerOptions>().StateRoot, "briani.db")};Foreign Keys=True;Default Timeout=5;Pooling=False"));
builder.Services.AddSingleton<ServiceConnections>();builder.Services.AddSingleton<ISafeDns,SystemSafeDns>();builder.Services.AddSingleton<SafeHttp>();builder.Services.AddSingleton<IProwlarrTransport,ProwlarrTransport>();builder.Services.AddSingleton<IProwlarrClient,ProwlarrClient>();
 builder.Services.AddSingleton<DownloadJobLocks>();builder.Services.AddSingleton<ITorrentEngine,QBitTorrentClient>();builder.Services.AddScoped<DownloadCommands>();builder.Services.AddScoped<DownloadAdmission>();builder.Services.AddScoped<DownloadImport>();builder.Services.AddSingleton<DownloadWorker>();builder.Services.AddHostedService(sp=>sp.GetRequiredService<DownloadWorker>());builder.Services.AddScoped<DownloadAccess>();builder.Services.AddScoped<DiscoveryAccess>();builder.Services.AddSingleton<SourceLimits>();builder.Services.AddScoped<SourceService>();builder.Services.AddSingleton<SourceHousekeeping>();builder.Services.AddHostedService(sp=>sp.GetRequiredService<SourceHousekeeping>());builder.Services.AddSingleton<DiscoveryQueryWorker>();builder.Services.AddHostedService(sp=>sp.GetRequiredService<DiscoveryQueryWorker>());
builder.Services.AddSingleton<TimeProvider>(TimeProvider.System);
builder.Services.AddSingleton<WriteGate>();builder.Services.AddSingleton<AuthLimiter>();
builder.Services.AddSingleton<SecretStore>();builder.Services.AddSingleton<PageCursor>();builder.Services.AddSingleton<ContainedStorage>();
builder.Services.AddOptions<MediaProcessingOptions>().Bind(builder.Configuration.GetSection("MediaProcessing"));
builder.Services.AddScoped<MediaOperations>();builder.Services.AddHostedService<MutationWorker>();
builder.Services.AddSingleton<TorrentAvailability>();builder.Services.AddSingleton<MediaIndexProbe>();builder.Services.AddHostedService(sp=>sp.GetRequiredService<TorrentAvailability>());
builder.Services.AddScoped<MediaAccess>();builder.Services.AddScoped<CompletedPlayback>();builder.Services.AddScoped<ProgressivePlayback>();builder.Services.AddScoped<SubtitleDelivery>();builder.Services.AddSingleton<MediaReaders>();
builder.Services.AddSingleton<ProbeService>();builder.Services.AddSingleton<ScanWorker>();builder.Services.AddHostedService(sp=>sp.GetRequiredService<ScanWorker>());
builder.Services.AddSingleton<ApplicationOperationsWorker>();
builder.Services.AddHostedService(sp=>sp.GetRequiredService<ApplicationOperationsWorker>());
builder.Services.AddHostedService<IdentityHousekeeping>();
builder.Services.AddScoped<IdentityService>();builder.Services.AddScoped<PermissionService>();builder.Services.AddScoped<Audit>();
builder.Services.AddScoped<IPasswordHasher<User>,PasswordHasher<User>>();
builder.Services.AddAuthentication("opaque").AddScheme<AuthenticationSchemeOptions,OpaqueAuthentication>("opaque",null);
builder.Services.AddAuthorization(o=>{o.FallbackPolicy=new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build();o.AddPolicy("administrator",p=>p.RequireRole("administrator"));});
#if BRIANI_FAULT_TEST
// This registration is compiled only into the isolated fault-test artifact.
builder.Services.AddScoped<DownloadImport>(sp => {
    var importer = ActivatorUtilities.CreateInstance<DownloadImport>(sp);
    importer.TransactionBoundary = name => Briani.Api.Infrastructure.Testing.CrashBoundary.Wait("import:" + name);
    return importer;
});
#endif
var app = builder.Build();
#if BRIANI_FAULT_TEST
app.Services.GetRequiredService<DownloadWorker>().TransactionBoundary =
    name => Briani.Api.Infrastructure.Testing.CrashBoundary.Wait("download:" + name);
#endif
var options = app.Services.GetRequiredService<ServerOptions>();
Directory.CreateDirectory(options.StateRoot);
Directory.CreateDirectory(options.DataRoot);
if(!OperatingSystem.IsLinux())throw new PlatformNotSupportedException("Linux server required");
using var checkedState = new ContainedDirectory(options.StateRoot);
checkedState.RestrictPermissions();
using var checkedData = new ContainedDirectory(options.DataRoot);
using var processLock = new FileStream(Path.Combine(options.StateRoot, "owner.lock"), FileMode.OpenOrCreate,
    FileAccess.ReadWrite, FileShare.None);
app.Use(async (c,next)=> {
    try {await next(c);}
    catch(OperationCanceledException) when(c.RequestAborted.IsCancellationRequested){c.Abort();}
    catch(DbUpdateConcurrencyException){if(c.Response.HasStarted){c.Abort();return;}await Problems.WriteAsync(c,409,"version_conflict");}
    catch(ApiException e){if(c.Response.HasStarted){c.Abort();return;}await Problems.WriteAsync(c,e.Status,e.Code,e.SafeDetail,e.RetryAfterSeconds??(e.Status==429?5:null));}
    catch(BadHttpRequestException e){if(c.Response.HasStarted){c.Abort();return;}await Problems.WriteAsync(c,e.StatusCode,"invalid_request");}
    catch(Exception){if(c.Response.HasStarted){c.Abort();return;}await Problems.WriteAsync(c,500,"internal_error");}
});
app.UseStatusCodePages(c=>Problems.WriteAsync(c.HttpContext,c.HttpContext.Response.StatusCode,c.HttpContext.Response.StatusCode==404?"not_found":"request_failed"));
app.Use(async (context, next) =>
{
    var trace = Guid.NewGuid().ToString("N");
    context.TraceIdentifier = trace;
    context.Response.Headers["X-Correlation-Id"] = trace;
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers.CacheControl = "no-store";
    context.Response.Headers["Referrer-Policy"] = "no-referrer";
    await next(context);
});
var uploadSlots=new SemaphoreSlim(2,2);
app.Use(async(c,next)=>{if(c.Request.Path.Value?.TrimEnd('/').Equals("/api/v1/torrent-uploads",StringComparison.OrdinalIgnoreCase)==true && HttpMethods.IsPost(c.Request.Method)){if(!uploadSlots.Wait(0))throw new ApiException(429,"upload_limit");try{var size=c.Features.Get<Microsoft.AspNetCore.Http.Features.IHttpMaxRequestBodySizeFeature>();if(size is not null && !size.IsReadOnly)size.MaxRequestBodySize=16842752;if(c.Request.ContentLength>16842752)throw new ApiException(413,"torrent_upload_too_large");await next(c);}finally{uploadSlots.Release();}}else await next(c);});
app.Use(async(c,next)=>{
    if(c.Request.Path.StartsWithSegments("/api/v1/me/preferences") || c.Request.Path=="/api/v1/admin/settings") {
        var size=c.Features.Get<Microsoft.AspNetCore.Http.Features.IHttpMaxRequestBodySizeFeature>();
        if(size is not null && !size.IsReadOnly)size.MaxRequestBodySize=1048576;
        if(c.Request.ContentLength>1048576)throw new ApiException(413,"settings_too_large");
    }
    await next(c);
});
app.UseAuthentication();
app.UseAuthorization();
app.Use(async (c,next)=>{if(c.User.HasClaim("password_change","required") && c.Request.Path!="/api/v1/me/password" && c.Request.Path!="/api/v1/auth/logout" && c.Request.Path!="/api/v1/me"){await Problems.WriteAsync(c,403,"password_change_required");return;}await next(c);});
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<BrianiDb>();
    await db.Database.MigrateAsync();
    await db.Database.ExecuteSqlRawAsync("PRAGMA journal_mode=WAL;");
    await db.Database.ExecuteSqlRawAsync("PRAGMA synchronous=FULL;");
    if (!await db.SchemaState.AnyAsync()) { db.SchemaState.Add(new()); await db.SaveChangesAsync(); }
    var storage=app.Services.GetRequiredService<ContainedStorage>();
    var root=await db.Settings.FindAsync("storage_root_id");
    if(root is null){root=new(){Key="storage_root_id",ValueJson=Guid.NewGuid().ToString(),UpdatedAt=DateTimeOffset.UtcNow};db.Settings.Add(root);await db.SaveChangesAsync();}
    storage.RootId=root.ValueJson;
    var identity=scope.ServiceProvider.GetRequiredService<IdentityService>();
    await identity.InitializeBootstrapAsync(args.Contains("--regenerate-bootstrap"));
    if(args.Contains("--bootstrap-code") || args.Contains("--regenerate-bootstrap")) {
        if(await db.Users.AnyAsync()){Console.Error.WriteLine("Setup already claimed.");Environment.ExitCode=2;return;}
        Console.WriteLine(app.Services.GetRequiredService<SecretStore>().ReadBootstrap());return;
    }
    // Reconcile durable filesystem intents before scanners can adopt a moved path.
    await StartupRecovery.RequeueOrphanedWorkAsync(db, app.Services.GetRequiredService<TimeProvider>());
    for(var recovered=0;recovered<1000;recovered++) {
        using var recovery=app.Services.CreateScope();
        if(!await recovery.ServiceProvider.GetRequiredService<MediaOperations>().RunOnceAsync())break;
    }
}
app.MapGet("/healthz", () => Results.Ok(new { status = "alive" })).AllowAnonymous();
app.MapGet("/readyz", async (BrianiDb db, CancellationToken cancellation) => {
    try {
        using var state=new ContainedDirectory(options.StateRoot);using var data=new ContainedDirectory(options.DataRoot);
        return state.Identity==checkedState.Identity && data.Identity==checkedData.Identity && state.Volume().Writable &&
            await db.Database.CanConnectAsync(cancellation) ? Results.Ok(new { status = "ready" }) : Results.StatusCode(503);
    } catch(ApiException) { return Results.StatusCode(503); }
}).AllowAnonymous();
app.MapGet("/api/v1/server", async (BrianiDb db) => Results.Ok(new
{
    name = (await AdministratorConfiguration.ReadAsync(db))["serverName"]!.GetValue<string>(), apiMajor = 1, version = "0.1.0", bootstrapRequired = !await db.Users.AnyAsync(),
    publicBaseUrl = (await AdministratorConfiguration.ReadAsync(db))["publicBaseUrl"]?.GetValue<string>(),
    capabilities = new[] { "dockerServer" }, minimumClientVersion = "0.1.0"
})).AllowAnonymous();
app.MapIdentity();
app.MapPreferences();
app.MapAdministratorConfiguration();
ApplicationOperations.Map(app);
app.MapAdministration();
app.MapLibraryQueries();
app.MapDownloadQueries();DownloadCommands.Map(app);
ServiceConnections.Map(app);IntegrationHealth.Map(app);app.MapDiscoveryQueries();SourceService.Map(app);
CompletedPlayback.Map(app);
MediaEndpoints.Map(app);
MediaOperations.Map(app);
app.MapFallback(() => Results.NotFound()).AllowAnonymous();
app.Lifetime.ApplicationStopped.Register(processLock.Dispose);
await app.RunAsync();
public partial class Program;
