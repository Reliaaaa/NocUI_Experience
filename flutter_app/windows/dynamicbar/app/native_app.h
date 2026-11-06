// DynamicBar - composition root for the native side.
//
// Owns the stage window and every native service, in a fixed construction and
// teardown order, so that no channel outlives the engine it talks to.
#ifndef DYNAMICBAR_APP_NATIVE_APP_H_
#define DYNAMICBAR_APP_NATIVE_APP_H_

#include <flutter/dart_project.h>

#include <memory>

#include "dynamicbar/clipboard/clipboard_service.h"
#include "dynamicbar/connectivity/connectivity_service.h"
#include "dynamicbar/display/display_channel.h"
#include "dynamicbar/downloads/downloads_service.h"
#include "dynamicbar/hotkey/hotkey_service.h"
#include "dynamicbar/media/media_service.h"
#include "dynamicbar/power/power_channel.h"
#include "dynamicbar/shelf/shelf_channel.h"
#include "dynamicbar/shell/shell_channel.h"
#include "dynamicbar/startup/startup_service.h"
#include "dynamicbar/system/system_service.h"
#include "dynamicbar/tray/tray_channel.h"
#include "dynamicbar/window/island_window.h"
#include "dynamicbar/window/window_channel.h"
#include "dynamicbar/window/settings_window.h"

namespace dynamicbar {

class NativeApp {
 public:
  NativeApp();
  ~NativeApp();

  NativeApp(const NativeApp&) = delete;
  NativeApp& operator=(const NativeApp&) = delete;

  // Starts the engine, installs the services and runs the message loop.
  // Returns the process exit code.
  int Run(const flutter::DartProject& project, int icon_resource_id);

 private:
  void Shutdown();

  std::unique_ptr<IslandWindow> window_;
  std::unique_ptr<WindowChannel> window_channel_;
  std::unique_ptr<SettingsWindow> settings_window_;
  std::unique_ptr<DisplayChannel> display_channel_;
  std::unique_ptr<ShellChannel> shell_channel_;
  std::unique_ptr<ShelfChannel> shelf_channel_;
  std::unique_ptr<TrayChannel> tray_channel_;
  std::unique_ptr<MediaService> media_service_;
  std::unique_ptr<ClipboardService> clipboard_service_;
  std::unique_ptr<DownloadsService> downloads_service_;
  std::unique_ptr<SystemService> system_service_;
  std::unique_ptr<ConnectivityService> connectivity_service_;
  std::unique_ptr<PowerChannel> power_channel_;
  std::unique_ptr<HotkeyService> hotkey_service_;
  std::unique_ptr<StartupService> startup_service_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_APP_NATIVE_APP_H_
