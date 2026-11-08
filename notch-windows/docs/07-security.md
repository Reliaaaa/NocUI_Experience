# notch-windows — Security Review (Rilis 1 / MVP)

Ditinjau secara manual (statis, baca kode) — sandbox ini tidak bisa menjalankan `dotnet build`/analyzer
keamanan .NET nyata (lihat keterbatasan di `06-qa-report.md` §0). Codex Security (plugin) tidak
tersambung di sesi ini. Tinjauan memakai kerangka OWASP relevan untuk desktop app (OWASP Desktop App
Security Top 10 secara konsep, plus elemen OWASP API Top 10 untuk pemanggilan HTTP keluar) karena app
ini client-only, tidak ada backend/API server sendiri untuk MVP.

## Ringkasan

**Tidak ditemukan temuan Critical atau High yang terbuka.** Permukaan serangan MVP relatif kecil: tidak
ada server sendiri, tidak ada input dari pengguna lain/jaringan yang tidak tepercaya, satu-satunya
komunikasi keluar adalah ke Open-Meteo (publik, tanpa kredensial). Beberapa temuan Medium/Low dicatat di
bawah sebagai perbaikan sebelum rilis, tidak memblokir.

## 1. Rahasia & kredensial di kode

- **Tidak ditemukan** API key, password, token, atau connection string hardcoded di `src/` (disapu
  dengan pola `api[_-]?key|secret|password|token\s*=\s*"`, nihil hasil).
- Open-Meteo (`WeatherService`) tidak butuh API key sama sekali — tidak ada kredensial untuk bocor.
- Fitur Rilis 2 yang akan butuh kredensial (Google Calendar OAuth, AI provider API key) **belum
  diimplementasikan** di MVP ini. Dicatat sebagai syarat wajib sebelum fitur itu masuk: token/API key
  HARUS disimpan lewat Windows DPAPI (`System.Security.Cryptography.ProtectedData`,
  `DataProtectionScope.CurrentUser`), bukan di `settings.json` plaintext — `05-storage.md`/`05-database.md`
  belum secara eksplisit mewajibkan ini untuk field kredensial masa depan, **Tech Lead sebaiknya
  menambahkannya sebagai aturan desain sebelum Rilis 2 dimulai.**

## 2. Izin & execution level (Windows)

- `app.manifest`: `requestedExecutionLevel level="asInvoker" uiAccess="false"` — **benar**, app tidak
  minta admin. Semua fitur MVP (baca sensor via `PerformanceCounter`/WMI, toggle radio
  `Windows.Devices.Radios`, baca SMTC, baca/tulis registry `HKCU\...\Personalize`, Core Audio mic mute)
  tidak butuh privilese admin — konsisten dengan README fitur publik Poni ("no admin or driver needed").
- Tidak ditemukan deklarasi capability App Identity/MSIX (`Package.appxmanifest`) di solution — project
  masih unpackaged (Win32 classic `app.manifest`). **Ini bukan bug**, tapi berarti capability sensitif
  (mis. `location` untuk Wi-Fi listing — dicatat di README Poni sebagai kebutuhan Windows 11) belum relevan
  untuk MVP ini (dashboard Wi-Fi MVP hanya toggle radio, bukan list jaringan — itu Rilis 2+). Dicatat untuk
  DevOps: pemilihan packaged (MSIX) vs unpackaged menentukan model capability di rilis mendatang.

## 3. Proses eksternal (`Process.Start`)

Dua pemanggilan ditemukan, keduanya risiko rendah:

| Lokasi | Tujuan | Risiko |
|---|---|---|
| `Services/System/QuickToggleService.cs` fallback `LockPcAsync` | `rundll32.exe user32.dll,LockWorkStation` — hanya dipanggil bila P/Invoke `LockWorkStation()` langsung gagal | Rendah — argumen hardcoded (bukan dari input pengguna), `UseShellExecute=true` tanpa interpolasi string |
| `Services/Dock/RunningAppsService.cs` `LaunchOrActivateAsync` | `Process.Start(item.ExecutablePath)` untuk item yang di-pin pengguna sendiri | Rendah — path berasal dari pilihan pengguna sendiri (pin app miliknya), bukan dari sumber tak tepercaya/jaringan; tetap disarankan validasi `File.Exists` sebelum start (belum ada — **Low**, tambahkan supaya error lebih jelas daripada `Win32Exception` mentah ke UI) |

Tidak ditemukan pemanggilan shell dengan string yang digabung dari input eksternal (tidak ada pola
command injection klasik).

## 4. Komunikasi jaringan keluar

- `WeatherService` → `api.open-meteo.com` lewat `HttpClient` biasa, HTTPS, **tidak ada**
  `ServerCertificateCustomValidationCallback`/`DangerousAcceptAny...` yang melemahkan validasi TLS (disapu,
  nihil hasil) — validasi sertifikat default .NET dipakai, baik.
- **Low**: `HttpClient` di `WeatherService` tidak men-set `Timeout` eksplisit (default `HttpClient` 100
  detik) — untuk app UI yang menunggu respons untuk render dashboard, ini lebih lama dari wajar;
  sarankan `Timeout = TimeSpan.FromSeconds(10)` plus `CancellationTokenSource` yang sudah ada di
  signature (`ct` parameter) benar-benar diteruskan ke `HttpClient.GetAsync(url, ct)` — **perlu
  diverifikasi saat build nyata bahwa `ct` tidak diabaikan** (tidak terbaca penuh di tinjauan ini, catat
  untuk QA siklus berikut).
