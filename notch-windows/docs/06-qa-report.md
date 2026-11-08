# notch-windows — QA Report (Rilis 1 / MVP)

Status ringkas: **build/test otomatis tidak bisa dijalankan sampai selesai di lingkungan sandbox ini**
(lihat §0). Tinjauan dilakukan secara statis (baca kode penuh) menggantikan compile+run. Ditemukan
**13 bug baru** (4 diperbaiki langsung, 9 dicatat open) di atas **9 bug yang sudah diperbaiki agent QA
sebelumnya** (terlihat dari komentar `QA fix (bug QA-00X...)` yang sudah ada di kode, divalidasi ulang
di sini). **Ada 2 bug P0 baru yang memblokir build/run sepenuhnya** (QA-014, QA-015) — solution TIDAK
bisa dianggap "Kriteria Selesai" untuk fitur P0 manapun sampai keduanya ditutup.

## 0. Keterbatasan lingkungan

- **NuGet tidak bisa diakses dari sandbox ini**: `dotnet build` gagal di tahap restore dengan
  `NU1301: Unable to load the service index for source https://api.nuget.org/v3/index.json` →
  `proxy tunnel ... failed with status code 403`. Dikonfirmasi lewat
  `curl $HTTPS_PROXY/__agentproxy/status`: `api.nuget.org` tidak ada di `noProxy` allowlist proxy agent,
  gateway menolak CONNECT (`policy denial`). Ini keterbatasan jaringan sandbox, bukan bug kode — build
  nyata WAJIB dilakukan di mesin/CI dengan akses NuGet (lihat rencana `08-devops.md`, GitHub Actions
  runner Windows biasanya punya akses NuGet normal).
- **WinUI 3 / Windows App SDK tidak bisa benar-benar di-build atau dijalankan di Linux** terlepas dari
  NuGet — perlu Windows SDK + runtime WinAppSDK. `Directory.Build.props` sudah mengaktifkan
  `EnableWindowsTargeting=true` supaya restore/compile type-check *seharusnya* bisa jalan di Linux CI
  untuk feedback cepat, tapi tetap butuh NuGet untuk itu.
- **Konsekuensi**: `dotnet test` tidak dijalankan sama sekali (restore gagal lebih dulu untuk semua
  project, termasuk yang net8.0 murni seperti `NotchWindows.Core.Tests`, `NotchWindows.Data.Tests`,
  `NotchWindows.ViewModels.Tests`). Seluruh temuan di bawah berasal dari pembacaan kode baris-per-baris,
  bukan hasil compiler/test runner. **Build/test nyata di mesin Windows atau CI dengan akses NuGet wajib
  dilakukan sebelum rilis** — laporan ini bukan pengganti itu.

## 1. Bug yang SUDAH diperbaiki agent QA sebelumnya (divalidasi ulang di sini)

Ditemukan dari komentar `// QA fix (bug QA-00X, Pn): ...` yang sudah ada di kode saat laporan ini mulai
ditulis (siklus QA sebelumnya tampaknya tidak sempat menulis `06-qa-report.md`-nya). Dibaca ulang dan
dikonfirmasi masuk akal secara teknis:

