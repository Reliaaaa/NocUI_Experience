// winsock2.h must be seen before windows.h, which the service header pulls in.
// The IP helper headers then need windows.h, so they follow it. This ordering
// is load bearing; alphabetising these four lines breaks the build.
#include <winsock2.h>
#include <ws2tcpip.h>

#include "dynamicbar/system/system_service.h"

#include <iphlpapi.h>
#include <netioapi.h>

#include <flutter/standard_method_codec.h>
#include <netlistmgr.h>
#include <shellapi.h>
#include <wlanapi.h>

#include <functional>
#include <vector>

#include "dynamicbar/core/dispatcher.h"
#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "System";
constexpr const char kMethodChannelName[] = "dynamicbar/system";
constexpr const char kEventChannelName[] = "dynamicbar/system/events";
constexpr const wchar_t kClassName[] = L"DynamicBarSystemHost";

constexpr UINT_PTR kPerformanceTimerId = 1;

/// Two seconds is slow enough to be invisible on a power meter and fast enough
/// that a CPU graph still means something.
constexpr UINT kPerformanceIntervalMs = 1000;

// Power setting GUIDs, written out rather than taken from a header, because
// which SDK library exports them has moved between Windows SDK versions and a
// link error there is a poor trade for three constants.
const GUID kBatteryPercentageRemaining = {
    0xa7ad8041, 0xb45a, 0x4cae,
    {0x87, 0xa3, 0xee, 0xcb, 0xb4, 0x68, 0xa9, 0xe1}};
const GUID kAcDcPowerSource = {
    0x5d3e9a59, 0xe9d5, 0x4b00,
    {0xa6, 0xbd, 0xff, 0x34, 0xff, 0x51, 0x65, 0x48}};
const GUID kPowerSavingStatus = {
    0xe00958c0, 0xc213, 0x4ace,
    {0xac, 0x77, 0xfe, 0xcc, 0xed, 0x2e, 0xee, 0xa5}};

