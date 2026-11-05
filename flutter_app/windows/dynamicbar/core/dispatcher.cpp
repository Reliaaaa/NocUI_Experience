#include "dynamicbar/core/dispatcher.h"

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {
constexpr const wchar_t kClassName[] = L"DynamicBarDispatcherWindow";
constexpr UINT kDrainMessage = WM_APP + 0x100;
constexpr const char kTag[] = "Dispatcher";
}  // namespace

MainThreadDispatcher& MainThreadDispatcher::Instance() {
  static MainThreadDispatcher instance;
  return instance;
}

MainThreadDispatcher::~MainThreadDispatcher() {
  Shutdown();
}

bool MainThreadDispatcher::Initialize() {
  if (window_ != nullptr) {
    return true;
  }
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(WNDCLASSEXW);
  window_class.lpfnWndProc = MainThreadDispatcher::WndProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.lpszClassName = kClassName;
  ::RegisterClassExW(&window_class);

  window_ = ::CreateWindowExW(0, kClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                              nullptr, window_class.hInstance, this);
  if (window_ == nullptr) {
    DB_LOG_ERROR(kTag, "Failed to create the dispatcher message window.");
    return false;
  }
  shutting_down_ = false;
  return true;
}

void MainThreadDispatcher::Shutdown() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    shutting_down_ = true;
    queue_.clear();
  }
  if (window_ != nullptr) {
    ::DestroyWindow(window_);
    window_ = nullptr;
  }
}

void MainThreadDispatcher::Post(std::function<void()> task) {
  if (!task) {
    return;
  }
  HWND window = window_;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (shutting_down_ || window == nullptr) {
      return;
    }
    queue_.push_back(std::move(task));
  }
  ::PostMessageW(window, kDrainMessage, 0, 0);
}

void MainThreadDispatcher::Drain() {
  std::vector<std::function<void()>> pending;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    pending.swap(queue_);
  }
  for (const auto& task : pending) {
    task();
  }
}

// static
LRESULT CALLBACK MainThreadDispatcher::WndProc(HWND window, UINT message,
                                               WPARAM wparam,
                                               LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (message == kDrainMessage) {
    auto* self = reinterpret_cast<MainThreadDispatcher*>(
        ::GetWindowLongPtrW(window, GWLP_USERDATA));
    if (self != nullptr) {
      self->Drain();
    }
    return 0;
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace dynamicbar
