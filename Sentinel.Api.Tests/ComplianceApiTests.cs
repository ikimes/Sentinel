using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Sentinel.Api.Features.Compliance;
using Sentinel.Shared.Messaging;

namespace Sentinel.Api.Tests;

public sealed class ComplianceApiTests(PostgreSqlFixture postgresFixture) : IClassFixture<PostgreSqlFixture>
{
    [Fact]
    public async Task Startup_AdoptsLegacyEnsureCreatedSchema_AndRecordsBaselineMigration()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        await ProvisionLegacyEnsureCreatedSchemaAsync(adminConnectionString);

        var legacyColumns = await GetDispatchRecordColumnNamesAsync(adminConnectionString);
        var migrationHistoryBeforeStartup = await GetMigrationHistoryAsync(adminConnectionString);

        Assert.DoesNotContain("actor_id", legacyColumns);
        Assert.DoesNotContain("actor_type", legacyColumns);
        Assert.DoesNotContain("actor_display_name", legacyColumns);
        Assert.Empty(migrationHistoryBeforeStartup);

        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/");

        response.EnsureSuccessStatusCode();

        var dispatchRecordColumns = await GetDispatchRecordColumnNamesAsync(adminConnectionString);
        var migrationHistory = await GetMigrationHistoryAsync(adminConnectionString);

        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<MessagingDbContext>();
        var expectedBaselineMigrationId = dbContext.Database.GetMigrations().Last();

