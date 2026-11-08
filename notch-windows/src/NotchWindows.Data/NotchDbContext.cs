using Microsoft.Data.Sqlite;

namespace NotchWindows.Data;

/// <summary>
/// Membuka koneksi SQLite lewat <see cref="SqliteConnectionFactory"/> (migrasi dijalankan terpisah
/// saat startup via <c>MigrateAsync</c> — lihat composition root <c>App.xaml.cs</c>), bukan di sini.
/// QA fix (bug QA-014, P0): sebelumnya ditulis di atas sqlite-net-pcl (<c>SQLiteAsyncConnection</c>,
/// <c>CreateTableAsync</c>) yang tidak pernah direferensikan project ini (hanya Microsoft.Data.Sqlite +
/// Dapper) dan tidak kompatibel dengan satu-satunya connection factory yang ada. Sekarang jadi tipis:
/// tugasnya cuma membuka koneksi lewat factory yang sama dipakai migrasi, supaya path file DB dan
/// strategi migrasi tetap satu sumber kebenaran (lihat docs/05-database.md).
/// </summary>
public sealed class NotchDbContext
{
    private readonly SqliteConnectionFactory _connectionFactory;

    public NotchDbContext(SqliteConnectionFactory connectionFactory) => _connectionFactory = connectionFactory;

    /// <summary>Buka koneksi baru siap pakai. Pemanggil bertanggung jawab men-dispose (Dapper query pendek per panggilan).</summary>
    public SqliteConnection OpenConnection() => _connectionFactory.CreateOpenConnection();
}
