using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Npgsql;
using System.Reflection;
using System.Linq;
using System.Threading;

namespace Sentinel.Shared.Messaging;

public static class DatabaseBootstrapper
{
    private const long SecurityBootstrapLockKey = 347_220_911_318;
    private const string DefaultSchemaBootstrapMode = "migrate";

    public static string BuildRuntimeConnectionString(
        string adminConnectionString,
        string appRole,
        string appRolePassword,
        string applicationName)
    {
        var builder = new NpgsqlConnectionStringBuilder(adminConnectionString)
        {
            Username = appRole,
            Password = appRolePassword,
            ApplicationName = applicationName
        };

        return builder.ConnectionString;
    }

    public static void EnsureDatabaseAndSecurity(
        string adminConnectionString,
        string appRole,
        string appRolePassword,
        ILogger logger,
        string schemaBootstrapMode = DefaultSchemaBootstrapMode)
    {
        var options = new DbContextOptionsBuilder<MessagingDbContext>()
            .UseNpgsql(adminConnectionString)
            .UseSnakeCaseNamingConvention()
            .Options;

        using var db = new MessagingDbContext(options);
        try
        {
            ApplySchemaBootstrap(db, logger, schemaBootstrapMode);
        }
        catch (PostgresException ex) when (ex.SqlState is "42P07" or "23505")
        {
            // Concurrent bootstrap race on first startup is safe to ignore.
        }

        using var conn = new NpgsqlConnection(adminConnectionString);
        conn.Open();

        using (var lockCmd = conn.CreateCommand())
        {
            lockCmd.CommandText = $"SELECT pg_advisory_lock({SecurityBootstrapLockKey});";
            lockCmd.ExecuteNonQuery();
        }

        try
        {
            using var cmd = conn.CreateCommand();
            cmd.CommandText = BuildGrantsSql(appRole, appRolePassword);
            cmd.ExecuteNonQuery();
        }
        finally
        {
            using var unlockCmd = conn.CreateCommand();
            unlockCmd.CommandText = $"SELECT pg_advisory_unlock({SecurityBootstrapLockKey});";
            unlockCmd.ExecuteNonQuery();
        }

        logger.LogInformation(
            "Database security bootstrap applied. RuntimeRole={RuntimeRole} LedgerTable={Schema}.{Table}",
            appRole,
            MessagingDbContext.ComplianceLedgerSchema,
            "events"
        );
    }

    private static void ApplySchemaBootstrap(
        MessagingDbContext db,
        ILogger logger,
        string schemaBootstrapMode)
    {
        var normalizedMode = (schemaBootstrapMode ?? DefaultSchemaBootstrapMode).Trim().ToLowerInvariant();
        var hasMigrations = db.Database.GetMigrations().Any();

        // Migration-first is the steady-state policy once migrations exist.
        // auto and ensurecreated remain explicit compatibility modes for transition and local proof paths.
        logger.LogInformation(
            "Database schema bootstrap policy. RequestedMode={RequestedMode} SteadyStateMode={SteadyStateMode} CompatibilityModes={CompatibilityModes}",
            normalizedMode,
            DefaultSchemaBootstrapMode,
            "auto, ensurecreated");

        switch (normalizedMode)
        {
            case "auto":
                if (hasMigrations)
                {
                    if (TryAdoptLegacyEnsureCreatedSchema(db, logger))
                    {
                        break;
                    }

                    logger.LogInformation("SchemaBootstrapMode=auto is a transitional compatibility path. EF migrations are present, so migrations will be applied.");
                    db.Database.Migrate();
                }
                else
                {
                    logger.LogInformation("SchemaBootstrapMode=auto is a transitional compatibility path. No EF migrations were found, so EnsureCreated will be used.");
                    db.Database.EnsureCreated();
                }
                break;
            case "migrate":
                if (hasMigrations)
                {
                    if (TryAdoptLegacyEnsureCreatedSchema(db, logger))
                    {
                        break;
                    }

                    logger.LogInformation("Applying EF migrations during database bootstrap. SchemaBootstrapMode=migrate");
                    db.Database.Migrate();
                }
                else
                {
                    logger.LogWarning("SchemaBootstrapMode=migrate requested, but no EF migrations were found. Falling back to EnsureCreated as transitional compatibility.");
                    db.Database.EnsureCreated();
                }
                break;
            case "ensurecreated":
                logger.LogWarning("SchemaBootstrapMode=ensurecreated is a compatibility-only local proof or transition path. Using EnsureCreated during database bootstrap.");
                db.Database.EnsureCreated();
                break;
            default:
                throw new InvalidOperationException(
                    $"Unsupported Sentinel:DbSchemaBootstrapMode '{schemaBootstrapMode}'. Expected auto, migrate, or ensurecreated.");
        }
    }

