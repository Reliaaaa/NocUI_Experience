using System.Text.Json;
using System.Text.Json.Serialization;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Services.Settings;

/// <summary>Versioned local settings; incompatible or unreadable files remain untouched.</summary>
public sealed class JsonSettingsStore : ISettingsStore
{
    private readonly string _filePath;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private byte[]? _loadedBytes;
    private bool _loaded;
    private bool _canSave;
    private bool _backedUp;
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public JsonSettingsStore() : this(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NotchWindows", "settings.json")) { }

    public JsonSettingsStore(string filePath) => _filePath = Path.GetFullPath(filePath);

    public AppSettings Current { get; private set; } = new();
    public string? LastError { get; private set; }
    public event EventHandler<AppSettings>? Changed;

    public async Task LoadAsync()
    {
        await _gate.WaitAsync();
        try { await LoadCoreAsync(); }
        finally { _gate.Release(); }
    }

    private async Task LoadCoreAsync()
    {
        _loaded = true;
        _backedUp = false;
        _canSave = false;
        LastError = null;
        Current = new();
        try
        {
            _loadedBytes = await File.ReadAllBytesAsync(_filePath);
            using var document = JsonDocument.Parse(_loadedBytes);
            if (document.RootElement.ValueKind != JsonValueKind.Object ||
                !document.RootElement.TryGetProperty("SchemaVersion", out var version) ||
                version.ValueKind != JsonValueKind.Number || !version.TryGetInt32(out var number) || number != 1)
                throw new JsonException("Unsupported settings schema.");
            var settings = JsonSerializer.Deserialize<AppSettings>(_loadedBytes, JsonOptions);
            if (settings is null || !IsValid(settings))
                throw new JsonException("Invalid settings values.");
            Current = settings;
            _canSave = true;
        }
        catch (FileNotFoundException) { _loadedBytes = null; _canSave = true; }
        catch (DirectoryNotFoundException) { _loadedBytes = null; _canSave = true; }
        catch (Exception ex) when (ex is JsonException or IOException or UnauthorizedAccessException)
        {
            LastError = "Settings could not be loaded safely; the existing file will not be overwritten.";
        }
    }

    private static bool IsValid(AppSettings settings) =>
        settings.SchemaVersion == 1 && settings.PinnedAppPaths is not null &&
        settings.PinnedAppPaths.All(path => path is not null) &&
        settings.GlobalToggleShortcut is not null && settings.PreferredMonitorIndex >= 0 &&
        Enum.IsDefined(settings.Theme) && Enum.IsDefined(settings.Position) &&
        Enum.IsDefined(settings.LeftMetric) && Enum.IsDefined(settings.RightMetric);

    public async Task SaveAsync(AppSettings settings)
    {
        await _gate.WaitAsync();
        string? temporaryPath = null;
        try
        {
            // A caller saving before startup load must not bypass compatibility checks.
            if (!_loaded) await LoadCoreAsync();
            Current = settings;
            if (!_canSave) return;
            if (!IsValid(settings))
            {
                LastError = "Invalid or unsupported settings; changes apply only to this session.";
                return;
            }
            byte[]? actualBytes;
            try { actualBytes = await File.ReadAllBytesAsync(_filePath); }
            catch (FileNotFoundException) { actualBytes = null; }
            catch (DirectoryNotFoundException) { actualBytes = null; }
            if ((_loadedBytes is null) != (actualBytes is null) ||
                (_loadedBytes is not null && !_loadedBytes.AsSpan().SequenceEqual(actualBytes)))
            {
                _canSave = false;
                LastError = "Settings changed on disk; reload before saving. Changes apply only to this session.";
                return;
            }

            var bytes = JsonSerializer.SerializeToUtf8Bytes(settings, JsonOptions);
            Directory.CreateDirectory(Path.GetDirectoryName(_filePath)!);
            temporaryPath = _filePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
            await File.WriteAllBytesAsync(temporaryPath, bytes);
            if (_loadedBytes is null)
                File.Move(temporaryPath, _filePath); // Never overwrite a newly created file.
            else
            {
                // Preserve the pre-session file once; slider updates must not create unlimited backups.
                File.Replace(temporaryPath, _filePath, _backedUp ? null :
                    _filePath + "." + Guid.NewGuid().ToString("N") + ".bak");
                _backedUp = true;
            }
            _loadedBytes = bytes;
            LastError = null;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            LastError = "Settings could not be saved; changes apply only to this session.";
        }
        finally
        {
            if (temporaryPath is not null)
            {
                try { File.Delete(temporaryPath); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
            _gate.Release();
            Changed?.Invoke(this, Current);
        }
    }
}
