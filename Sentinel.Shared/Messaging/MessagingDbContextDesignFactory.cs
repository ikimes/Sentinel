using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Sentinel.Shared.Messaging;

public sealed class MessagingDbContextDesignFactory : IDesignTimeDbContextFactory<MessagingDbContext>
{
    private const string DefaultConnectionString =
        "Host=localhost;Database=compliancedb;Username=postgres;Password=example-password";

    public MessagingDbContext CreateDbContext(string[] args)
    {
        var connectionString = ResolveConnectionString(args);
        var optionsBuilder = new DbContextOptionsBuilder<MessagingDbContext>();

        optionsBuilder
            .UseNpgsql(
                connectionString,
                npgsql => npgsql.MigrationsAssembly(typeof(MessagingDbContext).Assembly.FullName))
            .UseSnakeCaseNamingConvention();

        return new MessagingDbContext(optionsBuilder.Options);
    }

    private static string ResolveConnectionString(string[] args)
    {
        var cliConnection = args
            .FirstOrDefault(arg => arg.StartsWith("--connection=", StringComparison.OrdinalIgnoreCase));

        if (!string.IsNullOrWhiteSpace(cliConnection))
        {
            return cliConnection["--connection=".Length..];
        }

        return Environment.GetEnvironmentVariable("ConnectionStrings__compliancedb_admin")
            ?? Environment.GetEnvironmentVariable("ConnectionStrings__compliancedb")
            ?? DefaultConnectionString;
    }
}
