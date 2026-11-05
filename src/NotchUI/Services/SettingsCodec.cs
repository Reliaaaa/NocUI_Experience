using System;
using System.IO;
using System.Text.Json;
using NotchUI.Models;

namespace NotchUI.Services;

/// <summary>Platform-independent serialization boundary, shared with the self-check.</summary>
public static class SettingsCodec
{
    public const int CurrentVersion = 1;
    public const int MaximumPayloadLength = 4096;

    public static bool CanInspectStoredValue(object? value) =>
        value is string payload && payload.Length <= MaximumPayloadLength;

    // Read one extra character to detect oversize without loading the entire file.
    // Readers may return fewer characters than requested before reaching EOF.
    public static bool TryReadBounded(TextReader reader, out string payload)
    {
        var buffer = new char[MaximumPayloadLength + 1];
        var count = 0;
        while (count < buffer.Length)
        {
            var read = reader.Read(buffer, count, buffer.Length - count);
            if (read == 0) break;
            count += read;
        }
        payload = new string(buffer, 0, count);
        return count <= MaximumPayloadLength;
    }

    public static string Encode(NotchSettings settings) =>
        JsonSerializer.Serialize(new SettingsEnvelope(settings.Normalize()));

    public static bool TryDecode(string? payload, out NotchSettings settings)
    {
        settings = new NotchSettings();
        if (string.IsNullOrWhiteSpace(payload) || payload.Length > MaximumPayloadLength) return false;
        try
        {
            var envelope = JsonSerializer.Deserialize<SettingsEnvelope>(payload);
            if (envelope is null || envelope.SchemaVersion != CurrentVersion || envelope.Settings is null) return false;
            settings = envelope.Settings.Normalize();
            return true;
        }
        catch (JsonException) { return false; }
    }

    public sealed class SettingsEnvelope
    {
        // Missing schemaVersion is invalid, rather than silently assuming an old/future format.
        public int SchemaVersion { get; init; }
        public NotchSettings? Settings { get; init; }

        public SettingsEnvelope() { }
        public SettingsEnvelope(NotchSettings settings) { SchemaVersion = CurrentVersion; Settings = settings; }
    }
}
