using Microsoft.AspNetCore.Components;
using Microsoft.Extensions.Logging;
using Sentinel.Web.Features.Theme;

namespace Sentinel.Web.Features.Matters;

public abstract class MatterWorkspacePrototypeBase : ComponentBase
{
    private static readonly IReadOnlyList<QueueViewOption> QueueViewOptionsInternal =
    [
        new(MatterQueueViews.All, "All matters", "Full queue."),
        new(MatterQueueViews.ActiveClock, "Live deadlines", "Due pressure."),
        new(MatterQueueViews.BlockedDownstream, "Blocked handoffs", "Stalled follow-through."),
        new(MatterQueueViews.MissingEvidence, "Evidence gaps", "Proof incomplete."),
        new(MatterQueueViews.MissingOwner, "Unassigned matters", "Ownership unclear.")
    ];

    [Inject]
    protected MatterWorkspaceClient MatterWorkspaceClient { get; set; } = default!;

    [Inject]
    protected ILoggerFactory LoggerFactory { get; set; } = default!;

    [CascadingParameter]
    protected ShellThemeController ThemeController { get; set; } = default!;

    protected ComplianceMatterQueueResponse? MatterQueue { get; private set; }

    protected ComplianceMatterOverviewResponse? Overview { get; private set; }

    protected ComplianceMatterTimelineResponse? Timeline { get; private set; }

    protected string SelectedQueueView { get; private set; } = MatterQueueViews.All;

    protected string? SelectedScenarioId { get; private set; }

    protected bool IsLoadingQueue { get; private set; } = true;

    protected bool IsLoadingMatter { get; private set; }

    protected string? ErrorMessage { get; private set; }

    protected IReadOnlyList<QueueViewOption> QueueViewOptions => QueueViewOptionsInternal;

    protected ComplianceMatterQueueItemResponse? SelectedQueueItem =>
        MatterQueue?.Items.FirstOrDefault(item => item.ScenarioId == SelectedScenarioId);

    protected override async Task OnInitializedAsync()
    {
        await LoadQueueAsync(SelectedQueueView, preserveCurrentSelection: false);
    }

    protected async Task ChangeQueueViewAsync(string view)
    {
        if (string.Equals(SelectedQueueView, view, StringComparison.Ordinal))
        {
            return;
        }

        await LoadQueueAsync(view, preserveCurrentSelection: true);
    }

    protected async Task SelectMatterAsync(string scenarioId)
    {
        if (string.Equals(SelectedScenarioId, scenarioId, StringComparison.Ordinal))
        {
            return;
        }

        SelectedScenarioId = scenarioId;
        await LoadSelectedMatterAsync(scenarioId);
    }

    protected string GetQueueMetaText()
    {
        if (IsLoadingQueue && MatterQueue is null)
        {
            return "Loading queue";
        }

        if (MatterQueue is null)
        {
            return "Queue unavailable";
        }

        var activeView = QueueViewOptions.First(option => option.Value == SelectedQueueView);
        return $"{activeView.Label} · {MatterQueue.Items.Count} matters";
    }

    protected string GetSelectionMetaText()
    {
        if (SelectedQueueItem is null)
        {
            return "Choose a matter to open its brief";
        }

        return $"{SelectedQueueItem.Jurisdiction} · {SelectedQueueItem.Owner}";
    }

    protected static string GetMatterDisplayName(string matterName) =>
        matterName.Contains("post-intake cross-market safety follow-up matter", StringComparison.OrdinalIgnoreCase)
            ? "Germany affiliate safety follow-up"
            : matterName;

    protected static string GetClockTone(ComplianceMatterOverviewResponse overview) =>
        overview.IsClockActive ? "urgency" : "clear";

    protected static string GetBlockerTone(ComplianceMatterOverviewResponse overview) =>
        overview.Blocker.Contains("no active blocker", StringComparison.OrdinalIgnoreCase)
        || string.Equals(overview.Blocker.Trim(), "none", StringComparison.OrdinalIgnoreCase)
            ? "clear"
            : "blocked";

    protected static string GetClockDetail(ComplianceMatterOverviewResponse overview)
    {
        if (overview.IsClockActive)
        {
            return $"Due {FormatDueTimestamp(overview.DueAtUtc)}";
        }

        return "Deadline resolved";
    }

    protected static string BuildDeadlineValue(ComplianceMatterOverviewResponse overview)
    {
        if (!overview.IsClockActive)
        {
            return "No active deadline";
        }

        if (overview.IsClockNearingBreach)
        {
            return "Due window nearing breach";
        }

        return "Due window active";
    }

