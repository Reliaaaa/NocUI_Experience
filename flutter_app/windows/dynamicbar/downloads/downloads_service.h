// DynamicBar - download activity.
//
// Windows has no "current downloads" API; downloads belong to whichever browser
// or tool started them. What every one of them does have in common is that the
// bytes land in the Downloads folder, and that in-progress files carry a
// partial-download extension (.crdownload, .part, .tmp, .download, .opdownload)
// which is renamed away on completion.
//
// So this service watches that folder with ReadDirectoryChangesW - an event
// driven API, not a polling loop - and reconstructs the lifecycle from the file
// system itself. It is honest about what it can and cannot know: transferred
// bytes and transfer rate are measured directly, while a percentage is only
// reported when the total size is actually knowable, which for a partial file
// it is not. The Dart side treats such downloads as indeterminate rather than
// inventing a number.
#ifndef DYNAMICBAR_DOWNLOADS_DOWNLOADS_SERVICE_H_
#define DYNAMICBAR_DOWNLOADS_DOWNLOADS_SERVICE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <atomic>
#include <memory>
#include <string>
#include <thread>
#include <unordered_map>

#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

/// One file being written into the Downloads folder.
struct DownloadRecord {
  std::wstring file_name;
  std::string id;
  int64_t bytes = 0;
  int64_t previous_bytes = 0;
  int64_t started_at_ms = 0;
  int64_t updated_at_ms = 0;
  double bytes_per_second = 0;
  bool partial = false;
};

class DownloadsService {
 public:
  explicit DownloadsService(flutter::BinaryMessenger* messenger);
  ~DownloadsService();

  DownloadsService(const DownloadsService&) = delete;
  DownloadsService& operator=(const DownloadsService&) = delete;

 private:
  void SetEnabled(bool enabled);
  void WatchLoop();
  void StopWatching();

  /// Called on the platform thread for each change the watcher observed.
  void OnFileChanged(DWORD action, const std::wstring& name,
                     const std::wstring& old_name);

  void EmitStarted(const DownloadRecord& record);
  void EmitProgress(const DownloadRecord& record);
  void EmitFinished(const DownloadRecord& record, const std::string& outcome);

  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  std::wstring downloads_directory_;
  std::thread worker_;
  std::atomic<bool> running_{false};
  HANDLE stop_event_ = nullptr;
  HANDLE directory_ = nullptr;

  std::unordered_map<std::wstring, DownloadRecord> active_;
  int64_t next_id_ = 1;
  int64_t last_progress_emit_ms_ = 0;

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_DOWNLOADS_DOWNLOADS_SERVICE_H_
