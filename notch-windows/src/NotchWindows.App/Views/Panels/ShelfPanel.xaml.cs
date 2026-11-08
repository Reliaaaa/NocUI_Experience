using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.ApplicationModel.DataTransfer;

namespace NotchWindows.App.Views.Panels;

/// <summary>F-005a — shelf sementara untuk file yang di-drag ke notch. MVP: terima drop, tampilkan daftar nama file.</summary>
public sealed partial class ShelfPanel : UserControl
{
    public ShelfPanel() => InitializeComponent();

    private void OnDragOver(object sender, DragEventArgs e) => e.AcceptedOperation = DataPackageOperation.Copy;

    private async void OnDrop(object sender, DragEventArgs e)
    {
        if (!e.DataView.Contains(Windows.ApplicationModel.DataTransfer.StandardDataFormats.StorageItems))
            return;

        var items = await e.DataView.GetStorageItemsAsync();
        // TODO Rilis 2: aksi cepat (zip/extract/convert/copy) — lihat backlog F-shelf-actions di 01-features.md roadmap.
        _ = items; // placeholder MVP: file diterima, aksi lanjutan belum diimplementasikan.
    }
}