constexpr const wchar_t kConsentStoreRoot[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\"
    L"ConsentStore";

uint64_t ToUint64(const FILETIME& value) {
  ULARGE_INTEGER converted = {};
  converted.LowPart = value.dwLowDateTime;
  converted.HighPart = value.dwHighDateTime;
  return converted.QuadPart;
}

/// True when any application under this capability key is *currently* using the
/// device. Windows records a zero stop time while a capture is in progress.
bool CapabilityInUse(HKEY root, const wchar_t* capability) {
  std::wstring path = std::wstring(kConsentStoreRoot) + L"\\" + capability;
  HKEY key = nullptr;
  if (::RegOpenKeyExW(root, path.c_str(), 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }

  bool in_use = false;
  for (DWORD index = 0; !in_use; ++index) {
    wchar_t name[512] = {};
    DWORD name_length = 512;
    if (::RegEnumKeyExW(key, index, name, &name_length, nullptr, nullptr,
                        nullptr, nullptr) != ERROR_SUCCESS) {
      break;
    }

    // Desktop applications are nested one level deeper, under NonPackaged.
    const bool non_packaged = ::_wcsicmp(name, L"NonPackaged") == 0;
    HKEY app_root = nullptr;
    if (::RegOpenKeyExW(key, name, 0, KEY_READ, &app_root) != ERROR_SUCCESS) {
      continue;
    }

    if (non_packaged) {
      for (DWORD inner = 0; !in_use; ++inner) {
        wchar_t inner_name[512] = {};
        DWORD inner_length = 512;
        if (::RegEnumKeyExW(app_root, inner, inner_name, &inner_length, nullptr,
                            nullptr, nullptr, nullptr) != ERROR_SUCCESS) {
          break;
        }
        HKEY app = nullptr;
        if (::RegOpenKeyExW(app_root, inner_name, 0, KEY_READ, &app) !=
            ERROR_SUCCESS) {
          continue;
        }
        uint64_t stop = 1;
        DWORD size = sizeof(stop);
        if (::RegQueryValueExW(app, L"LastUsedTimeStop", nullptr, nullptr,
                               reinterpret_cast<LPBYTE>(&stop),
                               &size) == ERROR_SUCCESS &&
            stop == 0) {
          in_use = true;
        }
        ::RegCloseKey(app);
      }
    } else {
      uint64_t stop = 1;
      DWORD size = sizeof(stop);
      if (::RegQueryValueExW(app_root, L"LastUsedTimeStop", nullptr, nullptr,
                             reinterpret_cast<LPBYTE>(&stop),
                             &size) == ERROR_SUCCESS &&
          stop == 0) {
        in_use = true;
      }
    }
    ::RegCloseKey(app_root);
  }

  ::RegCloseKey(key);
  return in_use;
}

/// Minimal IAudioEndpointVolumeCallback. Hand rolled rather than pulled from a
/// framework: it has one method and needs no threading model of its own.
class VolumeCallback : public IAudioEndpointVolumeCallback {
 public:
  explicit VolumeCallback(std::function<void()> on_change)
      : on_change_(std::move(on_change)) {}

  ULONG STDMETHODCALLTYPE AddRef() override {
    return ::InterlockedIncrement(&ref_count_);
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG value = ::InterlockedDecrement(&ref_count_);
    if (value == 0) {
      delete this;
    }
    return value;
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) override {
    if (object == nullptr) {
      return E_POINTER;
    }
    if (iid == __uuidof(IUnknown) ||
        iid == __uuidof(IAudioEndpointVolumeCallback)) {
      *object = static_cast<IAudioEndpointVolumeCallback*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE OnNotify(PAUDIO_VOLUME_NOTIFICATION_DATA) override {
    if (on_change_) {
      on_change_();
    }
    return S_OK;
  }

 private:
  ~VolumeCallback() = default;

  LONG ref_count_ = 1;
  std::function<void()> on_change_;
};

/// Notices the default output device changing, so the volume reading follows
/// the user's headphones instead of freezing on the speakers.
class DeviceCallback : public IMMNotificationClient {
 public:
  explicit DeviceCallback(std::function<void()> on_default_changed)
      : on_default_changed_(std::move(on_default_changed)) {}

  ULONG STDMETHODCALLTYPE AddRef() override {
    return ::InterlockedIncrement(&ref_count_);
  }

  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG value = ::InterlockedDecrement(&ref_count_);
    if (value == 0) {
      delete this;
    }
    return value;
  }

  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) override {
    if (object == nullptr) {
      return E_POINTER;
    }
    if (iid == __uuidof(IUnknown) || iid == __uuidof(IMMNotificationClient)) {
      *object = static_cast<IMMNotificationClient*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(EDataFlow flow, ERole role,
                                                   LPCWSTR) override {
    if (flow == eRender && role == eConsole && on_default_changed_) {
      on_default_changed_();
    }
    return S_OK;
  }

  HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD) override {
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override { return S_OK; }
  HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR,
                                                   const PROPERTYKEY) override {
    return S_OK;
  }

 private:
  ~DeviceCallback() = default;

  LONG ref_count_ = 1;
  std::function<void()> on_default_changed_;
};

/// The only instance, so the WinEvent hook (which carries no user context) can
/// find its way back. There is exactly one SystemService for the lifetime of
/// the process.
SystemService* g_system_service = nullptr;

void CALLBACK ForegroundHookProc(HWINEVENTHOOK, DWORD event, HWND hwnd,
                                 LONG object, LONG, DWORD, DWORD) {
  if (g_system_service == nullptr) {
    return;
  }
  // Location changes fire for every child control; only whole top-level
  // windows matter, and only the events that can change what is in front.
  if (event == EVENT_OBJECT_LOCATIONCHANGE) {
    if (object != OBJID_WINDOW || hwnd == nullptr ||
        ::GetAncestor(hwnd, GA_ROOT) != hwnd) {
      return;
    }
  } else if (event != EVENT_SYSTEM_FOREGROUND &&
             event != EVENT_SYSTEM_MINIMIZESTART &&
             event != EVENT_SYSTEM_MINIMIZEEND &&
             event != EVENT_SYSTEM_MOVESIZEEND) {
    return;
  }
  // The hook is out-of-context, so this already runs on our message loop.
  g_system_service->OnForegroundChanged();
}

/// Windows that belong to the shell itself and never count as "an app in
/// front": the desktop, the taskbar, and the wallpaper host.
bool IsShellWindow(HWND hwnd) {
  wchar_t cls[64] = {};
  ::GetClassNameW(hwnd, cls, 64);
  return ::lstrcmpW(cls, L"Progman") == 0 || ::lstrcmpW(cls, L"WorkerW") == 0 ||
         ::lstrcmpW(cls, L"Shell_TrayWnd") == 0 ||
         ::lstrcmpW(cls, L"Shell_SecondaryTrayWnd") == 0;
}

void __stdcall OnInterfaceChange(PVOID context, PMIB_IPINTERFACE_ROW,
                                 MIB_NOTIFICATION_TYPE) {
  auto* service = static_cast<SystemService*>(context);
  if (service == nullptr) {
    return;
  }
  // Called on a threadpool thread; hop to the platform thread before touching
  // anything the engine can see.
  MainThreadDispatcher::Instance().Post([service]() {
    service->OnNetworkChanged();
  });
}

}  // namespace

SystemService::SystemService(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
  events_ = std::make_unique<EventEmitter>(messenger, kEventChannelName);
  events_->SetOnListen([this]() { PublishAll(); });
  g_system_service = this;
}

SystemService::~SystemService() {
  g_system_service = nullptr;
  SetEnabled(false);
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
}

bool SystemService::EnsureWindow() {
  if (window_ != nullptr) {
    return true;
  }
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(WNDCLASSEXW);
  window_class.lpfnWndProc = SystemService::WndProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.lpszClassName = kClassName;
  ::RegisterClassExW(&window_class);

  // A real (if invisible) top level window: power setting notifications are not
  // delivered to message-only windows.
  window_ = ::CreateWindowExW(0, kClassName, L"", WS_POPUP, 0, 0, 0, 0, nullptr,
                              nullptr, window_class.hInstance, this);
  if (window_ == nullptr) {
    DB_LOG_ERROR(kTag, "Failed to create the system host window.");
    return false;
  }
  return true;
}

void SystemService::SetEnabled(bool enabled) {
  if (enabled_ == enabled) {
    return;
  }
  enabled_ = enabled;
  if (enabled) {
    if (!EnsureWindow()) {
      enabled_ = false;
      return;
    }
    StartPower();
    StartVolume();
    StartPrivacy();
    StartNetwork();
    StartForeground();
    PublishAll();
    DB_LOG_INFO(kTag, "System sensors started.");
  } else {
    SetPerformanceEnabled(false);
    StopForeground();
    StopNetwork();
    StopPrivacy();
    StopVolume();
    StopPower();
    DB_LOG_INFO(kTag, "System sensors stopped.");
  }
}

// --- Power ------------------------------------------------------------------

void SystemService::StartPower() {
  if (window_ == nullptr || battery_notify_ != nullptr) {
    return;
  }
  battery_notify_ = ::RegisterPowerSettingNotification(
      window_, &kBatteryPercentageRemaining, DEVICE_NOTIFY_WINDOW_HANDLE);
  power_source_notify_ = ::RegisterPowerSettingNotification(
      window_, &kAcDcPowerSource, DEVICE_NOTIFY_WINDOW_HANDLE);
  saver_notify_ = ::RegisterPowerSettingNotification(
      window_, &kPowerSavingStatus, DEVICE_NOTIFY_WINDOW_HANDLE);
  RefreshPower();
}

void SystemService::StopPower() {
  if (battery_notify_ != nullptr) {
    ::UnregisterPowerSettingNotification(battery_notify_);
    battery_notify_ = nullptr;
  }
  if (power_source_notify_ != nullptr) {
    ::UnregisterPowerSettingNotification(power_source_notify_);
    power_source_notify_ = nullptr;
  }
  if (saver_notify_ != nullptr) {
    ::UnregisterPowerSettingNotification(saver_notify_);
    saver_notify_ = nullptr;
  }
}

void SystemService::RefreshPower() {
  SYSTEM_POWER_STATUS status = {};
  if (!::GetSystemPowerStatus(&status)) {
    power_ = PowerStatus();
    return;
  }
  const bool no_battery = (status.BatteryFlag & 128) != 0;
  power_.hasBattery = !no_battery && status.BatteryLifePercent != 255;
  power_.onAcPower = status.ACLineStatus == 1;
  power_.charging = (status.BatteryFlag & 8) != 0;
  power_.percent =
      status.BatteryLifePercent == 255 ? -1 : status.BatteryLifePercent;
  power_.minutesRemaining = status.BatteryLifeTime == 0xFFFFFFFF
                                ? -1
                                : static_cast<int>(status.BatteryLifeTime / 60);
  power_.saverOn = status.SystemStatusFlag == 1;
}

// --- Volume -----------------------------------------------------------------

void SystemService::StartVolume() {
  if (device_enumerator_ != nullptr) {
    return;
  }
  HRESULT hr = ::CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                  CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&device_enumerator_));
  if (FAILED(hr) || device_enumerator_ == nullptr) {
    DB_LOG_WARN(kTag, "Audio endpoints unavailable: " + FormatHResult(hr));
    return;
  }

  device_callback_.Attach(new DeviceCallback([this]() {
    MainThreadDispatcher::Instance().Post([this]() {
      AttachDefaultEndpoint();
      RefreshVolume();
      PublishVolume();
    });
  }));
  device_enumerator_->RegisterEndpointNotificationCallback(
      device_callback_.Get());

  AttachDefaultEndpoint();
  RefreshVolume();
}