- Tidak ada data pengguna yang dikirim ke Open-Meteo selain koordinat lat/lon hardcoded sementara
  (`-6.2, 106.8` di `DashboardViewModel` — Jakarta, placeholder) — **tidak masalah keamanan**, tapi
  dicatat sebagai item fungsional (lokasi harus dari pengaturan pengguna/deteksi, bukan hardcoded) untuk
  `01-features.md` F-021, bukan temuan security.

## 5. Penyimpanan data lokal

- `settings.json` (`%AppData%\NotchWindows`): preferensi non-sensitif (posisi notch, tema, hotkey, daftar
  app pin). **Tidak ada data sensitif di MVP ini** (tidak ada password/token di struktur yang didokumentasikan
  `05-storage.md`) — penyimpanan plaintext dapat diterima untuk data ini.
- `notch.db` (SQLite via `Microsoft.Data.Sqlite`): skema MVP (`SchemaVersion`, `Settings`, `DockPins`) juga
  tidak berisi data sensitif. Todo/Notes (Rilis 2) berisi data pribadi pengguna tapi bukan kategori
  "sensitif" standar (kredensial/kesehatan/finansial) — enkripsi at-rest **tidak wajib** untuk MVP,
  tapi dicatat sebagai pertimbangan Tech Lead untuk Rilis 2 jika Notes dipakai menyimpan hal sensitif
  pengguna (README Poni menyebut Notes/flashcards, bukan data sensitif per definisi).
- Tidak ditemukan enkripsi (DPAPI) diterapkan di mana pun saat ini — **konsisten dengan tidak adanya
  data sensitif di MVP**, bukan temuan terbuka untuk rilis ini. Wajib ditambahkan sebelum fitur
  kredensial (Calendar OAuth, AI API key) masuk — lihat §1.

## 6. Dependensi (supply chain)

- Tidak bisa dijalankan `dotnet list package --vulnerable` di sandbox ini (tidak ada akses NuGet, lihat
  `06-qa-report.md` §0). Daftar versi di `Directory.Packages.props` terlihat wajar (CommunityToolkit.Mvvm
  8.2.2, Microsoft.Extensions.* 9.0.0, dll — rilis stabil, bukan versi pre-release/dev yang tidak jelas
  asalnya). **Wajib dijalankan `dotnet list package --vulnerable --include-transitive` di CI/mesin Windows
  sebelum rilis** — tambahkan sebagai langkah di workflow DevOps (`08-devops.md`).

## 7. Interop Win32/COM (permukaan unsafe code)

- `QuickToggleService` mendefinisikan interface COM Core Audio (`IMMDeviceEnumerator`,
  `IAudioEndpointVolume`) manual via `[ComImport]`/GUID publik Microsoft (didokumentasikan resmi
  `mmdeviceapi.h`/`endpointvolume.h`) — pola umum, bukan kode yang disalin dari aplikasi pihak ketiga
  manapun. Dibungkus `try/catch (COMException)` di kedua sisi baca/tulis — tidak ada unhandled exception
  yang bisa crash app dari kegagalan COM.
- P/Invoke lain (`WindowStyler`, `NotchInteropService`, `RunningAppsService.SetForegroundWindow`) memakai
  signature Win32 publik standar, sudah diperbaiki untuk pointer-size yang benar (`nint`, lihat QA-013) —
  tidak ditemukan buffer/marshaling tidak aman (tidak ada manipulasi pointer mentah ke buffer ukuran
  tetap yang rawan overflow).

## 8. Temuan & status

| ID | Severity | Lokasi | Temuan | Status |
|---|---|---|---|---|
| SEC-001 | Low | `App.xaml.cs` (registrasi `HttpClient`) | Tidak ada `HttpClient.Timeout` eksplisit; `ct` sudah diverifikasi diteruskan ke `GetFromJsonAsync` dengan benar | **Fixed** — `Timeout = TimeSpan.FromSeconds(10)` ditambahkan di registrasi DI |
| SEC-002 | Low | `RunningAppsService.LaunchOrActivateAsync` | Tidak ada `File.Exists` sebelum `Process.Start(item.ExecutablePath)` | **Sudah ada di kode** (`if (!string.IsNullOrEmpty(...) && File.Exists(...))`) — temuan awal keliru, divalidasi ulang, bukan bug nyata |
| SEC-003 | Info | Arsitektur kredensial Rilis 2 | DPAPI untuk token/API key Rilis 2 (Calendar OAuth, AI provider) belum dirancang eksplisit di dokumen | Open — rekomendasi desain sebelum Rilis 2 mulai |
| SEC-004 | Info | Supply chain | `dotnet list package --vulnerable` belum pernah dijalankan (keterbatasan sandbox) | Open — wajib di CI, lihat `08-devops.md` |

**Tidak ada temuan Critical/High/Medium terbuka.** SEC-001 ditutup langsung, SEC-002 ternyata bukan bug.
SEC-003/004 adalah syarat proses untuk tahap berikutnya (Rilis 2 dan pipeline CI), bukan blocker kode
Rilis 1. Rilis 1 (MVP) LOLOS tinjauan keamanan.
