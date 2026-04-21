using MassTransit;
using Microsoft.EntityFrameworkCore;
using Sentinel.Api.Features.Compliance;
using Sentinel.Api.Features.Diagnostics;
using Sentinel.Shared.Contracts;
using Sentinel.Shared.Messaging;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var adminPostgresBaseConnectionString = builder.Configuration.GetConnectionString("compliancedb_admin")
    ?? builder.Configuration.GetConnectionString("compliancedb");
var appDbRole = builder.Configuration["Sentinel:DbAppRole"] ?? "sentinel_app";
var appDbRolePassword = builder.Configuration["Sentinel:DbAppRolePassword"] ?? "example-app-role-password";
var dbBootstrapOwner = (builder.Configuration["Sentinel:DbBootstrapOwner"] ?? "api").ToLowerInvariant();
var dbSchemaBootstrapMode = builder.Configuration["Sentinel:DbSchemaBootstrapMode"] ?? "migrate";
var messagingTransportMode = (builder.Configuration["Sentinel:MessagingTransportMode"] ?? "rabbitmq")
    .Trim()
    .ToLowerInvariant();
var replayOnlyDevelopmentMode = builder.Environment.IsDevelopment()
    && string.IsNullOrWhiteSpace(adminPostgresBaseConnectionString);

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0, ComplianceApiJsonContext.Default);
});

builder.Services.AddScoped<IComplianceActorResolver, TrustedHeaderComplianceActorResolver>();

if (replayOnlyDevelopmentMode)
{
    builder.Services.AddSingleton<IComplianceAcceptanceService, ReplayOnlyComplianceAcceptanceService>();
    builder.Services.AddSingleton<IComplianceReadService, ReplayOnlyComplianceReadService>();
}
else
{
    var resolvedAdminConnectionString = adminPostgresBaseConnectionString
        ?? throw new InvalidOperationException("Connection string 'compliancedb' is required.");
    var adminPostgresConnectionString = new NpgsqlConnectionStringBuilder(resolvedAdminConnectionString)
    {
        ApplicationName = "sentinel-api-admin"
    }.ConnectionString;
    var runtimePostgresConnectionString = DatabaseBootstrapper.BuildRuntimeConnectionString(
        resolvedAdminConnectionString,
        appDbRole,
        appDbRolePassword,
        "sentinel-api-runtime");
    var messagingConnectionString = messagingTransportMode == "inmemory"
        ? null
        : builder.Configuration.GetConnectionString("messaging")
            ?? throw new InvalidOperationException("Connection string 'messaging' is required when using RabbitMQ transport.");

    builder.Services.AddScoped<IComplianceAcceptanceService, ComplianceAcceptanceService>();
    builder.Services.AddScoped<IComplianceReadService, ComplianceReadService>();
    builder.Services.AddDbContext<MessagingDbContext>(options =>
        options.UseNpgsql(
                runtimePostgresConnectionString,
                npgsql => npgsql.MigrationsAssembly(typeof(MessagingDbContext).Assembly.FullName))
            .UseSnakeCaseNamingConvention());
    builder.Services.AddSentinelMassTransitObservers("sentinel-api");

    builder.Services.AddOptions<MassTransitHostOptions>().Configure(options =>
    {
        options.WaitUntilStarted = true;
        options.StartTimeout = TimeSpan.FromSeconds(45);
        options.StopTimeout = TimeSpan.FromSeconds(30);
    });

    builder.Services.AddMassTransit(configurator =>
    {
        configurator.SetKebabCaseEndpointNameFormatter();

        configurator.AddEntityFrameworkOutbox<MessagingDbContext>(outbox =>
        {
            outbox.UsePostgres();
            outbox.UseBusOutbox(busOutbox =>
            {
                busOutbox.MessageDeliveryLimit = 100;
                busOutbox.MessageDeliveryTimeout = TimeSpan.FromSeconds(30);
            });
            outbox.QueryDelay = TimeSpan.FromMilliseconds(200);
            outbox.QueryMessageLimit = 250;
            outbox.QueryTimeout = TimeSpan.FromSeconds(30);
        });

        if (messagingTransportMode == "inmemory")
        {
            configurator.UsingInMemory((context, cfg) =>
            {
                cfg.ConfigureEndpoints(context);
            });
        }
        else
        {
            configurator.UsingRabbitMq((context, cfg) =>
            {
                cfg.Host(new Uri(messagingConnectionString!), host =>
                {
                    host.ConnectionName("sentinel-api-runtime");
                    host.Heartbeat(15);
                    host.RequestedConnectionTimeout(TimeSpan.FromSeconds(30));
                    host.ContinuationTimeout(TimeSpan.FromSeconds(30));
                    host.PublisherConfirmation = true;
                });

                cfg.Message<AnalyzeComplianceRequest>(message => message.SetEntityName("compliance"));
                cfg.Publish<AnalyzeComplianceRequest>(publish => publish.ExchangeType = "direct");

                cfg.ConfigureEndpoints(context);
            });
        }
    });

    builder.Services.AddSingleton(new RuntimeBootstrapSettings(
        resolvedAdminConnectionString,
        adminPostgresConnectionString,
        runtimePostgresConnectionString,
        messagingTransportMode));
}

