# notch-windows — Tech Lead Review (Rilis 1 / MVP)

Status proyek: C# + WinUI 3, 9 project (`src/` + `tests/`), 59 file `.cs`. Tahap DevOps/GitHub **ditunda
atas permintaan pengguna** (kode tetap lokal untuk saat ini) — tidak memblokir keputusan rilis dokumen
ini, hanya menunda publikasi dan build CI nyata.

## Per agent

| Agent | Dokumen | Keputusan | Catatan |
|---|---|---|---|
| Project Manager | `01-features.md` | **LOLOS** | Fitur terkecil, P0/P1/P2, kriteria selesai jelas; MVP (F-001..F-050) sesuai scope yang diminta |
| Architect | `02-architecture.md` | **LOLOS** | Struktur 6+ project, MVVM+DI+Messenger, library+versi, konvensi penamaan — cukup detail untuk dikerjakan tanpa tanya |
| Designer | `03-design.md` | **LOLOS (dengan catatan)** | Canva tidak tersambung di sesi ini → wireframe teks/ASCII dipakai sebagai gantinya (sesuai aturan skill saat Canva tidak tersedia); desain token & state layar lengkap untuk fitur P0 |
| Services + Storage | `04-services.md`, `04-services-api.md`, `05-storage.md`, `05-database.md` | **LOLOS (setelah revisi)** | Desain awal (`04-services.md`/`05-storage.md`, LiteDB) berbeda dari implementasi akhir (`04-services-api.md`/`05-database.md`, Microsoft.Data.Sqlite+Dapper) — dua dokumen lama dipertahankan sebagai riwayat keputusan, dokumen `-api`/`05-database` adalah sumber kebenaran saat ini. Keputusan pivot LiteDB→SQLite masuk akal (hindari dependensi native tambahan) tapi **seharusnya didokumentasikan eksplisit sebagai ADR, bukan file paralel tanpa catatan migrasi** — item kebersihan dokumentasi, bukan blocker |
| QA | `06-qa-report.md` | **LOLOS** | 22 bug tercatat (QA-001..022), seluruh P0 blocker (build/run) tertutup termasuk 2 yang ditemukan+ditutup di siklus Tech Lead ini (QA-021 `INetworkService`, QA-022 `IWeatherService`); QA-018/019 (DPI, dock activate) juga sudah tertutup. **Build/test nyata belum pernah dijalankan** (sandbox tidak punya NuGet/Windows SDK) — ini keterbatasan lingkungan, bukan kegagalan proses QA, tapi tetap syarat wajib sebelum rilis publik |
| Security | `07-security.md` | **LOLOS** | Tidak ada Critical/High/Medium terbuka. SEC-001 (HttpClient timeout) ditutup langsung dalam siklus ini; SEC-002 ternyata bukan bug (validasi sudah ada); SEC-003/004 adalah syarat proses Rilis 2/CI, bukan blocker kode |
| DevOps | — | **DITUNDA (atas permintaan pengguna)** | Tidak ada repo GitHub dipilih; `08-devops.md` belum ditulis. Lihat §Risiko |

## Perbaikan yang dilakukan dalam siklus review ini (sebelum LOLOS)

1. **QA-021 (P0)** — `INetworkService` ditulis ulang supaya cocok dengan `NetworkToggleService` (satu-satunya implementasi) dan `QuickToggleService` (satu-satunya pemanggil): `GetWiFiStateAsync/GetBluetoothStateAsync` (→`ToggleState`) menggantikan `IsWifiEnabledAsync`/`IsBluetoothEnabledAsync`(bool); anggota mic-mute/lock dihapus dari interface ini (bukan tanggung jawabnya, sudah ditangani langsung di `QuickToggleService`).
2. **QA-022 (P0)** — `IWeatherService.GetCurrentAsync` disamakan ke `Task<WeatherSnapshot?>` (tipe yang sungguh dipakai `WeatherService` dan `DashboardViewModel`), menggantikan `Task<WeatherInfo>` yang tidak pernah cocok dengan implementasi maupun pemanggil.
3. **SEC-001** — `HttpClient` untuk `WeatherService` diberi `Timeout = TimeSpan.FromSeconds(10)` eksplisit di composition root (`App.xaml.cs`), menggantikan default 100 detik.

Ketiganya divalidasi dengan membaca ulang seluruh rantai interface→implementasi→pemanggil (bukan hanya
file yang diedit) untuk memastikan tidak ada pemanggil lain yang bergantung pada signature lama — tidak
ditemukan.

