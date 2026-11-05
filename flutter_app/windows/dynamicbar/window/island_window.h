// DynamicBar - the overlay window that hosts the island.
//
// This is deliberately not a Win32Window subclass: the Flutter template window
// is a normal application window (WS_OVERLAPPEDWINDOW, taskbar button, opaque
// surface) and almost none of that behaviour is wanted here. The island lives
// in a frameless, always-on-top, tool-style "stage" window with per-pixel
// alpha that is click-through everywhere except the island itself.
//
// The stage never resizes while the island animates. It is sized once to hold
// the largest island state and only moves when the monitor, the DPI or the
// stage mode changes, so morphing costs nothing outside the GPU.
#ifndef DYNAMICBAR_WINDOW_ISLAND_WINDOW_H_
#define DYNAMICBAR_WINDOW_ISLAND_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <thread>
#include <vector>

#include "dynamicbar/core/encodable.h"

namespace dynamicbar {

// A rectangle in logical, stage-local coordinates as Flutter sees it.
struct LogicalRect {
  double left = 0.0;
  double top = 0.0;
  double right = 0.0;
  double bottom = 0.0;
};

// Where the stage sits on its monitor.
struct StagePlacement {
  std::string monitor_id;      // Empty means "follow the primary monitor".
  // Logical pixels. These match IslandMetrics.stageSize(), which is one size
  // for every mode and scale, so the window is created at its final size and
  // the engine never has to resize its surface - not during the first frames,
  // and not later either. A resize leaves DWM stretching the old surface into
  // the new rectangle.
  double width = 1284.0;
  double height = 900.6;
  double align_x = 0.5;        // 0 = left edge, 0.5 = centred, 1 = right edge.
  double offset_x = 0.0;       // Logical pixels, applied after alignment.
  double offset_y = 0.0;       // Logical pixels from the top of the area.
  bool use_work_area = false;  // Anchor to the work area instead of the panel.
};

class IslandWindow {
 public:
  // type + payload, delivered on the platform thread.
  using EventCallback =
      std::function<void(const std::string& type, EncodableMap payload)>;
  // Returns true when the hook consumed the message and filled `result`.
  using MessageHook = std::function<bool(HWND window, UINT message,
                                         WPARAM wparam, LPARAM lparam,
                                         LRESULT* result)>;

  IslandWindow();
  ~IslandWindow();

  IslandWindow(const IslandWindow&) = delete;
  IslandWindow& operator=(const IslandWindow&) = delete;

  bool Create(const flutter::DartProject& project);
  void Destroy();

  HWND handle() const { return window_; }
  flutter::FlutterViewController* view_controller() const {
    return view_controller_.get();
  }
  flutter::BinaryMessenger* messenger() const;

  // Scale factor of the monitor currently hosting the stage.
  double scale() const { return dpi_ / 96.0; }
  unsigned int dpi() const { return dpi_; }

  const StagePlacement& placement() const { return placement_; }
  void SetPlacement(const StagePlacement& placement);
  // Recomputes the stage bounds and moves the window. Cheap and idempotent;
  // skips the SetWindowPos entirely when nothing actually changed.
  void ApplyPlacement();

  // Logical, stage-local rectangles that should receive mouse input. Everything
  // outside them is click-through.
  void SetInteractiveRects(std::vector<LogicalRect> rects);

  void SetVisible(bool visible);
  bool visible() const { return visible_; }

  // When false, clicking the island does not steal focus from the foreground
  // application; when true the island can take keyboard focus.
  void SetFocusable(bool focusable);
  bool focusable() const { return focusable_; }

  // Hard override that makes the whole stage transparent to the mouse.
  void SetIgnoreMouse(bool ignore);

  void SetAlwaysOnTop(bool always_on_top);
  // Re-asserts the topmost band without activating the window. Used after
  // events that are known to demote overlays (session unlock, shell restart).
  void AssertTopmost();

  void RequestFocus();
  void RequestQuit();

  // While enabled, a mouse button pressed anywhere outside the interactive
  // rectangles raises a "clickOutside" event.
  void SetOutsideClickWatch(bool enabled);

  // While enabled, the cursor entering or leaving the reveal zone raises a
  // "proximity" event. This is what lets the island hide completely and come
  // back when the pointer approaches the top of the screen.
  void SetProximityWatch(bool enabled);

  // The zone, in logical stage coordinates. Usually the collapsed island
  // inflated by a margin, so the pill is already arriving as the cursor
  // reaches it.
  void SetRevealZone(LogicalRect zone);

  void SetEventCallback(EventCallback callback);
  void AddMessageHook(MessageHook hook);

