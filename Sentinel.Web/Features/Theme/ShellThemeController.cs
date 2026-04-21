namespace Sentinel.Web.Features.Theme;

public sealed class ShellThemeController
{
    public const string Light = "light";
    public const string Dark = "dark";

    public event Action? Changed;

    public string Preference { get; private set; } = Dark;

    public void SetPreference(string preference)
    {
        var normalized = Normalize(preference);
        if (string.Equals(Preference, normalized, StringComparison.Ordinal))
        {
            return;
        }

        Preference = normalized;
        Changed?.Invoke();
    }

    private static string Normalize(string? preference) =>
        preference?.ToLowerInvariant() switch
        {
            Light => Light,
            Dark => Dark,
            _ => Dark
        };
}
