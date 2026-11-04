# Desain Windows Dynamic Notch

## Dasar dan batas desain

Dokumen ini menerjemahkan `01-features.md` dan `02-architecture.md` menjadi kontrak UI MVP. Tujuh pasangan `screen.png`/`code.html` serta dua `DESIGN.md` di `ui-reference/stitch_windows_dynamic_notch_utility` sudah ditelaah. Screenshot menentukan arah visual; HTML menjelaskan komponen/properti mockup, bukan implementasi native atau bukti performa. Persyaratan fitur dan arsitektur mengungguli mockup bila berbeda.

MVP: satu dashboard pengaturan, satu overlay pada layar utama, jam, baterai, media, dan tray. Tidak ada katalog plugin, akun, pencarian global, multi-display, monitor chooser, profil, tombol Apply, diagnostik, cuaca, fokus, autorun, atau halaman About terpisah. Preferensi berlaku langsung. F17 reposisi display/DPI dan F18 preferensi reduced motion tetap P1; kontrol keduanya belum ditampilkan pada MVP.

## Peta navigasi dan jendela

```text
Peluncuran aplikasi (satu instance)
├── OverlayWindow → Compact ⇄ Opening/Closing ⇄ Expanded
├── MainWindow → SettingsPage (satu halaman)
│   ├── Ukuran dan bentuk
│   ├── Warna notch
│   └── Modul: Jam / Baterai / Media
└── Ikon tray → menu konteks
    ├── Settings → buat atau aktifkan MainWindow yang sama
    └── Exit → tutup kedua jendela, hapus tray, akhiri proses
```

Dashboard tampil saat peluncuran pertama untuk menemukan pengaturan; peluncuran berikutnya boleh menggunakan perilaku startup yang sama secara konsisten. Tombol Close dan Alt+F4 pada dashboard hanya menutup dashboard. Teks bantuan permanen: “Notch tetap berjalan di tray. Pilih Exit dari menu tray untuk keluar.” Minimize memakai perilaku Windows biasa. Dashboard tidak topmost. Overlay topmost tanpa title bar, taskbar button, atau bingkai; tampil tanpa merebut fokus dari aplikasi aktif. Tidak ada dialog konfirmasi saat menutup dashboard maupun Exit.

Menu tray memiliki label `Settings` dan `Exit` sesuai arsitektur. Bahasa label halaman dapat dilokalkan, tetapi gunakan resource string konsisten; dokumen ini memakai contoh copy Indonesia. Tray memiliki tooltip “NotchUI — berjalan”. Interaksi keyboard menu tray mengikuti shell Windows.

## Layout dashboard MVP

Ukuran awal usulan 880 × 720 DIP, dapat diubah; layout minimal 480 DIP lebar sebelum konten perlu penataan tambahan. Gunakan title bar/caption buttons native dan judul “NotchUI — Pengaturan”. Tidak perlu sidebar kosong atau breadcrumb untuk satu halaman. Pertahankan komposisi kartu Stitch: heading “Pengaturan notch”, deskripsi “Perubahan langsung diterapkan pada notch di layar utama”, lalu tiga kartu dalam ScrollViewer vertikal. Margin 24 DIP (12 saat lebar <640), jarak kartu 16, padding kartu 16. Pada lebar kecil semua label, nilai, dan kontrol disusun vertikal; jangan membuat scroll horizontal.

Kartu “Ukuran dan bentuk”: slider Lebar, Tinggi, Radius sudut dengan nilai numerik DIP yang selalu terlihat. Nilai bukan ukuran piksel fisik monitor. Kartu “Warna notch”: swatch, nilai warna heksadesimal, serta ColorPicker native dalam flyout. Kartu “Modul”: satu baris untuk tiap modul, label, status saat ini, dan ToggleSwitch berlabel Aktif/Nonaktif. Semua perubahan langsung terlihat di overlay tanpa Apply/reload; helper penyimpanan hanya muncul jika gagal.

