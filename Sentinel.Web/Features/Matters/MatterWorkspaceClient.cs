using System.Net;
using System.Net.Http.Json;

namespace Sentinel.Web.Features.Matters;

public sealed class MatterWorkspaceClient(HttpClient httpClient)
{
    public async Task<ComplianceMatterQueueResponse> GetQueueAsync(
        string view,
        CancellationToken cancellationToken = default)
    {
        var requestUri = string.Equals(view, MatterQueueViews.All, StringComparison.Ordinal)
            ? "/api/compliance/matters/queue"
            : $"/api/compliance/matters/queue?view={Uri.EscapeDataString(view)}";

        var response = await httpClient.GetFromJsonAsync<ComplianceMatterQueueResponse>(requestUri, cancellationToken);
        return response ?? new ComplianceMatterQueueResponse(view, []);
    }

    public Task<ComplianceMatterOverviewResponse?> GetOverviewAsync(
        string scenarioId,
        CancellationToken cancellationToken = default) =>
        GetOptionalAsync<ComplianceMatterOverviewResponse>(
            $"/api/compliance/matters/{Uri.EscapeDataString(scenarioId)}/overview",
            cancellationToken);

    public Task<ComplianceMatterTimelineResponse?> GetTimelineAsync(
        string scenarioId,
        CancellationToken cancellationToken = default) =>
        GetOptionalAsync<ComplianceMatterTimelineResponse>(
            $"/api/compliance/matters/{Uri.EscapeDataString(scenarioId)}/timeline",
            cancellationToken);

    private async Task<T?> GetOptionalAsync<T>(string requestUri, CancellationToken cancellationToken)
    {
        using var response = await httpClient.GetAsync(requestUri, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            return default;
        }

        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<T>(cancellationToken: cancellationToken);
    }
}