void SystemService::AttachDefaultEndpoint() {
  if (device_enumerator_ == nullptr) {
    return;
  }
  if (endpoint_volume_ != nullptr && volume_callback_ != nullptr) {
    endpoint_volume_->UnregisterControlChangeNotify(volume_callback_.Get());
  }
  endpoint_volume_.Reset();

  Microsoft::WRL::ComPtr<IMMDevice> device;
  if (FAILED(device_enumerator_->GetDefaultAudioEndpoint(eRender, eConsole,
                                                         &device)) ||
      device == nullptr) {
    volume_.available = false;
    return;
  }

  if (FAILED(device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                              nullptr, &endpoint_volume_)) ||
      endpoint_volume_ == nullptr) {
    volume_.available = false;
    return;
  }

  if (volume_callback_ == nullptr) {
    volume_callback_.Attach(new VolumeCallback([this]() {
      MainThreadDispatcher::Instance().Post([this]() {
        RefreshVolume();
        PublishVolume();
      });
    }));
  }
  endpoint_volume_->RegisterControlChangeNotify(volume_callback_.Get());
  volume_.available = true;
}

void SystemService::StopVolume() {
  if (endpoint_volume_ != nullptr && volume_callback_ != nullptr) {
    endpoint_volume_->UnregisterControlChangeNotify(volume_callback_.Get());
  }
  endpoint_volume_.Reset();
  volume_callback_.Reset();
  if (device_enumerator_ != nullptr && device_callback_ != nullptr) {
    device_enumerator_->UnregisterEndpointNotificationCallback(
        device_callback_.Get());
  }
  device_callback_.Reset();
  device_enumerator_.Reset();
  volume_.available = false;
}

