namespace NotchWindows.Core.Abstractions;

/// <summary>
/// Penyimpanan data terstruktur (Todo/Notes/Calendar cache — Rilis 2) via SQLite.
/// CRUD generik sederhana; query spesifik ditambahkan per fitur saat Rilis 2 diimplementasi.
/// </summary>
public interface ILocalStore
{
    Task InitializeAsync(CancellationToken ct = default);
    Task<T?> GetByIdAsync<T>(object id, CancellationToken ct = default) where T : class, new();
    Task<IReadOnlyList<T>> GetAllAsync<T>(CancellationToken ct = default) where T : class, new();
    Task UpsertAsync<T>(T item, CancellationToken ct = default) where T : class, new();
    Task DeleteAsync<T>(object id, CancellationToken ct = default) where T : class, new();
}
