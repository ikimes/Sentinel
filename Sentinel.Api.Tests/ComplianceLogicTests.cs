extern alias sentinelweb;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Sentinel.Api.Features.Compliance;
using Sentinel.Shared.Messaging;
using sentinelweb::Sentinel.Web.Features.InternalActors;

namespace Sentinel.Api.Tests;

public sealed class ComplianceLogicTests
{
    [Theory]
    [InlineData(null, ComplianceStatusNames.Accepted)]
    [InlineData("", ComplianceStatusNames.Accepted)]
    [InlineData("processed", ComplianceStatusNames.Processed)]
    [InlineData("failed", ComplianceStatusNames.Failed)]
    [InlineData("unexpected", ComplianceStatusNames.Accepted)]
    public void StatusMapping_UsesUiVocabulary(string? ledgerStatus, string expectedStatus)
    {
        var status = ComplianceStatusNames.Map(ledgerStatus);

        Assert.Equal(expectedStatus, status);
    }

    [Fact]
    public void ActorHeaderNormalization_ConvertsMissingAndWhitespaceValuesToNull()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers[ComplianceActorHeaders.ActorId] = "   ";
        context.Request.Headers[ComplianceActorHeaders.ActorType] = "";

        var actor = ComplianceActorHeaders.Parse(context.Request);

