#include "dynamicbar/window/window_channel.h"

#include <flutter/standard_method_codec.h>

#include <string>
#include <vector>

#include "dynamicbar/core/logging.h"
#include "dynamicbar/window/window_effects.h"

namespace dynamicbar {
namespace {
constexpr const char kTag[] = "WindowChannel";
constexpr const char kMethodChannelName[] = "dynamicbar/window";
constexpr const char kEventChannelName[] = "dynamicbar/window/events";
}  // namespace

WindowChannel::WindowChannel(flutter::BinaryMessenger* messenger,
                             IslandWindow* window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });

  events_ = std::make_unique<EventEmitter>(messenger, kEventChannelName);
  window_->SetEventCallback([this](const std::string& type,
                                   EncodableMap payload) {
    events_->Emit(type, std::move(payload));
  });
}

WindowChannel::~WindowChannel() {
  if (window_ != nullptr) {
    window_->SetEventCallback(nullptr);
  }
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void WindowChannel::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "describe") {
    result->Success(EncodableValue(window_->DescribeStage()));
    return;
  }

  if (method == "setPlacement") {
    StagePlacement placement = window_->placement();
    if (FindValue(args, "monitorId") != nullptr) {
      placement.monitor_id = GetString(args, "monitorId");
    }
    placement.width = GetDouble(args, "width", placement.width);
    placement.height = GetDouble(args, "height", placement.height);
    placement.align_x = GetDouble(args, "alignX", placement.align_x);
    placement.offset_x = GetDouble(args, "offsetX", placement.offset_x);
    placement.offset_y = GetDouble(args, "offsetY", placement.offset_y);
    placement.use_work_area =
        GetBool(args, "useWorkArea", placement.use_work_area);
    window_->SetPlacement(placement);
    result->Success(EncodableValue(window_->DescribeStage()));
    return;
  }

  if (method == "setInteractiveRects") {
    std::vector<LogicalRect> rects;
    if (const EncodableList* list = GetList(args, "rects")) {
      rects.reserve(list->size());
      for (const EncodableValue& entry : *list) {
        const EncodableMap* rect_map = AsMap(&entry);
        if (rect_map == nullptr) {
          continue;
        }
        LogicalRect rect;
        rect.left = GetDouble(*rect_map, "left");
        rect.top = GetDouble(*rect_map, "top");
        rect.right = GetDouble(*rect_map, "right");
        rect.bottom = GetDouble(*rect_map, "bottom");
        if (rect.right > rect.left && rect.bottom > rect.top) {
          rects.push_back(rect);
        }
      }
    }
    window_->SetInteractiveRects(std::move(rects));
    result->Success();
    return;
  }

  if (method == "setVisible") {
    window_->SetVisible(GetBool(args, "visible", true));
    result->Success();
    return;
  }

  if (method == "setFocusable") {
    window_->SetFocusable(GetBool(args, "focusable", false));
    result->Success();
    return;
  }

  if (method == "setIgnoreMouse") {
    window_->SetIgnoreMouse(GetBool(args, "ignore", false));
    result->Success();
    return;
  }

  if (method == "setAlwaysOnTop") {
    window_->SetAlwaysOnTop(GetBool(args, "value", true));
    result->Success();
    return;
  }

  if (method == "assertTopmost") {
    window_->AssertTopmost();
    result->Success();
    return;
  }

  if (method == "setOutsideClickWatch") {
    window_->SetOutsideClickWatch(GetBool(args, "enabled", false));
    result->Success();
    return;
  }

  if (method == "setProximityWatch") {
    window_->SetProximityWatch(GetBool(args, "enabled", false));
    result->Success();
    return;
  }

  if (method == "setRevealZone") {
    LogicalRect zone;
    zone.left = GetDouble(args, "left");
    zone.top = GetDouble(args, "top");
    zone.right = GetDouble(args, "right");
    zone.bottom = GetDouble(args, "bottom");
    window_->SetRevealZone(zone);
    result->Success();
    return;
  }

  if (method == "requestFocus") {
    window_->RequestFocus();
    result->Success();
    return;
  }

  if (method == "systemPrefersDarkMode") {
    result->Success(EncodableValue(SystemPrefersDarkMode()));
    return;
  }

  if (method == "log") {
    const std::string level = GetString(args, "level", "info");
    const std::string tag = GetString(args, "tag", "Dart");
    const std::string message = GetString(args, "message");
    LogLevel parsed = LogLevel::kInfo;
    if (level == "trace") {
      parsed = LogLevel::kTrace;
    } else if (level == "debug") {
      parsed = LogLevel::kDebug;
    } else if (level == "warn") {
      parsed = LogLevel::kWarn;
    } else if (level == "error") {
      parsed = LogLevel::kError;
    }
    LogMessage(parsed, tag.c_str(), message);
    result->Success();
    return;
  }

  if (method == "logPath") {
    result->Success(EncodableValue(Utf8FromUtf16(LogFilePath())));
    return;
  }

  if (method == "quit") {
    window_->RequestQuit();
    result->Success();
    return;
  }

  DB_LOG_WARN(kTag, "Unimplemented window method: " + method);
  result->NotImplemented();
}

}  // namespace dynamicbar
