namespace Sentinel.Web.Features.Matters;

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

public static class MatterQueueViews
{
    public const string All = "all";
    public const string ActiveClock = "active-clock";
    public const string BlockedDownstream = "blocked-downstream";
    public const string MissingEvidence = "missing-evidence";
    public const string MissingOwner = "missing-owner";
}
