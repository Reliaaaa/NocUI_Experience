// DynamicBar - clipboard activity, privacy first.
//
// Windows offers a real notification for this (AddClipboardFormatListener), so
// nothing is polled and the clipboard is never read speculatively.
//
// What is reported by default is only the *shape* of what was copied: its kind,
// its size, and the application it came from. The clipboard's contents are read
// only when the user has explicitly turned on text previews, and even then only
// the first line, truncated. Copied passwords, tokens and card numbers pass
// through this listener constantly; treating them as interesting data would be
// a serious mistake.
#ifndef DYNAMICBAR_CLIPBOARD_CLIPBOARD_SERVICE_H_
#define DYNAMICBAR_CLIPBOARD_CLIPBOARD_SERVICE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>

#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

class ClipboardService {
 public:
  explicit ClipboardService(flutter::BinaryMessenger* messenger);
  ~ClipboardService();

  ClipboardService(const ClipboardService&) = delete;
  ClipboardService& operator=(const ClipboardService&) = delete;

 private:
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) noexcept;

  bool EnsureWindow();
  void SetEnabled(bool enabled);
  void OnClipboardUpdate();

  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  HWND window_ = nullptr;
  bool listening_ = false;
  bool enabled_ = false;

  /// Off unless the user turns it on in Privacy settings.
  bool text_preview_enabled_ = false;
  int preview_length_ = 80;

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_CLIPBOARD_CLIPBOARD_SERVICE_H_
