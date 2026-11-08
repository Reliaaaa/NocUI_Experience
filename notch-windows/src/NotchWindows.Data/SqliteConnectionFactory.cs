using Microsoft.Data.Sqlite;

namespace NotchWindows.Data;

/// <summary>
/// Satu file SQLite di %LOCALAPPDATA%\notch-windows\notch.db. Menjalankan migrasi manual idempotent
/// (Migrations/*.sql, urut berdasar nama file) saat startup. Lihat docs/05-database.md untuk skema lengkap.
/// </summary>
public sealed class SqliteConnectionFactory
{
    private readonly string _dbPath;
    private readonly string _migrationsDir;

    public SqliteConnectionFactory(string? overrideDbPath = null, string? overrideMigrationsDir = null)
    {
        var baseDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "notch-windows");
        Directory.CreateDirectory(baseDir);

        _dbPath = overrideDbPath ?? Path.Combine(baseDir, "notch.db");
        _migrationsDir = overrideMigrationsDir ?? Path.Combine(AppContext.BaseDirectory, "Migrations");
    }

    public SqliteConnection CreateOpenConnection()
    {
        var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        return connection;
    }

    /// <summary>Jalankan semua migrasi *.sql yang belum tercatat di tabel SchemaVersion, urut nama file (001_, 002_, ...).</summary>
    public async Task MigrateAsync(CancellationToken ct = default)
    {
        using var connection = CreateOpenConnection();

        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS SchemaVersion (
                Version INTEGER PRIMARY KEY,
                AppliedAtUtc TEXT NOT NULL
            );
            """, ct);

        var applied = await GetAppliedVersionsAsync(connection, ct);

        if (!Directory.Exists(_migrationsDir)) return;

        var files = Directory.GetFiles(_migrationsDir, "*.sql").OrderBy(f => f, StringComparer.Ordinal);

        foreach (var file in files)
        {
            var version = ParseVersion(Path.GetFileName(file));
            if (applied.Contains(version)) continue;

            var sql = await File.ReadAllTextAsync(file, ct);
            using var tx = connection.BeginTransaction();
            await ExecuteAsync(connection, sql, ct, tx);
            await ExecuteAsync(
                connection,
                "INSERT INTO SchemaVersion (Version, AppliedAtUtc) VALUES ($v, $t);",
                ct,
                tx,
                ("$v", version), ("$t", DateTime.UtcNow.ToString("O")));
            tx.Commit();
        }
    }

    private static int ParseVersion(string fileName)
    {
        // Format: 001_Initial.sql -> 1
        var prefix = fileName.Split('_', 2)[0];
        return int.TryParse(prefix, out var v) ? v : throw new InvalidOperationException($"Nama migrasi tidak valid: {fileName}");
    }

    private static async Task<HashSet<int>> GetAppliedVersionsAsync(SqliteConnection connection, CancellationToken ct)
    {
        var result = new HashSet<int>();
        using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT Version FROM SchemaVersion;";
        using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct)) result.Add(reader.GetInt32(0));
        return result;
    }

    private static async Task ExecuteAsync(
        SqliteConnection connection, string sql, CancellationToken ct,
        SqliteTransaction? tx = null, params (string name, object value)[] parameters)
    {
        using var cmd = connection.CreateCommand();
        cmd.CommandText = sql;
        if (tx is not null) cmd.Transaction = tx;
        foreach (var (name, value) in parameters) cmd.Parameters.AddWithValue(name, value);
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