Preview simulasi desktop besar dari Stitch tidak diperlukan; overlay asli menjadi umpan balik langsung. Jika memakai ilustrasi kecil noninteraktif, tandai sebagai ilustrasi dan jangan berisi metadata lagu atau metrik palsu.

## Geometri dan susunan overlay

Default desain usulan: ringkas 320 × 34 DIP, radius 16 DIP, warna #000000; semua modul aktif. Default ini harus menjadi satu sumber bersama `NotchSettings`, bukan nilai terpisah di view. Ambil arah ukuran dari appearance mockup, dengan offset atas tetap 0 agar tertambat pada tepi atas. Lebar usulan 200–520 DIP, tinggi 28–64 DIP, radius 0–32 DIP; batas efektif selalu tunduk pada monitor dan `radius ≤ min(width,height)/2`. Tampilkan batas efektif pada slider; perubahan tinggi dapat menjepit radius dan langsung memperbarui nilainya. Angka ini spesifikasi desain awal yang perlu diverifikasi di Windows, bukan hasil pengukuran.

Titik tengah horizontal tidak bergerak ketika membuka/menutup. Expanded memakai target awal 440 × 176 DIP dengan padding 16; ukuran target dapat bertambah mengikuti text scaling dan dijepit pada ruang layar. Target expanded minimal menampung kontrol media; pengaturan ukuran ringkas tidak mengecilkan kontrol expanded. Saat layar sangat sempit, susun konten vertikal dengan tetap mempertahankan target kontrol dan batas monitor.

Compact memprioritaskan waktu di kiri, judul media satu baris di tengah, persentase/ikon pengisian di kanan. Judul dipotong dengan ellipsis; jangan marquee atau menampilkan judul contoh. Saat lebar tidak cukup, sembunyikan judul ringkas terlebih dahulu; informasi penuh tetap di expanded. Modul off dilepas dari layout. Semua modul off menyisakan bentuk notch kosong yang tetap dapat dibuka, dengan teks expanded “Semua modul dinonaktifkan” dan petunjuk membuka Settings dari tray.

Expanded memuat baris waktu/baterai, lalu judul/artis media maksimal masing-masing satu baris, dan tiga tombol Previous, Play/Pause, Next. Urutan tombol tetap, target interaksi minimal 32 × 32 DIP dengan jarak 8. Tidak ada seekbar, shuffle, repeat, volume, favorite, perkiraan waktu baterai, album art wajib, Wi-Fi, atau equalizer karena belum diminta. Metadata panjang dapat dibaca melalui tooltip serta nama aksesibilitas lengkap.

## Tujuan, komponen, dan state setiap P0

