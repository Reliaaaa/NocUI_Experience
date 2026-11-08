# Migrasi NotchWindows.Data

Skema MVP dibuat langsung oleh `NotchDbContext.OpenAsync()` (CreateTableAsync, idempotent).
Mulai dari perubahan skema pertama di Rilis 2, tambahkan skrip bernomor di folder ini
(`0001_add_column_x.sql`, dst.) dan test migrasi di `tests/NotchWindows.Tests/Migrations/`
yang membuka database versi lama (fixture `.db` di-commit) lalu menjalankan skrip secara
berurutan, memverifikasi skema akhir cocok dengan entity saat ini.

Belum ada skrip migrasi karena skema Rilis 1 (Todo, Note) adalah skema awal.
