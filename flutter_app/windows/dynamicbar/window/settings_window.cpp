#include "dynamicbar/window/settings_window.h"

#include <flutter/standard_method_codec.h>
#include <flutter/method_result_functions.h>

#include <algorithm>

#include "dynamicbar/core/logging.h"
#include "dynamicbar/window/window_effects.h"

namespace dynamicbar {
namespace {
constexpr char kTag[] = "SettingsWindow";
constexpr char kChannel[] = "nocui/settings_window";
constexpr wchar_t kWindowClass[] = L"NocUIExperienceSettingsWindow";
constexpr UINT_PTR kReadyTimer = 41;

std::unique_ptr<flutter::EncodableValue> CopyValue(
    const flutter::EncodableValue* value) {
  return value ? std::make_unique<flutter::EncodableValue>(*value) : nullptr;
}
}  // namespace

SettingsWindow::SettingsWindow(flutter::BinaryMessenger* main_messenger,
                               int icon_resource_id)
    : icon_resource_id_(icon_resource_id) {
  main_channel_ = std::make_unique<Channel>(
      main_messenger, kChannel, &flutter::StandardMethodCodec::GetInstance());
  main_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<Value>& call,
             std::unique_ptr<flutter::MethodResult<Value>> result) {
        if (call.method_name() == "open") {
          if (Open(call.arguments())) result->Success();
          else result->Error("settings_window", "Could not create settings window.");
        } else if (call.method_name() == "state") {
          NotifySettings("state", call.arguments());
          result->Success();
        } else if (call.method_name() == "flush") {
          if (settings_ready_ && settings_channel_) {
            Forward(settings_channel_.get(), "flush", nullptr, std::move(result));
          } else {
            result->Success();
          }
        } else if (call.method_name() == "close") {
          Hide();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

SettingsWindow::~SettingsWindow() {
  if (main_channel_) main_channel_->SetMethodCallHandler(nullptr);
  if (settings_channel_) settings_channel_->SetMethodCallHandler(nullptr);
  // Resolve outstanding replies before tearing down their Flutter engine.
  for (const auto& pending : replies_->pending) {
    if (pending->result) {
      pending->result->Error("settings_closed", "The application is closing.");
      pending->result.reset();
    }
  }
  replies_->pending.clear();
  settings_channel_.reset();
  controller_.reset();
  flutter_view_ = nullptr;
  if (window_) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
}

bool SettingsWindow::Open(const Value* arguments) {
  open_arguments_ = CopyValue(arguments);
  if (window_ != nullptr) {
    ::ShowWindow(window_, ::IsIconic(window_) ? SW_RESTORE : SW_SHOW);
    ::SetForegroundWindow(window_);
    if (settings_ready_) {
      NotifySettings("openSection", open_arguments_.get());
      NotifyMain("ready", open_arguments_.get());
    } else {
      ::SetTimer(window_, kReadyTimer, 15000, nullptr);
    }
    return true;
  }

  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = &SettingsWindow::WndProc;
  wc.hInstance = ::GetModuleHandleW(nullptr);
  wc.hIcon = ::LoadIconW(wc.hInstance, MAKEINTRESOURCEW(icon_resource_id_));
  wc.hIconSm = wc.hIcon;
  wc.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  wc.lpszClassName = kWindowClass;
  if (!::RegisterClassExW(&wc) && ::GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    DB_LOG_WARN(kTag, "Could not register the settings window class.");
    return false;
  }

  window_ = ::CreateWindowExW(
      0, kWindowClass, L"NocUI Experience Settings", WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT, CW_USEDEFAULT, 1024, 720, nullptr, nullptr, wc.hInstance, this);
  if (!window_) return false;
  SetImmersiveDarkMode(window_, true);

  RECT client = {};
  ::GetClientRect(window_, &client);
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("settingsMain");
  controller_ = std::make_unique<flutter::FlutterViewController>(
      client.right, client.bottom, project);
  if (!controller_->engine() || !controller_->view()) {
    controller_.reset();
    ::DestroyWindow(window_);
    window_ = nullptr;
    return false;
  }
  flutter_view_ = controller_->view()->GetNativeWindow();
  ::SetParent(flutter_view_, window_);
  ::MoveWindow(flutter_view_, 0, 0, client.right, client.bottom, TRUE);

  settings_channel_ = std::make_unique<Channel>(
      controller_->engine()->messenger(), kChannel,
      &flutter::StandardMethodCodec::GetInstance());
  settings_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<Value>& call,
             std::unique_ptr<flutter::MethodResult<Value>> result) {
        if (call.method_name() == "ready") {
          settings_ready_ = true;
          if (window_) ::KillTimer(window_, kReadyTimer);
          if (window_ && ::IsWindowVisible(window_)) {
            NotifyMain("ready", open_arguments_.get());
          }
          result->Success();
        } else if (call.method_name() == "update" || call.method_name() == "call") {
          // The primary isolate owns settings and native services. Forward
          // the reply so the second isolate can serialize edits safely.
          Forward(main_channel_.get(), call.method_name(), call.arguments(),
                  std::move(result));
        } else if (call.method_name() == "failed") {
          Hide();
          NotifyMain("failed");
          result->Success();
        } else if (call.method_name() == "close") {
          Hide();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  // If the entrypoint or IPC handshake fails, the main isolate can retain its
  // in-notch fallback instead of leaving the user with a blank window.
  ::SetTimer(window_, kReadyTimer, 15000, nullptr);
  ::ShowWindow(window_, SW_SHOW);
  ::SetForegroundWindow(window_);
  if (settings_ready_) {
    ::KillTimer(window_, kReadyTimer);
    NotifyMain("ready", open_arguments_.get());
  }
  return true;
}

void SettingsWindow::Hide() {
  if (window_ && ::IsWindowVisible(window_)) {
    ::KillTimer(window_, kReadyTimer);
    NotifySettings("closing");
    ::ShowWindow(window_, SW_HIDE);
    NotifyMain("closed");
  }
}

void SettingsWindow::NotifyMain(const std::string& method,
                                const Value* arguments) {
  if (main_channel_) main_channel_->InvokeMethod(method, CopyValue(arguments));
}

void SettingsWindow::NotifySettings(const std::string& method,
                                    const Value* arguments) {
  if (settings_ready_ && settings_channel_) {
    settings_channel_->InvokeMethod(method, CopyValue(arguments));
  }
}

void SettingsWindow::Forward(
    Channel* channel, const std::string& method, const Value* arguments,
    std::unique_ptr<flutter::MethodResult<Value>> result) {
  const auto reply = std::make_shared<PendingReply>();
  reply->result = std::move(result);
  const auto state = replies_;
  state->pending.push_back(reply);
  const auto remove_reply = [state, reply]() {
    auto& pending = state->pending;
    pending.erase(std::remove(pending.begin(), pending.end(), reply),
                  pending.end());
  };
  channel->InvokeMethod(
      method, CopyValue(arguments),
      std::make_unique<flutter::MethodResultFunctions<Value>>(
          [reply, remove_reply](const Value* value) {
            if (reply->result) {
              if (value) reply->result->Success(*value);
              else reply->result->Success();
              reply->result.reset();
            }
            remove_reply();
          },
          [reply, remove_reply](const std::string& code, const std::string& message,
                                const Value* details) {
            if (reply->result) {
              if (details) reply->result->Error(code, message, *details);
              else reply->result->Error(code, message);
              reply->result.reset();
            }
            remove_reply();
          },
          [reply, remove_reply]() {
            if (reply->result) {
              reply->result->NotImplemented();
              reply->result.reset();
            }
            remove_reply();
          }));
}

LRESULT CALLBACK SettingsWindow::WndProc(HWND window, UINT message,
                                        WPARAM wparam, LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto* self = reinterpret_cast<SettingsWindow*>(
      ::GetWindowLongPtrW(window, GWLP_USERDATA));
  return self ? self->HandleMessage(window, message, wparam, lparam)
              : ::DefWindowProcW(window, message, wparam, lparam);
}

LRESULT SettingsWindow::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                      LPARAM lparam) noexcept {
  if (controller_) {
    const auto result = controller_->HandleTopLevelWindowProc(window, message,
                                                               wparam, lparam);
    if (result.has_value()) return *result;
  }
  switch (message) {
    case WM_TIMER:
      if (wparam == kReadyTimer) {
        ::KillTimer(window, kReadyTimer);
        if (!settings_ready_) {
          Hide();
          NotifyMain("failed");
        }
        return 0;
      }
      break;
    case WM_CLOSE:
      Hide();
      return 0;
    case WM_SIZE:
      if (flutter_view_) {
        RECT client = {};
        ::GetClientRect(window, &client);
        ::MoveWindow(flutter_view_, 0, 0, client.right, client.bottom, TRUE);
      }
      return 0;
    case WM_ACTIVATE:
      if (LOWORD(wparam) != WA_INACTIVE && flutter_view_) {
        ::SetFocus(flutter_view_);
      }
      return 0;
    case WM_GETMINMAXINFO: {
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const UINT dpi = ::GetDpiForWindow(window);
      info->ptMinTrackSize.x = ::MulDiv(700, dpi ? dpi : 96, 96);
      info->ptMinTrackSize.y = ::MulDiv(480, dpi ? dpi : 96, 96);
      return 0;
    }
    case WM_DPICHANGED: {
      const auto* suggested = reinterpret_cast<const RECT*>(lparam);
      ::SetWindowPos(window, nullptr, suggested->left, suggested->top,
                     suggested->right - suggested->left,
                     suggested->bottom - suggested->top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace dynamicbar
