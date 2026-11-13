import 'package:flutter/foundation.dart';

import 'events.dart';
import 'native_audio_backend.dart';
import 'types/audio_device.dart';
import 'types/audio_source.dart';
import 'types/record_config.dart';

/// Internal backend contract used by `AudioPlayer` and `AudioRecorder`.
///
/// Implemented by [NativeAudioBackend] on Android, iOS, macOS, Windows, and
/// Linux, and by `XueHuaAudioWebPlugin` on Web.
///
/// 由 `AudioPlayer` 与 `AudioRecorder` 使用的内部后端接口。
///
/// Android、iOS、macOS、Windows、Linux 由 [NativeAudioBackend] 实现；
/// Web 端由 `XueHuaAudioWebPlugin` 实现。
abstract interface class AudioBackend {
  /// Active backend instance. Defaults to [NativeAudioBackend]; Web replaces
  /// it during plugin registration.
  ///
  /// 当前激活的后端实例。默认为 [NativeAudioBackend]；Web 端会在插件注册时
  /// 替换它。
  static AudioBackend instance = NativeAudioBackend();

  /// Restores the default [NativeAudioBackend] instance in tests.
  /// 在测试中将 [instance] 恢复为默认的 [NativeAudioBackend]。
  @visibleForTesting
  static void resetInstance() {
    instance = NativeAudioBackend();
  }

  // ---------------------------------------------------------------------
  // Playback / 播放
  // ---------------------------------------------------------------------

  /// Creates a player instance and returns its id.
  /// 创建一个播放器实例并返回其 id。
  Future<int> createPlayer();

  /// Loads [source] into player [playerId] and returns the duration when known.
  /// 为播放器 [playerId] 加载音频源 [source]，已知时返回总时长。
  Future<Duration?> setSource(int playerId, AudioSource source);

  /// Starts or resumes playback of player [playerId].
  /// 开始或恢复播放器 [playerId] 的播放。
  Future<void> play(int playerId);

  /// Pauses player [playerId] keeping its position.
  /// 暂停播放器 [playerId] 并保留播放进度。
  Future<void> pause(int playerId);

  /// Stops player [playerId] and rewinds to the beginning.
  /// 停止播放器 [playerId] 并把进度重置到起点。
  Future<void> stopPlayer(int playerId);

  /// Seeks player [playerId] to [position].
  /// 将播放器 [playerId] 跳转到 [position]。
  Future<void> seekTo(int playerId, Duration position);

  /// Sets the volume of player [playerId] (`0.0`–`1.0`).
  /// 设置播放器 [playerId] 的音量（`0.0`～`1.0`）。
  Future<void> setVolume(int playerId, double volume);

  /// Sets the playback speed of player [playerId].
  /// 设置播放器 [playerId] 的播放速度。
  Future<void> setSpeed(int playerId, double speed);

  /// Enables or disables looping for player [playerId].
  /// 开启或关闭播放器 [playerId] 的循环播放。
  Future<void> setLooping(int playerId, bool looping);

  /// Returns the current playback position of player [playerId].
  /// 返回播放器 [playerId] 的当前播放位置。
  Future<Duration> getPosition(int playerId);

  /// Returns the total duration of player [playerId], or `null` when unknown.
  /// 返回播放器 [playerId] 的总时长；未知时返回 `null`。
  Future<Duration?> getDuration(int playerId);

  /// Lists the available audio output devices.
  /// 列出可用的音频输出设备。
  Future<List<AudioDevice>> listOutputDevices();

  /// Returns the output device player [playerId] is routed to, or `null` when
  /// following the system default.
  /// 返回播放器 [playerId] 当前路由到的输出设备；跟随系统默认时返回 `null`。
  Future<AudioDevice?> getOutputDevice(int playerId);

  /// Routes player [playerId] to [deviceId], or back to the system default
  /// when `null`.
  /// 将播放器 [playerId] 路由到 [deviceId]；传 `null` 恢复系统默认设备。
  Future<void> setOutputDevice(int playerId, String? deviceId);

  /// Releases all resources held by player [playerId].
  /// 释放播放器 [playerId] 持有的全部资源。
  Future<void> disposePlayer(int playerId);

  /// Broadcast stream of [PlayerEvent]s emitted by player [playerId].
  /// 播放器 [playerId] 推送的 [PlayerEvent] 广播流。
  Stream<PlayerEvent> playerEvents(int playerId);

  // ---------------------------------------------------------------------
  // Recording / 录音
  // ---------------------------------------------------------------------

  /// Creates a recorder instance and returns its id.
  /// 创建一个录音机实例并返回其 id。
  Future<int> createRecorder();

  /// Checks and requests microphone permission when supported.
  /// 检查（并在支持时请求）麦克风权限。
  Future<bool> hasRecordPermission();

  /// Lists the available audio input devices.
  /// 列出可用的音频输入设备。
  Future<List<AudioDevice>> listInputDevices();

  /// Returns the input device recorder [recorderId] captures from, or `null`
  /// when following the system default.
  /// 返回录音机 [recorderId] 当前使用的输入设备；跟随系统默认时返回 `null`。
  Future<AudioDevice?> getInputDevice(int recorderId);

  /// Selects input device [deviceId] for recorder [recorderId], or the system
  /// default when `null`.
  /// 为录音机 [recorderId] 选择输入设备 [deviceId]；传 `null` 使用系统默认。
  Future<void> setInputDevice(int recorderId, String? deviceId);

  /// Starts recorder [recorderId] writing to [path] using [config].
  /// 使用 [config] 启动录音机 [recorderId]，并写入 [path]。
  Future<void> startRecorder(
    int recorderId,
    RecordConfig config, {
    required String path,
  });

  /// Pauses recorder [recorderId]. / 暂停录音机 [recorderId]。
  Future<void> pauseRecorder(int recorderId);

  /// Resumes recorder [recorderId]. / 恢复录音机 [recorderId]。
  Future<void> resumeRecorder(int recorderId);

  /// Stops recorder [recorderId] and returns the output path (or blob URL).
  /// 停止录音机 [recorderId] 并返回输出路径（或 Web blob URL）。
  Future<String?> stopRecorder(int recorderId);

  /// Stops recorder [recorderId] and deletes the partial recording.
  /// 停止录音机 [recorderId] 并删除未完成的录音。
  Future<void> cancelRecorder(int recorderId);

  /// Releases all resources held by recorder [recorderId].
  /// 释放录音机 [recorderId] 持有的全部资源。
  Future<void> disposeRecorder(int recorderId);

  /// Broadcast stream of [RecorderEvent]s emitted by recorder [recorderId].
  /// 录音机 [recorderId] 推送的 [RecorderEvent] 广播流。
  Stream<RecorderEvent> recorderEvents(int recorderId);
}
