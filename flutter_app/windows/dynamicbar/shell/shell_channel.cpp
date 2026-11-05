#include "dynamicbar/shell/shell_channel.h"

// windows.h has to be seen before the shell headers; shellapi.h does not pull
// its own prerequisites in and fails with a wall of "missing type specifier"
// if it is included first.
#include <windows.h>

#include <shellapi.h>
#include <shlwapi.h>

#include <flutter/standard_method_codec.h>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Shell";
constexpr const char kMethodChannelName[] = "dynamicbar/shell";

/// ShellExecuteW returns a fake HINSTANCE; anything above 32 means it started
/// something. Below that the value is an error code worth logging, because the
/// most common one - "no application is associated" - is a real answer the user
/// needs rather than a silent failure.
bool Launch(const std::wstring& target, const std::wstring& parameters) {
  const HINSTANCE code = ::ShellExecuteW(
      nullptr, L"open", target.c_str(),
      parameters.empty() ? nullptr : parameters.c_str(), nullptr, SW_SHOWNORMAL);
  const auto value = static_cast<INT_PTR>(reinterpret_cast<uintptr_t>(code));
  if (value > 32) {
    return true;
  }
  DB_LOG_WARN(kTag, "Could not open a target (ShellExecute code " +
                        std::to_string(value) + ").");
  return false;
}

}  // namespace

ShellChannel::ShellChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

ShellChannel::~ShellChannel() {
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void ShellChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "open") {
    const std::wstring target = Utf16FromUtf8(GetString(args, "target"));
    if (target.empty()) {
      result->Error("argument", "A target is required.");
      return;
    }
    result->Success(
        EncodableValue(Launch(target, Utf16FromUtf8(GetString(args, "args")))));
    return;
  }

  if (method == "reveal") {
    // Selecting the file inside its folder is what a person means by "show me
    // where this is"; opening the folder alone loses the answer.
    const std::wstring path = Utf16FromUtf8(GetString(args, "path"));
    if (path.empty()) {
      result->Error("argument", "A path is required.");
      return;
    }
    result->Success(EncodableValue(Launch(L"explorer.exe", L"/select,\"" + path + L"\"")));
    return;
  }

  if (method == "exists") {
    const std::wstring path = Utf16FromUtf8(GetString(args, "path"));
    result->Success(
        EncodableValue(!path.empty() && ::PathFileExistsW(path.c_str()) != FALSE));
    return;
  }

  result->NotImplemented();
}

}  // namespace dynamicbar