void SystemService::RefreshVolume() {
  if (endpoint_volume_ == nullptr) {
    volume_.available = false;
    return;
  }
  float level = 0;
  BOOL muted = FALSE;
  if (SUCCEEDED(endpoint_volume_->GetMasterVolumeLevelScalar(&level))) {
    volume_.level = level;
  }
  if (SUCCEEDED(endpoint_volume_->GetMute(&muted))) {
    volume_.muted = muted != FALSE;
  }
  volume_.available = true;
}

// --- Privacy sensors --------------------------------------------------------

void SystemService::StartPrivacy() {
  if (privacy_running_.load()) {
    return;
  }
  privacy_stop_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  privacy_running_.store(true);
  privacy_thread_ = std::thread(&SystemService::PrivacyWatchLoop, this);
  RefreshPrivacy();
}

void SystemService::StopPrivacy() {
  if (!privacy_running_.load()) {
    return;
  }
  privacy_running_.store(false);
  if (privacy_stop_ != nullptr) {
    ::SetEvent(privacy_stop_);
  }
  if (privacy_thread_.joinable()) {
    privacy_thread_.join();
  }
  if (privacy_stop_ != nullptr) {
    ::CloseHandle(privacy_stop_);
    privacy_stop_ = nullptr;
  }
}

void SystemService::PrivacyWatchLoop() {
  HKEY microphone = nullptr;
  HKEY camera = nullptr;
  const std::wstring mic_path = std::wstring(kConsentStoreRoot) + L"\\microphone";
  const std::wstring cam_path = std::wstring(kConsentStoreRoot) + L"\\webcam";
  ::RegOpenKeyExW(HKEY_CURRENT_USER, mic_path.c_str(), 0, KEY_NOTIFY,
                  &microphone);
  ::RegOpenKeyExW(HKEY_CURRENT_USER, cam_path.c_str(), 0, KEY_NOTIFY, &camera);

  HANDLE mic_event = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  HANDLE cam_event = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);

  while (privacy_running_.load()) {
    if (microphone != nullptr) {
      ::ResetEvent(mic_event);
      ::RegNotifyChangeKeyValue(microphone, TRUE,
                                REG_NOTIFY_CHANGE_LAST_SET |
                                    REG_NOTIFY_CHANGE_NAME,
                                mic_event, TRUE);
    }
    if (camera != nullptr) {
      ::ResetEvent(cam_event);
      ::RegNotifyChangeKeyValue(camera, TRUE,
                                REG_NOTIFY_CHANGE_LAST_SET |
                                    REG_NOTIFY_CHANGE_NAME,
                                cam_event, TRUE);
    }

    HANDLE waits[3] = {privacy_stop_, mic_event, cam_event};
    const DWORD result = ::WaitForMultipleObjects(3, waits, FALSE, INFINITE);
    if (result == WAIT_OBJECT_0 || !privacy_running_.load()) {
      break;
    }
    MainThreadDispatcher::Instance().Post([this]() {
      const bool was_mic = privacy_.microphoneInUse;
      const bool was_camera = privacy_.cameraInUse;
      RefreshPrivacy();
      if (privacy_.microphoneInUse != was_mic ||
          privacy_.cameraInUse != was_camera) {
        PublishPrivacy();
      }
    });
  }

  if (mic_event != nullptr) {
    ::CloseHandle(mic_event);
  }
  if (cam_event != nullptr) {
    ::CloseHandle(cam_event);
  }
  if (microphone != nullptr) {
    ::RegCloseKey(microphone);
  }
  if (camera != nullptr) {
    ::RegCloseKey(camera);
  }
}

