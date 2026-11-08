using System.Net.Http.Json;
using System.Text.Json.Serialization;
using NotchWindows.Core.Abstractions;
using NotchWindows.Core.Models;

namespace NotchWindows.Services.Network;

/// <summary>F-021 — Open-Meteo, tanpa API key (lihat docs/04-services.md untuk kontrak JSON).</summary>
public sealed class WeatherService : IWeatherService
{
    private readonly HttpClient _httpClient;

    public WeatherService(HttpClient httpClient) => _httpClient = httpClient;

    public async Task<WeatherSnapshot?> GetCurrentAsync(double latitude, double longitude, CancellationToken ct = default)
    {
        var url = $"https://api.open-meteo.com/v1/forecast?latitude={latitude.ToString(global::System.Globalization.CultureInfo.InvariantCulture)}" +
                  $"&longitude={longitude.ToString(global::System.Globalization.CultureInfo.InvariantCulture)}&current_weather=true";
        try
        {
            var response = await _httpClient.GetFromJsonAsync<OpenMeteoResponse>(url, ct);
            if (response?.current_weather is null) return null;
            return new WeatherSnapshot(
                response.current_weather.temperature,
                DescribeWeatherCode(response.current_weather.weathercode),
                response.current_weather.weathercode);
        }
        catch (HttpRequestException)
        {
            return null; // offline atau API down -> dashboard tampil tanpa cuaca, lihat F-021
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            // QA fix (bug QA-007, P2): HttpClient timeout melempar TaskCanceledException, bukan
            // HttpRequestException. Sebelumnya tidak ditangkap -> exception tak tertangani bisa
            // menjalar sampai DashboardViewModel. Hanya ditangani bila BUKAN pembatalan caller sendiri.
            return null;
        }
        catch (global::System.Text.Json.JsonException)
        {
            // QA fix (bug QA-007, P2): respons API berubah format / tidak valid -> jangan crash,
            // perlakukan sama seperti offline.
            return null;
        }
    }

    private static string DescribeWeatherCode(int code) => code switch
    {
        0 => "Cerah",
        1 or 2 or 3 => "Berawan",
        45 or 48 => "Berkabut",
        >= 51 and <= 67 => "Hujan ringan",
        >= 71 and <= 77 => "Salju",
        >= 80 and <= 82 => "Hujan deras",
        >= 95 => "Badai petir",
        _ => "Tidak diketahui",
    };

    // Nama properti SENGAJA snake_case: cocok persis dengan field JSON asli Open-Meteo
    // (current_weather / temperature / weathercode) tanpa perlu JsonPropertyName, supaya
    // deserialisasi default System.Text.Json (case-sensitive) tetap benar.
    private sealed class OpenMeteoResponse
    {
        public CurrentWeatherDto? current_weather { get; set; }
    }

    private sealed class CurrentWeatherDto
    {
        public double temperature { get; set; }
        public int weathercode { get; set; }
    }
}
