-- Skema awal MVP (Rilis 1): Settings key-value + DockPins.
-- Tabel Rilis 2 (Todos, Notes, NotificationHistory) ditambah lewat migrasi baru (002_...sql dst),
-- tidak mengubah skema di file ini (lihat docs/05-database.md §Migrasi).

CREATE TABLE IF NOT EXISTS Settings (
    Key   TEXT PRIMARY KEY NOT NULL,
    Value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS DockPins (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    AppUserModelId  TEXT NOT NULL UNIQUE,
    DisplayName     TEXT NOT NULL,
    IconPath        TEXT NOT NULL,
    SortOrder       INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS IX_DockPins_SortOrder ON DockPins (SortOrder);
