using NotchUI.Models;
using NotchUI.Services;

static void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

var expected = new NotchSettings { Width = 401, Height = 48, CornerRadius = 23, BackgroundColor = "#AABBCC", Opacity = 0.65, ClockEnabled = false, MediaEnabled = false };
Check(SettingsCodec.TryDecode(SettingsCodec.Encode(expected), out var actual) && actual == expected, "Settings roundtrip failed.");
foreach (var invalid in new[] { "", "{", "null", "{}", "[]", "{\"SchemaVersion\":2,\"Settings\":{}}", "{\"SchemaVersion\":1,\"Settings\":{\"Width\":\"bad\"}}", new string('x', 4097) })
    Check(!SettingsCodec.TryDecode(invalid, out var fallback) && fallback == new NotchSettings(), "Invalid document was accepted.");
Check(SettingsCodec.TryDecode("{\"SchemaVersion\":1,\"Settings\":{}}", out var defaults) && defaults == new NotchSettings(), "Missing fields must use defaults.");
var normalized = new NotchSettings { Width = double.NaN, Height = -1, CornerRadius = double.PositiveInfinity, BackgroundColor = "#12345678" }.Normalize();
Check(normalized.Width == 320 && normalized.Height == 28 && normalized.CornerRadius == 14 && normalized.BackgroundColor == "#000000", "Normalization failed.");
var small = new NotchSettings { CornerRadius = 32 }.Normalize(100, 20);
Check(small.Width == 100 && small.Height == 20 && small.CornerRadius == 10, "Monitor bounds failed.");
Check(new NotchSettings { Opacity = -1 }.Normalize().Opacity == 0.2 && new NotchSettings { Opacity = double.NaN }.Normalize().Opacity == 1, "Opacity normalization failed.");
Check(new NotchSettings { AnimationDurationMs = 1000 }.Normalize().AnimationDurationMs == 600 && new NotchSettings { AnimationDurationMs = double.NaN }.Normalize().AnimationDurationMs == 180, "Animation duration normalization failed.");
var behavior = new NotchSettings { OpenOnHover = false, AnimationDurationMs = 0 };
Check(SettingsCodec.TryDecode(SettingsCodec.Encode(behavior), out var restoredBehavior) && restoredBehavior == behavior, "Behavior settings roundtrip failed.");
Console.WriteLine("PASS: roundtrip, invalid JSON/type/version/size, missing fields, normalization and monitor bounds.");
