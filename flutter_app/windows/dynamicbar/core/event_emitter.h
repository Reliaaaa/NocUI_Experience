// DynamicBar - a reusable EventChannel sink holder.
//
// Every native service exposes a single stream of {type, payload} maps. This
// wrapper owns the channel, tracks the active sink and silently drops events
// while Dart is not listening, so services never have to care whether the UI is
// attached yet.
#ifndef DYNAMICBAR_CORE_EVENT_EMITTER_H_
#define DYNAMICBAR_CORE_EVENT_EMITTER_H_

#include <flutter/binary_messenger.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <utility>

#include "dynamicbar/core/encodable.h"

namespace dynamicbar {

class EventEmitter {
 public:
  EventEmitter(flutter::BinaryMessenger* messenger, const std::string& name) {
    channel_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
        messenger, name, &flutter::StandardMethodCodec::GetInstance());
    auto handler = std::make_unique<
        flutter::StreamHandlerFunctions<EncodableValue>>(
        [this](const EncodableValue*,
               std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
            -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
          sink_ = std::move(events);
          if (on_listen_) {
            on_listen_();
          }
          return nullptr;
        },
        [this](const EncodableValue*)
            -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
          sink_.reset();
          return nullptr;
        });
    channel_->SetStreamHandler(std::move(handler));
  }

  ~EventEmitter() {
    if (channel_ != nullptr) {
      channel_->SetStreamHandler(nullptr);
    }
  }

  EventEmitter(const EventEmitter&) = delete;
  EventEmitter& operator=(const EventEmitter&) = delete;

  bool has_listener() const { return sink_ != nullptr; }

  // Called on the platform thread the first time Dart subscribes; used to
  // replay current state so the UI never starts out blank.
  void SetOnListen(std::function<void()> on_listen) {
    on_listen_ = std::move(on_listen);
  }

  void Emit(const std::string& type, EncodableMap payload = EncodableMap()) {
    if (sink_ == nullptr) {
      return;
    }
    payload[EncodableValue("type")] = EncodableValue(type);
    sink_->Success(EncodableValue(std::move(payload)));
  }

 private:
  std::unique_ptr<flutter::EventChannel<EncodableValue>> channel_;
  std::unique_ptr<flutter::EventSink<EncodableValue>> sink_;
  std::function<void()> on_listen_;
};

}  // namespace dynamicbar

#endif  // DYNAMICBAR_CORE_EVENT_EMITTER_H_
