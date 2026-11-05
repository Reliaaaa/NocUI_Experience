// DynamicBar - notification area icon and context menu.
//
// The tray owns a dedicated hidden window rather than hooking the island stage.
// Popup menus need an owner window that can be brought to the foreground, and
// the stage deliberately refuses activation while the island is collapsed;
// keeping the two apart avoids fighting over that policy.
#ifndef DYNAMICBAR_TRAY_TRAY_CHANNEL_H_
#define DYNAMICBAR_TRAY_TRAY_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

struct TrayMenuItem {
  std::string id;
  std::wstring label;
  std::string type = "normal";  // normal | separator | checkbox | submenu
  bool enabled = true;
  bool checked = false;
  bool is_default = false;
  std::vector<TrayMenuItem> children;
};

class TrayChannel {
 public:
  TrayChannel(flutter::BinaryMessenger* messenger, int icon_resource_id);
  ~TrayChannel();

  TrayChannel(const TrayChannel&) = delete;
  TrayChannel& operator=(const TrayChannel&) = delete;

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) noexcept;

  bool EnsureWindow();
  bool AddIcon();
  void RemoveIcon();
  void UpdateTooltip();
  void ShowContextMenu();
  void ShowBalloon(const std::wstring& title, const std::wstring& body,
                   int level);
  HMENU BuildMenu(const std::vector<TrayMenuItem>& items);
  void ParseMenu(const EncodableList& list, std::vector<TrayMenuItem>* out);

  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  HWND window_ = nullptr;
  HICON icon_ = nullptr;
  int icon_resource_id_ = 0;
  bool icon_added_ = false;
  std::wstring tooltip_ = L"Notch X";
  UINT taskbar_created_message_ = 0;

  std::vector<TrayMenuItem> menu_;
  std::vector<std::string> command_ids_;

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_TRAY_TRAY_CHANNEL_H_
