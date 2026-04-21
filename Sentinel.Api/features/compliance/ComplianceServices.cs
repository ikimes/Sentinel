using System.Data;
using MassTransit;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Sentinel.Shared.Contracts;
using Sentinel.Shared.Messaging;

namespace Sentinel.Api.Features.Compliance;

internal interface IComplianceAcceptanceService
{
    Task<CheckTextResponse> AcceptAsync(CheckTextRequest request, HttpRequest httpRequest, CancellationToken cancellationToken);
}

internal interface IComplianceActorResolver
{
    ComplianceActorMetadata Resolve(HttpRequest request);
}

internal interface IComplianceReadService
{
    Task<ComplianceCheckStatusResponse?> GetStatusAsync(Guid requestId, CancellationToken cancellationToken);
    Task<IReadOnlyList<ComplianceCheckRecentItemResponse>> GetRecentAsync(int take, CancellationToken cancellationToken);
    Task<ComplianceCheckHistoryResponse?> GetHistoryAsync(Guid requestId, CancellationToken cancellationToken);
    Task<ComplianceMatterOverviewResponse?> GetMatterOverviewAsync(string scenarioId, CancellationToken cancellationToken);
    Task<ComplianceMatterQueueResponse> GetMatterQueueAsync(string view, CancellationToken cancellationToken);
    Task<ComplianceMatterTimelineResponse?> GetMatterTimelineAsync(string scenarioId, CancellationToken cancellationToken);
}

internal static class ComplianceActorHeaders
{
    public const string ActorId = "X-Actor-Id";
    public const string ActorType = "X-Actor-Type";
    public const string ActorDisplayName = "X-Actor-Display-Name";

    public static ComplianceActorMetadata Parse(HttpRequest request) =>
        new(
            Normalize(request.Headers[ActorId], 128),
            Normalize(request.Headers[ActorType], 64),
            Normalize(request.Headers[ActorDisplayName], 256));

    private static string? Normalize(Microsoft.Extensions.Primitives.StringValues value, int maxLength)
    {
        var normalized = value.ToString().Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        return normalized.Length <= maxLength
            ? normalized
            : normalized[..maxLength];
    }
}

internal static class ComplianceStatusNames
{
    public const string Accepted = "accepted";
    public const string Processed = "processed";
    public const string Failed = "failed";

    public static string Map(string? ledgerStatus) =>
        ledgerStatus switch
        {
            Processed => Processed,
            Failed => Failed,
            _ => Accepted
        };
}

internal static class ComplianceMatterQueueViews
{
    public const string All = "all";
    public const string ActiveClock = "active-clock";
    public const string BlockedDownstream = "blocked-downstream";
    public const string MissingEvidence = "missing-evidence";
    public const string MissingOwner = "missing-owner";

    public static IReadOnlyList<string> Supported { get; } =
    [
        All,
        ActiveClock,
        BlockedDownstream,
        MissingEvidence,
        MissingOwner
    ];

    public static bool TryNormalize(string? view, out string normalizedView)
    {
        normalizedView = string.IsNullOrWhiteSpace(view)
            ? All
            : view.Trim().ToLowerInvariant();

        return Supported.Contains(normalizedView, StringComparer.Ordinal);
    }
}

internal sealed record ComplianceActorMetadata(
    string? ActorId,
    string? ActorType,
    string? ActorDisplayName);

internal sealed class TrustedHeaderComplianceActorResolver : IComplianceActorResolver
{
    public ComplianceActorMetadata Resolve(HttpRequest request) => ComplianceActorHeaders.Parse(request);
}

internal sealed class ReplayOnlyComplianceAcceptanceService : IComplianceAcceptanceService
{
    public Task<CheckTextResponse> AcceptAsync(
        CheckTextRequest request,
        HttpRequest httpRequest,
        CancellationToken cancellationToken) =>
        throw new NotSupportedException(
            "Compliance acceptance is unavailable when the API is running in replay-only development mode.");
}

