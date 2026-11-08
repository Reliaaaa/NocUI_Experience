# notch-windows — Services

Referensi: `01-features.md`, `02-architecture.md`. Layer `NotchWindows.Services` mengimplementasikan interface dari `NotchWindows.Core.Abstractions`. Tidak ada backend server wajib untuk Rilis 1/2 — semua service memanggil Windows API/WMI lokal atau API publik HTTP langsung dari client. Backend server (sync cloud, akun multi-device) **tidak dirancang di sini**; bila dibutuhkan di fase lanjutan (di luar backlog saat ini), itu jadi proyek terpisah opsional, bukan prasyarat fitur manapun di `01-features.md`.

## 1. INowPlayingService (F-010, F-011, F-012)

```csharp
public interface INowPlayingService
{
    NowPlayingInfo? Current { get; }
    event EventHandler<NowPlayingInfo?> NowPlayingChanged;
    event EventHandler<PlaybackPosition> PositionChanged;

    Task<bool> TryPlayAsync();
    Task<bool> TryPauseAsync();
    Task<bool> TrySkipNextAsync();
    Task<bool> TrySkipPreviousAsync();
    Task<bool> TrySeekAsync(TimeSpan position); // P2, F-012 drag-to-seek
}

public record NowPlayingInfo(
    string Title, string Artist, string AlbumTitle,
    byte[]? AlbumArtBytes, string SourceAppId, bool IsPlaying);

public record PlaybackPosition(TimeSpan Position, TimeSpan Duration);
```

- **Sumber data**: `Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager` (SMTC), API UWP yang bisa dipanggil dari WinUI3 desktop (Windows App SDK).
- **Strategi**: event-driven, bukan polling. Subscribe `CurrentSessionChanged` di manager; untuk current session subscribe `MediaPropertiesChanged`, `PlaybackInfoChanged`, `TimelinePropertiesChanged`. Re-subscribe otomatis saat `CurrentSessionChanged` (app sumber musik berganti, mis. Spotify → browser).
- **Album art**: `MediaPropertiesChanged.Thumbnail` adalah `IRandomAccessStreamReference` — baca ke `byte[]` di background thread, cache per track (hindari re-decode tiap event kecil).
- **Error handling**: jika tidak ada session aktif → `Current = null`, UI tampilkan state kosong (lihat `03-design.md`). Jika `TryPlayAsync()` dkk gagal (app sumber tidak dukung kontrol) → return `false`, ViewModel tampilkan tombol disabled, tidak throw ke UI.
- **Thread**: semua event SMTC datang di thread COM/background — wajib marshal ke UI lewat `DispatcherQueue.TryEnqueue` sebelum update ViewModel (`[ObservableProperty]`), sesuai catatan arsitektur §2.

## 2. ISystemMetricsService (F-004, F-022)

```csharp
public interface ISystemMetricsService
{
    SystemMetrics Snapshot { get; }
    event EventHandler<SystemMetrics> MetricsUpdated;
    void SetPollingInterval(TimeSpan interval); // dipanggil saat notch expand/collapse
}

public record SystemMetrics(
    double CpuPercent, double RamUsedPercent, double? DiskFreePercent,
    int? BatteryPercent, bool? IsCharging, double? GpuPercent, double? GpuTempC);
```

- **CPU**: `PerformanceCounter("Processor", "% Processor Time", "_Total")` — inisialisasi counter sekali (first call selalu 0, lewati sample pertama).
- **RAM**: P/Invoke `GlobalMemoryStatusEx` — lebih murah daripada WMI, tidak perlu polling interval ketat.
- **Disk**: WMI `Win32_LogicalDisk` (`FreeSpace`/`Size`) untuk drive sistem (`C:`) — **di-cache 30 detik**, nilai jarang berubah signifikan per detik.
- **Baterai**: `Windows.Devices.Power.Battery.AggregateBattery` (lebih ringan dari WMI `Win32_Battery`); jika device desktop tanpa baterai → `BatteryPercent = null`, UI sembunyikan slot itu.
- **GPU/Temp** (rilis lanjutan, opsional): `LibreHardwareMonitorLib.Computer` — butuh privilege admin untuk sebagian sensor (suhu). **Fallback graceful**: jika `Computer.Open()` gagal atau sensor null, set `GpuPercent/GpuTempC = null` tanpa exception ke caller; log sekali (bukan tiap poll) agar tidak flood log.
- **Polling**: `DispatcherQueueTimer` di ViewModel memanggil `SetPollingInterval` — 1–2 detik saat notch expanded, 5 detik saat collapsed (hemat CPU idle), sesuai `02-architecture.md` §3.3.
- **Retry/backoff**: WMI query yang gagal (COM exception, biasa terjadi transient) — retry sekali dengan delay 500ms, lalu skip 1 siklus poll (bukan throw) jika tetap gagal.

## 3. IWifiBluetoothService (F-020, F-060 rilis 2)

```csharp
public interface IWifiBluetoothService
{
    Task<bool> GetWifiEnabledAsync();
    Task SetWifiEnabledAsync(bool enabled);
    Task<bool> GetBluetoothEnabledAsync();
    Task SetBluetoothEnabledAsync(bool enabled);
    Task<IReadOnlyList<WifiNetworkInfo>> ScanWifiNetworksAsync(); // rilis 2, F-060
    Task<bool> ConnectWifiAsync(string ssid, string? password);   // rilis 2, F-060
}
```

