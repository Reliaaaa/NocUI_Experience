#ifndef DYNAMICBAR_WINDOW_SETTINGS_WINDOW_H_
#define DYNAMICBAR_WINDOW_SETTINGS_WINDOW_H_

#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>
#include <vector>

namespace dynamicbar {

// A second Flutter engine renders settings in a normal, independently
// focusable window. The main Dart isolate remains the sole settings owner.
class SettingsWindow {
 public:
  SettingsWindow(flutter::BinaryMessenger* main_messenger, int icon_resource_id);
  ~SettingsWindow();

  SettingsWindow(const SettingsWindow&) = delete;
  SettingsWindow& operator=(const SettingsWindow&) = delete;

 private:
  using Value = flutter::EncodableValue;
  using Channel = flutter::MethodChannel<Value>;
  struct PendingReply {
    std::unique_ptr<flutter::MethodResult<Value>> result;
  };
  struct ReplyState {
    std::vector<std::shared_ptr<PendingReply>> pending;
  };
  bool Open(const Value* arguments);
  void Hide();
  void NotifyMain(const std::string& method, const Value* arguments = nullptr);
  void NotifySettings(const std::string& method, const Value* arguments = nullptr);
  void Forward(Channel* channel, const std::string& method,
               const Value* arguments,
               std::unique_ptr<flutter::MethodResult<Value>> result);
  static LRESULT CALLBACK WndProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  LRESULT HandleMessage(HWND window, UINT message, WPARAM wparam,
                        LPARAM lparam) noexcept;

  HWND window_ = nullptr;
  HWND flutter_view_ = nullptr;
  std::unique_ptr<flutter::FlutterViewController> controller_;
  std::unique_ptr<Channel> main_channel_;
  std::unique_ptr<Channel> settings_channel_;
  std::unique_ptr<Value> open_arguments_;
  bool settings_ready_ = false;
  int icon_resource_id_ = 0;
  std::shared_ptr<ReplyState> replies_ = std::make_shared<ReplyState>();
};

}  // namespace dynamicbar
#endif  // DYNAMICBAR_WINDOW_SETTINGS_WINDOW_H_
