import 'package:flutter/services.dart';

import 'events.dart';
import 'messages.g.dart';
import 'types/amplitude.dart';
import 'types/audio_device.dart';
import 'types/audio_error.dart';
import 'types/audio_source.dart';
import 'types/player_state.dart';
import 'types/record_config.dart';
import 'xue_hua_audio_platform.dart';

/// The default [XueHuaAudioPlatform] implementation backed by Pigeon
/// method channels and per-instance [EventChannel]s.
///
/// It is shared by every native platform (Android, iOS, macOS, Windows and
/// Linux); those packages only ship native code that answers the same
/// channels. Web replaces the platform instance with its own pure-Dart
/// implementation instead.
///
/// Event channel names / 事件通道命名:
///
/// * players / 播放器: `xue_hua_audio/player_events_<playerId>`
/// * recorders / 录音机: `xue_hua_audio/recorder_events_<recorderId>`
///
/// 基于 Pigeon 方法通道与按实例创建的 [EventChannel] 的默认
/// [XueHuaAudioPlatform] 实现。
///
/// 该实现被所有原生平台（Android、iOS、macOS、Windows、Linux）共用；
/// 各平台包只包含应答同一组通道的原生代码。Web 端则以纯 Dart 实现
/// 直接替换平台实例。
class MethodChannelXueHuaAudio extends XueHuaAudioPlatform {
  /// Creates the method-channel implementation, optionally injecting Pigeon
  /// API clients for testing.
  ///
  /// [playerApi] / [recorderApi]: test doubles for the generated Pigeon
  /// clients; production code uses the defaults.
  ///
  /// 创建 MethodChannel 实现；可为测试注入 Pigeon 客户端。
  ///
  /// [playerApi] / [recorderApi]：用于测试的 Pigeon 客户端替身；
  /// 生产环境使用默认实例。
  MethodChannelXueHuaAudio({
    AudioPlayerHostApi? playerApi,
    AudioRecorderHostApi? recorderApi,
  }) : _players = playerApi ?? AudioPlayerHostApi(),
       _recorders = recorderApi ?? AudioRecorderHostApi();

  final AudioPlayerHostApi _players;
  final AudioRecorderHostApi _recorders;

  /// Converts [source] to its Pigeon wire representation.
  /// 将 [source] 转换为 Pigeon 传输结构。
  static AudioSourceMessage _encodeSource(AudioSource source) {
    return switch (source) {
      FileSource(:final path) => AudioSourceMessage(
        type: SourceTypeMessage.file,
        uri: path,
      ),
      UrlSource(:final url, :final headers) => AudioSourceMessage(
        type: SourceTypeMessage.url,
        uri: url,
        headers: headers,
      ),
      AssetSource() => AudioSourceMessage(
        type: SourceTypeMessage.asset,
        uri: source.resolvedKey,
      ),
    };
  }

  /// Converts [config] to its Pigeon wire representation.
  /// 将 [config] 转换为 Pigeon 传输结构。
  static RecordConfigMessage _encodeConfig(RecordConfig config) {
    return RecordConfigMessage(
      encoder: switch (config.encoder) {
        AudioEncoder.wav => EncoderMessage.wav,
        AudioEncoder.aacLc => EncoderMessage.aacLc,
        AudioEncoder.opus => EncoderMessage.opus,
      },
      sampleRate: config.sampleRate,
      numChannels: config.numChannels,
      bitRate: config.bitRate,
      amplitudeIntervalMs: config.amplitudeInterval.inMilliseconds,
      deviceId: config.deviceId,
    );
  }

