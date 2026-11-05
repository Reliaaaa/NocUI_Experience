#include "dynamicbar/connectivity/connectivity_service.h"

// windows.h arrives with the header above; these all require it first.
#include <wlanapi.h>

#include <bthsdpdef.h>
#include <BluetoothAPIs.h>

#include <windows.devices.radios.h>
#include <windows.foundation.h>
#include <windows.foundation.collections.h>

#include <wrl/client.h>
#include <wrl/event.h>
#include <wrl/implements.h>
#include <wrl/wrappers/corewrappers.h>

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdio>
#include <functional>
#include <set>
#include <utility>

#include "dynamicbar/core/dispatcher.h"
#include "dynamicbar/core/logging.h"

namespace WDR = ABI::Windows::Devices::Radios;
namespace WF = ABI::Windows::Foundation;
namespace WFC = ABI::Windows::Foundation::Collections;

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::FtmBase;
using Microsoft::WRL::Implements;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::Wrappers::HStringReference;

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Connectivity";
constexpr const char kMethodChannelName[] = "dynamicbar/connectivity";
constexpr const char kEventChannelName[] = "dynamicbar/connectivity/events";

/// Enough to fill any list the island can show without scrolling forever.
constexpr size_t kMaxNetworks = 24;
constexpr size_t kMaxDevices = 24;

/// Free-threaded handler, so WinRT completions arrive directly rather than
/// being marshalled through an apartment that may be busy.
template <typename THandler>
struct AgileHandler {
  using type =
      Implements<RuntimeClassFlags<Microsoft::WRL::ClassicCom>, THandler,
                 FtmBase>;
};

std::string SsidToUtf8(const DOT11_SSID& ssid) {
  if (ssid.uSSIDLength == 0) {
    return std::string();
  }
  return std::string(reinterpret_cast<const char*>(ssid.ucSSID),
                     ssid.uSSIDLength);
}

std::string FormatAddress(const BLUETOOTH_ADDRESS& address) {
  char buffer[18] = {};
  // rgBytes is little-endian, so the printable form runs backwards.
  ::sprintf_s(buffer, sizeof(buffer), "%02X:%02X:%02X:%02X:%02X:%02X",
              address.rgBytes[5], address.rgBytes[4], address.rgBytes[3],
              address.rgBytes[2], address.rgBytes[1], address.rgBytes[0]);
  return std::string(buffer);
}

/// The major device class, which is all the island needs: it picks an icon and
/// nothing else. Minor classes distinguish a mouse from a keyboard, which is a
/// distinction no one needs at thirteen pixels.
std::string DeviceKind(ULONG class_of_device) {
  switch ((class_of_device >> 8) & 0x1F) {
    case 0x01:
      return "computer";
    case 0x02:
      return "phone";
    case 0x04:
      return "audio";
    case 0x05:
      return "input";
    case 0x06:
      return "imaging";
    case 0x07:
      return "wearable";
    default:
      return "device";
  }
}

std::string RadioStateName(WDR::RadioState state) {
  switch (state) {
    case WDR::RadioState_On:
      return "on";
    case WDR::RadioState_Off:
      return "off";
    case WDR::RadioState_Disabled:
      return "disabled";
    case WDR::RadioState_Unknown:
    default:
      return "unknown";
  }
}

/// Context handed to the WLAN notification callback.
///
/// Deliberately never freed. A notification already in flight when the service
/// goes away still dereferences this, and one small allocation for the life of
/// the process is a better answer than a race during shutdown. The flag inside
/// says whether the service is still there.
struct WlanCallbackContext {
  ConnectivityService* service = nullptr;
  std::shared_ptr<std::atomic<bool>> alive;
};

