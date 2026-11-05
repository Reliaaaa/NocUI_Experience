#include "dynamicbar/window/island_window.h"

#include <flutter_windows.h>
#include <windowsx.h>
#include <wtsapi32.h>

#include <algorithm>
#include <cmath>
#include <optional>

#include "dynamicbar/core/logging.h"
#include "dynamicbar/window/window_effects.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "IslandWindow";
constexpr UINT kOutsideClickMessage = WM_APP + 0x300;
constexpr UINT kProximityEnterMessage = WM_APP + 0x301;
constexpr UINT kProximityLeaveMessage = WM_APP + 0x302;
constexpr UINT kPointerStateMessage = WM_APP + 0x303;

/// The single stage, reachable from the low-level mouse hook (which carries no
/// user context). There is exactly one IslandWindow per process.
IslandWindow* g_island_window = nullptr;
constexpr const wchar_t kWindowClassName[] = L"DynamicBarIslandStage";
constexpr const wchar_t kWindowTitle[] = L"DynamicBar";

struct MonitorSearch {
  std::string wanted_id;
  HMONITOR found = nullptr;
};

std::string MonitorIdOf(HMONITOR monitor) {
  MONITORINFOEXW info = {};
  info.cbSize = sizeof(MONITORINFOEXW);
  if (!::GetMonitorInfoW(monitor, &info)) {
    return std::string();
  }
  return Utf8FromUtf16(info.szDevice);
}

BOOL CALLBACK FindMonitorProc(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* search = reinterpret_cast<MonitorSearch*>(data);
  if (MonitorIdOf(monitor) == search->wanted_id) {
    search->found = monitor;
    return FALSE;
  }
  return TRUE;
}

int RoundToInt(double value) {
  return static_cast<int>(std::lround(value));
}

EncodableValue RectToValue(const RECT& rect) {
  return EncodableValue(EncodableMap{
      {EncodableValue("left"), EncodableValue(static_cast<int64_t>(rect.left))},
      {EncodableValue("top"), EncodableValue(static_cast<int64_t>(rect.top))},
      {EncodableValue("right"),
       EncodableValue(static_cast<int64_t>(rect.right))},
      {EncodableValue("bottom"),
       EncodableValue(static_cast<int64_t>(rect.bottom))},
  });
}

}  // namespace

IslandWindow::IslandWindow() {
  g_island_window = this;
}

IslandWindow::~IslandWindow() {
  SetOutsideClickWatch(false);
  SetProximityWatch(false);
  // The click-through watch is the third thing holding the hook thread open,
  // and the thread must be joined before the window it posts to goes away.
  click_through_watch_.store(false);
  SyncMouseHook();
  Destroy();
  g_island_window = nullptr;
}

void IslandWindow::SetOutsideClickWatch(bool enabled) {
  if (outside_click_watch_.load() == enabled) {
    return;
  }
  outside_click_watch_.store(enabled);
  SyncMouseHook();
}

void IslandWindow::SetProximityWatch(bool enabled) {
  if (proximity_watch_.load() == enabled) {
    return;
  }
  proximity_watch_.store(enabled);
  proximity_inside_.store(false);
  SyncMouseHook();

  // The cursor may already be sitting in the zone when the watch starts - the
  // user turned auto-hide on with the pointer on the island. Without this the
  // island would stay away until the pointer left and came back.
  if (enabled && window_ != nullptr) {
    POINT cursor = {};
    if (::GetCursorPos(&cursor)) {
      bool inside = false;
      ::AcquireSRWLockShared(&cache_lock_);
      inside = reveal_screen_.right > reveal_screen_.left &&
               cursor.x >= reveal_screen_.left &&
               cursor.x < reveal_screen_.right &&
               cursor.y >= reveal_screen_.top &&
               cursor.y < reveal_screen_.bottom;
      ::ReleaseSRWLockShared(&cache_lock_);
      if (inside) {
        proximity_inside_.store(true);
        ::PostMessageW(window_, kProximityEnterMessage, 0, 0);
      }
    }
  }
}

void IslandWindow::SetRevealZone(LogicalRect zone) {
  reveal_zone_ = zone;
  RefreshMouseCache();
}

