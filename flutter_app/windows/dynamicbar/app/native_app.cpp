#include "dynamicbar/app/native_app.h"

#include <windows.h>

#include "dynamicbar/core/dispatcher.h"
#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {
constexpr const char kTag[] = "NativeApp";
}  // namespace

NativeApp::NativeApp() = default;

NativeApp::~NativeApp() {
  Shutdown();
}

int NativeApp::Run(const flutter::DartProject& project, int icon_resource_id) {
  InitLogging();
  DB_LOG_INFO(kTag, "DynamicBar starting.");

  if (!MainThreadDispatcher::Instance().Initialize()) {
    DB_LOG_ERROR(kTag, "Dispatcher unavailable; native events would be lost.");
    return EXIT_FAILURE;
  }

  window_ = std::make_unique<IslandWindow>();
  if (!window_->Create(project)) {
    DB_LOG_ERROR(kTag, "Unable to create the island stage.");
    Shutdown();
    return EXIT_FAILURE;
  }

  flutter::BinaryMessenger* messenger = window_->messenger();
  if (messenger == nullptr) {
    DB_LOG_ERROR(kTag, "Engine started without a messenger.");
    Shutdown();
    return EXIT_FAILURE;
  }

  window_channel_ = std::make_unique<WindowChannel>(messenger, window_.get());
  settings_window_ = std::make_unique<SettingsWindow>(messenger, icon_resource_id);
  display_channel_ = std::make_unique<DisplayChannel>(messenger);
  shell_channel_ = std::make_unique<ShellChannel>(messenger);
  shelf_channel_ = std::make_unique<ShelfChannel>(messenger);
  // The stage is click-through outside the island's own rectangle, so a drag
  // that misses the island passes to whatever is underneath; one that lands on
  // it comes here.
  shelf_channel_->AttachDropTarget(window_->handle());
  tray_channel_ = std::make_unique<TrayChannel>(messenger, icon_resource_id);
  media_service_ = std::make_unique<MediaService>(messenger);
  clipboard_service_ = std::make_unique<ClipboardService>(messenger);
  downloads_service_ = std::make_unique<DownloadsService>(messenger);
  system_service_ = std::make_unique<SystemService>(messenger);
  connectivity_service_ = std::make_unique<ConnectivityService>(messenger);
  power_channel_ = std::make_unique<PowerChannel>(messenger);
  hotkey_service_ = std::make_unique<HotkeyService>(messenger);
  startup_service_ = std::make_unique<StartupService>(messenger);

  DB_LOG_INFO(kTag, "Native services installed; entering the message loop.");

  MSG message = {};
  while (::GetMessageW(&message, nullptr, 0, 0)) {
    ::TranslateMessage(&message);
    ::DispatchMessageW(&message);
  }

  DB_LOG_INFO(kTag, "Message loop finished.");
  Shutdown();
  return EXIT_SUCCESS;
}

void NativeApp::Shutdown() {
  // Channels first: they hold raw pointers into the engine and the window.
  settings_window_.reset();
  startup_service_.reset();
  hotkey_service_.reset();
  power_channel_.reset();
  connectivity_service_.reset();
  system_service_.reset();
  downloads_service_.reset();
  clipboard_service_.reset();
  media_service_.reset();
  tray_channel_.reset();
  shelf_channel_.reset();
  shell_channel_.reset();
  display_channel_.reset();
  window_channel_.reset();
  window_.reset();
  MainThreadDispatcher::Instance().Shutdown();
  DB_LOG_INFO(kTag, "DynamicBar stopped.");
  ShutdownLogging();
}

}  // namespace dynamicbar
