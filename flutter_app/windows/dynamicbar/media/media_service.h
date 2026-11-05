// DynamicBar - Windows media session integration.
//
// Uses GlobalSystemMediaTransportControlsSessionManager, the same API the
// Windows shell itself uses for the media flyout, through the WinRT ABI with
// WRL smart pointers. The C++/WinRT projection is not used because it requires
// exceptions, and the Flutter runner is compiled with _HAS_EXCEPTIONS=0; mixing
// the two would mean two different standard library configurations in one
// binary.
//
// Everything here is event driven. Nothing polls: track changes, playback state
// and timeline updates all arrive as WinRT events, and the playback position
// between events is interpolated in Dart from the session's own
// LastUpdatedTime. A media widget that redraws all day costs nothing while the
// music is paused.
#ifndef DYNAMICBAR_MEDIA_MEDIA_SERVICE_H_
#define DYNAMICBAR_MEDIA_MEDIA_SERVICE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <windows.h>
#include <windows.media.control.h>
#include <windows.storage.streams.h>
#include <wrl/client.h>

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "dynamicbar/core/event_emitter.h"

namespace dynamicbar {

/// Snapshot of the current session, as sent to Dart.
struct MediaSnapshot {
  bool has_session = false;
  std::string source_app_id;
  std::string title;
  std::string artist;
  std::string album;
  std::string status = "closed";
  bool can_play = false;
  bool can_pause = false;
  bool can_next = false;
  bool can_previous = false;
  int64_t position_ms = 0;
  int64_t duration_ms = 0;
  int64_t start_ms = 0;
  /// Milliseconds since the Unix epoch at which `position_ms` was measured.
  int64_t updated_at_ms = 0;
  /// Identity of the artwork currently published, so Dart can tell whether the
  /// image it holds is still the right one without the bytes being resent.
  int64_t artwork_id = 0;
};

class MediaService {
 public:
  MediaService(flutter::BinaryMessenger* messenger);
  ~MediaService();

  MediaService(const MediaService&) = delete;
  MediaService& operator=(const MediaService&) = delete;

  /// Connects to the session manager. Safe to call when no media application is
  /// running; the service simply reports that there is no session.
  void Start();
  void Stop();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  void OnManagerReady(
      Microsoft::WRL::ComPtr<
          ABI::Windows::Media::Control::
              IGlobalSystemMediaTransportControlsSessionManager> manager);
  void AttachToCurrentSession();
  void DetachSession();
  void RefreshAll();
  void RefreshPlaybackInfo();
  void RefreshTimeline();
  void RequestMediaProperties();
  void RequestThumbnail(
      Microsoft::WRL::ComPtr<
          ABI::Windows::Storage::Streams::IRandomAccessStreamReference>
          reference);
  void PublishSnapshot();
  void PublishArtwork(std::vector<uint8_t> bytes);

  /// Runs the callable on the platform thread if the service is still alive.
  void PostToPlatformThread(std::function<void()> action);

  Microsoft::WRL::ComPtr<
      ABI::Windows::Media::Control::
          IGlobalSystemMediaTransportControlsSessionManager>
      manager_;
  Microsoft::WRL::ComPtr<
      ABI::Windows::Media::Control::IGlobalSystemMediaTransportControlsSession>
      session_;

  EventRegistrationToken current_session_token_ = {};
  EventRegistrationToken sessions_changed_token_ = {};
  EventRegistrationToken media_properties_token_ = {};
  EventRegistrationToken playback_info_token_ = {};
  EventRegistrationToken timeline_token_ = {};

  MediaSnapshot snapshot_;
  std::vector<uint8_t> artwork_;
  int64_t next_artwork_id_ = 1;
  bool started_ = false;

  /// Guards against WinRT completion handlers firing after teardown.
  std::shared_ptr<std::atomic<bool>> alive_;

  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
  std::unique_ptr<EventEmitter> events_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_MEDIA_MEDIA_SERVICE_H_
