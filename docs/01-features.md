# Fitur Windows Dynamic Notch

## Ruang lingkup dan aturan rilis

Produk adalah aplikasi desktop native Windows dengan C# 12, .NET 8, WinUI 3 (Windows App SDK), dan Win32 untuk pengelolaan jendela. Rilis awal hanya mencakup satu notch di tengah tepi atas **layar utama**. Dashboard mengikuti arah visual Fluent pada `ui-reference`, sedangkan kebutuhan fungsional dirangkum di matriks berikut. Tautan PRD asli di `README.md` menunjuk ke `attachments/` yang tidak tersedia dalam checkout ini; jangan menafsirkan mockup sebagai kebutuhan tambahan. Satu fitur di bawah ini dirancang sebagai pekerjaan satu orang selama sekitar 1–3 hari; rentang itu adalah perkiraan, bukan janji jadwal.

**P0** wajib untuk MVP; **P1** peningkatan setelah MVP. Tidak ada P2 yang dijadwalkan. Dependensi merujuk ID fitur yang harus selesai lebih dahulu. Kriteria selesai berarti perilaku bisa diperiksa pada Windows, bukan hanya adanya kontrol di layar.

## Status implementasi saat ini

Source kini berisi proyek WinUI, `App`, dashboard dan overlay XAML, view model, coordinator, service jam/baterai/media, adapter HWND/tray, manifest MSIX, workflow build Windows, dan skrip installer Inno Setup. Pengguna melaporkan aplikasi **berhasil dijalankan** pada Windows. Itu adalah bukti smoke run dari pengguna, bukan hasil matriks penerimaan F01–F18: log build, hasil pengukuran animasi, pengujian click-through lintas proses, variasi perangkat/sesi media, persistensi, serta instalasi paket/installer belum tercatat lengkap dalam repo.

| Cakupan source | Keadaan yang dapat ditelusuri |
| --- | --- |
| F01–F04, F11 | `App.xaml.cs` membuat satu overlay dan dashboard serta tray; `OverlayWindowHost` mengatur topmost, layered window, region rounded rectangle, dan hit test. Perilaku HWND lintas proses masih memerlukan uji Windows. |
| F05–F10 | `OverlayWindow.xaml(.cs)` mengelola hover, klik, Storyboard, jam/baterai, dan tombol media; service memakai waktu lokal, status daya, dan GSMTC. Hasil runtime setiap state belum didokumentasikan. |
| F12–F16 | Dashboard `NavigationView` menyediakan ukuran, radius, warna, opasitas, tiga sakelar modul; `NotchCoordinator` menyimpan perubahan dengan debounce 400 ms lewat `SettingsService`. Build unpackaged menyimpan `settings.json`; build MSIX memakai `ApplicationData.LocalSettings`. Pemulihan end-to-end perlu diuji. |
| F17–F18 | Source sudah merespons perubahan display/DPI dan menyediakan durasi animasi 0–600 ms (0 menonaktifkan gerak). Keduanya tetap P1 dan belum mendapat acceptance Windows. |

Navigasi dashboard saat ini memiliki halaman Appearance, Widgets, Behavior, Animations, dan About. Behavior menyediakan sakelar hover; Animations menyediakan durasi transisi. Ini permukaan UI yang sudah ada, bukan penambahan persyaratan PRD. Warna/opasitas pill, aset branding, dan jalur installer juga ada di source, tetapi belum menjadi klaim acceptance tersendiri.