    private static bool TryAdoptLegacyEnsureCreatedSchema(MessagingDbContext db, ILogger logger)
    {
        var appliedMigrations = db.Database.GetAppliedMigrations().ToArray();
        if (appliedMigrations.Length > 0)
        {
            return false;
        }

        var availableMigrations = db.Database.GetMigrations().ToArray();
        if (availableMigrations.Length == 0)
        {
            return false;
        }

        if (!LegacySchemaExists(db))
        {
            return false;
        }

        logger.LogInformation("Existing EnsureCreated schema detected without EF migration history. Adopting baseline migration.");

        db.Database.ExecuteSqlRaw(
            """
ALTER TABLE IF EXISTS masstransit.dispatch_records
    ADD COLUMN IF NOT EXISTS actor_id character varying(128);

ALTER TABLE IF EXISTS masstransit.dispatch_records
    ADD COLUMN IF NOT EXISTS actor_type character varying(64);

ALTER TABLE IF EXISTS masstransit.dispatch_records
    ADD COLUMN IF NOT EXISTS actor_display_name character varying(256);
""");

        db.Database.ExecuteSqlRaw(
            """
CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);
""");

        var baselineMigrationId = availableMigrations[^1];
        var productVersion = ResolveProductVersion();
        db.Database.ExecuteSqlRaw(
            """
INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ({0}, {1})
ON CONFLICT ("MigrationId") DO NOTHING;
""",
            baselineMigrationId,
            productVersion);

        logger.LogInformation(
            "Legacy schema adopted as baseline migration. MigrationId={MigrationId} ProductVersion={ProductVersion}",
            baselineMigrationId,
            productVersion
        );

        return true;
    }

    private static bool LegacySchemaExists(MessagingDbContext db)
    {
        var connection = db.Database.GetDbConnection();
        var shouldClose = connection.State != System.Data.ConnectionState.Open;
        if (shouldClose)
        {
            connection.Open();
        }

        try
        {
            using var command = connection.CreateCommand();
            command.CommandText =
                """
SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE (table_schema = 'masstransit' AND table_name = 'dispatch_records')
       OR (table_schema = 'compliance_ledger' AND table_name = 'events')
       OR (table_schema = 'masstransit' AND table_name = 'outbox_message')
);
""";

            return Convert.ToBoolean(command.ExecuteScalar() ?? false);
        }
        finally
        {
            if (shouldClose)
            {
                connection.Close();
            }
        }
    }

    private static string ResolveProductVersion() =>
        typeof(DbContext).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion?
            .Split('+')[0]
        ?? "9.0.0";

    public static void WaitForDatabaseReady(
        string connectionString,
        ILogger logger,
        string serviceName,
        int maxAttempts = 30,
        int delayMilliseconds = 1000)
    {
        for (var attempt = 1; attempt <= maxAttempts; attempt++)
        {
            try
            {
                using var conn = new NpgsqlConnection(connectionString);
                conn.Open();
                using var cmd = conn.CreateCommand();
                cmd.CommandText = "SELECT 1;";
                cmd.ExecuteScalar();
                logger.LogInformation(
                    "{ServiceName} database readiness confirmed on attempt {Attempt}/{MaxAttempts}.",
                    serviceName,
                    attempt,
                    maxAttempts
                );
                return;
            }
            catch (Exception ex) when (attempt < maxAttempts)
            {
                logger.LogInformation(
                    ex,
                    "{ServiceName} database readiness wait attempt {Attempt}/{MaxAttempts} failed. Retrying in {DelayMs} ms.",
                    serviceName,
                    attempt,
                    maxAttempts,
                    delayMilliseconds
                );
                Thread.Sleep(delayMilliseconds);
            }
        }

        throw new InvalidOperationException($"{serviceName} could not connect to database after {maxAttempts} attempts.");
    }

