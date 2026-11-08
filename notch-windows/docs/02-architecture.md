# notch-windows — Arsitektur

Referensi: `01-features.md`. Target: C# + WinUI 3 (Windows App SDK 1.6+), arsitektur MVVM, app client-only untuk MVP (tanpa backend server wajib).

## 1. Struktur Solution & Folder

```
NotchWindows.sln
  src/
    NotchWindows.App/                 # entry point, App.xaml, shell host, DI composition root
      App.xaml(.cs)
      Program.cs                      # custom main (single-instance check, WinUI bootstrap)
      AppWindowFactory.cs             # buat/posisikan window notch & dock per monitor
      Assets/                         # ikon app, tray icon — ORIGINAL, tanpa aset pihak ketiga
      Resources/Styles/               # ResourceDictionary tema (colors, glass brush, pill shape)

    NotchWindows.Core/                # domain: model, interface service, tidak boleh depend ke WinUI/Win32
      Models/                         # NowPlayingInfo, SystemMetrics, DockItem, NotchSettings, dll
      Abstractions/                   # INowPlayingService, ISystemMetricsService, ISettingsStore, IDockService, dst
      Messaging/                      # pesan WeakReferenceMessenger (NotchExpandRequested, SettingsChanged, dll)
      Enums/                          # NotchPosition, ThemeMode, ClosedNotchSlot

    NotchWindows.Services/            # implementasi konkret Abstractions, boleh depend ke Core saja (bukan UI)
      Media/SmtcNowPlayingService.cs       # wraps GlobalSystemMediaTransportControlsSessionManager
      System/SystemMetricsService.cs       # CPU/RAM/disk via System.Diagnostics + LibreHardwareMonitorLib untuk GPU/temp
      Network/WifiBluetoothService.cs      # Windows.Devices.WiFi / Bluetooth Runtime APIs
      Storage/JsonSettingsStore.cs         # persist Settings ke %AppData%\NotchWindows\settings.json
      Storage/LocalDatabase.cs             # LiteDB untuk data terstruktur rilis 2+ (todo, notes, dll)
      Weather/OpenMeteoClient.cs           # HTTP client Open-Meteo (rilis 1 opsional P1)
      Dock/RunningAppsService.cs           # enumerasi window & taskbar via Win32 (EnumWindows, Shell_NotifyIcon hook)

    NotchWindows.Infrastructure/      # Win32 interop & platform plumbing, tidak boleh depend ke ViewModel
      Interop/WindowStylesInterop.cs       # WS_EX_TRANSPARENT, WS_EX_TOOLWINDOW, SetWindowLong, DwmExtendFrame
      Interop/HitTestRegionManager.cs      # region klik-tembus vs area notch aktif
      Interop/FullscreenDetector.cs        # deteksi app lain fullscreen (GetForegroundWindow + monitor bounds)
      Interop/GlobalHotkeyManager.cs       # RegisterHotKey/UnregisterHotKey via message-only window
      Interop/MonitorEnumerator.cs         # multi-monitor bounds & DPI

    NotchWindows.UI/                  # Views (XAML) + ViewModels, depend ke Core + Services interfaces (via DI) saja
      Views/Notch/NotchShellView.xaml
      Views/Notch/ClosedNotchView.xaml
      Views/Notch/ExpandedPanelView.xaml  # host tab: Dashboard, Music, ControlCenter (rilis 2), dst
      Views/Dock/DockBarView.xaml
      Views/Settings/SettingsView.xaml
      ViewModels/NotchShellViewModel.cs
      ViewModels/NowPlayingViewModel.cs
      ViewModels/DashboardViewModel.cs
      ViewModels/DockViewModel.cs
      ViewModels/SettingsViewModel.cs
      Converters/, Behaviors/

  tests/
    NotchWindows.Core.Tests/
    NotchWindows.Services.Tests/
    NotchWindows.UI.Tests/            # ViewModel tests (tanpa UI otomatis dulu; UI automation test masuk rilis 2)
```