/// Hysteresis: leaving takes a little more travel than entering.
///
/// Without it a hand resting on the boundary makes the island appear and
/// disappear several times a second - which is exactly the behaviour this
/// feature exists to avoid.
constexpr LONG kRevealHysteresis = 26;

namespace {

inline bool Contains(const RECT& rect, POINT point) {
  return point.x >= rect.left && point.x < rect.right && point.y >= rect.top &&
         point.y < rect.bottom;
}

}  // namespace

/// Turns the logical rectangles into screen pixels, once, on the UI thread.
///
/// Everything the hook procedure needs is precomputed here so that it can run
/// without touching a window handle, and therefore without ever waiting on the
/// UI thread that owns one.
void IslandWindow::RefreshMouseCache() {
  POINT origin = {0, 0};
  if (window_ != nullptr) {
    ::ClientToScreen(window_, &origin);
  }
  const double factor = scale();

  auto to_screen = [&](const LogicalRect& rect) {
    RECT out;
    out.left = origin.x + RoundToInt(rect.left * factor);
    out.top = origin.y + RoundToInt(rect.top * factor);
    out.right = origin.x + RoundToInt(rect.right * factor);
    out.bottom = origin.y + RoundToInt(rect.bottom * factor);
    return out;
  };

  RECT reveal = {};
  RECT slack = {};
  if (window_ != nullptr && reveal_zone_.right > reveal_zone_.left) {
    reveal = to_screen(reveal_zone_);
    const LONG give = RoundToInt(kRevealHysteresis * factor);
    slack = reveal;
    slack.left -= give;
    slack.top -= give;
    slack.right += give;
    slack.bottom += give;
  }

  std::vector<RECT> interactive;
  if (window_ != nullptr && !ignore_mouse_) {
    interactive.reserve(interactive_rects_.size());
    for (const LogicalRect& rect : interactive_rects_) {
      interactive.push_back(to_screen(rect));
    }
  }

  ::AcquireSRWLockExclusive(&cache_lock_);
  reveal_screen_ = reveal;
  reveal_screen_slack_ = slack;
  interactive_screen_.swap(interactive);
  ::ReleaseSRWLockExclusive(&cache_lock_);

  // The island may have arrived, grown or left from under a cursor that never
  // moved, and a hook that reports movement cannot know that.
  EvaluatePointerNow();
}

/// Reads the cursor once and settles the click-through style against it.
void IslandWindow::EvaluatePointerNow() {
  bool on_island = false;
  POINT cursor = {};
  if (::GetCursorPos(&cursor)) {
    ::AcquireSRWLockShared(&cache_lock_);
    for (const RECT& rect : interactive_screen_) {
      if (Contains(rect, cursor)) {
        on_island = true;
        break;
      }
    }
    ::ReleaseSRWLockShared(&cache_lock_);
  }
  pointer_on_island_.store(on_island);
  UpdateTransparentStyle();
}

/// The one place WS_EX_TRANSPARENT is written.
///
/// HTTRANSPARENT alone is not enough: it hands the point to windows of the
/// same thread, and the window under the stage always belongs to another
/// process, so a click there is swallowed rather than passed on. This flag is
/// honoured by the system's own hit test, which is what actually lets the
/// desktop see a click that lands on the empty part of the stage.
void IslandWindow::UpdateTransparentStyle() {
  if (window_ == nullptr) {
    return;
  }
  // A watch that never installed leaves the stage opaque rather than
  // permanently click-through: an island that cannot be clicked would be a
  // far worse failure than one that is a little greedy with the pointer.
  const bool transparent =
      ignore_mouse_ || (click_through_watch_.load() &&
                        hook_installed_.load() && !pointer_on_island_.load());
  if (transparent == transparent_applied_) {
    return;
  }
  transparent_applied_ = transparent;

  LONG_PTR style = ::GetWindowLongPtrW(window_, GWL_EXSTYLE);
  const LONG_PTR next = transparent
                            ? (style | WS_EX_TRANSPARENT)
                            : (style & ~static_cast<LONG_PTR>(WS_EX_TRANSPARENT));
  if (next != style) {
    ::SetWindowLongPtrW(window_, GWL_EXSTYLE, next);
  }
}

