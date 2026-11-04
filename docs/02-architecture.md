# Arsitektur Windows Dynamic Notch

## Keputusan dasar

Aplikasi adalah **satu proses desktop packaged** dengan dua jendela WinUI 3: `MainWindow` untuk pengaturan dan `OverlayWindow` untuk notch. Tidak ada server, WebView, akun, sinkronisasi cloud, atau proses pendamping. `AppInstance.FindOrRegisterForKey` mengarahkan peluncuran kedua ke proses utama dan membuka dashboard; satu instance memiliki satu overlay pada **layar utama**. Dashboard boleh ditutup tanpa mengakhiri proses; menu tray `Exit` adalah jalur keluar yang disengaja.

Target implementasi: C# 12, .NET 8 (`net8.0-windows10.0.19041.0`), WinUI 3 melalui Windows App SDK, serta interop Win32 yang dibatasi pada shell jendela dan tray. Paket MSIX memberi identitas aplikasi dan `ApplicationData.LocalSettings`; manifest tidak perlu mendeklarasikan kemampuan background atau tray khusus untuk proses desktop yang sedang berjalan. Perilaku setelah sign-out/restart Windows dan autorun tidak termasuk MVP.

## Susunan proyek

Satu proyek aplikasi cukup untuk MVP. Pemisahan folder berikut adalah batas tanggung jawab, bukan alasan membuat banyak assembly.

```text
src/NotchUI/
  App.xaml(.cs)                 # bootstrap, satu instance, lifetime
  MainWindow.xaml(.cs)          # shell dashboard, event jendela saja
  OverlayWindow.xaml(.cs)       # visual notch, Storyboard, pointer event
  NotchUI.csproj                 # target .NET 8 dan Windows App SDK
  Package.appxmanifest          # identitas aplikasi packaged
  ViewModels/
    SettingsViewModel.cs        # input pengaturan
  Models/
    NotchSettings.cs            # preferensi tervalidasi
    ClockState.cs
    BatteryState.cs
    MediaState.cs
  Services/
    SettingsService.cs          # baca/tulis LocalSettings
    ClockService.cs             # waktu lokal
    BatteryService.cs           # status daya
    MediaService.cs             # GSMTC
    NotchCoordinator.cs         # state ringkas/terbuka, modul aktif
  Interop/
    OverlayWindowHost.cs        # HWND, style, posisi, WndProc, hit test
    TrayIconHost.cs             # Shell_NotifyIcon, menu, callback
    DisplayMetrics.cs           # monitor utama dan konversi DPI
  Assets/Logo.png               # logo paket PNG persegi 64×64
tests/NotchUI.Tests/             # logika geometri/preferensi bila diperlukan
```

Nama tipe menggunakan PascalCase, anggota privat `_camelCase`, async berakhiran `Async`, dan interface hanya untuk dependensi yang perlu disubstitusi (`ISettingsService`, `IMediaService`, dan sejenisnya). View model tidak memanggil P/Invoke. `Interop` tidak mengenal kontrol XAML selain adapter jendela. Model tidak menyimpan `Window`, `HWND`, atau objek WinRT hidup. `App` membuat coordinator bersama satu kali, mengelola dua jendela dan tray; container DI terpisah belum diperlukan.

## Alur data dan kepemilikan state

```text
LocalSettings → SettingsService → NotchSettings → NotchCoordinator
                                            ↘ SettingsViewModel → dashboard
Clock/Battery/MediaService → snapshot → NotchCoordinator → overlay
dashboard → SettingsViewModel → SettingsService + NotchCoordinator → overlay
pointer/click → OverlayWindow → NotchCoordinator → state visual + geometri hit test
tray → App → tampilkan dashboard / Exit
```

