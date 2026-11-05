// DynamicBar - launch at sign-in.
//
// Uses the per-user Run key rather than a scheduled task or a service: it needs
// no elevation, it is visible to the user in Task Manager's Startup tab where
// they would look for it, and Windows lets them disable it there without the
// application having to agree.
//
// The registered command is re-verified on every launch. A utility like this
// gets moved, re-installed into a different folder, or copied to a new machine,
// and a Run entry pointing at a path that no longer exists is a startup that
// silently stopped working.
#ifndef DYNAMICBAR_STARTUP_STARTUP_SERVICE_H_
#define DYNAMICBAR_STARTUP_STARTUP_SERVICE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "dynamicbar/core/encodable.h"

namespace dynamicbar {

class StartupService {
 public:
  explicit StartupService(flutter::BinaryMessenger* messenger);
  ~StartupService();

  StartupService(const StartupService&) = delete;
  StartupService& operator=(const StartupService&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  static std::wstring ExecutablePath();
  static std::wstring ExpectedCommand();

  /// Whether a Run entry exists at all.
  static bool IsRegistered();

  /// Whether the Run entry exists *and* points at this executable.
  static bool IsHealthy();

  static bool Register();
  static bool Unregister();

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_STARTUP_STARTUP_SERVICE_H_
