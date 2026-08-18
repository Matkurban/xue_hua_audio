// WASAPI-based microphone recording instance.
// 基于 WASAPI 的麦克风录音实例。
#ifndef XUE_HUA_AUDIO_WINDOWS_WINDOWS_RECORDER_H_
#define XUE_HUA_AUDIO_WINDOWS_WINDOWS_RECORDER_H_

#include <flutter/binary_messenger.h>

#include <atomic>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <thread>

#include "event_stream.h"
#include "main_thread_dispatcher.h"
#include "messages.g.h"

namespace xue_hua_audio_windows {

// One microphone recording instance. A background thread captures 16-bit
// PCM through WASAPI (shared mode with automatic format conversion),
// computes the peak amplitude (dBFS) and writes WAV directly or AAC-LC
// (`.m4a`) through a Media Foundation sink writer. Amplitude and state
// events are pushed to Dart through `xue_hua_audio/recorder_events_<id>`.
//
// 单个麦克风录音实例。后台线程通过 WASAPI（共享模式 + 自动格式转换）
// 采集 16 位 PCM，计算峰值振幅（dBFS），并直接写 WAV 或经 Media
// Foundation Sink Writer 写 AAC-LC（`.m4a`）。振幅与状态事件经
// `xue_hua_audio/recorder_events_<id>` 推送给 Dart。
class WindowsRecorder {
 public:
  // Creates the recorder and its event channel. / 创建录音机及其事件通道。
  WindowsRecorder(flutter::BinaryMessenger* messenger,
                  std::shared_ptr<MainThreadDispatcher> dispatcher,
                  int64_t id);
  ~WindowsRecorder();

  // Starts capturing with `config`, writing to `path`. Returns an error
  // message on failure, nullopt on success.
  // 按 `config` 开始采集并写入 `path`；失败返回错误信息，成功返回空。
  std::optional<std::string> Start(const RecordConfigMessage& config,
                                   const std::string& path);

  // Pauses capture (data is discarded while paused). / 暂停采集（期间丢弃数据）。
  void Pause();
  // Resumes capture. / 恢复采集。
  void Resume();
  // Stops recording and returns the file path, or nullopt when nothing was
  // recorded. / 停止录音并返回文件路径；未录音时返回空。
  std::optional<std::string> Stop();
  // Stops recording and deletes the file. / 停止录音并删除文件。
  void Cancel();

  // Selects the input device for the next Start (nullopt = system default).
  // Returns false when recording is in progress — Windows cannot switch the
  // capture device of a running WASAPI stream.
  //
  // 为下一次 Start 选择输入设备（nullopt 使用系统默认）。录音中返回
  // false——Windows 无法切换运行中 WASAPI 流的采集设备。
  bool SetInputDevice(const std::optional<std::string>& device_id);

  // Id of the preferred input device, nullopt = system default.
  // 偏好的输入设备 id；nullopt 表示系统默认。
  const std::optional<std::string>& InputDeviceId() const {
    return preferred_device_id_;
  }

 private:
  class FileWriter;
  class WavFileWriter;
  class AacFileWriter;

  void CaptureLoop(int64_t amplitude_interval_ms);
  void StopThread();
  void EmitState(const std::string& state);

  std::unique_ptr<EventStream> events_;
  std::shared_ptr<MainThreadDispatcher> dispatcher_;

  std::thread thread_;
  std::atomic<bool> running_{false};
  std::atomic<bool> paused_{false};

  // Set up on the platform thread in Start(), consumed by the capture
  // thread. / 在 Start()（平台线程）中配置，由采集线程使用。
  void* audio_client_ = nullptr;    // IAudioClient*
  void* capture_client_ = nullptr;  // IAudioCaptureClient*
  std::unique_ptr<FileWriter> writer_;
  int sample_rate_ = 44100;
  int channels_ = 1;

  std::string output_path_;
  std::optional<std::string> preferred_device_id_;
  double max_db_ = -160.0;
};

}  // namespace xue_hua_audio_windows

#endif  // XUE_HUA_AUDIO_WINDOWS_WINDOWS_RECORDER_H_
