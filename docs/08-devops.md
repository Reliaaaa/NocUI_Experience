# Build, CI, dan distribusi NotchUI

## Kondisi awal

Per 2026-11-04, hanya `tests/NotchUI.Settings.SelfCheck/NotchUI.Settings.SelfCheck.csproj` yang merupakan proyek .NET. Source di `src/NotchUI` belum mempunyai `NotchUI.csproj`, `App.xaml`, `MainWindow.xaml`, `OverlayWindow.xaml`, view model, atau `Package.appxmanifest`. Karena itu belum ada aplikasi yang dapat dibangun, MSIX yang dapat dikemas, atau hasil uji Windows yang bisa diklaim. Lingkungan kerja ini tidak menyediakan `dotnet` maupun toolchain Windows; pemeriksaan lokal terbatas pada inspeksi statis. Lihat juga `06-qa-report.md`.

## Prasyarat pengembang Windows

- Windows 10 build 19041 atau lebih baru, Visual Studio 2022 dengan workload pengembangan aplikasi Windows/WinUI dan alat MSIX, serta .NET 8 SDK.
- Proyek packaged WinUI 3 di `src/NotchUI/NotchUI.csproj` dengan target `net8.0-windows10.0.19041.0`, C# 12, dan `Package.appxmanifest` di folder yang sama. Kunci versi patch stabil Windows App SDK dan paket NuGet lain dalam proyek/lock file sebelum memakai pipeline sebagai gerbang rilis.
- Sertifikat tepercaya untuk distribusi MSIX. Sertifikat dan private key jangan dimasukkan ke repository.

## Langkah verifikasi

1. Jalankan `dotnet run --project tests/NotchUI.Settings.SelfCheck/NotchUI.Settings.SelfCheck.csproj --configuration Release` untuk codec pengaturan. Ini tidak memverifikasi WinRT atau aplikasi.
2. Sesudah shell WinUI ditambahkan, buka proyek pada Windows, pulihkan paket, lalu build konfigurasi Release x64. Pastikan hasil paket dihasilkan oleh proyek packaged, bukan sekadar DLL hasil kompilasi. Workflow `.github/workflows/windows-build.yml` mencoba membuat MSIX **unsigned** pada runner Windows bila proyek dan manifest ada; job gagal jika build mengaku sukses tetapi tidak ada paket.
3. Pasang build yang sudah ditandatangani dengan identitas sertifikat yang cocok, lalu uji kriteria penerimaan `01-features.md` dan kasus tepi di `06-qa-report.md` pada Windows nyata. Fokus pada transparansi dan click-through lintas proses, topmost/fokus, tray dan Exit, media, baterai, persistensi, serta animasi.

## Pipeline dan artefak

Workflow Windows berjalan pada push, pull request, dan pemicu manual. Job self-check aktif untuk keadaan repo saat ini. Job paket memeriksa keberadaan proyek aplikasi dan manifest; jika keduanya belum ada, langkah build/upload dilewati dan ringkasan job mencatat blocker. Setelah keduanya tersedia, runner menjalankan MSBuild Release x64 dengan `GenerateAppxPackageOnBuild=true` dan signing dimatikan, lalu mengunggah MSIX sebagai artefak CI sementara. Artefak unsigned itu adalah bahan inspeksi, **bukan installer siap rilis**. Periksa nama dan isi paket sebelum menggunakannya.

Untuk rilis, atur identitas paket/publisher di manifest, buat atau gunakan sertifikat yang dipercaya target, tandatangani paket pada proses rilis terkontrol, verifikasi signature serta instalasi, dan lakukan smoke test pada Windows target. Publikasi GitHub Release atau toko aplikasi memerlukan keputusan kanal distribusi dan otorisasi tersendiri; pipeline ini tidak memublikasikan apa pun. Jangan menaruh sertifikat atau password signing di source, log, atau artefak CI.

## Blocker sebelum rilis

- Shell packaged WinUI dan integrasi service belum ada; F01–F16 tidak dapat diterima end-to-end.
- Build dan self-check belum dieksekusi pada toolchain .NET 8/Windows dalam lingkungan ini.
- Uji manual Windows untuk HWND, tray, GSMTC, transparansi, hit test, dan performa belum dilakukan.
- Identitas paket, sertifikat signing, dan kanal distribusi belum ditetapkan.
