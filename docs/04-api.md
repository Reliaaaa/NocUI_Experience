# Kontrak integrasi desktop NotchUI

Implementasi berada di `src/NotchUI`. Ini API dalam satu proses C# WinUI 3, bukan HTTP API atau backend server. Tidak ada port, endpoint, autentikasi jaringan, atau penyimpanan media. Windows menyediakan data secara lokal. Target .NET 8/Windows App SDK mengikuti `02-architecture.md`.

## Kepemilikan dan thread

`App` membuat satu service per modul menggunakan `DispatcherQueue` UI, lalu menyuplai instance yang sama ke dashboard dan overlay. Panggil constructor, `Start`, `Stop`, `Refresh`, perintah media, dan `Dispose` di thread UI. `Changed` adalah `EventHandler`; konsumen membaca snapshot immutable dari properti `State`. Event WinRT dari thread lain dipindahkan melalui `DispatcherQueue.TryEnqueue` sebelum state berubah. Await yang dimulai di UI kembali melalui synchronization context WinUI. Jangan memanggil service dari `Task.Run`.

Tidak ada event yang menyimpan objek XAML dalam model. Saat toggle modul off, panggil `Stop` dan lepaskan slot UI; saat on, panggil `Start`. `Start` media idempoten. `Stop` clock/battery menghentikan polling tetapi mempertahankan snapshot terakhir; konsumen harus memakai toggle untuk visibilitas. `Stop` media menghapus metadata dan mengubah availability menjadi `Disabled`.

## Service dan snapshot

| Service / anggota publik | Kontrak |
| --- | --- |
| `ClockService(DispatcherQueue)` | `ClockState State`, `Changed`, `Start()`, `Stop()`, `Refresh()`, `Dispose()`. |
| `ClockState` | `DateTimeOffset LocalTime`; `TimeText` memakai format `t`, `DateText` memakai format `D` dari kultur proses saat ini. Tidak ada detik pada teks jam. |
| `BatteryService(DispatcherQueue)` | `BatteryState State`, `Changed`, `Start()`, `Stop()`, `Refresh()`, `Dispose()`. Membaca `GetSystemPowerStatus`. |
| `BatteryState` | `BatteryAvailability Availability` (`Available`, `Unavailable`, `Unknown`), `int? Percentage`, `bool IsCharging`. Persentase hanya tersedia ketika status diketahui; nilai 255 dari Windows tidak diubah menjadi 0%. `IsCharging` mengikuti flag charging Windows. |
| `IMediaService` / `MediaService(DispatcherQueue)` | `MediaState State`, `Changed`, `Start()`, `Stop()`, `Task<bool> TogglePlayPauseAsync()`, `PreviousAsync()`, `NextAsync()`, `Dispose()`. Implementasi juga menyediakan `Refresh()`. |
| `MediaState` | `MediaAvailability Availability` (`Loading`, `Active`, `NoSession`, `Error`, `Disabled`), string `Title`/`Artist`, bool `IsPlaying`, `CanTogglePlayPause`, `CanPrevious`, `CanNext`, `IsBusy`, dan nullable string `Error`. |

`Start()` media memulai permintaan GSMTC async dan melaporkan Loading segera. Kegagalan request/metadata memberi `Error` tanpa exception yang lolos ke event UI. Tidak ada sesi menghasilkan `NoSession` dengan metadata kosong dan seluruh kemampuan false. UI memakai judul fallback hanya ketika `Active` tetapi `Title` kosong, dan menyembunyikan baris artis kosong. Jangan memakai judul contoh sebagai metadata.

Perintah hanya dijalankan bila kemampuan sesi mengizinkan dan tidak ada perintah pending. `IsBusy` mencegah pengiriman ganda ke seluruh kelompok tombol; hasil `false` berarti tidak tersedia, ditolak Windows, gagal, atau sesi berganti. Kegagalan sesi terkini mengisi `Error` dengan pesan nonfatal. Token generasi mengabaikan metadata serta hasil perintah sesi lama; nomor refresh mencegah metadata lama menimpa refresh yang lebih baru. Perubahan sesi melepaskan semua handler sesi sebelumnya. Modul media off tidak menghentikan playback aplikasi sumber.

## Cadence dan event sistem

