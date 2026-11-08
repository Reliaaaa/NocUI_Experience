using System.Globalization;
using Dapper;
using NotchWindows.Data.Entities;

namespace NotchWindows.Data.Repositories;

/// <summary>Dipanggil dari Core ViewModels lewat abstraksi yang akan ditambah di Rilis 2 (lihat 02-architecture.md §5).</summary>
public interface ITodoRepository
{
    Task<List<TodoEntity>> GetAllAsync();
    Task<TodoEntity> UpsertAsync(TodoEntity todo);
    Task DeleteAsync(int id);
}

/// <summary>
/// QA fix (bug QA-014, P0): ditulis ulang di atas Microsoft.Data.Sqlite + Dapper (lewat
/// <see cref="NotchDbContext"/>/<see cref="SqliteConnectionFactory"/>) alih-alih sqlite-net-pcl,
/// supaya konsisten dengan satu-satunya connection factory yang sungguh dipakai di proyek ini.
/// Tabel <c>Todos</c> ditambahkan lewat migrasi <c>002_AddTodosNotes.sql</c>.
/// </summary>
public sealed class TodoRepository : ITodoRepository
{
    private readonly NotchDbContext _dbContext;

    public TodoRepository(NotchDbContext dbContext) => _dbContext = dbContext;

    public async Task<List<TodoEntity>> GetAllAsync()
    {
        using var connection = _dbContext.OpenConnection();
        var rows = await connection.QueryAsync<TodoRow>(
            "SELECT Id, Title, DueAt, IsCompleted, IsRecurring, RecurrenceRule, CreatedAt FROM Todos ORDER BY CreatedAt;");
        return rows.Select(row => new TodoEntity
        {
            Id = row.Id,
            Title = row.Title,
            DueAt = row.DueAt is null ? null : ParseTimestamp(row.DueAt),
            IsCompleted = row.IsCompleted,
            IsRecurring = row.IsRecurring,
            RecurrenceRule = row.RecurrenceRule,
            CreatedAt = ParseTimestamp(row.CreatedAt),
        }).ToList();
    }

    public async Task<TodoEntity> UpsertAsync(TodoEntity todo)
    {
        using var connection = _dbContext.OpenConnection();

        // SQLite stores timestamps as TEXT. Explicit round-trip formatting avoids
        // provider-specific DateTimeOffset conversion and preserves the original offset.
        var parameters = new
        {
            todo.Id,
            todo.Title,
            DueAt = todo.DueAt?.ToString("O", CultureInfo.InvariantCulture),
            todo.IsCompleted,
            todo.IsRecurring,
            todo.RecurrenceRule,
            CreatedAt = todo.CreatedAt.ToString("O", CultureInfo.InvariantCulture),
        };

        if (todo.Id == 0)
        {
            var newId = await connection.ExecuteScalarAsync<long>(
                """
                INSERT INTO Todos (Title, DueAt, IsCompleted, IsRecurring, RecurrenceRule, CreatedAt)
                VALUES (@Title, @DueAt, @IsCompleted, @IsRecurring, @RecurrenceRule, @CreatedAt);
                SELECT last_insert_rowid();
                """,
                parameters);
            todo.Id = (int)newId;
        }
        else
        {
            await connection.ExecuteAsync(
                """
                UPDATE Todos
                SET Title = @Title, DueAt = @DueAt, IsCompleted = @IsCompleted,
                    IsRecurring = @IsRecurring, RecurrenceRule = @RecurrenceRule
                WHERE Id = @Id;
                """,
                parameters);
        }

        return todo;
    }

    // Parse also accepts timestamps previously written by Microsoft.Data.Sqlite
    // (yyyy-MM-dd HH:mm:ss.FFFFFFFzzz), so existing databases remain readable.
    private static DateTimeOffset ParseTimestamp(string value) =>
        DateTimeOffset.Parse(value, CultureInfo.InvariantCulture, DateTimeStyles.None);

    private sealed class TodoRow
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? DueAt { get; set; }
        public bool IsCompleted { get; set; }
        public bool IsRecurring { get; set; }
        public string? RecurrenceRule { get; set; }
        public string CreatedAt { get; set; } = string.Empty;
    }

    public async Task DeleteAsync(int id)
    {
        using var connection = _dbContext.OpenConnection();
        await connection.ExecuteAsync("DELETE FROM Todos WHERE Id = @Id;", new { Id = id });
    }
}
