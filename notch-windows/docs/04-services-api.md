# notch-windows — Services API (Layer `NotchWindows.Services`)

Layer ini mengimplementasikan interface `NotchWindows.Core.Abstractions` yang butuh Win32/WinRT API nyata.
Semua kode di sini valid C# (ditulis manual, bukan hasil decompile aplikasi pihak ketiga manapun) tapi
**belum pernah dikompilasi** di lingkungan ini (Linux, tanpa Windows SDK) — kompilasi & verifikasi nyata
harus dilakukan di mesin Windows dengan Visual Studio / `dotnet build` sebelum dianggap selesai (lihat
catatan QA di `06-qa-report.md`).

## Status implementasi per fitur MVP (Rilis 1)

| Fitur | Interface | Implementasi | Status |
|---|---|---|---|
| F-004 CPU/RAM/disk/baterai | `ISystemStatsService` | `SystemStatsService` + `BatteryService` | Implementasi nyata (PerformanceCounter, ComputerInfo, DriveInfo, Windows.System.Power) |
| F-010/011/012 SMTC now-playing | `IMusicService` | `SmtcMusicService` | Implementasi nyata (GlobalSystemMediaTransportControlsSessionManager) |
| F-020 Toggle Wi-Fi/Bluetooth | `INetworkService` | `NetworkToggleService` | Implementasi nyata (Windows.Devices.Radios) |
| F-020 Toggle Dark Mode/Mic/Lock | `IQuickToggleService` (baru, ditambahkan di iterasi ini) | `QuickToggleService` | Implementasi nyata (registry Personalize, Core Audio COM interop, LockWorkStation) — mengomposisi `INetworkService` untuk Wi-Fi/Bluetooth supaya satu titik akses untuk ViewModel |
| F-021 Cuaca | `IWeatherService` | `WeatherService` | Implementasi nyata (Open-Meteo, tanpa API key) |
| F-003 Auto-hide (deteksi fullscreen) | — (dipakai App/Interop) | `FullscreenDetectionService` | Implementasi nyata (GetForegroundWindow + GetMonitorInfo) |
| F-001 Geometri notch | `INotchPositionService` | `NotchInteropService` | Implementasi nyata untuk geometri; styling HWND mentah sengaja di `App/Interop/Win32Window.cs`, bukan di Services (lihat §3) |
| F-040 Dock items | `IDockService` | `RunningAppsService` | Implementasi nyata untuk MVP (Process-based); enumerasi window penuh via shell hook ditunda ke F-130 Rilis 2 |
| F-050 Settings | `ISettingsStore` | `JsonSettingsStore` | Implementasi nyata (`%LOCALAPPDATA%\NotchWindows\settings.json`) |

Tidak ada service yang di-stub murni untuk MVP — semua item P0 di `01-features.md` Rilis 1 punya implementasi
nyata terhadap Win32/WinRT API. Satu-satunya hal yang disengaja "best-effort dengan fallback diam" adalah
mic-mute (COM Core Audio bisa gagal di mesin tanpa mic default — ditangani, lihat §2.2) dan Wi-Fi/Bluetooth
radio (bisa `IsAvailable=false` bila hardware tidak ada).

## 1. IMusicService — SmtcMusicService

```csharp
public interface IMusicService : IDisposable
{
    TrackInfo Current { get; }
    event EventHandler<TrackInfo>? TrackChanged;
    Task InitializeAsync(CancellationToken ct = default);
    Task PlayPauseAsync();
    Task NextAsync();
    Task PreviousAsync();
    Task SeekAsync(TimeSpan position);
}
```

- Sumber: `GlobalSystemMediaTransportControlsSessionManager` (WinRT bawaan Windows, tidak butuh NuGet).
- Memilih session aktif via `GetCurrentSession()` (OS yang menentukan prioritas session, biasanya yang
  terakhir berinteraksi) — cukup untuk MVP; prioritas eksplisit "session Playing" dicatat sebagai
  perbaikan Rilis 2 bila `GetCurrentSession()` tidak selalu memilih yang sedang Playing.
- Error handling: bila tidak ada session (`_session is null`), `Current` di-set `TrackInfo.Empty` dan
  event tetap di-raise — ViewModel menampilkan state "Kosong" sesuai `03-design.md` §2.2.
