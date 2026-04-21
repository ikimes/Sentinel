using Microsoft.Extensions.Configuration;

namespace Sentinel.Web.Features.InternalActors;

public interface IInternalActorProvider
{
    InternalActorIdentity GetCurrentActor();
}

public sealed record InternalActorIdentity(
    string? ActorId,
    string? ActorType,
    string? ActorDisplayName);

public static class InternalActorHeaderNames
{
    public const string ActorId = "X-Actor-Id";
    public const string ActorType = "X-Actor-Type";
    public const string ActorDisplayName = "X-Actor-Display-Name";
}

public sealed class ConfigurationInternalActorProvider(IConfiguration configuration) : IInternalActorProvider
{
    private const string DefaultActorId = "sentinel-workspace";
    private const string DefaultActorType = "internal-user";
    private const string DefaultActorDisplayName = "Sentinel Workspace";

    public InternalActorIdentity GetCurrentActor() =>
        new(
            Normalize(configuration["Sentinel:InternalActor:Id"], 128) ?? DefaultActorId,
            Normalize(configuration["Sentinel:InternalActor:Type"], 64) ?? DefaultActorType,
            Normalize(configuration["Sentinel:InternalActor:DisplayName"], 256) ?? DefaultActorDisplayName);

    private static string? Normalize(string? value, int maxLength)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return null;
        }

        return normalized.Length <= maxLength
            ? normalized
            : normalized[..maxLength];
    }
}

public sealed class InternalActorHeadersHandler(IInternalActorProvider actorProvider) : DelegatingHandler
{
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var actor = actorProvider.GetCurrentActor();

        ApplyHeader(request, InternalActorHeaderNames.ActorId, actor.ActorId);
        ApplyHeader(request, InternalActorHeaderNames.ActorType, actor.ActorType);
        ApplyHeader(request, InternalActorHeaderNames.ActorDisplayName, actor.ActorDisplayName);

        return base.SendAsync(request, cancellationToken);
    }

    private static void ApplyHeader(HttpRequestMessage request, string name, string? value)
    {
        request.Headers.Remove(name);

        if (!string.IsNullOrWhiteSpace(value))
        {
            request.Headers.TryAddWithoutValidation(name, value);
        }
    }
}