    protected static string BuildBlockerValue(ComplianceMatterOverviewResponse overview) =>
        NormalizeFactForDisplay(overview.Blocker, "No blocker");

    protected static string BuildNextMoveValue(ComplianceMatterOverviewResponse overview) =>
        NormalizeFactForDisplay(overview.DownstreamAction, "No next move");

    protected static string BuildWhatHappened(
        ComplianceMatterOverviewResponse overview,
        ComplianceMatterTimelineResponse timeline)
    {
        switch (overview.ScenarioId)
        {
            case "de-affiliate-delay-path":
                return "Matter opened; Germany affiliate evidence is still missing.";
            case "de-affiliate-downstream-retry":
                return "Evidence arrived, but downstream acknowledgement is still pending after retry.";
            case "de-affiliate-happy-path":
                return "Evidence arrived and downstream acknowledgement was recorded.";
        }

        var latestEvent = timeline.Events.LastOrDefault();
        if (latestEvent is not null)
        {
            return $"{latestEvent.Summary} {latestEvent.Owner} is currently holding the latest recorded step.";
        }

        return $"{GetMatterDisplayName(overview.MatterName)} is the selected matter for {overview.Jurisdiction}.";
    }

    protected static string BuildWhyItMatters(ComplianceMatterOverviewResponse overview)
    {
        switch (overview.ScenarioId)
        {
            case "de-affiliate-delay-path":
                return $"Deadline remains active until {FormatDueTimestamp(overview.DueAtUtc)}.";
            case "de-affiliate-downstream-retry":
                return "Matter stays open until downstream acknowledgement lands.";
            case "de-affiliate-happy-path":
                return "No active intervention is required.";
        }

        var clockClause = overview.IsClockActive
            ? $"{overview.ClockName} remains active until {FormatDueTimestamp(overview.DueAtUtc)}."
            : $"{overview.ClockName} is no longer active.";

        return $"{clockClause} Main blocker: {overview.Blocker}. Current handoff state: {GetDownstreamLabel(overview.DownstreamState)}. Decision basis: {overview.DecisionBasis}.";
    }

    protected static string BuildNextExpectedAction(ComplianceMatterOverviewResponse overview)
    {
        switch (overview.ScenarioId)
        {
            case "de-affiliate-delay-path":
                return $"{overview.Owner} provides the missing evidence.";
            case "de-affiliate-downstream-retry":
                return $"{overview.Owner} confirms downstream acknowledgement.";
            case "de-affiliate-happy-path":
                return $"{overview.Owner} monitors only if status changes.";
        }

        return $"{overview.Owner} is carrying the next move: {overview.DownstreamAction}.";
    }

    protected static string BuildMatterSubtitle(ComplianceMatterOverviewResponse overview) =>
        $"{GetQueueReasonLabel(overview.IsClockActive ? MatterQueueViews.ActiveClock : MatterQueueViews.All)} · {GetDownstreamLabel(overview.DownstreamState)}";

    protected static string BuildOwnerSupportText(ComplianceMatterOverviewResponse overview) =>
        overview.Jurisdiction;

    protected static string BuildBlockerSupportText(ComplianceMatterOverviewResponse overview) =>
        $"Downstream: {GetDownstreamLabel(overview.DownstreamState)}";

    protected static string BuildNextMoveSupportText(ComplianceMatterOverviewResponse overview) =>
        $"Decision basis: {BuildDecisionBasisNote(overview)}";

    protected static string BuildQueueSummary(ComplianceMatterQueueItemResponse item)
    {
        var blocker = NormalizeFactForDisplay(item.Blocker, string.Empty);
        if (!string.IsNullOrWhiteSpace(blocker) && !string.Equals(blocker, "No blocker", StringComparison.Ordinal))
        {
            return blocker;
        }

        return NormalizeFactForDisplay(item.DownstreamAction, "No downstream action");
    }

    protected static string BuildSurfacedReason(ComplianceMatterQueueItemResponse item) =>
        item.ScenarioId switch
        {
            "de-affiliate-delay-path" => "Evidence missing under deadline.",
            "de-affiliate-downstream-retry" => "Acknowledgement still unsettled.",
            "de-affiliate-happy-path" => "Visible only in full queue.",
            _ => string.IsNullOrWhiteSpace(item.QueueReason)
                ? "This matter remains active in the current queue view."
                : $"{TrimTrailingPunctuation(item.QueueReason)}."
        };