builder.AddServiceDefaults();

var app = builder.Build();

var logger = app.Services.GetRequiredService<ILogger<Program>>();
if (replayOnlyDevelopmentMode)
{
    logger.LogWarning(
        "API started in replay-only development mode. Postgres and messaging were not configured, so matter queue endpoints run from the replay harness only.");
}
else
{
    logger.LogInformation(
        "API schema bootstrap mode resolved. BootstrapOwner={BootstrapOwner} SchemaBootstrapMode={SchemaBootstrapMode} SteadyStateMode={SteadyStateMode}",
        dbBootstrapOwner,
        dbSchemaBootstrapMode,
        "migrate");

    var bootstrapSettings = app.Services.GetRequiredService<RuntimeBootstrapSettings>();
    DatabaseBootstrapper.WaitForDatabaseReady(bootstrapSettings.AdminPostgresConnectionString, logger, "sentinel-api");
    if (dbBootstrapOwner is "api" or "both")
    {
        DatabaseBootstrapper.EnsureDatabaseAndSecurity(
            bootstrapSettings.AdminPostgresConnectionString,
            appDbRole,
            appDbRolePassword,
            logger,
            dbSchemaBootstrapMode);
    }
    else
    {
        logger.LogInformation(
            "Database security bootstrap skipped in API. BootstrapOwner={BootstrapOwner}",
            dbBootstrapOwner
        );
    }

    var runtimeUser = new NpgsqlConnectionStringBuilder(bootstrapSettings.RuntimePostgresConnectionString).Username;
    logger.LogInformation("API runtime DB role in use: {RuntimeRole}", runtimeUser);
    logger.LogInformation("API transport configured. Mode={TransportMode}", bootstrapSettings.MessagingTransportMode);
    logger.LogInformation("API PostgreSQL durability configured: True. ConnectionName={ConnectionName}", "compliancedb");
    logger.LogInformation(
        "API outbox tuning. QueryDelayMs={QueryDelayMs} QueryMessageLimit={QueryMessageLimit} QueryTimeoutSeconds={QueryTimeoutSeconds} MessageDeliveryLimit={MessageDeliveryLimit} MessageDeliveryTimeoutSeconds={MessageDeliveryTimeoutSeconds} WaitUntilStarted={WaitUntilStarted} StartTimeoutSeconds={StartTimeoutSeconds} HeartbeatSeconds={HeartbeatSeconds} RequestedConnectionTimeoutSeconds={RequestedConnectionTimeoutSeconds} ContinuationTimeoutSeconds={ContinuationTimeoutSeconds}",
        200,
        250,
        30,
        100,
        30,
        true,
        45,
        15,
        30,
        30
    );
}

CheckTextEndpoint.Map(app);

var diagnosticsEnabled = app.Configuration.GetValue<bool>("Sentinel:EnableDiagnosticsEndpoints");
if (diagnosticsEnabled)
{
    MassTransitDiagnosticsEndpoint.Map(app);
    logger.LogInformation("Diagnostics endpoints enabled.");
}
else
{
    logger.LogInformation("Diagnostics endpoints disabled.");
}

app.MapGet("/", () => "Sentinel API (MassTransit) is Online");
app.MapDefaultEndpoints();
app.Run();

public partial class Program { }

internal sealed record RuntimeBootstrapSettings(
    string AdminPostgresBaseConnectionString,
    string AdminPostgresConnectionString,
    string RuntimePostgresConnectionString,
    string MessagingTransportMode);
