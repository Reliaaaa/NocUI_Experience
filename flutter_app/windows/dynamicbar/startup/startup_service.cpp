#include "dynamicbar/startup/startup_service.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Startup";
constexpr const char kMethodChannelName[] = "dynamicbar/startup";
constexpr const wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr const wchar_t kValueName[] = L"NocUIExperience.Flutter";

/// Marks a launch as automatic so the application can honour a start delay and
/// a "start paused" preference without guessing.
constexpr const wchar_t kAutoStartFlag[] = L" --autostart";

std::wstring ReadRunValue() {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return std::wstring();
  }
  wchar_t buffer[1024] = {};
  DWORD size = sizeof(buffer);
  DWORD type = 0;
  const LSTATUS status = ::RegQueryValueExW(
      key, kValueName, nullptr, &type, reinterpret_cast<LPBYTE>(buffer), &size);
  ::RegCloseKey(key);
  if (status != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ)) {
    return std::wstring();
  }
  return std::wstring(buffer);
}

}  // namespace

StartupService::StartupService(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
}

StartupService::~StartupService() {
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

std::wstring StartupService::ExecutablePath() {
  wchar_t buffer[MAX_PATH] = {};
  const DWORD length =
      ::GetModuleFileNameW(nullptr, buffer, static_cast<DWORD>(MAX_PATH));
  if (length == 0 || length >= MAX_PATH) {
    return std::wstring();
  }
  return std::wstring(buffer, length);
}

std::wstring StartupService::ExpectedCommand() {
  const std::wstring path = ExecutablePath();
  if (path.empty()) {
    return std::wstring();
  }
  return L"\"" + path + L"\"" + kAutoStartFlag;
}

bool StartupService::IsRegistered() {
  return !ReadRunValue().empty();
}

bool StartupService::IsHealthy() {
  const std::wstring current = ReadRunValue();
  if (current.empty()) {
    return false;
  }
  return current == ExpectedCommand();
}

bool StartupService::Register() {
  const std::wstring command = ExpectedCommand();
  if (command.empty()) {
    DB_LOG_ERROR(kTag, "Could not determine the executable path.");
    return false;
  }
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0, KEY_WRITE,
                        nullptr, &key, nullptr) != ERROR_SUCCESS) {
    DB_LOG_ERROR(kTag, "Could not open the Run key for writing.");
    return false;
  }
  const LSTATUS status = ::RegSetValueExW(
      key, kValueName, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(key);
  if (status != ERROR_SUCCESS) {
    DB_LOG_ERROR(kTag, "Writing the Run value failed.");
    return false;
  }
  DB_LOG_INFO(kTag, "Registered for launch at sign-in.");
  return true;
}

bool StartupService::Unregister() {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_WRITE, &key) !=
      ERROR_SUCCESS) {
    return true;  // Nothing to remove.
  }
  const LSTATUS status = ::RegDeleteValueW(key, kValueName);
  ::RegCloseKey(key);
  const bool ok = status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
  if (ok) {
    DB_LOG_INFO(kTag, "Removed from launch at sign-in.");
  }
  return ok;
}

void StartupService::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "status") {
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("registered"), EncodableValue(IsRegistered())},
        {EncodableValue("healthy"), EncodableValue(IsHealthy())},
        {EncodableValue("command"),
         EncodableValue(Utf8FromUtf16(ReadRunValue()))},
        {EncodableValue("expected"),
         EncodableValue(Utf8FromUtf16(ExpectedCommand()))},
    }));
    return;
  }

  if (method == "setEnabled") {
    const bool enabled = GetBool(args, "enabled", false);
    result->Success(EncodableValue(enabled ? Register() : Unregister()));
    return;
  }

  if (method == "repair") {
    // The entry exists but points somewhere else: the application was moved or
    // reinstalled. Rewriting it is the whole point of tracking health.
    if (IsRegistered() && !IsHealthy()) {
      DB_LOG_WARN(kTag, "Startup entry was stale; rewriting it.");
      result->Success(EncodableValue(Register()));
      return;
    }
    result->Success(EncodableValue(false));
    return;
  }

  DB_LOG_WARN(kTag, "Unimplemented startup method: " + method);
  result->NotImplemented();
}

}  // namespace dynamicbar
