namespace NotchWindows.Core.Models;

/// <summary>Data cuaca ringkas untuk Dashboard (F-021). Sumber: Open-Meteo, tanpa API key.</summary>
public sealed record WeatherInfo
{
    public double TemperatureCelsius { get; init; }
    public int WeatherCode { get; init; }
    public string ConditionText { get; init; } = string.Empty;
    public double Latitude { get; init; }
    public double Longitude { get; init; }
    public DateTimeOffset FetchedAt { get; init; } = DateTimeOffset.Now;

    public static WeatherInfo Placeholder { get; } = new()
    {
        TemperatureCelsius = 28,
        WeatherCode = 0,
        ConditionText = "Cerah (placeholder)",
    };
}
