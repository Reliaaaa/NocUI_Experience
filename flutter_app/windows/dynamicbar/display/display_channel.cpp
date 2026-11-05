#include "dynamicbar/display/display_channel.h"

#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
#include <windows.h>

#include <string>

#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "DisplayChannel";
constexpr const char kMethodChannelName[] = "dynamicbar/display";

EncodableValue RectValue(const RECT& rect) {
  return EncodableValue(EncodableMap{
      {EncodableValue("left"), EncodableValue(static_cast<int64_t>(rect.left))},
      {EncodableValue("top"), EncodableValue(static_cast<int64_t>(rect.top))},
      {EncodableValue("width"),
       EncodableValue(static_cast<int64_t>(rect.right - rect.left))},
      {EncodableValue("height"),
       EncodableValue(static_cast<int64_t>(rect.bottom - rect.top))},
  });
}

std::wstring FriendlyNameFor(const wchar_t* device_name) {
  DISPLAY_DEVICEW device = {};
  device.cb = sizeof(DISPLAY_DEVICEW);
  if (::EnumDisplayDevicesW(device_name, 0, &device, 0)) {
    return device.DeviceString;
  }
  return std::wstring(device_name);
}

BOOL CALLBACK CollectMonitorProc(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* list = reinterpret_cast<EncodableList*>(data);

  MONITORINFOEXW info = {};
  info.cbSize = sizeof(MONITORINFOEXW);
  if (!::GetMonitorInfoW(monitor, &info)) {
    return TRUE;
  }
  UINT dpi = ::FlutterDesktopGetDpiForMonitor(monitor);
  if (dpi == 0) {
    dpi = 96;
  }

  list->push_back(EncodableValue(EncodableMap{
      {EncodableValue("id"), EncodableValue(Utf8FromUtf16(info.szDevice))},
      {EncodableValue("name"),
       EncodableValue(Utf8FromUtf16(FriendlyNameFor(info.szDevice)))},
      {EncodableValue("primary"),
       EncodableValue((info.dwFlags & MONITORINFOF_PRIMARY) != 0)},
      {EncodableValue("bounds"), RectValue(info.rcMonitor)},
      {EncodableValue("workArea"), RectValue(info.rcWork)},
      {EncodableValue("dpi"), EncodableValue(static_cast<int64_t>(dpi))},
      {EncodableValue("scale"), EncodableValue(dpi / 96.0)},
  }));
  return TRUE;
}

}  // namespace

// static
EncodableList DisplayChannel::ListDisplays() {
  EncodableList displays;
  ::EnumDisplayMonitors(nullptr, nullptr, CollectMonitorProc,
                        reinterpret_cast<LPARAM>(&displays));
  return displays;
}

DisplayChannel::DisplayChannel(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "list") {
          result->Success(EncodableValue(ListDisplays()));
          return;
        }
        DB_LOG_WARN(kTag, "Unimplemented display method: " + call.method_name());
        result->NotImplemented();
      });
}

DisplayChannel::~DisplayChannel() {
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

}  // namespace dynamicbar