void WINAPI WlanNotificationProc(PWLAN_NOTIFICATION_DATA data, PVOID context) {
  if (data == nullptr || context == nullptr ||
      data->NotificationSource != WLAN_NOTIFICATION_SOURCE_ACM) {
    return;
  }
  switch (data->NotificationCode) {
    case wlan_notification_acm_scan_complete:
    case wlan_notification_acm_scan_fail:
    case wlan_notification_acm_connection_complete:
    case wlan_notification_acm_disconnected:
    case wlan_notification_acm_interface_arrival:
    case wlan_notification_acm_interface_removal:
      break;
    default:
      return;
  }

  auto* wlan_context = static_cast<WlanCallbackContext*>(context);
  ConnectivityService* service = wlan_context->service;
  std::shared_ptr<std::atomic<bool>> alive = wlan_context->alive;
  const unsigned long code = data->NotificationCode;
  MainThreadDispatcher::Instance().Post([service, alive, code]() {
    if (service != nullptr && alive != nullptr && alive->load()) {
      service->OnWlanNotification(code);
    }
  });
}

}  // namespace

/// The Wi-Fi and Bluetooth radio switches.
///
/// Windows.Devices.Radios is the only supported way to turn either radio on or
/// off from a normal user process: WlanSetInterface's radio opcode needs
/// administrator rights, and the Bluetooth C API has no equivalent at all. It
/// is also the source the Quick Settings toggles use, so this agrees with what
/// the taskbar shows.
class RadioWatcher {
 public:
  using StateCallback =
      std::function<void(std::string wifi, std::string bluetooth)>;

  explicit RadioWatcher(StateCallback on_state)
      : on_state_(std::move(on_state)),
        alive_(std::make_shared<std::atomic<bool>>(true)) {}

  ~RadioWatcher() {
    alive_->store(false);
    Stop();
  }

  RadioWatcher(const RadioWatcher&) = delete;
  RadioWatcher& operator=(const RadioWatcher&) = delete;

  void Start() {
    if (started_) {
      return;
    }
    started_ = true;

    ComPtr<WDR::IRadioStatics> statics;
    HRESULT hr = ::RoGetActivationFactory(
        HStringReference(RuntimeClass_Windows_Devices_Radios_Radio).Get(),
        IID_PPV_ARGS(&statics));
    if (FAILED(hr) || statics == nullptr) {
      DB_LOG_WARN(kTag, "Radio API unavailable: " + FormatHResult(hr));
      return;
    }
    statics_ = statics;

    // Access has to be requested before the radios can be read. On the desktop
    // this is granted without a prompt; where it is not, the switches read as
    // unknown rather than claiming a state they cannot see.
    ComPtr<WF::IAsyncOperation<WDR::RadioAccessStatus>> access;
    hr = statics_->RequestAccessAsync(&access);
    if (FAILED(hr) || access == nullptr) {
      LoadRadios();
      return;
    }

    std::shared_ptr<std::atomic<bool>> alive = alive_;
    auto handler = Callback<typename AgileHandler<
        WF::IAsyncOperationCompletedHandler<WDR::RadioAccessStatus>>::type>(
        [this, alive](WF::IAsyncOperation<WDR::RadioAccessStatus>*,
                      AsyncStatus) -> HRESULT {
          MainThreadDispatcher::Instance().Post([this, alive]() {
            if (alive != nullptr && alive->load()) {
              LoadRadios();
            }
          });
          return S_OK;
        });
    if (FAILED(access->put_Completed(handler.Get()))) {
      LoadRadios();
    }
  }

  void Stop() {
    for (size_t i = 0; i < radios_.size(); ++i) {
      if (radios_[i] != nullptr && tokens_[i].value != 0) {
        radios_[i]->remove_StateChanged(tokens_[i]);
      }
    }
    radios_.clear();
    tokens_.clear();
    wifi_.Reset();
    bluetooth_.Reset();
    statics_.Reset();
    started_ = false;
    wifi_state_ = "unknown";
    bluetooth_state_ = "unknown";
  }

  std::string wifi_state() const { return wifi_state_; }
  std::string bluetooth_state() const { return bluetooth_state_; }