  // Describes the monitor the stage is currently placed on.
  EncodableMap DescribeStage() const;

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) noexcept;

  HMONITOR ResolveMonitor() const;
  void Emit(const std::string& type, EncodableMap payload = EncodableMap());
  LRESULT HitTest(POINT screen_point) const;

  HWND window_ = nullptr;
  HWND flutter_view_ = nullptr;
  std::unique_ptr<flutter::FlutterViewController> view_controller_;

  StagePlacement placement_;
  std::vector<LogicalRect> interactive_rects_;
  RECT bounds_ = {};
  unsigned int dpi_ = 96;
  std::string active_monitor_id_;

  bool visible_ = false;
  bool focusable_ = false;
  bool ignore_mouse_ = false;
  bool always_on_top_ = true;
  // Resizing the view before the engine has presented its first frame leaves
  // it presenting a stale, stretched surface for good. Placement requests that
  // arrive before then are parked here and applied from the first-frame hook.
  bool first_frame_presented_ = false;
  bool placement_pending_ = false;
  bool destroying_ = false;

  UINT taskbar_created_message_ = 0;
  UINT activation_message_ = 0;
  // --- The mouse watch ---------------------------------------------------
  //
  // A WH_MOUSE_LL hook is called on the thread that installed it, and Windows
  // holds every mouse event in the system until that thread answers. Installed
  // on the UI thread it therefore couples the responsiveness of the whole
  // desktop to Flutter's frame loop: one slow frame and the pointer stops
  // moving everywhere. So it lives on a thread of its own that does nothing
  // else, and the hook procedure touches only the pre-computed screen
  // rectangles below - no window handles, no DPI arithmetic, no allocation -
  // before posting a message and returning.
  std::thread mouse_thread_;
  std::atomic<DWORD> mouse_thread_id_{0};
  std::atomic<bool> mouse_running_{false};
  HANDLE mouse_ready_ = nullptr;

  std::atomic<bool> outside_click_watch_{false};
  std::atomic<bool> proximity_watch_{false};
  std::atomic<bool> proximity_inside_{false};

  // --- Click-through ------------------------------------------------------
  //
  // Answering WM_NCHITTEST with HTTRANSPARENT is only documented to hand the
  // point to windows *of the same thread*: for the application underneath -
  // which is always another process - the click is simply swallowed, and the
  // stage is a 750x450 hole in the middle of the top of the screen that eats
  // every click that lands in it. WS_EX_TRANSPARENT is the flag the system
  // itself honours, so the stage carries it whenever the pointer is not over
  // the island and drops it the moment the pointer arrives.
  //
  // The pointer position comes from the mouse watch, which is already running
  // for the other two features and already holds the island's rectangle in
  // screen pixels. The watch therefore runs whenever the stage is on screen.
  std::atomic<bool> click_through_watch_{false};
  std::atomic<bool> pointer_on_island_{false};
  std::atomic<bool> buttons_down_{false};
  std::atomic<bool> hook_installed_{false};
  bool transparent_applied_ = false;
  bool region_applied_ = false;

  // Guards the cached rectangles. Taken shared by the hook thread and
  // exclusively by the UI thread, which writes only when the stage moves.
  mutable SRWLOCK cache_lock_ = SRWLOCK_INIT;
  RECT reveal_screen_ = {};
  RECT reveal_screen_slack_ = {};
  std::vector<RECT> interactive_screen_;

  LogicalRect reveal_zone_;

  static LRESULT CALLBACK MouseHookProc(int code, WPARAM wparam,
                                        LPARAM lparam);
  void MouseWatchLoop();
  void SyncMouseHook();

  // Reads the cursor once and applies the click-through style to match. Used
  // where the pointer cannot have moved but the answer may have changed: the
  // island appearing under a stationary cursor, or resizing around it.
  void EvaluatePointerNow();

  // The single place WS_EX_TRANSPARENT is written. Transparent while the
  // stage is paused, or while the watch is running and the pointer is not on
  // the island; opaque otherwise, so a watch that failed to install leaves an
  // island that still answers the mouse.
  void UpdateTransparentStyle();

  // Converts the logical rectangles into screen pixels. Called on the UI
  // thread whenever the stage moves, the DPI changes, or either rectangle set
  // is replaced.
  void RefreshMouseCache();
  // Bound the native stage to the published interactive area. Unlike
  // HTTRANSPARENT on its own this also applies across process boundaries.
  void UpdateWindowRegion();
  EventCallback event_callback_;
  std::vector<MessageHook> message_hooks_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_WINDOW_ISLAND_WINDOW_H_
