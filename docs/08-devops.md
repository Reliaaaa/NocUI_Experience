# Build, CI, dan distribusi NotchUI

## Status dan batas verifikasi

Source memuat proyek WinUI 3 `src/NotchUI/NotchUI.csproj`, manifest MSIX `Package.appxmanifest`, dan skrip Inno Setup `installer/NocUIExperience.iss`. Workflow `.github/workflows/windows-build.yml` menjalankan self-check dan mencoba menghasilkan tiga artefak Windows x64. Inspeksi statis di lingkungan ini tidak membuktikan bahwa restore, build, installer, atau aplikasi berhasil dijalankan: `dotnet` dan toolchain Windows tidak tersedia. Lihat [laporan QA](06-qa-report.md) untuk status pengujian.

## Prasyarat

- Untuk self-check: .NET 8 SDK. Proyek ini menargetkan `net8.0` dan dapat dijalankan tanpa WinUI, tetapi hanya memeriksa codec dan penyimpanan pengaturan yang dicakup proyek uji.
- Untuk build aplikasi: Windows x64, Windows 10 build 19041 atau lebih baru (atau Windows 11), .NET 8 SDK, Visual Studio 2022 dengan workload pengembangan aplikasi Windows/WinUI dan alat MSIX, serta akses restore NuGet. Proyek menargetkan `net8.0-windows10.0.19041.0` dan memakai Windows App SDK `1.6.250205002`. Periksa dukungan SDK dan dependensi hasil restore sebelum rilis.
- Untuk installer lokal: Inno Setup 6 (`ISCC.exe`) dan isi publish portable di `artifacts/portable`. Workflow mengharapkan compiler di `%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe` pada runner `windows-2022`; job gagal jika tidak tersedia.
- Untuk rilis MSIX: identitas paket dan publisher yang final, sertifikat code signing yang dipercaya target, serta tempat aman untuk private key. Manifest source saat ini memakai `NotchUI.Desktop`, `CN=NotchUI`, dan versi `1.0.0.0`; nilai itu perlu diselaraskan dengan sertifikat dan strategi upgrade. Jangan simpan private key atau password dalam repository, log, maupun artefak CI.

## Pemeriksaan lokal dan CI

Jalankan self-check dari root repository:

```sh
dotnet run --project tests/NotchUI.Settings.SelfCheck/NotchUI.Settings.SelfCheck.csproj --configuration Release
```

Workflow berjalan pada push, pull request, dan `workflow_dispatch`, dengan izin `contents: read`. Job `self-check` menjadi prasyarat bagi job `package` dan `portable`. Tidak ada secrets yang dipakai workflow saat ini; signing dan publikasi rilis tidak dilakukan oleh CI.

| Job | Cara kerja | Artefak CI |
| --- | --- | --- |
| `self-check` | `dotnet run` konfigurasi Release pada runner `windows-2022` dengan .NET 8. | Tidak ada. |
| `package` | `dotnet msbuild -restore`, Release x64 / `win-x64`, `GenerateAppxPackageOnBuild=true`, bundle dimatikan, signing dimatikan. Job gagal jika tidak menemukan paket. | `notchui-unsigned-msix-x64` dari `artifacts/msix` (`.msix`/`.appx` dan kemungkinan bundle). |
| `portable` | `dotnet publish` Release `win-x64`, `--self-contained true`, `WindowsPackageType=None`; memastikan `NotchUI.exe` ada, lalu menjalankan `ISCC.exe` atas `installer/NocUIExperience.iss` dan memeriksa hasilnya. | `notchui-portable-x64` dari `artifacts/portable` dan `nocui-experience-installer-x64` dari `artifacts/installer/NocUI-Experience-Setup-x64.exe`. |

Untuk mereproduksi build, ikuti perintah dan properti persis di workflow. Portable dibuat sebelum installer karena skrip Inno menyalin seluruh `artifacts/portable` secara rekursif. Installer memasang ke `%LocalAppData%\Programs\NocUI Experience` per pengguna (`PrivilegesRequired=lowest`), mendukung Windows x64 build 19041+, dan menawarkan shortcut desktop opsional. Status sukses job menunjukkan artefak dibuat pada runner tersebut; status itu belum membuktikan instalasi maupun fungsi aplikasi.

