var builder = DistributedApplication.CreateBuilder(args);
var rabbitImageTag = builder.Configuration["Sentinel:RabbitImageTag"] ?? "3.13-management";
var messageSendMode = builder.Configuration["Sentinel:MessageSendMode"] ?? "send";
var diagnosticsEnabled = builder.Configuration["Sentinel:EnableDiagnosticsEndpoints"] ?? "false";
var dbAppRole = builder.Configuration["Sentinel:DbAppRole"] ?? "sentinel_app";
var dbAppRolePassword = builder.Configuration["Sentinel:DbAppRolePassword"] ?? "example-app-role-password";
var dbBootstrapOwner = builder.Configuration["Sentinel:DbBootstrapOwner"] ?? "api";
var dbSchemaBootstrapMode = builder.Configuration["Sentinel:DbSchemaBootstrapMode"] ?? "auto";
var workerPrefetchCount = builder.Configuration["Sentinel:WorkerPrefetchCount"] ?? "32";
var workerConcurrentMessageLimit = builder.Configuration["Sentinel:WorkerConcurrentMessageLimit"] ?? "16";
var workerOutboxQueryDelayMs = builder.Configuration["Sentinel:WorkerOutboxQueryDelayMs"] ?? "200";
var workerOutboxQueryMessageLimit = builder.Configuration["Sentinel:WorkerOutboxQueryMessageLimit"] ?? "500";

// 1. Create the Server (Infrastructure)
var rabbit = builder.AddRabbitMQ("messaging")
    .WithImageTag(rabbitImageTag)
    .WithManagementPlugin();
var postgres = builder.AddPostgres("postgres");
var complianceDatabase = postgres.AddDatabase("compliancedb");

// 2. Wire up the API (Producer)
// We pass the 'rabbit' resource variable directly. 
// Aspire handles the connection string injection behind the scenes.
var api = builder.AddProject<Projects.Sentinel_Api>("sentinel-api")
    .WithEnvironment("Sentinel__MessageSendMode", messageSendMode)
    .WithEnvironment("Sentinel__EnableDiagnosticsEndpoints", diagnosticsEnabled)
    .WithEnvironment("Sentinel__DbAppRole", dbAppRole)
    .WithEnvironment("Sentinel__DbAppRolePassword", dbAppRolePassword)
    .WithEnvironment("Sentinel__DbBootstrapOwner", dbBootstrapOwner)
    .WithEnvironment("Sentinel__DbSchemaBootstrapMode", dbSchemaBootstrapMode)
    .WithReference(rabbit)
    .WithReference(complianceDatabase)
    .WaitFor(rabbit)
    .WaitFor(complianceDatabase);

// 3. Wire up the Worker (Consumer)
var worker = builder.AddProject<Projects.Sentinel_Worker>("sentinel-worker")
    .WithEnvironment("Sentinel__DbAppRole", dbAppRole)
    .WithEnvironment("Sentinel__DbAppRolePassword", dbAppRolePassword)
    .WithEnvironment("Sentinel__DbBootstrapOwner", dbBootstrapOwner)
    .WithEnvironment("Sentinel__DbSchemaBootstrapMode", dbSchemaBootstrapMode)
    .WithEnvironment("Sentinel__WorkerPrefetchCount", workerPrefetchCount)
    .WithEnvironment("Sentinel__WorkerConcurrentMessageLimit", workerConcurrentMessageLimit)
    .WithEnvironment("Sentinel__WorkerOutboxQueryDelayMs", workerOutboxQueryDelayMs)
    .WithEnvironment("Sentinel__WorkerOutboxQueryMessageLimit", workerOutboxQueryMessageLimit)
    .WithReference(rabbit)
    .WithReference(complianceDatabase)
    .WaitFor(rabbit)
    .WaitFor(complianceDatabase);

var web = builder.AddProject("sentinel-web", "../Sentinel.Web/Sentinel.Web.csproj")
    .WithReference(api)
    .WaitFor(api)
    .WithExternalHttpEndpoints();

builder.Build().Run();