/// One hook serves both watches; it exists only while at least one is on, and
/// always on a thread of its own.
void IslandWindow::SyncMouseHook() {
  const bool wanted =
      outside_click_watch_ || proximity_watch_ || click_through_watch_;
  if (wanted && !mouse_running_.load()) {
    RefreshMouseCache();
    mouse_running_.store(true);
    mouse_ready_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
    mouse_thread_ = std::thread(&IslandWindow::MouseWatchLoop, this);
    if (mouse_ready_ != nullptr) {
      // The thread has to have a message queue before anything can post to it.
      ::WaitForSingleObject(mouse_ready_, 2000);
    }
  } else if (!wanted && mouse_running_.load()) {
    mouse_running_.store(false);
    const DWORD id = mouse_thread_id_.load();
    if (id != 0) {
      ::PostThreadMessageW(id, WM_QUIT, 0, 0);
    }
    if (mouse_thread_.joinable()) {
      mouse_thread_.join();
    }
    mouse_thread_id_.store(0);
    if (mouse_ready_ != nullptr) {
      ::CloseHandle(mouse_ready_);
      mouse_ready_ = nullptr;
    }
  }
}

/// The watch thread. It owns the hook and pumps messages, and does nothing
/// else for as long as it lives.
void IslandWindow::MouseWatchLoop() {
  // Forces the queue into existence before anyone is told the thread is ready.
  MSG message = {};
  ::PeekMessageW(&message, nullptr, WM_USER, WM_USER, PM_NOREMOVE);
  mouse_thread_id_.store(::GetCurrentThreadId());

  HHOOK hook = ::SetWindowsHookExW(WH_MOUSE_LL, &IslandWindow::MouseHookProc,
                                   ::GetModuleHandleW(nullptr), 0);
  if (hook == nullptr) {
    DB_LOG_WARN(kTag, "Could not install the mouse watch.");
  }
  // Click-through follows the pointer, so it may only be switched on once the
  // hook is actually there to report where the pointer is.
  hook_installed_.store(hook != nullptr);
  if (hook != nullptr) {
    ::PostMessageW(window_, kPointerStateMessage, 0, 0);
  }
  if (mouse_ready_ != nullptr) {
    ::SetEvent(mouse_ready_);
  }

  while (::GetMessageW(&message, nullptr, 0, 0) > 0) {
    // Nothing is dispatched here. The loop exists because a low level hook is
    // only delivered to a thread that is pumping messages.
  }

  if (hook != nullptr) {
    ::UnhookWindowsHookEx(hook);
  }
  hook_installed_.store(false);
  if (window_ != nullptr) {
    ::PostMessageW(window_, kPointerStateMessage, 0, 0);
  }
}

