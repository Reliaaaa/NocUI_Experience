# Laporan QA NotchUI

Tanggal pemeriksaan: 2026-11-04 (putaran kedua)

## Ringkasan keputusan

P0 belum dapat dinyatakan tertutup. Putaran kedua menemukan proyek WinUI, manifest, App, dashboard, overlay, view model, dan coordinator. Pemeriksaan XML berhasil, namun belum ada Windows build atau uji runtime; beberapa perilaku P0 masih tidak memenuhi kontrak.

P1 juga belum tertutup. F17 (perubahan display/DPI) dan F18 (reduced motion) didokumentasikan sebagai tahap sesudah MVP dan belum terlihat sebagai implementasi. Ini tidak menghalangi rilis MVP menurut urutan fitur, tetapi keduanya belum selesai.

## Matriks uji

| Area | Metode | Hasil | Status |
| --- | --- | --- | --- |
| Inventaris docs 01–05 dan sumber | Inspeksi file dan kontrak | Dokumen 01–05, proyek WinUI, jendela, service, manifest, dan self-check tersedia. | Ada; build belum diverifikasi |
| Build/test .NET | `dotnet run --project tests/NotchUI.Settings.SelfCheck` tidak dapat dijalankan | `dotnet`, `csc`, dan `mcs` tidak tersedia di PATH lingkungan ini. | Blocked (toolchain) |
| Codec settings | Review statis | Ada roundtrip, batas payload, version check, fallback default, normalisasi NaN/infinity, ukuran/radius/warna. Self-check mencakup kasus tersebut tetapi belum dieksekusi. | Review saja |
| Penyimpanan LocalSettings | Review statis | Main key dan LastGood, penolakan versi masa depan, penyimpanan satu payload, penanganan exception tampak konsisten dengan docs. Integrasi WinRT dan kegagalan storage belum bisa disimulasikan. | Review saja |
| Jam/baterai/media | Review statis | Timer jam selaras pergantian menit; baterai membedakan unavailable/unknown; media membersihkan sesi dan menjaga hasil async dengan generation/version. Belum ada uji runtime Windows atau GSMTC. | Review saja |
| Overlay/tray Win32 | Review statis | Native adapter terhubung ke shell. Click-through lintas proses, region, taskbar restart, menu, DPI, dan lifetime belum diuji. | Belum terverifikasi |
| UI reference | Inventaris tujuh pasang screenshot/HTML serta dua DESIGN.md | Referensi tersedia dan UI XAML telah dibuat; kesesuaian visual belum diuji pada Windows. | Review saja |
| Static checks | Inspeksi source | Edge case radius nol pada hit test ditemukan dan diperbaiki. Tidak menjalankan analyzer/compiler. | Sebagian |
| XML/XAML/project/manifest | Python `xml.etree.ElementTree` parse | App.xaml, MainWindow.xaml, OverlayWindow.xaml, NotchUI.csproj, Package.appxmanifest valid sebagai XML. Ini bukan validasi XAML compiler atau manifest schema Windows. | Lulus parse |

## Temuan

| ID | Severity | Status | Temuan / dampak |
| --- | --- | --- | --- |
| QA-001 | P1 (edge case) | Fixed | `OverlayWindowHost` melakukan uji rounded-rectangle dengan radius nol. Rumus awal hanya menerima titik yang tepat pada sudut (0,0), walau region HWND berbentuk persegi panjang; notch beradius nol praktis tidak dapat diklik. Ditambahkan jalur hit test persegi panjang pada radius nol di `src/NotchUI/Interop/OverlayWindowHost.cs`. Perlu validasi runtime Windows karena toolchain tidak tersedia. |
| QA-002 | P0 | Source tersedia; verifikasi terbuka | Proyek WinUI, bootstrap, jendela, manifest, dan integrasi service sudah ditambahkan. Build serta penerimaan F01–F16 masih memerlukan Windows. |
| QA-003 | P0 (verification) | Open | Tidak ada .NET SDK/compiler di lingkungan QA; self-check tidak dijalankan. Kegagalan ini adalah keterbatasan lingkungan, bukan bukti tes gagal. Jalankan self-check pada mesin .NET 8 sebelum merge/release. |
| QA-004 | P1 | Open / deferred by scope | F17 monitor/DPI dinamis dan F18 reduced motion tidak ada dalam sumber. Docs secara eksplisit menjadwalkannya setelah MVP; tandai belum selesai, bukan penerimaan MVP. |
| QA-005 | P0 | Perbaikan source; belum diuji | Penyimpanan sekarang memakai debounce 400 ms dan flush saat dispose. Kegagalan tulis dan keluar saat debounce tertunda masih perlu diuji di Windows. |
| QA-006 | P0 | Perbaikan source; belum diuji | Geometri diperbarui selama animasi menggunakan ukuran visual. Kesesuaian area interaktif dan ruang monitor perlu diuji pada Windows. |

## Risiko dan kasus tepi yang perlu diuji pada Windows

- Settings: rusaknya primary dengan LastGood valid/tidak valid, key versi masa depan, nilai lebih dari batas, kegagalan tulis, dan Exit ketika debounce tertunda.
- Overlay: radius 0 dan maksimum, layar lebih kecil dari minimum desain, sudut click-through ke aplikasi proses lain, hover/click selama ekspansi, ukuran visual versus region pada setiap frame, serta topmost/fokus.
- Media: pergantian sesi saat command berjalan, tanpa sesi, metadata kosong/panjang, dan kemampuan previous/next parsial.
- Sistem: desktop tanpa baterai, sleep/resume dan perubahan jam zona lokal, Taskbar restart, DPI selain 100%, serta cleanup saat Exit.

## Perintah verifikasi yang disarankan

Pada mesin ber-.NET 8 jalankan `dotnet run --project tests/NotchUI.Settings.SelfCheck`. Setelah proyek WinUI ditambahkan, build packaged app pada Windows dan lakukan matriks penerimaan manual di docs/01-features.md serta walkthrough Windows tambahan di docs/05-database.md. Tidak ada hasil runtime yang diklaim oleh laporan ini.
