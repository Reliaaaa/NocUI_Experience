// DynamicBar - what this machine is connected to.
//
// Three sources, one channel:
//
// * Wi-Fi        WlanRegisterNotification for association and scan results,
//                WlanGetAvailableNetworkList for the list itself
// * Bluetooth    BluetoothFindFirstDevice over the paired set
// * Radios       Windows.Devices.Radios, which is the only supported way to
//                turn either radio on or off without administrator rights
//
// Everything is gated behind setEnabled: the lists are only worth keeping
// current while a surface that shows them is on screen, and a scan is a real
// cost - it takes seconds and briefly interrupts the connection's throughput.
//
// The Windows headers this needs have strict include ordering (wlanapi.h and
// BluetoothAPIs.h both want windows.h on their own terms) and this header is
// pulled in by the runner, so none of them appear here. The WLAN handle is a
// plain HANDLE and the radio work lives behind a pointer to an implementation
// declared in the .cpp.
#ifndef DYNAMICBAR_CONNECTIVITY_CONNECTIVITY_SERVICE_H_
#define DYNAMICBAR_CONNECTIVITY_CONNECTIVITY_SERVICE_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <atomic>
#include <memory>
#include <string>
#include <vector>

#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

/// One wireless network as the user thinks of it: a name, a strength, and
/// whether this machine already knows how to get on it.
struct WifiNetwork {
  std::string ssid;
  int signal = 0;  // 0..100 signal quality.
  bool secured = false;
  bool saved = false;  // A stored profile exists, so one click can connect.
  bool connected = false;
};

/// One paired Bluetooth device.
struct BluetoothDevice {
  std::string address;  // AA:BB:CC:DD:EE:FF
  std::string name;
  bool connected = false;
  bool paired = false;
  /// Coarse class of device, used only to pick an icon: audio, input, phone,
  /// computer, wearable, imaging or device.
  std::string kind;
};

class RadioWatcher;

class ConnectivityService {
 public:
  explicit ConnectivityService(flutter::BinaryMessenger* messenger);
  ~ConnectivityService();

  ConnectivityService(const ConnectivityService&) = delete;
  ConnectivityService& operator=(const ConnectivityService&) = delete;

  /// Called on the platform thread when the WLAN service reports that a scan
  /// finished, a connection completed, or an interface came or went.
  void OnWlanNotification(unsigned long code);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  void SetEnabled(bool enabled);

  // Wi-Fi ----------------------------------------------------------------
  bool OpenWlan();
  void CloseWlan();
  void RefreshWifi();
  bool RequestScan();
  bool ConnectWifi(const std::string& ssid);
  bool DisconnectWifi();

  // Bluetooth ------------------------------------------------------------
  void RefreshBluetooth();

  // Publishing -----------------------------------------------------------
  void PublishWifi();
  void PublishBluetooth();
  void PublishRadios();
  void PublishScanning();

  bool enabled_ = false;
  bool scanning_ = false;

  HANDLE wlan_ = nullptr;
  bool wlan_registered_ = false;
  bool has_wifi_interface_ = false;

  std::vector<WifiNetwork> wifi_;
  std::vector<BluetoothDevice> bluetooth_;
  bool bluetooth_present_ = false;

  std::string wifi_radio_ = "unknown";
  std::string bluetooth_radio_ = "unknown";

  std::unique_ptr<RadioWatcher> radios_;

  /// Guards callbacks that outlive this object: WLAN notifications arrive on a
  /// service thread and WinRT completions on a thread pool one.
  std::shared_ptr<std::atomic<bool>> alive_;

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_CONNECTIVITY_CONNECTIVITY_SERVICE_H_