| Fitur | Tujuan / komponen UI | State dan perilaku yang harus terlihat |
| --- | --- | --- |
| F01 Kerangka | MainWindow dan OverlayWindow terpisah | Satu instance; buka Settings berulang mengaktifkan dashboard yang sama. Overlay tetap hidup saat dashboard ditutup. |
| F02 Overlay tanpa chrome | Root transparan dan satu rounded rectangle | Seluruh area selain notch benar-benar memperlihatkan desktop. Tidak ada canvas berwarna, caption, atau fokus yang dicuri saat tampil. |
| F03 Bentuk ringkas | Pill terpusat di tepi atas layar utama | Compact default; hanya pill berwarna. Posisi memakai bounds monitor utama saat startup, bukan posisi dashboard. |
| F04 Hit test | Bentuk interaktif sesuai rounded rectangle | Area di dalam menerima input; luar, termasuk sudut kosong, meneruskan klik ke aplikasi lain. Geometri mengikuti frame visual selama transisi dan perubahan slider. |
| F05 Buka/tutup | Pill sebagai trigger, panel expanded | Compact → hover/klik → Opening → Expanded; pointer keluar/klik ulang → Closing → Compact. Klik tombol media ditangani tombol, tidak ikut men-toggle parent. Perpindahan pointer ke kontrol dalam expanded tidak dianggap keluar. |
| F06 Animasi | Storyboard ukuran/radius/opacity konten | Usulan 180–220 ms ease-out, tanpa bounce besar; input baru membalik target dari ukuran saat ini. Konten tidak menonjol keluar bentuk. Anchor atas/tengah tetap. Target 60 Hz diverifikasi pada Windows. |
| F07 Jam | TextBlock waktu lokal | Loading singkat boleh memakai “—”; Ready memakai format waktu lokal Windows, tanpa detik; refresh menit/resume/perubahan waktu. Off menghapus slot. |
| F08 Baterai | Ikon daya, angka persen, status teks | Tersedia: “84%”; Charging: ikon + “84% · Mengisi daya”; Unavailable: “Baterai tidak tersedia” pada expanded/dashboard, slot compact disembunyikan. Unknown memakai “Status baterai tidak diketahui”, tanpa 0% palsu. Off menghapus slot. |
| F09 Info media | Judul/artis dan status sesi | Loading: “Memuat media…”; Active: metadata aktual; tanpa judul: “Judul tidak tersedia”; tanpa artis: hilangkan baris artis; No session: “Tidak ada media aktif”, metadata lama dibersihkan. Error: “Media belum tersedia” tanpa crash. Off menghapus seluruh area media. |
| F10 Kontrol media | Tiga Button berikon | Playing menampilkan Pause; Paused menampilkan Play. Tiap tombol disabled sesuai kemampuan sesi. No session menonaktifkan semua. Saat perintah pending cegah pengiriman berulang pada tombol itu; hasil gagal memberi status singkat “Kontrol media gagal. Coba lagi.” dan tetap menjaga metadata sesi terbaru. |
| F11 Tray/lifetime | Ikon tray dan menu Settings/Exit | Dashboard Visible/Closed tidak memengaruhi overlay; Settings membuka satu dashboard; Exit menghentikan semuanya. Tidak ada sakelar “minimize to tray” karena perilakunya tetap. |
| F12 Dashboard | Heading, kartu, label, nilai, status | Semua kontrol bisa dijangkau keyboard; nilai aktual tampil saat dibuka kembali. ScrollViewer menampung konten pada window kecil/text scaling besar. |
| F13 Ukuran/radius | Tiga Slider, label dan nilai DIP | Rest/Hover/Dragging/KeyboardFocus; perubahan langsung, nilai dibatasi, radius tervalidasi, hit test sinkron. Nilai yang dijepit tampil sebagai nilai efektif. |
| F14 Warna | Swatch + Button/flyout ColorPicker | Closed/Open/Changing; RGB/hex valid mengubah fill segera. Alpha dipertahankan opak untuk menjaga kontras yang dapat dihitung. Luar notch tetap transparan. Foreground notch menyesuaikan gelap/terang berdasarkan luminansi fill. |
| F15 Sakelar modul | Tiga ToggleSwitch independen | On/Off terpisah dari Ready/Unavailable. Baterai tanpa perangkat tetap dapat On; status menjelaskan ketersediaan. Menonaktifkan media menghapus tombol/metadata, tanpa memengaruhi playback sumber. |
| F16 Preferensi | Umpan balik simpan nonmodal | Perubahan langsung di memori; simpan tertunda singkat setelah drag. Default aman saat data rusak/hilang. Jika gagal menyimpan: InfoBar “Pengaturan berlaku untuk sesi ini, tetapi belum tersimpan.” Retry hanya mengulangi penyimpanan lokal; tidak membatalkan perubahan. |

Status kesalahan tidak boleh mengganti seluruh dashboard. Gunakan pesan dekat modul terkait; InfoBar global hanya untuk kegagalan preferensi. Ketika sesi media berganti saat operasi async berjalan, UI menampilkan sesi terbaru tanpa pesan sukses dari sesi lama.

## Token visual Fluent / Mica dark

Utamakan `fluent_desktop_mica_dark/DESIGN.md` dan screenshot HUD `_2`. `fluent_desktop_system` memasok ritme/layout; Work Sans dan warna light pada HTML tidak dibawa ke aplikasi native. Nilai berikut adalah alias desain; gunakan resource theme WinUI untuk state native/high contrast alih-alih mengganti setiap template kontrol.

