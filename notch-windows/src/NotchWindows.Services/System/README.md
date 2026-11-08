# System (CPU/RAM/disk/baterai/Wi-Fi)

Implementasi `ISystemInfoService` (`SystemInfoService.cs`, dibuat di tahap implementasi F-004/F-020):

- CPU: `PerformanceCounter("Processor", "% Processor Time", "_Total")` (butuh warm-up read pertama diabaikan).
- RAM: `GlobalMemoryStatusEx` P/Invoke atau `PerformanceCounter("Memory", "% Committed Bytes In Use")`.
- Disk: `DriveInfo.GetDrives()` filter `DriveType.Fixed`.
- Baterai: `System.Windows.Forms.SystemInformation.PowerStatus` ATAU `Windows.System.Power.PowerManager` (WinRT, lebih idiomatik WinUI3, dipakai agar tidak menambah dependency WinForms).
- Wi-Fi SSID: `WlanOpenHandle`/`WlanQueryInterface` (wlanapi.dll P/Invoke) — opsional di MVP, boleh fallback ke `NetworkInterface` nama koneksi.
- GPU temp (bila tersedia, tanpa admin/driver tambahan): `System.Management` WMI `MSAcpi_ThermalZoneTemperature` atau `Win32_PerfFormattedData_GPUPerformanceCounters_GPU*` (ketersediaan bervariasi per driver — tidak dijamin, UI harus toleran null).

Polling interval default 1-5 detik (lihat `AppSettings`), dijalankan via `PeriodicTimer` di background task, bukan `DispatcherTimer`, supaya tidak membebani UI thread; hasil dipublikasikan lewat event `Updated` dan di-marshal ke UI thread oleh ViewModel (`DispatcherQueue.TryEnqueue`).