// static
///
/// Runs for every mouse event on the system, on the watch thread. Two
/// rectangle comparisons and, only when the answer changes, one PostMessage.
/// Nothing here may block, allocate, or call into a window: Windows holds
/// every mouse event in the session until this returns.
LRESULT CALLBACK IslandWindow::MouseHookProc(int code, WPARAM wparam,
                                             LPARAM lparam) {
  IslandWindow* self = g_island_window;
  if (code != HC_ACTION || self == nullptr) {
    return ::CallNextHookEx(nullptr, code, wparam, lparam);
  }
  const auto* info = reinterpret_cast<const MSLLHOOKSTRUCT*>(lparam);
  HWND target = self->window_;
  if (info == nullptr || target == nullptr) {
    return ::CallNextHookEx(nullptr, code, wparam, lparam);
  }

  const bool moving = wparam == WM_MOUSEMOVE;
  const bool pressing =
      wparam == WM_LBUTTONDOWN || wparam == WM_RBUTTONDOWN ||
      wparam == WM_MBUTTONDOWN || wparam == WM_XBUTTONDOWN;
  const bool releasing = wparam == WM_LBUTTONUP || wparam == WM_RBUTTONUP ||
                         wparam == WM_MBUTTONUP || wparam == WM_XBUTTONUP;
  if (pressing) {
    self->buttons_down_.store(true);
  } else if (releasing) {
    self->buttons_down_.store(false);
  }

  const bool want_proximity = self->proximity_watch_.load() && moving;
  const bool want_outside = self->outside_click_watch_.load() && pressing;
  // The side of the island the pointer is on decides whether the stage is
  // click-through. It is never re-decided mid-drag: a scrub that wanders off
  // the island must not hand the rest of the gesture to the desktop.
  const bool want_click_through = self->click_through_watch_.load() &&
                                  (moving || pressing) &&
                                  !(moving && self->buttons_down_.load());
  if (!want_proximity && !want_outside && !want_click_through) {
    return ::CallNextHookEx(nullptr, code, wparam, lparam);
  }

  bool inside_zone = false;
  bool on_island = false;
  ::AcquireSRWLockShared(&self->cache_lock_);
  if (want_proximity) {
    const RECT& zone = self->proximity_inside_.load()
                           ? self->reveal_screen_slack_
                           : self->reveal_screen_;
    inside_zone = zone.right > zone.left && Contains(zone, info->pt);
  }
  if (want_outside || want_click_through) {
    for (const RECT& rect : self->interactive_screen_) {
      if (Contains(rect, info->pt)) {
        on_island = true;
        break;
      }
    }
  }
  ::ReleaseSRWLockShared(&self->cache_lock_);

  if (want_click_through && on_island != self->pointer_on_island_.load()) {
    self->pointer_on_island_.store(on_island);
    // The style has to be written by the thread that owns the window, and
    // nothing here may wait for it, so the answer is posted rather than
    // applied. It arrives on the next message the stage pumps, which is
    // ahead of the button event this move preceded.
    ::PostMessageW(target, kPointerStateMessage, 0, 0);
  }

  if (want_proximity && inside_zone != self->proximity_inside_.load()) {
    self->proximity_inside_.store(inside_zone);
    ::PostMessageW(
        target, inside_zone ? kProximityEnterMessage : kProximityLeaveMessage,
        0, 0);
  }
  if (want_outside && !on_island) {
    ::PostMessageW(target, kOutsideClickMessage, 0, 0);
  }

  return ::CallNextHookEx(nullptr, code, wparam, lparam);
}

flutter::BinaryMessenger* IslandWindow::messenger() const {
  if (view_controller_ == nullptr || view_controller_->engine() == nullptr) {
    return nullptr;
  }
  return view_controller_->engine()->messenger();
}

