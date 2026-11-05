#include "dynamicbar/hotkey/hotkey_service.h"

#include <flutter/standard_method_codec.h>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Hotkeys";
constexpr const char kMethodChannelName[] = "dynamicbar/hotkeys";
constexpr const char kEventChannelName[] = "dynamicbar/hotkeys/events";
constexpr const wchar_t kClassName[] = L"DynamicBarHotkeyHost";

}  // namespace

HotkeyService::HotkeyService(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
  events_ = std::make_unique<EventEmitter>(messenger, kEventChannelName);
}

HotkeyService::~HotkeyService() {
  UnregisterAll();
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
}

bool HotkeyService::EnsureWindow() {
  if (window_ != nullptr) {
    return true;
  }
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(WNDCLASSEXW);
  window_class.lpfnWndProc = HotkeyService::WndProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.lpszClassName = kClassName;
  ::RegisterClassExW(&window_class);

  window_ = ::CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                              nullptr, window_class.hInstance, this);
  if (window_ == nullptr) {
    DB_LOG_ERROR(kTag, "Failed to create the hotkey host window.");
    return false;
  }
  return true;
}

void HotkeyService::UnregisterAll() {
  if (window_ == nullptr) {
    registered_.clear();
    return;
  }
  for (const auto& entry : registered_) {
    ::UnregisterHotKey(window_, entry.first);
  }
  registered_.clear();
}

EncodableList HotkeyService::Apply(const EncodableList& bindings) {
  EncodableList outcomes;
  if (!EnsureWindow()) {
    return outcomes;
  }
  UnregisterAll();

  for (const EncodableValue& entry : bindings) {
    const EncodableMap* map = AsMap(&entry);
    if (map == nullptr) {
      continue;
    }
    HotkeyBinding binding;
    binding.id = GetString(*map, "id");
    binding.modifiers = static_cast<UINT>(GetInt(*map, "modifiers"));
    binding.virtual_key = static_cast<UINT>(GetInt(*map, "keyCode"));

    if (binding.id.empty() || binding.virtual_key == 0) {
      continue;
    }

    const int id = next_id_++;
    // MOD_NOREPEAT: holding the combination fires once, not forty times.
    const bool ok = ::RegisterHotKey(window_, id,
                                     binding.modifiers | MOD_NOREPEAT,
                                     binding.virtual_key) != FALSE;
    std::string error;
    if (ok) {
      registered_[id] = binding;
    } else {
      const DWORD code = ::GetLastError();
      error = code == ERROR_HOTKEY_ALREADY_REGISTERED
                  ? "alreadyInUse"
                  : "failed";
      DB_LOG_WARN(kTag, "Could not register hotkey '" + binding.id +
                            "': " + error);
    }

    outcomes.push_back(EncodableValue(EncodableMap{
        {EncodableValue("id"), EncodableValue(binding.id)},
        {EncodableValue("registered"), EncodableValue(ok)},
        {EncodableValue("error"), EncodableValue(error)},
    }));
  }

  DB_LOG_INFO(kTag, "Registered " + std::to_string(registered_.size()) +
                        " of " + std::to_string(bindings.size()) +
                        " shortcuts.");
  return outcomes;
}

void HotkeyService::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "apply") {
    const EncodableList* bindings = GetList(args, "bindings");
    result->Success(
        EncodableValue(Apply(bindings != nullptr ? *bindings : EncodableList())));
    return;
  }
  if (method == "clear") {
    UnregisterAll();
    result->Success();
    return;
  }
  DB_LOG_WARN(kTag, "Unimplemented hotkey method: " + method);
  result->NotImplemented();
}

// static
LRESULT CALLBACK HotkeyService::WndProc(HWND window, UINT message,
                                        WPARAM wparam,
                                        LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (auto* self = reinterpret_cast<HotkeyService*>(
                 ::GetWindowLongPtrW(window, GWLP_USERDATA))) {
    return self->HandleMessage(window, message, wparam, lparam);
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

LRESULT HotkeyService::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) noexcept {
  if (message == WM_HOTKEY) {
    const auto found = registered_.find(static_cast<int>(wparam));
    if (found != registered_.end()) {
      events_->Emit("pressed", EncodableMap{
                                   {EncodableValue("id"),
                                    EncodableValue(found->second.id)},
                               });
    }
    return 0;
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace dynamicbar