| ID | Severity | File | Deskripsi | Status |
|---|---|---|---|---|
| QA-001 | P1 | `Services/Music/SmtcMusicService.cs` | Event handler `CurrentSessionChanged` disimpan di field agar bisa di-unsubscribe di `Dispose()` (sebelumnya lambda anonim tak pernah lepas → leak). | Fixed (divalidasi) |
| QA-002 | P1 | `Services/Music/SmtcMusicService.cs` | `AttachToCurrentSessionAsync()` dibungkus `SemaphoreSlim` agar ganti-app-pemutar cepat tidak menyebabkan subscribe/unsubscribe ganda yang saling interleave. | Fixed (divalidasi) |
| QA-003 | P1 | `Services/Music/SmtcMusicService.cs` | Race/TOCTOU: `_session` disalin ke variabel lokal sebelum dipakai di `RefreshAsync()` supaya tidak NRE saat `_session` diganti di tengah `await`. | Fixed (divalidasi) |
| QA-005 | P1 | `Core/ViewModels/NotchShellViewModel.cs` | ViewModel kini `IDisposable`, melepas subscription `_statsSubscription` (sebelumnya tidak pernah dipanggil). | Fixed (divalidasi) |
| QA-006 | P1 | `Services/Dock/RunningAppsService.cs` | `Process.GetProcesses()` / `GetProcessesByName()` sekarang di-`Dispose()` tiap instance (sebelumnya handle leak tiap 3 detik selama app hidup). | Fixed (divalidasi) |
| QA-007 | P2 | `Services/Network/WeatherService.cs` | Tambah tangkapan `TaskCanceledException` (timeout) dan `JsonException` (API berubah format), tidak hanya `HttpRequestException`. | Fixed (divalidasi) |
| QA-009 | P2 | `tests/*.Tests.csproj` (Core/ViewModels) | `TargetFramework` diturunkan ke `net8.0` murni untuk test yang tidak butuh WinUI, supaya bisa dibangun di CI non-Windows. | Fixed (divalidasi) |

QA-004 dan QA-008 disebut di komentar tapi nomornya tidak ditemukan terpasang di file manapun saat
ditinjau (kemungkinan nomor dicadangkan/di-skip oleh siklus sebelumnya, atau fix-nya ada di file yang
belum sempat saya baca). Tidak dianggap bug terbuka karena tidak ada jejak masalah yang cocok.

## 2. Bug BARU ditemukan di siklus ini

### 2.1 Diperbaiki langsung (P0/P1, perbaikan mekanis, tidak perlu keputusan desain)

**QA-010 (P0, Fixed)** — `App/Views/NotchShellWindow.xaml.cs`
View notch (fitur inti F-001/F-002) mengacu ke `ViewModel.IsOpen` dan `ViewModel.ToggleCommand`, padahal
`NotchShellViewModel` (Core) tidak pernah mendefinisikan anggota itu — nama sebenarnya `IsExpanded` dan
`ToggleExpandCommand` (dari `[RelayCommand] private void ToggleExpand()`). Ini `CS1061`, file utama
window notch gagal kompilasi sama sekali. **Diperbaiki**: referensi disamakan ke `IsExpanded` /
`ToggleExpandCommand`.

**QA-011 (P0, Fixed)** — hampir seluruh `.csproj` di solution
`Directory.Packages.props` mengaktifkan `ManagePackageVersionsCentrally=true`, tapi 6 dari 10 project
(`App`, `Assets`, `Data`, `Interop`, `Services`, `Core.Tests`) tetap menetapkan atribut `Version="..."`
langsung di `PackageReference` — ini `NU1008`, restore gagal total untuk hampir semua project di
solution, terlepas dari masalah akses NuGet di §0. Beberapa versi juga berbeda dari yang tercatat di
`Directory.Packages.props` (mis. `Microsoft.WindowsAppSDK` 1.6.241114003 dipakai 3 project tapi file
pusat mencatat 1.5.240627000) dan beberapa paket (Dapper, Microsoft.Data.Sqlite, Microsoft.Windows.CsWinRT,
Microsoft.Windows.CsWin32, CommunityToolkit.WinUI.Controls.Segmented, System.Reactive) tidak terdaftar
di file pusat sama sekali. **Diperbaiki**: `Version=` dihapus dari semua `PackageReference`,
`Directory.Packages.props` diperbarui ke versi yang sudah konsisten dipakai + entri yang hilang
ditambahkan.

