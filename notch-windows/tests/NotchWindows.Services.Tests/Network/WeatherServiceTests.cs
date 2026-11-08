using System.Net;
using NotchWindows.Services.Network;
using Xunit;

namespace NotchWindows.Services.Tests.Network;

public class WeatherServiceTests
{
    [Fact]
    public async Task GetCurrentAsync_ParsesOpenMeteoResponse()
    {
        var json = """{"current_weather":{"temperature":28.4,"weathercode":1}}""";
        var handler = new StubHttpMessageHandler(json, HttpStatusCode.OK);
        var service = new WeatherService(new HttpClient(handler));

        var result = await service.GetCurrentAsync(-7.25, 112.75);

        Assert.NotNull(result);
        Assert.Equal(28.4, result!.TemperatureCelsius);
        Assert.Equal("Berawan", result.ConditionText);
        Assert.Equal(1, result.WeatherCode);
    }

    [Fact]
    public async Task GetCurrentAsync_ReturnsNull_WhenResponseEmpty()
    {
        var handler = new StubHttpMessageHandler("{}", HttpStatusCode.OK);
        var service = new WeatherService(new HttpClient(handler));

        var result = await service.GetCurrentAsync(0, 0);

        Assert.Null(result);
    }

    [Fact]
    public async Task GetCurrentAsync_ReturnsNull_WhenHttpFails()
    {
        var handler = new ThrowingHttpMessageHandler();
        var service = new WeatherService(new HttpClient(handler));

        var result = await service.GetCurrentAsync(0, 0);

        Assert.Null(result);
    }

    private sealed class StubHttpMessageHandler(string content, HttpStatusCode statusCode) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var response = new HttpResponseMessage(statusCode)
            {
                Content = new StringContent(content, global::System.Text.Encoding.UTF8, "application/json"),
            };
            return Task.FromResult(response);
        }
    }

    private sealed class ThrowingHttpMessageHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            => throw new HttpRequestException("network down");
    }
}