- Album art diambil sebagai `byte[]` mentah dari `IRandomAccessStreamReference` — konversi ke
  `BitmapImage` untuk binding XAML dilakukan di View/Converter (App layer), bukan di Services.

**Contoh pemakaian ViewModel:**
```csharp
public partial class NowPlayingViewModel : ObservableObject
{
    private readonly IMusicService _music;
    public NowPlayingViewModel(IMusicService music)
    {
        _music = music;
        _music.TrackChanged += (_, track) => CurrentTrack = track;
    }

    [ObservableProperty] private TrackInfo currentTrack = TrackInfo.Empty;

    [RelayCommand] private Task PlayPause() => _music.PlayPauseAsync();
}
```

## 2. IQuickToggleService — QuickToggleService (baru)

```csharp
public interface IQuickToggleService
{
    Task<QuickToggleState> GetCurrentAsync();
    event EventHandler<QuickToggleState>? StateChanged;
    Task SetWifiEnabledAsync(bool enabled);
    Task SetBluetoothEnabledAsync(bool enabled);
    Task SetDarkModeAsync(bool enabled);
    Task SetMicMutedAsync(bool muted);
    Task LockPcAsync();
}
```

Satu service gabungan untuk `QuickToggleGrid` di `03-design.md` §2.2, supaya `DashboardViewModel`
hanya depend ke satu interface untuk kelima toggle, bukan tiga service terpisah.

### 2.1 Wi-Fi / Bluetooth
Didelegasikan ke `INetworkService` (`NetworkToggleService`, sudah ada sebelum iterasi ini) —
`Windows.Devices.Radios.Radio`. Butuh `Radio.RequestAccessAsync()` sekali (OS akan minta izin radio
capability jika app packaged/MSIX; untuk unpackaged exe biasanya granted langsung). Bila radio tidak
terdeteksi (laptop tanpa Wi-Fi/BT, atau driver tidak expose radio API), `ToggleState.IsAvailable=false`
dan `QuickToggleGrid` menonaktifkan tombol sesuai state Error di `03-design.md`.

### 2.2 Dark Mode
Registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`:
- `AppsUseLightTheme` (DWORD, 0=dark/1=light) — tema aplikasi.
- `SystemUsesLightTheme` (DWORD) — tema shell/taskbar, diset sama agar konsisten.

Tidak butuh admin (HKCU, bukan HKLM). Windows Explorer biasanya mendeteksi perubahan ini sendiri;
tidak ada broadcast event resmi yang perlu di-handle di MVP — cukup set registry lalu refresh UI lokal.

### 2.3 Mute Mic
COM interop Core Audio API (`mmdeviceapi.h`/`endpointvolume.h`, definisi publik Microsoft):
`IMMDeviceEnumerator.GetDefaultAudioEndpoint(eCapture, eCommunications)` → `IMMDevice.Activate` dengan
IID `IAudioEndpointVolume` → `GetMute`/`SetMute`. Dibungkus `try/catch (COMException)` — bila gagal
(tidak ada mic default, driver tidak expose endpoint), method mengembalikan `null`/diam-diam no-op dan
`ToggleState` terkait ditandai tidak tersedia di UI (bukan exception yang menjatuhkan app).

**Catatan evolusi (Rilis 2 candidate)**: untuk kebutuhan lebih kompleks (daftar semua audio
device/jenis endpoint lain) pertimbangkan NuGet `NAudio.CoreAudioApi` agar tidak menulis ulang
COM interop manual seperti di atas.

### 2.4 Lock PC
`user32!LockWorkStation()` langsung via P/Invoke (lebih cepat, tidak spawn proses baru), dengan
fallback ke `rundll32.exe user32.dll,LockWorkStation` bila panggilan langsung gagal (jarang, mis.
kebijakan grup tertentu).

**Contoh pemakaian ViewModel:**
```csharp
public partial class DashboardViewModel : ObservableObject
{
    private readonly IQuickToggleService _toggles;
    public DashboardViewModel(IQuickToggleService toggles)
    {
        _toggles = toggles;
        _toggles.StateChanged += (_, state) => Toggles = state;
    }

    [ObservableProperty] private QuickToggleState toggles = new();

