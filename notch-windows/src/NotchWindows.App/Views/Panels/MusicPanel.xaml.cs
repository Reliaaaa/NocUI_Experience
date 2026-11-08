using Microsoft.UI.Xaml.Controls;
using NotchWindows.Core.ViewModels;

namespace NotchWindows.App.Views.Panels;

public sealed partial class MusicPanel : UserControl
{
    public MusicViewModel ViewModel { get; }

    public MusicPanel()
    {
        InitializeComponent();
        ViewModel = App.Services.GetService(typeof(MusicViewModel)) as MusicViewModel
                    ?? throw new InvalidOperationException("MusicViewModel belum terdaftar di DI.");
    }
}
