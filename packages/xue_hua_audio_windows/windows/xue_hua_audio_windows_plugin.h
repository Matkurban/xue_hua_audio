// Windows implementation of the xue_hua_audio plugin.
// xue_hua_audio 插件的 Windows 实现。
#ifndef FLUTTER_PLUGIN_XUE_HUA_AUDIO_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_AUDIO_WINDOWS_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <map>
#include <memory>
#include <optional>
#include <string>

#include "main_thread_dispatcher.h"
#include "messages.g.h"
#include "windows_player.h"
#include "windows_recorder.h"

namespace xue_hua_audio_windows {

class PlayerApi;
class RecorderApi;

// Entry point of the Windows implementation: owns the player/recorder
// registries and the two Pigeon host API implementations (kept as separate
// classes because `AudioPlayerHostApi::Pause(int64_t)` and
// `AudioRecorderHostApi::Pause(int64_t)` share one C++ signature).
//
// Windows 实现入口：持有播放器/录音机注册表以及两个 Pigeon Host API 实现
// （二者必须是独立的类，因为 `AudioPlayerHostApi::Pause(int64_t)` 与
// `AudioRecorderHostApi::Pause(int64_t)` 的 C++ 签名相同）。
class XueHuaAudioWindowsPlugin : public flutter::Plugin {
 public:
  // Registers the plugin with the Windows registrar. / 向 Windows 注册器注册插件。
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit XueHuaAudioWindowsPlugin(flutter::PluginRegistrarWindows* registrar);
  virtual ~XueHuaAudioWindowsPlugin();

  // Disallow copy and assign. / 禁止拷贝与赋值。
  XueHuaAudioWindowsPlugin(const XueHuaAudioWindowsPlugin&) = delete;
  XueHuaAudioWindowsPlugin& operator=(const XueHuaAudioWindowsPlugin&) = delete;

 private:
  friend class PlayerApi;
  friend class RecorderApi;

  flutter::PluginRegistrarWindows* registrar_;
  std::shared_ptr<MainThreadDispatcher> dispatcher_;
  std::unique_ptr<PlayerApi> player_api_;
  std::unique_ptr<RecorderApi> recorder_api_;

  std::map<int64_t, std::unique_ptr<WindowsPlayer>> players_;
  std::map<int64_t, std::unique_ptr<WindowsRecorder>> recorders_;
  int64_t next_player_id_ = 1;
  int64_t next_recorder_id_ = 1;
};

// Playback host API backed by WindowsPlayer (IMFMediaEngine).
// 基于 WindowsPlayer（IMFMediaEngine）的播放 Host API 实现。
class PlayerApi : public AudioPlayerHostApi {
 public:
  explicit PlayerApi(XueHuaAudioWindowsPlugin* plugin) : plugin_(plugin) {}

  ErrorOr<int64_t> CreatePlayer() override;
  void SetSource(int64_t player_id, const AudioSourceMessage& source,
                 std::function<void(ErrorOr<std::optional<int64_t>> reply)>
                     result) override;
  std::optional<FlutterError> Play(int64_t player_id) override;
  std::optional<FlutterError> Pause(int64_t player_id) override;
  std::optional<FlutterError> Stop(int64_t player_id) override;
  void SeekTo(int64_t player_id, int64_t position_ms,
              std::function<void(std::optional<FlutterError> reply)> result)
      override;
  std::optional<FlutterError> SetVolume(int64_t player_id,
                                        double volume) override;
  std::optional<FlutterError> SetSpeed(int64_t player_id,
                                       double speed) override;
  std::optional<FlutterError> SetLooping(int64_t player_id,
                                         bool looping) override;
  ErrorOr<int64_t> GetPosition(int64_t player_id) override;
  ErrorOr<std::optional<int64_t>> GetDuration(int64_t player_id) override;
  void ListOutputDevices(
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result)
      override;
  void GetOutputDevice(
      int64_t player_id,
      std::function<void(ErrorOr<std::optional<AudioDeviceMessage>> reply)>
          result) override;
  void SetOutputDevice(int64_t player_id, const std::string* device_id,
                       std::function<void(std::optional<FlutterError> reply)>
                           result) override;
  std::optional<FlutterError> DisposePlayer(int64_t player_id) override;

 private:
  WindowsPlayer* PlayerOf(int64_t id);
  XueHuaAudioWindowsPlugin* plugin_;
};

// Recording host API backed by WindowsRecorder (WASAPI).
// 基于 WindowsRecorder（WASAPI）的录音 Host API 实现。
class RecorderApi : public AudioRecorderHostApi {
 public:
  explicit RecorderApi(XueHuaAudioWindowsPlugin* plugin) : plugin_(plugin) {}

  ErrorOr<int64_t> CreateRecorder() override;
  void HasPermission(
      std::function<void(ErrorOr<bool> reply)> result) override;
  void ListInputDevices(
      std::function<void(ErrorOr<flutter::EncodableList> reply)> result)
      override;
  void GetInputDevice(
      int64_t recorder_id,
      std::function<void(ErrorOr<std::optional<AudioDeviceMessage>> reply)>
          result) override;
  void SetInputDevice(int64_t recorder_id, const std::string* device_id,
                      std::function<void(std::optional<FlutterError> reply)>
                          result) override;
  void Start(int64_t recorder_id, const RecordConfigMessage& config,
             const std::string& path,
             std::function<void(std::optional<FlutterError> reply)> result)
      override;
  std::optional<FlutterError> Pause(int64_t recorder_id) override;
  std::optional<FlutterError> Resume(int64_t recorder_id) override;
  void Stop(int64_t recorder_id,
            std::function<void(ErrorOr<std::optional<std::string>> reply)>
                result) override;
  void Cancel(int64_t recorder_id,
              std::function<void(std::optional<FlutterError> reply)> result)
      override;
  std::optional<FlutterError> DisposeRecorder(int64_t recorder_id) override;

 private:
  WindowsRecorder* RecorderOf(int64_t id);
  XueHuaAudioWindowsPlugin* plugin_;
};

}  // namespace xue_hua_audio_windows

#endif  // FLUTTER_PLUGIN_XUE_HUA_AUDIO_WINDOWS_PLUGIN_H_
