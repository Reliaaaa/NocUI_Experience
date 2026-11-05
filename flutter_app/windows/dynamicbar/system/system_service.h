// DynamicBar - system status sensors.
//
// Every sensor here is event driven except one, and that exception is
// deliberate and gated:
//
// * battery      RegisterPowerSettingNotification (WM_POWERBROADCAST)
// * volume       IAudioEndpointVolumeCallback, plus IMMNotificationClient so a
//                change of default output device does not freeze the reading
// * mic / camera RegNotifyChangeKeyValue on the capability consent store
// * network      NotifyIpInterfaceChange, then a query on each change
// * CPU / memory polled, because Windows exposes no notification for either
//
// The CPU and memory poller only runs while Dart has explicitly asked for it,
// which the UI does only while a face showing those numbers is on screen. A
// tray utility has no business waking the CPU twice a second to report on the
// CPU.
#ifndef DYNAMICBAR_SYSTEM_SYSTEM_SERVICE_H_
#define DYNAMICBAR_SYSTEM_SYSTEM_SERVICE_H_

#include <windows.h>

#include <audiopolicy.h>
#include <endpointvolume.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

// The IP helper headers are deliberately not included here. They require
// winsock2.h to be seen before windows.h, and this header is pulled in by the
// runner, which includes windows.h on its own terms. The one networking handle
// this class keeps is a plain HANDLE, so the dependency stays in the .cpp.

#include <atomic>
#include <memory>
#include <string>
#include <thread>

#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

struct PowerStatus {
  bool hasBattery = false;
  bool charging = false;
  bool onAcPower = true;
  int percent = -1;
  int minutesRemaining = -1;
  bool saverOn = false;
};

struct VolumeStatus {
  bool available = false;
  double level = 0;
  bool muted = false;
};

struct PrivacyStatus {
  bool microphoneInUse = false;
  bool cameraInUse = false;
};

struct NetworkStatus {
  bool connected = false;
  bool hasInternet = false;
  bool wifi = false;
  std::string ssid;
  int signal = -1;  // 0..100, -1 when unknown.
};

struct PerformanceStatus {
  double cpuPercent = 0;
  double memoryPercent = 0;
  int64_t memoryUsedBytes = 0;
  int64_t memoryTotalBytes = 0;
  // Throughput across every operational, non-loopback adapter, in bytes per
  // second. Like CPU, these are deltas and mean nothing on the first sample.
  double networkDownBytes = 0;
  double networkUpBytes = 0;
  bool networkValid = false;
};

class SystemService {
 public:
  explicit SystemService(flutter::BinaryMessenger* messenger);
  ~SystemService();

  SystemService(const SystemService&) = delete;
  SystemService& operator=(const SystemService&) = delete;

  /// Called on the platform thread after an IP interface change.
  void OnNetworkChanged();

  /// Called when the foreground window changes, to re-check whether the user
  /// is in a state where an overlay would be unwelcome.
  void OnForegroundChanged();

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) noexcept;

  bool EnsureWindow();
  void SetEnabled(bool enabled);

  // Power ---------------------------------------------------------------
  void StartPower();
  void StopPower();
  void RefreshPower();

  // Volume --------------------------------------------------------------
  void StartVolume();
  void StopVolume();
  void AttachDefaultEndpoint();
  void RefreshVolume();

  // Privacy sensors -----------------------------------------------------
  void StartPrivacy();
  void StopPrivacy();
  void PrivacyWatchLoop();
  void RefreshPrivacy();

  // Network -------------------------------------------------------------
  void StartNetwork();
  void StopNetwork();
  void RefreshNetwork();

  // Presentation state --------------------------------------------------
  void StartForeground();
  void StopForeground();
  void RefreshPresentationState();
  bool ComputeForegroundCovers() const;
  void PublishOcclusion();

  // Performance ---------------------------------------------------------
  void SetPerformanceEnabled(bool enabled);
  void SamplePerformance();
  void SampleThroughput();

  void PublishAll();
  void PublishPower();
  void PublishVolume();
  void PublishPrivacy();
  void PublishNetwork();
  void PublishPerformance();
  void PublishPresentation();

  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  HWND window_ = nullptr;
  bool enabled_ = false;

  HPOWERNOTIFY battery_notify_ = nullptr;
  HPOWERNOTIFY power_source_notify_ = nullptr;
  HPOWERNOTIFY saver_notify_ = nullptr;

  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> device_enumerator_;
  Microsoft::WRL::ComPtr<IAudioEndpointVolume> endpoint_volume_;
  Microsoft::WRL::ComPtr<IAudioEndpointVolumeCallback> volume_callback_;
  Microsoft::WRL::ComPtr<IMMNotificationClient> device_callback_;

  std::thread privacy_thread_;
  std::atomic<bool> privacy_running_{false};
  HANDLE privacy_stop_ = nullptr;

  HANDLE network_notification_ = nullptr;
  HWINEVENTHOOK foreground_hook_ = nullptr;
  HWINEVENTHOOK location_hook_ = nullptr;
  std::string presentation_state_ = "normal";
  bool foreground_covers_ = false;
  UINT_PTR performance_timer_ = 0;
  bool performance_enabled_ = false;
  int performance_samples_ = 0;
  ULARGE_INTEGER last_idle_ = {};
  ULARGE_INTEGER last_kernel_ = {};
  ULARGE_INTEGER last_user_ = {};
  uint64_t last_octets_in_ = 0;
  uint64_t last_octets_out_ = 0;
  uint64_t last_octets_tick_ = 0;

  PowerStatus power_;
  VolumeStatus volume_;
  PrivacyStatus privacy_;
  NetworkStatus network_;
  PerformanceStatus performance_;

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_SYSTEM_SYSTEM_SERVICE_H_
