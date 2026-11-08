-- QA fix (bug QA-014, P0): Todos/Notes dipakai TodoRepository (Dapper) tapi belum ada tabelnya —
-- 001_Initial.sql (MVP) hanya Settings+DockPins. Ditambahkan di sini sebagai migrasi baru terpisah,
-- sesuai aturan "tidak pernah mengubah file migrasi lama" (lihat docs/05-database.md §Migrasi).

CREATE TABLE IF NOT EXISTS Todos (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    Title           TEXT NOT NULL,
    DueAt           TEXT NULL,
    IsCompleted     INTEGER NOT NULL DEFAULT 0,
    IsRecurring     INTEGER NOT NULL DEFAULT 0,
    RecurrenceRule  TEXT NULL,
    CreatedAt       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS Notes (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    Content         TEXT NOT NULL,
    IsFlashcardMode INTEGER NOT NULL DEFAULT 0,
    UpdatedAt       TEXT NOT NULL
);