bool IslandWindow::Create(const flutter::DartProject& project) {
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(WNDCLASSEXW);
  window_class.style = CS_HREDRAW | CS_VREDRAW;
  window_class.lpfnWndProc = IslandWindow::WndProc;
  window_class.hInstance = ::GetModuleHandleW(nullptr);
  window_class.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  window_class.hbrBackground = nullptr;
  window_class.lpszClassName = kWindowClassName;
  ::RegisterClassExW(&window_class);

  taskbar_created_message_ = ::RegisterWindowMessageW(L"TaskbarCreated");
  activation_message_ =
      ::RegisterWindowMessageW(L"DynamicBar.ActivateExisting");

  // Placement needs a monitor, and the monitor needs a window handle for DPI
  // queries, so start at a provisional position and correct it immediately
  // after creation.
  HMONITOR monitor = ResolveMonitor();
  dpi_ = ::FlutterDesktopGetDpiForMonitor(monitor);
  if (dpi_ == 0) {
    dpi_ = 96;
  }

  const DWORD style = WS_POPUP | WS_CLIPCHILDREN;
  const DWORD extended_style = WS_EX_TOPMOST | WS_EX_TOOLWINDOW;

  window_ = ::CreateWindowExW(
      extended_style, kWindowClassName, kWindowTitle, style, 0, 0,
      RoundToInt(placement_.width * scale()),
      RoundToInt(placement_.height * scale()), nullptr, nullptr,
      window_class.hInstance, this);
  if (window_ == nullptr) {
    DB_LOG_ERROR(kTag, "CreateWindowEx failed for the island stage.");
    return false;
  }

  // DYNAMICBAR_OPAQUE=1 leaves the window opaque. Used to tell a composition
  // problem apart from a layout one, and as a support escape hatch on machines
  // where the composition attribute misbehaves.
  wchar_t opaque[8] = {};
  const bool force_opaque =
      ::GetEnvironmentVariableW(L"DYNAMICBAR_OPAQUE", opaque, 8) > 0 &&
      opaque[0] == L'1';
  if (force_opaque) {
    DB_LOG_WARN(kTag, "DYNAMICBAR_OPAQUE=1; rendering against an opaque window.");
  } else {
    EnablePerPixelTransparency(
        window_, AlphaModeFromEnvironment(AlphaMode::kGlass));
  }
  SetCornerPreference(window_, 1 /* DWMWCP_DONOTROUND */);
  ApplyPlacement();

  RECT client = {};
  ::GetClientRect(window_, &client);
  view_controller_ = std::make_unique<flutter::FlutterViewController>(
      client.right - client.left, client.bottom - client.top, project);
  if (view_controller_->engine() == nullptr ||
      view_controller_->view() == nullptr) {
    DB_LOG_ERROR(kTag, "Failed to start the Flutter engine for the stage.");
    return false;
  }

  flutter_view_ = view_controller_->view()->GetNativeWindow();
  ::SetParent(flutter_view_, window_);
  ::MoveWindow(flutter_view_, 0, 0, client.right - client.left,
               client.bottom - client.top, TRUE);

  // Any resize before this point corrupts the presented surface (see
  // docs/WINDOWS_INTEGRATION.md). Hold placement changes until the engine has
  // actually put a frame on screen. Invoked on the platform thread.
  view_controller_->engine()->SetNextFrameCallback([this]() {
    first_frame_presented_ = true;
    DB_LOG_INFO(kTag, "First frame presented.");
    if (placement_pending_) {
      placement_pending_ = false;
      ApplyPlacement();
    }
  });

  ::WTSRegisterSessionNotification(window_, NOTIFY_FOR_THIS_SESSION);

  DB_LOG_INFO(kTag, "Island stage created.");
  return true;
}

void IslandWindow::Destroy() {
  if (destroying_) {
    return;
  }
  destroying_ = true;
  if (window_ != nullptr) {
    ::WTSUnRegisterSessionNotification(window_);
  }
  view_controller_.reset();
  flutter_view_ = nullptr;
  if (window_ != nullptr) {
    HWND window = window_;
    window_ = nullptr;
    ::DestroyWindow(window);
  }
  destroying_ = false;
}

HMONITOR IslandWindow::ResolveMonitor() const {
  if (!placement_.monitor_id.empty()) {
    MonitorSearch search;
    search.wanted_id = placement_.monitor_id;
    ::EnumDisplayMonitors(nullptr, nullptr, FindMonitorProc,
                          reinterpret_cast<LPARAM>(&search));
    if (search.found != nullptr) {
      return search.found;
    }
    DB_LOG_WARN(kTag, "Configured monitor '" + placement_.monitor_id +
                          "' is gone; falling back to the primary monitor.");
  }
  const POINT origin = {0, 0};
  return ::MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY);
}

void IslandWindow::SetPlacement(const StagePlacement& placement) {
  placement_ = placement;
  ApplyPlacement();
}

