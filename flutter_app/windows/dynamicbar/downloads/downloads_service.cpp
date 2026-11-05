#include "dynamicbar/downloads/downloads_service.h"

#include <flutter/standard_method_codec.h>
#include <knownfolders.h>
#include <shlobj.h>
#include <shlwapi.h>

#include <algorithm>
#include <chrono>
#include <vector>

#include "dynamicbar/core/dispatcher.h"
#include "dynamicbar/core/logging.h"

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Downloads";
constexpr const char kMethodChannelName[] = "dynamicbar/downloads";
constexpr const char kEventChannelName[] = "dynamicbar/downloads/events";

/// At most four progress events per second. The island shows a rate and a bar;
/// beyond this the extra frames are invisible and the channel traffic is not.
constexpr int64_t kProgressIntervalMs = 250;

constexpr DWORD kNotifyFilter = FILE_NOTIFY_CHANGE_FILE_NAME |
                                FILE_NOTIFY_CHANGE_SIZE |
                                FILE_NOTIFY_CHANGE_LAST_WRITE;

const wchar_t* const kPartialExtensions[] = {
    L".crdownload", L".part", L".download", L".partial", L".opdownload",
    L".tmp",        L".!ut",  L".aria2",
};

int64_t NowMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

bool HasPartialExtension(const std::wstring& name) {
  for (const wchar_t* extension : kPartialExtensions) {
    const size_t length = ::wcslen(extension);
    if (name.size() > length &&
        ::_wcsicmp(name.c_str() + name.size() - length, extension) == 0) {
      return true;
    }
  }
  return false;
}

/// Strips one partial-download extension, so `film.mkv.crdownload` is shown to
/// the user as `film.mkv` while it is still arriving.
std::wstring DisplayName(const std::wstring& name) {
  for (const wchar_t* extension : kPartialExtensions) {
    const size_t length = ::wcslen(extension);
    if (name.size() > length &&
        ::_wcsicmp(name.c_str() + name.size() - length, extension) == 0) {
      return name.substr(0, name.size() - length);
    }
  }
  return name;
}

int64_t FileSizeOf(const std::wstring& path) {
  WIN32_FILE_ATTRIBUTE_DATA data = {};
  if (!::GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &data)) {
    return -1;
  }
  if ((data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
    return -1;
  }
  LARGE_INTEGER size = {};
  size.LowPart = data.nFileSizeLow;
  size.HighPart = static_cast<LONG>(data.nFileSizeHigh);
  return size.QuadPart;
}

std::wstring KnownDownloadsFolder() {
  PWSTR path = nullptr;
  std::wstring result;
  if (SUCCEEDED(::SHGetKnownFolderPath(FOLDERID_Downloads, 0, nullptr,
                                       &path)) &&
      path != nullptr) {
    result.assign(path);
  }
  if (path != nullptr) {
    ::CoTaskMemFree(path);
  }
  return result;
}

}  // namespace

DownloadsService::DownloadsService(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
  events_ = std::make_unique<EventEmitter>(messenger, kEventChannelName);
}

