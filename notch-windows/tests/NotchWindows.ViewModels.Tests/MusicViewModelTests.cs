using Moq;
using NotchWindows.Core.Models;
using NotchWindows.Core.Abstractions;
using NotchWindows.Core.ViewModels;
using Xunit;

namespace NotchWindows.ViewModels.Tests;

public sealed class MusicViewModelTests
{
    [Fact]
    public void ProgressRatio_WhenDurationZero_ReturnsZero()
    {
        var music = new Mock<IMusicService>();
        music.SetupGet(m => m.Current).Returns(TrackInfo.Empty);
        var viewModel = new MusicViewModel(music.Object);

        Assert.Equal(0, viewModel.ProgressRatio);
    }

    [Theory]
    [InlineData(30, 120, 0.25)]
    [InlineData(120, 120, 1.0)]
    [InlineData(200, 120, 1.0)] // clamp di atas durasi (lihat MusicViewModel.ProgressRatio)
    public void ProgressRatio_ComputesExpectedRatio(int positionSeconds, int durationSeconds, double expected)
    {
        var track = new TrackInfo
        {
            Title = "Test",
            Position = TimeSpan.FromSeconds(positionSeconds),
            Duration = TimeSpan.FromSeconds(durationSeconds),
        };
        var music = new Mock<IMusicService>();
        music.SetupGet(m => m.Current).Returns(track);
        var viewModel = new MusicViewModel(music.Object);

        Assert.Equal(expected, viewModel.ProgressRatio, precision: 3);
    }

    [Fact]
    public void IsPlaying_ReflectsTrackStatus()
    {
        var track = new TrackInfo { Title = "Test", Status = PlaybackStatus.Playing };
        var music = new Mock<IMusicService>();
        music.SetupGet(m => m.Current).Returns(track);
        var viewModel = new MusicViewModel(music.Object);

        Assert.True(viewModel.IsPlaying);
    }
}