**QA-012 (P0, Fixed)** — `src/NotchWindows.App/NotchWindows.App.csproj`
`NotchShellWindow.xaml.cs` memakai `WindowStyler` dan `MonitorHelper` dari namespace
`NotchWindows.Interop`, tapi `NotchWindows.App.csproj` tidak pernah mereferensikan project
`NotchWindows.Interop` — `CS0246` (tipe tidak ditemukan), build `App` gagal total. **Diperbaiki**:
`ProjectReference` ke `NotchWindows.Interop` ditambahkan. Lihat juga QA-017 (duplikasi arsitektur yang
jadi akar masalah ini) — ini perbaikan minimal supaya bisa kompilasi, BUKAN keputusan konsolidasi final.

**QA-013 (P1, Fixed)** — `src/NotchWindows.App/Interop/Win32Window.cs`
`GetWindowLong`/`SetWindowLong` di-P/Invoke dengan `EntryPoint = "GetWindowLongPtr"/"SetWindowLongPtr"`
(variant pointer-sized resmi untuk proses x64) tapi tanda tangan memakai `int` (32-bit) untuk nilai
kembalian/parameter. Di build x64 nyata ini salah tipe untuk fungsi yang sesungguhnya mengembalikan
`LONG_PTR` 64-bit. **Diperbaiki**: diganti ke `nint` (pointer-sized benar di x86 maupun x64), sesuai pola
yang sudah benar di `NotchWindows.Interop.NativeMethods.GetWindowLongPtrSafe/SetWindowLongPtrSafe`.

### 2.2 Terbuka — butuh keputusan desain/arsitektur (tidak diperbaiki sepihak)

**QA-014 (P0, OPEN — BLOCKER)** — Data layer memakai DUA library SQLite yang saling tidak kompatibel
`src/NotchWindows.Data/NotchDbContext.cs` dan `Repositories/ITodoRepository.cs` (`TodoRepository`)
ditulis seluruhnya memakai API **sqlite-net-pcl** (`using SQLite;`, `SQLiteAsyncConnection`,
`connection.Table<T>()`, `InsertAsync`/`UpdateAsync`/`DeleteAsync<T>(id)`, `CreateTableAsync<T>()`).
Tapi:
- `NotchWindows.Data.csproj` **tidak mereferensikan `sqlite-net-pcl` sama sekali** (hanya
  `Microsoft.Data.Sqlite` + `Dapper`) → `using SQLite;` tidak akan resolve.
- Satu-satunya factory koneksi, `SqliteConnectionFactory`, dibangun di atas **Microsoft.Data.Sqlite**
  (ADO.NET style: `CreateOpenConnection()` → `Microsoft.Data.Sqlite.SqliteConnection`, migrasi manual
  `*.sql` idempotent lewat `MigrateAsync()`) — tidak punya method `CreateConnection()` yang dipanggil
  `NotchDbContext`, dan tipe baliknya pun bukan `SQLiteAsyncConnection`.

Akibatnya `NotchDbContext.cs` dan `TodoRepository` (dipakai `TodoRepositoryTests.cs`) **tidak akan
pernah bisa dikompilasi** terhadap `SqliteConnectionFactory` yang ada sekarang — ini pola yang sama
dengan duplikasi di layer Interop (QA-017): dua desain paralel yang tidak pernah direkonsiliasi.

Rekomendasi untuk Tech Lead/Architect: pertahankan **`Microsoft.Data.Sqlite` + migrasi manual
`*.sql`** (sudah didokumentasikan lengkap di `05-database.md` §Migrasi dengan skema
`SchemaVersion`/`Settings`/`DockPins` dan strategi idempotent yang jelas, dan sudah dipakai
`SqliteConnectionFactory` + `006-qa` migrasi test nyata) sebagai satu-satunya pendekatan; tulis ulang
`NotchDbContext`/`TodoRepository` di atas `Microsoft.Data.Sqlite` + Dapper (atau ADO.NET manual) alih-alih
sqlite-net-pcl, lalu hapus `sqlite-net-pcl`/`SQLitePCLRaw.bundle_e_sqlite3` dari
`Directory.Packages.props` bila jadi tidak terpakai sama sekali. F-080 Todo sendiri dijadwalkan Rilis 2
di `01-features.md`, jadi file ini bisa dipindah/ditandai eksperimen sampai keputusan ini diambil, supaya
tidak memblokir build MVP (F-050 Settings tidak bergantung pada `NotchDbContext`, hanya
`JsonSettingsStore`).

