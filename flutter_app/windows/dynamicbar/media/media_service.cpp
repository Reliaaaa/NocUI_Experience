#include "dynamicbar/media/media_service.h"

#include <flutter/standard_method_codec.h>
#include <windows.foundation.h>
#include <wrl/event.h>
#include <wrl/implements.h>
#include <wrl/wrappers/corewrappers.h>

#include "dynamicbar/core/dispatcher.h"
#include "dynamicbar/core/logging.h"

namespace WF = ABI::Windows::Foundation;
namespace WMC = ABI::Windows::Media::Control;
namespace WSS = ABI::Windows::Storage::Streams;

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::FtmBase;
using Microsoft::WRL::Implements;
using Microsoft::WRL::RuntimeClassFlags;
using Microsoft::WRL::Wrappers::HString;
using Microsoft::WRL::Wrappers::HStringReference;

namespace dynamicbar {
namespace {

constexpr const char kTag[] = "Media";
constexpr const char kMethodChannelName[] = "dynamicbar/media";
constexpr const char kEventChannelName[] = "dynamicbar/media/events";

/// Largest artwork we are willing to move across the channel. Album art is
/// displayed at well under 100px; anything bigger is a decode cost for nothing.
constexpr UINT64 kMaxArtworkBytes = 4 * 1024 * 1024;

using SessionManager = WMC::GlobalSystemMediaTransportControlsSessionManager;
using ISessionManager =
    WMC::IGlobalSystemMediaTransportControlsSessionManager;
using Session = WMC::GlobalSystemMediaTransportControlsSession;
using ISession = WMC::IGlobalSystemMediaTransportControlsSession;
using IMediaProperties =
    WMC::IGlobalSystemMediaTransportControlsSessionMediaProperties;
using IPlaybackInfo =
    WMC::IGlobalSystemMediaTransportControlsSessionPlaybackInfo;
using IPlaybackControls =
    WMC::IGlobalSystemMediaTransportControlsSessionPlaybackControls;
using ITimelineProperties =
    WMC::IGlobalSystemMediaTransportControlsSessionTimelineProperties;
using PlaybackStatus =
    WMC::GlobalSystemMediaTransportControlsSessionPlaybackStatus;

/// Free-threaded handler, so completions are delivered directly instead of
/// being marshalled back through an apartment that may be busy.
template <typename THandler>
struct AgileHandler {
  using type = Implements<RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
                          THandler, FtmBase>;
};

std::string ToUtf8(HSTRING value) {
  if (value == nullptr) {
    return std::string();
  }
  UINT32 length = 0;
  const wchar_t* buffer = ::WindowsGetStringRawBuffer(value, &length);
  if (buffer == nullptr || length == 0) {
    return std::string();
  }
  return Utf8FromUtf16(std::wstring(buffer, length));
}

std::string StatusName(PlaybackStatus status) {
  switch (status) {
    case WMC::GlobalSystemMediaTransportControlsSessionPlaybackStatus_Closed:
      return "closed";
    case WMC::GlobalSystemMediaTransportControlsSessionPlaybackStatus_Opened:
      return "opened";
    case WMC::GlobalSystemMediaTransportControlsSessionPlaybackStatus_Changing:
      return "changing";
    case WMC::GlobalSystemMediaTransportControlsSessionPlaybackStatus_Stopped:
      return "stopped";
    case WMC::GlobalSystemMediaTransportControlsSessionPlaybackStatus_Playing:
      return "playing";
    case WMC::GlobalSystemMediaTransportControlsSessionPlaybackStatus_Paused:
      return "paused";
  }
  return "unknown";
}

int64_t TicksToMilliseconds(int64_t ticks) {
  return ticks / 10000;
}

/// Converts a WinRT DateTime (100ns ticks since 1601-01-01) to Unix epoch
/// milliseconds, which is what Dart's DateTime understands.
int64_t DateTimeToUnixMillis(const WF::DateTime& value) {
  constexpr int64_t kTicksFrom1601To1970 = 116444736000000000LL;
  return (value.UniversalTime - kTicksFrom1601To1970) / 10000;
}

}  // namespace

MediaService::MediaService(flutter::BinaryMessenger* messenger)
    : alive_(std::make_shared<std::atomic<bool>>(true)) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });

  events_ = std::make_unique<EventEmitter>(messenger, kEventChannelName);
  // Replay the current state as soon as Dart subscribes, so the UI is correct
  // on the first frame rather than after the next track change.
  events_->SetOnListen([this]() {
    PublishSnapshot();
    if (!artwork_.empty()) {
      PublishArtwork(artwork_);
    }
  });
}

