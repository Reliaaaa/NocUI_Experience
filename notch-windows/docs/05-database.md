# notch-windows — Database lokal (SQLite)

Lokasi file: `%LOCALAPPDATA%\notch-windows\notch.db` (dibuat otomatis oleh `SqliteConnectionFactory`
bila belum ada). Satu file per user Windows, tidak ada server database — desktop single-user.

## Skema MVP (migrasi `001_Initial.sql`)

### `SchemaVersion`
| Kolom | Tipe | Keterangan |
|---|---|---|
| Version | INTEGER PK | Nomor migrasi yang sudah diterapkan |
| AppliedAtUtc | TEXT | Timestamp ISO-8601 UTC saat migrasi dijalankan |

### `Settings` (key-value, F-050)
| Kolom | Tipe | Keterangan |
|---|---|---|
| Key | TEXT PK | mis. `"AppSettings"` (satu baris JSON berisi seluruh `AppSettings`) |
| Value | TEXT | Nilai JSON/string |

Desain key-value generik dipilih agar menambah pengaturan baru tidak butuh migrasi skema — cukup field baru
di kelas `AppSettings` (Core), tetap tersimpan di baris JSON yang sama. Dock pin dipisah ke tabel sendiri
karena berbentuk daftar (bukan satu objek), lihat di bawah.

### `DockPins` (F-040, dock bar)
| Kolom | Tipe | Keterangan |
|---|---|---|
| Id | INTEGER PK AUTOINCREMENT | |
| AppUserModelId | TEXT UNIQUE | Identitas app Windows (AUMID) untuk launch/compare |
| DisplayName | TEXT | Nama tampilan di dock |
| IconPath | TEXT | Path ke ikon ter-cache/ekstrak dari app |
| SortOrder | INTEGER | Urutan tampil di dock, index: `IX_DockPins_SortOrder` |

## Migrasi

- File di `src/NotchWindows.Data/Migrations/`, format nama `NNN_Nama.sql` (mis. `001_Initial.sql`,
  `002_AddTodos.sql`), dijalankan urut ascending oleh `SqliteConnectionFactory.MigrateAsync()` saat startup.
- Idempotent: setiap migrasi dibungkus transaksi, nomor versi dicatat di `SchemaVersion` setelah sukses,
  migrasi yang sudah tercatat di-skip pada run berikutnya.
- **Tidak pernah mengubah file migrasi lama yang sudah dirilis** — perubahan skema selalu lewat file baru,
  supaya instalasi existing user bisa upgrade tanpa kehilangan data (lihat `01-features.md` F-120 Backup &
  Restore, yang bergantung pada skema stabil ini).
- Migrasi Rilis 2 yang sudah diantisipasi strukturnya (belum dibuat filenya, dikerjakan saat fitur mulai):
  - `002_AddDockTheming.sql` — kolom tema per dock (F-041/F-110)
  - `003_AddTodosNotes.sql` — tabel `Todos`, `Notes` (F-080, F-081)
  - `004_AddNotificationHistory.sql` — tabel `NotificationHistory` (F-100, lihat §Enkripsi)
  - `005_AddCalendarCache.sql` — cache event ICS yang sudah di-parse (F-070)

## Strategi offline & sinkronisasi
Aplikasi ini sepenuhnya lokal-first — tidak ada akun/server milik aplikasi sendiri. "Sinkronisasi" yang ada
hanya pemanggilan API publik stateless (cuaca) atau link yang user masukkan sendiri (ICS calendar, Rilis 2).
Tidak ada konflik multi-device untuk ditangani di MVP; `F-120 Backup & Restore` (Rilis 2) menangani pindah PC
lewat export/import file, bukan sinkronisasi real-time.

## Enkripsi data sensitif
- MVP: tidak ada data sensitif tersimpan (Settings MVP hanya preferensi UI, bukan kredensial).
- Saat fitur yang menyimpan data sensitif mulai dikerjakan (Rilis 2+):
  - **Notification history (F-100)**: isi notifikasi bisa berisi info pribadi → wajib dienkripsi per field
    dengan `System.Security.Cryptography.ProtectedData` (Windows DPAPI, `DataProtectionScope.CurrentUser`)
    sebelum disimpan ke kolom `NotificationHistory.ContentEncrypted`. DPAPI dipilih (bukan SQLCipher) karena
    kunci terikat ke akun Windows user secara otomatis, tanpa perlu app mengelola kunci sendiri — cocok untuk
    skenario desktop single-user, konsisten dengan keputusan Architect di `02-architecture.md` §6.
  - **API key pihak ketiga (backlog F-200 AI Chat/Translate)**: disimpan di tabel terpisah `SecureSecrets`
    (ditambah lewat migrasi saat F-200 mulai), nilai dienkripsi DPAPI sebelum `INSERT`, didekripsi hanya saat
    dipakai di memory, tidak pernah di-log (lihat `docs/07-services.md` §Catatan keamanan kunci API dan
    `docs/07-security.md` saat tahap Security Dev berjalan).
- Tidak ada kolom yang menyimpan password/token dalam bentuk plain text pada skema manapun — aturan ini
  berlaku permanen untuk semua migrasi berikutnya.
