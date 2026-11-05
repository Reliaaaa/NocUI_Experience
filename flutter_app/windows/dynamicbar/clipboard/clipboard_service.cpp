#include "dynamicbar/clipboard/clipboard_service.h"

#include <flutter/standard_method_codec.h>
#include <shlwapi.h>

#include <vector>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Clipboard";
constexpr const char kMethodChannelName[] = "dynamicbar/clipboard";
constexpr const char kEventChannelName[] = "dynamicbar/clipboard/events";
constexpr const wchar_t kClassName[] = L"DynamicBarClipboardListener";

/// Name of the process that owns the clipboard, without its path.
std::wstring ClipboardOwnerName() {
  HWND owner = ::GetClipboardOwner();
  if (owner == nullptr) {
    return std::wstring();
  }
  DWORD process_id = 0;
  ::GetWindowThreadProcessId(owner, &process_id);
  if (process_id == 0) {
    return std::wstring();
  }
  HANDLE process = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                                 process_id);
  if (process == nullptr) {
    return std::wstring();
  }
  wchar_t path[MAX_PATH] = {};
  DWORD size = MAX_PATH;
  std::wstring name;
  if (::QueryFullProcessImageNameW(process, 0, path, &size)) {
    const wchar_t* file = ::PathFindFileNameW(path);
    name = file != nullptr ? file : L"";
  }
  ::CloseHandle(process);
  return name;
}

/// Reads at most `limit` characters of the first line of clipboard text.
std::wstring ReadTextPreview(int limit, size_t* full_length) {
  std::wstring preview;
  if (!::IsClipboardFormatAvailable(CF_UNICODETEXT)) {
    return preview;
  }
  if (!::OpenClipboard(nullptr)) {
    return preview;
  }
  HANDLE handle = ::GetClipboardData(CF_UNICODETEXT);
  if (handle != nullptr) {
    auto* text = static_cast<const wchar_t*>(::GlobalLock(handle));
    if (text != nullptr) {
      const size_t length = ::wcslen(text);
      if (full_length != nullptr) {
        *full_length = length;
      }
      size_t end = 0;
      while (end < length && text[end] != L'\r' && text[end] != L'\n' &&
             end < static_cast<size_t>(limit)) {
        ++end;
      }
      preview.assign(text, end);
      ::GlobalUnlock(handle);
    }
  }
  ::CloseClipboard();
  return preview;
}

}  // namespace

ClipboardService::ClipboardService(flutter::BinaryMessenger* messenger) {
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

ClipboardService::~ClipboardService() {
  SetEnabled(false);
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
}

bool ClipboardService::EnsureWindow() {
  if (window_ != nullptr) {
    return true;
  }
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(WNDCLASSEXW);
  window_class.lpfnWndProc = ClipboardService::WndProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.lpszClassName = kClassName;
  ::RegisterClassExW(&window_class);

  window_ = ::CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                              nullptr, window_class.hInstance, this);
  if (window_ == nullptr) {
    DB_LOG_ERROR(kTag, "Failed to create the clipboard listener window.");
    return false;
  }
  return true;
}

void ClipboardService::SetEnabled(bool enabled) {
  if (enabled_ == enabled) {
    return;
  }
  enabled_ = enabled;
  if (enabled) {
    if (!EnsureWindow()) {
      enabled_ = false;
      return;
    }
    listening_ = ::AddClipboardFormatListener(window_) != FALSE;
    if (!listening_) {
      DB_LOG_WARN(kTag, "AddClipboardFormatListener was refused.");
    } else {
      DB_LOG_INFO(kTag, "Clipboard activity monitoring enabled.");
    }
  } else if (listening_ && window_ != nullptr) {
    ::RemoveClipboardFormatListener(window_);
    listening_ = false;
    DB_LOG_INFO(kTag, "Clipboard activity monitoring disabled.");
  }
}

void ClipboardService::OnClipboardUpdate() {
  if (!enabled_) {
    return;
  }

  std::string kind = "other";
  int64_t size_bytes = 0;

  if (::IsClipboardFormatAvailable(CF_HDROP)) {
    kind = "files";
  } else if (::IsClipboardFormatAvailable(CF_UNICODETEXT)) {
    kind = "text";
  } else if (::IsClipboardFormatAvailable(CF_BITMAP) ||
             ::IsClipboardFormatAvailable(CF_DIB)) {
    kind = "image";
  }

  std::string preview;
  if (kind == "text") {
    size_t length = 0;
    if (text_preview_enabled_) {
      preview = Utf8FromUtf16(ReadTextPreview(preview_length_, &length));
    } else {
      // Still measure the length, which needs no preview and reveals nothing.
      ReadTextPreview(0, &length);
    }
    size_bytes = static_cast<int64_t>(length);
  }

  const std::string owner = Utf8FromUtf16(ClipboardOwnerName());

  events_->Emit("copied",
                EncodableMap{
                    {EncodableValue("kind"), EncodableValue(kind)},
                    {EncodableValue("length"), EncodableValue(size_bytes)},
                    {EncodableValue("source"), EncodableValue(owner)},
                    {EncodableValue("preview"), EncodableValue(preview)},
                });
}

void ClipboardService::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "setEnabled") {
    SetEnabled(GetBool(args, "enabled", false));
    result->Success(EncodableValue(listening_));
    return;
  }
  if (method == "setTextPreview") {
    text_preview_enabled_ = GetBool(args, "enabled", false);
    preview_length_ = GetInt(args, "length", 80);
    if (preview_length_ < 0) {
      preview_length_ = 0;
    } else if (preview_length_ > 256) {
      preview_length_ = 256;
    }
    result->Success();
    return;
  }
  DB_LOG_WARN(kTag, "Unimplemented clipboard method: " + method);
  result->NotImplemented();
}

// static
LRESULT CALLBACK ClipboardService::WndProc(HWND window, UINT message,
                                           WPARAM wparam,
                                           LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (auto* self = reinterpret_cast<ClipboardService*>(
                 ::GetWindowLongPtrW(window, GWLP_USERDATA))) {
    return self->HandleMessage(window, message, wparam, lparam);
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

LRESULT ClipboardService::HandleMessage(HWND window, UINT message,
                                        WPARAM wparam,
                                        LPARAM lparam) noexcept {
  if (message == WM_CLIPBOARDUPDATE) {
    OnClipboardUpdate();
    return 0;
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace dynamicbar
