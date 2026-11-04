using System;
using System.Text.Json;
using NotchUI.Models;

namespace NotchUI.Services;

/// <summary>Platform-independent serialization boundary, shared with the self-check.</summary>
public static class SettingsCodec
{
    public const int CurrentVersion = 1;
    public const int MaximumPayloadLength = 4096;

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
