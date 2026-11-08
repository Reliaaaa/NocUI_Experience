using Moq;
using NotchWindows.Core.Abstractions;
using NotchWindows.Core.Models;
using NotchWindows.Core.ViewModels;
using Xunit;

namespace NotchWindows.ViewModels.Tests;

public sealed class SettingsViewModelTests
{
    [Fact]
    public async Task Save_ShowsStoreError()
    {
        var store = new Mock<ISettingsStore>();
        store.SetupGet(s => s.Current).Returns(new AppSettings());
        store.SetupGet(s => s.LastError).Returns("Settings could not be saved.");
        store.Setup(s => s.SaveAsync(It.IsAny<AppSettings>())).Returns(Task.CompletedTask);
        var viewModel = new SettingsViewModel(store.Object);

        await viewModel.SaveCommand.ExecuteAsync(null);

        Assert.Equal("Settings could not be saved.", viewModel.ErrorMessage);
    }
}
