using System.Text.Json;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Services.Settings;

/// <summary>F-050 — persist ke %LOCALAPPDATA%\NotchWindows\settings.json (plain JSON; tidak ada secret di MVP).</summary>
public sealed class JsonSettingsStore : ISettingsStore
{
    private static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NotchWindows", "settings.json");

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public AppSettings Current { get; private set; } = new();
    public event EventHandler<AppSettings>? Changed;

    public async Task LoadAsync()
    {
        try
        {
            if (File.Exists(FilePath))
            {
                var json = await File.ReadAllTextAsync(FilePath);
                Current = JsonSerializer.Deserialize<AppSettings>(json, JsonOptions) ?? new AppSettings();
            }
        }
        catch (JsonException)
        {
            // file korup -> fallback ke default, jangan crash startup
            Current = new AppSettings();
        }
    }

    public async Task SaveAsync(AppSettings settings)
    {
        Current = settings;
        var directory = Path.GetDirectoryName(FilePath)!;
        Directory.CreateDirectory(directory);
        var json = JsonSerializer.Serialize(settings, JsonOptions);
        await File.WriteAllTextAsync(FilePath, json);
        Changed?.Invoke(this, settings);
    }
}