`NotchCoordinator` memegang satu snapshot pengaturan yang sudah divalidasi dan target interaksi ringkas/terbuka. Hover membuka; keluar menutup; klik pada pill membalik keadaan. Saat arah berubah, overlay mengambil `ActualWidth`/`ActualHeight` yang sedang tampil, menetapkannya sebagai nilai dasar, menghentikan Storyboard lama, lalu memulai Storyboard baru dari ukuran tersebut. Saat animasi selesai, nilai akhir ditetapkan sebagai nilai dasar sebelum clock animasi dihentikan agar `HoldEnd` tidak menyisakan nilai lama. Lebar, tinggi, radius, dan area hit test berasal dari **geometri yang sama**; posisi horizontal dihitung ulang dari titik tengah monitor utama. Konten modul dibatasi oleh ukuran terbuka sehingga perubahan lebar ringkas tidak menimpa kontrol media.

Slider, ColorPicker, dan toggle mengubah snapshot di memori segera, lalu `SettingsService` menyimpan preferensi ke `ApplicationData.LocalSettings` dengan penundaan singkat saat slider digeser. Saat mulai, nilai hilang/rusak dikembalikan ke default dan seluruh ukuran dijepit pada batas aman, termasuk `radius ≤ min(width, height)/2`. Hanya preferensi yang disimpan: ukuran, radius, warna, dan tiga toggle. State hover, media, baterai, dan jam tidak disimpan. Pada P1, pilihan reduced motion ditambahkan ke model dengan default yang kompatibel.

Semua pemberitahuan dari WinRT/Win32 dan hasil operasi async dipindahkan ke `DispatcherQueue` milik jendela sebelum mengubah properti terikat XAML. Service yang berjalan saat aplikasi aktif memiliki `Start`/`Stop` atau `Dispose`; unsubscribe event dan batalkan pekerjaan ketika Exit. Dashboard hanya menjadi konsumen state; menutupnya tidak menghentikan service overlay.

## Integrasi Windows

| Batas | Implementasi dan perilaku gagal |
| --- | --- |
| Overlay | Setelah `OverlayWindow` memiliki `HWND`, `OverlayWindowHost` melepas chrome, mengatur topmost dengan `SetWindowPos`, dan menyiapkan transparansi termasuk `WS_EX_LAYERED` sesuai PRD. Root XAML transparan, hanya bentuk notch yang mengisi warna. Jendela overlay tidak mengambil fokus ketika muncul; dashboard tetap jendela biasa. |
| Hit test | Subclass WndProc menangani `WM_NCHITTEST`: dalam bentuk notch mengembalikan area interaktif, di luarnya meneruskan input. Koordinat layar dikonversi ke koordinat jendela/DPI lalu diuji terhadap rounded rectangle yang sedang tampil. Jangan memakai `WS_EX_TRANSPARENT` untuk seluruh HWND karena pill harus menerima hover/klik. `HTTRANSPARENT` perlu diuji terhadap aplikasi **proses lain**; bila tidak meneruskan klik pada target Windows, batasi region HWND ke geometri notch dengan `SetWindowRgn` dan perbarui selama perubahan ukuran. |
| Monitor dan DPI | MVP membaca bounds monitor utama saat startup, memakai koordinat fisik untuk Win32 dan DIP untuk XAML. `GetDpiForWindow` menjadi sumber skala. Reposisi otomatis saat `WM_DISPLAYCHANGE`/`WM_DPICHANGED` dan perubahan layar utama adalah F17 (P1); jangan menjanjikannya dalam penerimaan MVP. |
| Tray | `TrayIconHost` memiliki satu ikon `Shell_NotifyIcon`, callback message, menu konteks Win32 (`Settings`, `Exit`), dan pembersihan ikon saat Exit. Klik kanan membuka menu; `Settings` memanggil `App.ShowSettings`, yang mengaktifkan dashboard yang sudah ada atau membuatnya sekali. Penutupan dashboard menutup jendela itu saja. |
| Jam | `ClockService` membaca waktu lokal sistem. `DispatcherTimer` satu menit (dengan penyelarasan ke pergantian menit) memperbarui tampilan; refresh juga pada resume/perubahan waktu sistem agar tidak menampilkan waktu lama. |
| Baterai | `BatteryService` membaca `GetSystemPowerStatus` pada timer berkala dan saat perubahan daya/resume. Status tanpa baterai atau nilai tidak diketahui menghasilkan state `Unavailable`, bukan angka palsu. Toggle off menghentikan polling bila tidak ada konsumen lain. |
| Media | `MediaService` memakai `Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager`, mengikuti sesi aktif dan event perubahan sesi, metadata, playback, serta kemampuan kontrol. Tiga perintah memanggil API `Try*Async` hanya saat sesi/kemampuan tersedia. Busy perintah dijaga terpisah dari snapshot metadata sehingga refresh gagal tidak membuka perintah kedua; busy dilepas di `finally` atau saat service dihentikan. Sesi hilang mengosongkan judul/artis dan menonaktifkan tombol; hasil async sesi lama diabaikan setelah sesi berganti. |

