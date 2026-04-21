using Microsoft.Extensions.Configuration;

namespace Sentinel.Api.Features.Compliance;

internal static class ComplianceMatterReplayScenarioIds
{
    public const string DeAffiliateHappyPath = "de-affiliate-happy-path";
    public const string DeAffiliateDelayPath = "de-affiliate-delay-path";
    public const string DeAffiliateDownstreamRetry = "de-affiliate-downstream-retry";

    public static IReadOnlyList<string> All { get; } =
    [
        DeAffiliateHappyPath,
        DeAffiliateDelayPath,
        DeAffiliateDownstreamRetry
    ];
}

internal sealed class ComplianceMatterReplayHarness
{
    private const string MatterName = "post-intake cross-market safety follow-up matter";
    private const string Jurisdiction = "Germany";
    private const string GlobalSafetyOps = "Global Safety Ops";
    private const string GermanyAffiliateSafety = "Germany Affiliate Safety";
    private const string SourceSystemName = "Safety Intake Stub";
    private const string DownstreamSystemName = "Quality Action Queue Stub";

    private readonly ComplianceMatterClockConfiguration _clockConfiguration;

    public ComplianceMatterReplayHarness(IConfiguration configuration)
    {
        _clockConfiguration = ComplianceMatterClockConfiguration.FromConfiguration(configuration);
    }

    public ComplianceMatterReplayResult Replay(string scenarioId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(scenarioId);

        return scenarioId switch
        {
            ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath => BuildHappyPathReplay(),
            ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath => BuildDelayPathReplay(),
            ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry => BuildDownstreamRetryReplay(),
            _ => throw new ArgumentOutOfRangeException(
                nameof(scenarioId),
                scenarioId,
                $"Unsupported Stage 4 scenario. Supported ids: {string.Join(", ", ComplianceMatterReplayScenarioIds.All)}")
        };
    }

    private ComplianceMatterReplayResult BuildHappyPathReplay()
    {
        var sourceEmittedAtUtc = new DateTime(2026, 3, 14, 8, 0, 0, DateTimeKind.Utc);
        var matterOpenedAtUtc = sourceEmittedAtUtc.AddMinutes(5);
        var reviewRequestedAtUtc = sourceEmittedAtUtc.AddMinutes(20);
        var affiliateEvidenceReceivedAtUtc = reviewRequestedAtUtc.AddHours(20);
        var downstreamRequestedAtUtc = affiliateEvidenceReceivedAtUtc.AddHours(1);
        var downstreamAcknowledgedAtUtc = downstreamRequestedAtUtc.AddHours(1);

        return new ComplianceMatterReplayResult(
            ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath,
            MatterName,
            Jurisdiction,
            CreateSourceSignal(
                "safety-de-1001",
                sourceEmittedAtUtc,
                "Triaged signal requires Germany affiliate confirmation before quality follow-up.",
                ("triaged", sourceEmittedAtUtc),
                ("affiliate-review-requested", reviewRequestedAtUtc),
                ("affiliate-evidence-received", affiliateEvidenceReceivedAtUtc)),
            CreateDownstreamTarget(
                "Route quality follow-up from Germany affiliate evidence",
                ComplianceMatterDownstreamState.Acknowledged,
                1,
                downstreamAcknowledgedAtUtc,
                downstreamAcknowledgedAtUtc),
            CreateResolvedClock(
                reviewRequestedAtUtc,
                affiliateEvidenceReceivedAtUtc,
                "review received"),
            new ComplianceMatterOperatorAnswers(
                GlobalSafetyOps,
                "none; DE affiliate follow-up satisfied",
                "none",
                "quality action acknowledged",
                "source signal + Germany affiliate evidence + routed quality action acknowledgement"),
            [
                new ComplianceMatterReplayEvent(
                    sourceEmittedAtUtc,
                    "source-signal-emitted",
                    "Safety Intake Stub emitted a triaged signal reference for Germany follow-up.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    matterOpenedAtUtc,
                    "matter-opened",
                    "Sentinel opened the governed follow-up matter and assigned Global Safety Ops.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    reviewRequestedAtUtc,
                    "affiliate-review-requested",
                    "Global Safety Ops requested Germany affiliate review and started the due window.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    affiliateEvidenceReceivedAtUtc,
                    "affiliate-evidence-received",
                    "Germany affiliate supplied the required evidence before the due window expired.",
                    GlobalSafetyOps,
                    Evidence: "Germany affiliate review evidence"),
                new ComplianceMatterReplayEvent(
                    downstreamRequestedAtUtc,
                    "downstream-action-requested",
                    "Sentinel routed one follow-up action to the Quality Action Queue Stub.",
                    GlobalSafetyOps,
                    DownstreamState: ComplianceMatterDownstreamState.Pending),
                new ComplianceMatterReplayEvent(
                    downstreamAcknowledgedAtUtc,
                    "downstream-action-acknowledged",
                    "The downstream quality action was acknowledged.",
                    GlobalSafetyOps,
                    DownstreamState: ComplianceMatterDownstreamState.Acknowledged)
            ]);
    }

