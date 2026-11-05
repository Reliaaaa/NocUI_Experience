# Laporan QA NotchUI

Tanggal pemeriksaan: 2026-11-05 (putaran ketiga)

## Ringkasan keputusan

P0 belum dapat dinyatakan tertutup. Putaran ketiga meninjau perubahan Escape/lifecycle overlay, ukuran preview dan label UI, pembacaan storage berbatas, serta perluasan self-check. `git diff --check` dan parse XML lulus. Self-check belum dijalankan karena `dotnet` tidak tersedia di lingkungan ini; belum ada Windows build atau uji runtime.

P1 juga belum tertutup. Source awal F17 (perubahan display/DPI) dan F18 (durasi animasi yang dapat disetel hingga nol) kini tersedia. Review source melihat handler perubahan display/DPI memperbarui geometri dan durasi nol melewati animasi; keduanya masih deferred dari acceptance MVP dan belum diverifikasi lewat build atau runtime Windows. F18 belum menyediakan preferensi reduced-motion yang terpisah atau sinkronisasi kebijakan sistem.

## Matriks uji

| Area | Metode | Hasil | Status |
| --- | --- | --- | --- |
| Inventaris docs 01–05 dan sumber | Inspeksi file dan kontrak | Dokumen 01–05, proyek WinUI, jendela, service, manifest, dan self-check tersedia. | Ada; build belum diverifikasi |
| Build/test .NET | `dotnet run --project tests/NotchUI.Settings.SelfCheck` dicoba | `dotnet` tidak tersedia di PATH; self-check tidak dijalankan. | Blocked (toolchain) |
| Diff hygiene | `git diff --check` | Tidak ada whitespace error. | Lulus |
| XML/XAML/project | Python `xml.etree.ElementTree` parse | MainWindow.xaml, OverlayWindow.xaml, NotchUI.csproj, dan self-check csproj valid sebagai XML. Ini bukan validasi XAML compiler atau manifest schema Windows. | Lulus parse |
| Codec dan penyimpanan unpackaged | Review statis terhadap bounded reader, preservation guard, atomic replace, serta self-check baru | Pembacaan dibatasi 4097 karakter untuk mendeteksi payload >4096; BOM ditangani oleh StreamReader; future version dan kegagalan baca mempertahankan file. Self-check kini mencakup short read, batas ukuran, BOM, file hilang, payload masa depan/oversize, serta kegagalan baca, tetapi belum dijalankan. | Review saja |
| Penyimpanan packaged LocalSettings | Review statis setelah guard ditambahkan | `CanInspectStoredValue` menerima hanya string dengan panjang maksimum 4096; tipe tak sesuai atau nilai lebih besar mengaktifkan preservation guard sebelum decode/save. Integrasi WinRT belum bisa disimulasikan; tidak ada klaim runtime. | Review saja |
| Overlay Escape/lifecycle | Review statis | Escape ditangani saat event KeyDown merutekan melalui Pill; callback timer, coordinator, display, serta aksi media memeriksa `_closed`; teardown melepas handler dan menghentikan timer/transisi. Belum diuji dengan input/runtime Windows. | Review saja |
| Preview dan label UI | Review statis | Preview dipasang dalam Viewbox `DownOnly`; slider memiliki `LabeledBy`/HelpText dan kontrol widget memiliki nama aksesibilitas. Skala dan pembacaan screen reader belum diuji pada Windows. | Review saja |
| Jam/baterai/media | Review statis | Timer jam selaras pergantian menit; baterai membedakan unavailable/unknown; media membersihkan sesi dan menjaga hasil async dengan generation/version. Belum ada uji runtime Windows atau GSMTC. | Review saja |
| Overlay/tray Win32 | Review statis | Native adapter terhubung ke shell. Click-through lintas proses, region, taskbar restart, menu, DPI, dan lifetime belum diuji. | Belum terverifikasi |
| UI reference | Inventaris tujuh pasang screenshot/HTML serta dua DESIGN.md | Referensi tersedia dan UI XAML telah dibuat; kesesuaian visual belum diuji pada Windows. | Review saja |
| Static checks | Inspeksi source | Edge case radius nol pada hit test ditemukan dan diperbaiki. Tidak menjalankan analyzer/compiler. | Sebagian |
| XML/XAML/project/manifest | Parse XML sebelumnya; parse putaran ini untuk file yang berubah | Pemeriksaan sebelumnya juga mencakup App.xaml dan manifest. Parse tidak memvalidasi XAML compiler atau manifest schema Windows. | Lulus parse |

