using System.Collections.ObjectModel;
using System.Reactive.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;

namespace NotchWindows.Core.ViewModels;

/// <summary>F-040, F-041 — dock bar bawah layar: pinned + running apps, magnify on hover (di View).</summary>
// QA fix (bug QA-005, P1): sama seperti NotchShellViewModel — Dispose() butuh IDisposable eksplisit
// supaya DI container/`using` benar-benar memanggilnya dan _subscription tidak bocor.
public sealed partial class DockBarViewModel : ObservableObject, IDisposable
{
    private readonly IDockService _dockService;
    private IDisposable? _subscription;

    public DockBarViewModel(IDockService dockService)
    {
        _dockService = dockService;
    }

    public ObservableCollection<DockItem> Items { get; } = new();

    public void Initialize()
    {
        _subscription = _dockService.Items.Subscribe(items =>
        {
            Items.Clear();
            foreach (var item in items)
                Items.Add(item);
        });
    }

    [RelayCommand]
    private Task Activate(DockItem item) => _dockService.LaunchOrActivateAsync(item);

    [RelayCommand]
    private Task Pin(string executablePath) => _dockService.PinAsync(executablePath);

    [RelayCommand]
    private Task Unpin(string appId) => _dockService.UnpinAsync(appId);

    public void Dispose() => _subscription?.Dispose();
}
