# Storage

- `JsonSettingsStore.cs` — implementasi `ISettingsStore`. Tulis atomic: serialize ke `settings.json.tmp`,
  `File.Replace`/rename ke `settings.json` agar tidak korup saat crash di tengah write.
- `SqliteLocalStore.cs` — implementasi `ILocalStore` pakai `sqlite-net-pcl`, dibuat saat Rilis 2
  (Todo/Notes/Calendar). Skema versi disimpan di tabel `schema_version`, migrasi dijalankan di `InitializeAsync`.
- Data sensitif (riwayat notifikasi, F-100): enkripsi `System.Security.Cryptography.ProtectedData`
  (DPAPI, scope CurrentUser) sebelum ditulis — lihat docs/02-architecture.md §7.