  /// Asks for a radio to change state. Returns whether the request was sent;
  /// the state itself arrives through the change handler, so the UI never has
  /// to assume it worked.
  bool SetState(const std::string& kind, bool on) {
    ComPtr<WDR::IRadio> radio = kind == "bluetooth" ? bluetooth_ : wifi_;
    if (radio == nullptr) {
      return false;
    }
    ComPtr<WF::IAsyncOperation<WDR::RadioAccessStatus>> operation;
    const HRESULT hr = radio->SetStateAsync(
        on ? WDR::RadioState_On : WDR::RadioState_Off, &operation);
    if (FAILED(hr) || operation == nullptr) {
      DB_LOG_WARN(kTag, "SetStateAsync failed: " + FormatHResult(hr));
      return false;
    }

    std::shared_ptr<std::atomic<bool>> alive = alive_;
    auto handler = Callback<typename AgileHandler<
        WF::IAsyncOperationCompletedHandler<WDR::RadioAccessStatus>>::type>(
        [this, alive](WF::IAsyncOperation<WDR::RadioAccessStatus>*,
                      AsyncStatus) -> HRESULT {
          MainThreadDispatcher::Instance().Post([this, alive]() {
            if (alive != nullptr && alive->load()) {
              ReadStates();
            }
          });
          return S_OK;
        });
    operation->put_Completed(handler.Get());
    return true;
  }

 private:
  void LoadRadios() {
    if (statics_ == nullptr) {
      return;
    }
    ComPtr<WF::IAsyncOperation<WFC::IVectorView<WDR::Radio*>*>> operation;
    const HRESULT hr = statics_->GetRadiosAsync(&operation);
    if (FAILED(hr) || operation == nullptr) {
      DB_LOG_WARN(kTag, "GetRadiosAsync failed: " + FormatHResult(hr));
      return;
    }

    std::shared_ptr<std::atomic<bool>> alive = alive_;
    auto handler =
        Callback<typename AgileHandler<WF::IAsyncOperationCompletedHandler<
            WFC::IVectorView<WDR::Radio*>*>>::type>(
            [this, alive](
                WF::IAsyncOperation<WFC::IVectorView<WDR::Radio*>*>* async,
                AsyncStatus status) -> HRESULT {
              if (status != AsyncStatus::Completed) {
                return S_OK;
              }
              ComPtr<WFC::IVectorView<WDR::Radio*>> view;
              if (FAILED(async->GetResults(&view)) || view == nullptr) {
                return S_OK;
              }
              MainThreadDispatcher::Instance().Post([this, alive, view]() {
                if (alive != nullptr && alive->load()) {
                  OnRadios(view);
                }
              });
              return S_OK;
            });
    operation->put_Completed(handler.Get());
  }

  void OnRadios(ComPtr<WFC::IVectorView<WDR::Radio*>> view) {
    unsigned int count = 0;
    if (view == nullptr || FAILED(view->get_Size(&count))) {
      return;
    }

    for (unsigned int i = 0; i < count; ++i) {
      ComPtr<WDR::IRadio> radio;
      if (FAILED(view->GetAt(i, &radio)) || radio == nullptr) {
        continue;
      }
      WDR::RadioKind kind = WDR::RadioKind_Other;
      if (FAILED(radio->get_Kind(&kind))) {
        continue;
      }
      if (kind == WDR::RadioKind_WiFi && wifi_ == nullptr) {
        wifi_ = radio;
      } else if (kind == WDR::RadioKind_Bluetooth && bluetooth_ == nullptr) {
        bluetooth_ = radio;
      } else {
        continue;
      }

      // One handler per radio, so a change made in Quick Settings shows up
      // here without anything being polled.
      std::shared_ptr<std::atomic<bool>> alive = alive_;
      auto changed = Callback<typename AgileHandler<
          WF::ITypedEventHandler<WDR::Radio*, IInspectable*>>::type>(
          [this, alive](WDR::IRadio*, IInspectable*) -> HRESULT {
            MainThreadDispatcher::Instance().Post([this, alive]() {
              if (alive != nullptr && alive->load()) {
                ReadStates();
              }
            });
            return S_OK;
          });
      EventRegistrationToken token = {};
      if (SUCCEEDED(radio->add_StateChanged(changed.Get(), &token))) {
        radios_.push_back(radio);
        tokens_.push_back(token);
      }
    }

    ReadStates();
  }

  void ReadStates() {
    wifi_state_ = ReadState(wifi_);
    bluetooth_state_ = ReadState(bluetooth_);
    if (on_state_) {
      on_state_(wifi_state_, bluetooth_state_);
    }
  }