void SystemService::RefreshPrivacy() {
  privacy_.microphoneInUse =
      CapabilityInUse(HKEY_CURRENT_USER, L"microphone") ||
      CapabilityInUse(HKEY_LOCAL_MACHINE, L"microphone");
  privacy_.cameraInUse = CapabilityInUse(HKEY_CURRENT_USER, L"webcam") ||
                         CapabilityInUse(HKEY_LOCAL_MACHINE, L"webcam");
}

// --- Network ----------------------------------------------------------------

void SystemService::StartNetwork() {
  if (network_notification_ != nullptr) {
    return;
  }
  const NETIO_STATUS status = ::NotifyIpInterfaceChange(
      AF_UNSPEC, OnInterfaceChange, this, FALSE, &network_notification_);
  if (status != NO_ERROR) {
    DB_LOG_WARN(kTag, "Network change notifications unavailable.");
    network_notification_ = nullptr;
  }
  RefreshNetwork();
}

void SystemService::StopNetwork() {
  if (network_notification_ != nullptr) {
    ::CancelMibChangeNotify2(network_notification_);
    network_notification_ = nullptr;
  }
}

void SystemService::OnNetworkChanged() {
  RefreshNetwork();
  PublishNetwork();
}

void SystemService::RefreshNetwork() {
  network_ = NetworkStatus();

  // Wi-Fi details, when a wireless interface is connected.
  HANDLE wlan = nullptr;
  DWORD negotiated = 0;
  if (::WlanOpenHandle(WLAN_API_VERSION_2_0, nullptr, &negotiated, &wlan) ==
          ERROR_SUCCESS &&
      wlan != nullptr) {
    PWLAN_INTERFACE_INFO_LIST interfaces = nullptr;
    if (::WlanEnumInterfaces(wlan, nullptr, &interfaces) == ERROR_SUCCESS &&
        interfaces != nullptr) {
      for (DWORD i = 0; i < interfaces->dwNumberOfItems; ++i) {
        const WLAN_INTERFACE_INFO& info = interfaces->InterfaceInfo[i];
        if (info.isState != wlan_interface_state_connected) {
          continue;
        }
        DWORD size = 0;
        PWLAN_CONNECTION_ATTRIBUTES attributes = nullptr;
        WLAN_OPCODE_VALUE_TYPE opcode = wlan_opcode_value_type_invalid;
        if (::WlanQueryInterface(wlan, &info.InterfaceGuid,
                                 wlan_intf_opcode_current_connection, nullptr,
                                 &size,
                                 reinterpret_cast<PVOID*>(&attributes),
                                 &opcode) == ERROR_SUCCESS &&
            attributes != nullptr) {
          network_.wifi = true;
          network_.connected = true;
          network_.signal = static_cast<int>(
              attributes->wlanAssociationAttributes.wlanSignalQuality);
          const DOT11_SSID& ssid =
              attributes->wlanAssociationAttributes.dot11Ssid;
          network_.ssid.assign(reinterpret_cast<const char*>(ssid.ucSSID),
                               ssid.uSSIDLength);
          ::WlanFreeMemory(attributes);
        }
        break;
      }
      ::WlanFreeMemory(interfaces);
    }
    ::WlanCloseHandle(wlan, nullptr);
  }

  // Reachability, wired or wireless. INetworkListManager is the same source the
  // taskbar network icon uses.
  Microsoft::WRL::ComPtr<INetworkListManager> manager;
  if (SUCCEEDED(::CoCreateInstance(__uuidof(NetworkListManager), nullptr,
                                   CLSCTX_ALL, IID_PPV_ARGS(&manager))) &&
      manager != nullptr) {
    NLM_CONNECTIVITY connectivity = NLM_CONNECTIVITY_DISCONNECTED;
    if (SUCCEEDED(manager->GetConnectivity(&connectivity))) {
      network_.hasInternet =
          (connectivity & (NLM_CONNECTIVITY_IPV4_INTERNET |
                           NLM_CONNECTIVITY_IPV6_INTERNET)) != 0;
      network_.connected =
          network_.connected ||
          (connectivity & (NLM_CONNECTIVITY_IPV4_LOCALNETWORK |
                           NLM_CONNECTIVITY_IPV6_LOCALNETWORK |
                           NLM_CONNECTIVITY_IPV4_INTERNET |
                           NLM_CONNECTIVITY_IPV6_INTERNET)) != 0;
    }
  }
}

