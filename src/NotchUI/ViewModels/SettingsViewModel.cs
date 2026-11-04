using NotchUI.Models;
using NotchUI.Services;

namespace NotchUI.ViewModels;

public sealed class SettingsViewModel(NotchCoordinator coordinator)
{
    public NotchSettings Settings => coordinator.Settings;
    public string? Error => coordinator.SettingsError;
    public void Update(Func<NotchSettings, NotchSettings> change)
        => coordinator.UpdateSettings(change(coordinator.Settings));
}
