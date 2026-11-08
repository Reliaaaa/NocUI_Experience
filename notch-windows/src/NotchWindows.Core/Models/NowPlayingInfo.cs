namespace NotchWindows.Core.Models;

public sealed class NowPlayingInfo
{
    public string Title { get; init; } = string.Empty;
    public string Artist { get; init; } = string.Empty;
    public byte[]? AlbumArt { get; init; }
    public TimeSpan Position { get; init; }
    public TimeSpan Duration { get; init; }
    public bool IsPlaying { get; init; }
    public string SourceAppId { get; init; } = string.Empty;
}
