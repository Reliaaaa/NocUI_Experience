<div align="center">

# NocUI Experience

**Notch interaktif untuk Windows yang dirancang agar informasi dan kontrol penting tetap mudah dijangkau.**

Antarmuka minimalis, animasi responsif, dan widget yang dapat disesuaikan—dalam satu ruang ringkas di bagian atas layar.

![Version](https://img.shields.io/badge/version-1.1.1-blue)
[![Windows build](https://github.com/Reliaaaa/NocUI_Experience/actions/workflows/flutter-windows.yml/badge.svg?branch=feature)](https://github.com/Reliaaaa/NocUI_Experience/actions/workflows/flutter-windows.yml)
![Platform](https://img.shields.io/badge/platform-Windows%20x64-0078D4)
![Flutter](https://img.shields.io/badge/Flutter-Windows-02569B?logo=flutter&logoColor=white)
![License](https://img.shields.io/badge/license-MIT%20planned-lightgrey)

**Status: Full Release · Version 1.1.1**

</div>

---

## 📖 Tentang Proyek

NocUI Experience adalah aplikasi desktop Windows yang menghadirkan notch interaktif sebagai tempat melihat informasi dan mengakses kontrol tanpa membuka banyak jendela. Dalam keadaan ringkas, notch menampilkan informasi sekilas; ketika dibuka, pengguna dapat mengakses halaman dan pengaturan yang lebih lengkap.

Implementasi utama menggunakan Flutter untuk antarmuka dan C++ dengan API Windows untuk integrasi sistem. Source WinUI sebelumnya masih tersimpan sebagai referensi dan pemulihan, tetapi bukan jalur build utama.

> **Status pengujian:** build dan tes otomatis tidak membuktikan penerimaan runtime. Instalasi, animasi, fokus keyboard, media, transparansi, click-through, DPI, monitor, dan migrasi pengaturan masih perlu diuji pada Windows. Installer CI belum ditandatangani.

## 🚀 Fitur Utama

- **Notch interaktif** — tampilan ringkas dan terbuka dengan transisi berbasis spring.
- **Jam dan informasi sekilas** — waktu, tanggal, dan aktivitas yang relevan pada notch.
- **Kontrol media** — informasi dan kontrol sesi media Windows yang tersedia.
- **Halaman utilitas** — akses ke kalender, shortcut, media, shelf, timer, dan informasi sistem.
- **Personalisasi** — pengaturan tampilan, warna aksen, ukuran, animasi, dan perilaku notch.
- **Integrasi Windows** — system tray, pengaturan monitor, deteksi layar penuh, dan integrasi sistem lainnya.
- **Privasi berdasarkan pilihan** — cuaca, lokasi otomatis, pemantauan unduhan, clipboard, dan shortcut global tidak aktif secara default untuk pengaturan baru.

Ketersediaan dan perilaku fitur harus tetap diverifikasi pada perangkat Windows yang ditargetkan. Mengaktifkan cuaca dapat melakukan permintaan jaringan untuk data cuaca dan, jika dipilih, lokasi.

## 🛠️ Arsitektur & Teknologi

| Komponen | Teknologi / lokasi | Peran |
| --- | --- | --- |
| Antarmuka desktop | Flutter dan Dart di `flutter_app/lib/` | Tampilan notch, halaman, pengaturan, dan animasi. |
| Integrasi Windows | C++ / Win32 / WinRT di `flutter_app/windows/` | Jendela overlay, system tray, media, dan layanan sistem. |
| Pengujian | Flutter Test di `flutter_app/test/` | Pengujian otomatis logika dan komponen yang tersedia. |
| Packaging | Inno Setup di `installer/NocUIFlutter.iss` | Membuat installer Windows x64. |
| CI | GitHub Actions | Analisis, tes, build Windows, dan artifact installer. |
| Implementasi terdahulu | C# / WinUI 3 di `src/` | Referensi dan pemulihan; bukan build utama. |

Struktur utama repository:

```text
NocUI_Experience/
├── flutter_app/          # Aplikasi Flutter dan integrasi Windows
│   ├── lib/              # Antarmuka, state, layanan, dan pengaturan
│   ├── test/             # Pengujian Flutter
│   └── windows/          # Runner dan integrasi native Windows
├── installer/            # Skrip installer Inno Setup
├── .github/workflows/    # Workflow CI
├── docs/                 # Dokumen proyek dan catatan migrasi
└── src/                  # Implementasi WinUI terdahulu
```

## 📦 Memulai & Instalasi

### Persyaratan

- Windows x64 dengan dukungan desktop Flutter.
- Flutter SDK dengan Dart yang memenuhi batas versi pada [`pubspec.yaml`](flutter_app/pubspec.yaml) (`^3.12.2`).
- Visual Studio dengan workload **Desktop development with C++**, termasuk Windows SDK dan CMake.
- Git. Inno Setup 6 diperlukan jika Anda ingin membuat installer sendiri.

### 1. Clone repository

```bash
git clone https://github.com/Reliaaaa/NocUI_Experience.git
cd NocUI_Experience
```

### 2. Siapkan dependensi

```bash
cd flutter_app
flutter doctor -v
flutter pub get
```

Pastikan `flutter doctor -v` menunjukkan bahwa toolchain Windows tersedia sebelum melanjutkan.

### 3. Jalankan dalam mode pengembangan

```bash
flutter run -d windows
```

### 4. Jalankan pemeriksaan

```bash
flutter analyze
flutter test
```

### 5. Build aplikasi Windows

```bash
flutter build windows --release
```

Bundle hasil build berada di `flutter_app/build/windows/x64/runner/Release/`. Jalankan executable bersama seluruh isi folder tersebut; executable tidak berdiri sendiri tanpa file pendukungnya.

### 6. Unduh installer dari CI

Buka [GitHub Actions](https://github.com/Reliaaaa/NocUI_Experience/actions), pilih run **Windows build and package** yang berhasil untuk commit yang ingin diuji, lalu unduh artifact `nocui-experience-installer-x64`. Ekstrak ZIP dan jalankan installer di dalamnya. Artifact merupakan hasil CI untuk pengujian, bukan jaminan rilis siap pakai.

## 💻 Penggunaan & Konfigurasi

Jalankan aplikasi, lalu gunakan notch atau ikon system tray untuk mengakses fitur dan pengaturan. Di Settings, sesuaikan tampilan, animasi, halaman, dan perilaku sesuai kebutuhan. Shortcut global dapat dikonfigurasi oleh pengguna dan tidak diaktifkan secara default untuk pengaturan baru.

Contoh preferensi yang dapat dipilih melalui Settings:

```text
Tampilan       : mengikuti tema sistem
Aksen          : teal
Animasi        : intensitas sesuai preferensi
Cuaca/lokasi   : nonaktif sampai diaktifkan
Shortcut global: belum ditetapkan
```

Pengaturan Flutter disimpan di `%APPDATA%\NocUIExperience`. Saat migrasi dari aplikasi WinUI unpackaged, aplikasi mencoba mengimpor status media dan preferensi animasi nol tanpa mengubah file lama. Pengaturan lain dan `LocalSettings` MSIX belum dimigrasikan; lihat [catatan migrasi](docs/flutter-migration.md).

Jika versi WinUI lama masih berjalan, tutup aplikasi tersebut sebelum menjalankan Flutter untuk menghindari dua notch aktif sekaligus. Mengubah pengaturan dan menjalankan aplikasi membutuhkan pengujian pada sistem Anda; jangan menganggap hasil CI sebagai pengganti pengujian runtime.

## 📸 Pratinjau Visual

> **Placeholder:** tambahkan screenshot hasil build NocUI Experience terbaru di sini setelah tampilan diverifikasi pada Windows.

```markdown
![Notch ringkas dan terbuka](docs/screenshots/nocui-notch.png)
![Pengaturan NocUI Experience](docs/screenshots/nocui-settings.png)
```

Jalur gambar di atas adalah contoh dan belum menyatakan bahwa file screenshot tersebut tersedia.

## 🤝 Panduan Kontribusi

Kontribusi berupa laporan bug, perbaikan dokumentasi, pengujian, dan perubahan kode sangat dihargai.

1. Periksa issue yang ada atau jelaskan perubahan yang ingin dikerjakan.
2. Gunakan alur branch yang disepakati pengelola: `feature → dev → main`.
3. Pertahankan perubahan tetap terfokus dan sertakan penjelasan perilaku sebelum dan sesudahnya.
4. Jalankan `flutter analyze` dan `flutter test`; sertakan hasil build dan pengujian Windows yang relevan.
5. Ajukan pull request ke branch tujuan yang disepakati, lengkap dengan batas pengujian dan screenshot untuk perubahan visual.

Jangan sertakan data pribadi, token, atau file pengaturan pengguna dalam commit maupun laporan.

## 🐛 Pelaporan Masalah

Buka [GitHub Issues](https://github.com/Reliaaaa/NocUI_Experience/issues) dan sertakan:

- Versi Windows, skala layar, jumlah monitor, serta versi atau commit aplikasi.
- Langkah reproduksi dan perilaku yang diharapkan dibandingkan hasil aktual.
- Jenis paket yang digunakan: portable atau installer.
- Screenshot, rekaman, atau log yang relevan setelah informasi pribadi dihapus.

## 📜 Lisensi

Lisensi MIT adalah pilihan yang dinyatakan untuk proyek ini. File `LICENSE` belum tersedia di repository; ketentuan distribusi dan lisensi source serta dependensi pihak ketiga perlu dipastikan sebelum proyek dinyatakan berlisensi atau didistribusikan di bawah MIT.

---

<div align="center">

Dibuat dengan ❤️ oleh **Reliaaaa**.

</div>