        Assert.Contains("actor_id", dispatchRecordColumns);
        Assert.Contains("actor_type", dispatchRecordColumns);
        Assert.Contains("actor_display_name", dispatchRecordColumns);
        Assert.Single(migrationHistory);
        Assert.Equal(expectedBaselineMigrationId, migrationHistory[0].MigrationId);
        Assert.False(string.IsNullOrWhiteSpace(migrationHistory[0].ProductVersion));
    }

    [Fact]
    public async Task Startup_AppliesMigrations_ToAnEmptyDatabase()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/");

        response.EnsureSuccessStatusCode();

        await using var connection = new NpgsqlConnection(adminConnectionString);
        await connection.OpenAsync();

        await using var command = connection.CreateCommand();
        command.CommandText = """select count(*) from "__EFMigrationsHistory" """;
        var migrationCount = Convert.ToInt32(await command.ExecuteScalarAsync() ?? 0);

        Assert.True(migrationCount > 0);
    }

    [Fact]
    public async Task Post_ReturnsAccepted_AndPersistsActorHeaders()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/compliance/check")
        {
            Content = JsonContent.Create(new CheckTextRequest("Hello world", "ui-smoke"))
        };
        request.Headers.Add("X-Actor-Id", "reviewer-123");
        request.Headers.Add("X-Actor-Type", "internal-user");
        request.Headers.Add("X-Actor-Display-Name", "Casey Reviewer");

        var response = await client.SendAsync(request);
        response.EnsureSuccessStatusCode();
        var payload = await response.Content.ReadFromJsonAsync<CheckTextResponse>();

        Assert.NotNull(payload);
        Assert.NotEqual(Guid.Empty, payload.CheckId);
        Assert.Equal("accepted", payload.Status);

        var status = await client.GetFromJsonAsync<ComplianceCheckStatusResponse>(
            $"/api/compliance/check/{payload.CheckId}");

        Assert.NotNull(status);
        Assert.Equal("accepted", status.Status);
        Assert.Equal("reviewer-123", status.ActorId);
        Assert.Equal("internal-user", status.ActorType);
        Assert.Equal("Casey Reviewer", status.ActorDisplayName);

        var dispatchRecord = await GetDispatchRecordAsync(factory, payload.CheckId);
        Assert.NotNull(dispatchRecord);
        Assert.Equal("reviewer-123", dispatchRecord.ActorId);
        Assert.Equal("internal-user", dispatchRecord.ActorType);
        Assert.Equal("Casey Reviewer", dispatchRecord.ActorDisplayName);
    }

    [Fact]
    public async Task Post_WithoutActorHeaders_LeavesActorFieldsNull()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync(
            "/api/compliance/check",
            new CheckTextRequest("No actor header", "ui-smoke"));
        response.EnsureSuccessStatusCode();
        var payload = await response.Content.ReadFromJsonAsync<CheckTextResponse>();

        Assert.NotNull(payload);

        var dispatchRecord = await GetDispatchRecordAsync(factory, payload.CheckId);
        Assert.NotNull(dispatchRecord);
        Assert.Null(dispatchRecord.ActorId);
        Assert.Null(dispatchRecord.ActorType);
        Assert.Null(dispatchRecord.ActorDisplayName);
    }

    [Fact]
    public async Task StatusEndpoint_UsesTerminalLedgerStatus_WhenPresent()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var requestId = Guid.NewGuid();
        var messageId = Guid.NewGuid();
        await SeedDispatchAsync(factory, requestId, new DateTime(2026, 3, 12, 12, 0, 0, DateTimeKind.Utc));
        await SeedLedgerEventAsync(
            factory,
            requestId,
            messageId,
            "processed",
            new DateTime(2026, 3, 12, 12, 0, 5, DateTimeKind.Utc));

        var status = await client.GetFromJsonAsync<ComplianceCheckStatusResponse>(
            $"/api/compliance/check/{requestId}");

        Assert.NotNull(status);
        Assert.Equal("processed", status.Status);
        Assert.Equal(messageId, status.MessageId);
        Assert.Equal(new DateTime(2026, 3, 12, 12, 0, 5, DateTimeKind.Utc), status.ProcessedAtUtc);
    }

    [Fact]
    public async Task StatusEndpoint_ReturnsNotFound_ForUnknownRequest()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.GetAsync($"/api/compliance/check/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task StatusEndpoint_ReturnsFailedAndFailureDetail_WhenTerminalFailedRowExists()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var requestId = Guid.NewGuid();
        var acceptedUtc = new DateTime(2026, 3, 12, 12, 1, 0, DateTimeKind.Utc);
        var failedUtc = new DateTime(2026, 3, 12, 12, 1, 9, DateTimeKind.Utc);
        var messageId = Guid.NewGuid();

        await SeedDispatchAsync(factory, requestId, acceptedUtc);
        await SeedLedgerEventAsync(
            factory,
            requestId,
            messageId,
            "failed",
            failedUtc,
            traceId: "trace-failed-123",
            errorCode: "InvalidOperationException",
            errorDetail: "terminal failure");

        var status = await client.GetFromJsonAsync<ComplianceCheckStatusResponse>(
            $"/api/compliance/check/{requestId}");

        Assert.NotNull(status);
        Assert.Equal("failed", status.Status);
        Assert.Equal(acceptedUtc, status.AcceptedUtc);
        Assert.Equal(failedUtc, status.ProcessedAtUtc);
        Assert.Equal(messageId, status.MessageId);
        Assert.Equal("trace-failed-123", status.TraceId);
        Assert.Equal("InvalidOperationException", status.ErrorCode);
        Assert.Equal("terminal failure", status.ErrorDetail);
    }

    [Fact]
    public async Task RecentEndpoint_ReturnsNewestFirst_AndClampsTake()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var oldestRequestId = Guid.NewGuid();
        await SeedDispatchAsync(
            factory,
            oldestRequestId,
            new DateTime(2026, 3, 12, 11, 58, 0, DateTimeKind.Utc),
            actorId: "actor-old",
            actorType: "internal-user",
            actorDisplayName: "Old");

        var middleRequestId = Guid.NewGuid();
        await SeedDispatchAsync(
            factory,
            middleRequestId,
            new DateTime(2026, 3, 12, 11, 59, 0, DateTimeKind.Utc),
            actorId: "actor-mid",
            actorType: "internal-user",
            actorDisplayName: "Middle");
        await SeedLedgerEventAsync(
            factory,
            middleRequestId,
            Guid.NewGuid(),
            "failed",
            new DateTime(2026, 3, 12, 11, 59, 5, DateTimeKind.Utc),
            errorCode: "InvalidOperationException",
            errorDetail: "forced");

        var newestRequestId = Guid.NewGuid();
        await SeedDispatchAsync(
            factory,
            newestRequestId,
            new DateTime(2026, 3, 12, 12, 0, 0, DateTimeKind.Utc),
            actorId: "actor-new",
            actorType: "internal-user",
            actorDisplayName: "Newest");

        var recentResponse = await client.GetAsync("/api/compliance/check/recent?take=0");
        var recentJson = await recentResponse.Content.ReadAsStringAsync();
        Assert.True(recentResponse.IsSuccessStatusCode, recentJson);
        var recent = await recentResponse.Content.ReadFromJsonAsync<ComplianceCheckRecentItemResponse[]>();

        Assert.NotNull(recent);
        Assert.Single(recent);
        Assert.Equal(newestRequestId, recent[0].RequestId);
        Assert.Equal("accepted", recent[0].Status);
        Assert.DoesNotContain("\"content\":", recentJson, StringComparison.OrdinalIgnoreCase);

        var allRecent = await client.GetFromJsonAsync<ComplianceCheckRecentItemResponse[]>(
            "/api/compliance/check/recent?take=100");

        Assert.NotNull(allRecent);
        Assert.Equal(3, allRecent.Length);
        Assert.Equal(new[] { newestRequestId, middleRequestId, oldestRequestId }, allRecent.Select(item => item.RequestId));
        Assert.Equal("failed", allRecent[1].Status);
        Assert.Equal("InvalidOperationException", allRecent[1].ErrorCode);
        Assert.Equal("actor-mid", allRecent[1].ActorId);
    }

    [Fact]
    public async Task RecentEndpoint_DeduplicatesDuplicateDispatchRows_AndUsesEarliestAcceptedTime()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var duplicatedRequestId = Guid.NewGuid();
        var earliestAcceptedUtc = new DateTime(2026, 3, 12, 12, 2, 0, DateTimeKind.Utc);
        var duplicateAcceptedUtc = earliestAcceptedUtc.AddMinutes(3);
        await SeedDispatchAsync(
            factory,
            duplicatedRequestId,
            earliestAcceptedUtc,
            actorId: "actor-earliest",
            actorType: "internal-user",
            actorDisplayName: "Earliest Dispatch");
        await SeedDispatchAsync(
            factory,
            duplicatedRequestId,
            duplicateAcceptedUtc,
            actorId: "actor-duplicate",
            actorType: "internal-user",
            actorDisplayName: "Duplicate Dispatch");
        await SeedLedgerEventAsync(
            factory,
            duplicatedRequestId,
            Guid.NewGuid(),
            "failed",
            duplicateAcceptedUtc.AddSeconds(15),
            errorCode: "DuplicateDispatch",
            errorDetail: "ignored duplicate dispatch");

        var newerRequestId = Guid.NewGuid();
        await SeedDispatchAsync(
            factory,
            newerRequestId,
            duplicateAcceptedUtc.AddMinutes(1),
            actorId: "actor-newer",
            actorType: "internal-user",
            actorDisplayName: "Newer Request");

        var recent = await client.GetFromJsonAsync<ComplianceCheckRecentItemResponse[]>(
            "/api/compliance/check/recent?take=10");

        Assert.NotNull(recent);
        Assert.Equal(2, recent.Length);

        var duplicatedItem = Assert.Single(recent, item => item.RequestId == duplicatedRequestId);
        Assert.Equal("failed", duplicatedItem.Status);
        Assert.Equal(earliestAcceptedUtc, duplicatedItem.AcceptedUtc);
        Assert.Equal("actor-earliest", duplicatedItem.ActorId);
        Assert.Equal("DuplicateDispatch", duplicatedItem.ErrorCode);
    }

    [Fact]
    public async Task HistoryEndpoint_ReturnsAcceptedOnly_WhenNoLedgerEventExists()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var requestId = Guid.NewGuid();
        var acceptedUtc = new DateTime(2026, 3, 12, 12, 5, 0, DateTimeKind.Utc);
        await SeedDispatchAsync(
            factory,
            requestId,
            acceptedUtc,
            actorId: "actor-1",
            actorType: "internal-user",
            actorDisplayName: "Accepted Only");

        var response = await client.GetAsync($"/api/compliance/check/{requestId}/history");
        response.EnsureSuccessStatusCode();
        var historyJson = await response.Content.ReadAsStringAsync();
        var history = await response.Content.ReadFromJsonAsync<ComplianceCheckHistoryResponse>();

        Assert.NotNull(history);
        Assert.Equal("accepted", history.Status);
        Assert.Equal(acceptedUtc, history.AcceptedUtc);
        Assert.Null(history.ProcessedAtUtc);
        Assert.Single(history.Events);
        Assert.Equal("accepted", history.Events[0].Status);
        Assert.Equal(acceptedUtc, history.Events[0].TimestampUtc);
        Assert.DoesNotContain("\"content\":", historyJson, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task HistoryEndpoint_ReturnsAcceptedAndFailedTimeline()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var requestId = Guid.NewGuid();
        var acceptedUtc = new DateTime(2026, 3, 12, 12, 10, 0, DateTimeKind.Utc);
        var failedUtc = new DateTime(2026, 3, 12, 12, 10, 8, DateTimeKind.Utc);
        var messageId = Guid.NewGuid();

        await SeedDispatchAsync(
            factory,
            requestId,
            acceptedUtc,
            actorId: "actor-fail",
            actorType: "internal-user",
            actorDisplayName: "Failure Reviewer");
        await SeedLedgerEventAsync(
            factory,
            requestId,
            messageId,
            "failed",
            failedUtc,
            traceId: "trace-123",
            errorCode: "InvalidOperationException",
            errorDetail: "forced failure");

        var history = await client.GetFromJsonAsync<ComplianceCheckHistoryResponse>(
            $"/api/compliance/check/{requestId}/history");

        Assert.NotNull(history);
        Assert.Equal("failed", history.Status);
        Assert.Equal(failedUtc, history.ProcessedAtUtc);
        Assert.Equal(2, history.Events.Count);
        Assert.Equal("accepted", history.Events[0].Status);
        Assert.Equal("failed", history.Events[1].Status);
        Assert.Equal(messageId, history.Events[1].MessageId);
        Assert.Equal("trace-123", history.Events[1].TraceId);
        Assert.Equal("InvalidOperationException", history.Events[1].ErrorCode);
        Assert.Equal("forced failure", history.Events[1].ErrorDetail);
    }

    [Fact]
    public async Task HistoryEndpoint_DeduplicatesDuplicateDispatchRows_AndUsesEarliestAcceptedTime()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var requestId = Guid.NewGuid();
        var earliestAcceptedUtc = new DateTime(2026, 3, 12, 12, 20, 0, DateTimeKind.Utc);
        var duplicateAcceptedUtc = earliestAcceptedUtc.AddSeconds(30);
        var failedUtc = earliestAcceptedUtc.AddMinutes(1);
        var messageId = Guid.NewGuid();

        await SeedDispatchAsync(
            factory,
            requestId,
            earliestAcceptedUtc,
            actorId: "actor-accepted",
            actorType: "internal-user",
            actorDisplayName: "Accepted Actor");
        await SeedDispatchAsync(
            factory,
            requestId,
            duplicateAcceptedUtc,
            actorId: "actor-duplicate",
            actorType: "internal-user",
            actorDisplayName: "Duplicate Actor");
        await SeedLedgerEventAsync(
            factory,
            requestId,
            messageId,
            "failed",
            failedUtc,
            errorCode: "DuplicateDispatch",
            errorDetail: "duplicate ignored");

        var history = await client.GetFromJsonAsync<ComplianceCheckHistoryResponse>(
            $"/api/compliance/check/{requestId}/history");

        Assert.NotNull(history);
        Assert.Equal("failed", history.Status);
        Assert.Equal(earliestAcceptedUtc, history.AcceptedUtc);
        Assert.Equal(failedUtc, history.ProcessedAtUtc);
        Assert.Equal("actor-accepted", history.ActorId);
        Assert.Equal(2, history.Events.Count);
        Assert.Equal("accepted", history.Events[0].Status);
        Assert.Equal(earliestAcceptedUtc, history.Events[0].TimestampUtc);
        Assert.Equal("failed", history.Events[1].Status);
        Assert.Equal(messageId, history.Events[1].MessageId);
        Assert.Equal("DuplicateDispatch", history.Events[1].ErrorCode);
        Assert.Equal("duplicate ignored", history.Events[1].ErrorDetail);
    }

    [Fact]
    public async Task HistoryEndpoint_ReturnsNotFound_ForUnknownRequest()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.GetAsync($"/api/compliance/check/{Guid.NewGuid()}/history");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task MatterOverviewEndpoint_ReturnsHappyPathOverview()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var overview = await client.GetFromJsonAsync<ComplianceMatterOverviewResponse>(
            $"/api/compliance/matters/{ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath}/overview");

        Assert.NotNull(overview);
        Assert.Equal(ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath, overview.ScenarioId);
        Assert.Equal("post-intake cross-market safety follow-up matter", overview.MatterName);
        Assert.Equal("Germany", overview.Jurisdiction);
        Assert.Equal("Global Safety Ops", overview.Owner);
        Assert.Equal("none; DE affiliate follow-up satisfied", overview.ActiveClock);
        Assert.Equal("none", overview.Blocker);
        Assert.Equal(ComplianceMatterDownstreamState.Acknowledged, overview.DownstreamState);
        Assert.Equal("quality action acknowledged", overview.DownstreamAction);
        Assert.Equal(
            "source signal + Germany affiliate evidence + routed quality action acknowledgement",
            overview.DecisionBasis);
        Assert.Equal("DE affiliate follow-up due window", overview.ClockName);
        Assert.False(overview.IsClockActive);
        Assert.False(overview.IsClockNearingBreach);
        Assert.Equal(new DateTime(2026, 3, 17, 8, 20, 0, DateTimeKind.Utc), overview.DueAtUtc);
        Assert.Null(overview.TimeRemaining);
    }

    [Fact]
    public async Task MatterOverviewEndpoint_ReturnsDelayPathOverviewWithActiveClock()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var overview = await client.GetFromJsonAsync<ComplianceMatterOverviewResponse>(
            $"/api/compliance/matters/{ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath}/overview");

        Assert.NotNull(overview);
        Assert.Equal(ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath, overview.ScenarioId);
        Assert.Equal("Germany Affiliate Safety", overview.Owner);
        Assert.Equal("DE affiliate follow-up due window active and nearing breach", overview.ActiveClock);
        Assert.Equal("waiting on Germany affiliate review evidence", overview.Blocker);
        Assert.Equal(ComplianceMatterDownstreamState.Pending, overview.DownstreamState);
        Assert.Equal("quality action pending", overview.DownstreamAction);
        Assert.Equal("source signal + open affiliate review request + no local evidence yet", overview.DecisionBasis);
        Assert.Equal("DE affiliate follow-up due window", overview.ClockName);
        Assert.True(overview.IsClockActive);
        Assert.True(overview.IsClockNearingBreach);
        Assert.Equal(new DateTime(2026, 3, 17, 9, 15, 0, DateTimeKind.Utc), overview.DueAtUtc);
        Assert.Equal(TimeSpan.FromHours(6), overview.TimeRemaining);
    }

    [Fact]
    public async Task MatterOverviewEndpoint_ReturnsDownstreamRetryOverview()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var overview = await client.GetFromJsonAsync<ComplianceMatterOverviewResponse>(
            $"/api/compliance/matters/{ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry}/overview");

        Assert.NotNull(overview);
        Assert.Equal(ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry, overview.ScenarioId);
        Assert.Equal("Global Safety Ops", overview.Owner);
        Assert.Equal("none; DE affiliate follow-up satisfied", overview.ActiveClock);
        Assert.Equal("waiting on downstream quality acknowledgement after retry", overview.Blocker);
        Assert.Equal(ComplianceMatterDownstreamState.Pending, overview.DownstreamState);
        Assert.Equal("quality action pending after one failed attempt", overview.DownstreamAction);
        Assert.Equal(
            "source signal + Germany affiliate evidence + downstream failure event + retry decision",
            overview.DecisionBasis);
        Assert.False(overview.IsClockActive);
        Assert.False(overview.IsClockNearingBreach);
        Assert.Equal(new DateTime(2026, 3, 17, 10, 20, 0, DateTimeKind.Utc), overview.DueAtUtc);
        Assert.Null(overview.TimeRemaining);
    }

    [Fact]
    public async Task MatterQueueEndpoint_DefaultsToAllView_AndReturnsDeterministicQueueOrder()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var queue = await client.GetFromJsonAsync<ComplianceMatterQueueResponse>(
            "/api/compliance/matters/queue");

        Assert.NotNull(queue);
        Assert.Equal(ComplianceMatterQueueViews.All, queue.View);
        Assert.Equal(3, queue.Items.Count);
        Assert.Equal(
            [
                ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath,
                ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry,
                ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath
            ],
            queue.Items.Select(item => item.ScenarioId));

        var first = queue.Items[0];
        Assert.Equal("post-intake cross-market safety follow-up matter", first.MatterName);
        Assert.Equal("Germany", first.Jurisdiction);
        Assert.Equal("Germany Affiliate Safety", first.Owner);
        Assert.Equal("DE affiliate follow-up due window active and nearing breach", first.ActiveClock);
        Assert.Equal("waiting on Germany affiliate review evidence", first.Blocker);
        Assert.Equal(ComplianceMatterDownstreamState.Pending, first.DownstreamState);
        Assert.Equal("quality action pending", first.DownstreamAction);
        Assert.Equal("source signal + open affiliate review request + no local evidence yet", first.DecisionBasis);
        Assert.Equal(ComplianceMatterQueueViews.ActiveClock, first.QueueReason);
    }

    [Fact]
    public async Task MatterQueueEndpoint_ActiveClockView_IsolatesDelayPath()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var queue = await client.GetFromJsonAsync<ComplianceMatterQueueResponse>(
            $"/api/compliance/matters/queue?view={ComplianceMatterQueueViews.ActiveClock}");

        Assert.NotNull(queue);
        var item = Assert.Single(queue.Items);
        Assert.Equal(ComplianceMatterQueueViews.ActiveClock, queue.View);
        Assert.Equal(ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath, item.ScenarioId);
    }

    [Fact]
    public async Task MatterQueueEndpoint_BlockedDownstreamView_IncludesRetryPath()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var queue = await client.GetFromJsonAsync<ComplianceMatterQueueResponse>(
            $"/api/compliance/matters/queue?view={ComplianceMatterQueueViews.BlockedDownstream}");

        Assert.NotNull(queue);
        Assert.Equal(2, queue.Items.Count);
        Assert.Contains(queue.Items, item => item.ScenarioId == ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry);
        Assert.Equal(
            [
                ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath,
                ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry
            ],
            queue.Items.Select(item => item.ScenarioId));
    }

    [Fact]
    public async Task MatterQueueEndpoint_MissingEvidenceView_IncludesDelayPath()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var queue = await client.GetFromJsonAsync<ComplianceMatterQueueResponse>(
            $"/api/compliance/matters/queue?view={ComplianceMatterQueueViews.MissingEvidence}");

        Assert.NotNull(queue);
        var item = Assert.Single(queue.Items);
        Assert.Equal(ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath, item.ScenarioId);
        Assert.Equal("waiting on Germany affiliate review evidence", item.Blocker);
    }

    [Fact]
    public async Task MatterQueueEndpoint_MissingOwnerView_ReturnsEmptyList()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var queue = await client.GetFromJsonAsync<ComplianceMatterQueueResponse>(
            $"/api/compliance/matters/queue?view={ComplianceMatterQueueViews.MissingOwner}");

        Assert.NotNull(queue);
        Assert.Equal(ComplianceMatterQueueViews.MissingOwner, queue.View);
        Assert.Empty(queue.Items);
    }

    [Fact]
    public async Task MatterQueueEndpoint_ReturnsBadRequest_ForUnsupportedView()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/api/compliance/matters/queue?view=needs-dashboard");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task MatterTimelineEndpoint_ReturnsHappyPathTimelineInReplayOrder()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var timeline = await client.GetFromJsonAsync<ComplianceMatterTimelineResponse>(
            $"/api/compliance/matters/{ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath}/timeline");

        Assert.NotNull(timeline);
        Assert.Equal(ComplianceMatterReplayScenarioIds.DeAffiliateHappyPath, timeline.ScenarioId);
        Assert.Equal("post-intake cross-market safety follow-up matter", timeline.MatterName);
        Assert.Equal("Germany", timeline.Jurisdiction);
        Assert.Equal(6, timeline.Events.Count);
        Assert.Equal(
            [
                "source-signal-emitted",
                "matter-opened",
                "affiliate-review-requested",
                "affiliate-evidence-received",
                "downstream-action-requested",
                "downstream-action-acknowledged"
            ],
            timeline.Events.Select(evt => evt.EventType));
        Assert.Equal(new DateTime(2026, 3, 14, 8, 0, 0, DateTimeKind.Utc), timeline.Events[0].TimestampUtc);
        Assert.Equal("Germany affiliate review evidence", timeline.Events[3].Evidence);
        Assert.Equal(ComplianceMatterDownstreamState.Pending, timeline.Events[4].DownstreamState);
        Assert.Equal(ComplianceMatterDownstreamState.Acknowledged, timeline.Events[5].DownstreamState);
    }

    [Fact]
    public async Task MatterTimelineEndpoint_ReturnsDelayPathBlockerAndClockNearingBreach()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var timeline = await client.GetFromJsonAsync<ComplianceMatterTimelineResponse>(
            $"/api/compliance/matters/{ComplianceMatterReplayScenarioIds.DeAffiliateDelayPath}/timeline");

        Assert.NotNull(timeline);
        Assert.Equal(4, timeline.Events.Count);

        var breachEvent = timeline.Events[^1];
        Assert.Equal("clock-nearing-breach", breachEvent.EventType);
        Assert.Equal(new DateTime(2026, 3, 17, 3, 15, 0, DateTimeKind.Utc), breachEvent.TimestampUtc);
        Assert.Equal("Germany Affiliate Safety", breachEvent.Owner);
        Assert.Equal("waiting on Germany affiliate review evidence", breachEvent.Blocker);
        Assert.Equal(ComplianceMatterDownstreamState.Pending, breachEvent.DownstreamState);
        Assert.Contains("nearing breach", breachEvent.Summary, StringComparison.Ordinal);
    }

    [Fact]
    public async Task MatterTimelineEndpoint_ReturnsRetryFailureSchedulingAndRetriedState()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var timeline = await client.GetFromJsonAsync<ComplianceMatterTimelineResponse>(
            $"/api/compliance/matters/{ComplianceMatterReplayScenarioIds.DeAffiliateDownstreamRetry}/timeline");

        Assert.NotNull(timeline);
        Assert.Equal(8, timeline.Events.Count);

        Assert.Collection(
            timeline.Events.Skip(4),
            requested =>
            {
                Assert.Equal("downstream-action-requested", requested.EventType);
                Assert.Equal(ComplianceMatterDownstreamState.Pending, requested.DownstreamState);
            },
            failed =>
            {
                Assert.Equal("downstream-action-failed", failed.EventType);
                Assert.Equal("queue timeout", failed.Evidence);
                Assert.Null(failed.Blocker);
                Assert.Equal(ComplianceMatterDownstreamState.Failed, failed.DownstreamState);
            },
            scheduled =>
            {
                Assert.Equal("downstream-retry-scheduled", scheduled.EventType);
                Assert.Equal("waiting on downstream quality acknowledgement after retry", scheduled.Blocker);
                Assert.Equal(ComplianceMatterDownstreamState.Failed, scheduled.DownstreamState);
            },
            retried =>
            {
                Assert.Equal("downstream-action-retried", retried.EventType);
                Assert.Equal("waiting on downstream quality acknowledgement after retry", retried.Blocker);
                Assert.Equal(ComplianceMatterDownstreamState.Pending, retried.DownstreamState);
            });
    }

    [Fact]
    public async Task MatterTimelineEndpoint_ReturnsNotFound_ForUnsupportedScenarioId()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/api/compliance/matters/not-a-locked-scenario/timeline");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task MatterOverviewEndpoint_ReturnsNotFound_ForUnsupportedScenarioId()
    {
        var adminConnectionString = await postgresFixture.CreateDatabaseAsync();
        using var factory = new SentinelApiFactory(adminConnectionString);
        using var client = factory.CreateClient();

        var response = await client.GetAsync("/api/compliance/matters/not-a-locked-scenario/overview");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    private static async Task<OutboxDispatchRecord?> GetDispatchRecordAsync(SentinelApiFactory factory, Guid requestId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<MessagingDbContext>();

        return await dbContext.DispatchRecords
            .AsNoTracking()
            .OrderBy(record => record.CreatedAtUtc)
            .FirstOrDefaultAsync(record => record.RequestId == requestId);
    }

    private static async Task ProvisionLegacyEnsureCreatedSchemaAsync(string adminConnectionString)
    {
        var options = new DbContextOptionsBuilder<MessagingDbContext>()
            .UseNpgsql(adminConnectionString)
            .UseSnakeCaseNamingConvention()
            .Options;

        await using var dbContext = new MessagingDbContext(options);
        await dbContext.Database.EnsureCreatedAsync();
        await dbContext.Database.ExecuteSqlRawAsync(
            """
ALTER TABLE IF EXISTS masstransit.dispatch_records
    DROP COLUMN IF EXISTS actor_id,
    DROP COLUMN IF EXISTS actor_type,
    DROP COLUMN IF EXISTS actor_display_name;

DROP TABLE IF EXISTS "__EFMigrationsHistory";
""");
    }

    private static async Task<IReadOnlyList<string>> GetDispatchRecordColumnNamesAsync(string adminConnectionString)
    {
        await using var connection = new NpgsqlConnection(adminConnectionString);
        await connection.OpenAsync();

        await using var command = connection.CreateCommand();
        command.CommandText =
            """
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'masstransit'
  AND table_name = 'dispatch_records'
ORDER BY ordinal_position;
""";

        var columnNames = new List<string>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            columnNames.Add(reader.GetString(0));
        }

        return columnNames;
    }

    private static async Task<IReadOnlyList<(string MigrationId, string ProductVersion)>> GetMigrationHistoryAsync(string adminConnectionString)
    {
        await using var connection = new NpgsqlConnection(adminConnectionString);
        await connection.OpenAsync();

        await using var existsCommand = connection.CreateCommand();
        existsCommand.CommandText =
            """
SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = '__EFMigrationsHistory'
);
""";

        var hasMigrationHistory = Convert.ToBoolean(await existsCommand.ExecuteScalarAsync() ?? false);
        if (!hasMigrationHistory)
        {
            return Array.Empty<(string MigrationId, string ProductVersion)>();
        }

        await using var command = connection.CreateCommand();
        command.CommandText =
            """
SELECT "MigrationId", "ProductVersion"
FROM "__EFMigrationsHistory"
ORDER BY "MigrationId";
""";

        var rows = new List<(string MigrationId, string ProductVersion)>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            rows.Add((reader.GetString(0), reader.GetString(1)));
        }

        return rows;
    }

    private static async Task SeedDispatchAsync(
        SentinelApiFactory factory,
        Guid requestId,
        DateTime createdAtUtc,
        string? actorId = null,
        string? actorType = null,
        string? actorDisplayName = null)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<MessagingDbContext>();

        dbContext.DispatchRecords.Add(new OutboxDispatchRecord
        {
            RequestId = requestId,
            SendMode = "send",
            Destination = "queue:compliance",
            CreatedAtUtc = createdAtUtc,
            ActorId = actorId,
            ActorType = actorType,
            ActorDisplayName = actorDisplayName
        });

        await dbContext.SaveChangesAsync();
    }

    private static async Task SeedLedgerEventAsync(
        SentinelApiFactory factory,
        Guid requestId,
        Guid messageId,
        string status,
        DateTime processedAtUtc,
        string? traceId = null,
        string? errorCode = null,
        string? errorDetail = null)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<MessagingDbContext>();

        dbContext.ComplianceLedgerEvents.Add(new ComplianceLedgerEvent
        {
            RequestId = requestId,
            MessageId = messageId,
            Source = "tests",
            ContentLength = 12,
            Status = status,
            HandlerDurationMs = 42,
            ProcessedAtUtc = processedAtUtc,
            TraceId = traceId,
            ErrorCode = errorCode,
            ErrorDetail = errorDetail
        });

        await dbContext.SaveChangesAsync();
    }
}