        Assert.Null(actor.ActorId);
        Assert.Null(actor.ActorType);
        Assert.Null(actor.ActorDisplayName);
    }

    [Fact]
    public void ActorHeaderNormalization_TrimsAndClampsValues()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers[ComplianceActorHeaders.ActorId] = $"  {new string('a', 140)}  ";
        context.Request.Headers[ComplianceActorHeaders.ActorType] = $"  {new string('b', 80)}  ";
        context.Request.Headers[ComplianceActorHeaders.ActorDisplayName] = $"  {new string('c', 300)}  ";

        var actor = ComplianceActorHeaders.Parse(context.Request);

        Assert.Equal(new string('a', 128), actor.ActorId);
        Assert.Equal(new string('b', 64), actor.ActorType);
        Assert.Equal(new string('c', 256), actor.ActorDisplayName);
    }

    [Fact]
    public void ActorResolver_UsesTrustedHeaderParsingSemantics()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers[ComplianceActorHeaders.ActorId] = "  reviewer-123  ";
        context.Request.Headers[ComplianceActorHeaders.ActorType] = "  internal-user  ";
        context.Request.Headers[ComplianceActorHeaders.ActorDisplayName] = "  Casey Reviewer  ";
        var resolver = new TrustedHeaderComplianceActorResolver();

        var actor = resolver.Resolve(context.Request);

        Assert.Equal("reviewer-123", actor.ActorId);
        Assert.Equal("internal-user", actor.ActorType);
        Assert.Equal("Casey Reviewer", actor.ActorDisplayName);
    }

    [Fact]
    public async Task InternalActorHeadersHandler_AppliesActorHeadersFromProvider()
    {
        var provider = new StubInternalActorProvider(
            new InternalActorIdentity("workspace-actor", "internal-user", "Sentinel Workspace"));
        var captureHandler = new CaptureRequestHandler();
        using var client = new HttpClient(new InternalActorHeadersHandler(provider)
        {
            InnerHandler = captureHandler
        });

        using var response = await client.GetAsync("https://example.test/api/compliance/matters/queue");

        response.EnsureSuccessStatusCode();
        Assert.NotNull(captureHandler.Request);
        Assert.Equal("workspace-actor", captureHandler.Request.Headers.GetValues(InternalActorHeaderNames.ActorId).Single());
        Assert.Equal("internal-user", captureHandler.Request.Headers.GetValues(InternalActorHeaderNames.ActorType).Single());
        Assert.Equal("Sentinel Workspace", captureHandler.Request.Headers.GetValues(InternalActorHeaderNames.ActorDisplayName).Single());
    }

    [Fact]
    public async Task StatusProjection_UsesEarliestDispatchRecordForAcceptedTimeAndActor()
    {
        await using var dbContext = CreateDbContext();
        var requestId = Guid.NewGuid();
        var acceptedUtc = new DateTime(2026, 3, 12, 12, 0, 0, DateTimeKind.Utc);

        dbContext.DispatchRecords.AddRange(
            new OutboxDispatchRecord
            {
                RequestId = requestId,
                SendMode = "send",
                Destination = "queue:compliance",
                CreatedAtUtc = acceptedUtc.AddMinutes(2),
                ActorId = "later-actor",
                ActorType = "later-type",
                ActorDisplayName = "Later Actor"
            },
            new OutboxDispatchRecord
            {
                RequestId = requestId,
                SendMode = "send",
                Destination = "queue:compliance",
                CreatedAtUtc = acceptedUtc,
                ActorId = "earliest-actor",
                ActorType = "internal-user",
                ActorDisplayName = "Earliest Actor"
            });
        await dbContext.SaveChangesAsync();

        var service = CreateReadService(dbContext);

        var response = await service.GetStatusAsync(requestId, CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal(ComplianceStatusNames.Accepted, response.Status);
        Assert.Equal(acceptedUtc, response.AcceptedUtc);
        Assert.Equal("earliest-actor", response.ActorId);
        Assert.Equal("internal-user", response.ActorType);
        Assert.Equal("Earliest Actor", response.ActorDisplayName);
        Assert.Null(response.ProcessedAtUtc);
    }

    [Fact]
    public async Task HistoryProjection_UsesLatestLedgerEventForTerminalSelection()
    {
        await using var dbContext = CreateDbContext();
        var requestId = Guid.NewGuid();
        var acceptedUtc = new DateTime(2026, 3, 12, 12, 0, 0, DateTimeKind.Utc);
        var processedMessageId = Guid.NewGuid();
        var failedMessageId = Guid.NewGuid();
        var processedUtc = acceptedUtc.AddSeconds(5);
        var failedUtc = acceptedUtc.AddSeconds(12);

        dbContext.DispatchRecords.Add(new OutboxDispatchRecord
        {
            RequestId = requestId,
            SendMode = "send",
            Destination = "queue:compliance",
            CreatedAtUtc = acceptedUtc,
            ActorId = "actor-123",
            ActorType = "internal-user",
            ActorDisplayName = "Casey Reviewer"
        });
        dbContext.ComplianceLedgerEvents.AddRange(
            new ComplianceLedgerEvent
            {
                RequestId = requestId,
                MessageId = processedMessageId,
                Status = ComplianceStatusNames.Processed,
                ProcessedAtUtc = processedUtc,
                TraceId = "trace-processed"
            },
            new ComplianceLedgerEvent
            {
                RequestId = requestId,
                MessageId = failedMessageId,
                Status = ComplianceStatusNames.Failed,
                ProcessedAtUtc = failedUtc,
                ErrorCode = "InvalidOperationException",
                ErrorDetail = "forced",
                TraceId = "trace-failed"
            });
        await dbContext.SaveChangesAsync();

        var service = CreateReadService(dbContext);

        var response = await service.GetHistoryAsync(requestId, CancellationToken.None);

        Assert.NotNull(response);
        Assert.Equal(ComplianceStatusNames.Failed, response.Status);
        Assert.Equal(acceptedUtc, response.AcceptedUtc);
        Assert.Equal(failedUtc, response.ProcessedAtUtc);
        Assert.Equal("actor-123", response.ActorId);
        Assert.Equal(3, response.Events.Count);
        Assert.Collection(
            response.Events,
            evt =>
            {
                Assert.Equal(ComplianceStatusNames.Accepted, evt.Status);
                Assert.Equal(acceptedUtc, evt.TimestampUtc);
                Assert.Null(evt.MessageId);
            },
            evt =>
            {
                Assert.Equal(ComplianceStatusNames.Processed, evt.Status);
                Assert.Equal(processedUtc, evt.TimestampUtc);
                Assert.Equal(processedMessageId, evt.MessageId);
                Assert.Equal("trace-processed", evt.TraceId);
            },
            evt =>
            {
                Assert.Equal(ComplianceStatusNames.Failed, evt.Status);
                Assert.Equal(failedUtc, evt.TimestampUtc);
                Assert.Equal(failedMessageId, evt.MessageId);
                Assert.Equal("trace-failed", evt.TraceId);
                Assert.Equal("InvalidOperationException", evt.ErrorCode);
                Assert.Equal("forced", evt.ErrorDetail);
            });
    }

    private static MessagingDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<MessagingDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new MessagingDbContext(options);
    }

    private static ComplianceReadService CreateReadService(MessagingDbContext dbContext) =>
        new(
            dbContext,
            NullLogger<ComplianceReadService>.Instance,
            new ConfigurationBuilder().AddInMemoryCollection().Build());

    private sealed class StubInternalActorProvider(InternalActorIdentity actor) : IInternalActorProvider
    {
        public InternalActorIdentity GetCurrentActor() => actor;
    }

    private sealed class CaptureRequestHandler : HttpMessageHandler
    {
        public HttpRequestMessage? Request { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Request = request;

            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent("{}")
            });
        }
    }
}
