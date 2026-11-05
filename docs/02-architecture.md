# Arsitektur Windows Dynamic Notch

## Keputusan dasar

Aplikasi adalah **satu proses desktop** dengan dua jendela WinUI 3: `MainWindow` untuk pengaturan dan `OverlayWindow` untuk notch. Proyek menyediakan jalur MSIX dan publish unpackaged untuk installer Inno Setup. Tidak ada server, WebView, akun, sinkronisasi cloud, atau proses pendamping. `AppInstance.FindOrRegisterForKey` mengarahkan peluncuran kedua ke proses utama dan membuka dashboard; satu instance memiliki satu overlay pada **layar utama**. Dashboard boleh ditutup tanpa mengakhiri proses; menu tray `Exit` adalah jalur keluar yang disengaja.

Konfigurasi source: C# 12, .NET 8 (`net8.0-windows10.0.19041.0`), WinUI 3 melalui Windows App SDK `1.6.250205002`, serta interop Win32 untuk jendela, tray, dan status daya. Paket MSIX memakai `ApplicationData.LocalSettings`; build unpackaged memakai `%LOCALAPPDATA%/NotchUI/settings.json`. Manifest meminta `runFullTrust`. Autorun dan perilaku setelah sign-out/restart Windows tidak termasuk MVP.

Pengguna melaporkan aplikasi berhasil dijalankan pada Windows. Source dan laporan itu belum merupakan acceptance lengkap: hasil build/install kedua jalur, transparansi dan hit test lintas proses, performa, keadaan media/baterai, serta pemulihan settings belum terdokumentasi sebagai matriks uji Windows.

## Susunan proyek

Satu proyek aplikasi dan satu proyek self-check tersedia. Struktur aktual yang relevan:

```text
src/NotchUI/
  App.xaml / App.xaml.cs       # resource dan bootstrap aplikasi
  MainWindow.xaml / MainWindow.xaml.cs # tampilan dan interaksi dashboard
  OverlayWindow.xaml / OverlayWindow.xaml.cs # tampilan dan interaksi notch
  NotchUI.csproj                 # target .NET 8 dan Windows App SDK
  Package.appxmanifest          # identitas aplikasi packaged
  ViewModels/
    SettingsViewModel.cs        # input pengaturan
  Models/
    NotchSettings.cs            # preferensi tervalidasi
    SystemStates.cs            # ClockState, BatteryState, MediaState
  Services/
    SettingsService.cs / SettingsCodec.cs # codec serta storage MSIX/unpackaged
    ClockService.cs             # waktu lokal
    BatteryService.cs           # status daya
    MediaService.cs             # GSMTC
    NotchCoordinator.cs         # state ringkas/terbuka, modul aktif
  Interop/
    OverlayWindowHost.cs        # HWND, style, posisi, WndProc, hit test
    TrayIconHost.cs             # Shell_NotifyIcon, menu, callback
    NativeMethods.cs            # deklarasi P/Invoke
  Assets/                       # logo paket dan branding
installer/NocUIExperience.iss  # installer dari publish unpackaged
tests/NotchUI.Settings.SelfCheck/ # pemeriksaan codec
```

`App` membuat coordinator bersama satu kali, mengelola dua jendela dan tray. View model meneruskan perubahan pengaturan ke coordinator; P/Invoke terkumpul di `Interop` serta bootstrap pesan gagal startup. Model menyimpan preferensi dan snapshot state tanpa `Window`/`HWND`. Tidak ada container DI terpisah atau dependensi CommunityToolkit.Mvvm pada proyek saat ini.

## Alur data dan kepemilikan state

```text
LocalSettings (MSIX) / settings.json (unpackaged) → SettingsService → NotchSettings → NotchCoordinator
                                            ↘ SettingsViewModel → dashboard
Clock/Battery/MediaService → snapshot → NotchCoordinator → overlay
dashboard → SettingsViewModel → SettingsService + NotchCoordinator → overlay
pointer/click → OverlayWindow → NotchCoordinator → state visual + geometri hit test
tray → App → tampilkan dashboard / Exit
```

