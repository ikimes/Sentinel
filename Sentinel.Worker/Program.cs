using MassTransit;
using Microsoft.EntityFrameworkCore;
using Sentinel.Shared.Contracts;
using Sentinel.Shared.Messaging;
using Sentinel.Worker;
using Npgsql;

var builder = Host.CreateApplicationBuilder(args);

builder.AddServiceDefaults();

var adminPostgresBaseConnectionString = builder.Configuration.GetConnectionString("compliancedb_admin")
    ?? builder.Configuration.GetConnectionString("compliancedb")
    ?? throw new InvalidOperationException("Connection string 'compliancedb' is required.");
var adminPostgresConnectionString = new NpgsqlConnectionStringBuilder(adminPostgresBaseConnectionString)
{
    ApplicationName = "sentinel-worker-admin"
}.ConnectionString;
var appDbRole = builder.Configuration["Sentinel:DbAppRole"] ?? "sentinel_app";
var appDbRolePassword = builder.Configuration["Sentinel:DbAppRolePassword"] ?? "example-app-role-password";
var dbBootstrapOwner = (builder.Configuration["Sentinel:DbBootstrapOwner"] ?? "api").ToLowerInvariant();
var dbSchemaBootstrapMode = builder.Configuration["Sentinel:DbSchemaBootstrapMode"] ?? "migrate";
var runtimePostgresConnectionString = DatabaseBootstrapper.BuildRuntimeConnectionString(
    adminPostgresBaseConnectionString,
    appDbRole,
    appDbRolePassword,
    "sentinel-worker-runtime");
var messagingConnectionString = builder.Configuration.GetConnectionString("messaging")
    ?? throw new InvalidOperationException("Connection string 'messaging' is required.");
var workerOutboxQueryDelayMs = builder.Configuration.GetValue("Sentinel:WorkerOutboxQueryDelayMs", 200);
var workerOutboxQueryMessageLimit = builder.Configuration.GetValue("Sentinel:WorkerOutboxQueryMessageLimit", 500);
var workerPrefetchCount = builder.Configuration.GetValue("Sentinel:WorkerPrefetchCount", 32);
var workerConcurrentMessageLimit = builder.Configuration.GetValue("Sentinel:WorkerConcurrentMessageLimit", 16);

builder.Services.AddDbContext<MessagingDbContext>(options =>
    options.UseNpgsql(
            runtimePostgresConnectionString,
            npgsql => npgsql.MigrationsAssembly(typeof(MessagingDbContext).Assembly.FullName))
        .UseSnakeCaseNamingConvention());
builder.Services.AddSentinelMassTransitObservers("sentinel-worker");

builder.Services.AddOptions<MassTransitHostOptions>().Configure(options =>
{
    options.WaitUntilStarted = true;
    options.StartTimeout = TimeSpan.FromSeconds(45);
    options.StopTimeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddMassTransit(configurator =>
{
    configurator.SetKebabCaseEndpointNameFormatter();
    configurator.AddConsumer<ComplianceHandler>();
    configurator.AddEntityFrameworkOutbox<MessagingDbContext>(outbox =>
    {
        outbox.UsePostgres();
        outbox.QueryDelay = TimeSpan.FromMilliseconds(workerOutboxQueryDelayMs);
        outbox.QueryMessageLimit = workerOutboxQueryMessageLimit;
        outbox.QueryTimeout = TimeSpan.FromSeconds(10);
    });

    configurator.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(new Uri(messagingConnectionString), host =>
        {
            host.ConnectionName("sentinel-worker-runtime");
            host.Heartbeat(15);
            host.RequestedConnectionTimeout(TimeSpan.FromSeconds(30));
            host.ContinuationTimeout(TimeSpan.FromSeconds(30));
            host.PublisherConfirmation = true;
        });

        cfg.ReceiveEndpoint("compliance", endpoint =>
        {
            endpoint.ConfigureConsumeTopology = false;
            endpoint.PrefetchCount = checked((ushort)workerPrefetchCount);
            if (workerConcurrentMessageLimit > 0)
            {
                endpoint.ConcurrentMessageLimit = workerConcurrentMessageLimit;
            }
            endpoint.UseMessageRetry(retry => retry.Interval(MessagingPolicy.RetryCount, TimeSpan.FromSeconds(2)));
            endpoint.UseEntityFrameworkOutbox<MessagingDbContext>(context);
            endpoint.ConfigureConsumer<ComplianceHandler>(context);
            endpoint.Bind("compliance");
        });
    });
});

var host = builder.Build();

var logger = host.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation(
    "Worker schema bootstrap mode resolved. BootstrapOwner={BootstrapOwner} SchemaBootstrapMode={SchemaBootstrapMode} SteadyStateMode={SteadyStateMode}",
    dbBootstrapOwner,
    dbSchemaBootstrapMode,
    "migrate");
DatabaseBootstrapper.WaitForDatabaseReady(adminPostgresConnectionString, logger, "sentinel-worker");
if (dbBootstrapOwner is "worker" or "both")
{
    DatabaseBootstrapper.EnsureDatabaseAndSecurity(
        adminPostgresConnectionString,
        appDbRole,
        appDbRolePassword,
        logger,
        dbSchemaBootstrapMode);
}
else
{
    logger.LogInformation(
        "Database security bootstrap skipped in Worker. BootstrapOwner={BootstrapOwner}",
        dbBootstrapOwner
    );
}

var runtimeUser = new NpgsqlConnectionStringBuilder(runtimePostgresConnectionString).Username;
logger.LogInformation("Worker runtime DB role in use: {RuntimeRole}", runtimeUser);
logger.LogInformation("Worker starting. Listening on 'compliance'.");
logger.LogInformation("RabbitMQ connection configured: True. QueueName={QueueName}", "compliance");
logger.LogInformation("PostgreSQL durability configured: True. ConnectionName={ConnectionName}", "compliancedb");
logger.LogInformation(
    "Worker transport tuning. QueryDelayMs={QueryDelayMs} QueryMessageLimit={QueryMessageLimit} QueryTimeoutSeconds={QueryTimeoutSeconds} PrefetchCount={PrefetchCount} ConcurrentMessageLimit={ConcurrentMessageLimit} WaitUntilStarted={WaitUntilStarted} StartTimeoutSeconds={StartTimeoutSeconds} HeartbeatSeconds={HeartbeatSeconds} RequestedConnectionTimeoutSeconds={RequestedConnectionTimeoutSeconds} ContinuationTimeoutSeconds={ContinuationTimeoutSeconds}",
    workerOutboxQueryDelayMs,
    workerOutboxQueryMessageLimit,
    10,
    workerPrefetchCount,
    workerConcurrentMessageLimit,
    true,
    45,
    15,
    30,
    30
);

host.Run();
