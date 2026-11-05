// DynamicBar - Dart facing control surface for the island stage.
#ifndef DYNAMICBAR_WINDOW_WINDOW_CHANNEL_H_
#define DYNAMICBAR_WINDOW_WINDOW_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <memory>

#include "dynamicbar/core/event_emitter.h"
#include "dynamicbar/window/island_window.h"

namespace dynamicbar {

class WindowChannel {
 public:
  WindowChannel(flutter::BinaryMessenger* messenger, IslandWindow* window);
  ~WindowChannel();

  WindowChannel(const WindowChannel&) = delete;
  WindowChannel& operator=(const WindowChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  IslandWindow* window_;
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_WINDOW_WINDOW_CHANNEL_H_