    protected static string BuildDecisionBasisNote(ComplianceMatterOverviewResponse overview) =>
        NormalizeDecisionBasis(overview.DecisionBasis);

    protected static IReadOnlyList<string> BuildDecisionBasisItems(ComplianceMatterOverviewResponse overview) =>
        NormalizeDecisionBasis(overview.DecisionBasis)
            .Split('·', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Select(item => item switch
            {
                "source signal" => "Source signal",
                "open affiliate review request" => "Affiliate review requested",
                "no local evidence yet" => "No local evidence yet",
                _ => NormalizeFactForDisplay(item, item)
            })
            .ToArray();

    protected static string GetQueueSignal(ComplianceMatterQueueItemResponse item) =>
        GetQueueReasonLabel(item.QueueReason);

    protected static string GetQueueSignalClass(ComplianceMatterQueueItemResponse item) =>
        $"queue-signal {GetQueueSignalTone(item)}";

    protected static string GetQueueSignalTone(ComplianceMatterQueueItemResponse item)
    {
        switch (item.ScenarioId)
        {
            case "de-affiliate-delay-path":
                return "urgency";
            case "de-affiliate-downstream-retry":
                return "blocked";
            case "de-affiliate-happy-path":
                return "clear";
        }

        if (item.Owner.Contains("unassigned", StringComparison.OrdinalIgnoreCase)
            || item.Owner.Contains("missing", StringComparison.OrdinalIgnoreCase)
            || item.Blocker.Contains("evidence", StringComparison.OrdinalIgnoreCase))
        {
            return "urgency";
        }

        if (item.DownstreamState.Contains("acknowledged", StringComparison.OrdinalIgnoreCase))
        {
            return "clear";
        }

        return "blocked";
    }

    protected static string GetScenarioTag(string scenarioId) =>
        scenarioId switch
        {
            "de-affiliate-delay-path" => "Delay path",
            "de-affiliate-downstream-retry" => "Retry path",
            "de-affiliate-happy-path" => "Happy path",
            _ => scenarioId
        };

    protected static string GetQueueReasonLabel(string queueReason) =>
        queueReason switch
        {
            MatterQueueViews.ActiveClock => "Deadline active",
            MatterQueueViews.BlockedDownstream => "Blocked handoff",
            MatterQueueViews.MissingEvidence => "Evidence gap",
            MatterQueueViews.MissingOwner => "Needs owner",
            MatterQueueViews.All => "Full queue",
            _ => NormalizeFactForDisplay(queueReason.Replace('-', ' '), "Active")
        };

    protected static string GetDownstreamLabel(string downstreamState)
    {
        if (downstreamState.Contains("fail", StringComparison.OrdinalIgnoreCase))
        {
            return "Blocked";
        }

        if (downstreamState.Contains("acknowledged", StringComparison.OrdinalIgnoreCase))
        {
            return "Acknowledged";
        }

        if (downstreamState.Contains("pending", StringComparison.OrdinalIgnoreCase))
        {
            return "Pending";
        }

        return downstreamState;
    }

    protected static string GetTimelineEventLabel(string eventType) =>
        eventType switch
        {
            "source-signal-emitted" => "Signal",
            "matter-opened" => "Opened",
            "affiliate-review-requested" => "Review requested",
            "clock-nearing-breach" => "Deadline warning",
            "affiliate-evidence-arrived" => "Evidence arrived",
            "downstream-quality-action-failed" => "Downstream failed",
            "downstream-quality-action-retried" => "Retry issued",
            "downstream-quality-action-acknowledged" => "Acknowledged",
            _ => eventType.Replace('-', ' ').Replace('_', ' ')
        };

    protected static string BuildTimelineSummary(ComplianceMatterTimelineEventResponse evt) =>
        evt.EventType switch
        {
            "source-signal-emitted" => "Safety intake created the follow-up signal.",
            "matter-opened" => "Sentinel opened the governed matter.",
            "affiliate-review-requested" => "Germany affiliate review was requested.",
            "clock-nearing-breach" => "Due window is nearing breach without evidence.",
            "affiliate-evidence-arrived" => "Germany affiliate evidence arrived.",
            "downstream-quality-action-failed" => "Downstream acknowledgement failed.",
            "downstream-quality-action-retried" => "Quality action was retried downstream.",
            "downstream-quality-action-acknowledged" => "Downstream acknowledgement was recorded.",
            _ => evt.Summary
        };

    protected static string NormalizeDecisionBasis(string decisionBasis) =>
        decisionBasis.Replace(" + ", " · ", StringComparison.Ordinal);

    protected static string NormalizeFactForDisplay(string value, string fallback)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        var trimmed = TrimTrailingPunctuation(value);
        if (string.Equals(trimmed, "none", StringComparison.OrdinalIgnoreCase)
            || trimmed.Contains("no active blocker", StringComparison.OrdinalIgnoreCase))
        {
            return fallback;
        }

        trimmed = char.ToUpperInvariant(trimmed[0]) + trimmed[1..];
        return trimmed;
    }

