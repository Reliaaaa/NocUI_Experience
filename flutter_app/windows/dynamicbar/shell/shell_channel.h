// DynamicBar - launching things.
//
// One narrow door onto ShellExecuteW, used by the Shortcuts page and by every
// "open the Windows panel for this" button. It launches; it never enumerates,
// never watches and never keeps a handle, so there is nothing here to leak and
// nothing to switch off.
#ifndef DYNAMICBAR_SHELL_SHELL_CHANNEL_H_
#define DYNAMICBAR_SHELL_SHELL_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "dynamicbar/core/encodable.h"

namespace dynamicbar {

class ShellChannel {
 public:
  explicit ShellChannel(flutter::BinaryMessenger* messenger);
  ~ShellChannel();

  ShellChannel(const ShellChannel&) = delete;
  ShellChannel& operator=(const ShellChannel&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_SHELL_SHELL_CHANNEL_H_