**QA-015 (P0, OPEN — BLOCKER)** — Composition root (`App.xaml.cs`) kosong total
Seluruh isi `OnLaunched()` adalah komentar `TODO` + satu baris `ServiceCollection` kosong tanpa satupun
`AddSingleton`/`AddTransient` untuk `IWeatherService`, `IMusicService`, `IQuickToggleService`,
`ISystemStatsService`, `IDockService`, `ISettingsStore`, `NotchShellViewModel`, dst. Pembuatan dan
`Activate()` window notch/dock juga masih dikomentari. Artinya: **bahkan jika semua bug kompilasi di
atas sudah ditutup dan solution berhasil di-build, aplikasi tidak melakukan apa-apa saat dijalankan** —
tidak ada window yang muncul, tidak ada service yang jalan. Ini bukan "mudah diperbaiki" (bukan null
check/disposal) — menyangkut keputusan composition: urutan startup, single-instance guard (disebutkan
di `02-architecture.md` §7 tapi belum ada di kode), tray icon host, kapan `NotchDbContext`/migrasi
dijalankan, dll. **Rekomendasi**: Architect/Backend menuliskan composition root lengkap sesuai
`02-architecture.md` §1–§2 (DI per `AddCoreServices()`/`AddInfrastructure()`/`AddViewModels()`) sebagai
tugas tersendiri sebelum F-001–F-050 bisa dianggap "Kriteria Selesai" — walau kode servicenya sendiri
sudah ada dan (sejauh tinjauan statis) benar secara fungsional.

**QA-016 (P1, OPEN)** — F-006 Global Shortcut (Alt+N) tidak pernah di-wire
`HotkeyManager` (di `NotchWindows.Interop`, mendaftarkan `RegisterHotKey` Win32) tidak dipanggil/dipakai
di mana pun di `src/NotchWindows.App` — tidak ada kode yang membuat instance, mendaftarkan
`HotkeyIds.ToggleNotch`, atau menangani pesan `WM_HOTKEY` di window proc manapun. F-006 (P1 di
`01-features.md`) secara fungsional belum ada sama sekali, bukan cuma belum diuji. Rekomendasi: wiring
ini perlu masuk ke pekerjaan composition root yang sama dengan QA-015 (butuh akses ke message loop
window, jadi wajar satu paket dengan `OnLaunched`/`NotchShellWindow`).

**QA-017 (P1, OPEN)** — Duplikasi implementasi Win32 interop notch-window (window styling + deteksi fullscreen)
Ditemukan TIGA implementasi tumpang-tindih untuk hal yang secara fungsional sama:
1. `NotchWindows.Interop/WindowStyler.cs` + `NativeMethods.cs` (project terpisah, type-safe `nint`,
   dipakai `NotchShellWindow.xaml.cs` — baru bisa kompilasi setelah QA-012).
2. `App/Interop/Win32Window.cs` (type-incorrect sebelum QA-013, dipakai `DockBarWindow.xaml.cs`).
3. `NotchWindows.Interop/FullscreenDetector.cs` (static, dipakai — ke mana belum jelas) vs
   `NotchWindows.Services/Window/FullscreenDetectionService.cs` (instance, dipakai di mana juga belum
   jelas dari composition root yang kosong — lihat QA-015) — dua kelas berbeda nama, interface berbeda
   (`static bool IsForegroundWindowFullscreen()` vs `bool IsForegroundAppFullscreen()` instance method),
   tapi logika hampir identik (bandingkan rect window foreground vs monitor, exclude shell classnames
   mirip). Tidak saling referensi satu sama lain.

