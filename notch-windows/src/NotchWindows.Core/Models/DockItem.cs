namespace NotchWindows.Core.Models;

/// <summary>Satu entri di dock bar (F-040): app pinned atau app yang sedang berjalan.</summary>
public sealed class DockItem
{
    public required string AppId { get; init; }
    public required string DisplayName { get; init; }
    public required string ExecutablePath { get; init; }
    public byte[]? IconBytes { get; init; }
    public bool IsPinned { get; init; }
    public bool IsRunning { get; init; }
    public int OpenWindowCount { get; init; }
}