| Token | Nilai / penggunaan WinUI 3 |
| --- | --- |
| Window backdrop | MicaBackdrop pada dashboard bila OS mendukung; solid #181818 saat tidak tersedia/transparency effects off. Mica bukan transparansi overlay. |
| Canvas / inset / card | #202020 / #1C1C1C / #2C2C2C; Border + Grid untuk kartu. |
| Flyout | Material native Flyout/MenuFlyout; fallback solid #2C2C2C. Jangan menyalin CSS backdrop-filter 30 px. |
| Accent / hover / pressed | #60CDFF / #7ADAFF / #4CB8ED; teks pada accent #000000. Gunakan theme resource saat sistem memerlukan override. |
| Text primary / secondary | #FFFFFF / #D0D4D9. Tertiary #8A929B hanya untuk bantuan nonesensial/disabled. |
| Stroke / focus | Putih 8% untuk kartu, outline fokus native terlihat dengan accent; jangan hapus focus visual. |
| Typography | Segoe UI Variable, fallback Segoe UI; heading 28/36 semibold, section 20/26 semibold, body 14/20, caption 12/16 DIP. Nilai/font mengikuti text scaling. |
| Spacing | 4, 8, 12, 16, 24 DIP; gap tombol 8; padding kartu 16. |
| Radius | Kontrol 4, kartu/flyout 8 DIP; frame dashboard dikelola DWM. Radius notch berasal dari preferensi tervalidasi. |
| Icons | SymbolIcon/FontIcon Segoe Fluent Icons; glyph status selalu didampingi nama atau tooltip. Tidak memakai Material Symbols dari CDN. |
| Elevation | Kartu dibedakan oleh stroke, tanpa shadow berat. Native flyout mengelola shadow. Overlay tidak memakai glow dekoratif yang memperluas area visual di luar hit test. |

## Aksesibilitas dan ergonomi desktop

- Tab/Shift+Tab mengikuti urutan visual: slider lebar → tinggi → radius → warna → toggle jam → baterai → media. Arrow keys mengubah slider 1 DIP; Home/End mencapai batas. Space mengubah toggle, Enter/Space mengaktifkan button. Flyout ColorPicker dapat ditutup Esc dan mengembalikan fokus ke pemicu.
- Beri AutomationProperties.Name, label/value yang terbaca, help text satuan DIP, serta status media/baterai. Nama Play/Pause berubah sesuai aksi. Disabled control tetap memiliki label dan penjelasan kemampuan yang tidak tersedia. Jangan memakai tooltip sebagai satu-satunya label.
- Overlay tidak mengambil fokus saat hover. Bila diaktifkan secara eksplisit melalui keyboard/shell, trigger harus focusable dengan Enter/Space membuka; Tab mencapai tombol media, Esc menutup dan mengembalikan fokus ke trigger. Pointer keluar tidak menutup panel selama fokus keyboard masih di dalamnya. Ini aturan mempertahankan akses keyboard untuk F05, bukan fitur pin/global shortcut baru. Jalur pengaktifan overlay via keyboard harus dibuktikan dengan shell native pada Windows; jangan menyembunyikan seluruh aksesibilitas overlay demi menghilangkan taskbar button.
- Text scaling hingga 200% dan DPI 100/150/200% tidak memotong label atau target kontrol. Dashboard reflow/scroll; expanded tumbuh dan compact mengurangi konten sekunder. Ini pengujian rendering startup pada tiap skala; reposisi dinamis setelah perubahan monitor tetap F17.
- Teks normal menargetkan kontras minimal 4,5:1, teks besar dan batas kontrol esensial 3:1. Warna notch yang dipilih pengguna harus memilih foreground hitam/putih dengan kontras memadai. High contrast menggunakan SystemColor/theme resource, bukan forced palette; informasi status tidak hanya dibedakan warna.
- Jangan mengumumkan jam setiap menit melalui live region. Umumkan kegagalan interaksi media secara polite; perubahan lagu tidak memindahkan fokus. Placeholder/dekorasi tidak menjadi tab stop.
- P0 memakai motion singkat tanpa kedipan atau gerak terus-menerus. Pengaturan reduced motion dan sinkronisasi kebijakan animasi memerlukan F18; jangan menampilkan switch palsu sebelum didukung.

