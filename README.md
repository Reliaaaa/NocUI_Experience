# NotchUI

NotchUI adalah prototipe aplikasi desktop Windows yang menempatkan notch interaktif di tengah tepi atas layar utama. Target produk adalah C# 12, .NET 8, WinUI 3, dan Windows App SDK; kebutuhan awal ada di [PRD](attachments/e03c4d15-6ae7-4021-9794-4ddf76fe9aac/product_requirements_document.txt), sedangkan cakupan MVP ada di [fitur](docs/01-features.md).

## Status saat ini

Repository ini memuat model pengaturan, codec dan penyimpanan `ApplicationData.LocalSettings`, layanan jam/baterai/media, adapter Win32 untuk overlay dan tray, serta proyek self-check codec. **Aplikasi belum dapat dijalankan atau dikemas:** proyek aplikasi WinUI, bootstrap, XAML dashboard/overlay, view model, dan manifest MSIX belum tersedia. Status verifikasi terperinci ada di [laporan QA](docs/06-qa-report.md).

## Pemeriksaan yang tersedia

Dengan .NET 8 SDK, jalankan:

```sh
dotnet run --project tests/NotchUI.Settings.SelfCheck/NotchUI.Settings.SelfCheck.csproj --configuration Release
```

Ini hanya memeriksa codec pengaturan dan tidak menguji WinUI, interop Win32, atau perilaku overlay. Lingkungan kerja ini belum memiliki `dotnet`, sehingga hasil pemeriksaan belum diklaim. Workflow Windows di `.github/workflows/windows-build.yml` menjalankan self-check; tahap paket akan aktif setelah `src/NotchUI/NotchUI.csproj` dan `src/NotchUI/Package.appxmanifest` ditambahkan.

## Dokumentasi

- [Fitur dan kriteria penerimaan](docs/01-features.md)
- [Arsitektur](docs/02-architecture.md)
- [Desain](docs/03-design.md)
- [Kontrak integrasi](docs/04-api.md)
- [Penyimpanan lokal](docs/05-database.md)
- [Laporan QA](docs/06-qa-report.md)
- [Build, CI, dan rilis](docs/08-devops.md)

Referensi visual HTML/gambar di `ui-reference/` adalah mockup, bukan aplikasi yang dapat dijalankan.
