using System.Text.Json;
using NotchWindows.Core.Models;
using NotchWindows.Services.Settings;
using Xunit;

namespace NotchWindows.Services.Tests.Settings;

public sealed class JsonSettingsStoreTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "notch-settings-" + Guid.NewGuid().ToString("N"));
    private string SettingsPath => Path.Combine(_directory, "settings.json");

    public JsonSettingsStoreTests() => Directory.CreateDirectory(_directory);
    public void Dispose() => Directory.Delete(_directory, recursive: true);

    [Theory]
    [InlineData("{broken")]
    [InlineData("null")]
    [InlineData("{}")]
    [InlineData("{\"SchemaVersion\":2}")]
    [InlineData("{\"SchemaVersion\":\"newer\"}")]
    [InlineData("{\"SchemaVersion\":1,\"FuturePreference\":true}")]
    [InlineData("{\"SchemaVersion\":1,\"PinnedAppPaths\":null}")]
    public async Task SaveWithoutLoad_PreservesIncompatibleFile(string original)
    {
        await File.WriteAllTextAsync(SettingsPath, original);
        var store = new JsonSettingsStore(SettingsPath);
        await store.SaveAsync(new AppSettings { Use24HourClock = false });
        Assert.Equal(original, await File.ReadAllTextAsync(SettingsPath));
        Assert.NotNull(store.LastError);
        Assert.False(store.Current.Use24HourClock);
    }

    [Fact]
    public async Task SavesRoundTrip_AndKeepsOriginalBackup()
    {
        var original = JsonSerializer.Serialize(new AppSettings());
        await File.WriteAllTextAsync(SettingsPath, original);
        var store = new JsonSettingsStore(SettingsPath);
        await store.LoadAsync();
        await store.SaveAsync(new AppSettings { Use24HourClock = false });
        await store.SaveAsync(new AppSettings { Use24HourClock = false, PreferredMonitorIndex = 2 });
        Assert.Null(store.LastError);
        Assert.Equal(original, await File.ReadAllTextAsync(Assert.Single(Directory.GetFiles(_directory, "*.bak"))));
        Assert.Empty(Directory.GetFiles(_directory, "*.tmp"));
        var reloaded = new JsonSettingsStore(SettingsPath);
        await reloaded.LoadAsync();
        Assert.False(reloaded.Current.Use24HourClock);
        Assert.Equal(2, reloaded.Current.PreferredMonitorIndex);
    }

    [Fact]
    public async Task Save_PreservesExternalChanges()
    {
        var store = new JsonSettingsStore(SettingsPath);
        await store.LoadAsync();
        const string external = "{\"SchemaVersion\":2}";
        await File.WriteAllTextAsync(SettingsPath, external);
        await store.SaveAsync(new AppSettings());
        Assert.Equal(external, await File.ReadAllTextAsync(SettingsPath));
        Assert.NotNull(store.LastError);
    }

    [Fact]
    public async Task MissingFile_CanBeCreatedAndReloaded()
    {
        var store = new JsonSettingsStore(SettingsPath);
        await store.SaveAsync(new AppSettings { PreferredMonitorIndex = 3 });
        var reloaded = new JsonSettingsStore(SettingsPath);
        await reloaded.LoadAsync();
        Assert.Null(store.LastError);
        Assert.Equal(3, reloaded.Current.PreferredMonitorIndex);
    }

    [Fact]
    public async Task UnreadablePath_IsNotReplaced()
    {
        Directory.CreateDirectory(SettingsPath);
        var store = new JsonSettingsStore(SettingsPath);
        await store.LoadAsync();
        await store.SaveAsync(new AppSettings());
        Assert.True(Directory.Exists(SettingsPath));
        Assert.NotNull(store.LastError);
    }
}
