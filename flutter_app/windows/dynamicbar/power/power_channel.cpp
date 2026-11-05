#include "dynamicbar/power/power_channel.h"

#include <powrprof.h>

#include <flutter/standard_method_codec.h>

#include <string>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Power";
constexpr const char kMethodChannelName[] = "dynamicbar/power";

/// Standard reason code for anything a user asked for at the keyboard.
constexpr DWORD kReason =
    SHTDN_REASON_MAJOR_OTHER | SHTDN_REASON_MINOR_OTHER |
    SHTDN_REASON_FLAG_PLANNED;

/// Turns SE_SHUTDOWN_NAME on for this process.
///
/// The privilege is present but disabled in a normal interactive token, so it
/// has to be enabled before ExitWindowsEx and is switched off again the moment
/// the call returns - a utility that sits in the tray all day should not hold
/// the right to shut the machine down while it is idle.
bool AdjustShutdownPrivilege(bool enable) {
  HANDLE token = nullptr;
  if (::OpenProcessToken(::GetCurrentProcess(),
                         TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                         &token) == FALSE) {
    return false;
  }

  LUID luid = {};
  bool ok = ::LookupPrivilegeValueW(nullptr, SE_SHUTDOWN_NAME, &luid) != FALSE;
  if (ok) {
    TOKEN_PRIVILEGES privileges = {};
    privileges.PrivilegeCount = 1;
    privileges.Privileges[0].Luid = luid;
    privileges.Privileges[0].Attributes = enable ? SE_PRIVILEGE_ENABLED : 0;
    ::AdjustTokenPrivileges(token, FALSE, &privileges, sizeof(privileges),
                            nullptr, nullptr);
    ok = ::GetLastError() == ERROR_SUCCESS;
  }
  ::CloseHandle(token);
  return ok;
}

/// True when this machine can actually enter the given sleep state. Asked
/// rather than assumed: a desktop with hibernation switched off should not be
/// offered a hibernate button that silently does nothing.
bool PowerCapabilities(bool* sleep, bool* hibernate) {
  SYSTEM_POWER_CAPABILITIES capabilities = {};
  if (::GetPwrCapabilities(&capabilities) == FALSE) {
    *sleep = true;
    *hibernate = false;
    return false;
  }
  *sleep = capabilities.SystemS1 != FALSE || capabilities.SystemS2 != FALSE ||
           capabilities.SystemS3 != FALSE ||
           capabilities.AoAc != FALSE;
  *hibernate = capabilities.SystemS4 != FALSE &&
               capabilities.HiberFilePresent != FALSE;
  return true;
}

bool Suspend(bool hibernate) {
  // The first argument is "hibernate"; the second forces the transition past
  // applications that veto it, which is never what a person clicking Sleep in
  // a tray utility means. The third disables wake events.
  return ::SetSuspendState(hibernate ? TRUE : FALSE, FALSE, FALSE) != FALSE;
}

bool ExitSession(UINT flags) {
  const bool needs_privilege = (flags & EWX_LOGOFF) == 0;
  if (needs_privilege && !AdjustShutdownPrivilege(true)) {
    DB_LOG_WARN(kTag, "Could not enable the shutdown privilege.");
    return false;
  }
  const bool ok =
      ::ExitWindowsEx(flags | EWX_FORCEIFHUNG, kReason) != FALSE;
  if (!ok) {
    DB_LOG_WARN(kTag, "ExitWindowsEx refused (" +
                          std::to_string(::GetLastError()) + ").");
  }
  if (needs_privilege) {
    AdjustShutdownPrivilege(false);
  }
  return ok;
}

/// Puts the displays to sleep without touching the session. Broadcast with a
/// timeout because one hung top-level window anywhere on the desktop would
/// otherwise stall the platform thread.
bool MonitorOff() {
  DWORD_PTR unused = 0;
  return ::SendMessageTimeoutW(HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER,
                               static_cast<LPARAM>(2), SMTO_ABORTIFHUNG, 1000,
                               &unused) != 0;
}

}  // namespace

PowerChannel::PowerChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

PowerChannel::~PowerChannel() {
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void PowerChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "capabilities") {
    bool sleep = true;
    bool hibernate = false;
    PowerCapabilities(&sleep, &hibernate);
    EncodableMap map;
    map[EncodableValue("sleep")] = EncodableValue(sleep);
    map[EncodableValue("hibernate")] = EncodableValue(hibernate);
    map[EncodableValue("lock")] = EncodableValue(true);
    map[EncodableValue("screenOff")] = EncodableValue(true);
    map[EncodableValue("shutdown")] = EncodableValue(true);
    map[EncodableValue("restart")] = EncodableValue(true);
    map[EncodableValue("signOut")] = EncodableValue(true);
    result->Success(EncodableValue(map));
    return;
  }

  if (method == "run") {
    const EncodableMap* arguments = AsMap(call.arguments());
    const EncodableMap empty;
    const std::string action =
        GetString(arguments != nullptr ? *arguments : empty, "action");

    DB_LOG_INFO(kTag, "Power action requested: " + action);

    bool ok = false;
    if (action == "lock") {
      ok = ::LockWorkStation() != FALSE;
    } else if (action == "sleep") {
      ok = Suspend(false);
    } else if (action == "hibernate") {
      ok = Suspend(true);
    } else if (action == "screenOff") {
      ok = MonitorOff();
    } else if (action == "signOut") {
      ok = ExitSession(EWX_LOGOFF);
    } else if (action == "restart") {
      ok = ExitSession(EWX_REBOOT);
    } else if (action == "shutdown") {
      // Hybrid shutdown is what the Start menu does, so "Shut down" here and
      // "Shut down" there leave the machine in the same state.
      ok = ExitSession(EWX_SHUTDOWN | EWX_HYBRID_SHUTDOWN);
    } else {
      result->Error("argument", "Unknown power action: " + action);
      return;
    }

    result->Success(EncodableValue(ok));
    return;
  }

  result->NotImplemented();
}

}  // namespace dynamicbar