| ID | Prioritas | Fitur terkecil | Deskripsi | Dependensi | Kriteria selesai |
| --- | --- | --- | --- | --- | --- |
| F01 | P0 | Kerangka aplikasi | Buat aplikasi WinUI 3 packaged dengan dua jendela terpisah untuk dashboard dan overlay. | — | Aplikasi dapat dibuka pada Windows target; dashboard dan overlay dapat dibuat dalam satu proses tanpa jendela duplikat. |
| F02 | P0 | Overlay tanpa chrome | Tampilkan jendela overlay transparan, selalu di atas, tanpa bingkai Windows. | F01 | Desktop terlihat melalui seluruh bagian kosong overlay; tidak ada title bar/border; overlay tetap di atas jendela biasa. |
| F03 | P0 | Bentuk notch ringkas | Gambar pill hitam bersudut membulat pada tengah tepi atas layar utama. | F02 | Posisi tetap di tengah setelah aplikasi dibuka; ukuran awal konsisten; hanya area pill yang tampak gelap. |
| F04 | P0 | Hit test area kosong | Teruskan klik pada bagian transparan overlay ke aplikasi di belakangnya melalui penanganan `WM_NCHITTEST`. | F02, F03 | Klik di luar pill mengaktifkan kontrol aplikasi di bawah; klik di dalam pill diterima notch. |
| F05 | P0 | Buka dan tutup notch | Ubah pill antara keadaan ringkas dan terbuka saat hover atau klik, lalu tutup lagi saat pointer keluar atau klik ulang. | F03, F04 | Hover dan klik masing-masing membuka panel; keluar/klik ulang menutupnya; area interaktif mengikuti ukuran visual di kedua keadaan. |
| F06 | P0 | Animasi perubahan ukuran | Animasikan transisi ringkas–terbuka dengan Storyboard tanpa menahan thread UI. | F05 | Transisi terlihat mulus pada monitor 60 Hz; input dashboard dan klik desktop tetap responsif selama animasi; tidak ada loncatan posisi di tengah atas. |
| F07 | P0 | Jam sistem | Tampilkan waktu lokal sistem pada notch dan perbarui saat menit berganti. | F05 | Waktu sesuai jam Windows; berubah tanpa membuka ulang aplikasi; tampilan tetap masuk akal sesudah sistem bangun dari sleep. |
| F08 | P0 | Status baterai | Tampilkan persentase dan status pengisian bila Windows menyediakan baterai. | F05 | Persentase/status sesuai sistem dan diperbarui; pada desktop tanpa baterai modul menampilkan status tidak tersedia atau disembunyikan tanpa error. |
| F09 | P0 | Info media | Baca sesi media aktif melalui Global System Media Transport Controls dan tampilkan judul/artis yang tersedia. | F05 | Lagu/sesi aktif tampil dan berubah saat sesi berganti; bila tidak ada sesi, tampilkan keadaan kosong yang jelas tanpa metadata lama. |
| F10 | P0 | Kontrol media dasar | Sediakan play/pause, sebelumnya, dan berikutnya untuk sesi media aktif jika didukung. | F09 | Tombol yang didukung mengendalikan sesi aktif; tombol yang tidak didukung dinonaktifkan; kegagalan/kehilangan sesi tidak membuat aplikasi berhenti. |
| F11 | P0 | Ikon tray dan siklus hidup | Jalankan aplikasi dari tray, buka dashboard lewat menu klik kanan, dan sediakan Exit. | F01 | Ikon tray hadir saat aplikasi berjalan; menu membuka satu dashboard; menutup dashboard tidak mematikan overlay; Exit menutup jendela dan proses. |
| F12 | P0 | Dashboard pengaturan dasar | Sediakan satu halaman pengaturan dengan kontrol ukuran, warna, dan status modul. | F01, F11 | Dashboard dapat dibuka dari tray; kontrol memiliki label dan nilai/keadaan yang terbaca; navigasi keyboard dasar berfungsi. |
| F13 | P0 | Ukuran dan radius | Ubah lebar, tinggi, dan radius sudut notch melalui slider. | F03, F12 | Tiap slider mengubah pill segera; batas mencegah ukuran di luar layar atau radius tidak valid; area hit test tetap sesuai bentuk baru. |
| F14 | P0 | Warna latar notch | Ubah warna latar pill melalui color picker. | F03, F12 | Pilihan warna langsung tampak pada pill; area transparan di luar pill tetap transparan. |
| F15 | P0 | Sakelar modul | Aktifkan/nonaktifkan jam, baterai, dan media secara terpisah dari dashboard. | F07, F08, F09, F12 | Setiap sakelar hanya memengaruhi modulnya; modul yang dimatikan tidak menyisakan teks/kontrol lama; layout menyesuaikan tanpa overlap. |
| F16 | P0 | Simpan preferensi lokal | Simpan ukuran, radius, warna, dan sakelar modul ke data aplikasi lokal lalu pulihkan saat mulai. | F13, F14, F15 | Setelah aplikasi benar-benar ditutup dan dibuka ulang, semua nilai sama; data hilang/rusak kembali ke default aman tanpa crash. |
| F17 | P1 | Pemulihan posisi dan DPI | Reposisikan notch saat resolusi, DPI, atau layar utama berubah. | F03, F13 | Notch tetap berada di tengah tepi atas layar utama setelah perubahan display yang didukung, tanpa harus membuka ulang aplikasi. |
| F18 | P1 | Preferensi animasi sederhana | Beri satu pilihan mengurangi atau menonaktifkan animasi untuk kebutuhan aksesibilitas. | F06, F12, F16 | Saat dikurangi, perpindahan keadaan tetap jelas tanpa animasi penuh; pilihan tersimpan. |