void IslandWindow::ApplyPlacement() {
  if (window_ == nullptr) {
    return;
  }
  if (view_controller_ != nullptr && !first_frame_presented_) {
    placement_pending_ = true;
    DB_LOG_DEBUG(kTag, "Placement deferred until the first frame.");
    return;
  }
  HMONITOR monitor = ResolveMonitor();
  MONITORINFOEXW info = {};
  info.cbSize = sizeof(MONITORINFOEXW);
  if (!::GetMonitorInfoW(monitor, &info)) {
    DB_LOG_WARN(kTag, "GetMonitorInfo failed; keeping the current placement.");
    return;
  }

  unsigned int dpi = ::FlutterDesktopGetDpiForMonitor(monitor);
  if (dpi != 0) {
    dpi_ = dpi;
  }
  active_monitor_id_ = Utf8FromUtf16(info.szDevice);

  const RECT area = placement_.use_work_area ? info.rcWork : info.rcMonitor;
  const double factor = scale();
  const int width = std::max(1, RoundToInt(placement_.width * factor));
  const int height = std::max(1, RoundToInt(placement_.height * factor));
  const int area_width = area.right - area.left;

  int x = area.left +
          RoundToInt((area_width - width) * placement_.align_x) +
          RoundToInt(placement_.offset_x * factor);
  int y = area.top + RoundToInt(placement_.offset_y * factor);

  // Never let the stage hang off the monitor; a partially off-screen overlay
  // is both ugly and hard to reach.
  x = static_cast<int>(std::max<LONG>(
      area.left, std::min<LONG>(x, area.right - width)));
  y = static_cast<int>(std::max<LONG>(
      area.top, std::min<LONG>(y, area.bottom - height)));

  RECT next = {x, y, x + width, y + height};
  if (::EqualRect(&next, &bounds_)) {
    return;
  }
  bounds_ = next;

  // Never SWP_NOREDRAW here: skipping the redraw leaves DWM holding the
  // child's previous surface geometry, and the Flutter view is then stretched
  // into the new rectangle instead of re-presented at it.
  // SWP_NOCOPYBITS as well: without it DWM keeps the previous client bits
  // and stretches them into the new rectangle, and with a scaled island the
  // very first placement is a resize - the stage is created at scale 1.0 and
  // immediately re-placed at the user's scale. The result was a page drawn
  // wider and shorter than its window, clipped on the right.
  const UINT flags = SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED |
                     SWP_NOCOPYBITS;
  ::SetWindowPos(window_, always_on_top_ ? HWND_TOPMOST : HWND_NOTOPMOST, x, y,
                 width, height, flags);
  if (flutter_view_ != nullptr) {
    ::SetWindowPos(flutter_view_, nullptr, 0, 0, width, height,
                   SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOCOPYBITS);
    RECT view = {};
    ::GetClientRect(flutter_view_, &view);
    DB_LOG_DEBUG(kTag, "Flutter view client " + std::to_string(view.right) +
                           "x" + std::to_string(view.bottom));
  }

  RECT client = {};
  ::GetClientRect(window_, &client);
  DB_LOG_INFO(kTag, "Stage placed at (" + std::to_string(x) + "," +
                        std::to_string(y) + ") " + std::to_string(width) + "x" +
                        std::to_string(height) + " client " +
                        std::to_string(client.right) + "x" +
                        std::to_string(client.bottom) + " dpi " +
                        std::to_string(dpi_));

  // The watch thread compares against screen pixels; the stage just moved.
  RefreshMouseCache();
}

void IslandWindow::SetInteractiveRects(std::vector<LogicalRect> rects) {
  interactive_rects_ = std::move(rects);
  RefreshMouseCache();
  if (!interactive_rects_.empty()) {
    const LogicalRect& first = interactive_rects_.front();
    DB_LOG_DEBUG(kTag, "Island rect (logical) " +
                           std::to_string(static_cast<int>(first.left)) + "," +
                           std::to_string(static_cast<int>(first.top)) + " to " +
                           std::to_string(static_cast<int>(first.right)) + "," +
                           std::to_string(static_cast<int>(first.bottom)));
  }
}

void IslandWindow::SetVisible(bool visible) {
  if (window_ == nullptr || visible_ == visible) {
    return;
  }
  visible_ = visible;
  // SW_SHOWNOACTIVATE keeps the foreground application focused when the island
  // reappears on its own (a notification, a media change, a hotkey).
  ::ShowWindow(window_, visible ? SW_SHOWNOACTIVATE : SW_HIDE);
  if (visible) {
    AssertTopmost();
  }
  // The stage is only a hole in the desktop while it is on screen, so the
  // watch that keeps it click-through lives exactly that long.
  click_through_watch_.store(visible);
  SyncMouseHook();
  EvaluatePointerNow();
}