  /// Runs [action], translating [PlatformException]s thrown by Pigeon into
  /// structured [AudioError]s.
  /// 执行 [action]，并把 Pigeon 抛出的 [PlatformException] 翻译为结构化的
  /// [AudioError]。
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (e) {
      throw AudioError(
        code: e.code,
        message: e.message ?? 'Unknown platform error',
        details: e.details,
      );
    }
  }

  /// Decodes one raw event-channel payload into a [PlayerEvent].
  /// 将一条原始事件通道数据解码为 [PlayerEvent]。
  static PlayerEvent _decodePlayerEvent(dynamic raw) {
    final map = (raw as Map).cast<Object?, Object?>();
    return switch (map['type']) {
      'state' => PlayerStateEvent(
        PlayerState.values.byName(map['state']! as String),
      ),
      'completed' => const PlayerCompletedEvent(),
      'duration' => PlayerDurationEvent(
        map['durationMs'] == null
            ? null
            : Duration(milliseconds: (map['durationMs']! as num).toInt()),
      ),
      'error' => PlayerErrorEvent(
        AudioError(
          code: map['code'] as String? ?? AudioError.codePlaybackFailed,
          message: map['message'] as String? ?? 'Unknown playback error',
          details: map['details'],
        ),
      ),
      _ => throw StateError('Unknown player event: $map'),
    };
  }

  /// Decodes one raw event-channel payload into a [RecorderEvent].
  /// 将一条原始事件通道数据解码为 [RecorderEvent]。
  static RecorderEvent _decodeRecorderEvent(dynamic raw) {
    final map = (raw as Map).cast<Object?, Object?>();
    return switch (map['type']) {
      'state' => RecorderStateEvent(
        RecorderState.values.byName(map['state']! as String),
      ),
      'amplitude' => RecorderAmplitudeEvent(
        Amplitude(
          current: (map['current']! as num).toDouble(),
          max: (map['max']! as num).toDouble(),
        ),
      ),
      'error' => RecorderErrorEvent(
        AudioError(
          code: map['code'] as String? ?? AudioError.codeRecordingFailed,
          message: map['message'] as String? ?? 'Unknown recording error',
          details: map['details'],
        ),
      ),
      _ => throw StateError('Unknown recorder event: $map'),
    };
  }

  // -- Playback / 播放 ----------------------------------------------------

  @override
  Future<int> createPlayer() => _guard(_players.createPlayer);

  @override
  Future<Duration?> setSource(int playerId, AudioSource source) =>
      _guard(() async {
        final ms = await _players.setSource(playerId, _encodeSource(source));
        return ms == null ? null : Duration(milliseconds: ms);
      });

  @override
  Future<void> play(int playerId) => _guard(() => _players.play(playerId));

  @override
  Future<void> pause(int playerId) => _guard(() => _players.pause(playerId));

  @override
  Future<void> stopPlayer(int playerId) =>
      _guard(() => _players.stop(playerId));

  @override
  Future<void> seekTo(int playerId, Duration position) =>
      _guard(() => _players.seekTo(playerId, position.inMilliseconds));

  @override
  Future<void> setVolume(int playerId, double volume) =>
      _guard(() => _players.setVolume(playerId, volume.clamp(0.0, 1.0)));

  @override
  Future<void> setSpeed(int playerId, double speed) =>
      _guard(() => _players.setSpeed(playerId, speed));

  @override
  Future<void> setLooping(int playerId, bool looping) =>
      _guard(() => _players.setLooping(playerId, looping));

  @override
  Future<Duration> getPosition(int playerId) => _guard(
    () async => Duration(milliseconds: await _players.getPosition(playerId)),
  );

  @override
  Future<Duration?> getDuration(int playerId) => _guard(() async {
    final ms = await _players.getDuration(playerId);
    return ms == null ? null : Duration(milliseconds: ms);
  });

  @override
  Future<List<AudioDevice>> listOutputDevices() => _guard(() async {
    final devices = await _players.listOutputDevices();
    return [for (final d in devices) AudioDevice(id: d.id, label: d.label)];
  });

  @override
  Future<AudioDevice?> getOutputDevice(int playerId) => _guard(() async {
    final device = await _players.getOutputDevice(playerId);
    return device == null
        ? null
        : AudioDevice(id: device.id, label: device.label);
  });

  @override
  Future<void> setOutputDevice(int playerId, String? deviceId) =>
      _guard(() => _players.setOutputDevice(playerId, deviceId));

  @override
  Future<void> disposePlayer(int playerId) =>
      _guard(() => _players.disposePlayer(playerId));

  @override
  Stream<PlayerEvent> playerEvents(int playerId) {
    return EventChannel(
      'xue_hua_audio/player_events_$playerId',
    ).receiveBroadcastStream().map(_decodePlayerEvent);
  }

  // -- Recording / 录音 ----------------------------------------------------

  @override
  Future<int> createRecorder() => _guard(_recorders.createRecorder);

  @override
  Future<bool> hasRecordPermission() => _guard(_recorders.hasPermission);

  @override
  Future<List<AudioDevice>> listInputDevices() => _guard(() async {
    final devices = await _recorders.listInputDevices();
    return [for (final d in devices) AudioDevice(id: d.id, label: d.label)];
  });

  @override
  Future<AudioDevice?> getInputDevice(int recorderId) => _guard(() async {
    final device = await _recorders.getInputDevice(recorderId);
    return device == null
        ? null
        : AudioDevice(id: device.id, label: device.label);
  });

  @override
  Future<void> setInputDevice(int recorderId, String? deviceId) =>
      _guard(() => _recorders.setInputDevice(recorderId, deviceId));

  @override
  Future<void> startRecorder(
    int recorderId,
    RecordConfig config, {
    required String path,
  }) => _guard(() => _recorders.start(recorderId, _encodeConfig(config), path));

  @override
  Future<void> pauseRecorder(int recorderId) =>
      _guard(() => _recorders.pause(recorderId));

  @override
  Future<void> resumeRecorder(int recorderId) =>
      _guard(() => _recorders.resume(recorderId));

  @override
  Future<String?> stopRecorder(int recorderId) =>
      _guard(() => _recorders.stop(recorderId));

  @override
  Future<void> cancelRecorder(int recorderId) =>
      _guard(() => _recorders.cancel(recorderId));

  @override
  Future<void> disposeRecorder(int recorderId) =>
      _guard(() => _recorders.disposeRecorder(recorderId));

  @override
  Stream<RecorderEvent> recorderEvents(int recorderId) {
    return EventChannel(
      'xue_hua_audio/recorder_events_$recorderId',
    ).receiveBroadcastStream().map(_decodeRecorderEvent);
  }
}