MediaService::~MediaService() {
  Stop();
  if (alive_) {
    alive_->store(false);
  }
  if (channel_ != nullptr) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void MediaService::PostToPlatformThread(std::function<void()> action) {
  std::shared_ptr<std::atomic<bool>> alive = alive_;
  MainThreadDispatcher::Instance().Post([alive, action]() {
    if (alive != nullptr && alive->load()) {
      action();
    }
  });
}

void MediaService::Start() {
  if (started_) {
    return;
  }
  started_ = true;

  ComPtr<WMC::IGlobalSystemMediaTransportControlsSessionManagerStatics> statics;
  HRESULT hr = ::RoGetActivationFactory(
      HStringReference(
          RuntimeClass_Windows_Media_Control_GlobalSystemMediaTransportControlsSessionManager)
          .Get(),
      IID_PPV_ARGS(&statics));
  if (FAILED(hr) || statics == nullptr) {
    DB_LOG_WARN(kTag, "Media session API unavailable: " + FormatHResult(hr));
    PublishSnapshot();
    return;
  }

  ComPtr<WF::IAsyncOperation<SessionManager*>> operation;
  hr = statics->RequestAsync(&operation);
  if (FAILED(hr) || operation == nullptr) {
    DB_LOG_WARN(kTag, "RequestAsync failed: " + FormatHResult(hr));
    PublishSnapshot();
    return;
  }

  std::shared_ptr<std::atomic<bool>> alive = alive_;
  auto handler = Callback<typename AgileHandler<
      WF::IAsyncOperationCompletedHandler<SessionManager*>>::type>(
      [this, alive](WF::IAsyncOperation<SessionManager*>* async,
                    AsyncStatus status) -> HRESULT {
        if (status != AsyncStatus::Completed) {
          return S_OK;
        }
        ComPtr<ISessionManager> manager;
        if (FAILED(async->GetResults(&manager)) || manager == nullptr) {
          return S_OK;
        }
        MainThreadDispatcher::Instance().Post([this, alive, manager]() {
          if (alive != nullptr && alive->load()) {
            OnManagerReady(manager);
          }
        });
        return S_OK;
      });

  hr = operation->put_Completed(handler.Get());
  if (FAILED(hr)) {
    DB_LOG_WARN(kTag, "put_Completed failed: " + FormatHResult(hr));
  }
}

void MediaService::OnManagerReady(ComPtr<ISessionManager> manager) {
  manager_ = manager;
  DB_LOG_INFO(kTag, "Connected to the Windows media session manager.");

  std::shared_ptr<std::atomic<bool>> alive = alive_;
  auto on_session_changed = Callback<typename AgileHandler<
      WF::ITypedEventHandler<SessionManager*,
                             WMC::CurrentSessionChangedEventArgs*>>::type>(
      [this, alive](ISessionManager*,
                    WMC::ICurrentSessionChangedEventArgs*) -> HRESULT {
        MainThreadDispatcher::Instance().Post([this, alive]() {
          if (alive != nullptr && alive->load()) {
            AttachToCurrentSession();
          }
        });
        return S_OK;
      });
  manager_->add_CurrentSessionChanged(on_session_changed.Get(),
                                      &current_session_token_);

  auto on_sessions_changed = Callback<typename AgileHandler<
      WF::ITypedEventHandler<SessionManager*,
                             WMC::SessionsChangedEventArgs*>>::type>(
      [this, alive](ISessionManager*,
                    WMC::ISessionsChangedEventArgs*) -> HRESULT {
        MainThreadDispatcher::Instance().Post([this, alive]() {
          if (alive != nullptr && alive->load()) {
            AttachToCurrentSession();
          }
        });
        return S_OK;
      });
  manager_->add_SessionsChanged(on_sessions_changed.Get(),
                                &sessions_changed_token_);

  AttachToCurrentSession();
}

void MediaService::DetachSession() {
  if (session_ != nullptr) {
    if (media_properties_token_.value != 0) {
      session_->remove_MediaPropertiesChanged(media_properties_token_);
      media_properties_token_ = {};
    }
    if (playback_info_token_.value != 0) {
      session_->remove_PlaybackInfoChanged(playback_info_token_);
      playback_info_token_ = {};
    }
    if (timeline_token_.value != 0) {
      session_->remove_TimelinePropertiesChanged(timeline_token_);
      timeline_token_ = {};
    }
  }
  session_.Reset();
}

void MediaService::AttachToCurrentSession() {
  DetachSession();

  if (manager_ == nullptr) {
    snapshot_ = MediaSnapshot();
    PublishSnapshot();
    return;
  }

  ComPtr<ISession> session;
  HRESULT hr = manager_->GetCurrentSession(&session);
  if (FAILED(hr) || session == nullptr) {
    DB_LOG_DEBUG(kTag, "No active media session.");
    snapshot_ = MediaSnapshot();
    artwork_.clear();
    PublishSnapshot();
    return;
  }

  session_ = session;
  snapshot_ = MediaSnapshot();
  snapshot_.has_session = true;

  HString source_id;
  if (SUCCEEDED(session_->get_SourceAppUserModelId(source_id.GetAddressOf()))) {
    snapshot_.source_app_id = ToUtf8(source_id.Get());
  }

  std::shared_ptr<std::atomic<bool>> alive = alive_;

  auto on_media_properties = Callback<typename AgileHandler<
      WF::ITypedEventHandler<Session*,
                             WMC::MediaPropertiesChangedEventArgs*>>::type>(
      [this, alive](ISession*,
                    WMC::IMediaPropertiesChangedEventArgs*) -> HRESULT {
        MainThreadDispatcher::Instance().Post([this, alive]() {
          if (alive != nullptr && alive->load()) {
            RequestMediaProperties();
          }
        });
        return S_OK;
      });
  session_->add_MediaPropertiesChanged(on_media_properties.Get(),
                                       &media_properties_token_);

  auto on_playback_info = Callback<typename AgileHandler<
      WF::ITypedEventHandler<Session*,
                             WMC::PlaybackInfoChangedEventArgs*>>::type>(
      [this, alive](ISession*,
                    WMC::IPlaybackInfoChangedEventArgs*) -> HRESULT {
        MainThreadDispatcher::Instance().Post([this, alive]() {
          if (alive != nullptr && alive->load()) {
            RefreshPlaybackInfo();
            RefreshTimeline();
            PublishSnapshot();
          }
        });
        return S_OK;
      });
  session_->add_PlaybackInfoChanged(on_playback_info.Get(),
                                    &playback_info_token_);

  auto on_timeline = Callback<typename AgileHandler<
      WF::ITypedEventHandler<Session*,
                             WMC::TimelinePropertiesChangedEventArgs*>>::type>(
      [this, alive](ISession*,
                    WMC::ITimelinePropertiesChangedEventArgs*) -> HRESULT {
        MainThreadDispatcher::Instance().Post([this, alive]() {
          if (alive != nullptr && alive->load()) {
            RefreshTimeline();
            PublishSnapshot();
          }
        });
        return S_OK;
      });
  session_->add_TimelinePropertiesChanged(on_timeline.Get(), &timeline_token_);

  RefreshAll();
}

void MediaService::RefreshAll() {
  RefreshPlaybackInfo();
  RefreshTimeline();
  PublishSnapshot();
  RequestMediaProperties();
}

void MediaService::RefreshPlaybackInfo() {
  if (session_ == nullptr) {
    return;
  }
  ComPtr<IPlaybackInfo> info;
  if (FAILED(session_->GetPlaybackInfo(&info)) || info == nullptr) {
    return;
  }
  PlaybackStatus status = {};
  if (SUCCEEDED(info->get_PlaybackStatus(&status))) {
    snapshot_.status = StatusName(status);
  }
  ComPtr<IPlaybackControls> controls;
  if (SUCCEEDED(info->get_Controls(&controls)) && controls != nullptr) {
    boolean value = false;
    if (SUCCEEDED(controls->get_IsPlayEnabled(&value))) {
      snapshot_.can_play = value != 0;
    }
    if (SUCCEEDED(controls->get_IsPauseEnabled(&value))) {
      snapshot_.can_pause = value != 0;
    }
    if (SUCCEEDED(controls->get_IsNextEnabled(&value))) {
      snapshot_.can_next = value != 0;
    }
    if (SUCCEEDED(controls->get_IsPreviousEnabled(&value))) {
      snapshot_.can_previous = value != 0;
    }
  }
}

void MediaService::RefreshTimeline() {
  if (session_ == nullptr) {
    return;
  }
  ComPtr<ITimelineProperties> timeline;
  if (FAILED(session_->GetTimelineProperties(&timeline)) ||
      timeline == nullptr) {
    return;
  }
  WF::TimeSpan position = {};
  WF::TimeSpan start = {};
  WF::TimeSpan end = {};
  WF::DateTime updated = {};
  timeline->get_Position(&position);
  timeline->get_StartTime(&start);
  timeline->get_EndTime(&end);
  timeline->get_LastUpdatedTime(&updated);

  snapshot_.position_ms = TicksToMilliseconds(position.Duration);
  snapshot_.start_ms = TicksToMilliseconds(start.Duration);
  snapshot_.duration_ms =
      TicksToMilliseconds(end.Duration) - snapshot_.start_ms;
  snapshot_.updated_at_ms = DateTimeToUnixMillis(updated);
}

void MediaService::RequestMediaProperties() {
  if (session_ == nullptr) {
    return;
  }
  ComPtr<WF::IAsyncOperation<WMC::GlobalSystemMediaTransportControlsSessionMediaProperties*>>
      operation;
  if (FAILED(session_->TryGetMediaPropertiesAsync(&operation)) ||
      operation == nullptr) {
    return;
  }

  std::shared_ptr<std::atomic<bool>> alive = alive_;
  auto handler = Callback<typename AgileHandler<
      WF::IAsyncOperationCompletedHandler<
          WMC::GlobalSystemMediaTransportControlsSessionMediaProperties*>>::type>(
      [this, alive](
          WF::IAsyncOperation<
              WMC::GlobalSystemMediaTransportControlsSessionMediaProperties*>*
              async,
          AsyncStatus status) -> HRESULT {
        if (status != AsyncStatus::Completed) {
          return S_OK;
        }
        ComPtr<IMediaProperties> properties;
        if (FAILED(async->GetResults(&properties)) || properties == nullptr) {
          return S_OK;
        }

        HString title;
        HString artist;
        HString album;
        properties->get_Title(title.GetAddressOf());
        properties->get_Artist(artist.GetAddressOf());
        properties->get_AlbumTitle(album.GetAddressOf());
        std::string title_utf8 = ToUtf8(title.Get());
        std::string artist_utf8 = ToUtf8(artist.Get());
        std::string album_utf8 = ToUtf8(album.Get());

        ComPtr<WSS::IRandomAccessStreamReference> thumbnail;
        properties->get_Thumbnail(&thumbnail);

        MainThreadDispatcher::Instance().Post(
            [this, alive, title_utf8, artist_utf8, album_utf8, thumbnail]() {
              if (alive == nullptr || !alive->load()) {
                return;
              }
              snapshot_.title = title_utf8;
              snapshot_.artist = artist_utf8;
              snapshot_.album = album_utf8;
              PublishSnapshot();
              if (thumbnail != nullptr) {
                RequestThumbnail(thumbnail);
              } else if (!artwork_.empty()) {
                artwork_.clear();
                PublishArtwork(artwork_);
              }
            });
        return S_OK;
      });
  operation->put_Completed(handler.Get());
}

void MediaService::RequestThumbnail(
    ComPtr<WSS::IRandomAccessStreamReference> reference) {
  if (reference == nullptr) {
    return;
  }
  ComPtr<WF::IAsyncOperation<WSS::IRandomAccessStreamWithContentType*>>
      open_operation;
  if (FAILED(reference->OpenReadAsync(&open_operation)) ||
      open_operation == nullptr) {
    return;
  }

  std::shared_ptr<std::atomic<bool>> alive = alive_;
  auto on_open = Callback<typename AgileHandler<
      WF::IAsyncOperationCompletedHandler<
          WSS::IRandomAccessStreamWithContentType*>>::type>(
      [this, alive](
          WF::IAsyncOperation<WSS::IRandomAccessStreamWithContentType*>* async,
          AsyncStatus status) -> HRESULT {
        if (status != AsyncStatus::Completed) {
          return S_OK;
        }
        ComPtr<WSS::IRandomAccessStreamWithContentType> stream;
        if (FAILED(async->GetResults(&stream)) || stream == nullptr) {
          return S_OK;
        }
        UINT64 size = 0;
        ComPtr<WSS::IRandomAccessStream> random_access;
        if (FAILED(stream.As(&random_access)) || random_access == nullptr) {
          return S_OK;
        }
        random_access->get_Size(&size);
        if (size == 0 || size > kMaxArtworkBytes) {
          return S_OK;
        }

        ComPtr<WSS::IDataReaderFactory> reader_factory;
        if (FAILED(::RoGetActivationFactory(
                HStringReference(RuntimeClass_Windows_Storage_Streams_DataReader)
                    .Get(),
                IID_PPV_ARGS(&reader_factory)))) {
          return S_OK;
        }
        ComPtr<WSS::IInputStream> input;
        if (FAILED(stream.As(&input))) {
          return S_OK;
        }
        ComPtr<WSS::IDataReader> reader;
        if (FAILED(reader_factory->CreateDataReader(input.Get(), &reader)) ||
            reader == nullptr) {
          return S_OK;
        }

        ComPtr<WF::IAsyncOperation<UINT32>> load_operation;
        if (FAILED(reader->LoadAsync(static_cast<UINT32>(size), &load_operation)) ||
            load_operation == nullptr) {
          return S_OK;
        }

        auto on_loaded = Callback<typename AgileHandler<
            WF::IAsyncOperationCompletedHandler<UINT32>>::type>(
            [this, alive, reader, size](WF::IAsyncOperation<UINT32>* load,
                                        AsyncStatus load_status) -> HRESULT {
              if (load_status != AsyncStatus::Completed) {
                return S_OK;
              }
              UINT32 loaded = 0;
              if (FAILED(load->GetResults(&loaded)) || loaded == 0) {
                return S_OK;
              }
              std::vector<uint8_t> bytes(loaded);
              if (FAILED(reader->ReadBytes(loaded, bytes.data()))) {
                return S_OK;
              }
              MainThreadDispatcher::Instance().Post([this, alive, bytes]() {
                if (alive != nullptr && alive->load()) {
                  PublishArtwork(bytes);
                }
              });
              return S_OK;
            });
        load_operation->put_Completed(on_loaded.Get());
        return S_OK;
      });
  open_operation->put_Completed(on_open.Get());
}

void MediaService::PublishArtwork(std::vector<uint8_t> bytes) {
  const bool changed = bytes != artwork_;
  artwork_ = std::move(bytes);
  if (changed) {
    snapshot_.artwork_id = artwork_.empty() ? 0 : next_artwork_id_++;
  }
  events_->Emit(
      "artwork",
      EncodableMap{
          {EncodableValue("artworkId"),
           EncodableValue(snapshot_.artwork_id)},
          {EncodableValue("bytes"), EncodableValue(artwork_)},
      });
  if (changed) {
    PublishSnapshot();
  }
}

void MediaService::PublishSnapshot() {
  events_->Emit(
      "session",
      EncodableMap{
          {EncodableValue("hasSession"),
           EncodableValue(snapshot_.has_session)},
          {EncodableValue("sourceAppId"),
           EncodableValue(snapshot_.source_app_id)},
          {EncodableValue("title"), EncodableValue(snapshot_.title)},
          {EncodableValue("artist"), EncodableValue(snapshot_.artist)},
          {EncodableValue("album"), EncodableValue(snapshot_.album)},
          {EncodableValue("status"), EncodableValue(snapshot_.status)},
          {EncodableValue("canPlay"), EncodableValue(snapshot_.can_play)},
          {EncodableValue("canPause"), EncodableValue(snapshot_.can_pause)},
          {EncodableValue("canNext"), EncodableValue(snapshot_.can_next)},
          {EncodableValue("canPrevious"),
           EncodableValue(snapshot_.can_previous)},
          {EncodableValue("positionMs"),
           EncodableValue(snapshot_.position_ms)},
          {EncodableValue("durationMs"),
           EncodableValue(snapshot_.duration_ms)},
          {EncodableValue("startMs"), EncodableValue(snapshot_.start_ms)},
          {EncodableValue("updatedAtMs"),
           EncodableValue(snapshot_.updated_at_ms)},
          {EncodableValue("artworkId"), EncodableValue(snapshot_.artwork_id)},
      });
}

void MediaService::Stop() {
  DetachSession();
  if (manager_ != nullptr) {
    if (current_session_token_.value != 0) {
      manager_->remove_CurrentSessionChanged(current_session_token_);
      current_session_token_ = {};
    }
    if (sessions_changed_token_.value != 0) {
      manager_->remove_SessionsChanged(sessions_changed_token_);
      sessions_changed_token_ = {};
    }
  }
  manager_.Reset();
  started_ = false;
}

void MediaService::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "start") {
    Start();
    result->Success();
    return;
  }
  if (method == "refresh") {
    AttachToCurrentSession();
    result->Success();
    return;
  }

  if (session_ == nullptr) {
    result->Success(EncodableValue(false));
    return;
  }

  ComPtr<WF::IAsyncOperation<bool>> operation;
  HRESULT hr = E_NOTIMPL;
  if (method == "play") {
    hr = session_->TryPlayAsync(&operation);
  } else if (method == "pause") {
    hr = session_->TryPauseAsync(&operation);
  } else if (method == "playPause") {
    hr = session_->TryTogglePlayPauseAsync(&operation);
  } else if (method == "next") {
    hr = session_->TrySkipNextAsync(&operation);
  } else if (method == "previous") {
    hr = session_->TrySkipPreviousAsync(&operation);
  } else if (method == "seek") {
    const EncodableMap* arguments = AsMap(call.arguments());
    const int64_t position_ms =
        arguments != nullptr
            ? static_cast<int64_t>(GetDouble(*arguments, "positionMs"))
            : 0;
    hr = session_->TryChangePlaybackPositionAsync(position_ms * 10000,
                                                 &operation);
  } else {
    DB_LOG_WARN(kTag, "Unimplemented media method: " + method);
    result->NotImplemented();
    return;
  }

  if (FAILED(hr)) {
    DB_LOG_WARN(kTag, method + " failed: " + FormatHResult(hr));
    result->Success(EncodableValue(false));
    return;
  }
  result->Success(EncodableValue(true));
}

}  // namespace dynamicbar
