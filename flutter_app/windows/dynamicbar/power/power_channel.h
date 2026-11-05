// DynamicBar - the session and machine power actions.
//
// Six things Windows will do to a session, behind one call. Nothing here
// observes anything: the channel has no state, no timer and no thread, and
// every method runs exactly once because a person clicked something.
//
// The destructive three (shut down, restart, sign out) need SE_SHUTDOWN_NAME,
// which a normal interactive process has but does not hold enabled. The
// privilege is enabled for the length of the call and dropped again, rather
// than being left switched on for the life of a tray utility.
#ifndef DYNAMICBAR_POWER_POWER_CHANNEL_H_
#define DYNAMICBAR_POWER_POWER_CHANNEL_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <memory>

#include "dynamicbar/core/encodable.h"

namespace dynamicbar {

class PowerChannel {
 public:
  explicit PowerChannel(flutter::BinaryMessenger* messenger);
  ~PowerChannel();

  PowerChannel(const PowerChannel&) = delete;
  PowerChannel& operator=(const PowerChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_POWER_POWER_CHANNEL_H_
