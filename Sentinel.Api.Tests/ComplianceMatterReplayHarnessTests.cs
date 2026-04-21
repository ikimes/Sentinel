using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Sentinel.Api.Features.Compliance;

namespace Sentinel.Api.Tests;

public sealed class ComplianceMatterReplayHarnessTests
{
    [Fact]
    public void Replay_HappyPath_ReturnsLockedOperatorAnswers()
    {
        var harness = CreateHarness();

        var replay = harness.Replay(ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath);

        Assert.Equal("post-intake cross-market safety follow-up matter", replay.MatterName);
        Assert.Equal("Germany", replay.Jurisdiction);
        Assert.Equal("Safety Intake Stub", replay.SourceSignal.SourceSystemName);
        Assert.Equal("Quality Action Queue Stub", replay.DownstreamTarget.TargetSystemName);
        Assert.Equal("Global Safety Ops", replay.OperatorAnswers.Owner);
        Assert.Equal("none; DE affiliate follow-up satisfied", replay.OperatorAnswers.ActiveClock);
        Assert.Equal("none", replay.OperatorAnswers.Blocker);
        Assert.Equal("quality action acknowledged", replay.OperatorAnswers.DownstreamAction);
        Assert.Equal(
            "source signal + Germany affiliate evidence + routed quality action acknowledgement",
            replay.OperatorAnswers.DecisionBasis);
        Assert.Equal(1, replay.DownstreamTarget.AttemptCount);
        Assert.Equal(ComplianceMatterDownstreamState.Acknowledged, replay.DownstreamTarget.State);
        Assert.False(replay.Clock.IsActive);
    }

    [Fact]
    public void Replay_DelayPath_UsesConfiguredGermanyAffiliateClock()
    {
        var harness = CreateHarness(new Dictionary<string, string?>
        {
            ["Sentinel:Stage4Harness:GermanyAffiliateFollowUpHours"] = "84",
            ["Sentinel:Stage4Harness:UrgencyThresholdHours"] = "8"
        });

        var replay = harness.Replay(ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath);

        Assert.Equal("Germany Affiliate Safety", replay.OperatorAnswers.Owner);
        Assert.Equal("DE affiliate follow-up due window active and nearing breach", replay.OperatorAnswers.ActiveClock);
        Assert.Equal("waiting on Germany affiliate review evidence", replay.OperatorAnswers.Blocker);
        Assert.Equal("quality action pending", replay.OperatorAnswers.DownstreamAction);
        Assert.Equal(TimeSpan.FromHours(84), replay.Clock.DueWindow);
        Assert.Equal(new DateTime(2026, 3, 17, 21, 15, 0, DateTimeKind.Utc), replay.Clock.DueAtUtc);
        Assert.Equal(TimeSpan.FromHours(6), replay.Clock.TimeRemaining);
        Assert.True(replay.Clock.IsActive);
        Assert.True(replay.Clock.IsNearingBreach);
        Assert.Equal(ComplianceMatterDownstreamState.Pending, replay.DownstreamTarget.State);
    }

    [Fact]
    public void Replay_DownstreamRetry_PreservesFailureAndRetryState()
    {
        var harness = CreateHarness();

        var replay = harness.Replay(ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry);

        Assert.Equal("Global Safety Ops", replay.OperatorAnswers.Owner);
        Assert.Equal("none; DE affiliate follow-up satisfied", replay.OperatorAnswers.ActiveClock);
        Assert.Equal("waiting on downstream quality acknowledgement after retry", replay.OperatorAnswers.Blocker);
        Assert.Equal("quality action pending after one failed attempt", replay.OperatorAnswers.DownstreamAction);
        Assert.Equal(
            "source signal + Germany affiliate evidence + downstream failure event + retry decision",
            replay.OperatorAnswers.DecisionBasis);
        Assert.Equal(2, replay.DownstreamTarget.AttemptCount);
        Assert.Equal(ComplianceMatterDownstreamState.Pending, replay.DownstreamTarget.State);
        Assert.Equal("First acknowledgement attempt failed: queue timeout", replay.DownstreamTarget.FailureReason);
        Assert.Contains(replay.Timeline, evt => evt.EventType == "downstream-action-failed");
        Assert.Contains(replay.Timeline, evt => evt.EventType == "downstream-action-retried");
    }

    [Fact]
    public void Replay_IsDeterministic_ForAllLockedScenarioIds()
    {
        var harness = CreateHarness();

        foreach (var scenarioId in ComplianceMatterReplayScenarioIds.All)
        {
            var firstReplay = harness.Replay(scenarioId);
            var secondReplay = harness.Replay(scenarioId);

            Assert.Equal(Serialize(firstReplay), Serialize(secondReplay));
        }
    }

    private static ComplianceMatterReplayHarness CreateHarness(
        IReadOnlyDictionary<string, string?>? values = null)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(values ?? new Dictionary<string, string?>())
            .Build();

        return new ComplianceMatterReplayHarness(configuration);
    }

    private static string Serialize(ComplianceMatterReplayResult replay) =>
        JsonSerializer.Serialize(replay);
}