`NotchCoordinator` memegang snapshot pengaturan yang dinormalisasi, state modul, dan target ringkas/terbuka. `OverlayWindow` mengatur hover tertunda 350 ms, keluar tertunda 320 ms, klik header, fokus keyboard, dan Storyboard. Saat arah berubah, overlay memakai `ActualWidth`/`ActualHeight`, menghentikan Storyboard lama, lalu memulai dari ukuran visual tersebut. Timer geometri 16 ms memanggil `OverlayWindowHost.SetGeometry` selama transisi; host menempatkan HWND di tengah tepi atas monitor utama dan membentuk region rounded rectangle. Durasi 0 langsung memindahkan state tanpa Storyboard. Kesesuaian visual, region, dan input setiap frame masih perlu diuji di Windows.

Slider, ColorPicker, dan toggle mengubah snapshot di memori segera; `NotchCoordinator` melakukan debounce penyimpanan 400 ms dan flush saat `Dispose`. `NotchSettings.Normalize` membatasi ukuran/radius, opasitas 0,2–1, dan durasi 0–600 ms. Preferensi yang disimpan meliputi ukuran, radius, warna, opasitas, tiga toggle modul, pilihan hover, dan durasi animasi. State hover saat ini, media, baterai, dan jam tidak disimpan. Codec memakai payload berversi; jalur MSIX menyimpan nilai utama dan cadangan `LastGood`, sedangkan unpackaged menulis file sementara lalu mengganti `settings.json`. Kegagalan atau versi masa depan menampilkan default sesi tanpa menimpa data yang belum dapat dibaca.

Semua pemberitahuan dari WinRT/Win32 dan hasil operasi async dipindahkan ke `DispatcherQueue` milik jendela sebelum mengubah properti terikat XAML. Service yang berjalan saat aplikasi aktif memiliki `Start`/`Stop` atau `Dispose`; unsubscribe event dan batalkan pekerjaan ketika Exit. Dashboard hanya menjadi konsumen state; menutupnya tidak menghentikan service overlay.

## Integrasi Windows

| Batas | Implementasi dan perilaku gagal |
| --- | --- |
| Overlay | `OverlayWindowHost` melepas chrome, menetapkan extended style layered/topmost, memanggil `SetLayeredWindowAttributes`, dan memosisikan HWND lewat `SetWindowPos`. Root XAML transparan; brush pill memakai warna dan opasitas pengaturan. Perilaku komposisi dan fokus aktual belum mendapat hasil acceptance Windows. |
| Hit test | Subclass WndProc menangani `WM_NCHITTEST` terhadap rounded rectangle (termasuk radius nol), mengembalikan `HTCLIENT` di dalam dan `HTTRANSPARENT` di luar. `SetWindowRgn` membatasi HWND ke bentuk pill dan diperbarui bersama geometri. Click-through ke aplikasi proses lain masih harus diuji pada Windows target. |
| Monitor dan DPI | `OverlayWindowHost` membaca bounds monitor utama dan `GetDpiForWindow`; Win32 memakai piksel fisik dan XAML memakai DIP. Handler `WM_DISPLAYCHANGE`/`WM_DPICHANGED` memicu pembaruan geometri. F17 tetap P1 dan belum terverifikasi untuk pergantian monitor utama serta konfigurasi DPI nyata. |
| Tray | `TrayIconHost` memiliki satu ikon `Shell_NotifyIcon`, callback message, menu konteks Win32 (`Settings`, `Exit`), dan pembersihan ikon saat Exit. Klik kanan membuka menu; `Settings` memanggil `App.ShowSettings`, yang mengaktifkan dashboard yang sudah ada atau membuatnya sekali. Penutupan dashboard menutup jendela itu saja. |
| Jam | `ClockService` membaca waktu lokal dan memperbarui state melalui timer yang disejajarkan ke menit; host meneruskan perubahan state sistem untuk refresh. |
| Baterai | `BatteryService` membaca `GetSystemPowerStatus` pada timer berkala dan saat perubahan daya/resume. Status tanpa baterai atau nilai tidak diketahui menghasilkan state `Unavailable`, bukan angka palsu. Toggle off menghentikan polling bila tidak ada konsumen lain. |
| Media | `MediaService` memakai `Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager`, mengikuti sesi aktif dan event perubahan sesi, metadata, playback, serta kemampuan kontrol. Tiga perintah memanggil API `Try*Async` hanya saat sesi/kemampuan tersedia. Busy perintah dijaga terpisah dari snapshot metadata sehingga refresh gagal tidak membuka perintah kedua; busy dilepas di `finally` atau saat service dihentikan. Sesi hilang mengosongkan judul/artis dan menonaktifkan tombol; hasil async sesi lama diabaikan setelah sesi berganti. |

