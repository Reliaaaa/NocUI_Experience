using NotchWindows.Data;
using NotchWindows.Data.Entities;
using NotchWindows.Data.Repositories;
using Xunit;

namespace NotchWindows.Data.Tests;

/// <summary>
/// CRUD Todo via SQLite (F-080, Rilis 2) — lihat docs/05-database.md.
/// QA fix (bug QA-014, P0): ditulis ulang untuk Microsoft.Data.Sqlite + Dapper (bukan sqlite-net-pcl).
/// Pakai file temp unik per test (bukan ":memory:") supaya isolasi antar test tetap terjaga tanpa
/// bergantung pada detail connection-pool library tertentu.
/// </summary>
public sealed class TodoRepositoryTests : IAsyncLifetime
{
    private readonly string _dbPath = Path.Combine(Path.GetTempPath(), $"notch-test-{Guid.NewGuid():N}.db");

    public async Task InitializeAsync()
    {
        var factory = new SqliteConnectionFactory(_dbPath);
        await factory.MigrateAsync();
    }

    public Task DisposeAsync()
    {
        try { File.Delete(_dbPath); } catch (IOException) { /* file masih dipegang, abaikan di test */ }
        return Task.CompletedTask;
    }

    private ITodoRepository CreateRepository()
    {
        var factory = new SqliteConnectionFactory(_dbPath);
        var dbContext = new NotchDbContext(factory);
        return new TodoRepository(dbContext);
    }

    [Fact]
    public async Task UpsertAsync_InsertsNewTodo_WhenIdIsZero()
    {
        var repo = CreateRepository();

        var saved = await repo.UpsertAsync(new TodoEntity { Title = "Beli susu" });

        Assert.True(saved.Id > 0);
        var all = await repo.GetAllAsync();
        Assert.Single(all);
        Assert.Equal("Beli susu", all[0].Title);
    }

    [Fact]
    public async Task UpsertAsync_UpdatesExistingTodo_WhenIdIsSet()
    {
        var repo = CreateRepository();
        var created = await repo.UpsertAsync(new TodoEntity { Title = "Draft" });

        created.Title = "Final";
        created.IsCompleted = true;
        await repo.UpsertAsync(created);

        var all = await repo.GetAllAsync();
        Assert.Single(all);
        Assert.Equal("Final", all[0].Title);
        Assert.True(all[0].IsCompleted);
    }

    [Fact]
    public async Task Timestamps_RoundTripOffsetsAndTicks_AndNullableDueAtUpdates()
    {
        var repo = CreateRepository();
        var createdAt = new DateTimeOffset(2026, 11, 8, 12, 34, 56, TimeSpan.FromHours(5.5)).AddTicks(1234567);
        var dueAt = new DateTimeOffset(2026, 11, 9, 1, 2, 3, TimeSpan.FromHours(-7)).AddTicks(7654321);
        var saved = await repo.UpsertAsync(new TodoEntity { Title = "Offsets", CreatedAt = createdAt });

        var loaded = Assert.Single(await CreateRepository().GetAllAsync());
        Assert.True(createdAt.EqualsExact(loaded.CreatedAt));
        Assert.Null(loaded.DueAt);

        saved.DueAt = dueAt;
        await repo.UpsertAsync(saved);
        loaded = Assert.Single(await CreateRepository().GetAllAsync());
        Assert.True(dueAt.EqualsExact(loaded.DueAt!.Value));
        Assert.True(createdAt.EqualsExact(loaded.CreatedAt));

        saved.DueAt = null;
        await repo.UpsertAsync(saved);
        loaded = Assert.Single(await CreateRepository().GetAllAsync());
        Assert.Null(loaded.DueAt);
        Assert.True(createdAt.EqualsExact(loaded.CreatedAt));
    }

    [Fact]
    public async Task GetAllAsync_ReadsExistingProviderTimestampFormat()
    {
        var createdAt = new DateTimeOffset(2026, 11, 8, 12, 34, 56, TimeSpan.FromHours(7)).AddTicks(1234567);
        var dueAt = createdAt.AddDays(1).ToOffset(TimeSpan.FromHours(-4));
        using (var connection = new SqliteConnectionFactory(_dbPath).CreateOpenConnection())
        {
            using var command = connection.CreateCommand();
            command.CommandText = "INSERT INTO Todos (Title, CreatedAt, DueAt) VALUES ($title, $created, $due);";
            command.Parameters.AddWithValue("$title", "Legacy provider format");
            command.Parameters.AddWithValue("$created", createdAt);
            command.Parameters.AddWithValue("$due", dueAt);
            await command.ExecuteNonQueryAsync();
        }

        var loaded = Assert.Single(await CreateRepository().GetAllAsync());
        Assert.True(createdAt.EqualsExact(loaded.CreatedAt));
        Assert.True(dueAt.EqualsExact(loaded.DueAt!.Value));
    }

    [Fact]
    public async Task DeleteAsync_RemovesTodo()
    {
        var repo = CreateRepository();
        var created = await repo.UpsertAsync(new TodoEntity { Title = "Hapus aku" });

        await repo.DeleteAsync(created.Id);

        var all = await repo.GetAllAsync();
        Assert.Empty(all);
    }
}