## Validasi dan rilis

1. Jalankan self-check dan pastikan kedua job build berhasil pada runner Windows. Simpan nomor run, commit SHA, versi toolchain, dan hash artefak bersama catatan rilis agar paket yang diuji dapat diidentifikasi.
2. Pada Windows target sebagai pengguna biasa, pasang MSIX yang sudah ditandatangani dan uji portable serta installer secara terpisah. Uji startup, dashboard/tray/Exit, klik pada area transparan lintas proses, monitor/DPI, media, baterai, sleep/resume, persistensi setelah restart proses, serta uninstall. Ikuti matriks [fitur](01-features.md) dan [QA](06-qa-report.md). Self-check tidak menggantikan uji ini.
3. Untuk jalur MSIX, tetapkan identitas/publisher dan naikkan versi paket secara konsisten. Tanda tangani paket hasil build di proses rilis terkontrol menggunakan sertifikat yang cocok dengan publisher; verifikasi signature, trust chain, serta instalasi dan upgrade pada mesin target sebelum distribusi. MSIX unsigned dari CI hanya untuk inspeksi, bukan paket instalasi rilis.
4. Untuk jalur Inno, selaraskan `MyAppVersion` di `.iss` dengan versi aplikasi, tanda tangani `NocUI-Experience-Setup-x64.exe`, verifikasi signature dan konten installer, lalu uji instalasi serta upgrade per pengguna. Publish portable juga perlu keputusan kanal dan pemeriksaan integritas sebelum dibagikan. Workflow saat ini tidak menandatangani MSIX, EXE, atau installer dan tidak mengunggahnya ke kanal rilis.
5. Sebelum mengumumkan rilis, periksa dependensi langsung/transitif dan advisori pada restore Windows, manifest hasil build, serta hasil uji keamanan dan penerimaan yang masih terbuka. Simpan artefak versi sebelumnya yang telah diverifikasi untuk pemulihan.

## Rollback

Jika rilis gagal, hentikan distribusi artefak yang bermasalah dan arahkan pengguna ke versi terakhir yang telah lolos uji. Untuk MSIX, instalasi versi lebih rendah umumnya tidak dapat menimpa versi lebih tinggi dengan identitas yang sama: buat paket perbaikan dengan nomor versi lebih tinggi atau uninstall versi bermasalah sebelum memasang paket lama. Uji dampak uninstall terhadap data `ApplicationData.LocalSettings` dan cadangkan preferensi pengguna sebelum langkah yang dapat menghapusnya. Sertifikat/publisher harus tetap cocok untuk upgrade dalam identitas paket yang sama.

Untuk installer Inno, simpan EXE versi lama yang sudah ditandatangani; uji uninstall atau reinstall versi lama pada Windows sebelum memberi instruksi rollback. Installer ini menyalin file ke direktori per pengguna, sementara mode unpackaged menyimpan preferensi di `%LocalAppData%\NotchUI\settings.json`; jangan menghapus atau menimpa data itu tanpa rencana migrasi/pemulihan. Untuk portable, kembalikan seluruh isi direktori publish versi lama, bukan hanya `NotchUI.exe`. Pastikan proses sudah keluar sebelum mengganti file, kemudian uji startup dan preferensi kembali.

## Batas runtime Windows

MSIX dan portable adalah mode berbeda: proyek memakai `WindowsPackageType=MSIX` secara default dan `ApplicationData.LocalSettings` untuk packaged; publish `WindowsPackageType=None` menyertakan .NET serta Windows App SDK secara self-contained dan memakai file pengaturan di `%LocalAppData%\NotchUI\settings.json`. Build self-contained tetap membutuhkan API Windows yang sesuai dan tidak membuktikan perilaku overlay/tray di mesin target. Identitas paket, lokasi data, serta alur update kedua mode berbeda; uji masing-masing. CI belum melakukan uji GUI, HWND, tray, GSMTC, transparansi, hit test, signature, atau instalasi pada Windows nyata.
