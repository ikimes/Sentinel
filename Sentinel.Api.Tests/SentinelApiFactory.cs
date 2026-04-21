using DotNet.Testcontainers.Configurations;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Npgsql;
using Testcontainers.PostgreSql;

namespace Sentinel.Api.Tests;

public sealed class PostgreSqlFixture : IAsyncLifetime
{
    static PostgreSqlFixture()
    {
        var dockerConfigDirectory = Path.Combine(Path.GetTempPath(), "sentinel-testcontainers-docker");
        Directory.CreateDirectory(dockerConfigDirectory);
        File.WriteAllText(Path.Combine(dockerConfigDirectory, "config.json"), """{"auths":{}}""");

        Environment.SetEnvironmentVariable("DOCKER_CONFIG", dockerConfigDirectory);
        Environment.SetEnvironmentVariable("TESTCONTAINERS_RYUK_DISABLED", "true");
        TestcontainersSettings.ResourceReaperEnabled = false;
    }

    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:16-alpine")
        .WithDatabase("postgres")
        .WithUsername("postgres")
        .WithPassword("postgres")
        .Build();

    public Task InitializeAsync() => _container.StartAsync();

    public Task DisposeAsync() => _container.DisposeAsync().AsTask();

    public async Task<string> CreateDatabaseAsync()
    {
        var databaseName = $"sentinel_tests_{Guid.NewGuid():N}";

        await using var connection = new NpgsqlConnection(_container.GetConnectionString());
        await connection.OpenAsync();

        await using var command = connection.CreateCommand();
        command.CommandText = $"""CREATE DATABASE "{databaseName}" """;
        await command.ExecuteNonQueryAsync();

        return new NpgsqlConnectionStringBuilder(_container.GetConnectionString())
        {
            Database = databaseName
        }.ConnectionString;
    }
}

internal sealed class SentinelApiFactory : WebApplicationFactory<Program>
{
    private readonly string _adminConnectionString;
    private readonly Dictionary<string, string?> _previousEnvironmentValues = new();

    public SentinelApiFactory(string adminConnectionString)
    {
        _adminConnectionString = adminConnectionString;
        SetEnvironmentVariable("ConnectionStrings__compliancedb_admin", adminConnectionString);
        SetEnvironmentVariable("ConnectionStrings__compliancedb", adminConnectionString);
        SetEnvironmentVariable("Sentinel__MessagingTransportMode", "inmemory");
        SetEnvironmentVariable("Sentinel__EnableDiagnosticsEndpoints", "false");
        SetEnvironmentVariable("Sentinel__DbBootstrapOwner", "api");
        SetEnvironmentVariable("Sentinel__DbSchemaBootstrapMode", "auto");
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureAppConfiguration((_, configurationBuilder) =>
        {
            configurationBuilder.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:compliancedb_admin"] = _adminConnectionString,
                ["ConnectionStrings:compliancedb"] = _adminConnectionString,
                ["Sentinel:MessagingTransportMode"] = "inmemory",
                ["Sentinel:EnableDiagnosticsEndpoints"] = "false",
                ["Sentinel:DbBootstrapOwner"] = "api",
                ["Sentinel:DbSchemaBootstrapMode"] = "auto"
            });
        });
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            foreach (var environmentValue in _previousEnvironmentValues)
            {
                Environment.SetEnvironmentVariable(environmentValue.Key, environmentValue.Value);
            }
        }

        base.Dispose(disposing);
    }

    private void SetEnvironmentVariable(string key, string value)
    {
        if (!_previousEnvironmentValues.ContainsKey(key))
        {
            _previousEnvironmentValues[key] = Environment.GetEnvironmentVariable(key);
        }

        Environment.SetEnvironmentVariable(key, value);
    }
}
