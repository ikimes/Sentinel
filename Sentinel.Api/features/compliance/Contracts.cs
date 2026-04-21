using System.Text.Json.Serialization;
using Sentinel.Api.Features.Diagnostics;
using Sentinel.Shared.Contracts;

namespace Sentinel.Api.Features.Compliance;

public record CheckTextRequest(string Content, string Source);

public record CheckTextResponse(Guid CheckId, string Status);

public sealed record ComplianceCheckStatusResponse(
    Guid RequestId,
    string Status,
    string? SendMode,
    DateTime? AcceptedUtc,
    DateTime? ProcessedAtUtc,
    string? ActorId,
    string? ActorType,
    string? ActorDisplayName,
    string? TraceId,
    Guid? MessageId,
    string? ErrorCode,
    string? ErrorDetail
);

public sealed record ComplianceCheckRecentItemResponse(
    Guid RequestId,
    string Status,
    DateTime AcceptedUtc,
    DateTime? ProcessedAtUtc,
    string? ActorId,
    string? ActorType,
    string? ActorDisplayName,
    string? ErrorCode
);

public sealed record ComplianceCheckHistoryResponse(
    Guid RequestId,
    string Status,
    DateTime? AcceptedUtc,
    DateTime? ProcessedAtUtc,
    string? ActorId,
    string? ActorType,
    string? ActorDisplayName,
    IReadOnlyList<ComplianceCheckHistoryEventResponse> Events
);

public sealed record ComplianceCheckHistoryEventResponse(
    string Status,
    DateTime TimestampUtc,
    Guid? MessageId,
    string? TraceId,
    string? ErrorCode,
    string? ErrorDetail
);

public sealed record ComplianceMatterOverviewResponse(
    string ScenarioId,
    string MatterName,
    string Jurisdiction,
    string Owner,
    string ActiveClock,
    string Blocker,
    string DownstreamState,
    string DownstreamAction,
    string DecisionBasis,
    string ClockName,
    bool IsClockActive,
    bool IsClockNearingBreach,
    DateTime DueAtUtc,
    TimeSpan? TimeRemaining
);

public sealed record ComplianceMatterTimelineResponse(
    string ScenarioId,
    string MatterName,
    string Jurisdiction,
    IReadOnlyList<ComplianceMatterTimelineEventResponse> Events
);

public sealed record ComplianceMatterQueueResponse(
    string View,
    IReadOnlyList<ComplianceMatterQueueItemResponse> Items
);

public sealed record ComplianceMatterQueueItemResponse(
    string ScenarioId,
    string MatterName,
    string Jurisdiction,
    string Owner,
    string ActiveClock,
    string Blocker,
    string DownstreamState,
    string DownstreamAction,
    string DecisionBasis,
    string QueueReason
);

public sealed record ComplianceMatterTimelineEventResponse(
    DateTime TimestampUtc,
    string EventType,
    string Summary,
    string Owner,
    string? Blocker,
    string? Evidence,
    string? DownstreamState
);

public sealed record DiagnosticsReadinessResponse(
    bool ApiHealthy,
    bool DatabaseHealthy,
    bool BrokerHealthy,
    int OutboxPending,
    int InboxCount,
    int DispatchRecordCount,
    int ErrorQueueMessages,
    DateTime? LatestProcessedUtc,
    DateTime? LatestFailedUtc,
    bool WorkerSignalFresh,
    double? WorkerSignalAgeSeconds,
    bool DiagnosticsEnabled,
    string DatabaseStatus,
    string BrokerStatus,
    string WorkerSignalStatus
);

[JsonSerializable(typeof(CheckTextRequest))]
[JsonSerializable(typeof(CheckTextResponse))]
[JsonSerializable(typeof(ComplianceCheckStatusResponse))]
[JsonSerializable(typeof(ComplianceCheckRecentItemResponse[]))]
[JsonSerializable(typeof(ComplianceCheckHistoryResponse))]
[JsonSerializable(typeof(ComplianceCheckHistoryEventResponse[]))]
[JsonSerializable(typeof(ComplianceMatterOverviewResponse))]
[JsonSerializable(typeof(ComplianceMatterQueueResponse))]
[JsonSerializable(typeof(ComplianceMatterQueueItemResponse[]))]
[JsonSerializable(typeof(ComplianceMatterTimelineResponse))]
[JsonSerializable(typeof(ComplianceMatterTimelineEventResponse[]))]
[JsonSerializable(typeof(DiagnosticsReadinessResponse))]
[JsonSerializable(typeof(AnalyzeComplianceRequest))]
[JsonSerializable(typeof(DuplicateReplayRequest))]
[JsonSerializable(typeof(DuplicateReplayResponse))]
[JsonSerializable(typeof(ForcedFailureRequest))]
[JsonSerializable(typeof(ForcedFailureResponse))]
public partial class ComplianceApiJsonContext : JsonSerializerContext { }
