using NotchWindows.Core.Models;

namespace NotchWindows.Core.Abstractions;

/// <summary>Abstraksi klien cuaca (F-021). Implementasi: Services/Network/WeatherService (Open-Meteo).
/// QA fix (bug QA-022, P0): tipe balik sebelumnya <c>Task&lt;WeatherInfo&gt;</c> tidak cocok dengan
/// satu-satunya implementasi nyata (<c>WeatherService.GetCurrentAsync</c> mengembalikan
/// <c>Task&lt;WeatherSnapshot?&gt;</c>, nullable karena bisa gagal diam-diam — lihat penanganan error
/// QA-007) maupun pemanggilnya (DashboardViewModel.Weather bertipe WeatherSnapshot?) -> CS0738, tidak
/// akan kompilasi. Disamakan ke kontrak yang sungguh dipakai di kedua sisi. Model WeatherInfo (tidak lagi
/// dipakai) dibiarkan di Core/Models untuk referensi desain, lihat 03-design.md.</summary>
public interface IWeatherService
{
    Task<WeatherSnapshot?> GetCurrentAsync(double latitude, double longitude, CancellationToken ct = default);
}
