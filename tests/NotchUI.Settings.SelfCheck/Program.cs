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
var encoded = SettingsCodec.Encode(expected);
foreach (var opaque in new object?[] { null, 42, new byte[] { 1, 2 }, new string(' ', 4097) })
    Check(!SettingsCodec.CanInspectStoredValue(opaque), "Opaque LocalSettings value must be protected from overwrite.");
Check(SettingsCodec.CanInspectStoredValue(encoded.PadRight(4096)) && SettingsCodec.CanInspectStoredValue("{"),
    "Inspectable values must retain valid-load or corrupt-snapshot recovery behavior.");
using (var shortReader = new ShortReader(encoded))
    Check(SettingsCodec.TryReadBounded(shortReader, out var read) && read == encoded, "Short reads truncated settings.");
using (var oversizedReader = new ShortReader(new string(' ', 10000)))
    Check(!SettingsCodec.TryReadBounded(oversizedReader, out var read) && read.Length == 4097 && oversizedReader.CharactersRead == 4097, "Oversize read was not bounded.");
using (var boundaryReader = new ShortReader(encoded.PadRight(4096)))
    Check(SettingsCodec.TryReadBounded(boundaryReader, out var read) && SettingsCodec.TryDecode(read, out _), "Exact size limit rejected.");

var directory = Path.Combine(Path.GetTempPath(), "NotchUI.Settings.SelfCheck-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(directory);
var path = Path.Combine(directory, "settings.json");
try
{
    var service = new SettingsService(path);
    Check(new SettingsService(path).Save(expected) && File.ReadAllText(path) == encoded,
        "Save before Load must allow a new settings file.");
    File.Delete(path);
    Check(service.Load() == new NotchSettings() && service.Save(expected), "Missing file must allow save.");
    foreach (var encoding in new System.Text.Encoding[] { new System.Text.UTF8Encoding(true), System.Text.Encoding.Unicode, System.Text.Encoding.BigEndianUnicode })
    {
        File.WriteAllText(path, encoded, encoding);
        Check(service.Load() == expected, "BOM settings failed to load.");
    }
    foreach (var protectedPayload in new[] { new string('x', 4097), "{\"SchemaVersion\":2,\"Settings\":{}}" })
    {
        File.WriteAllText(path, protectedPayload);
        Check(!new SettingsService(path).Save(expected) && File.ReadAllText(path) == protectedPayload,
            "Save before Load overwrote protected settings.");
        Check(service.Load() == new NotchSettings() && !service.Save(expected) && File.ReadAllText(path) == protectedPayload,
            "Oversize or future settings were overwritten.");
    }
    File.Delete(path);
    Directory.CreateDirectory(path); // Opening a directory as a file fails on supported platforms.
    Check(!new SettingsService(path).Save(expected) && Directory.Exists(path), "Save before Load overwrote unreadable settings.");
    Check(service.Load() == new NotchSettings() && !service.Save(expected) && Directory.Exists(path), "Unreadable settings were overwritten.");
    Directory.Delete(path);
    File.WriteAllText(path, encoded);
    Check(service.Load() == expected && service.Save(expected), "Successful reload must release preservation guard.");
}
finally
{
    Directory.Delete(directory, true);
}
var now = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);
var pomodoro = new Pomodoro();
pomodoro.Start(now);
Check(pomodoro.Remaining(now.AddMinutes(10)) == TimeSpan.FromMinutes(15), "Pomodoro countdown failed.");
pomodoro.Pause(now.AddMinutes(10));
Check(pomodoro.Remaining(now.AddHours(1)) == TimeSpan.FromMinutes(15), "Paused timer changed.");
pomodoro.Start(now.AddHours(1));
Check(pomodoro.Tick(now.AddHours(1).AddMinutes(15)) && pomodoro.Phase == PomodoroPhase.ShortBreak, "Focus transition failed.");
for (var i = 0; i < 3; i++)
{
    pomodoro.Start(now);
    Check(pomodoro.Tick(now.Add(pomodoro.Duration)), "Break did not finish.");
    pomodoro.Start(now);
    Check(pomodoro.Tick(now.Add(pomodoro.Duration)), "Focus did not finish.");
}
Check(pomodoro.Phase == PomodoroPhase.LongBreak && pomodoro.CompletedFocusSessions == 4, "Long break transition failed.");
pomodoro.Reset();
Check(!pomodoro.IsRunning && pomodoro.Remaining(now) == TimeSpan.FromMinutes(15), "Reset failed.");
Console.WriteLine("PASS: codec, bounded short reads, size boundary, BOM and portable storage preservation.");

sealed class ShortReader(string text) : StringReader(text)
{
    public int CharactersRead { get; private set; }
    public override int Read(char[] buffer, int index, int count)
    {
        var read = base.Read(buffer, index, Math.Min(count, 3));
        CharactersRead += read;
        return read;
    }
}