void IslandWindow::SetFocusable(bool focusable) {
  focusable_ = focusable;
  if (window_ == nullptr) {
    return;
  }
  LONG_PTR style = ::GetWindowLongPtrW(window_, GWL_EXSTYLE);
  if (focusable) {
    style &= ~static_cast<LONG_PTR>(WS_EX_NOACTIVATE);
  } else {
    style |= WS_EX_NOACTIVATE;
  }
  ::SetWindowLongPtrW(window_, GWL_EXSTYLE, style);
}

void IslandWindow::SetIgnoreMouse(bool ignore) {
  ignore_mouse_ = ignore;
  // Refreshing the cache empties the interactive rectangles while ignoring,
  // and settles the style against the cursor on its way out.
  RefreshMouseCache();
}

void IslandWindow::SetAlwaysOnTop(bool always_on_top) {
  always_on_top_ = always_on_top;
  AssertTopmost();
}

void IslandWindow::AssertTopmost() {
  if (window_ == nullptr) {
    return;
  }
  ::SetWindowPos(window_, always_on_top_ ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0,
                 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
}

void IslandWindow::RequestFocus() {
  if (window_ == nullptr) {
    return;
  }
  SetFocusable(true);
  ::SetForegroundWindow(window_);
  if (flutter_view_ != nullptr) {
    ::SetFocus(flutter_view_);
  }
}

void IslandWindow::RequestQuit() {
  DB_LOG_INFO(kTag, "Quit requested.");
  ::PostQuitMessage(0);
}

void IslandWindow::SetEventCallback(EventCallback callback) {
  event_callback_ = std::move(callback);
}

void IslandWindow::AddMessageHook(MessageHook hook) {
  message_hooks_.push_back(std::move(hook));
}

void IslandWindow::Emit(const std::string& type, EncodableMap payload) {
  if (event_callback_) {
    event_callback_(type, std::move(payload));
  }
}

EncodableMap IslandWindow::DescribeStage() const {
  return EncodableMap{
      {EncodableValue("monitorId"), EncodableValue(active_monitor_id_)},
      {EncodableValue("scale"), EncodableValue(scale())},
      {EncodableValue("dpi"), EncodableValue(static_cast<int64_t>(dpi_))},
      {EncodableValue("width"), EncodableValue(placement_.width)},
      {EncodableValue("height"), EncodableValue(placement_.height)},
      {EncodableValue("bounds"), RectToValue(bounds_)},
      {EncodableValue("visible"), EncodableValue(visible_)},
      {EncodableValue("focusable"), EncodableValue(focusable_)},
  };
}

LRESULT IslandWindow::HitTest(POINT screen_point) const {
  if (ignore_mouse_ || interactive_rects_.empty()) {
    return HTTRANSPARENT;
  }
  POINT point = screen_point;
  ::ScreenToClient(window_, &point);
  const double factor = scale();
  const double x = point.x / factor;
  const double y = point.y / factor;
  for (const LogicalRect& rect : interactive_rects_) {
    if (x >= rect.left && x < rect.right && y >= rect.top && y < rect.bottom) {
      return HTCLIENT;
    }
  }
  return HTTRANSPARENT;
}

// static
LRESULT CALLBACK IslandWindow::WndProc(HWND window, UINT message,
                                       WPARAM wparam, LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    auto* self = static_cast<IslandWindow*>(create->lpCreateParams);
    ::SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(self));
    if (self != nullptr) {
      self->window_ = window;
    }
  } else if (auto* self = reinterpret_cast<IslandWindow*>(
                 ::GetWindowLongPtrW(window, GWLP_USERDATA))) {
    return self->HandleMessage(window, message, wparam, lparam);
  }
  return ::DefWindowProcW(window, message, wparam, lparam);
}

