# notch-windows — Local Storage

Referensi: `01-features.md`, `02-architecture.md` §5. Semua data tersimpan lokal di `%AppData%\NotchWindows\` — tidak ada database server (selaras keputusan Architect: app client-only). Dua mekanisme penyimpanan dipakai sesuai jenis data: file `settings.json` untuk preferensi ringan, LiteDB (`data.db`) untuk data terstruktur yang tumbuh (todo, notes, cache kalender).

## 1. settings.json (F-050) — preferensi

Disimpan via `IJsonSettingsStore` (`NotchWindows.Services.Storage.JsonSettingsStore`), satu file flat, ditulis atomik (write ke temp file lalu `File.Replace` — hindari file korup jika app crash saat menulis).

```json
{
  "schemaVersion": 1,
  "notch": {
    "position": "TopCenterAttached",
    "displayMode": "PrimaryOnly",
    "closedLeftSlot": "Battery",
    "closedRightSlot": "Cpu",
    "autoHide": true,
    "autoHideWhenApps": []
  },
  "theme": { "mode": "Dark", "accentVariant": "Default" },
  "hotkey": { "toggleNotch": "Alt+N" },
  "dock": { "enabled": true, "pinnedApps": [] },
  "weather": { "mode": "Manual", "manualLat": null, "manualLon": null },
  "clock": { "use24Hour": true }
}
```

- **Migrasi**: field `schemaVersion` diperiksa saat load; `JsonSettingsStore` punya daftar `IReadonlyList<ISettingsMigration>` berurutan (mis. `MigrateV1ToV2`) yang transform `JsonNode` sebelum deserialize ke model final — pola sama seperti migrasi EF/LiteDB, supaya update app tidak mereset setting user.
- **Reaktif**: `JsonSettingsStore` expose `event EventHandler<SettingsChangedEventArgs> SettingsChanged` setelah tiap `SaveAsync()` berhasil — dipakai Messenger (`02-architecture.md` §2) untuk broadcast `SettingsChangedMessage` ke semua ViewModel lintas window tanpa restart app.
- **Validasi**: deserialize dibungkus try/catch — file korup/tidak valid JSON → fallback ke default settings + backup file korup ke `settings.corrupt.<timestamp>.json` (jangan menimpa diam-diam, user bisa lapor bug dengan file ini).

## 2. data.db (LiteDB) — Rilis 2+ (F-080 Todo, F-081 Notes, F-070 Calendar cache)

LiteDB dipilih (bukan SQLite relasional) karena: embedded single-file, tanpa native dependency rumit di WinUI3 packaging, schema-less cocok untuk model yang masih berubah antar rilis awal.

### Collections

```csharp
// collection: "todos"
public class TodoEntity
{
    public ObjectId Id { get; set; }
    public string Title { get; set; } = "";
    public DateTimeOffset? DueAt { get; set; }
    public RepeatRule? Repeat { get; set; }     // null = sekali saja
    public bool IsDone { get; set; }
    public DateTimeOffset? SnoozedUntil { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

// collection: "notes"
public class NoteEntity
{
    public ObjectId Id { get; set; }
    public string Title { get; set; } = "";
    public string Content { get; set; } = "";   // raw text; baris "Q :: A" di-parse saat mode flashcard dibuka
    public DateTimeOffset UpdatedAt { get; set; }
}

// collection: "calendar_cache"
public class CalendarEventEntity
{
    public string Uid { get; set; } = "";       // dari ICS UID, jadi _id
    public string SourceUrl { get; set; } = "";
    public string Title { get; set; } = "";
    public DateTimeOffset Start { get; set; }
    public DateTimeOffset End { get; set; }
    public string? JoinUrl { get; set; }
    public DateTimeOffset FetchedAt { get; set; }
}
```

### Index

- `todos`: index pada `DueAt` (query "todo mendatang" untuk countdown closed-notch, F-080) dan `IsDone` (filter cepat list aktif).
- `calendar_cache`: index pada `Start` (query "event hari ini/minggu ini" untuk tab bulan, F-070), unique constraint pada `Uid` (upsert, hindari duplikat saat re-fetch ICS).
- `notes`: tanpa index khusus di Rilis 2 (volume data kecil, full-scan cukup); tambahkan index teks jika fitur search notes masuk roadmap.

### Migrasi skema

- LiteDB schema-less → migrasi berarti transformasi field lama ke baru saat `EnsureIndex`/akses pertama, bukan ALTER TABLE SQL.
- Konvensi: tiap breaking change pada entity, tambah field `int EntityVersion` default sesuai versi saat ditulis; `LocalDatabase.OpenAsync()` jalankan langkah migrasi berurutan (mis. `if (doc["EntityVersion"] < 2) { ... }`) sebelum query normal dibuka ke caller.
- **Tes migrasi** (kriteria selesai QA, `01-features.md`): sediakan file `data.db` versi lama (fixture) di test project, jalankan migrasi, assert field baru terisi default yang benar dan data lama tidak hilang.

## 3. Backup & Restore (F-120, Rilis 2)

- Export: zip berisi `settings.json` + `data.db` (LiteDB sudah single-file, tinggal copy) + `notifications.enc` jika ada → nama file `NotchWindows-Backup-<timestamp>.nwbak`.
- Import: validasi `schemaVersion` tiap file di dalam zip dulu (jalankan migrasi bila perlu) sebelum menimpa data aktif — tampilkan konfirmasi "Ini akan mengganti semua data saat ini" di UI (Settings, lihat `03-design.md`).
- Kriteria selesai (`01-features.md` F-120): export lalu import di PC lain menghasilkan state identik — termasuk todo/notes/settings, **bukan** termasuk cache sensor/weather (data transient, re-fetch otomatis).

## 4. Enkripsi data sensitif

- **Riwayat notifikasi** (`notifications.enc`, F-100) dan **API key BYO** (AI chat, backlog F-200) adalah satu-satunya data yang perlu proteksi tambahan selain file-permission OS biasa.
- Notifikasi: serialize ke JSON lalu `System.Security.Cryptography.ProtectedData.Protect(bytes, optionalEntropy, DataProtectionScope.CurrentUser)` (Windows DPAPI) — terikat ke user Windows yang login, tidak perlu kelola key sendiri, sesuai rekomendasi arsitektur (§5 `02-architecture.md`: "bukan custom crypto").
- API key provider AI (backlog, bukan Rilis 1/2): **tidak** disimpan di `settings.json` plaintext — pakai `Windows.Security.Credentials.PasswordVault` (Credential Locker bawaan Windows), konsisten dengan catatan Architect.
- Token OAuth kalender (bila integrasi Google Calendar OAuth ditambah di luar mode ICS link publik) — skema sama: `PasswordVault`, bukan file.

## 5. Ringkasan lokasi file

```
%AppData%\NotchWindows\
  settings.json          # F-050, Rilis 1
  settings.corrupt.<ts>.json   # fallback jika korup
  data.db                # LiteDB — todo/notes/calendar cache, Rilis 2
  notifications.enc      # DPAPI-encrypted, Rilis 2 F-100
  logs\                  # rolling log opsional, semua rilis
```

Tidak ada data yang keluar dari folder ini kecuali lewat fitur Backup (F-120, user-initiated, hasil file dipindah manual oleh user) — selaras prinsip privasi "semua tetap di PC" yang dicatat sebagai pola baik di dokumen fitur.