## Temuan

| ID | Severity | Status | Temuan / dampak |
| --- | --- | --- | --- |
| QA-001 | P1 (edge case) | Fixed | `OverlayWindowHost` melakukan uji rounded-rectangle dengan radius nol. Rumus awal hanya menerima titik yang tepat pada sudut (0,0), walau region HWND berbentuk persegi panjang; notch beradius nol praktis tidak dapat diklik. Ditambahkan jalur hit test persegi panjang pada radius nol di `src/NotchUI/Interop/OverlayWindowHost.cs`. Perlu validasi runtime Windows karena toolchain tidak tersedia. |
| QA-002 | P0 | Source tersedia; verifikasi terbuka | Proyek WinUI, bootstrap, jendela, manifest, dan integrasi service sudah ditambahkan. Build serta penerimaan F01–F16 masih memerlukan Windows. |
| QA-003 | P0 (verification) | Open | Tidak ada .NET SDK/compiler di lingkungan QA; self-check tidak dijalankan. Kegagalan ini adalah keterbatasan lingkungan, bukan bukti tes gagal. Jalankan self-check pada mesin .NET 8 sebelum merge/release. |
| QA-004 | P1 | Source tersedia; acceptance terbuka | F17 memiliki handler perubahan display/DPI dan perhitungan ulang geometri di `OverlayWindowHost`; F18 menyediakan kontrol durasi animasi 0–600 ms dan jalur durasi 0 tanpa animasi. Review statis saja; build, perubahan monitor/DPI nyata, serta acceptance aksesibilitas/reduced motion belum diverifikasi di Windows. |
| QA-005 | P0 | Perbaikan source; belum diuji | Penyimpanan sekarang memakai debounce 400 ms dan flush saat dispose. Kegagalan tulis dan keluar saat debounce tertunda masih perlu diuji di Windows. |
| QA-006 | P0 | Perbaikan source; belum diuji | Geometri diperbarui selama animasi menggunakan ukuran visual. Kesesuaian area interaktif dan ruang monitor perlu diuji pada Windows. |
| QA-007 | P0 (verification) | Open | Perubahan Escape, cleanup lifecycle, Viewbox, automation labels, bounded storage, dan self-check direview secara statis; belum ada hasil compile atau eksekusi self-check. `dotnet` tidak tersedia di lingkungan pemeriksaan ini. |
| QA-008 | P1 (verification) | Source guard added; runtime open | Jalur packaged `LocalSettings` kini memeriksa tipe dan batas 4096 karakter melalui `SettingsCodec.CanInspectStoredValue`; nilai tak sesuai/oversize dipertahankan dan tidak ditimpa. Perilaku WinRT belum diuji pada Windows. |

## Risiko dan kasus tepi yang perlu diuji pada Windows

- Settings: rusaknya primary dengan LastGood valid/tidak valid, key versi masa depan, nilai lebih dari batas, kegagalan tulis, dan Exit ketika debounce tertunda.
- Settings: jalankan self-check terbaru pada .NET 8, termasuk short read, payload tepat 4096 karakter, BOM UTF-8/UTF-16, preservation pada payload oversize/future, dan kegagalan baca.
- Overlay: Escape setelah buka dengan keyboard, mouse, dan hover; fokus saat collapse; close ketika timer/transisi/aksi media berjalan; radius 0 dan maksimum, layar lebih kecil dari minimum desain, sudut click-through ke aplikasi proses lain, ukuran visual versus region pada setiap frame, serta topmost/fokus.
- Media: pergantian sesi saat command berjalan, tanpa sesi, metadata kosong/panjang, dan kemampuan previous/next parsial.
- Sistem: desktop tanpa baterai, sleep/resume dan perubahan jam zona lokal, Taskbar restart, DPI selain 100%, serta cleanup saat Exit.

## Perintah verifikasi yang disarankan

Pada mesin ber-.NET 8 jalankan `dotnet run --project tests/NotchUI.Settings.SelfCheck`. Setelah proyek WinUI ditambahkan, build packaged app pada Windows dan lakukan matriks penerimaan manual di docs/01-features.md serta walkthrough Windows tambahan di docs/05-database.md. Tidak ada hasil runtime yang diklaim oleh laporan ini.
