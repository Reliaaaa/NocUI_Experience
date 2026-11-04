using System;

namespace NotchUI.Models;

/// <summary>Only user preferences; live module and interaction state are never persisted.</summary>
public sealed record NotchSettings
{
    public const double MinimumWidth = 200;
    public const double MaximumWidth = 520;
    public const double MinimumHeight = 28;
    public const double MaximumHeight = 64;
    public const double MaximumRadius = 32;

    public double Width { get; init; } = 320;
    public double Height { get; init; } = 34;
    public double CornerRadius { get; init; } = 16;
    public string BackgroundColor { get; init; } = "#000000";
    public bool ClockEnabled { get; init; } = true;
    public bool BatteryEnabled { get; init; } = true;
    public bool MediaEnabled { get; init; } = true;

    public NotchSettings Normalize(double availableWidth = double.MaxValue, double availableHeight = double.MaxValue)
    {
        var widthLimit = double.IsFinite(availableWidth) && availableWidth > 0 ? Math.Min(MaximumWidth, availableWidth) : MaximumWidth;
        var heightLimit = double.IsFinite(availableHeight) && availableHeight > 0 ? Math.Min(MaximumHeight, availableHeight) : MaximumHeight;
        var width = Math.Clamp(double.IsFinite(Width) ? Width : 320, Math.Min(MinimumWidth, widthLimit), widthLimit);
        var height = Math.Clamp(double.IsFinite(Height) ? Height : 34, Math.Min(MinimumHeight, heightLimit), heightLimit);
        var radius = Math.Clamp(double.IsFinite(CornerRadius) ? CornerRadius : 16, 0, Math.Min(MaximumRadius, Math.Min(width, height) / 2));
        return this with { Width = width, Height = height, CornerRadius = radius, BackgroundColor = NormalizeColor(BackgroundColor) };
    }

    private static string NormalizeColor(string? color)
    {
        if (color is null || color.Length != 7 || color[0] != '#') return "#000000";
        for (var index = 1; index < color.Length; index++)
            if (!Uri.IsHexDigit(color[index])) return "#000000";
        return color.ToUpperInvariant();
    }
}
