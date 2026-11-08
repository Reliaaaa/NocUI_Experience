using NotchWindows.Core.Navigation;

namespace NotchWindows.App.Services;

/// <summary>
/// Implementasi konkret INotchNavigationService (butuh WinUI, karena itu tinggal di App, bukan Core).
/// Mengganti isi ContentControl ActivePanelHost di NotchShellWindow sesuai NotchPanelKind.
/// </summary>
public sealed class NotchNavigationService : INotchNavigationService
{
    public NotchPanelKind CurrentPanel { get; private set; } = NotchPanelKind.Closed;

    public event EventHandler<NotchPanelKind>? PanelChanged;

    public void ShowPanel(NotchPanelKind panel)
    {
        CurrentPanel = panel;
        PanelChanged?.Invoke(this, panel);
    }

    public void Close() => ShowPanel(NotchPanelKind.Closed);
}