    private ComplianceMatterReplayResult BuildDelayPathReplay()
    {
        var sourceEmittedAtUtc = new DateTime(2026, 3, 14, 9, 0, 0, DateTimeKind.Utc);
        var matterOpenedAtUtc = sourceEmittedAtUtc.AddMinutes(5);
        var reviewRequestedAtUtc = sourceEmittedAtUtc.AddMinutes(15);
        var evaluatedAtUtc = reviewRequestedAtUtc
            .Add(_clockConfiguration.FollowUpWindow)
            .Subtract(TimeSpan.FromHours(6));

        return new ComplianceMatterReplayResult(
            ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath,
            MatterName,
            Jurisdiction,
            CreateSourceSignal(
                "safety-de-1002",
                sourceEmittedAtUtc,
                "Triaged signal requires Germany affiliate review before downstream quality routing.",
                ("triaged", sourceEmittedAtUtc),
                ("affiliate-review-requested", reviewRequestedAtUtc),
                ("affiliate-evidence-overdue", evaluatedAtUtc)),
            CreateDownstreamTarget(
                "Hold downstream quality follow-up until Germany affiliate evidence arrives",
                ComplianceMatterDownstreamState.Pending,
                0,
                evaluatedAtUtc,
                null),
            CreateActiveClock(reviewRequestedAtUtc, evaluatedAtUtc),
            new ComplianceMatterOperatorAnswers(
                GermanyAffiliateSafety,
                "DE affiliate follow-up due window active and nearing breach",
                "waiting on Germany affiliate review evidence",
                "quality action pending",
                "source signal + open affiliate review request + no local evidence yet"),
            [
                new ComplianceMatterReplayEvent(
                    sourceEmittedAtUtc,
                    "source-signal-emitted",
                    "Safety Intake Stub emitted a triaged signal reference for Germany follow-up.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    matterOpenedAtUtc,
                    "matter-opened",
                    "Sentinel opened the governed follow-up matter.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    reviewRequestedAtUtc,
                    "affiliate-review-requested",
                    "Global Safety Ops requested Germany affiliate review and started the due window.",
                    GermanyAffiliateSafety),
                new ComplianceMatterReplayEvent(
                    evaluatedAtUtc,
                    "clock-nearing-breach",
                    "The Germany affiliate due window is active, nearing breach, and still lacks local evidence.",
                    GermanyAffiliateSafety,
                    Blocker: "waiting on Germany affiliate review evidence",
                    DownstreamState: ComplianceMatterDownstreamState.Pending)
            ]);
    }

