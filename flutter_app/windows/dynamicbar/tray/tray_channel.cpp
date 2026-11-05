#include "dynamicbar/tray/tray_channel.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Tray";
constexpr const char kMethodChannelName[] = "dynamicbar/tray";
constexpr const char kEventChannelName[] = "dynamicbar/tray/events";
constexpr const wchar_t kClassName[] = L"DynamicBarTrayHost";
constexpr UINT kTrayCallbackMessage = WM_APP + 0x200;
constexpr UINT kTrayIconId = 1;
constexpr UINT kFirstCommandId = 0x1000;

}  // namespace

TrayChannel::TrayChannel(flutter::BinaryMessenger* messenger,
                         int icon_resource_id)
    : icon_resource_id_(icon_resource_id) {
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

TrayChannel::~TrayChannel() {
  RemoveIcon();
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
  if (icon_ != nullptr) {
    ::DestroyIcon(icon_);
    icon_ = nullptr;
  }
}

bool TrayChannel::EnsureWindow() {
  if (window_ != nullptr) {
    return true;
  }
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(WNDCLASSEXW);
  window_class.lpfnWndProc = TrayChannel::WndProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.lpszClassName = kClassName;
  ::RegisterClassExW(&window_class);

  window_ = ::CreateWindowExW(0, kClassName, L"DynamicBar", WS_POPUP, 0, 0, 0,
                              0, nullptr, nullptr, window_class.hInstance,
                              this);
  if (window_ == nullptr) {
    DB_LOG_ERROR(kTag, "Failed to create the tray host window.");
    return false;
  }
  taskbar_created_message_ = ::RegisterWindowMessageW(L"TaskbarCreated");
  return true;
}

bool TrayChannel::AddIcon() {
  if (!EnsureWindow()) {
    return false;
  }
  if (icon_ == nullptr && icon_resource_id_ != 0) {
    icon_ = static_cast<HICON>(::LoadImageW(
        ::GetModuleHandleW(nullptr), MAKEINTRESOURCEW(icon_resource_id_),
        IMAGE_ICON, ::GetSystemMetrics(SM_CXSMICON),
        ::GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR));
  }

  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(NOTIFYICONDATAW);
  data.hWnd = window_;
  data.uID = kTrayIconId;
  data.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  data.uCallbackMessage = kTrayCallbackMessage;
  data.hIcon = icon_;
  ::wcsncpy_s(data.szTip, tooltip_.c_str(), _TRUNCATE);

  if (icon_added_) {
    ::Shell_NotifyIconW(NIM_MODIFY, &data);
    return true;
  }
  if (!::Shell_NotifyIconW(NIM_ADD, &data)) {
    DB_LOG_ERROR(kTag, "Shell_NotifyIcon(NIM_ADD) failed.");
    return false;
  }
  data.uVersion = NOTIFYICON_VERSION_4;
  ::Shell_NotifyIconW(NIM_SETVERSION, &data);
  icon_added_ = true;
  DB_LOG_INFO(kTag, "Tray icon added.");
  return true;
}

void TrayChannel::RemoveIcon() {
  if (!icon_added_ || window_ == nullptr) {
    return;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(NOTIFYICONDATAW);
  data.hWnd = window_;
  data.uID = kTrayIconId;
  ::Shell_NotifyIconW(NIM_DELETE, &data);
  icon_added_ = false;
}

void TrayChannel::UpdateTooltip() {
  if (!icon_added_) {
    return;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(NOTIFYICONDATAW);
  data.hWnd = window_;
  data.uID = kTrayIconId;
  data.uFlags = NIF_TIP | NIF_SHOWTIP;
  ::wcsncpy_s(data.szTip, tooltip_.c_str(), _TRUNCATE);
  ::Shell_NotifyIconW(NIM_MODIFY, &data);
}

void TrayChannel::ShowBalloon(const std::wstring& title,
                              const std::wstring& body, int level) {
  if (!icon_added_) {
    return;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(NOTIFYICONDATAW);
  data.hWnd = window_;
  data.uID = kTrayIconId;
  data.uFlags = NIF_INFO;
  ::wcsncpy_s(data.szInfoTitle, title.c_str(), _TRUNCATE);
  ::wcsncpy_s(data.szInfo, body.c_str(), _TRUNCATE);
  switch (level) {
    case 1:
      data.dwInfoFlags = NIIF_WARNING;
      break;
    case 2:
      data.dwInfoFlags = NIIF_ERROR;
      break;
    default:
      data.dwInfoFlags = NIIF_INFO;
      break;
  }
  ::Shell_NotifyIconW(NIM_MODIFY, &data);
}

void TrayChannel::ParseMenu(const EncodableList& list,
                            std::vector<TrayMenuItem>* out) {
  for (const EncodableValue& entry : list) {
    const EncodableMap* map = AsMap(&entry);
    if (map == nullptr) {
      continue;
    }
    TrayMenuItem item;
    item.id = GetString(*map, "id");
    item.label = Utf16FromUtf8(GetString(*map, "label"));
    item.type = GetString(*map, "type", "normal");
    item.enabled = GetBool(*map, "enabled", true);
    item.checked = GetBool(*map, "checked", false);
    item.is_default = GetBool(*map, "isDefault", false);
    if (const EncodableList* children = GetList(*map, "items")) {
      ParseMenu(*children, &item.children);
    }
    out->push_back(std::move(item));
  }
}

HMENU TrayChannel::BuildMenu(const std::vector<TrayMenuItem>& items) {
  HMENU menu = ::CreatePopupMenu();
  if (menu == nullptr) {
    return nullptr;
  }
  for (const TrayMenuItem& item : items) {
    if (item.type == "separator") {
      ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
      continue;
    }
    if (item.type == "submenu" && !item.children.empty()) {
      HMENU submenu = BuildMenu(item.children);
      ::AppendMenuW(menu, MF_POPUP | (item.enabled ? MF_ENABLED : MF_GRAYED),
                    reinterpret_cast<UINT_PTR>(submenu), item.label.c_str());
      continue;
    }
    command_ids_.push_back(item.id);
    const UINT command =
        kFirstCommandId + static_cast<UINT>(command_ids_.size()) - 1;
    UINT flags = MF_STRING;
    flags |= item.enabled ? MF_ENABLED : MF_GRAYED;
    if (item.type == "checkbox" && item.checked) {
      flags |= MF_CHECKED;
    }
    ::AppendMenuW(menu, flags, command, item.label.c_str());
    if (item.is_default) {
      ::SetMenuDefaultItem(menu, command, FALSE);
    }
  }
  return menu;
}

void TrayChannel::ShowContextMenu() {
  if (window_ == nullptr || menu_.empty()) {
    return;
  }
  command_ids_.clear();
  HMENU menu = BuildMenu(menu_);
  if (menu == nullptr) {
    return;
  }
  POINT cursor = {};
  ::GetCursorPos(&cursor);

  // Required so the menu dismisses when the user clicks elsewhere.
  ::SetForegroundWindow(window_);
  const int command = ::TrackPopupMenuEx(
      menu, TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY, cursor.x, cursor.y,
      window_, nullptr);
  ::PostMessageW(window_, WM_NULL, 0, 0);
  ::DestroyMenu(menu);

  if (command >= static_cast<int>(kFirstCommandId)) {
    const size_t index = static_cast<size_t>(command) - kFirstCommandId;
    if (index < command_ids_.size()) {
      events_->Emit("menu", EncodableMap{{EncodableValue("id"),
                                          EncodableValue(command_ids_[index])}});
    }
  }
}

void TrayChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "install") {
    if (FindValue(args, "tooltip") != nullptr) {
      tooltip_ = Utf16FromUtf8(GetString(args, "tooltip", "NocUI Experience"));
    }
    result->Success(EncodableValue(AddIcon()));
    return;
  }
  if (method == "setTooltip") {
    tooltip_ = Utf16FromUtf8(GetString(args, "tooltip", "NocUI Experience"));
    UpdateTooltip();
    result->Success();
    return;
  }
  if (method == "setMenu") {
    menu_.clear();
    if (const EncodableList* items = GetList(args, "items")) {
      ParseMenu(*items, &menu_);
    }
    result->Success();
    return;
  }
  if (method == "showMenu") {
    ShowContextMenu();
    result->Success();
    return;
  }
  if (method == "showBalloon") {
    ShowBalloon(Utf16FromUtf8(GetString(args, "title")),
                Utf16FromUtf8(GetString(args, "body")), GetInt(args, "level"));
    result->Success();
    return;
  }
  if (method == "remove") {
    RemoveIcon();
    result->Success();
    return;
  }
  DB_LOG_WARN(kTag, "Unimplemented tray method: " + method);
  result->NotImplemented();
}

// static
LRESULT CALLBACK TrayChannel::WndProc(HWND window, UINT message, WPARAM wparam,
                                      LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (auto* self = reinterpret_cast<TrayChannel*>(
                 ::GetWindowLongPtrW(window, GWLP_USERDATA))) {
    return self->HandleMessage(window, message, wparam, lparam);
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

LRESULT TrayChannel::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                   LPARAM lparam) noexcept {
  if (taskbar_created_message_ != 0 && message == taskbar_created_message_) {
    // Explorer restarted and dropped every notification icon.
    icon_added_ = false;
    AddIcon();
    return 0;
  }
  if (message == kTrayCallbackMessage) {
    switch (LOWORD(lparam)) {
      case WM_LBUTTONUP:
        events_->Emit("activate");
        return 0;
      case WM_LBUTTONDBLCLK:
        events_->Emit("doubleClick");
        return 0;
      case WM_CONTEXTMENU:
      case WM_RBUTTONUP:
        ShowContextMenu();
        return 0;
      case NIN_BALLOONUSERCLICK:
        events_->Emit("balloonClick");
        return 0;
      default:
        return 0;
    }
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace dynamicbar
