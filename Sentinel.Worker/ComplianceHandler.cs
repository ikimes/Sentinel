using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using MassTransit;
using Microsoft.EntityFrameworkCore;
using Sentinel.Shared.Contracts;
using Sentinel.Shared.Messaging;

namespace Sentinel.Worker;

public class ComplianceHandler(
    ILogger<ComplianceHandler> logger,
    MessagingDbContext dbContext,
    IServiceScopeFactory serviceScopeFactory,
    IConfiguration configuration) : IConsumer<AnalyzeComplianceRequest>
{
    private const string ProcessedStatus = "processed";
    private const string DuplicateSkippedStatus = "duplicate_skipped";
    private const string FailedStatus = "failed";
    private const int MaxErrorDetailLength = 2048;
    private const string DiagnosticsFailureSource = "diagnostics-force-failure";

    public static int HandledCount;

    public async Task Consume(ConsumeContext<AnalyzeComplianceRequest> context)
    {
        var startedUtc = DateTime.UtcNow;
        var stopwatch = Stopwatch.StartNew();
        var message = context.Message;
        var messageId = ResolveMessageId(context.MessageId, message);

        try
        {
            if (!context.MessageId.HasValue)
            {
                logger.LogWarning(
                    "COMPLIANCE_MESSAGEID_FALLBACK requestId={RequestId} fallbackMessageId={MessageId}",
                    message.RequestId,
                    messageId
                );
            }
            logger.LogInformation(
                "COMPLIANCE_WORKER_RECEIVED requestId={RequestId} correlationId={CorrelationId} messageId={MessageId} source={Source} contentLength={ContentLength} service={Service} processId={ProcessId}",
                message.RequestId,
                context.CorrelationId,
                messageId,
                message.Source ?? "unknown",
                message.Content.Length,
                "sentinel-worker",
                Environment.ProcessId
            );

            var isDuplicate = await dbContext.ComplianceLedgerEvents.AnyAsync(x =>
                x.MessageId == messageId &&
                (x.Status == ProcessedStatus || x.Status == DuplicateSkippedStatus || x.Status == FailedStatus),
                context.CancellationToken
            );

            if (isDuplicate)
            {
                logger.LogInformation(
                    "COMPLIANCE_DUPLICATE_SKIPPED requestId={RequestId} messageId={MessageId}",
                    message.RequestId,
                    messageId
                );
                return;
            }

            var diagnosticsEnabled = configuration.GetValue<bool>("Sentinel:EnableDiagnosticsEndpoints");
            if (diagnosticsEnabled &&
                string.Equals(message.Source, DiagnosticsFailureSource, StringComparison.OrdinalIgnoreCase))
            {
                logger.LogWarning(
                    "COMPLIANCE_DIAGNOSTIC_FAILURE_INJECTED requestId={RequestId} messageId={MessageId}",
                    message.RequestId,
                    messageId
                );
                throw new InvalidOperationException("Phase 4 diagnostics forced failure");
            }

            Interlocked.Increment(ref HandledCount);
            stopwatch.Stop();
            var durationMs = checked((int)stopwatch.ElapsedMilliseconds);

            dbContext.ComplianceLedgerEvents.Add(new ComplianceLedgerEvent
            {
                RequestId = message.RequestId,
                MessageId = messageId,
                CorrelationId = context.CorrelationId,
                Source = message.Source,
                ContentLength = message.Content.Length,
                Status = ProcessedStatus,
                HandlerDurationMs = durationMs,
                ProcessedAtUtc = startedUtc,
                TraceId = Activity.Current?.TraceId.ToString()
            });
            await dbContext.SaveChangesAsync(context.CancellationToken);

            logger.LogInformation(
                "COMPLIANCE_LEDGER_WRITTEN requestId={RequestId} messageId={MessageId} status={Status} durationMs={DurationMs}",
                message.RequestId,
                messageId,
                ProcessedStatus,
                durationMs
            );
            logger.LogInformation(
                "COMPLIANCE_WORKER_PROCESSED requestId={RequestId} service={Service} processId={ProcessId}",
                message.RequestId,
                "sentinel-worker",
                Environment.ProcessId
            );
            logger.LogInformation(
                "Processed compliance request {RequestId} from {Source}. ContentLength={ContentLength}",
                message.RequestId,
                message.Source,
                message.Content.Length
            );
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            var durationMs = checked((int)stopwatch.ElapsedMilliseconds);
            var retryAttempt = context.GetRetryAttempt();
            var isFinalAttempt = retryAttempt >= MessagingPolicy.RetryCount;

            if (isFinalAttempt)
            {
                try
                {
                    await using var terminalScope = serviceScopeFactory.CreateAsyncScope();
                    var terminalDbContext = terminalScope.ServiceProvider.GetRequiredService<MessagingDbContext>();

                    var terminalRecordExists = await terminalDbContext.ComplianceLedgerEvents.AnyAsync(
                        x => x.MessageId == messageId,
                        context.CancellationToken
                    );

                    if (!terminalRecordExists)
                    {
                        var errorDetail = ex.ToString();
                        if (errorDetail.Length > MaxErrorDetailLength)
                        {
                            errorDetail = errorDetail[..MaxErrorDetailLength];
                        }

                        terminalDbContext.ComplianceLedgerEvents.Add(new ComplianceLedgerEvent
                        {
                            RequestId = message.RequestId,
                            MessageId = messageId,
                            CorrelationId = context.CorrelationId,
                            Source = message.Source,
                            ContentLength = message.Content.Length,
                            Status = FailedStatus,
                            HandlerDurationMs = durationMs,
                            ProcessedAtUtc = DateTime.UtcNow,
                            ErrorCode = ex.GetType().Name,
                            ErrorDetail = errorDetail,
                            TraceId = Activity.Current?.TraceId.ToString()
                        });
                        await terminalDbContext.SaveChangesAsync(context.CancellationToken);

                        logger.LogError(
                            "COMPLIANCE_LEDGER_WRITTEN requestId={RequestId} messageId={MessageId} status={Status} durationMs={DurationMs}",
                            message.RequestId,
                            messageId,
                            FailedStatus,
                            durationMs
                        );
                    }
                }
                catch (Exception ledgerEx)
                {
                    logger.LogWarning(
                        ledgerEx,
                        "COMPLIANCE_LEDGER_FAILED_WRITE requestId={RequestId} messageId={MessageId} retryAttempt={RetryAttempt}",
                        message.RequestId,
                        messageId,
                        retryAttempt
                    );
                }
            }

            logger.LogError(
                ex,
                "COMPLIANCE_WORKER_FAILED requestId={RequestId} correlationId={CorrelationId} messageId={MessageId} retryAttempt={RetryAttempt} isFinalAttempt={IsFinalAttempt} service={Service} processId={ProcessId}",
                message.RequestId,
                context.CorrelationId,
                messageId,
                retryAttempt,
                isFinalAttempt,
                "sentinel-worker",
                Environment.ProcessId
            );
            throw;
        }
    }

    private static Guid ResolveMessageId(Guid? messageId, AnalyzeComplianceRequest message)
    {
        if (messageId.HasValue)
        {
            return messageId.Value;
        }

        var normalizedSource = message.Source ?? string.Empty;
        var payload = $"{message.RequestId:N}|{normalizedSource}|{message.Content}";
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(payload));
        Span<byte> guidBytes = stackalloc byte[16];
        bytes.AsSpan(0, 16).CopyTo(guidBytes);
        return new Guid(guidBytes);
    }
}
