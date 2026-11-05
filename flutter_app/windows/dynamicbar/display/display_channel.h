// DynamicBar - monitor enumeration.
//
// There is no event channel here on purpose: the stage window already reports
// displaysChanged / dpiChanged / workAreaChanged, and Dart re-lists on those.
// One source of truth, no duplicated notifications.
#ifndef DYNAMICBAR_DISPLAY_DISPLAY_CHANNEL_H_
#define DYNAMICBAR_DISPLAY_DISPLAY_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <memory>

#include "dynamicbar/core/encodable.h"

namespace dynamicbar {

class DisplayChannel {
 public:
  explicit DisplayChannel(flutter::BinaryMessenger* messenger);
  ~DisplayChannel();

  DisplayChannel(const DisplayChannel&) = delete;
  DisplayChannel& operator=(const DisplayChannel&) = delete;

  // Exposed for other services that need the current monitor topology.
  static EncodableList ListDisplays();

 private:
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_DISPLAY_DISPLAY_CHANNEL_H_
