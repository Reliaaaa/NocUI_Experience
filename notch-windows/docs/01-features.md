# notch-windows — Daftar Fitur

Aplikasi desktop Windows (C# + WinUI 3, Windows App SDK). Utility notch interaktif di bagian atas layar mirip Dynamic Island. Fitur terinspirasi dari daftar fitur publik README Poni (github.com/liimalim/Poni — hanya deskripsi fungsional, tidak ada kode disalin). Gaya visual terinspirasi notch pill rounded + dark glass-morphism ala "Gili", dibangun ulang dengan aset original sendiri (tanpa logo/aset pihak ketiga).

Format tiap fitur: **ID | Deskripsi | Prioritas | Ketergantungan | Kriteria Selesai**

## Rilis 1 — MVP (iterasi pertama, in-scope sekarang)

- **F-001 Notch Shell** | Window WinUI3 topmost, transparent, frameless, berbentuk pill rounded menempel di top-center layar, click-through di luar area notch | P0 | — | Window tampil di atas semua app, tidak mengganggu klik di luar notch, posisi auto-center di semua resolusi/multi-monitor.
- **F-002 Expand/Collapse Notch** | Hover atau klik membuka notch (expand dengan animasi), klik di luar atau timeout menutup | P0 | F-001 | Expand/collapse mulus <200ms, state tersimpan per sesi.
- **F-003 Auto-hide** | Notch otomatis slide naik/sembunyi saat app lain fullscreen, muncul lagi saat mouse mendekat edge atas | P0 | F-001 | Terdeteksi fullscreen via Win32 API, tidak false-positive pada app window biasa.
- **F-004 Closed-notch Info Display** | Saat notch tertutup, tampilkan info kiri/kanan yang bisa dipilih user (jam, baterai, tanggal, CPU, RAM, disk, Wi-Fi) | P0 | F-001, F-002 | Minimal 3 metrik pilihan berfungsi dan update tiap 1-5 detik tanpa lag UI.
- **F-005 Jam Tengah Notch** | Jam real-time di tengah notch tertutup, tetap tampil walau musik sedang main | P0 | F-004 | Update per detik, format 12/24 jam sesuai setting Windows atau manual.
- **F-005a Drag-and-Drop File ke Notch** | User bisa drag file dari Explorer ke notch untuk aksi cepat (buka shelf sementara) | P1 | F-002 | Drop file terdeteksi, file muncul di area shelf sementara notch terbuka.
- **F-006 Global Shortcut Toggle** | Shortcut keyboard opsional untuk expand/collapse notch | P1 | F-002 | Belum aktif: shortcut global harus opt-in dari Settings; pengaturan baru menyimpannya kosong dan aplikasi tidak mendaftarkan hotkey saat startup.
- **F-010 SMTC Now-Playing** | Ambil info lagu aktif (judul, artis, album art) dari Windows SMTC (System Media Transport Controls) | P0 | F-001 | Terdeteksi dari minimal Spotify/browser/VLC, update saat lagu berganti.
- **F-011 Kontrol Musik** | Tombol play/pause/next/prev yang memanggil SMTC command ke app sumber | P0 | F-010 | Tombol berfungsi dua arah (kontrol dari notch tercermin di app asal).
- **F-012 Progress Bar Lagu** | Progress bar posisi lagu berjalan, update smooth | P1 | F-010 | Progress akurat ±1 detik, drag-to-seek opsional P2.
- **F-020 Dashboard Quick Toggle** | Panel dashboard di notch terbuka: toggle Wi-Fi, Bluetooth, Dark Mode, Mute Mic, Lock PC | P0 | F-002 | Minimal 4 toggle berfungsi nyata via Windows API/WMI, state sinkron dengan OS.
- **F-021 Dashboard Cuaca (placeholder)** | Tampilkan suhu & kondisi cuaca lokasi user (data statis/placeholder di MVP, API real di rilis 2) | P1 | F-020 | Tampil di dashboard dengan data dummy atau 1 sumber gratis (mis. Open-Meteo) bila sempat.
- **F-022 Progress Hari** | Bar visual persentase hari yang sudah lewat (00:00–sekarang vs 24 jam) | P2 | F-020 | Update tiap menit, akurat terhadap timezone lokal.
- **F-030 App Launcher Pin** | Shelf kecil berisi shortcut app favorit user untuk dibuka cepat dari notch | P2 | F-002 | Minimal tambah/hapus/jalankan app dari daftar pin.
- **F-040 Dock Bar Dasar** | Bar dock rounded di bawah layar menampilkan app yang sedang berjalan + pinned apps, dengan efek magnify saat hover | P0 | — | Dock tampil, klik ikon switch/launch app, hover memperbesar ikon halus.
- **F-041 Dock Theming Dasar** | Minimal 1 gaya visual dock (dark glass) di MVP | P1 | F-040 | Dock konsisten dengan tema notch.
- **F-050 Settings Dasar** | Halaman pengaturan: posisi notch, info kiri/kanan closed-notch, shortcut, tema dasar (gelap/terang) | P0 | F-001–F-040 | Semua setting tersimpan persisten (local storage) dan diterapkan tanpa restart app.

## Rilis 2 — Lanjutan

- **F-060 Control Center Penuh** | Panel ala Windows Quick Settings: daftar Wi-Fi + connect, daftar Bluetooth + pairing, slider brightness & volume, pilih output/input audio | P1 | F-020 | Semua kontrol memanipulasi state OS nyata, bukan mock.
- **F-070 Calendar ICS** | Integrasi kalender via link iCal (.ics) — Google Calendar/Outlook/custom, tampilkan event & reminder meeting di notch, tab bulan, tombol Join meeting | P1 | F-002 | Parsing ICS berkala (polling), reminder muncul tepat waktu, Join membuka link meeting.
- **F-080 Todo** | Todo dengan due time bahasa natural (ID/EN), repeating task, snooze, countdown di closed-notch, centang dari notch | P1 | F-002, F-050 | CRUD lengkap, late task auto-centang opsional, persist lokal.
- **F-081 Notes + Flashcard** | Catatan teks, mode flashcard dari baris `pertanyaan :: jawaban` | P2 | F-080 | Simpan/edit note, mode belajar flip card berfungsi.
- **F-082 Pomodoro** | Timer kustom + stopwatch dengan notifikasi di notch | P1 | F-002 | Timer akurat, notifikasi muncul saat selesai, pause/resume berfungsi.
- **F-083 Health Reminder** | Reminder minum air, istirahat, breathing, 20-20-20 eye break, dengan tracking streak | P2 | F-050 | Reminder terjadwal, user bisa snooze/selesai, histori tersimpan.
- **F-090 Snap Zones** | Drag window browser/app ke area notch untuk tile ke posisi layar tertentu | P2 | F-001 | Minimal 4 zona snap (kiri/kanan/atas/maksimal), drag terdeteksi akurat.
- **F-100 Windows Notification Mirror** | Notifikasi Windows (toast) ditampilkan di bawah closed-notch, klik membuka app sumber, riwayat beberapa hari | P1 | F-004 | Listener notifikasi OS berfungsi, riwayat tersimpan terenkripsi lokal, opsi matikan toast asli OS.
- **F-110 Theming Lanjutan** | Pilihan warna kustom, glass, frosted-glass, posisi menempel vs mengambang di bawah edge | P2 | F-050 | Minimal 3 varian tema selain default, preview langsung di Settings.
- **F-120 Backup & Restore** | Export/import semua setting & data lokal ke file untuk pindah PC | P2 | F-050, F-080 | Export menghasilkan 1 file, import mengembalikan state identik.
- **F-130 Dock Lanjutan** | Mode pengganti taskbar penuh: tray icon host, Start/Task View button, window list on hover, end-task dari menu, idle reveal | P2 | F-040 | Minimal 3 kapabilitas tambahan berfungsi stabil tanpa crash Explorer.

## Backlog (fase berikutnya, tidak diestimasi detail sekarang)

- **F-200 AI Chat & Translate** (provider BYO-key: OpenAI-compatible/Ollama) — P2, butuh desain keamanan API key terpisah.
- **F-210 Prayer Times** (API eksternal + adhan custom) — P2.
- **F-220 Clipboard History + Pins** — P2.
- **F-230 FPS Counter** (overlay game, perlu hook capture) — P2, risiko teknis tinggi (kompatibilitas anti-cheat).
- **F-240 Radio Internet (Radio Browser)** — P2.
- **F-250 Bookmarks** — P2.
- **F-260 Multi-bahasa (ID/EN minimal, lainnya nice-to-have)** — P1 untuk ID/EN, P2 lainnya.
- **F-270 Auto-update signed installer** — P1, perlu code-signing cert sebelum rilis publik.
- **F-280 Buddy/companion 3D pet** — P2, nice-to-have, bukan prioritas fungsional.
- **F-290 Cute cursor pack** — P2.
- **F-300 System summary popup berkala** — P2.

## Catatan ketergantungan lintas rilis
Rilis 1 harus selesai dan stabil (F-001 s/d F-050) sebelum Rilis 2 dimulai, karena hampir semua fitur lanjutan menempel pada notch shell dan settings dasar. F-100 (notification mirror) butuh F-004. F-070/F-080/F-082/F-083 semua butuh F-002 dan F-050 untuk UI container dan persistence dasar.
