param(
    [Parameter(Mandatory = $true)]
    [string]$PublishDir,
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $PublishDir 'NotchWindows.App.exe'
if (!(Test-Path $exe)) { throw "Portable executable is missing: $exe" }

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class PortableWindowScanner
{
    [StructLayout(LayoutKind.Sequential)]
    private struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    private struct MonitorInfo { public int Size; public Rect Monitor; public Rect Work; public uint Flags; }

    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")]
    private static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);

    public static string[] VisibleTopCenter(int targetProcessId)
    {
        int left = GetSystemMetrics(76);  // SM_XVIRTUALSCREEN
        int top = GetSystemMetrics(77);   // SM_YVIRTUALSCREEN
        int right = left + GetSystemMetrics(78);
        int bottom = top + GetSystemMetrics(79);
        if (right <= left || bottom <= top)
            throw new InvalidOperationException("Windows did not report a usable desktop screen.");

        var windows = new List<string>();
        EnumWindows((hwnd, _) =>
        {
            GetWindowThreadProcessId(hwnd, out uint owner);
            if (owner != targetProcessId || !IsWindowVisible(hwnd) || !GetWindowRect(hwnd, out Rect rect))
                return true;

            if (rect.Right <= rect.Left || rect.Bottom <= rect.Top ||
                rect.Right <= left || rect.Left >= right || rect.Bottom <= top || rect.Top >= bottom)
                return true;

            var monitor = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
            if (!GetMonitorInfo(MonitorFromWindow(hwnd, 2), ref monitor)) return true;
            int centerError = Math.Abs((rect.Left + rect.Right) - (monitor.Monitor.Left + monitor.Monitor.Right));
            if (Math.Abs(rect.Top - monitor.Monitor.Top) <= 8 && centerError <= 48)
                windows.Add($"HWND=0x{hwnd.ToInt64():X} rect=({rect.Left},{rect.Top})-({rect.Right},{rect.Bottom})");
            return true;
        }, IntPtr.Zero);
        return windows.ToArray();
    }
}
'@

$startupLog = Join-Path $env:RUNNER_TEMP ("nocui-startup-" + [Guid]::NewGuid().ToString('N') + '.log')
$env:NOCUI_STARTUP_LOG = $startupLog
$process = Start-Process -FilePath $exe -WorkingDirectory $PublishDir -PassThru
try {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $stablePolls = 0
    while ([DateTime]::UtcNow -lt $deadline) {
        $process.Refresh()
        if ($process.HasExited) {
            if (Test-Path $startupLog) { Get-Content $startupLog | ForEach-Object { Write-Host $_ } }
            Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = (Get-Date).AddMinutes(-3); Id = 1000, 1026 } -ErrorAction SilentlyContinue |
                Where-Object { $_.Message -match 'NotchWindows.App' } | Select-Object -First 5 | ForEach-Object { Write-Host $_.Message }
            throw "Portable app exited before showing a window (code $($process.ExitCode))."
        }

        $windows = [PortableWindowScanner]::VisibleTopCenter($process.Id)
        if ($windows.Length -gt 0) {
            $stablePolls++
            if ($stablePolls -ge 2) {
                Write-Host "Portable app stayed alive with visible top-center window(s): $($windows -join '; ')"
                return
            }
        } else {
            $stablePolls = 0
        }
        Start-Sleep -Seconds 1
    }
    throw "Portable app stayed alive but showed no visible top-center window on the desktop within $TimeoutSeconds seconds."
}
finally {
    $process.Refresh()
    if (!$process.HasExited) {
        $process.Kill($true)
        $process.WaitForExit(5000) | Out-Null
    }
    $process.Dispose()
    Remove-Item Env:NOCUI_STARTUP_LOG -ErrorAction SilentlyContinue
    Remove-Item $startupLog -ErrorAction SilentlyContinue
}