    private ComplianceMatterReplayResult BuildDownstreamRetryReplay()
    {
        var sourceEmittedAtUtc = new DateTime(2026, 3, 14, 10, 0, 0, DateTimeKind.Utc);
        var matterOpenedAtUtc = sourceEmittedAtUtc.AddMinutes(5);
        var reviewRequestedAtUtc = sourceEmittedAtUtc.AddMinutes(20);
        var affiliateEvidenceReceivedAtUtc = reviewRequestedAtUtc.AddHours(18);
        var downstreamRequestedAtUtc = affiliateEvidenceReceivedAtUtc.AddHours(1);
        var downstreamFailedAtUtc = downstreamRequestedAtUtc.AddHours(1);
        var retryScheduledAtUtc = downstreamFailedAtUtc.AddMinutes(15);
        var downstreamRetriedAtUtc = retryScheduledAtUtc.AddMinutes(15);

        return new ComplianceMatterReplayResult(
            ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry,
            MatterName,
            Jurisdiction,
            CreateSourceSignal(
                "safety-de-1003",
                sourceEmittedAtUtc,
                "Triaged signal requires Germany affiliate confirmation before downstream quality routing.",
                ("triaged", sourceEmittedAtUtc),
                ("affiliate-review-requested", reviewRequestedAtUtc),
                ("affiliate-evidence-received", affiliateEvidenceReceivedAtUtc)),
            CreateDownstreamTarget(
                "Retry quality follow-up after first downstream acknowledgement failure",
                ComplianceMatterDownstreamState.Pending,
                2,
                downstreamRetriedAtUtc,
                null,
                "First acknowledgement attempt failed: queue timeout"),
            CreateResolvedClock(
                reviewRequestedAtUtc,
                affiliateEvidenceReceivedAtUtc,
                "review received"),
            new ComplianceMatterOperatorAnswers(
                GlobalSafetyOps,
                "none; DE affiliate follow-up satisfied",
                "waiting on downstream quality acknowledgement after retry",
                "quality action pending after one failed attempt",
                "source signal + Germany affiliate evidence + downstream failure event + retry decision"),
            [
                new ComplianceMatterReplayEvent(
                    sourceEmittedAtUtc,
                    "source-signal-emitted",
                    "Safety Intake Stub emitted a triaged signal reference for Germany follow-up.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    matterOpenedAtUtc,
                    "matter-opened",
                    "Sentinel opened the governed follow-up matter and assigned Global Safety Ops.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    reviewRequestedAtUtc,
                    "affiliate-review-requested",
                    "Global Safety Ops requested Germany affiliate review and started the due window.",
                    GlobalSafetyOps),
                new ComplianceMatterReplayEvent(
                    affiliateEvidenceReceivedAtUtc,
                    "affiliate-evidence-received",
                    "Germany affiliate supplied the required evidence before the due window expired.",
                    GlobalSafetyOps,
                    Evidence: "Germany affiliate review evidence"),
                new ComplianceMatterReplayEvent(
                    downstreamRequestedAtUtc,
                    "downstream-action-requested",
                    "Sentinel routed the downstream quality action request.",
                    GlobalSafetyOps,
                    DownstreamState: ComplianceMatterDownstreamState.Pending),
                new ComplianceMatterReplayEvent(
                    downstreamFailedAtUtc,
                    "downstream-action-failed",
                    "The downstream queue rejected the first acknowledgement attempt.",
                    GlobalSafetyOps,
                    DownstreamState: ComplianceMatterDownstreamState.Failed,
                    Evidence: "queue timeout"),
                new ComplianceMatterReplayEvent(
                    retryScheduledAtUtc,
                    "downstream-retry-scheduled",
                    "Sentinel recorded the failure and scheduled one retry.",
                    GlobalSafetyOps,
                    Blocker: "waiting on downstream quality acknowledgement after retry",
                    DownstreamState: ComplianceMatterDownstreamState.Failed),
                new ComplianceMatterReplayEvent(
                    downstreamRetriedAtUtc,
                    "downstream-action-retried",
                    "Sentinel reissued the downstream quality action and is waiting for acknowledgement.",
                    GlobalSafetyOps,
                    Blocker: "waiting on downstream quality acknowledgement after retry",
                    DownstreamState: ComplianceMatterDownstreamState.Pending)
            ]);
    }

    private ComplianceMatterSourceSignalStub CreateSourceSignal(
        string sourceRecordId,
        DateTime provenanceTimestampUtc,
        string signalSummary,
        params (string Status, DateTime TimestampUtc)[] statusUpdates)
    {
        return new ComplianceMatterSourceSignalStub(
            sourceRecordId,
            SourceSystemName,
            signalSummary,
            provenanceTimestampUtc,
            statusUpdates
                .Select(update => new ComplianceMatterSourceStatusUpdate(update.Status, update.TimestampUtc))
                .ToArray());
    }

    private ComplianceMatterDownstreamTargetStub CreateDownstreamTarget(
        string requestedAction,
        string state,
        int attemptCount,
        DateTime lastUpdatedUtc,
        DateTime? acknowledgedAtUtc,
        string? failureReason = null)
    {
        return new ComplianceMatterDownstreamTargetStub(
            DownstreamSystemName,
            requestedAction,
            state,
            attemptCount,
            lastUpdatedUtc,
            acknowledgedAtUtc,
            failureReason);
    }

    private ComplianceMatterClockSnapshot CreateActiveClock(DateTime startedAtUtc, DateTime evaluatedAtUtc)
    {
        var dueAtUtc = startedAtUtc.Add(_clockConfiguration.FollowUpWindow);
        var timeRemaining = dueAtUtc - evaluatedAtUtc;

        return new ComplianceMatterClockSnapshot(
            _clockConfiguration.ClockName,
            Jurisdiction,
            _clockConfiguration.FollowUpWindow,
            startedAtUtc,
            dueAtUtc,
            evaluatedAtUtc,
            timeRemaining,
            IsActive: true,
            IsNearingBreach: timeRemaining <= _clockConfiguration.UrgencyThreshold,
            Resolution: "awaiting Germany affiliate review evidence");
    }