| Sumber | Pembaruan |
| --- | --- |
| Jam | Refresh segera saat Start, timer UI non-repeating diselaraskan ke pergantian menit berikutnya, kemudian dijadwalkan ulang dari waktu sistem terkini. |
| Baterai | Refresh segera saat Start, lalu tiap 30 detik melalui `DispatcherQueueTimer`. Stop menghentikan timer. |
| Media | Event `CurrentSessionChanged`, `MediaPropertiesChanged`, `PlaybackInfoChanged`; tanpa polling tetap. Refresh setelah perintah berhasil. |
| Resume/perubahan waktu/daya | `OverlayWindowHost.SystemStateChanged` dari `WM_TIMECHANGE`/`WM_POWERBROADCAST`; bootstrap menghubungkan ke `ClockService.Refresh` dan `BatteryService.Refresh`, dengan mempertimbangkan toggle. |

Timer menggunakan `DispatcherQueueTimer`, padanan WinUI 3 yang berada pada UI dispatcher untuk kebutuhan PRD timer UI. Tidak ada loop sibuk, thread polling permanen, ataupun proses background terpisah. Baterai tidak diketahui/gagal dibaca menghasilkan `Unknown`; tanpa baterai menghasilkan `Unavailable`. Refresh jam sesudah resume/perubahan waktu tidak perlu menunggu polling berikutnya.

## Interop jendela dan tray

`OverlayWindowHost(Window)` mengambil HWND setelah jendela dibuat. Adapter menghapus chrome, menerapkan `WS_EX_LAYERED`, `WS_EX_TOPMOST`, `WS_EX_TOOLWINDOW`, alpha 255, serta posisi topmost tanpa aktivasi. `SetGeometry(widthDip, heightDip, radiusDip)` memusatkan jendela di tepi atas monitor utama, mengonversi DIP dengan DPI HWND, menjepit ukuran dan radius, lalu memperbarui region rounded HWND. Panggil metode ini pada setiap frame ukuran visual, termasuk perubahan slider, agar region dan animasi tetap sama. Dimensi nonfinite ditolak dengan `ArgumentOutOfRangeException`.

`WM_NCHITTEST` mengembalikan `HTCLIENT` di dalam rounded rectangle dan `HTTRANSPARENT` di luar. Region HWND juga mengecualikan sudut agar click-through lintas proses tidak hanya bergantung pada `HTTRANSPARENT`. Region yang sukses diserahkan kepemilikannya kepada Windows; kegagalan SetWindowRgn membebaskan handle lokal. `Dispose` melepas subclass; jangan memanggilnya sesudah HWND dimusnahkan. `PrimaryWidthDip` dan `DpiScale` tersedia untuk batas pengaturan. Pemulihan display/DPI dinamis masih P1.

`TrayIconHost(nint hwnd, Action showSettings, Action exit)` memasang ikon tray dan subclass terpisah pada HWND overlay yang hidup sepanjang proses. Klik kanan membuka menu native `Settings`/`Exit`; klik ganda membuka Settings. Tooltip “NotchUI — berjalan”. Ikon default sistem dipakai sebagai fallback lokal, tanpa aset jaringan. `TaskbarCreated` mencoba menambahkan kembali ikon sesudah Explorer restart. Constructor gagal melempar `Win32Exception`; bootstrap perlu menampilkan kegagalan startup karena tanpa tray pengguna kehilangan jalur Exit. `Dispose` menghapus ikon dan subclass secara idempoten. Menu memakai `finally` untuk membebaskan HMENU, termasuk ketika action menutup aplikasi.

Tidak ada flag `WS_EX_TRANSPARENT` untuk seluruh overlay karena pill harus menerima input. Window tidak diberi `WS_EX_NOACTIVATE` permanen agar akses keyboard eksplisit masih dapat dikembangkan. Penampilan awal harus melalui host tanpa `Window.Activate()` yang merebut fokus.

## Batas verifikasi

Interop Win32, GSMTC, tray, transparansi komposisi WinUI, dan akses keyboard memerlukan build serta uji pada Windows. Kehadiran `WS_EX_LAYERED` dan region belum membuktikan transparansi komposisi XAML atau 60 FPS. Jalankan checklist `03-design.md` pada perangkat target, khususnya klik sudut lintas proses, restart Explorer, perubahan sesi media selama await, mesin tanpa baterai, sleep/resume, dan Exit. Tidak ada pengujian palsu yang menyatakan API Windows telah dijalankan di Linux. Ponytail tidak tersedia pada katalog tool sesi implementasi ini; berkas sumber disiapkan langsung di workspace.
