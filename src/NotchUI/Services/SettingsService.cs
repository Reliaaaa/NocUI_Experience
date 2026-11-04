using System;
using NotchUI.Models;
using Windows.Storage;
#if UNPACKAGED
using System.IO;
#endif

namespace NotchUI.Services;

/// <summary>A single versioned snapshot in packaged per-user application storage.</summary>
public sealed class SettingsService : ISettingsService
{
    private const string CurrentKey = "NotchUI.Settings";
    private const string RecoveryKey = "NotchUI.Settings.LastGood";
    private readonly object _gate = new();
    private bool _unsupportedVersion;
    public string? LastError { get; private set; }

    public NotchSettings Load()
    {
        lock (_gate)
        {
            LastError = null;
            _unsupportedVersion = false;
            try
            {
#if UNPACKAGED
                var path = SettingsPath;
                if (!File.Exists(path)) return new NotchSettings();
                var payload = File.ReadAllText(path);
                if (SettingsCodec.TryDecode(payload, out var settings)) return settings;
                if (IsFutureVersion(payload))
                {
                    _unsupportedVersion = true;
                    LastError = "Versi pengaturan lebih baru. Pengaturan sesi ini tidak akan menimpa data tersebut.";
                    return new NotchSettings();
                }
                LastError = "Pengaturan rusak; nilai default digunakan.";
                return new NotchSettings();
#else
                var values = ApplicationData.Current.LocalSettings.Values;
                if (!values.ContainsKey(CurrentKey)) return new NotchSettings();
                var payload = values[CurrentKey] as string;
                if (SettingsCodec.TryDecode(payload, out var settings)) return settings;
                // Preserve settings written by a newer app rather than overwriting on downgrade.
                if (IsFutureVersion(payload))
                {
                    _unsupportedVersion = true;
                    LastError = "Versi pengaturan lebih baru. Pengaturan sesi ini tidak akan menimpa data tersebut.";
                    return new NotchSettings();
                }
                LastError = "Pengaturan rusak; cadangan atau nilai default digunakan.";
                return SettingsCodec.TryDecode(values.TryGetValue(RecoveryKey, out var recovery) ? recovery as string : null, out var recovered)
                    ? recovered : new NotchSettings();
#endif
            }
            catch (Exception exception) when (exception is not OutOfMemoryException)
            {
                LastError = "Pengaturan lokal tidak dapat dibaca.";
                return new NotchSettings();
            }
        }
    }

    public bool Save(NotchSettings settings)
    {
        lock (_gate)
        {
            if (_unsupportedVersion) return false;
            try
            {
                var payload = SettingsCodec.Encode(settings);
#if UNPACKAGED
                Directory.CreateDirectory(Path.GetDirectoryName(SettingsPath)!);
                var temporary = SettingsPath + ".tmp";
                File.WriteAllText(temporary, payload);
                File.Move(temporary, SettingsPath, true);
#else
                var values = ApplicationData.Current.LocalSettings.Values;
                if (values.TryGetValue(CurrentKey, out var previous) && previous is string previousPayload && SettingsCodec.TryDecode(previousPayload, out _))
                    values[RecoveryKey] = previousPayload;
                // Single value assignment prevents half-updated preference fields.
                values[CurrentKey] = payload;
#endif
                LastError = null;
                return true;
            }
            catch (Exception exception) when (exception is not OutOfMemoryException)
            {
                LastError = "Pengaturan berlaku untuk sesi ini, tetapi belum tersimpan.";
                return false;
            }
        }
    }

#if UNPACKAGED
    private static string SettingsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NotchUI", "settings.json");
#endif

    private static bool IsFutureVersion(string? payload)
    {
        if (payload is null || payload.Length > SettingsCodec.MaximumPayloadLength) return false;
        try
        {
            using var document = System.Text.Json.JsonDocument.Parse(payload);
            return document.RootElement.ValueKind == System.Text.Json.JsonValueKind.Object &&
                document.RootElement.TryGetProperty("SchemaVersion", out var version) &&
                version.TryGetInt32(out var number) && number > SettingsCodec.CurrentVersion;
        }
        catch (System.Text.Json.JsonException) { return false; }
    }
}
