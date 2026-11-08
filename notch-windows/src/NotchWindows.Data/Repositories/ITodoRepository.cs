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
        var rows = await connection.QueryAsync<TodoEntity>(
            "SELECT Id, Title, DueAt, IsCompleted, IsRecurring, RecurrenceRule, CreatedAt FROM Todos ORDER BY CreatedAt;");
        return rows.AsList();
    }

    public async Task<TodoEntity> UpsertAsync(TodoEntity todo)
    {
        using var connection = _dbContext.OpenConnection();

        if (todo.Id == 0)
        {
            var newId = await connection.ExecuteScalarAsync<long>(
                """
                INSERT INTO Todos (Title, DueAt, IsCompleted, IsRecurring, RecurrenceRule, CreatedAt)
                VALUES (@Title, @DueAt, @IsCompleted, @IsRecurring, @RecurrenceRule, @CreatedAt);
                SELECT last_insert_rowid();
                """,
                todo);
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
                todo);
        }

        return todo;
    }

    public async Task DeleteAsync(int id)
    {
        using var connection = _dbContext.OpenConnection();
        await connection.ExecuteAsync("DELETE FROM Todos WHERE Id = @Id;", new { Id = id });
    }
}
