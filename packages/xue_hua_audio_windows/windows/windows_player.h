// IMFMediaEngine-based playback instance. / 基于 IMFMediaEngine 的播放实例。
#ifndef XUE_HUA_AUDIO_WINDOWS_WINDOWS_PLAYER_H_
#define XUE_HUA_AUDIO_WINDOWS_WINDOWS_PLAYER_H_

#include <flutter/binary_messenger.h>
#include <mfapi.h>
#include <mfmediaengine.h>
#include <wrl/client.h>
#include <wrl/implements.h>

#include <functional>
#include <memory>
#include <optional>
#include <string>

#include "event_stream.h"
#include "main_thread_dispatcher.h"

namespace xue_hua_audio_windows {

// One playback instance backed by Media Foundation's IMFMediaEngine (which
// handles decoding, buffering and audio output for local files and URLs).
// State/duration/error events are pushed to Dart through
// `xue_hua_audio/player_events_<id>`; the position is polled from Dart.
//
// 基于 Media Foundation IMFMediaEngine 的单个播放实例（解码、缓冲与音频
// 输出均由其完成，支持本地文件与 URL）。状态/时长/错误事件经
// `xue_hua_audio/player_events_<id>` 推送给 Dart；播放位置由 Dart 侧轮询。
class WindowsPlayer {
 public:
  using LoadCallback =
      std::function<void(std::optional<int64_t> duration_ms,
                         const std::optional<std::string>& error)>;

  // Creates the player and its event channel.
  // 创建播放器及其事件通道。
  WindowsPlayer(flutter::BinaryMessenger* messenger,
                std::shared_ptr<MainThreadDispatcher> dispatcher, int64_t id);
  ~WindowsPlayer();

  // Loads `url`; `callback` resolves with the duration (ms) once metadata
  // is known, or with an error message.
  // 加载 `url`；元数据可用后 `callback` 返回时长（毫秒）或错误信息。
  void SetSource(const std::string& url, LoadCallback callback);

  // Starts/resumes playback. / 开始或恢复播放。
  void Play();
  // Pauses playback. / 暂停播放。
  void Pause();
  // Stops playback and rewinds. / 停止播放并回到起点。
  void Stop();
  // Seeks to `position_ms`; `done` fires when the seek completes.
  // 跳转到 `position_ms`；seek 完成后触发 `done`。
  void SeekTo(int64_t position_ms, std::function<void()> done);
  // Sets volume 0.0–1.0. / 设置音量（0.0～1.0）。
  void SetVolume(double volume);
  // Sets playback speed. / 设置播放速度。
  void SetSpeed(double speed);
  // Enables/disables looping. / 开启或关闭循环。
  void SetLooping(bool looping);
  // Current position in ms. / 当前位置（毫秒）。
  int64_t Position();
  // Duration in ms, or nullopt when unknown. / 时长（毫秒），未知为空。
  std::optional<int64_t> Duration();

  // Result of SetOutputDevice. / SetOutputDevice 的执行结果。
  enum class RouteResult { kOk, kUnsupported, kFailed };

  // Routes audio to the endpoint `device_id` (nullopt = system default)
  // through IMFMediaEngineAudioEndpointId (Windows 10 1703+). Per Media
  // Foundation semantics the new endpoint is used from the next SetSource.
  //
  // 通过 IMFMediaEngineAudioEndpointId（Windows 10 1703+）将音频路由到
  // 端点 `device_id`（nullopt 恢复系统默认）。按 Media Foundation 语义，
  // 新端点自下一次 SetSource 起生效。
  RouteResult SetOutputDevice(const std::optional<std::string>& device_id);

  // Id of the selected output endpoint, nullopt = system default.
  // 已选择的输出端点 id；nullopt 表示系统默认。
  const std::optional<std::string>& OutputDeviceId() const {
    return output_device_id_;
  }

 private:
  // Receives media engine notifications (arbitrary thread) and forwards
  // them to the platform thread.
  // 接收媒体引擎通知（任意线程）并转发到平台线程。
  class Notify;

  void OnEngineEvent(DWORD event, DWORD_PTR param1, DWORD param2);
  void EmitState(const std::string& state);

  std::unique_ptr<EventStream> events_;
  std::shared_ptr<MainThreadDispatcher> dispatcher_;
  Microsoft::WRL::ComPtr<IMFMediaEngine> engine_;
  Microsoft::WRL::ComPtr<Notify> notify_;

  LoadCallback pending_load_;
  std::function<void()> pending_seek_;
  std::optional<std::string> output_device_id_;
  double speed_ = 1.0;
  bool started_once_ = false;
  bool stopped_by_user_ = false;
  std::string last_state_;
};

}  // namespace xue_hua_audio_windows

#endif  // XUE_HUA_AUDIO_WINDOWS_WINDOWS_PLAYER_H_
