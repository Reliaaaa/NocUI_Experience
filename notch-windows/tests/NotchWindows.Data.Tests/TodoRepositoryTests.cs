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
    public async Task DeleteAsync_RemovesTodo()
    {
        var repo = CreateRepository();
        var created = await repo.UpsertAsync(new TodoEntity { Title = "Hapus aku" });

        await repo.DeleteAsync(created.Id);

        var all = await repo.GetAllAsync();
        Assert.Empty(all);
    }
}