    [RelayCommand] private Task ToggleDarkMode(bool enabled) => _toggles.SetDarkModeAsync(enabled);
    [RelayCommand] private Task Lock() => _toggles.LockPcAsync();
}
```

## 3. ISystemStatsService — SystemStatsService + BatteryService

- CPU: `PerformanceCounter("Processor", "% Processor Time", "_Total")` — panggilan pertama selalu 0
  (perilaku PerformanceCounter API), sudah di-"warm up" sekali di constructor supaya sampel pertama
  yang dikonsumsi UI valid.
- RAM: `Microsoft.VisualBasic.Devices.ComputerInfo` (tidak perlu admin, akurat untuk MVP; alternatif
  WMI `Win32_OperatingSystem` dicatat sebagai opsi bila butuh detail lebih di Rilis 2).
- Disk: `DriveInfo` untuk drive sistem (`Environment.SystemDirectory`), persen pemakaian primary disk.
- Baterai: `Windows.System.Power.PowerManager` (WinRT bawaan) — `IsPresent=false` untuk desktop tanpa
  baterai, closed-notch menyembunyikan slot baterai otomatis bila `IsPresent=false` (lihat state
  "Kosong" F-004 di `03-design.md`).
- `Samples` adalah `IObservable<SystemStatus>` interval 2 detik (dalam rentang 1-5 detik kriteria
  selesai F-004), `Publish().RefCount()` supaya satu timer dibagi semua subscriber (closed-notch +
  dashboard), bukan timer terpisah per consumer.

Error handling: tidak ada try/catch eksplisit di `GetSnapshotAsync` untuk CPU/RAM/disk karena API ini
jarang throw pada kondisi normal; bila di pengujian Windows nyata ditemukan exception (mis.
`PerformanceCounter` butuh izin performance-monitor-users di beberapa image Windows terkunci), tambahkan
try/catch dengan fallback nilai terakhir — dicatat sebagai temuan untuk `06-qa-report.md`.

## 4. IWeatherService — WeatherService

- `GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true` —
  gratis, tanpa API key, sesuai privacy note README Poni yang jadi referensi fungsional (F-021).
  `HttpClient` di-inject (registrasi `IHttpClientFactory`/singleton `HttpClient` jadi tanggung jawab
  composition root App, dicatat di `02-architecture.md` §1 App bootstrap).
- Error handling: `HttpRequestException` ditangkap → return `null` → `WeatherCard` tampil state Error
  "Cuaca tidak tersedia" + retry (`03-design.md` §2.2), bukan crash dashboard.
- Lokasi (`latitude`/`longitude`) sumbernya `AppSettings` (lokasi manual user) atau deteksi kasar —
  TODO Rilis 2: layanan "Detect my location" terpisah (`IGeoLocationService`, belum diimplementasikan
  di iterasi ini, di luar scope MVP F-021 yang P1-placeholder).

## 5. INotchPositionService + FullscreenDetectionService

- `NotchInteropService.GetGeometryForActiveMonitor()`: sengaja TIDAK menyentuh HWND (lihat komentar di
  kode) — hanya menghitung lebar/posisi X berbasis `GetSystemMetrics(SM_CXSCREEN)`. Styling HWND
  (topmost/layered/click-through) ada di `App/Interop/Win32Window.cs` sesuai pembagian tanggung jawab
  `02-architecture.md` §6 ("Semua akses Win32/WinRT langsung WAJIB lewat Services... App boleh reference
  Core+Services+Data+Assets" — HWND adalah tipe UI-specific sehingga manipulasinya tetap di App,
  Services hanya menyediakan data geometri).
- **Catatan koreksi dari hasil review kode**: `DpiScale` di `GetGeometryForActiveMonitor()` saat ini
  hardcoded `1.0` dengan komentar "dihitung App/Interop/MonitorHelper.cs" — pastikan
  `MonitorHelper.cs` benar-benar memanggil balik nilai DPI aktual ke sini (atau pindahkan perhitungan
  DPI penuh ke Services bila `MonitorHelper` butuh akses WinRT yang tidak tersedia di Core). Ditandai
  untuk ditutup sebelum F-001 dianggap "Kriteria Selesai" di multi-monitor beda DPI.
- `FullscreenDetectionService.IsForegroundAppFullscreen()`: heuristik window rect == monitor rect,
  exclude shell classname (`Progman`, `Shell_TrayWnd`, dst). Belum ada whitelist/blacklist proses
  (mis. game launcher yang borderless-windowed tapi bukan gameplay) — dicatat sebagai item tuning di
  QA (lihat kriteria selesai F-003 "tidak false-positive").

## 6. IDockService — RunningAppsService (F-040, MVP)

- `Items`: `IObservable<IReadOnlyList<DockItem>>`, gabungan `AppSettings.PinnedAppPaths` + snapshot
  `Process.GetProcesses()` yang punya `MainWindowTitle` tidak kosong, di-refresh tiap 3 detik.
- Keterbatasan MVP (disengaja, lihat `01-features.md` F-130 Rilis 2): tidak pakai `WinEventHook`
  (`EVENT_SYSTEM_FOREGROUND`) untuk update real-time — polling 3 detik cukup untuk MVP dan jauh lebih
  sederhana/aman (tidak perlu hook global). `LaunchOrActivateAsync` untuk app yang sudah running
  belum memanggil `SetForegroundWindow` nyata (comment TODO F-130) — klik app running saat ini no-op,
  dicatat sebagai gap fungsional MVP yang perlu diputuskan: tutup sebelum rilis P0 F-040 dianggap
  "Kriteria Selesai" ("klik ikon switch/launch app" di `01-features.md` mengharuskan switch berfungsi).

## 7. ISettingsStore — JsonSettingsStore (F-050)

- `%LOCALAPPDATA%\NotchWindows\settings.json`, `JsonSerializer` dengan `WriteIndented=true`.
- Tidak ada debounce write di layer Services (disengaja — debounce 300ms adalah concern UI/ViewModel
  sesuai `03-design.md` §2.5 "SettingsWindow... auto-save debounced 300ms", bukan tanggung jawab
  storage layer supaya `SettingsStore` tetap sederhana dan dapat dipanggil langsung dari mana saja
  tanpa efek samping timing).
- Korup/`JsonException` → fallback ke `new AppSettings()` diam-diam, tidak crash startup.

## 8. Temuan tambahan untuk Tech Lead / Architect (di luar scope langsung Services)

Ditemukan saat membaca skeleton sebelum menulis service baru — **bukan** perubahan yang saya lakukan,
hanya dicatat karena berpotensi bikin solusi tidak kompilasi:

1. **Dua scaffold paralel yang tumpang-tindih dan saling bentrok**, tampaknya hasil dua proses
   Architect berbeda yang tidak direkonsiliasi:
   - `NotchWindows.Services/*` (canonical, dipakai dokumen ini) vs `NotchWindows.Services.External/*`
     (berisi `SmtcService.cs`, `OpenMeteoWeatherClient.cs`, `SystemMetricsService.cs` — fungsinya
     duplikat dari `SmtcMusicService`, `WeatherService`, `SystemStatsService`).
   - `NotchWindows.Core/Abstractions/*` vs `NotchWindows.Core/Services/Abstractions/*` (mis.
     `IMusicService` vs `ISmtcService`, dua `IWeatherService` berbeda signature).
   - `NotchWindows.Core/ViewModels/*` vs `NotchWindows.ViewModels/*` (proyek terpisah duplikat).
   - `App/Interop/*` vs `NotchWindows.Interop/*` (dua `MonitorHelper.cs` berbeda lokasi).
   - `App/Services/QuickToggleServiceStub.cs` mengimplementasikan `Core.Services.Abstractions.IQuickToggleService`
     (stub, Wi-Fi/Bluetooth belum real) — **berbeda** dari `IQuickToggleService` baru yang saya tulis
     di `Core.Abstractions` (real, komposisi `INetworkService`). Rekomendasi: Tech Lead/Architect
     memilih satu set (sarankan: pertahankan `NotchWindows.Services` + `Core.Abstractions` karena
     sudah punya implementasi nyata untuk semua interface P0, hapus/gabungkan sisi
     `.External`/`Services.Abstractions`/`ViewModels` project kedua) sebelum solution bisa di-build
     tanpa duplicate-type/namespace conflict.
2. `NotchWindows.sln` perlu dicek ulang apakah mereferensikan kedua proyek duplikat sekaligus
   (`NotchWindows.Services` dan `NotchWindows.Services.External`, `NotchWindows.ViewModels` dan
   `NotchWindows.Core`'s internal ViewModels folder) — bila ya, build akan gagal karena ambiguous
   type/namespace saat `App` reference keduanya.

Saya tidak menghapus proyek/file duplikat karena itu keputusan struktural di luar scope saya (Desktop
Services Engineer) — perlu keputusan eksplisit Architect/Tech Lead, bukan dihapus sepihak oleh agent
Services.