DownloadsService::~DownloadsService() {
  StopWatching();
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void DownloadsService::SetEnabled(bool enabled) {
  if (enabled == running_.load()) {
    return;
  }
  if (!enabled) {
    StopWatching();
    return;
  }

  downloads_directory_ = KnownDownloadsFolder();
  if (downloads_directory_.empty()) {
    DB_LOG_WARN(kTag, "The Downloads folder could not be resolved.");
    return;
  }

  directory_ = ::CreateFileW(
      downloads_directory_.c_str(), FILE_LIST_DIRECTORY,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
      OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED,
      nullptr);
  if (directory_ == INVALID_HANDLE_VALUE) {
    directory_ = nullptr;
    DB_LOG_WARN(kTag, "The Downloads folder could not be opened for watching.");
    return;
  }

  stop_event_ = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  running_.store(true);
  worker_ = std::thread(&DownloadsService::WatchLoop, this);
  DB_LOG_INFO(kTag, "Watching " + Utf8FromUtf16(downloads_directory_) + ".");
}

void DownloadsService::StopWatching() {
  if (!running_.load()) {
    return;
  }
  running_.store(false);
  if (stop_event_ != nullptr) {
    ::SetEvent(stop_event_);
  }
  if (directory_ != nullptr) {
    // Unblocks the pending ReadDirectoryChangesW.
    ::CancelIoEx(directory_, nullptr);
  }
  if (worker_.joinable()) {
    worker_.join();
  }
  if (directory_ != nullptr) {
    ::CloseHandle(directory_);
    directory_ = nullptr;
  }
  if (stop_event_ != nullptr) {
    ::CloseHandle(stop_event_);
    stop_event_ = nullptr;
  }
  DB_LOG_INFO(kTag, "Stopped watching the Downloads folder.");
}

void DownloadsService::WatchLoop() {
  // 64 KiB, the documented maximum for a network path and comfortably more
  // than a Downloads folder ever produces in one batch.
  std::vector<uint8_t> buffer(64 * 1024);
  OVERLAPPED overlapped = {};
  overlapped.hEvent = ::CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (overlapped.hEvent == nullptr) {
    return;
  }

  while (running_.load()) {
    ::ResetEvent(overlapped.hEvent);
    DWORD returned = 0;
    if (!::ReadDirectoryChangesW(directory_, buffer.data(),
                                 static_cast<DWORD>(buffer.size()), FALSE,
                                 kNotifyFilter, &returned, &overlapped,
                                 nullptr)) {
      break;
    }

    HANDLE waits[2] = {overlapped.hEvent, stop_event_};
    const DWORD wait = ::WaitForMultipleObjects(2, waits, FALSE, INFINITE);
    if (wait != WAIT_OBJECT_0 || !running_.load()) {
      break;
    }

    DWORD transferred = 0;
    if (!::GetOverlappedResult(directory_, &overlapped, &transferred, FALSE) ||
        transferred == 0) {
      continue;
    }

    size_t offset = 0;
    std::wstring pending_old_name;
    while (offset < transferred) {
      const auto* info = reinterpret_cast<const FILE_NOTIFY_INFORMATION*>(
          buffer.data() + offset);
      std::wstring name(info->FileName,
                        info->FileNameLength / sizeof(wchar_t));
      const DWORD action = info->Action;

      if (action == FILE_ACTION_RENAMED_OLD_NAME) {
        pending_old_name = name;
      } else {
        std::wstring old_name = pending_old_name;
        pending_old_name.clear();
        MainThreadDispatcher::Instance().Post([this, action, name, old_name]() {
          OnFileChanged(action, name, old_name);
        });
      }

      if (info->NextEntryOffset == 0) {
        break;
      }
      offset += info->NextEntryOffset;
    }
  }

  ::CloseHandle(overlapped.hEvent);
}

void DownloadsService::OnFileChanged(DWORD action, const std::wstring& name,
                                     const std::wstring& old_name) {
  if (name.empty()) {
    return;
  }
  const std::wstring path =
      downloads_directory_ + L"\\" + name;
  const int64_t now = NowMs();

  switch (action) {
    case FILE_ACTION_ADDED: {
      if (!HasPartialExtension(name)) {
        // A file that appears complete on arrival: a small download, a copy, or
        // a browser that writes straight to the final name.
        const int64_t size = FileSizeOf(path);
        if (size < 0) {
          return;
        }
        DownloadRecord record;
        record.file_name = name;
        record.id = std::to_string(next_id_++);
        record.bytes = size;
        record.started_at_ms = now;
        record.updated_at_ms = now;
        EmitFinished(record, "completed");
        return;
      }
      DownloadRecord record;
      record.file_name = name;
      record.id = std::to_string(next_id_++);
      record.bytes = std::max<int64_t>(FileSizeOf(path), 0);
      record.previous_bytes = record.bytes;
      record.started_at_ms = now;
      record.updated_at_ms = now;
      record.partial = true;
      active_[name] = record;
      EmitStarted(record);
      return;
    }

    case FILE_ACTION_MODIFIED: {
      auto it = active_.find(name);
      if (it == active_.end()) {
        return;
      }
      const int64_t size = FileSizeOf(path);
      if (size < 0) {
        return;
      }
      DownloadRecord& record = it->second;
      const int64_t elapsed = now - record.updated_at_ms;
      if (elapsed > 0) {
        const double instant =
            static_cast<double>(size - record.bytes) * 1000.0 / elapsed;
        // Light smoothing; a raw per-event rate jitters far too much to read.
        record.bytes_per_second = record.bytes_per_second <= 0
                                      ? instant
                                      : record.bytes_per_second * 0.6 +
                                            instant * 0.4;
      }
      record.previous_bytes = record.bytes;
      record.bytes = size;
      record.updated_at_ms = now;

      if (now - last_progress_emit_ms_ >= kProgressIntervalMs) {
        last_progress_emit_ms_ = now;
        EmitProgress(record);
      }
      return;
    }

    case FILE_ACTION_RENAMED_NEW_NAME: {
      auto it = active_.find(old_name);
      if (it == active_.end()) {
        // Something was renamed into the folder without us tracking it.
        return;
      }
      DownloadRecord record = it->second;
      active_.erase(it);
      record.file_name = name;
      record.bytes = std::max<int64_t>(FileSizeOf(path), record.bytes);
      record.updated_at_ms = now;
      if (HasPartialExtension(name)) {
        // Renamed from one partial name to another; still in flight.
        active_[name] = record;
        EmitProgress(record);
        return;
      }
      EmitFinished(record, "completed");
      return;
    }

    case FILE_ACTION_REMOVED: {
      auto it = active_.find(name);
      if (it == active_.end()) {
        return;
      }
      DownloadRecord record = it->second;
      active_.erase(it);
      // A partial file that disappears was cancelled or failed; we cannot tell
      // which, and saying "failed" for a deliberate cancel would be wrong.
      EmitFinished(record, "cancelled");
      return;
    }

    default:
      return;
  }
}

void DownloadsService::EmitStarted(const DownloadRecord& record) {
  events_->Emit("started",
                EncodableMap{
                    {EncodableValue("id"), EncodableValue(record.id)},
                    {EncodableValue("name"),
                     EncodableValue(Utf8FromUtf16(DisplayName(record.file_name)))},
                    {EncodableValue("bytes"), EncodableValue(record.bytes)},
                    {EncodableValue("startedAtMs"),
                     EncodableValue(record.started_at_ms)},
                });
}

void DownloadsService::EmitProgress(const DownloadRecord& record) {
  events_->Emit(
      "progress",
      EncodableMap{
          {EncodableValue("id"), EncodableValue(record.id)},
          {EncodableValue("name"),
           EncodableValue(Utf8FromUtf16(DisplayName(record.file_name)))},
          {EncodableValue("bytes"), EncodableValue(record.bytes)},
          {EncodableValue("bytesPerSecond"),
           EncodableValue(record.bytes_per_second)},
          {EncodableValue("updatedAtMs"), EncodableValue(record.updated_at_ms)},
      });
}

void DownloadsService::EmitFinished(const DownloadRecord& record,
                                    const std::string& outcome) {
  events_->Emit(
      "finished",
      EncodableMap{
          {EncodableValue("id"), EncodableValue(record.id)},
          {EncodableValue("name"),
           EncodableValue(Utf8FromUtf16(DisplayName(record.file_name)))},
          {EncodableValue("bytes"), EncodableValue(record.bytes)},
          {EncodableValue("outcome"), EncodableValue(outcome)},
          {EncodableValue("durationMs"),
           EncodableValue(record.updated_at_ms - record.started_at_ms)},
      });
}

void DownloadsService::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap* arguments = AsMap(call.arguments());
  const EncodableMap empty;
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "setEnabled") {
    SetEnabled(GetBool(args, "enabled", false));
    result->Success(EncodableValue(running_.load()));
    return;
  }
  if (method == "folder") {
    result->Success(EncodableValue(Utf8FromUtf16(
        downloads_directory_.empty() ? KnownDownloadsFolder()
                                     : downloads_directory_)));
    return;
  }
  DB_LOG_WARN(kTag, "Unimplemented downloads method: " + method);
  result->NotImplemented();
}

}  // namespace dynamicbar