  static std::string ReadState(const ComPtr<WDR::IRadio>& radio) {
    if (radio == nullptr) {
      return "absent";
    }
    WDR::RadioState state = WDR::RadioState_Unknown;
    if (FAILED(radio->get_State(&state))) {
      return "unknown";
    }
    return RadioStateName(state);
  }

  StateCallback on_state_;
  std::shared_ptr<std::atomic<bool>> alive_;
  bool started_ = false;

  ComPtr<WDR::IRadioStatics> statics_;
  ComPtr<WDR::IRadio> wifi_;
  ComPtr<WDR::IRadio> bluetooth_;
  std::vector<ComPtr<WDR::IRadio>> radios_;
  std::vector<EventRegistrationToken> tokens_;

  std::string wifi_state_ = "unknown";
  std::string bluetooth_state_ = "unknown";
};

ConnectivityService::ConnectivityService(flutter::BinaryMessenger* messenger)
    : alive_(std::make_shared<std::atomic<bool>>(true)) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });

  events_ = std::make_unique<EventEmitter>(messenger, kEventChannelName);
  events_->SetOnListen([this]() {
    PublishRadios();
    PublishWifi();
    PublishBluetooth();
  });

  radios_ = std::make_unique<RadioWatcher>(
      [this](std::string wifi, std::string bluetooth) {
        wifi_radio_ = std::move(wifi);
        bluetooth_radio_ = std::move(bluetooth);
        PublishRadios();
      });
}