Transparansi berlapis pada top-level WinUI 3 tetap risiko integrasi besar. Source sudah memakai layered window dan region, tetapi F01–F04 memerlukan bukti Windows: area di luar pill transparan dan dapat diklik lintas proses, XAML tetap terlihat, topmost stabil, dan fokus tidak direbut. Mockup HTML tidak membuktikan perilaku HWND.

## UI, animasi, dan dependensi

Dashboard memakai `NavigationView` WinUI dengan halaman Appearance, Widgets, Behavior, Animations, dan About, backdrop Mica, kartu pengaturan, serta preview pill. Appearance memuat ukuran, radius, warna, dan opasitas; Widgets memuat toggle jam/baterai/media; Behavior memuat toggle hover; Animations memuat durasi 0–600 ms. Ini susunan source yang lebih luas dari rancangan satu halaman awal, tanpa menambah widget cuaca/fokus, preset fisika, diagnostik, atau fitur mockup lain ke scope.

`Storyboard` yang dibuat di code-behind menggerakkan lebar dan tinggi pill dengan `EnableDependentAnimation=true`; durasi 0 melewati animasi. Lebar terbuka minimal 430 DIP lalu dijepit ke lebar monitor; lebar ringkas mengikuti pengaturan 200–520 DIP. Foreground teks dipilih hitam/putih dari luminansi warna latar. F18 memiliki kontrol durasi awal di source tetapi acceptance aksesibilitas belum selesai. Timer geometri 16 ms dan target 60 Hz bukan hasil pengukuran frame rate; ukur pada perangkat Windows.

| Dependensi | Versi/aturan |
| --- | --- |
| .NET SDK / C# | .NET 8 SDK, `LangVersion` 12; target Windows 10 2004 (build 19041) ke atas. |
| Windows App SDK | `Microsoft.WindowsAppSDK` dikunci pada `1.6.250205002` di project. Restore, support, dan advisori dependensi perlu diverifikasi pada build Windows. |
| CommunityToolkit.Mvvm | Tidak dipakai; `SettingsViewModel` adalah implementasi lokal. |
| WinRT/Win32 | GSMTC melalui Windows SDK contracts pada target framework; `GetSystemPowerStatus`, `Shell_NotifyIcon`, dan API jendela via P/Invoke sistem. Tidak perlu paket tray pihak ketiga. |

Workflow `.github/workflows/windows-build.yml` menjalankan self-check codec, menghasilkan MSIX unsigned, dan mencoba publish unpackaged x64 serta installer Inno Setup dari `installer/NocUIExperience.iss`. Installer memasang ke LocalAppData per pengguna dengan privilege terendah. Jalur artefak ini belum sama dengan bukti paket bertanda tangan atau instalasi yang lulus. Verifikasi minimal mencakup transparansi dan click-through lintas proses, state hover/klik selama animasi, media dengan dan tanpa sesi, baterai dengan dan tanpa perangkat, tray/dashboard tunggal, serta pemulihan preferensi pada kedua mode setelah restart proses.
