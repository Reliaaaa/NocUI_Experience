using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Collections.ObjectModel;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;

namespace NotchWindows.App.Views.Panels;

/// <summary>F-005a — shelf sementara untuk file yang di-drag ke notch. MVP: terima drop, tampilkan daftar nama file.</summary>
public sealed partial class ShelfPanel : UserControl
{
    private readonly ObservableCollection<IStorageItem> _items = new();

    public ShelfPanel()
    {
        InitializeComponent();
        ItemList.ItemsSource = _items;
    }

    private void OnDragOver(object sender, DragEventArgs e) => e.AcceptedOperation =
        e.DataView.Contains(StandardDataFormats.StorageItems) ? DataPackageOperation.Copy : DataPackageOperation.None;

    private async void OnDrop(object sender, DragEventArgs e)
    {
        if (!e.DataView.Contains(StandardDataFormats.StorageItems))
            return;

        try
        {
            var items = await e.DataView.GetStorageItemsAsync();
            foreach (var item in items) _items.Add(item);
            ClearButton.IsEnabled = _items.Count > 0;
            StatusText.Text = _items.Count > 0
                ? $"{_items.Count} item · daftar tersimpan selama aplikasi berjalan."
                : "Tidak ada file yang diterima. Jatuhkan file di sini.";
        }
        catch (Exception)
        {
            StatusText.Text = "File tidak dapat ditambahkan. Silakan coba lagi.";
        }
    }

    private void OnClear(object sender, RoutedEventArgs e)
    {
        _items.Clear();
        ClearButton.IsEnabled = false;
        StatusText.Text = "Jatuhkan file di sini. Daftar tersimpan selama aplikasi berjalan.";
    }
}