ConnectivityService::~ConnectivityService() {
  SetEnabled(false);
  alive_->store(false);
  radios_.reset();
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void ConnectivityService::SetEnabled(bool enabled) {
  if (enabled_ == enabled) {
    return;
  }
  enabled_ = enabled;
  if (enabled) {
    OpenWlan();
    RefreshWifi();
    RefreshBluetooth();
    if (radios_ != nullptr) {
      radios_->Start();
    }
    DB_LOG_INFO(kTag, "Connectivity watching.");
  } else {
    CloseWlan();
    if (radios_ != nullptr) {
      radios_->Stop();
    }
    wifi_.clear();
    bluetooth_.clear();
    scanning_ = false;
    wifi_radio_ = "unknown";
    bluetooth_radio_ = "unknown";
    DB_LOG_INFO(kTag, "Connectivity idle.");
  }
  PublishRadios();
  PublishWifi();
  PublishBluetooth();
}

// --- Wi-Fi ------------------------------------------------------------------

bool ConnectivityService::OpenWlan() {
  if (wlan_ != nullptr) {
    return true;
  }
  DWORD negotiated = 0;
  if (::WlanOpenHandle(WLAN_API_VERSION_2_0, nullptr, &negotiated, &wlan_) !=
          ERROR_SUCCESS ||
      wlan_ == nullptr) {
    wlan_ = nullptr;
    return false;
  }

  // Leaked on purpose; see WlanCallbackContext.
  auto* context = new WlanCallbackContext{this, alive_};
  wlan_registered_ =
      ::WlanRegisterNotification(wlan_, WLAN_NOTIFICATION_SOURCE_ACM, TRUE,
                                 &WlanNotificationProc, context, nullptr,
                                 nullptr) == ERROR_SUCCESS;
  return true;
}

void ConnectivityService::CloseWlan() {
  if (wlan_ == nullptr) {
    return;
  }
  if (wlan_registered_) {
    ::WlanRegisterNotification(wlan_, WLAN_NOTIFICATION_SOURCE_NONE, TRUE,
                               nullptr, nullptr, nullptr, nullptr);
    wlan_registered_ = false;
  }
  ::WlanCloseHandle(wlan_, nullptr);
  wlan_ = nullptr;
  has_wifi_interface_ = false;
}

void ConnectivityService::OnWlanNotification(unsigned long code) {
  if (!enabled_) {
    return;
  }
  if (code == wlan_notification_acm_scan_complete ||
      code == wlan_notification_acm_scan_fail) {
    scanning_ = false;
    PublishScanning();
  }
  RefreshWifi();
  PublishWifi();
}

void ConnectivityService::RefreshWifi() {
  wifi_.clear();
  has_wifi_interface_ = false;
  if (wlan_ == nullptr && !OpenWlan()) {
    return;
  }

  PWLAN_INTERFACE_INFO_LIST interfaces = nullptr;
  if (::WlanEnumInterfaces(wlan_, nullptr, &interfaces) != ERROR_SUCCESS ||
      interfaces == nullptr) {
    return;
  }

  for (DWORD i = 0; i < interfaces->dwNumberOfItems; ++i) {
    const WLAN_INTERFACE_INFO& info = interfaces->InterfaceInfo[i];
    has_wifi_interface_ = true;

    // Which networks this machine already has credentials for. A saved network
    // is one click; an unsaved one needs Windows' own credential prompt, and
    // the island says so rather than failing silently.
    std::set<std::string> saved;
    PWLAN_PROFILE_INFO_LIST profiles = nullptr;
    if (::WlanGetProfileList(wlan_, &info.InterfaceGuid, nullptr, &profiles) ==
            ERROR_SUCCESS &&
        profiles != nullptr) {
      for (DWORD p = 0; p < profiles->dwNumberOfItems; ++p) {
        saved.insert(Utf8FromUtf16(profiles->ProfileInfo[p].strProfileName));
      }
      ::WlanFreeMemory(profiles);
    }

    PWLAN_AVAILABLE_NETWORK_LIST networks = nullptr;
    if (::WlanGetAvailableNetworkList(
            wlan_, &info.InterfaceGuid,
            WLAN_AVAILABLE_NETWORK_INCLUDE_ALL_MANUAL_HIDDEN_PROFILES, nullptr,
            &networks) != ERROR_SUCCESS ||
        networks == nullptr) {
      continue;
    }

    for (DWORD n = 0; n < networks->dwNumberOfItems; ++n) {
      const WLAN_AVAILABLE_NETWORK& entry = networks->Network[n];
      const std::string ssid = SsidToUtf8(entry.dot11Ssid);
      if (ssid.empty()) {
        // A hidden network has nothing to show and nothing to click.
        continue;
      }

      const bool connected =
          (entry.dwFlags & WLAN_AVAILABLE_NETWORK_CONNECTED) != 0;
      const int signal = static_cast<int>(entry.wlanSignalQuality);

      // The same network is reported once per profile and per BSS type, so it
      // is merged here on the name the user actually reads.
      auto existing = std::find_if(
          wifi_.begin(), wifi_.end(),
          [&ssid](const WifiNetwork& value) { return value.ssid == ssid; });
      if (existing != wifi_.end()) {
        existing->signal = (std::max)(existing->signal, signal);
        existing->connected = existing->connected || connected;
        existing->saved = existing->saved || saved.count(ssid) > 0;
        continue;
      }

      WifiNetwork network;
      network.ssid = ssid;
      network.signal = signal;
      network.secured = entry.bSecurityEnabled != FALSE;
      network.saved = saved.count(ssid) > 0;
      network.connected = connected;
      wifi_.push_back(network);
    }
    ::WlanFreeMemory(networks);
  }
  ::WlanFreeMemory(interfaces);

  // Connected first, then by strength: the order a person would put them in.
  std::sort(wifi_.begin(), wifi_.end(),
            [](const WifiNetwork& a, const WifiNetwork& b) {
              if (a.connected != b.connected) {
                return a.connected;
              }
              if (a.signal != b.signal) {
                return a.signal > b.signal;
              }
              return a.ssid < b.ssid;
            });
  if (wifi_.size() > kMaxNetworks) {
    wifi_.resize(kMaxNetworks);
  }
}

bool ConnectivityService::RequestScan() {
  if (wlan_ == nullptr && !OpenWlan()) {
    return false;
  }
  PWLAN_INTERFACE_INFO_LIST interfaces = nullptr;
  if (::WlanEnumInterfaces(wlan_, nullptr, &interfaces) != ERROR_SUCCESS ||
      interfaces == nullptr) {
    return false;
  }
  bool requested = false;
  for (DWORD i = 0; i < interfaces->dwNumberOfItems; ++i) {
    if (::WlanScan(wlan_, &interfaces->InterfaceInfo[i].InterfaceGuid, nullptr,
                   nullptr, nullptr) == ERROR_SUCCESS) {
      requested = true;
    }
  }
  ::WlanFreeMemory(interfaces);
  if (requested) {
    scanning_ = true;
    PublishScanning();
  }
  return requested;
}

bool ConnectivityService::ConnectWifi(const std::string& ssid) {
  if (ssid.empty() || (wlan_ == nullptr && !OpenWlan())) {
    return false;
  }
  PWLAN_INTERFACE_INFO_LIST interfaces = nullptr;
  if (::WlanEnumInterfaces(wlan_, nullptr, &interfaces) != ERROR_SUCCESS ||
      interfaces == nullptr) {
    return false;
  }

  // Connecting by profile name is the only thing that can be done without
  // asking for a password: the profile carries the credentials Windows already
  // has. A network with no profile is handed to Windows' own picker instead.
  const std::wstring profile = Utf16FromUtf8(ssid);
  WLAN_CONNECTION_PARAMETERS parameters = {};
  parameters.wlanConnectionMode = wlan_connection_mode_profile;
  parameters.strProfile = profile.c_str();
  parameters.dot11BssType = dot11_BSS_type_any;

  bool connected = false;
  for (DWORD i = 0; i < interfaces->dwNumberOfItems; ++i) {
    const DWORD status =
        ::WlanConnect(wlan_, &interfaces->InterfaceInfo[i].InterfaceGuid,
                      &parameters, nullptr);
    if (status == ERROR_SUCCESS) {
      connected = true;
      break;
    }
    DB_LOG_WARN(kTag, "WlanConnect refused (" + std::to_string(status) + ").");
  }
  ::WlanFreeMemory(interfaces);
  return connected;
}

bool ConnectivityService::DisconnectWifi() {
  if (wlan_ == nullptr && !OpenWlan()) {
    return false;
  }
  PWLAN_INTERFACE_INFO_LIST interfaces = nullptr;
  if (::WlanEnumInterfaces(wlan_, nullptr, &interfaces) != ERROR_SUCCESS ||
      interfaces == nullptr) {
    return false;
  }
  bool done = false;
  for (DWORD i = 0; i < interfaces->dwNumberOfItems; ++i) {
    if (::WlanDisconnect(wlan_, &interfaces->InterfaceInfo[i].InterfaceGuid,
                         nullptr) == ERROR_SUCCESS) {
      done = true;
    }
  }
  ::WlanFreeMemory(interfaces);
  return done;
}

// --- Bluetooth --------------------------------------------------------------

void ConnectivityService::RefreshBluetooth() {
  bluetooth_.clear();
  bluetooth_present_ = false;

  BLUETOOTH_FIND_RADIO_PARAMS radio_params = {};
  radio_params.dwSize = sizeof(radio_params);
  HANDLE radio = nullptr;
  HBLUETOOTH_RADIO_FIND radio_find =
      ::BluetoothFindFirstRadio(&radio_params, &radio);
  if (radio_find == nullptr) {
    return;
  }
  bluetooth_present_ = true;

  BLUETOOTH_DEVICE_SEARCH_PARAMS search = {};
  search.dwSize = sizeof(search);
  search.fReturnAuthenticated = TRUE;
  search.fReturnRemembered = TRUE;
  search.fReturnConnected = TRUE;
  // No inquiry: discovering unpaired devices costs ten seconds of radio time,
  // and pairing has to happen in Windows' own flow anyway.
  search.fReturnUnknown = FALSE;
  search.fIssueInquiry = FALSE;
  search.cTimeoutMultiplier = 0;
  search.hRadio = radio;

  BLUETOOTH_DEVICE_INFO info = {};
  info.dwSize = sizeof(info);
  HBLUETOOTH_DEVICE_FIND find = ::BluetoothFindFirstDevice(&search, &info);
  if (find != nullptr) {
    do {
      const std::string address = FormatAddress(info.Address);
      auto existing = std::find_if(bluetooth_.begin(), bluetooth_.end(),
                                   [&address](const BluetoothDevice& value) {
                                     return value.address == address;
                                   });
      if (existing != bluetooth_.end()) {
        existing->connected = existing->connected || info.fConnected != FALSE;
        continue;
      }

      BluetoothDevice device;
      device.address = address;
      device.name = Utf8FromUtf16(info.szName);
      if (device.name.empty()) {
        device.name = address;
      }
      device.connected = info.fConnected != FALSE;
      device.paired = info.fAuthenticated != FALSE;
      device.kind = DeviceKind(info.ulClassofDevice);
      bluetooth_.push_back(device);
    } while (::BluetoothFindNextDevice(find, &info) != FALSE &&
             bluetooth_.size() < kMaxDevices);
    ::BluetoothFindDeviceClose(find);
  }

  if (radio != nullptr) {
    ::CloseHandle(radio);
  }
  ::BluetoothFindRadioClose(radio_find);

  // Connected devices first: they are the ones a person is looking for.
  std::sort(bluetooth_.begin(), bluetooth_.end(),
            [](const BluetoothDevice& a, const BluetoothDevice& b) {
              if (a.connected != b.connected) {
                return a.connected;
              }
              return a.name < b.name;
            });
}

// --- Publishing -------------------------------------------------------------

void ConnectivityService::PublishWifi() {
  EncodableList networks;
  for (const WifiNetwork& network : wifi_) {
    EncodableMap map;
    map[EncodableValue("ssid")] = EncodableValue(network.ssid);
    map[EncodableValue("signal")] = EncodableValue(network.signal);
    map[EncodableValue("secured")] = EncodableValue(network.secured);
    map[EncodableValue("saved")] = EncodableValue(network.saved);
    map[EncodableValue("connected")] = EncodableValue(network.connected);
    networks.push_back(EncodableValue(map));
  }

  EncodableMap payload;
  payload[EncodableValue("available")] = EncodableValue(has_wifi_interface_);
  payload[EncodableValue("radio")] = EncodableValue(wifi_radio_);
  payload[EncodableValue("scanning")] = EncodableValue(scanning_);
  payload[EncodableValue("networks")] = EncodableValue(networks);
  events_->Emit("wifi", payload);
}

void ConnectivityService::PublishBluetooth() {
  EncodableList devices;
  for (const BluetoothDevice& device : bluetooth_) {
    EncodableMap map;
    map[EncodableValue("address")] = EncodableValue(device.address);
    map[EncodableValue("name")] = EncodableValue(device.name);
    map[EncodableValue("connected")] = EncodableValue(device.connected);
    map[EncodableValue("paired")] = EncodableValue(device.paired);
    map[EncodableValue("kind")] = EncodableValue(device.kind);
    devices.push_back(EncodableValue(map));
  }

  EncodableMap payload;
  payload[EncodableValue("available")] = EncodableValue(bluetooth_present_);
  payload[EncodableValue("radio")] = EncodableValue(bluetooth_radio_);
  payload[EncodableValue("devices")] = EncodableValue(devices);
  events_->Emit("bluetooth", payload);
}

void ConnectivityService::PublishRadios() {
  EncodableMap payload;
  payload[EncodableValue("wifi")] = EncodableValue(wifi_radio_);
  payload[EncodableValue("bluetooth")] = EncodableValue(bluetooth_radio_);
  events_->Emit("radios", payload);
}

void ConnectivityService::PublishScanning() {
  EncodableMap payload;
  payload[EncodableValue("scanning")] = EncodableValue(scanning_);
  events_->Emit("scanning", payload);
}

void ConnectivityService::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "setEnabled") {
    SetEnabled(GetBool(args, "enabled"));
    result->Success(EncodableValue(enabled_));
    return;
  }

  if (method == "refresh") {
    if (enabled_) {
      RefreshWifi();
      RefreshBluetooth();
      PublishWifi();
      PublishBluetooth();
    }
    result->Success(EncodableValue(enabled_));
    return;
  }

  if (method == "scan") {
    result->Success(EncodableValue(enabled_ && RequestScan()));
    return;
  }

  if (method == "connect") {
    result->Success(EncodableValue(ConnectWifi(GetString(args, "ssid"))));
    return;
  }

  if (method == "disconnect") {
    result->Success(EncodableValue(DisconnectWifi()));
    return;
  }

  if (method == "setRadio") {
    const std::string kind = GetString(args, "kind");
    const bool on = GetBool(args, "on");
    result->Success(
        EncodableValue(radios_ != nullptr && radios_->SetState(kind, on)));
    return;
  }

  result->NotImplemented();
}

}  // namespace dynamicbar
