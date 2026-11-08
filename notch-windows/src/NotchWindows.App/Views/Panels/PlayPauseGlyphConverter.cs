using Microsoft.UI.Xaml.Data;

namespace NotchWindows.App.Views.Panels;

/// <summary>Converter kecil untuk tombol play/pause di MusicPanel (F-011).</summary>
public sealed class PlayPauseGlyphConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language) =>
        value is true ? "⏸" : "▶";

    public object ConvertBack(object value, Type targetType, object parameter, string language) =>
        throw new NotSupportedException();
}