Batas antar modul (dependency rule, searah, tidak boleh siklik):

```
App  ─▶ UI ─▶ Services ─▶ Core
 │           │
 │           ▼
 └────────▶ Infrastructure ─▶ Core
```

- `Core` tidak boleh reference project lain (pure C#, testable tanpa Windows runtime kecuali tipe dasar).
- `Infrastructure` hanya boleh reference `Core` (untuk tipe model), tidak boleh tahu soal ViewModel/View.
- `Services` boleh reference `Core` dan `Infrastructure` (butuh interop untuk beberapa service seperti RunningAppsService).
- `UI` boleh reference `Core` (model/abstractions) dan dapat instance `Services` lewat DI interface — **tidak boleh** `new SmtcNowPlayingService()` langsung di ViewModel.
- `App` adalah composition root: satu-satunya tempat `IServiceCollection.AddSingleton<IX, Impl>()` didaftarkan.

## 2. Pola Arsitektur

- **MVVM** dengan `CommunityToolkit.Mvvm` (`ObservableObject`, `[ObservableProperty]`, `[RelayCommand]`).
- **Dependency Injection**: `Microsoft.Extensions.DependencyInjection`, `Microsoft.Extensions.Hosting` generic host (`IHost`) dibangun di `Program.cs` sebelum `Application.Start`. Semua service terdaftar sebagai singleton (state notch harus hidup selama proses app, bukan per-window).
- **Messaging/event aggregator**: `CommunityToolkit.Mvvm.Messaging.WeakReferenceMessenger` untuk komunikasi lintas window (Notch window, Dock window, Settings window adalah window WinUI terpisah — tidak share visual tree). Contoh pesan: `NotchExpandRequestedMessage`, `ThemeChangedMessage`, `NowPlayingChangedMessage`, `DockItemActivatedMessage`.
- **Polling vs event-driven**: SMTC pakai event (`MediaPropertiesChanged`, `PlaybackInfoChanged`) — bukan polling. Sensor CPU/RAM/disk pakai timer polling 1–2 detik (`DispatcherQueueTimer`) dengan throttle saat notch collapsed (turunkan ke 5 detik untuk hemat CPU idle).
- **Settings reaktif**: `ISettingsStore` expose `IObservable`-style event `SettingsChanged`; semua ViewModel subscribe, tidak perlu restart app (sesuai kriteria selesai F-050).

## 3. Diagram Alur Data (teks)

### 3.1 Notch shell lifecycle
```
App start
  └─ Program.cs: build Host+DI, single-instance mutex check
       └─ AppWindowFactory: hitung monitor utama (atau semua monitor bila multi-notch di Settings)
            └─ buat NotchShellView window per monitor target
                 ├─ Infrastructure.WindowStylesInterop: set WS_EX_TRANSPARENT + TOOLWINDOW + topmost
                 ├─ Infrastructure.HitTestRegionManager: set region klik-tembus = full - area pill
                 └─ NotchShellViewModel.Initialize()
                      ├─ subscribe NowPlayingViewModel, DashboardViewModel via DI
                      └─ state = Collapsed

Event: mouse enter top-edge region / hover pill
  └─ HitTestRegionManager deteksi pointer masuk area aktif
       └─ Messenger publish NotchExpandRequestedMessage
            └─ NotchShellViewModel.State = Expanding → animasi (Storyboard) → Expanded
                 └─ HitTestRegionManager perbesar region klik-tembus ke panel penuh

Event: FullscreenDetector.ForegroundAppChanged (app lain fullscreen terdeteksi)
  └─ Messenger publish AutoHideRequestedMessage
       └─ NotchShellViewModel.State = Hidden (slide-up) kecuali pointer dekat edge atas
```

### 3.2 SMTC now-playing pipeline
```
GlobalSystemMediaTransportControlsSessionManager.RequestAsync()
  └─ SmtcNowPlayingService subscribe:
       - CurrentSessionChanged
       - MediaPropertiesChanged  → map ke NowPlayingInfo (title, artist, albumArtStream)
       - PlaybackInfoChanged     → map ke PlaybackState (playing/paused), kontrol enable/disable
       - TimelinePropertiesChanged → posisi/duration untuk progress bar
  └─ service expose event INowPlayingService.NowPlayingChanged
       └─ NowPlayingViewModel (UI thread via DispatcherQueue.TryEnqueue) update binding
  └─ UI command Play/Pause/Next/Prev
       └─ ViewModel.RelayCommand → INowPlayingService.TrySendCommandAsync(cmd)
            └─ session.TryPlayAsync() / TryPauseAsync() / TrySkipNextAsync() / TrySkipPreviousAsync()
```

### 3.3 Sensor polling (CPU/GPU/RAM/baterai)
```
DispatcherQueueTimer (interval dinamis: 1-2s expanded, 5s collapsed)
  └─ SystemMetricsService.PollAsync()
       ├─ CPU: PerformanceCounter("Processor", "% Processor Time", "_Total") atau WMI Win32_PerfFormattedData
       ├─ RAM: GlobalMemoryStatusEx (P/Invoke) — lebih ringan dari WMI
       ├─ Disk: WMI Win32_LogicalDisk (FreeSpace/Size), di-cache 30s (jarang berubah signifikan)
       ├─ Baterai: System.Devices.Power atau WMI Win32_Battery
       └─ GPU/Temp (rilis lanjutan jika aktif): LibreHardwareMonitorLib.Computer (butuh admin untuk sebagian sensor — fallback graceful bila gagal)
  └─ event SystemMetricsUpdated → DashboardViewModel + ClosedNotch binding (sesuai slot kiri/kanan user)
```

### 3.4 Dock bar window management
```
DockBarView = window WinUI terpisah, posisi bottom-center, sama prinsip hit-test seperti notch
RunningAppsService:
  └─ EnumWindows (Win32) + filter (visible, non-tool window, punya taskbar button)
       └─ map ke DockItem (hwnd, icon via ExtractIconEx, title)
  └─ Shell hook (opsional rilis lanjutan) untuk event real-time app buka/tutup; MVP boleh polling 1s
DockViewModel:
  └─ merge RunningApps + PinnedApps (dari ISettingsStore) → ObservableCollection<DockItem>
  └─ command Activate(item) → SetForegroundWindow / ShowWindow via Win32
  └─ hover → magnify visual (scale transform di XAML, tanpa perlu round-trip service)
```

## 4. Daftar Library & Versi (indikatif, pin ke versi stabil terbaru saat implementasi)

| Library | Versi (minimum) | Kegunaan |
|---|---|---|
| Microsoft.WindowsAppSDK | 1.6.x | Runtime WinUI 3 |
| Microsoft.Windows.SDK.BuildTools | 10.0.22621.x | Build/packaging |
| CommunityToolkit.Mvvm | 8.3.x | MVVM (ObservableObject, RelayCommand, Messenger) |
| CommunityToolkit.WinUI.Controls | 8.x (CommunityToolkit.WinUI.* split packages) | Controls tambahan (Expander, Shadow, Segmented) |
| CommunityToolkit.WinUI.Animations | 8.x | Easing/Composition animation untuk expand/collapse |
| Microsoft.Extensions.Hosting | 9.x (atau 8.x LTS) | Generic host + DI |
| Microsoft.Extensions.DependencyInjection | 9.x | DI container |
| H.NotifyIcon.WinUI | 2.x | Tray icon host |
| LiteDB | 5.x | Local DB rilis 2+ (todo/notes/catatan) |
| System.Text.Json | bundled .NET | Serialize settings.json |
| LibreHardwareMonitorLib | 0.9.x | Sensor GPU/temperature (opsional, graceful fallback) |
| Vanara.PInvoke.User32 / Vanara.PInvoke.Shell32 | latest | P/Invoke wrapper rapi untuk Win32 interop (alternatif hand-rolled DllImport) |
| xunit + Moq | latest | Unit test Core/Services |

.NET target: **.NET 8 (LTS)**, `net8.0-windows10.0.19041.0` (minimum Windows 10 2004) sebagai `TargetFramework`, `TargetPlatformMinVersion`.

## 5. Konvensi Penamaan & Local Storage

- Namespace mengikuti nama folder project: `NotchWindows.Core.Models`, `NotchWindows.Services.Media`, dst.
- Interface diawali `I` di `Core.Abstractions`; implementasi di `Services` dengan suffix `Service` (`SmtcNowPlayingService : INowPlayingService`).
- ViewModel suffix `ViewModel`, View suffix `View`, file XAML dan code-behind satu nama.
- Pesan Messenger suffix `Message` (`NotchExpandRequestedMessage`).
- Local storage root: `%AppData%\NotchWindows\`
  - `settings.json` — semua pengaturan user (posisi notch, closed-notch slots, shortcut, tema) — F-050
  - `data.db` — LiteDB untuk todo/notes/flashcard (rilis 2+)
  - `notifications.enc` — riwayat notifikasi (rilis 2, F-100), **wajib dienkripsi** (DPAPI `ProtectedData` per-user, bukan custom crypto)
  - `logs\` — rolling log (opsional, untuk debug crash)
- Tidak ada secret/API key hardcode di source; API key BYO (AI chat, dll — backlog F-200) disimpan via Windows Credential Manager (`Windows.Security.Credentials.PasswordVault`), bukan file plaintext.

## 6. Strategi Multi-Monitor & Background/Tray

- **Multi-notch**: `AppWindowFactory` baca setting `NotchDisplayMode` (`PrimaryOnly` default MVP | `AllMonitors` opsional). Satu `NotchShellView` window + satu `NotchShellViewModel` instance per monitor; service singleton (SMTC, sensor) tetap satu instance global, di-share lewat DI — hanya window/ViewModel yang per-monitor.
- Posisi dihitung ulang saat `DisplaySettingsChanged` (event sistem) — re-run `MonitorEnumerator` dan reposisi semua window notch/dock agar tetap top-center/bottom-center sesuai bounds baru.
- DPI-awareness: project manifest `dpiAware=PerMonitorV2`; semua perhitungan posisi pakai `GetDpiForMonitor`, hindari hardcode pixel.
- **Background/tray**: app berjalan sebagai proses tunggal tanpa taskbar entry utama (notch window `ShowInTaskbar=false`); `H.NotifyIcon` menghost tray icon dengan menu konteks (Show/Hide Notch, Settings, Quit). Single-instance dijamin via Named Mutex di `Program.cs`; instance kedua yang dijalankan cukup kirim signal (named pipe/event) ke instance pertama untuk fokus/expand, lalu exit.
- Startup opsional "Run at Windows startup" via Task Scheduler registration (bukan Registry Run key langsung, agar bisa run elevated jika diperlukan sensor tertentu) — dicatat sebagai item Settings F-050 lanjutan, bukan blocker MVP murni.

## 7. Catatan untuk Agent Berikutnya (Designer, Services dev, QA, Security, DevOps)

- Semua skenario UI (Designer) harus mengikuti batas window: Notch window, Dock window, Settings window adalah 3 window terpisah — jangan desain navigasi seolah satu window dengan banyak halaman penuh.
- Service dev yang mengimplementasikan `NotchWindows.Services` **tidak boleh** menyalin aset ikon/logo dari aplikasi pihak ketiga manapun (Poni/Gili) — semua ikon dibuat baru (vector shape sendiri) sesuai catatan di `01-features.md`.
- QA harus mencakup kasus: multi-monitor hot-plug saat app jalan, SMTC session berganti app sumber musik, sensor gagal baca (LibreHardwareMonitor butuh admin) harus fallback graceful tanpa crash.
- DevOps: target packaging MSIX (bukan portable exe dulu) agar auto-update (F-270, rilis lanjutan) lebih mudah lewat App Installer/Sparkle-equivalent; dicatat sebagai keputusan arsitektur, detail CI ada di `08-devops.md`.
