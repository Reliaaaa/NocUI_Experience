namespace NotchWindows.Core.Navigation;

/// <summary>
/// Panel mana yang sedang tampil di notch terbuka. Bukan Frame/NavigationView biasa — satu window,
/// ContentControl berganti isi via INotchNavigationService.ShowPanel&lt;T&gt;().
/// </summary>
public enum NotchPanelKind
{
    Closed,
    NowPlaying,
    Dashboard,
    ControlCenter, // stub Rilis 1, penuh di Rilis 2 (F-060)
    Shelf,
    Settings,
}

/// <summary>Abstraksi navigasi antar-panel notch. Implementasi konkret ada di NotchWindows.App (butuh WinUI).</summary>
public interface INotchNavigationService
{
    NotchPanelKind CurrentPanel { get; }
    event EventHandler<NotchPanelKind>? PanelChanged;

    void ShowPanel(NotchPanelKind panel);
    void Close();
}
