using Microsoft.UI.Xaml.Controls;
using NotchWindows.Core.ViewModels;

namespace NotchWindows.App.Views.Panels;

public sealed partial class DashboardPanel : UserControl
{
    public DashboardViewModel ViewModel { get; }

    public DashboardPanel()
    {
        InitializeComponent();
        ViewModel = App.Services.GetService(typeof(DashboardViewModel)) as DashboardViewModel
                    ?? throw new InvalidOperationException("DashboardViewModel belum terdaftar di DI.");
        _ = ViewModel.InitializeAsync();
    }
}