## Konsistensi lintas desain/API/database

- **Desain ↔ kode**: token tema (dark/glass, pill notch, rounded dock) di `03-design.md` konsisten
  dengan nama kelas/namespace kode (`WindowStyler`, `NotchGeometry`, dock bar) — tidak ditemukan
  penyimpangan.
- **Services ↔ Storage**: `IWeatherService`/`INetworkService`/`IMusicService`/`IQuickToggleService`/
  `IDockService`/`ISettingsStore`/`INotchPositionService` — seluruhnya diverifikasi ulang satu per satu
  di siklus ini (bukan hanya dipercaya dari laporan QA sebelumnya): signature interface = signature
  implementasi nyata, dan konstruktor yang menerima interface itu (`QuickToggleService`,
  `DashboardViewModel`) memakainya sesuai kontrak final.
- **`ILocalStore`** (Core/Abstractions) tidak punya implementasi maupun registrasi DI — dead
  interface, tidak memblokir build (tidak di-inject ke mana pun). **Rekomendasi**: hapus di Rilis 2 atau
  jadikan abstraksi resmi untuk `NotchDbContext`/`TodoRepository` supaya tidak ada abstraksi yang
  menggantung tanpa pemakai — dicatat juga di `06-qa-report.md` §5.

## Pola proses yang berulang (disebut QA & Services sebelumnya, dikonfirmasi di sini)

Tiga kali ditemukan (`App`↔`Interop` project reference QA-012, data layer QA-014, Win32 interop
duplikat QA-017) dan dua kali lagi dalam siklus ini (QA-021, QA-022): **interface Core ditulis terpisah
dari implementasi Services tanpa rekonsiliasi**, lalu bug baru ditemukan tiap kali ditinjau ulang alih-alih
sekali tuntas. Pola ini sudah berhenti berulang di siklus terakhir (QA-021/022 ditemukan DAN ditutup
dalam satu putaran yang sama, tidak dibiarkan terbuka lagi) — tapi **disarankan proses ke depan**: setiap
interface baru di `Core/Abstractions` ditulis BERSAMA implementasi pertamanya (satu PR/commit), bukan
oleh agent yang berbeda di waktu berbeda tanpa saling membaca kode satu sama lain.

## Risiko yang tersisa

1. **Build/test nyata belum pernah dijalankan** — seluruh verifikasi di proyek ini bersifat tinjauan
   statis (baca kode) karena sandbox tanpa akses NuGet/Windows SDK. Risiko: bug kompilasi lain yang
   tidak terlihat dari pembacaan kode (mis. ambiguitas overload, directive `using` yang hilang) bisa saja
   masih ada. **Mitigasi**: jalankan `dotnet build`/`dotnet test` di mesin Windows atau GitHub Actions
   Windows runner SEBELUM rilis publik — ini syarat keras, bukan saran.
2. **DevOps ditunda** — tidak ada repo GitHub, tidak ada CI, tidak ada cara otomatis menjalankan risiko
   #1 sampai pengguna memilih repo. Kode aman tersimpan lokal di `/home/claude/notch-windows/`.
3. **Fitur di luar scope MVP** (Control Center penuh, Calendar, Todo/Notes/Pomodoro UI nyata — skema DB
   sudah ada tapi UI belum, Snap Zones, notification mirror, AI chat, prayer times, clipboard manager,
   dll) tetap di backlog `01-features.md`, belum dikerjakan — sesuai scope iterasi pertama yang diminta
   pengguna di awal, bukan risiko baru.
4. **Dua pasang dokumen Services/Storage yang tidak sinkron** (`04-services.md` vs `04-services-api.md`;
   `05-storage.md` vs `05-database.md`) — sudah dicatat di atas sebagai item kebersihan dokumentasi,
   disarankan digabung/diberi catatan "superseded by" sebelum dokumen ini dibagikan ke orang baru di tim.

## Keputusan akhir

**Rilis 1 (MVP) LOLOS tinjauan Tech Lead** untuk sisi kode, desain, dan keamanan, dengan syarat keras
risiko #1 (build nyata) ditutup sebelum rilis publik ke pengguna akhir. Tidak ada agent yang perlu
mengulang pekerjaan (0 dari maksimal 3 putaran terpakai untuk pengembalian pekerjaan — seluruh
perbaikan di siklus ini dilakukan langsung sebagai bagian review, bukan dikembalikan ke agent asal).
