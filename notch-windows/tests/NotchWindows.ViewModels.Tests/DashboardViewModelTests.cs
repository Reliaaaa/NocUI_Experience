using Moq;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;
using NotchWindows.Core.ViewModels;
using Xunit;

namespace NotchWindows.ViewModels.Tests;

public sealed class DashboardViewModelTests
{
    [Fact]
    public async Task InitializeAsync_PopulatesFiveToggles()
    {
        var network = new Mock<INetworkService>();
        network.Setup(n => n.GetWiFiStateAsync())
            .ReturnsAsync(new ToggleState { Id = "WiFi", Label = "Wi-Fi", IsOn = true });
        network.Setup(n => n.GetBluetoothStateAsync())
            .ReturnsAsync(new ToggleState { Id = "Bluetooth", Label = "Bluetooth", IsOn = false });

        var weather = new Mock<IWeatherService>();
        weather.Setup(w => w.GetCurrentAsync(It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((WeatherSnapshot?)null);

        var viewModel = new DashboardViewModel(network.Object, weather.Object);

        await viewModel.InitializeAsync();

        Assert.Equal(5, viewModel.Toggles.Count);
        Assert.True(viewModel.Toggles[0].IsOn); // Wi-Fi
        Assert.Null(viewModel.Weather);
        weather.Verify(w => w.GetCurrentAsync(It.IsAny<double>(), It.IsAny<double>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public void DayProgressPercent_IsWithinZeroToHundred()
    {
        var viewModel = new DashboardViewModel(Mock.Of<INetworkService>(), Mock.Of<IWeatherService>());

        var progress = viewModel.DayProgressPercent;

        Assert.InRange(progress, 0, 100);
    }
}