- **Sumber**: `Windows.Devices.WiFi.WiFiAdapter` + `Windows.Devices.Radios.Radio` (toggle radio Wi-Fi/Bluetooth on/off — ini API resmi yang sama dipakai Quick Settings Windows).
- **Validasi input**: SSID non-empty, password sesuai panjang minimum WPA2 (8 karakter) sebelum `ConnectWifiAsync` dipanggil — validasi di ViewModel sebelum invoke service (fail-fast, tidak lempar request percuma ke adapter).
- **Error handling**: akses radio API butuh capability `radios` di package manifest; jika capability tidak di-declare atau izin ditolak user → exception `UnauthorizedAccessException`, service tangkap dan expose `Result<T>`-style (bukan exception bocor ke ViewModel) dengan pesan "Izin radio ditolak, buka Settings Windows".

## 4. IWeatherService (F-021, opsional P1 di Rilis 1)

```csharp
public interface IWeatherService
{
    Task<WeatherInfo?> GetCurrentWeatherAsync(double lat, double lon, CancellationToken ct);
}

public record WeatherInfo(double TemperatureC, string ConditionCode, DateTimeOffset FetchedAt);
```

- **Sumber**: Open-Meteo (`https://api.open-meteo.com/v1/forecast`), publik, tanpa API key.
- **Lokasi**: dari `Windows.Devices.Geolocation.Geolocator` (izin lokasi Windows) atau input manual kota di Settings — **tidak** scrape/guess IP-based location untuk privasi (selaras privacy note di README Poni sebagai referensi perilaku yang baik).
- **Rate limit**: Open-Meteo free tier ~10k call/hari per IP — client polling **maksimal tiap 15 menit** (cuaca tidak berubah signifikan per detik), cache hasil terakhir di memory + `WeatherInfo.FetchedAt` ditampilkan jika request gagal (stale-while-revalidate sederhana).
- **Retry/backoff**: `HttpClient` dengan `Polly`-style retry (atau manual): 2x retry exponential backoff (1s, 2s) untuk transient network error; setelah itu tampilkan data cache terakhir atau state error di UI, jangan retry tanpa batas.
- **Error handling**: `GetCurrentWeatherAsync` return `null` pada kegagalan total (bukan throw) — Dashboard ViewModel tampilkan placeholder "Cuaca tidak tersedia".

## 5. ICalendarIcsService (F-070, Rilis 2)

```csharp
public interface ICalendarIcsService
{
    Task<IReadOnlyList<CalendarEvent>> FetchEventsAsync(Uri icsUrl, CancellationToken ct);
}

public record CalendarEvent(string Title, DateTimeOffset Start, DateTimeOffset End, string? JoinUrl, string Uid);
```

- **Sumber**: link `.ics` publik (Google Calendar "Secret address in iCal format", Outlook published calendar, atau custom).
- **Parsing**: library `Ical.Net` (NuGet, parser ICS matang) — bukan regex manual.
- **Polling**: fetch berkala tiap 10–15 menit (bukan tiap detik); reminder di-schedule lokal (`DispatcherQueueTimer` atau `BackgroundTask`) berdasarkan hasil fetch terakhir.
- **Validasi input**: URL harus `https://` valid sebelum disimpan di Settings; test-fetch sekali saat user menambahkan link (feedback langsung "Link valid" / "Gagal diakses").
- **Error handling**: fetch gagal → pakai cache event terakhir (jangan hapus reminder yang sudah terjadwal), log warning, tidak crash notch.

## 6. INotificationMirrorService (F-100, Rilis 2)

```csharp
public interface INotificationMirrorService
{
    event EventHandler<MirroredNotification> NotificationReceived;
    Task<bool> RequestAccessAsync();
    Task SetSuppressNativeToastAsync(bool suppress);
}
```

- **Sumber**: `Windows.UI.Notifications.Management.UserNotificationListener` — butuh `RequestAccessAsync()` (user approve sekali di dialog OS, sama seperti README Poni sebutkan "Windows asks for permission once" untuk fitur sejenis FPS counter — pola izin resmi, bukan hook ilegal).
- **Privasi**: riwayat notifikasi disimpan **terenkripsi** (lihat `05-storage.md` §4) sesuai kriteria selesai F-100.
- **Error handling**: jika akses ditolak user → `RequestAccessAsync()` return `false`, fitur nonaktif dengan pesan jelas di Settings, bukan retry diam-diam berulang.

## 7. Konvensi umum semua service

- Semua service **singleton** (didaftarkan di DI composition root `NotchWindows.App`), stateful di memory selama proses app hidup (lihat `02-architecture.md` §2).
- Semua pemanggilan API eksternal (HTTP) **wajib** `CancellationToken` dan timeout eksplisit (default 10 detik) — tidak ada request tanpa batas waktu.
- Tidak ada service yang menyimpan/mengirim data ke server pihak ketiga di luar yang disebut eksplisit (Open-Meteo, ICS link milik user sendiri) — selaras prinsip privasi "semua data tetap di PC" yang jadi standar genre aplikasi ini.
- Logging: gunakan `Microsoft.Extensions.Logging` abstraction, bukan `Console.WriteLine`/`Debug.WriteLine` langsung, agar konsisten dan bisa dialihkan ke file rolling log opsional.