## Pemetaan tujuh layar Stitch ke WinUI 3

Semua nama folder relatif terhadap `ui-reference/stitch_windows_dynamic_notch_utility/` dan tiap baris merujuk `screen.png` serta `code.html` di folder tersebut.

| Layar referensi | Dipakai pada MVP / kontrol native | Tidak dibawa ke MVP |
| --- | --- | --- |
| `settings_general_appearance` | Kartu dimensi → Border/Grid + 3 Slider; warna → ColorPicker flyout; hierarki heading dan nilai. Tampilan diubah menjadi dark tokens. | Simulator resolusi/DPI, offset atas, material chooser, opacity/glow, monitor chooser, fullscreen rules, metrik performa, Apply Profile. |
| `notch_hud_top_bar_overlay_1` | Anatomi pill atas dan panel media expanded → Border/Grid/TextBlock/Button pada OverlayWindow; dashboard/overlay benar-benar dua HWND. | Desktop/terminal palsu, album art wajib, seek/volume/shuffle/repeat, fokus/night light/VRR, state simulator, equalizer, spring physics, reload engine. |
| `notch_hud_top_bar_overlay_2` | Sumber utama dark surface, stroke, kontras dan metadata media; digabung dengan anatomi `_1`. | Seluruh kontrol lanjutan yang sama; screenshot bukan halaman tambahan atau mode runtime tersendiri. |
| `notch_widgets_catalog` | Pola toggle per modul dan status → 3 baris ToggleSwitch pada SettingsPage; jam ditambahkan sesuai PRD. | Widget store, install/import, reorder/drag slots, auto-priority, cuaca, telemetry, fokus, clipboard, SDK pihak ketiga. |
| `gestures_behavior` | Arah penjelasan hover/klik dan batas hit test → state coordinator + pointer events; keterangan singkat perilaku pada dashboard bila perlu. | Halaman gesture, hit-zone slider, pin, touchpad swipe, wheel volume, exclusions, multi-display barrier, global shortcuts. |
| `animations_physics` | Gerak ringan sebagai Storyboard; token timing awal 180–220 ms. P1 F18 dapat menambah satu preferensi reduced motion pada halaman yang sama. | Inspector/grafik fisika, mass/stiffness/damping, preset spring, FPS selector, SVG morph, tilt, render backend switches, GPU numbers. |
| `about_notchui` | Identitas aplikasi pada title bar dan gagasan close-ke-tray → perilaku tetap AppLifetimeService. | Halaman About, versi/SDK/sertifikasi klaim mockup, update checker, autorun, notification mirroring, diagnostic export, runtime metrics, tautan komunitas tanpa tujuan nyata. |

HTML memakai Tailwind, web fonts, Material Symbols, absolute positioning, dan angka runtime statis. Semuanya dipetakan ke XAML serta API native; tidak memuat HTML/WebView/CDN atau menyalin teks “v2.4”, “Microsoft Store Signed”, “0.42 ms”, “120 Hz”, atau nama GPU sebagai fakta produk.

## Review penerimaan UI

Periksa pada Windows target: transparansi/click-through lintas proses termasuk sudut bulat; hover dan klik selama transisi; tombol media tidak menutup parent; dashboard tetap responsif; tray membuka satu dashboard; Close tidak mengakhiri overlay dan Exit mengakhiri proses. Uji semua modul On/Off, tanpa baterai, tanpa sesi media, metadata kosong/panjang, kemampuan kontrol parsial, serta preferensi rusak/gagal simpan/restart. Lakukan walkthrough keyboard dan Narrator, high contrast, text scaling, serta DPI startup berbeda. Halusnya animasi dan keterbacaan di monitor kecil perlu bukti runtime; aset Stitch hanya acuan visual.