LRESULT IslandWindow::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                    LPARAM lparam) noexcept {
  for (const MessageHook& hook : message_hooks_) {
    LRESULT result = 0;
    if (hook && hook(window, message, wparam, lparam, &result)) {
      return result;
    }
  }

  if (view_controller_ != nullptr) {
    std::optional<LRESULT> result =
        view_controller_->HandleTopLevelWindowProc(window, message, wparam,
                                                   lparam);
    if (result.has_value()) {
      return *result;
    }
  }

  if (message == kOutsideClickMessage) {
    Emit("clickOutside");
    return 0;
  }

  if (message == kPointerStateMessage) {
    UpdateTransparentStyle();
    return 0;
  }

  if (message == kProximityEnterMessage || message == kProximityLeaveMessage) {
    Emit("proximity",
         EncodableMap{{EncodableValue("inside"),
                       EncodableValue(message == kProximityEnterMessage)}});
    return 0;
  }

  if (activation_message_ != 0 && message == activation_message_) {
    // A second launch asked the running instance to show itself.
    DB_LOG_INFO(kTag, "Activation requested by a second instance.");
    AssertTopmost();
    Emit("activationRequested");
    return 0;
  }

  if (taskbar_created_message_ != 0 && message == taskbar_created_message_) {
    DB_LOG_INFO(kTag, "Explorer restarted; re-asserting the stage.");
    AssertTopmost();
    Emit("shellRestarted");
    return 0;
  }

  switch (message) {
    case WM_NCHITTEST: {
      const POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      return HitTest(point);
    }

    case WM_MOUSEACTIVATE:
      // Hovering must never steal focus from whatever the user is working in.
      return focusable_ ? MA_ACTIVATE : MA_NOACTIVATE;

    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE) {
        Emit("focusLost");
      } else {
        if (flutter_view_ != nullptr) {
          ::SetFocus(flutter_view_);
        }
        Emit("focusGained");
      }
      return 0;

    case WM_DPICHANGED: {
      dpi_ = HIWORD(wparam);
      // The suggested rectangle is for ordinary windows; the stage owns its
      // own placement, so recompute instead of accepting it.
      ApplyPlacement();
      Emit("dpiChanged",
           EncodableMap{{EncodableValue("scale"), EncodableValue(scale())},
                        {EncodableValue("dpi"),
                         EncodableValue(static_cast<int64_t>(dpi_))}});
      return 0;
    }

    case WM_DISPLAYCHANGE:
      ApplyPlacement();
      Emit("displaysChanged");
      return 0;

    case WM_SETTINGCHANGE: {
      const auto* area = reinterpret_cast<const wchar_t*>(lparam);
      if (area != nullptr && ::lstrcmpW(area, L"ImmersiveColorSet") == 0) {
        Emit("systemThemeChanged",
             EncodableMap{{EncodableValue("dark"),
                           EncodableValue(SystemPrefersDarkMode())}});
      } else if (wparam == SPI_SETWORKAREA) {
        ApplyPlacement();
        Emit("workAreaChanged");
      }
      return 0;
    }

    case WM_POWERBROADCAST:
      if (wparam == PBT_APMRESUMEAUTOMATIC || wparam == PBT_APMRESUMESUSPEND) {
        AssertTopmost();
        ApplyPlacement();
        Emit("sessionResumed");
      } else if (wparam == PBT_APMSUSPEND) {
        Emit("sessionSuspended");
      }
      return TRUE;

    case WM_WTSSESSION_CHANGE:
      if (wparam == WTS_SESSION_UNLOCK) {
        AssertTopmost();
        Emit("sessionUnlocked");
      } else if (wparam == WTS_SESSION_LOCK) {
        Emit("sessionLocked");
      }
      return 0;

    case WM_SIZE:
      if (flutter_view_ != nullptr) {
        RECT client = {};
        ::GetClientRect(window, &client);
        ::SetWindowPos(flutter_view_, nullptr, 0, 0,
                       client.right - client.left, client.bottom - client.top,
                       SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOCOPYBITS);
      }
      return 0;

    case WM_FONTCHANGE:
      if (view_controller_ != nullptr && view_controller_->engine() != nullptr) {
        view_controller_->engine()->ReloadSystemFonts();
      }
      return 0;

    case WM_ENDSESSION:
      Emit("systemShutdown");
      return 0;

    case WM_DESTROY:
      window_ = nullptr;
      ::PostQuitMessage(0);
      return 0;

    default:
      break;
  }

  return ::DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace dynamicbar
