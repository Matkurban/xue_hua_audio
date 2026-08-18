// An EventChannel wrapper that buffers events until Dart subscribes.
// 在 Dart 订阅前缓冲事件的 EventChannel 封装。
#ifndef XUE_HUA_AUDIO_WINDOWS_EVENT_STREAM_H_
#define XUE_HUA_AUDIO_WINDOWS_EVENT_STREAM_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <deque>
#include <memory>
#include <string>

namespace xue_hua_audio_windows {

// Owns one event channel; events sent before the Dart listener attaches are
// queued and flushed on subscription. All methods must be called on the
// platform thread.
//
// 持有一条事件通道；Dart 端订阅前发送的事件会先入队，订阅后统一冲刷。
// 所有方法必须在平台线程上调用。
class EventStream {
 public:
  // Creates the stream on channel `name`. / 在名为 `name` 的通道上创建事件流。
  EventStream(flutter::BinaryMessenger* messenger, const std::string& name)
      : channel_(messenger, name,
                 &flutter::StandardMethodCodec::GetInstance()) {
    auto handler = std::make_unique<
        flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
        [this](const flutter::EncodableValue* arguments,
               std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                   events)
            -> std::unique_ptr<
                flutter::StreamHandlerError<flutter::EncodableValue>> {
          sink_ = std::move(events);
          while (!pending_.empty()) {
            sink_->Success(pending_.front());
            pending_.pop_front();
          }
          return nullptr;
        },
        [this](const flutter::EncodableValue* arguments)
            -> std::unique_ptr<
                flutter::StreamHandlerError<flutter::EncodableValue>> {
          sink_.reset();
          return nullptr;
        });
    channel_.SetStreamHandler(std::move(handler));
  }

  // Sends `event` to Dart, buffering when nobody listens yet.
  // 将 `event` 发送给 Dart；若尚无订阅者则先缓冲。
  void Send(const flutter::EncodableMap& event) {
    if (sink_) {
      sink_->Success(flutter::EncodableValue(event));
    } else if (pending_.size() < 128) {
      pending_.push_back(flutter::EncodableValue(event));
    }
  }

  // Convenience: sends a state event. / 便捷方法：发送状态事件。
  void SendState(const std::string& state) {
    Send(flutter::EncodableMap{
        {flutter::EncodableValue("type"), flutter::EncodableValue("state")},
        {flutter::EncodableValue("state"), flutter::EncodableValue(state)},
    });
  }

  // Convenience: sends an error event. / 便捷方法：发送错误事件。
  void SendError(const std::string& code, const std::string& message) {
    Send(flutter::EncodableMap{
        {flutter::EncodableValue("type"), flutter::EncodableValue("error")},
        {flutter::EncodableValue("code"), flutter::EncodableValue(code)},
        {flutter::EncodableValue("message"), flutter::EncodableValue(message)},
    });
  }

 private:
  flutter::EventChannel<flutter::EncodableValue> channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::deque<flutter::EncodableValue> pending_;
};

}  // namespace xue_hua_audio_windows

#endif  // XUE_HUA_AUDIO_WINDOWS_EVENT_STREAM_H_
