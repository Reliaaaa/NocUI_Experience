# notch-windows — DevOps (ditunda)

Status: **ditunda atas permintaan pengguna** (lihat `09-review.md` §Risiko #2). Kode tersimpan lokal di
`/home/claude/notch-windows/` (9 project C#, 59 file), belum didorong ke GitHub mana pun.

## Yang perlu diputuskan saat dilanjutkan

1. **Nama & visibilitas repo** — baru atau yang sudah ada, public atau private.
2. **Strategi branch**: `main` + branch kerja per rilis (`release/1.0-mvp`), sesuai aturan skill
   fullstack-app-team.
3. **Packaging**: MSIX (lewat Windows Application Packaging Project) vs unpackaged Win32 (`app.manifest`
   saat ini sudah unpackaged, `asInvoker`) — menentukan isi workflow build & cara distribusi installer.

## Rencana workflow GitHub Actions (siap dieksekusi begitu repo dipilih)

- `windows-build.yml` — berjalan di `windows-latest` runner (WAJIB Windows, bukan Linux, karena WinUI3/
  Windows App SDK tidak bisa dikompilasi di luar Windows — lihat keterbatasan sandbox di
  `06-qa-report.md` §0): `dotnet restore`, `dotnet build -c Release`, `dotnet test`, plus
  `dotnet list package --vulnerable --include-transitive` (menutup SEC-004 di `07-security.md`), unggah
  hasil build sebagai artifact.
- Rahasia (jika Rilis 2 menambah code-signing certificate untuk auto-update, sesuai README Poni "Every
  update is signed") disimpan di GitHub Secrets, tidak pernah di-commit.
- Komentar status build/test ke commit atau PR (format: status, run number+link log, versi/branch/SHA,
  ringkasan tes, penyebab+langkah perbaikan bila gagal) — sesuai aturan pelaporan skill
  fullstack-app-team, dijalankan begitu GitHub tersambung.

## Cara melanjutkan

Beri tahu Claude nama repo GitHub (baru atau yang sudah ada) kapan saja; tahap ini akan dilanjutkan dari
titik ini tanpa mengulang kerja sebelumnya.
