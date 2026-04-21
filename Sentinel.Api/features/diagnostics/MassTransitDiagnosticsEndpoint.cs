using MassTransit;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using Sentinel.Api.Features.Compliance;
using Sentinel.Shared.Contracts;
using Sentinel.Shared.Messaging;

namespace Sentinel.Api.Features.Diagnostics;

public static class MassTransitDiagnosticsEndpoint
{
    private static readonly Uri ComplianceQueueUri = new("queue:compliance");
    private const string DiagnosticReplayMode = "diagnostic-duplicate-replay";
    private const string DiagnosticForcedFailureMode = "diagnostic-force-failure";
    private const int MaxReplayCount = 10;

    public static void Map(WebApplication app)
    {
        app.MapGet("/api/diagnostics/messaging/sender", (
            IBus bus,
            IConfiguration configuration) =>
        {
            var sendMode = configuration["Sentinel:MessageSendMode"] ?? "send";
            var endpoint = new
            {
                utc = DateTime.UtcNow,
                processId = Environment.ProcessId,
                sendMode,
                busType = bus.GetType().FullName,
                queue = "compliance",
                diagnostics = "masstransit"
            };

            return Results.Ok(endpoint);
        });

        app.MapGet("/api/diagnostics/readiness", async (
            MessagingDbContext dbContext,
            IConfiguration configuration,
            ILogger<Program> logger,
            CancellationToken cancellationToken) =>
        {
            var diagnosticsEnabled = configuration.GetValue<bool>("Sentinel:EnableDiagnosticsEndpoints");
            var databaseHealthy = true;
            var databaseStatus = "healthy";
            var outboxPending = 0;
            var inboxCount = 0;
            var dispatchRecordCount = 0;
            DateTime? latestProcessedUtc = null;
            DateTime? latestFailedUtc = null;

            try
            {
                outboxPending = await ExecuteScalarIntAsync(
                    dbContext,
                    "select count(*) from masstransit.outbox_message",
                    cancellationToken
                );
                inboxCount = await ExecuteScalarIntAsync(
                    dbContext,
                    "select count(*) from masstransit.inbox_state",
                    cancellationToken
                );
                dispatchRecordCount = await ExecuteScalarIntAsync(
                    dbContext,
                    "select count(*) from masstransit.dispatch_records",
                    cancellationToken
                );
                latestProcessedUtc = await dbContext.ComplianceLedgerEvents
                    .AsNoTracking()
                    .Where(evt => evt.Status == "processed")
                    .MaxAsync(evt => (DateTime?)evt.ProcessedAtUtc, cancellationToken);
                latestFailedUtc = await dbContext.ComplianceLedgerEvents
                    .AsNoTracking()
                    .Where(evt => evt.Status == "failed")
                    .MaxAsync(evt => (DateTime?)evt.ProcessedAtUtc, cancellationToken);
            }
            catch (Exception ex)
            {
                databaseHealthy = false;
                databaseStatus = $"degraded:{ex.GetType().Name}";
            }

            var brokerHealthy = false;
            var brokerStatus = "unknown";
            var errorQueueMessages = 0;

            try
            {
                var probe = await ProbeBrokerAsync(configuration, cancellationToken);
                brokerHealthy = probe.BrokerHealthy;
                brokerStatus = probe.BrokerStatus;
                errorQueueMessages = probe.ErrorQueueMessages;
            }
            catch (Exception ex)
            {
                brokerHealthy = false;
                brokerStatus = $"degraded:{ex.GetType().Name}";
            }

            var latestWorkerSignalUtc = latestProcessedUtc.HasValue && latestFailedUtc.HasValue
                ? (latestProcessedUtc > latestFailedUtc ? latestProcessedUtc : latestFailedUtc)
                : latestProcessedUtc ?? latestFailedUtc;

            string workerSignalStatus;
            bool workerSignalFresh;
            double? workerSignalAgeSeconds;

            if (!latestWorkerSignalUtc.HasValue)
            {
                workerSignalStatus = "unknown";
                workerSignalFresh = false;
                workerSignalAgeSeconds = null;
            }
            else
            {
                workerSignalAgeSeconds = Math.Round(
                    Math.Max(0, (DateTime.UtcNow - latestWorkerSignalUtc.Value).TotalSeconds),
                    3
                );
                workerSignalFresh = workerSignalAgeSeconds <= 300;
                workerSignalStatus = workerSignalFresh ? "fresh" : "stale";
            }

            var readiness = new DiagnosticsReadinessResponse(
                true,
                databaseHealthy,
                brokerHealthy,
                outboxPending,
                inboxCount,
                dispatchRecordCount,
                errorQueueMessages,
                latestProcessedUtc,
                latestFailedUtc,
                workerSignalFresh,
                workerSignalAgeSeconds,
                diagnosticsEnabled,
                databaseStatus,
                brokerStatus,
                workerSignalStatus
            );

            logger.LogInformation(
                "COMPLIANCE_DIAGNOSTICS_READINESS apiHealthy={ApiHealthy} databaseHealthy={DatabaseHealthy} brokerHealthy={BrokerHealthy} outboxPending={OutboxPending} errorQueueMessages={ErrorQueueMessages} workerSignalStatus={WorkerSignalStatus}",
                readiness.ApiHealthy,
                readiness.DatabaseHealthy,
                readiness.BrokerHealthy,
                readiness.OutboxPending,
                readiness.ErrorQueueMessages,
                readiness.WorkerSignalStatus
            );

            return Results.Ok(readiness);
        });

        app.MapPost("/api/diagnostics/messaging/replay-duplicate", async (
            DuplicateReplayRequest request,
            ISendEndpointProvider sendEndpointProvider,
            MessagingDbContext dbContext,
            ILogger<Program> logger,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Content))
            {
                return Results.BadRequest("Content is required");
            }

            var replayCount = request.ReplayCount <= 1 ? 2 : Math.Min(request.ReplayCount, MaxReplayCount);
            var requestId = request.RequestId ?? Guid.NewGuid();
            var messageId = request.MessageId ?? Guid.NewGuid();
            var source = string.IsNullOrWhiteSpace(request.Source) ? "diagnostics-duplicate-replay" : request.Source;
            var endpoint = await sendEndpointProvider.GetSendEndpoint(ComplianceQueueUri);
            var message = new AnalyzeComplianceRequest(requestId, request.Content, source);

            for (var i = 0; i < replayCount; i++)
            {
                await endpoint.Send(message, context =>
                {
                    context.CorrelationId = requestId;
                    context.MessageId = messageId;
                }, cancellationToken);

                dbContext.DispatchRecords.Add(new OutboxDispatchRecord
                {
                    RequestId = requestId,
                    SendMode = DiagnosticReplayMode,
                    Destination = ComplianceQueueUri.ToString(),
                    CreatedAtUtc = DateTime.UtcNow,
                    ActorId = null,
                    ActorType = null,
                    ActorDisplayName = null
                });
            }

            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogInformation(
                "COMPLIANCE_DIAGNOSTIC_REPLAY requestId={RequestId} messageId={MessageId} replayCount={ReplayCount} queue={Queue}",
                requestId,
                messageId,
                replayCount,
                "compliance"
            );

            return Results.Ok(new DuplicateReplayResponse(
                requestId,
                messageId,
                replayCount,
                ComplianceQueueUri.ToString(),
                DateTime.UtcNow
            ));
        });

        app.MapPost("/api/diagnostics/messaging/force-failure", async (
            ForcedFailureRequest request,
            ISendEndpointProvider sendEndpointProvider,
            MessagingDbContext dbContext,
            ILogger<Program> logger,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Content))
            {
                return Results.BadRequest("Content is required");
            }

            var requestId = request.RequestId ?? Guid.NewGuid();
            var messageId = request.MessageId ?? Guid.NewGuid();
            var source = string.IsNullOrWhiteSpace(request.Source) ? "diagnostics-force-failure" : request.Source;
            var endpoint = await sendEndpointProvider.GetSendEndpoint(ComplianceQueueUri);
            var message = new AnalyzeComplianceRequest(requestId, request.Content, source);

            await endpoint.Send(message, context =>
            {
                context.CorrelationId = requestId;
                context.MessageId = messageId;
            }, cancellationToken);

            dbContext.DispatchRecords.Add(new OutboxDispatchRecord
            {
                RequestId = requestId,
                SendMode = DiagnosticForcedFailureMode,
                Destination = ComplianceQueueUri.ToString(),
                CreatedAtUtc = DateTime.UtcNow,
                ActorId = null,
                ActorType = null,
                ActorDisplayName = null
            });

            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogInformation(
                "COMPLIANCE_DIAGNOSTIC_FAILURE_REQUESTED requestId={RequestId} messageId={MessageId} queue={Queue}",
                requestId,
                messageId,
                "compliance"
            );

            return Results.Ok(new ForcedFailureResponse(
                requestId,
                messageId,
                ComplianceQueueUri.ToString(),
                DateTime.UtcNow
            ));
        });
    }

    private static async Task<int> ExecuteScalarIntAsync(
        MessagingDbContext dbContext,
        string sql,
        CancellationToken cancellationToken)
    {
        var connection = dbContext.Database.GetDbConnection();
        var shouldClose = connection.State != System.Data.ConnectionState.Open;
        if (shouldClose)
        {
            await connection.OpenAsync(cancellationToken);
        }

        try
        {
            await using var command = connection.CreateCommand();
            command.CommandText = sql;
            return Convert.ToInt32(await command.ExecuteScalarAsync(cancellationToken) ?? 0);
        }
        finally
        {
            if (shouldClose)
            {
                await connection.CloseAsync();
            }
        }
    }

    private static async Task<(bool BrokerHealthy, string BrokerStatus, int ErrorQueueMessages)> ProbeBrokerAsync(
        IConfiguration configuration,
        CancellationToken cancellationToken)
    {
        var messagingConnectionString = configuration.GetConnectionString("messaging");
        if (string.IsNullOrWhiteSpace(messagingConnectionString))
        {
            return (false, "unknown:no-connection-string", 0);
        }

        var factory = new ConnectionFactory
        {
            Uri = new Uri(messagingConnectionString),
            ClientProvidedName = "sentinel-api-readiness-probe",
            AutomaticRecoveryEnabled = false
        };

        await using var connection = await factory.CreateConnectionAsync(cancellationToken);
        await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);
        await channel.QueueDeclarePassiveAsync("compliance", cancellationToken);
        await channel.QueueDeclarePassiveAsync("compliance_error", cancellationToken);
        var errorQueueMessages = Convert.ToInt32(await channel.MessageCountAsync("compliance_error", cancellationToken));

        return (true, "healthy", errorQueueMessages);
    }
}

public sealed record DuplicateReplayRequest(
    string Content,
    string? Source,
    Guid? RequestId,
    Guid? MessageId,
    int ReplayCount = 2
);

public sealed record DuplicateReplayResponse(
    Guid RequestId,
    Guid MessageId,
    int ReplayCount,
    string Destination,
    DateTime Utc
);

public sealed record ForcedFailureRequest(
    string Content,
    string? Source,
    Guid? RequestId,
    Guid? MessageId
);

public sealed record ForcedFailureResponse(
    Guid RequestId,
    Guid MessageId,
    string Destination,
    DateTime Utc
);
