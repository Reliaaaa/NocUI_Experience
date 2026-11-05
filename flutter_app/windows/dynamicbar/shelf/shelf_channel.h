// DynamicBar - getting images onto the shelf, and back off it.
//
// Three jobs:
//
// * the clipboard. Windows hands out clipboard images as GDI bitmaps, which
//   cannot cross a platform channel and cannot be written to disk unchanged, so
//   they are encoded to PNG through WIC on the way in and rebuilt as a device
//   independent bitmap on the way out;
// * format conversion, so an imported JPEG, BMP, GIF or WebP becomes the one
//   format the shelf stores;
// * drag and drop. An `IDropTarget` is registered on the stage window, so an
//   image dragged out of a browser, Explorer or any other application lands on
//   the island directly.
//
// Text needs none of this: Flutter's own clipboard handles it.
#ifndef DYNAMICBAR_SHELF_SHELF_CHANNEL_H_
#define DYNAMICBAR_SHELF_SHELF_CHANNEL_H_

#include <windows.h>

#include <objidl.h>

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <memory>

#include "dynamicbar/core/encodable.h"
#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

class ShelfChannel {
 public:
  explicit ShelfChannel(flutter::BinaryMessenger* messenger);
  ~ShelfChannel();

  ShelfChannel(const ShelfChannel&) = delete;
  ShelfChannel& operator=(const ShelfChannel&) = delete;

  /// Registers the stage window as a drop target. Called once, after the
  /// window exists, on the thread that owns it.
  void AttachDropTarget(HWND window);

  /// Raised by the drop target. Public only because the target is a free
  /// standing COM object rather than a member.
  void ReportDrop(EncodableList paths);
  void ReportHover(bool inside);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;

  HWND drop_window_ = nullptr;
  IDropTarget* drop_target_ = nullptr;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_SHELF_SHELF_CHANNEL_H_
