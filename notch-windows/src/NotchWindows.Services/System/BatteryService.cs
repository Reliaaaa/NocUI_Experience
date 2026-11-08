using Windows.System.Power;
using NotchWindows.Core.Models;

namespace NotchWindows.Services.System;

/// <summary>Baterai via Windows.System.Power (tidak perlu admin/driver). Laptop tanpa baterai -> IsPresent=false.</summary>
public sealed class BatteryService
{
    public NotchWindows.Core.Models.BatteryStatus GetStatus()
    {
        var status = PowerManager.BatteryStatus;
        if (status == Windows.System.Power.BatteryStatus.NotPresent)
            return new NotchWindows.Core.Models.BatteryStatus { IsPresent = false };

        return new NotchWindows.Core.Models.BatteryStatus
        {
            IsPresent = true,
            ChargePercent = PowerManager.RemainingChargePercent,
            IsCharging = status == Windows.System.Power.BatteryStatus.Charging,
        };
    }
}
