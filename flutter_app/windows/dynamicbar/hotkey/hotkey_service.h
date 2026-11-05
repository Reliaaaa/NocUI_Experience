// DynamicBar - global keyboard shortcuts.
//
// RegisterHotKey is the right API here rather than a low-level keyboard hook:
// it is cooperative, it cannot observe anything the user types, and Windows
// arbitrates conflicts between applications instead of the first one to install
// a hook winning. A utility that sits in the tray all day has no business
// watching the keyboard.
//
// Registration can legitimately fail - another application may already own the
// combination - and that failure is reported back to Dart rather than
// swallowed, so the settings screen can tell the user why their shortcut does
// nothing.
#ifndef DYNAMICBAR_HOTKEY_HOTKEY_SERVICE_H_
#define DYNAMICBAR_HOTKEY_HOTKEY_SERVICE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>
#include <unordered_map>

#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

struct HotkeyBinding {
  std::string id;
  UINT modifiers = 0;
  UINT virtual_key = 0;
};

class HotkeyService {
 public:
  explicit HotkeyService(flutter::BinaryMessenger* messenger);
  ~HotkeyService();

  HotkeyService(const HotkeyService&) = delete;
  HotkeyService& operator=(const HotkeyService&) = delete;

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) noexcept;

  bool EnsureWindow();
  void UnregisterAll();

  /// Registers the given set, replacing whatever was registered before.
  /// Returns one entry per binding describing whether it took effect.
  EncodableList Apply(const EncodableList& bindings);

  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  HWND window_ = nullptr;
  int next_id_ = 1;
  std::unordered_map<int, HotkeyBinding> registered_;

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_HOTKEY_HOTKEY_SERVICE_H_