Transparansi berlapis pada top-level WinUI 3 adalah risiko integrasi terbesar. F01–F04 harus dibuktikan lebih dahulu di Windows target: jendela benar-benar transparan di luar pill, komposisi XAML tetap tampil, hit test mencapai aplikasi lain, dan topmost tidak mencuri fokus. Pilihan teknis `WS_EX_LAYERED`/alpha dan fallback region diputuskan berdasarkan hasil uji tersebut; jangan menganggap mockup HTML sebagai bukti perilaku HWND.

## UI, animasi, dan dependensi

Dashboard mengikuti hierarki Fluent dari `ui-reference`: permukaan Mica bila tersedia, kartu pengaturan, tipografi Segoe UI Variable, dan kontrol native WinUI. MVP merangkum referensi itu menjadi **satu halaman** untuk ukuran/radius, warna, status serta toggle jam/baterai/media. Overlay memakai pill gelap yang sederhana; mockup multi-display, preset fisika, widget pihak ketiga, cuaca, fokus, diagnostik, dan material overlay alternatif tidak masuk scope.

`Storyboard` XAML menggerakkan lebar dan tinggi notch dengan `EnableDependentAnimation=true` karena kedua properti memengaruhi layout. Tepi atas tetap tertambat selama ekspansi; perubahan hit test mengikuti geometri visual per frame dan jendela dibatasi ke region visual. Lebar terbuka minimal 430 DIP agar tiga tombol media muat; lebar ringkas tetap mengikuti pengaturan (200–520 DIP). Foreground teks dipilih hitam/putih dari kecerahan warna latar sehingga pilihan terang tetap terbaca. P1 reduced motion memakai transisi singkat/tanpa animasi. Target 60 Hz adalah kriteria uji pada perangkat Windows, bukan klaim dari arsitektur.

| Dependensi | Versi/aturan |
| --- | --- |
| .NET SDK / C# | .NET 8 SDK, `LangVersion` 12; target Windows 10 2004 (build 19041) ke atas. |
| Windows App SDK | Jalur stabil 1.6.x sebagai baseline WinUI 3 untuk .NET 8; pilih dan **kunci satu versi patch** yang berhasil dipulihkan pada mesin build Windows. Tidak memakai API preview. |
| CommunityToolkit.Mvvm | 8.4.x untuk observable property dan command; kunci patch yang dipakai bersama Windows App SDK. |
| WinRT/Win32 | GSMTC melalui Windows SDK contracts pada target framework; `GetSystemPowerStatus`, `Shell_NotifyIcon`, dan API jendela via P/Invoke sistem. Tidak perlu paket tray pihak ketiga. |

Satu penguncian versi paket dilakukan saat proyek dibuat dan dicatat di project/lock file. Tidak ada ketergantungan runtime jaringan. Verifikasi minimal mencakup transparansi dan click-through lintas proses, state hover/klik selama animasi, media dengan dan tanpa sesi, baterai dengan dan tanpa perangkat, tray/dashboard tunggal, serta pemulihan preferensi setelah restart proses.