## Urutan pengiriman

1. **Fondasi MVP:** F01 → F02 → F03 → F04. Buktikan overlay benar-benar transparan dan tidak menghalangi desktop sebelum menambah konten.
2. **Interaksi MVP:** F05 → F06. Pastikan keadaan ringkas/terbuka dan hit test bekerja bersama.
3. **Konten MVP:** F07 → F08 → F09 → F10. Modul tetap dapat diuji sendiri-sendiri; F09 diperlukan sebelum kontrol media.
4. **Pengaturan MVP:** F11 → F12 → F13/F14/F15 → F16. Simpan hanya preferensi yang sudah nyata di dashboard.
5. **Tahap berikutnya:** terima F17 dan F18 di Windows setelah MVP; source awal untuk keduanya sudah ada. Fitur lain memerlukan keputusan produk tersendiri.

## Gerbang penerimaan MVP

- Uji di Windows target bahwa overlay tidak memiliki chrome, transparan di luar pill, tetap di atas, dan klik di luar pill mencapai aplikasi lain.
- Uji hover, klik, transisi, dan penggunaan dashboard bersama; animasi menargetkan frame 60 Hz (sekitar 16,7 ms per frame) dan tidak memblokir input. Pengukuran FPS harus dilakukan pada perangkat Windows target, bukan disimpulkan dari mockup.
- Uji jam, baterai tersedia/tidak tersedia, media aktif/tidak aktif, serta kontrol media yang didukung/tidak didukung.
- Uji perubahan seluruh pengaturan dan pemulihan setelah proses aplikasi dimulai ulang, baik jalur MSIX maupun unpackaged/installer bila keduanya didistribusikan.
- Simpan hasil build, instalasi, dan smoke run yang dapat ditelusuri. Laporan pengguna bahwa aplikasi dapat dijalankan tidak menutup uji transparansi, media, performa, dan kasus tepi di atas.

## Batas MVP

Mockup juga memperlihatkan banyak layar, multi-display, preset animasi, gesture touchpad, widget cuaca/fokus, metrik runtime, dan pembaruan aplikasi. Itu adalah referensi arah desain, bukan kebutuhan yang disahkan di matriks ini. MVP hanya mengandalkan tiga modul yang diminta; halaman navigasi tambahan yang sudah dibuat tidak berarti widget atau integrasi lain telah ada. Item mockup lainnya belum masuk backlog implementasi sampai kebutuhan dan kriteria penerimaannya ditetapkan.