    private ComplianceMatterClockSnapshot CreateResolvedClock(
        DateTime startedAtUtc,
        DateTime resolvedAtUtc,
        string resolution)
    {
        return new ComplianceMatterClockSnapshot(
            _clockConfiguration.ClockName,
            Jurisdiction,
            _clockConfiguration.FollowUpWindow,
            startedAtUtc,
            startedAtUtc.Add(_clockConfiguration.FollowUpWindow),
            resolvedAtUtc,
            null,
            IsActive: false,
            IsNearingBreach: false,
            Resolution: resolution);
    }
}

internal sealed record ComplianceMatterReplayResult(
    string ScenarioId,
    string MatterName,
    string Jurisdiction,
    ComplianceMatterSourceSignalStub SourceSignal,
    ComplianceMatterDownstreamTargetStub DownstreamTarget,
    ComplianceMatterClockSnapshot Clock,
    ComplianceMatterOperatorAnswers OperatorAnswers,
    IReadOnlyList<ComplianceMatterReplayEvent> Timeline);

internal sealed record ComplianceMatterSourceSignalStub(
    string SourceRecordId,
    string SourceSystemName,
    string SignalSummary,
    DateTime ProvenanceTimestampUtc,
    IReadOnlyList<ComplianceMatterSourceStatusUpdate> StatusUpdates);

internal sealed record ComplianceMatterSourceStatusUpdate(
    string Status,
    DateTime TimestampUtc);

internal sealed record ComplianceMatterDownstreamTargetStub(
    string TargetSystemName,
    string RequestedAction,
    string State,
    int AttemptCount,
    DateTime LastUpdatedUtc,
    DateTime? AcknowledgedAtUtc,
    string? FailureReason);

internal sealed record ComplianceMatterClockSnapshot(
    string ClockName,
    string Jurisdiction,
    TimeSpan DueWindow,
    DateTime StartedAtUtc,
    DateTime DueAtUtc,
    DateTime EvaluatedAtUtc,
    TimeSpan? TimeRemaining,
    bool IsActive,
    bool IsNearingBreach,
    string Resolution);

internal sealed record ComplianceMatterOperatorAnswers(
    string Owner,
    string ActiveClock,
    string Blocker,
    string DownstreamAction,
    string DecisionBasis);

internal sealed record ComplianceMatterReplayEvent(
    DateTime TimestampUtc,
    string EventType,
    string Summary,
    string Owner,
    string? Evidence = null,
    string? Blocker = null,
    string? DownstreamState = null);

internal static class ComplianceMatterDownstreamState
{
    public const string Pending = "pending";
    public const string Acknowledged = "acknowledged";
    public const string Failed = "failed";
    public const string NotRequired = "not required";
}

internal sealed record ComplianceMatterClockConfiguration(
    string ClockName,
    TimeSpan FollowUpWindow,
    TimeSpan UrgencyThreshold)
{
    private const string ClockNameKey = "Sentinel:Stage4Harness:GermanyAffiliateClockName";
    private const string FollowUpHoursKey = "Sentinel:Stage4Harness:GermanyAffiliateFollowUpHours";
    private const string UrgencyThresholdHoursKey = "Sentinel:Stage4Harness:UrgencyThresholdHours";

    public static ComplianceMatterClockConfiguration FromConfiguration(IConfiguration configuration)
    {
        var clockName = configuration[ClockNameKey];
        var followUpHours = configuration.GetValue<int?>(FollowUpHoursKey) ?? 72;
        var urgencyThresholdHours = configuration.GetValue<int?>(UrgencyThresholdHoursKey) ?? 12;

        if (followUpHours <= 0)
        {
            throw new InvalidOperationException(
                $"{FollowUpHoursKey} must be a positive number of hours.");
        }

        if (urgencyThresholdHours < 0)
        {
            throw new InvalidOperationException(
                $"{UrgencyThresholdHoursKey} cannot be negative.");
        }

        return new ComplianceMatterClockConfiguration(
            string.IsNullOrWhiteSpace(clockName) ? "DE affiliate follow-up due window" : clockName.Trim(),
            TimeSpan.FromHours(followUpHours),
            TimeSpan.FromHours(urgencyThresholdHours));
    }
}