    protected static string GetDownstreamClass(string downstreamState) =>
        $"state-pill {GetDownstreamTone(downstreamState)}";

    protected static string GetDownstreamTone(string downstreamState) =>
        downstreamState.Contains("fail", StringComparison.OrdinalIgnoreCase)
            ? "blocked"
            : downstreamState.Contains("acknowledged", StringComparison.OrdinalIgnoreCase)
                ? "clear"
                : "focus";

    protected static string FormatTimelineTimestamp(DateTime timestampUtc)
    {
        var localTime = timestampUtc.ToLocalTime();
        var today = DateTime.Now.Date;

        if (localTime.Date == today)
        {
            return $"Today at {localTime:h:mm tt}";
        }

        if (localTime.Date == today.AddDays(-1))
        {
            return $"Yesterday at {localTime:h:mm tt}";
        }

        return localTime.ToString("ddd, MMM d 'at' h:mm tt");
    }

    protected static string FormatDueTimestamp(DateTime timestampUtc) =>
        $"{timestampUtc.ToLocalTime():ddd, MMM d 'at' h:mm tt}";

    protected static string TrimTrailingPunctuation(string value) =>
        value.Trim().TrimEnd('.', '!', '?');

    private async Task LoadQueueAsync(string view, bool preserveCurrentSelection)
    {
        IsLoadingQueue = true;
        ErrorMessage = null;

        try
        {
            var queue = await MatterWorkspaceClient.GetQueueAsync(view);

            MatterQueue = queue;
            SelectedQueueView = queue.View;
            IsLoadingQueue = false;

            var scenarioId = ResolveSelectedScenarioId(queue, preserveCurrentSelection ? SelectedScenarioId : null);
            if (scenarioId is null)
            {
                SelectedScenarioId = null;
                Overview = null;
                Timeline = null;
                return;
            }

            SelectedScenarioId = scenarioId;
            await LoadSelectedMatterAsync(scenarioId);
        }
        catch (Exception ex)
        {
            LoggerFactory.CreateLogger(GetType())
                .LogError(ex, "Failed to load the compliance matter queue for view {QueueView}", view);
            ErrorMessage = "The Blazor shell could not load the matter queue from the existing Stage 4 endpoints.";
            MatterQueue = null;
            Overview = null;
            Timeline = null;
        }
        finally
        {
            IsLoadingQueue = false;
        }
    }

    private async Task LoadSelectedMatterAsync(string scenarioId)
    {
        IsLoadingMatter = true;
        ErrorMessage = null;

        try
        {
            var overviewTask = MatterWorkspaceClient.GetOverviewAsync(scenarioId);
            var timelineTask = MatterWorkspaceClient.GetTimelineAsync(scenarioId);

            await Task.WhenAll(overviewTask, timelineTask);

            Overview = await overviewTask;
            Timeline = await timelineTask;

            if (Overview is null || Timeline is null)
            {
                ErrorMessage = $"The Stage 4 read model did not return overview and timeline data for scenario '{scenarioId}'.";
            }
        }
        catch (Exception ex)
        {
            LoggerFactory.CreateLogger(GetType())
                .LogError(ex, "Failed to load matter details for scenario {ScenarioId}", scenarioId);
            ErrorMessage = $"The Blazor shell could not load the selected matter '{scenarioId}' from the existing endpoints.";
            Overview = null;
            Timeline = null;
        }
        finally
        {
            IsLoadingMatter = false;
        }
    }

    private static string? ResolveSelectedScenarioId(
        ComplianceMatterQueueResponse queue,
        string? currentScenarioId)
    {
        if (queue.Items.Count == 0)
        {
            return null;
        }

        if (!string.IsNullOrWhiteSpace(currentScenarioId)
            && queue.Items.Any(item => string.Equals(item.ScenarioId, currentScenarioId, StringComparison.Ordinal)))
        {
            return currentScenarioId;
        }

        return queue.Items[0].ScenarioId;
    }

    protected sealed record QueueViewOption(string Value, string Label, string Description);
}
