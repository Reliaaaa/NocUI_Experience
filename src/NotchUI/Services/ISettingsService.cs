using NotchUI.Models;

namespace NotchUI.Services;

public interface ISettingsService
{
    string? LastError { get; }
    NotchSettings Load();
    bool Save(NotchSettings settings);
}