Ini persis pola yang sudah diperingatkan agent Services sebelumnya di `04-services-api.md` §8 ("dua
proses Architect berbeda yang tidak direkonsiliasi") — contoh konkretnya di kode saat ini berbeda detail
dari yang disebutkan di situ (nama file/project tidak sama persis), tapi gejalanya identik: dua/tiga
implementasi paralel untuk tanggung jawab yang sama. **Rekomendasi**: Tech Lead memilih SATU implementasi
per tanggung jawab (window styling: sarankan `NotchWindows.Interop.WindowStyler`+`NativeMethods` karena
sudah type-safe dan dipakai di-notch-window yang lebih kompleks; fullscreen detection: sarankan
`FullscreenDetectionService` di `Services/Window` karena instance-based, lebih mudah di-mock untuk test
dan konsisten dengan pola DI service lain) lalu hapus yang satunya dan perbarui semua pemanggil
(`DockBarWindow.xaml.cs` pindah dari `Win32Window` ke `WindowStyler`).

**QA-018 (P2, OPEN, carried forward dari `04-services-api.md`)** — `DpiScale` di
`NotchInteropService.GetGeometryForActiveMonitor()` masih hardcoded `1.0`. Sudah dicatat oleh agent
Services sebagai item yang wajib ditutup sebelum F-001 "Kriteria Selesai" di multi-monitor beda DPI;
divalidasi masih ada di kode saat laporan ini ditulis.

**QA-019 (P2, OPEN, carried forward dari `04-services-api.md`)** — `RunningAppsService.LaunchOrActivateAsync`
untuk app yang sudah berjalan masih no-op (belum memanggil `SetForegroundWindow`). Kriteria selesai
F-040 "klik ikon switch/launch app" di `01-features.md` belum sepenuhnya terpenuhi untuk app yang sedang
berjalan (hanya launch app baru yang berfungsi).

**QA-020 (P2, OPEN, minor)** — Komentar di `TodoRepositoryTests.cs` menjelaskan perilaku connection-pool
`sqlite-net-pcl` sebagai alasan memakai file temp alih-alih `:memory:`. Pilihan file-temp-nya sendiri
tetap masuk akal, tapi akan butuh ditulis ulang begitu QA-014 selesai dan implementasi pindah ke library
lain (alasan teknisnya mungkin berbeda).

## 3. Kasus batas yang diperiksa (tinjauan statis)

| Kasus | Lokasi | Hasil |
|---|---|---|
| Tidak ada sesi SMTC aktif (tidak ada app pemutar musik) | `SmtcMusicService.AttachToCurrentSessionAsync` | OK — `Current` di-set `TrackInfo.Empty`, event tetap di-raise, tidak throw. |
| Ganti app pemutar musik dengan cepat (race) | `SmtcMusicService` | OK setelah QA-002/QA-003 (lock + salinan lokal `_session`). |
| Jaringan terputus / API cuaca down / timeout / format JSON berubah | `WeatherService.GetCurrentAsync` | OK setelah QA-007 — tiga jenis exception ditangkap, return `null`, tidak crash dashboard. |
| Tidak ada mic default / driver tidak expose Core Audio endpoint | `QuickToggleService.TryGetDefaultMicMuted/TrySetDefaultMicMuted` | OK — `COMException` ditangkap, fallback diam-diam, dicatat sendiri di komentar kode. |
| Tidak ada baterai (desktop) | `SystemStatsService`/`BatteryService` via `Windows.System.Power.PowerManager` | Didesain `IsPresent=false` (sesuai `04-services-api.md` §3), tidak diverifikasi langsung di kode `BatteryService.cs` (tidak dibaca penuh di siklus ini) — **tidak ditemukan masalah, tapi juga belum divalidasi 100%**; rekomendasi: verifikasi eksplisit saat build Windows nyata tersedia. |
| File `settings.json` korup / tidak valid JSON | `JsonSettingsStore.LoadAsync` | OK — `JsonException` ditangkap, fallback ke `new AppSettings()`, tidak crash startup. |
| `settings.json` tidak ada sama sekali (first run) | `JsonSettingsStore.LoadAsync` | OK — `File.Exists` dicek dulu, `Current` tetap `new AppSettings()` default dari field initializer. |
| Proses sistem yang `MainModule`/`MainWindowTitle`-nya tidak bisa diakses (izin ditolak) | `RunningAppsService.TryGetMainWindowTitle/TryGetExePath` | OK — dibungkus try/catch, proses diabaikan, tidak throw ke caller. |
| Data SQLite besar / migrasi berulang kali dijalankan | `SqliteConnectionFactory.MigrateAsync` | OK secara desain — idempotent (skip versi yang sudah di `SchemaVersion`, transaksi per file migrasi); tidak bisa diuji jalan nyata di sandbox ini (lihat §0) maupun lewat `NotchDbContext`/`TodoRepository` (lihat QA-014, jalur itu malah tidak memakai `SqliteConnectionFactory` sama sekali). |
| Input kosong pada `AppUserModelId`/`ExecutablePath` dock | `RunningAppsService.BuildItems` | OK — `exePath` fallback ke `string.Empty`, `AppId` fallback ke `p.ProcessName` bila path kosong, tidak NRE. |
| Rotasi layar / ganti monitor / multi-monitor beda DPI | `NotchInteropService` + `MonitorHelper` | **Gap** — lihat QA-018, DPI hardcoded 1.0. Pergantian monitor sendiri (`DisplayAreaWatcher` disebut di `02-architecture.md` §3.6) tidak ditemukan implementasinya di kode `src/` saat ini — dicatat sebagai gap tambahan di bawah QA-018, bukan item baru terpisah karena akar masalahnya sama (geometri multi-monitor belum solid). |

## 4. Ringkasan untuk Tech Lead

- **Rilis 1 (MVP) BELUM bisa dianggap "Kriteria Selesai" untuk fitur apa pun** sampai QA-014 dan QA-015
  ditutup — keduanya memblokir build/run, bukan cuma satu fitur spesifik.
- Setelah QA-014/QA-015 ditutup, build sungguhan (di mesin/CI dengan akses NuGet + Windows SDK) WAJIB
  dijalankan sebelum siklus QA berikutnya dianggap valid — laporan ini seluruhnya berbasis tinjauan
  statis karena keterbatasan sandbox (§0).
- Pola yang berulang di seluruh temuan P0/P1 (QA-012, QA-014, QA-017) adalah **beberapa bagian solution
  dikerjakan sebagai dua desain paralel yang tidak pernah direkonsiliasi** — ini juga sudah diperingatkan
  agent Services sebelumnya. Rekomendasi proses: sebelum iterasi berikutnya menambah fitur baru,
  Tech Lead/Architect sebaiknya melakukan satu putaran konsolidasi eksplisit (pilih satu implementasi per
  tanggung jawab, hapus sisanya) alih-alih menambal di atas duplikasi yang ada.

## 5. Addendum — siklus verifikasi lanjutan (setelah QA-014..020)

Ditinjau ulang statis setelah QA-014 (data layer), QA-015 (composition root), QA-016 (hotkey) dan
QA-017..019 (konsolidasi interop/DPI/dock activation) dikonfirmasi SUDAH tertutup di kode saat ini
(komentar `QA fix` + implementasi sesuai sudah ditemukan di `NotchDbContext`, `TodoRepository`,
`App.xaml.cs`, `DockBarWindow.xaml.cs`, `NotchShellWindow.xaml.cs`, `NotchInteropService`,
`RunningAppsService`).

**QA-021 (P0, Fixed)** — `Core/Abstractions/INetworkService.cs`
Interface mendeklarasikan `IsWifiEnabledAsync/IsBluetoothEnabledAsync` (bool) plus
`IsMicMutedAsync/SetMicMutedAsync/LockWorkstation`, sedangkan satu-satunya implementasi
(`NetworkToggleService`) dan satu-satunya pemanggil (`QuickToggleService`) memakai
`GetWiFiStateAsync/GetBluetoothStateAsync` (mengembalikan `ToggleState`) dan tidak pernah memakai
anggota mic/lock pada interface ini (keduanya ditangani langsung di `QuickToggleService` lewat Core
Audio COM interop / `LockWorkStation`) — `CS0535`, `App.xaml.cs` (`AddSingleton<INetworkService,
NetworkToggleService>()`) gagal kompilasi. **Diperbaiki**: interface disamakan ke kontrak yang sungguh
dipakai kedua sisi; anggota mic/lock dihapus dari `INetworkService` (bukan tanggung jawabnya).

**QA-022 (P0, Fixed)** — `Core/Abstractions/IWeatherService.cs`
Interface mendeklarasikan `Task<WeatherInfo> GetCurrentAsync(...)`, sedangkan satu-satunya implementasi
(`WeatherService`) mengembalikan `Task<WeatherSnapshot?>` dan satu-satunya pemanggil
(`DashboardViewModel.Weather`, bertipe `WeatherSnapshot?`) memakainya begitu — `CS0738`, registrasi DI
gagal kompilasi. **Diperbaiki**: tipe balik interface disamakan ke `WeatherSnapshot?`. Model `WeatherInfo`
yang jadi tidak terpakai dibiarkan di `Core/Models` (tidak berbahaya, bisa dibersihkan Tech Lead bila mau).

**Catatan kebersihan (bukan bug, P2)** — `Core/Abstractions/ILocalStore.cs` tidak punya implementasi
maupun registrasi DI; tidak dipakai di mana pun (Todo/Notes sudah pindah ke `NotchDbContext`+Dapper
langsung). Tidak memblokir build (tidak di-inject ke mana pun), tapi sebaiknya dihapus atau diberi
implementasi di Rilis 2 supaya tidak jadi duplikasi arsitektur baru seperti pola QA-012/014/017.

### Ringkasan status untuk Tech Lead (diperbarui)

Seluruh item **P0 blocker build/run** (QA-010, 011, 012, 014, 015, 021, 022) dan **P1/P2** yang tercatat
sebelumnya (QA-013, 016, 017, 018, 019) **sudah tertutup** berdasarkan tinjauan statis. Satu-satunya hal
yang masih menggantung dari §0 tetap berlaku: **build/test nyata belum pernah dijalankan** (sandbox ini
tidak punya akses NuGet maupun Windows SDK/WinAppSDK runtime) — wajib dijalankan di mesin Windows atau
GitHub Actions Windows runner sebelum Rilis 1 dianggap "Kriteria Selesai" secara resmi. Rekomendasi:
DevOps menyiapkan workflow build Windows sebagai gerbang verifikasi pertama yang sungguh menjalankan
`dotnet build`/`dotnet test`.

## 6. Addendum integrasi panel dan input shell

`NotchShellWindow` kini berlangganan `PanelChanged` dan memasang view Dashboard, Musik, Control Center,
atau Shelf ke `ActivePanelHost`. Toolbar shell menyediakan navigasi panel dan membuka `SettingsWindow`
secara on-demand. Klik atau hover membuka shell secara idempoten; tombol Ringkas menutupnya, jadi
pointer-enter sebelum klik tidak dapat membuka lalu langsung menutup shell. Ukuran HWND mengikuti
state pill/panel. Hotkey global sengaja tidak didaftarkan otomatis;
default `GlobalToggleShortcut` kosong sampai alur opt-in benar-benar diterapkan. Ini keputusan privasi
dan kompatibilitas preferensi pengguna, bukan hasil runtime test.

Perubahan ini hanya diperiksa secara statis. Build, hit testing transparansi sudut pill, resize/DPI, dan
alur Settings masih memerlukan validasi pada Windows dengan .NET 8 dan Windows App SDK.
