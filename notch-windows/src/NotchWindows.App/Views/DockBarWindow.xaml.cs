using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using NotchWindows.Core.Models;
using NotchWindows.Core.ViewModels;
using NotchWindows.Interop;
using WinRT.Interop;

namespace NotchWindows.App.Views;

/// <summary>F-040, F-041 — window dock terpisah dari notch (lihat docs/02-architecture.md: dua window top-level).</summary>
// QA fix (bug QA-017, P1): pakai NotchWindows.Interop.WindowStyler (sama dengan NotchShellWindow)
// alih-alih App/Interop/Win32Window.cs yang sudah dihapus — dua implementasi Win32 styling paralel
// dikonsolidasikan jadi satu. Lihat docs/06-qa-report.md §QA-017.
public sealed partial class DockBarWindow : Window
{
    public DockBarViewModel ViewModel { get; }

    public DockBarWindow(DockBarViewModel viewModel)
    {
        InitializeComponent();
        ViewModel = viewModel;

        var hwnd = WindowNative.GetWindowHandle(this);
        var styler = new WindowStyler(hwnd);
        styler.ApplyBaseNotchStyles();
        styler.ApplyBorderlessPresenter();
        styler.ReassertTopmost();

        ViewModel.Initialize();
    }

    private static void OnDockIconPointerEntered(object sender, PointerRoutedEventArgs e) =>
        SetScale((FrameworkElement)sender, 1.25);

    private static void OnDockIconPointerExited(object sender, PointerRoutedEventArgs e) =>
        SetScale((FrameworkElement)sender, 1.0);

    private void OnDockIconTapped(object sender, TappedRoutedEventArgs e)
    {
        if (((FrameworkElement)sender).DataContext is DockItem item)
            ViewModel.ActivateCommand.Execute(item);
    }

    private static void SetScale(FrameworkElement element, double scale)
    {
        if (element.RenderTransform is ScaleTransform transform)
        {
            transform.ScaleX = scale;
            transform.ScaleY = scale;
        }
    }
}
