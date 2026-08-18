/// Web implementation of the `xue_hua_audio` plugin.
///
/// Playback uses `HTMLAudioElement`, recording uses `getUserMedia` +
/// `MediaRecorder`, and real-time amplitude comes from a Web Audio API
/// `AnalyserNode`.
///
/// `xue_hua_audio` 插件的 Web 实现。
///
/// 播放基于 `HTMLAudioElement`；录音基于 `getUserMedia` +
/// `MediaRecorder`；实时振幅由 Web Audio API 的 `AnalyserNode` 提供。
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

import 'src/web_player.dart';
import 'src/web_recorder.dart';

/// The Web [XueHuaAudioPlatform] implementation, registered automatically
/// by the Flutter Web plugin registrant.
///
/// 由 Flutter Web 插件注册器自动注册的 Web 端 [XueHuaAudioPlatform] 实现。
class XueHuaAudioWebPlugin extends XueHuaAudioPlatform {
  /// Registers this implementation as the active platform instance.
  /// Called by the generated plugin registrant — not by user code.
  ///
  /// 将本实现注册为当前平台实例。由生成的插件注册器调用，无需用户手动调用。
  ///
  /// [registrar]: the Flutter Web plugin registrar. / Flutter Web 插件注册器。
  static void registerWith(Registrar registrar) {
    XueHuaAudioPlatform.instance = XueHuaAudioWebPlugin();
  }

  final Map<int, WebPlayer> _players = {};
  final Map<int, WebRecorder> _recorders = {};
  int _nextPlayerId = 1;
  int _nextRecorderId = 1;

  WebPlayer _playerOf(int id) {
    final player = _players[id];
    if (player == null) {
      throw AudioError(
        code: AudioError.codeInstanceNotFound,
        message: 'No player with id $id',
      );
    }
    return player;
  }

  WebRecorder _recorderOf(int id) {
    final recorder = _recorders[id];
    if (recorder == null) {
      throw AudioError(
        code: AudioError.codeInstanceNotFound,
        message: 'No recorder with id $id',
      );
    }
    return recorder;
  }

  // -- Playback / 播放 ----------------------------------------------------

  @override
  Future<int> createPlayer() async {
    final id = _nextPlayerId++;
    _players[id] = WebPlayer();
    return id;
  }

  @override
  Future<Duration?> setSource(int playerId, AudioSource source) =>
      _playerOf(playerId).setSource(source);

  @override
  Future<void> play(int playerId) => _playerOf(playerId).play();

  @override
  Future<void> pause(int playerId) async => _playerOf(playerId).pause();

  @override
  Future<void> stopPlayer(int playerId) async => _playerOf(playerId).stop();

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      _playerOf(playerId).seek(position);

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      _playerOf(playerId).setVolume(volume);

  @override
  Future<void> setSpeed(int playerId, double speed) async =>
      _playerOf(playerId).setSpeed(speed);

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      _playerOf(playerId).setLooping(looping);

  @override
  Future<Duration> getPosition(int playerId) async =>
      _playerOf(playerId).position();

  @override
  Future<Duration?> getDuration(int playerId) async =>
      _playerOf(playerId).duration();

  @override
  Future<List<AudioDevice>> listOutputDevices() =>
      _listDevices(kind: 'audiooutput', fallbackLabel: 'Speaker');

  @override
  Future<AudioDevice?> getOutputDevice(int playerId) async {
    final deviceId = _playerOf(playerId).outputDeviceId();
    if (deviceId == null) {
      return null;
    }
    final devices = await listOutputDevices();
    return devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => AudioDevice(id: deviceId, label: deviceId),
    );
  }

  @override
  Future<void> setOutputDevice(int playerId, String? deviceId) =>
      _playerOf(playerId).setOutputDevice(deviceId);

  @override
  Future<void> disposePlayer(int playerId) async =>
      _players.remove(playerId)?.dispose();

  @override
  Stream<PlayerEvent> playerEvents(int playerId) =>
      _playerOf(playerId).events.stream;

  // -- Recording / 录音 ----------------------------------------------------

  @override
  Future<int> createRecorder() async {
    final id = _nextRecorderId++;
    _recorders[id] = WebRecorder();
    return id;
  }

  @override
  Future<bool> hasRecordPermission() async {
    // Try the Permissions API first; fall back to a getUserMedia probe on
    // browsers (e.g. older Safari) that do not expose the 'microphone'
    // permission name.
    // 优先使用 Permissions API；在不支持 'microphone' 权限名的浏览器
    // （如旧版 Safari）上回退为 getUserMedia 探测。
    try {
      final status = await web.window.navigator.permissions
          .query(_PermissionDescriptor(name: 'microphone'))
          .toDart;
      if (status.state == 'granted') {
        return true;
      }
      if (status.state == 'denied') {
        return false;
      }
    } catch (_) {
      // Fall through to the probe below. / 继续走下面的探测逻辑。
    }
    try {
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Enumerates media devices of [kind]; labels are empty until a media
  /// permission has been granted, so [fallbackLabel] fills the gap.
  /// 枚举 [kind] 类型的媒体设备；未授予媒体权限前 label 为空，此时使用
  /// [fallbackLabel] 兜底。
  static Future<List<AudioDevice>> _listDevices({
    required String kind,
    required String fallbackLabel,
  }) async {
    final devices = await web.window.navigator.mediaDevices
        .enumerateDevices()
        .toDart;
    return [
      for (final device in devices.toDart)
        if (device.kind == kind)
          AudioDevice(
            id: device.deviceId,
            label: device.label.isEmpty ? fallbackLabel : device.label,
          ),
    ];
  }

  @override
  Future<List<AudioDevice>> listInputDevices() =>
      _listDevices(kind: 'audioinput', fallbackLabel: 'Microphone');

  @override
  Future<AudioDevice?> getInputDevice(int recorderId) async {
    final deviceId = _recorderOf(recorderId).currentInputDeviceId();
    if (deviceId == null) {
      return null;
    }
    final devices = await listInputDevices();
    return devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => AudioDevice(id: deviceId, label: deviceId),
    );
  }

  @override
  Future<void> setInputDevice(int recorderId, String? deviceId) async =>
      _recorderOf(recorderId).setInputDevice(deviceId);

  @override
  Future<void> startRecorder(
    int recorderId,
    RecordConfig config, {
    required String path,
  }) => _recorderOf(recorderId).start(config);

  @override
  Future<void> pauseRecorder(int recorderId) async =>
      _recorderOf(recorderId).pause();

  @override
  Future<void> resumeRecorder(int recorderId) async =>
      _recorderOf(recorderId).resume();

  @override
  Future<String?> stopRecorder(int recorderId) =>
      _recorderOf(recorderId).stop();

  @override
  Future<void> cancelRecorder(int recorderId) =>
      _recorderOf(recorderId).cancel();

  @override
  Future<void> disposeRecorder(int recorderId) async =>
      _recorders.remove(recorderId)?.dispose();

  @override
  Stream<RecorderEvent> recorderEvents(int recorderId) =>
      _recorderOf(recorderId).events.stream;
}

/// Minimal interop type for `navigator.permissions.query` descriptors.
/// `navigator.permissions.query` 描述对象的最小互操作类型。
extension type _PermissionDescriptor._(JSObject _) implements JSObject {
  external factory _PermissionDescriptor({String name});
}