// --- Presentation state -----------------------------------------------------

void SystemService::StartForeground() {
  if (foreground_hook_ != nullptr) {
    return;
  }
  // WINEVENT_OUTOFCONTEXT keeps the hook out of other processes entirely: the
  // notification is posted to our own message loop instead of injecting a DLL.
  foreground_hook_ = ::SetWinEventHook(
      EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_MINIMIZEEND, nullptr,
      &ForegroundHookProc, 0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
  location_hook_ = ::SetWinEventHook(
      EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_LOCATIONCHANGE, nullptr,
      &ForegroundHookProc, 0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
  RefreshPresentationState();
  foreground_covers_ = ComputeForegroundCovers();
}

/// True when the foreground window is maximised, or fills its monitor. The
/// island sits over the title-bar strip of exactly such windows, which is where
/// it would be in the way.
bool SystemService::ComputeForegroundCovers() const {
  HWND fg = ::GetForegroundWindow();
  if (fg == nullptr || ::IsIconic(fg) || !::IsWindowVisible(fg) ||
      IsShellWindow(fg)) {
    return false;
  }
  DWORD pid = 0;
  ::GetWindowThreadProcessId(fg, &pid);
  if (pid == ::GetCurrentProcessId()) {
    // Our own island has focus; whatever is behind it has not changed.
    return foreground_covers_;
  }
  if (::IsZoomed(fg)) {
    return true;
  }
  RECT rect = {};
  if (!::GetWindowRect(fg, &rect)) {
    return false;
  }
  HMONITOR monitor = ::MonitorFromWindow(fg, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!::GetMonitorInfoW(monitor, &info)) {
    return false;
  }
  return rect.left <= info.rcMonitor.left && rect.top <= info.rcMonitor.top &&
         rect.right >= info.rcMonitor.right &&
         rect.bottom >= info.rcMonitor.bottom;
}

void SystemService::PublishOcclusion() {
  events_->Emit("occlusion",
                EncodableMap{{EncodableValue("covered"),
                              EncodableValue(foreground_covers_)}});
}

void SystemService::StopForeground() {
  if (foreground_hook_ != nullptr) {
    ::UnhookWinEvent(foreground_hook_);
    foreground_hook_ = nullptr;
  }
  if (location_hook_ != nullptr) {
    ::UnhookWinEvent(location_hook_);
    location_hook_ = nullptr;
  }
}

void SystemService::OnForegroundChanged() {
  const std::string previous = presentation_state_;
  RefreshPresentationState();
  if (presentation_state_ != previous) {
    PublishPresentation();
  }
  const bool covers = ComputeForegroundCovers();
  if (covers != foreground_covers_) {
    foreground_covers_ = covers;
    PublishOcclusion();
  }
}

void SystemService::RefreshPresentationState() {
  QUERY_USER_NOTIFICATION_STATE state = QUNS_ACCEPTS_NOTIFICATIONS;
  if (FAILED(::SHQueryUserNotificationState(&state))) {
    presentation_state_ = "normal";
    return;
  }
  switch (state) {
    case QUNS_BUSY:
      presentation_state_ = "busy";
      break;
    case QUNS_RUNNING_D3D_FULL_SCREEN:
      presentation_state_ = "fullscreen";
      break;
    case QUNS_PRESENTATION_MODE:
      presentation_state_ = "presentation";
      break;
    case QUNS_QUIET_TIME:
      presentation_state_ = "quiet";
      break;
    case QUNS_APP:
      presentation_state_ = "fullscreenApp";
      break;
    default:
      presentation_state_ = "normal";
      break;
  }
}

// --- Performance ------------------------------------------------------------

void SystemService::SetPerformanceEnabled(bool enabled) {
  if (performance_enabled_ == enabled) {
    return;
  }
  performance_enabled_ = enabled;
  if (enabled) {
    if (!EnsureWindow()) {
      performance_enabled_ = false;
      return;
    }
    // Seeds the counters. Memory is valid immediately, so publish at once
    // rather than leaving the page blank for a whole interval; CPU needs a
    // second sample before it means anything and is marked accordingly.
    performance_samples_ = 0;
    performance_.networkValid = false;
    last_octets_tick_ = 0;
    SamplePerformance();
    PublishPerformance();
    performance_timer_ = ::SetTimer(window_, kPerformanceTimerId,
                                    kPerformanceIntervalMs, nullptr);
    DB_LOG_DEBUG(kTag, "CPU and memory sampling started.");
  } else if (performance_timer_ != 0) {
    ::KillTimer(window_, kPerformanceTimerId);
    performance_timer_ = 0;
    DB_LOG_DEBUG(kTag, "CPU and memory sampling stopped.");
  }
}

void SystemService::SamplePerformance() {
  FILETIME idle = {};
  FILETIME kernel = {};
  FILETIME user = {};
  if (::GetSystemTimes(&idle, &kernel, &user)) {
    const uint64_t idle_now = ToUint64(idle);
    const uint64_t kernel_now = ToUint64(kernel);
    const uint64_t user_now = ToUint64(user);

    const uint64_t idle_delta = idle_now - last_idle_.QuadPart;
    const uint64_t kernel_delta = kernel_now - last_kernel_.QuadPart;
    const uint64_t user_delta = user_now - last_user_.QuadPart;
    const uint64_t total = kernel_delta + user_delta;

    if (last_idle_.QuadPart != 0 && total > 0) {
      const double busy = static_cast<double>(total - idle_delta);
      performance_.cpuPercent = (busy / static_cast<double>(total)) * 100.0;
      if (performance_.cpuPercent < 0) {
        performance_.cpuPercent = 0;
      } else if (performance_.cpuPercent > 100) {
        performance_.cpuPercent = 100;
      }
    }
    last_idle_.QuadPart = idle_now;
    last_kernel_.QuadPart = kernel_now;
    last_user_.QuadPart = user_now;
  }

  SampleThroughput();
  ++performance_samples_;

  MEMORYSTATUSEX memory = {};
  memory.dwLength = sizeof(memory);
  if (::GlobalMemoryStatusEx(&memory)) {
    performance_.memoryPercent = static_cast<double>(memory.dwMemoryLoad);
    performance_.memoryTotalBytes = static_cast<int64_t>(memory.ullTotalPhys);
    performance_.memoryUsedBytes =
        static_cast<int64_t>(memory.ullTotalPhys - memory.ullAvailPhys);
  }
}

/// Sums the byte counters of every adapter that is actually carrying traffic.
///
/// One call per second while a page showing the graph is open; nothing at all
/// otherwise. Loopback and filter pseudo-interfaces are excluded so a VPN or a
/// packet filter cannot double-count the same bytes.
void SystemService::SampleThroughput() {
  MIB_IF_TABLE2* table = nullptr;
  if (::GetIfTable2Ex(MibIfTableNormal, &table) != NO_ERROR ||
      table == nullptr) {
    return;
  }

  uint64_t in_total = 0;
  uint64_t out_total = 0;
  for (ULONG i = 0; i < table->NumEntries; ++i) {
    const MIB_IF_ROW2& row = table->Table[i];
    if (row.Type == IF_TYPE_SOFTWARE_LOOPBACK ||
        row.OperStatus != IfOperStatusUp ||
        row.InterfaceAndOperStatusFlags.FilterInterface) {
      continue;
    }
    in_total += row.InOctets;
    out_total += row.OutOctets;
  }
  ::FreeMibTable(table);

  const uint64_t now = ::GetTickCount64();
  if (last_octets_tick_ != 0 && now > last_octets_tick_) {
    const double seconds = static_cast<double>(now - last_octets_tick_) / 1000.0;
    // Counters can wrap or reset when an adapter is re-enumerated; a negative
    // delta means the baseline is gone, so report nothing rather than a spike.
    performance_.networkDownBytes =
        in_total >= last_octets_in_
            ? static_cast<double>(in_total - last_octets_in_) / seconds
            : 0.0;
    performance_.networkUpBytes =
        out_total >= last_octets_out_
            ? static_cast<double>(out_total - last_octets_out_) / seconds
            : 0.0;
    performance_.networkValid = true;
  }
  last_octets_in_ = in_total;
  last_octets_out_ = out_total;
  last_octets_tick_ = now;
}

// --- Publishing -------------------------------------------------------------

void SystemService::PublishAll() {
  PublishPower();
  PublishVolume();
  PublishPrivacy();
  PublishNetwork();
  PublishPresentation();
  PublishOcclusion();
  if (performance_enabled_) {
    PublishPerformance();
  }
}

void SystemService::PublishPower() {
  events_->Emit(
      "power",
      EncodableMap{
          {EncodableValue("hasBattery"), EncodableValue(power_.hasBattery)},
          {EncodableValue("charging"), EncodableValue(power_.charging)},
          {EncodableValue("onAcPower"), EncodableValue(power_.onAcPower)},
          {EncodableValue("percent"),
           EncodableValue(static_cast<int64_t>(power_.percent))},
          {EncodableValue("minutesRemaining"),
           EncodableValue(static_cast<int64_t>(power_.minutesRemaining))},
          {EncodableValue("saverOn"), EncodableValue(power_.saverOn)},
      });
}

void SystemService::PublishVolume() {
  events_->Emit("volume",
                EncodableMap{
                    {EncodableValue("available"),
                     EncodableValue(volume_.available)},
                    {EncodableValue("level"), EncodableValue(volume_.level)},
                    {EncodableValue("muted"), EncodableValue(volume_.muted)},
                });
}

void SystemService::PublishPrivacy() {
  events_->Emit("privacy",
                EncodableMap{
                    {EncodableValue("microphone"),
                     EncodableValue(privacy_.microphoneInUse)},
                    {EncodableValue("camera"),
                     EncodableValue(privacy_.cameraInUse)},
                });
}

void SystemService::PublishNetwork() {
  events_->Emit(
      "network",
      EncodableMap{
          {EncodableValue("connected"), EncodableValue(network_.connected)},
          {EncodableValue("internet"), EncodableValue(network_.hasInternet)},
          {EncodableValue("wifi"), EncodableValue(network_.wifi)},
          {EncodableValue("ssid"), EncodableValue(network_.ssid)},
          {EncodableValue("signal"),
           EncodableValue(static_cast<int64_t>(network_.signal))},
      });
}

void SystemService::PublishPresentation() {
  events_->Emit("presentation",
                EncodableMap{
                    {EncodableValue("state"),
                     EncodableValue(presentation_state_)},
                });
}

void SystemService::PublishPerformance() {
  events_->Emit(
      "performance",
      EncodableMap{
          {EncodableValue("cpu"), EncodableValue(performance_.cpuPercent)},
          {EncodableValue("memory"),
           EncodableValue(performance_.memoryPercent)},
          {EncodableValue("memoryUsed"),
           EncodableValue(performance_.memoryUsedBytes)},
          {EncodableValue("memoryTotal"),
           EncodableValue(performance_.memoryTotalBytes)},
          {EncodableValue("networkDown"),
           EncodableValue(performance_.networkDownBytes)},
          {EncodableValue("networkUp"),
           EncodableValue(performance_.networkUpBytes)},
          {EncodableValue("networkValid"),
           EncodableValue(performance_.networkValid)},
          // One sample cannot produce a CPU figure; it is a delta.
          {EncodableValue("cpuValid"),
           EncodableValue(performance_samples_ >= 2)},
      });
}

void SystemService::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "setEnabled") {
    SetEnabled(GetBool(args, "enabled", false));
    result->Success(EncodableValue(enabled_));
    return;
  }
  if (method == "setPerformanceEnabled") {
    SetPerformanceEnabled(GetBool(args, "enabled", false));
    result->Success(EncodableValue(performance_enabled_));
    return;
  }
  if (method == "refresh") {
    RefreshPower();
    RefreshVolume();
    RefreshPrivacy();
    RefreshNetwork();
    RefreshPresentationState();
    PublishAll();
    result->Success();
    return;
  }
  if (method == "setVolume") {
    if (endpoint_volume_ == nullptr) {
      result->Success(EncodableValue(false));
      return;
    }
    const float level =
        static_cast<float>(GetDouble(args, "level", volume_.level));
    const HRESULT hr = endpoint_volume_->SetMasterVolumeLevelScalar(
        level < 0 ? 0.0f : (level > 1 ? 1.0f : level), nullptr);
    result->Success(EncodableValue(SUCCEEDED(hr)));
    return;
  }
  if (method == "setMuted") {
    if (endpoint_volume_ == nullptr) {
      result->Success(EncodableValue(false));
      return;
    }
    const HRESULT hr =
        endpoint_volume_->SetMute(GetBool(args, "muted", false), nullptr);
    result->Success(EncodableValue(SUCCEEDED(hr)));
    return;
  }
  DB_LOG_WARN(kTag, "Unimplemented system method: " + method);
  result->NotImplemented();
}

// static
LRESULT CALLBACK SystemService::WndProc(HWND window, UINT message,
                                        WPARAM wparam,
                                        LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (auto* self = reinterpret_cast<SystemService*>(
                 ::GetWindowLongPtrW(window, GWLP_USERDATA))) {
    return self->HandleMessage(window, message, wparam, lparam);
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

LRESULT SystemService::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) noexcept {
  switch (message) {
    case WM_POWERBROADCAST:
      if (wparam == PBT_POWERSETTINGCHANGE || wparam == PBT_APMPOWERSTATUSCHANGE) {
        RefreshPower();
        PublishPower();
      }
      return TRUE;

    case WM_TIMER:
      if (wparam == kPerformanceTimerId) {
        SamplePerformance();
        PublishPerformance();
        return 0;
      }
      break;

    default:
      break;
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace dynamicbar
