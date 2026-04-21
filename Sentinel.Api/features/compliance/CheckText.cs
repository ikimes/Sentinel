namespace Sentinel.Api.Features.Compliance;

public static class CheckTextEndpoint
{
    public static void Map(WebApplication app)
    {
        app.MapGet("/api/compliance/matters/queue", async (
            string? view,
            IComplianceReadService readService,
            CancellationToken cancellationToken) =>
        {
            if (!ComplianceMatterQueueViews.TryNormalize(view, out var normalizedView))
            {
                return Results.BadRequest(new
                {
                    Error = "Unsupported queue view.",
                    SupportedViews = ComplianceMatterQueueViews.Supported
                });
            }

            var response = await readService.GetMatterQueueAsync(normalizedView, cancellationToken);
            return Results.Ok(response);
        });

        app.MapGet("/api/compliance/matters/{scenarioId}/timeline", async (
            string scenarioId,
            IComplianceReadService readService,
            CancellationToken cancellationToken) =>
        {
            var response = await readService.GetMatterTimelineAsync(scenarioId, cancellationToken);
            return response is null
                ? Results.NotFound()
                : Results.Ok(response);
        });

        app.MapGet("/api/compliance/matters/{scenarioId}/overview", async (
            string scenarioId,
            IComplianceReadService readService,
            CancellationToken cancellationToken) =>
        {
            var response = await readService.GetMatterOverviewAsync(scenarioId, cancellationToken);
            return response is null
                ? Results.NotFound()
                : Results.Ok(response);
        });

        app.MapGet("/api/compliance/check/recent", async (
            int? take,
            IComplianceReadService readService,
            CancellationToken cancellationToken) =>
        {
            var response = await readService.GetRecentAsync(take ?? 25, cancellationToken);
            return Results.Ok(response);
        });

        app.MapGet("/api/compliance/check/{requestId:guid}/history", async (
            Guid requestId,
            IComplianceReadService readService,
            CancellationToken cancellationToken) =>
        {
            var response = await readService.GetHistoryAsync(requestId, cancellationToken);
            return response is null
                ? Results.NotFound()
                : Results.Ok(response);
        });

        app.MapGet("/api/compliance/check/{requestId:guid}", async (
            Guid requestId,
            IComplianceReadService readService,
            CancellationToken cancellationToken) =>
        {
            var response = await readService.GetStatusAsync(requestId, cancellationToken);
            return response is null
                ? Results.NotFound()
                : Results.Ok(response);
        });

        app.MapPost("/api/compliance/check", async (
            CheckTextRequest request,
            HttpRequest httpRequest,
            IComplianceAcceptanceService acceptanceService,
            CancellationToken cancellationToken) =>
        {
            if (string.IsNullOrWhiteSpace(request.Content))
            {
                return Results.BadRequest("Content is required");
            }

            try
            {
                var response = await acceptanceService.AcceptAsync(request, httpRequest, cancellationToken);
                return Results.Ok(response);
            }
            catch (NotSupportedException ex)
            {
                return Results.Problem(
                    title: "Compliance acceptance unavailable",
                    detail: ex.Message,
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        });
    }
}
