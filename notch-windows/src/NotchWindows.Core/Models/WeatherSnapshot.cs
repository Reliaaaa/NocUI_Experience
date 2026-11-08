namespace NotchWindows.Core.Models;

/// <summary>Current weather returned by the weather service.</summary>
public sealed record WeatherSnapshot(double TemperatureCelsius, string ConditionText, int WeatherCode);
