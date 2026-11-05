# NotchUI

NotchUI adalah prototipe aplikasi desktop Windows yang menempatkan notch interaktif di tengah tepi atas layar utama. Source menggunakan C# 12, .NET 8, WinUI 3, Windows App SDK, dan interop Win32. Cakupan MVP ada di [fitur](docs/01-features.md).

## Status saat ini

Repository sudah memuat proyek aplikasi WinUI, dashboard dan overlay XAML, service, manifest MSIX, proyek self-check pengaturan, serta konfigurasi build Windows. Pengguna pernah melaporkan aplikasi berjalan di Windows; laporan itu belum membuktikan build, instalasi, dan seluruh kriteria penerimaan untuk perubahan source saat ini. Lihat [laporan QA](docs/06-qa-report.md).

## Mulai memeriksa dan membangun

Pada mesin dengan .NET 8 SDK, jalankan pemeriksaan codec dan penyimpanan pengaturan:

```sh
dotnet run --project tests/NotchUI.Settings.SelfCheck/NotchUI.Settings.SelfCheck.csproj --configuration Release
```

Self-check tidak menjalankan UI WinUI, integrasi WinRT, atau interop Win32. Build dan pengujian aplikasi memerlukan Windows x64 versi 10 build 19041 atau lebih baru, .NET 8 SDK dan toolchain WinUI/MSIX. Workflow [Windows build and package](.github/workflows/windows-build.yml) menjalankan self-check, membuat MSIX **unsigned**, lalu menerbitkan aplikasi portable dan merakit installer Inno Setup. Artefak CI belum siap didistribusikan sebagai rilis: signature, instalasi, dan perilaku Windows perlu diverifikasi. Perintah, prasyarat dan prosedur rilis ada di [panduan DevOps](docs/08-devops.md).

Lingkungan pemeriksaan repository ini tidak menyediakan `dotnet` atau Windows; belum ada klaim bahwa build dan self-check terbaru berhasil dijalankan di sini.

## Dokumentasi

- [Fitur dan kriteria penerimaan](docs/01-features.md)
- [Arsitektur](docs/02-architecture.md)
- [Desain](docs/03-design.md)
- [Kontrak integrasi](docs/04-api.md)
- [Penyimpanan lokal](docs/05-database.md)
- [Laporan QA](docs/06-qa-report.md)
- [Build, CI, dan rilis](docs/08-devops.md)

Referensi visual HTML/gambar di `ui-reference/` adalah mockup, bukan aplikasi yang dapat dijalankan.