internal sealed class ComplianceAcceptanceService(
    ISendEndpointProvider sendEndpointProvider,
    IComplianceActorResolver actorResolver,
    MessagingDbContext dbContext,
    IConfiguration configuration,
    ILogger<ComplianceAcceptanceService> logger) : IComplianceAcceptanceService
{
    private const string ComplianceQueue = "compliance";
    private static readonly Uri ComplianceQueueUri = new("queue:compliance");
    private const string DefaultSendMode = "send";

    public async Task<CheckTextResponse> AcceptAsync(
        CheckTextRequest request,
        HttpRequest httpRequest,
        CancellationToken cancellationToken)
    {
        var checkId = Guid.NewGuid();
        var message = new AnalyzeComplianceRequest(checkId, request.Content, request.Source);
        var actor = actorResolver.Resolve(httpRequest);
        var sendMode = (configuration["Sentinel:MessageSendMode"] ?? DefaultSendMode).Trim().ToLowerInvariant();
        string destination;

        logger.LogInformation(
            "COMPLIANCE_API_RECEIVED requestId={RequestId} source={Source} contentLength={ContentLength} actorId={ActorId} actorType={ActorType}",
            checkId,
            request.Source ?? "unknown",
            request.Content.Length,
            actor.ActorId ?? "unknown",
            actor.ActorType ?? "unknown"
        );

        if (sendMode is "send" or "fallback-send" or "publish" or "outbox")
        {
            destination = ComplianceQueueUri.ToString();
            var endpoint = await sendEndpointProvider.GetSendEndpoint(ComplianceQueueUri);
            await endpoint.Send(message, context => context.CorrelationId = checkId, cancellationToken);
        }
        else
        {
            logger.LogWarning(
                "Unknown send mode {Mode}. Falling back to send path for compliance request {RequestId}",
                sendMode,
                checkId
            );
            destination = ComplianceQueueUri.ToString();
            var endpoint = await sendEndpointProvider.GetSendEndpoint(ComplianceQueueUri);
            await endpoint.Send(message, context => context.CorrelationId = checkId, cancellationToken);
            sendMode = DefaultSendMode;
        }

        dbContext.DispatchRecords.Add(new OutboxDispatchRecord
        {
            RequestId = checkId,
            SendMode = sendMode,
            Destination = destination,
            CreatedAtUtc = DateTime.UtcNow,
            ActorId = actor.ActorId,
            ActorType = actor.ActorType,
            ActorDisplayName = actor.ActorDisplayName
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        var pendingOutboxCount = await GetPendingOutboxCountAsync(cancellationToken);

        logger.LogInformation(
            "COMPLIANCE_API_DISPATCHED requestId={RequestId} mode={Mode} destination={Destination} queue={QueueName} service={Service} processId={ProcessId}",
            checkId,
            sendMode,
            destination,
            ComplianceQueue,
            "sentinel-api",
            Environment.ProcessId
        );
        logger.LogInformation(
            "COMPLIANCE_API_OUTBOX_PENDING requestId={RequestId} pendingCount={PendingCount} service={Service} processId={ProcessId}",
            checkId,
            pendingOutboxCount,
            "sentinel-api",
            Environment.ProcessId
        );

        return new CheckTextResponse(checkId, ComplianceStatusNames.Accepted);
    }

    private async Task<int> GetPendingOutboxCountAsync(CancellationToken cancellationToken)
    {
        var connection = dbContext.Database.GetDbConnection();
        var shouldClose = connection.State != ConnectionState.Open;
        if (shouldClose)
        {
            await connection.OpenAsync(cancellationToken);
        }

        try
        {
            await using var command = connection.CreateCommand();
            command.CommandText = "select count(*) from masstransit.outbox_message";
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
}

internal sealed class ComplianceReadService(
    MessagingDbContext dbContext,
    ILogger<ComplianceReadService> logger,
    IConfiguration configuration) : IComplianceReadService
{
    private readonly ComplianceMatterReplayHarness _matterReplayHarness = new(configuration);

    public async Task<ComplianceCheckStatusResponse?> GetStatusAsync(Guid requestId, CancellationToken cancellationToken)
    {
        var dispatchRecord = await GetEarliestDispatchRecordAsync(requestId, cancellationToken);
        var latestLedgerEvent = await GetLatestLedgerEventAsync(requestId, cancellationToken);

        if (dispatchRecord is null && latestLedgerEvent is null)
        {
            logger.LogInformation(
                "COMPLIANCE_API_STATUS_READ requestId={RequestId} status=not_found",
                requestId
            );

            return null;
        }

        var response = new ComplianceCheckStatusResponse(
            requestId,
            ComplianceStatusNames.Map(latestLedgerEvent?.Status),
            dispatchRecord?.SendMode,
            dispatchRecord?.CreatedAtUtc,
            latestLedgerEvent?.ProcessedAtUtc,
            dispatchRecord?.ActorId,
            dispatchRecord?.ActorType,
            dispatchRecord?.ActorDisplayName,
            latestLedgerEvent?.TraceId,
            latestLedgerEvent?.MessageId,
            latestLedgerEvent?.ErrorCode,
            latestLedgerEvent?.ErrorDetail
        );

        logger.LogInformation(
            "COMPLIANCE_API_STATUS_READ requestId={RequestId} status={Status} sendMode={SendMode}",
            requestId,
            response.Status,
            response.SendMode ?? "unknown"
        );

        return response;
    }

    public async Task<IReadOnlyList<ComplianceCheckRecentItemResponse>> GetRecentAsync(
        int take,
        CancellationToken cancellationToken)
    {
        var clampedTake = Math.Clamp(take, 1, 100);
        var dispatchRecords = await dbContext.DispatchRecords
            .AsNoTracking()
            .OrderBy(record => record.CreatedAtUtc)
            .Select(record => new DispatchRecordProjection(
                record.RequestId,
                record.SendMode,
                record.CreatedAtUtc,
                record.ActorId,
                record.ActorType,
                record.ActorDisplayName))
            .ToListAsync(cancellationToken);

        var acceptedSummaries = dispatchRecords
            .GroupBy(record => record.RequestId)
            .Select(group => group.First())
            .OrderByDescending(record => record.CreatedAtUtc)
            .Take(clampedTake)
            .Select(record => new AcceptedSummary(record.RequestId, record.CreatedAtUtc))
            .ToArray();

        if (acceptedSummaries.Length == 0)
        {
            return [];
        }

        var requestIds = acceptedSummaries.Select(summary => summary.RequestId).ToArray();
        var requestIdSet = requestIds.ToHashSet();
        var ledgerEvents = await dbContext.ComplianceLedgerEvents
            .AsNoTracking()
            .OrderByDescending(evt => evt.ProcessedAtUtc)
            .Select(evt => new LedgerEventProjection(
                evt.RequestId,
                evt.Status,
                evt.ProcessedAtUtc,
                evt.TraceId,
                evt.MessageId,
                evt.ErrorCode,
                evt.ErrorDetail))
            .ToListAsync(cancellationToken);

        var earliestDispatchByRequestId = dispatchRecords
            .GroupBy(record => record.RequestId)
            .ToDictionary(group => group.Key, group => group.First());
        var latestLedgerByRequestId = ledgerEvents
            .Where(evt => requestIdSet.Contains(evt.RequestId))
            .GroupBy(evt => evt.RequestId)
            .ToDictionary(group => group.Key, group => group.First());

        return acceptedSummaries
            .Select(summary =>
            {
                var dispatchRecord = earliestDispatchByRequestId[summary.RequestId];
                latestLedgerByRequestId.TryGetValue(summary.RequestId, out var latestLedgerEvent);

                return new ComplianceCheckRecentItemResponse(
                    summary.RequestId,
                    ComplianceStatusNames.Map(latestLedgerEvent?.Status),
                    dispatchRecord.CreatedAtUtc,
                    latestLedgerEvent?.ProcessedAtUtc,
                    dispatchRecord.ActorId,
                    dispatchRecord.ActorType,
                    dispatchRecord.ActorDisplayName,
                    latestLedgerEvent?.ErrorCode
                );
            })
            .ToArray();
    }

    public async Task<ComplianceCheckHistoryResponse?> GetHistoryAsync(Guid requestId, CancellationToken cancellationToken)
    {
        var dispatchRecord = await GetEarliestDispatchRecordAsync(requestId, cancellationToken);
        var ledgerEvents = await dbContext.ComplianceLedgerEvents
            .AsNoTracking()
            .Where(evt => evt.RequestId == requestId)
            .OrderBy(evt => evt.ProcessedAtUtc)
            .Select(evt => new LedgerEventProjection(
                evt.RequestId,
                evt.Status,
                evt.ProcessedAtUtc,
                evt.TraceId,
                evt.MessageId,
                evt.ErrorCode,
                evt.ErrorDetail))
            .ToListAsync(cancellationToken);

        if (dispatchRecord is null && ledgerEvents.Count == 0)
        {
            logger.LogInformation(
                "COMPLIANCE_API_HISTORY_READ requestId={RequestId} status=not_found",
                requestId
            );

            return null;
        }

        var events = new List<ComplianceCheckHistoryEventResponse>(ledgerEvents.Count + 1);
        if (dispatchRecord is not null)
        {
            events.Add(new ComplianceCheckHistoryEventResponse(
                ComplianceStatusNames.Accepted,
                dispatchRecord.CreatedAtUtc,
                null,
                null,
                null,
                null
            ));
        }

        events.AddRange(ledgerEvents.Select(evt => new ComplianceCheckHistoryEventResponse(
            ComplianceStatusNames.Map(evt.Status),
            evt.ProcessedAtUtc,
            evt.MessageId,
            evt.TraceId,
            evt.ErrorCode,
            evt.ErrorDetail
        )));

        var latestLedgerEvent = ledgerEvents.LastOrDefault();
        var response = new ComplianceCheckHistoryResponse(
            requestId,
            ComplianceStatusNames.Map(latestLedgerEvent?.Status),
            dispatchRecord?.CreatedAtUtc,
            latestLedgerEvent?.ProcessedAtUtc,
            dispatchRecord?.ActorId,
            dispatchRecord?.ActorType,
            dispatchRecord?.ActorDisplayName,
            events
        );

        logger.LogInformation(
            "COMPLIANCE_API_HISTORY_READ requestId={RequestId} status={Status} eventCount={EventCount}",
            requestId,
            response.Status,
            response.Events.Count
        );

        return response;
    }

    public Task<ComplianceMatterOverviewResponse?> GetMatterOverviewAsync(
        string scenarioId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var replay = TryReplayScenario(scenarioId, "COMPLIANCE_API_MATTER_OVERVIEW_READ");
        if (replay is null)
        {
            return Task.FromResult<ComplianceMatterOverviewResponse?>(null);
        }

        var response = CreateMatterOverviewResponse(replay);

        logger.LogInformation(
            "COMPLIANCE_API_MATTER_OVERVIEW_READ scenarioId={ScenarioId} owner={Owner} downstreamState={DownstreamState} clockActive={ClockActive}",
            scenarioId,
            response.Owner,
            response.DownstreamState,
            response.IsClockActive
        );

        return Task.FromResult<ComplianceMatterOverviewResponse?>(response);
    }

    public Task<ComplianceMatterQueueResponse> GetMatterQueueAsync(
        string view,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (!ComplianceMatterQueueViews.Supported.Contains(view, StringComparer.Ordinal))
        {
            throw new ArgumentOutOfRangeException(
                nameof(view),
                view,
                $"Unsupported queue view. Supported values: {string.Join(", ", ComplianceMatterQueueViews.Supported)}");
        }

        var items = ComplianceMatterReplayScenarioIds.All
            .Select(_matterReplayHarness.Replay)
            .OrderByDescending(replay => replay.Clock.IsActive)
            .ThenByDescending(IsBlockedDownstream)
            .ThenBy(replay => replay.ScenarioId, StringComparer.Ordinal)
            .Where(replay => MatchesQueueView(replay, view))
            .Select(CreateMatterQueueItemResponse)
            .ToArray();

        var response = new ComplianceMatterQueueResponse(view, items);

        logger.LogInformation(
            "COMPLIANCE_API_MATTER_QUEUE_READ view={View} itemCount={ItemCount}",
            response.View,
            response.Items.Count);

        return Task.FromResult(response);
    }

    public Task<ComplianceMatterTimelineResponse?> GetMatterTimelineAsync(
        string scenarioId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var replay = TryReplayScenario(scenarioId, "COMPLIANCE_API_MATTER_TIMELINE_READ");
        if (replay is null)
        {
            return Task.FromResult<ComplianceMatterTimelineResponse?>(null);
        }

        var response = new ComplianceMatterTimelineResponse(
            replay.ScenarioId,
            replay.MatterName,
            replay.Jurisdiction,
            replay.Timeline
                .Select(evt => new ComplianceMatterTimelineEventResponse(
                    evt.TimestampUtc,
                    evt.EventType,
                    evt.Summary,
                    evt.Owner,
                    evt.Blocker,
                    evt.Evidence,
                    evt.DownstreamState))
                .ToArray()
        );

        logger.LogInformation(
            "COMPLIANCE_API_MATTER_TIMELINE_READ scenarioId={ScenarioId} eventCount={EventCount} lastEventType={LastEventType}",
            scenarioId,
            response.Events.Count,
            response.Events.LastOrDefault()?.EventType ?? "none"
        );

        return Task.FromResult<ComplianceMatterTimelineResponse?>(response);
    }

    private static ComplianceMatterOverviewResponse CreateMatterOverviewResponse(ComplianceMatterReplayResult replay) =>
        new(
            replay.ScenarioId,
            replay.MatterName,
            replay.Jurisdiction,
            replay.OperatorAnswers.Owner,
            replay.OperatorAnswers.ActiveClock,
            replay.OperatorAnswers.Blocker,
            replay.DownstreamTarget.State,
            replay.OperatorAnswers.DownstreamAction,
            replay.OperatorAnswers.DecisionBasis,
            replay.Clock.ClockName,
            replay.Clock.IsActive,
            replay.Clock.IsNearingBreach,
            replay.Clock.DueAtUtc,
            replay.Clock.TimeRemaining);

    private static ComplianceMatterQueueItemResponse CreateMatterQueueItemResponse(ComplianceMatterReplayResult replay)
    {
        var overview = CreateMatterOverviewResponse(replay);

        return new ComplianceMatterQueueItemResponse(
            overview.ScenarioId,
            overview.MatterName,
            overview.Jurisdiction,
            overview.Owner,
            overview.ActiveClock,
            overview.Blocker,
            overview.DownstreamState,
            overview.DownstreamAction,
            overview.DecisionBasis,
            GetQueueReason(replay));
    }

    private static string GetQueueReason(ComplianceMatterReplayResult replay) =>
        replay.Clock.IsActive
            ? ComplianceMatterQueueViews.ActiveClock
            : IsBlockedDownstream(replay)
                ? ComplianceMatterQueueViews.BlockedDownstream
                : IsMissingEvidence(replay)
                    ? ComplianceMatterQueueViews.MissingEvidence
                    : IsMissingOwner(replay)
                        ? ComplianceMatterQueueViews.MissingOwner
                        : ComplianceMatterQueueViews.All;

    private static bool MatchesQueueView(ComplianceMatterReplayResult replay, string view) =>
        view switch
        {
            ComplianceMatterQueueViews.All => true,
            ComplianceMatterQueueViews.ActiveClock => replay.Clock.IsActive,
            ComplianceMatterQueueViews.BlockedDownstream => IsBlockedDownstream(replay),
            ComplianceMatterQueueViews.MissingEvidence => IsMissingEvidence(replay),
            ComplianceMatterQueueViews.MissingOwner => IsMissingOwner(replay),
            _ => false
        };

    private static bool IsBlockedDownstream(ComplianceMatterReplayResult replay) =>
        string.Equals(replay.DownstreamTarget.State, ComplianceMatterDownstreamState.Pending, StringComparison.Ordinal)
        && !string.Equals(replay.OperatorAnswers.Blocker, "none", StringComparison.OrdinalIgnoreCase);

    private static bool IsMissingEvidence(ComplianceMatterReplayResult replay) =>
        replay.OperatorAnswers.Blocker.Contains("review evidence", StringComparison.OrdinalIgnoreCase);

    private static bool IsMissingOwner(ComplianceMatterReplayResult replay) =>
        string.IsNullOrWhiteSpace(replay.OperatorAnswers.Owner);

    private ComplianceMatterReplayResult? TryReplayScenario(string scenarioId, string logEventName)
    {
        if (string.IsNullOrWhiteSpace(scenarioId)
            || !ComplianceMatterReplayScenarioIds.All.Contains(scenarioId, StringComparer.Ordinal))
        {
            logger.LogInformation(
                "{LogEventName} scenarioId={ScenarioId} status=not_found",
                logEventName,
                scenarioId ?? "null"
            );

            return null;
        }

        return _matterReplayHarness.Replay(scenarioId);
    }

    private Task<DispatchRecordProjection?> GetEarliestDispatchRecordAsync(
        Guid requestId,
        CancellationToken cancellationToken) =>
        dbContext.DispatchRecords
            .AsNoTracking()
            .Where(record => record.RequestId == requestId)
            .OrderBy(record => record.CreatedAtUtc)
            .Select(record => new DispatchRecordProjection(
                record.RequestId,
                record.SendMode,
                record.CreatedAtUtc,
                record.ActorId,
                record.ActorType,
                record.ActorDisplayName))
            .FirstOrDefaultAsync(cancellationToken);

    private Task<LedgerEventProjection?> GetLatestLedgerEventAsync(
        Guid requestId,
        CancellationToken cancellationToken) =>
        dbContext.ComplianceLedgerEvents
            .AsNoTracking()
            .Where(evt => evt.RequestId == requestId)
            .OrderByDescending(evt => evt.ProcessedAtUtc)
            .Select(evt => new LedgerEventProjection(
                evt.RequestId,
                evt.Status,
                evt.ProcessedAtUtc,
                evt.TraceId,
                evt.MessageId,
                evt.ErrorCode,
                evt.ErrorDetail))
            .FirstOrDefaultAsync(cancellationToken);

    private sealed record AcceptedSummary(Guid RequestId, DateTime AcceptedUtc);

    private sealed record DispatchRecordProjection(
        Guid RequestId,
        string SendMode,
        DateTime CreatedAtUtc,
        string? ActorId,
        string? ActorType,
        string? ActorDisplayName);

    private sealed record LedgerEventProjection(
        Guid RequestId,
        string Status,
        DateTime ProcessedAtUtc,
        string? TraceId,
        Guid MessageId,
        string? ErrorCode,
        string? ErrorDetail);
}

internal sealed class ReplayOnlyComplianceReadService(
    IConfiguration configuration,
    ILogger<ReplayOnlyComplianceReadService> logger) : IComplianceReadService
{
    private readonly ComplianceMatterReplayHarness _matterReplayHarness = new(configuration);

    public Task<ComplianceCheckStatusResponse?> GetStatusAsync(Guid requestId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult<ComplianceCheckStatusResponse?>(null);
    }

    public Task<IReadOnlyList<ComplianceCheckRecentItemResponse>> GetRecentAsync(int take, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult<IReadOnlyList<ComplianceCheckRecentItemResponse>>([]);
    }

    public Task<ComplianceCheckHistoryResponse?> GetHistoryAsync(Guid requestId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult<ComplianceCheckHistoryResponse?>(null);
    }

    public Task<ComplianceMatterOverviewResponse?> GetMatterOverviewAsync(
        string scenarioId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var replay = TryReplayScenario(scenarioId, "COMPLIANCE_API_MATTER_OVERVIEW_READ");
        if (replay is null)
        {
            return Task.FromResult<ComplianceMatterOverviewResponse?>(null);
        }

        var response = CreateMatterOverviewResponse(replay);

        logger.LogInformation(
            "COMPLIANCE_API_MATTER_OVERVIEW_READ scenarioId={ScenarioId} owner={Owner} downstreamState={DownstreamState} clockActive={ClockActive}",
            scenarioId,
            response.Owner,
            response.DownstreamState,
            response.IsClockActive
        );

        return Task.FromResult<ComplianceMatterOverviewResponse?>(response);
    }

    public Task<ComplianceMatterQueueResponse> GetMatterQueueAsync(
        string view,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        if (!ComplianceMatterQueueViews.Supported.Contains(view, StringComparer.Ordinal))
        {
            throw new ArgumentOutOfRangeException(
                nameof(view),
                view,
                $"Unsupported queue view. Supported values: {string.Join(", ", ComplianceMatterQueueViews.Supported)}");
        }

        var items = ComplianceMatterReplayScenarioIds.All
            .Select(_matterReplayHarness.Replay)
            .OrderByDescending(replay => replay.Clock.IsActive)
            .ThenByDescending(IsBlockedDownstream)
            .ThenBy(replay => replay.ScenarioId, StringComparer.Ordinal)
            .Where(replay => MatchesQueueView(replay, view))
            .Select(CreateMatterQueueItemResponse)
            .ToArray();

        var response = new ComplianceMatterQueueResponse(view, items);

        logger.LogInformation(
            "COMPLIANCE_API_MATTER_QUEUE_READ view={View} itemCount={ItemCount}",
            response.View,
            response.Items.Count);

        return Task.FromResult(response);
    }

    public Task<ComplianceMatterTimelineResponse?> GetMatterTimelineAsync(
        string scenarioId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var replay = TryReplayScenario(scenarioId, "COMPLIANCE_API_MATTER_TIMELINE_READ");
        if (replay is null)
        {
            return Task.FromResult<ComplianceMatterTimelineResponse?>(null);
        }

        var response = new ComplianceMatterTimelineResponse(
            replay.ScenarioId,
            replay.MatterName,
            replay.Jurisdiction,
            replay.Timeline
                .Select(evt => new ComplianceMatterTimelineEventResponse(
                    evt.TimestampUtc,
                    evt.EventType,
                    evt.Summary,
                    evt.Owner,
                    evt.Blocker,
                    evt.Evidence,
                    evt.DownstreamState))
                .ToArray()
        );

        logger.LogInformation(
            "COMPLIANCE_API_MATTER_TIMELINE_READ scenarioId={ScenarioId} eventCount={EventCount} lastEventType={LastEventType}",
            scenarioId,
            response.Events.Count,
            response.Events.LastOrDefault()?.EventType ?? "none"
        );

        return Task.FromResult<ComplianceMatterTimelineResponse?>(response);
    }

    private static ComplianceMatterOverviewResponse CreateMatterOverviewResponse(ComplianceMatterReplayResult replay) =>
        new(
            replay.ScenarioId,
            replay.MatterName,
            replay.Jurisdiction,
            replay.OperatorAnswers.Owner,
            replay.OperatorAnswers.ActiveClock,
            replay.OperatorAnswers.Blocker,
            replay.DownstreamTarget.State,
            replay.OperatorAnswers.DownstreamAction,
            replay.OperatorAnswers.DecisionBasis,
            replay.Clock.ClockName,
            replay.Clock.IsActive,
            replay.Clock.IsNearingBreach,
            replay.Clock.DueAtUtc,
            replay.Clock.TimeRemaining);

    private static ComplianceMatterQueueItemResponse CreateMatterQueueItemResponse(ComplianceMatterReplayResult replay)
    {
        var overview = CreateMatterOverviewResponse(replay);

        return new ComplianceMatterQueueItemResponse(
            overview.ScenarioId,
            overview.MatterName,
            overview.Jurisdiction,
            overview.Owner,
            overview.ActiveClock,
            overview.Blocker,
            overview.DownstreamState,
            overview.DownstreamAction,
            overview.DecisionBasis,
            GetQueueReason(replay));
    }

    private static string GetQueueReason(ComplianceMatterReplayResult replay) =>
        replay.Clock.IsActive
            ? ComplianceMatterQueueViews.ActiveClock
            : IsBlockedDownstream(replay)
                ? ComplianceMatterQueueViews.BlockedDownstream
                : IsMissingEvidence(replay)
                    ? ComplianceMatterQueueViews.MissingEvidence
                    : IsMissingOwner(replay)
                        ? ComplianceMatterQueueViews.MissingOwner
                        : ComplianceMatterQueueViews.All;

    private static bool MatchesQueueView(ComplianceMatterReplayResult replay, string view) =>
        view switch
        {
            ComplianceMatterQueueViews.All => true,
            ComplianceMatterQueueViews.ActiveClock => replay.Clock.IsActive,
            ComplianceMatterQueueViews.BlockedDownstream => IsBlockedDownstream(replay),
            ComplianceMatterQueueViews.MissingEvidence => IsMissingEvidence(replay),
            ComplianceMatterQueueViews.MissingOwner => IsMissingOwner(replay),
            _ => false
        };

    private static bool IsBlockedDownstream(ComplianceMatterReplayResult replay) =>
        string.Equals(replay.DownstreamTarget.State, ComplianceMatterDownstreamState.Pending, StringComparison.Ordinal)
        && !string.Equals(replay.OperatorAnswers.Blocker, "none", StringComparison.OrdinalIgnoreCase);

    private static bool IsMissingEvidence(ComplianceMatterReplayResult replay) =>
        replay.OperatorAnswers.Blocker.Contains("review evidence", StringComparison.OrdinalIgnoreCase);

    private static bool IsMissingOwner(ComplianceMatterReplayResult replay) =>
        string.IsNullOrWhiteSpace(replay.OperatorAnswers.Owner);

    private ComplianceMatterReplayResult? TryReplayScenario(string scenarioId, string logEventName)
    {
        if (string.IsNullOrWhiteSpace(scenarioId)
            || !ComplianceMatterReplayScenarioIds.All.Contains(scenarioId, StringComparer.Ordinal))
        {
            logger.LogInformation(
                "{LogEventName} scenarioId={ScenarioId} status=not_found",
                logEventName,
                scenarioId ?? "null"
            );

            return null;
        }

        return _matterReplayHarness.Replay(scenarioId);
    }
}