    private static string BuildGrantsSql(string appRole, string appRolePassword)
    {
        static string Escape(string value) => value.Replace("'", "''");

        var role = Escape(appRole);
        var pass = Escape(appRolePassword);

        return $"""
DO $$
BEGIN
    BEGIN
        EXECUTE 'CREATE ROLE {role} LOGIN PASSWORD ''{pass}''';
    EXCEPTION WHEN duplicate_object THEN
        NULL;
    END;

    EXECUTE 'ALTER ROLE {role} WITH LOGIN PASSWORD ''{pass}''';
END
$$;


DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'masstransit' AND table_name = 'dispatch_records' AND column_name = 'Id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'masstransit' AND table_name = 'dispatch_records' AND column_name = 'id'
    ) THEN
        ALTER TABLE masstransit.dispatch_records RENAME COLUMN "Id" TO id;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'masstransit' AND table_name = 'dispatch_records' AND column_name = 'RequestId') THEN
        ALTER TABLE masstransit.dispatch_records RENAME COLUMN "RequestId" TO request_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'masstransit' AND table_name = 'dispatch_records' AND column_name = 'SendMode') THEN
        ALTER TABLE masstransit.dispatch_records RENAME COLUMN "SendMode" TO send_mode;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'masstransit' AND table_name = 'dispatch_records' AND column_name = 'Destination') THEN
        ALTER TABLE masstransit.dispatch_records RENAME COLUMN "Destination" TO destination;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'masstransit' AND table_name = 'dispatch_records' AND column_name = 'CreatedAtUtc') THEN
        ALTER TABLE masstransit.dispatch_records RENAME COLUMN "CreatedAtUtc" TO created_at_utc;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'RequestId') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "RequestId" TO request_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'MessageId') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "MessageId" TO message_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'CorrelationId') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "CorrelationId" TO correlation_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'ContentLength') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "ContentLength" TO content_length;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'HandlerDurationMs') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "HandlerDurationMs" TO handler_duration_ms;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'ProcessedAtUtc') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "ProcessedAtUtc" TO processed_at_utc;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'ErrorCode') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "ErrorCode" TO error_code;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'ErrorDetail') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "ErrorDetail" TO error_detail;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'compliance_ledger' AND table_name = 'events' AND column_name = 'TraceId') THEN
        ALTER TABLE compliance_ledger.events RENAME COLUMN "TraceId" TO trace_id;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA masstransit TO {role};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA masstransit TO {role};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA masstransit TO {role};
ALTER DEFAULT PRIVILEGES IN SCHEMA masstransit
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {role};
ALTER DEFAULT PRIVILEGES IN SCHEMA masstransit
    GRANT USAGE, SELECT ON SEQUENCES TO {role};

GRANT USAGE ON SCHEMA compliance_ledger TO {role};
GRANT SELECT, INSERT ON TABLE compliance_ledger.events TO {role};
REVOKE UPDATE, DELETE, TRUNCATE ON TABLE compliance_ledger.events FROM {role};

ALTER DEFAULT PRIVILEGES IN SCHEMA compliance_ledger
    GRANT SELECT, INSERT ON TABLES TO {role};
ALTER DEFAULT PRIVILEGES IN SCHEMA compliance_ledger
    REVOKE UPDATE, DELETE, TRUNCATE ON TABLES FROM {role};
ALTER DEFAULT PRIVILEGES IN SCHEMA compliance_ledger
    GRANT USAGE, SELECT ON SEQUENCES TO {role};
""";
    }
}
