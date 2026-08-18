import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

/// An in-memory [XueHuaAudioPlatform] test double that records every call
/// and lets tests push events manually.
///
/// 内存版 [XueHuaAudioPlatform] 测试替身：记录所有调用，并允许测试手动
/// 推送事件。
class FakeAudioPlatform extends XueHuaAudioPlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = [];

  int _nextPlayerId = 0;
  int _nextRecorderId = 100;

  final Map<int, StreamController<PlayerEvent>> playerControllers = {};
  final Map<int, StreamController<RecorderEvent>> recorderControllers = {};

  Duration? sourceDuration = const Duration(seconds: 3);
  AudioError? setSourceError;
  Duration position = Duration.zero;
  String? stopResult = '/tmp/out.wav';
  bool permission = true;

  final List<AudioDevice> outputDevices = const [
    AudioDevice(id: 'out-0', label: 'Fake speaker'),
    AudioDevice(id: 'out-1', label: 'Fake headphones'),
  ];
  final Map<int, String?> playerOutputDevice = {};
  final Map<int, String?> recorderInputDevice = {};

  void emitPlayer(int id, PlayerEvent event) =>
      playerControllers[id]!.add(event);

  void emitRecorder(int id, RecorderEvent event) =>
      recorderControllers[id]!.add(event);

  @override
  Future<int> createPlayer() async {
    final id = _nextPlayerId++;
    playerControllers[id] = StreamController<PlayerEvent>.broadcast();
    calls.add('createPlayer:$id');
    return id;
  }

  @override
  Future<Duration?> setSource(int playerId, AudioSource source) async {
    calls.add('setSource:$playerId:$source');
    final error = setSourceError;
    if (error != null) {
      throw error;
    }
    return sourceDuration;
  }

  @override
  Future<void> play(int playerId) async => calls.add('play:$playerId');

  @override
  Future<void> pause(int playerId) async => calls.add('pause:$playerId');

  @override
  Future<void> stopPlayer(int playerId) async =>
      calls.add('stopPlayer:$playerId');

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      calls.add('seekTo:$playerId:${position.inMilliseconds}');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('setVolume:$playerId:$volume');

  @override
  Future<void> setSpeed(int playerId, double speed) async =>
      calls.add('setSpeed:$playerId:$speed');

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('setLooping:$playerId:$looping');

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<Duration?> getDuration(int playerId) async => sourceDuration;

  @override
  Future<List<AudioDevice>> listOutputDevices() async {
    calls.add('listOutputDevices');
    return outputDevices;
  }

  @override
  Future<AudioDevice?> getOutputDevice(int playerId) async {
    calls.add('getOutputDevice:$playerId');
    final id = playerOutputDevice[playerId];
    if (id == null) return null;
    return outputDevices.firstWhere((d) => d.id == id);
  }

  @override
  Future<void> setOutputDevice(int playerId, String? deviceId) async {
    calls.add('setOutputDevice:$playerId:$deviceId');
    playerOutputDevice[playerId] = deviceId;
  }

  @override
  Future<void> disposePlayer(int playerId) async {
    calls.add('disposePlayer:$playerId');
    await playerControllers.remove(playerId)?.close();
  }

  @override
  Stream<PlayerEvent> playerEvents(int playerId) =>
      playerControllers[playerId]!.stream;

  @override
  Future<int> createRecorder() async {
    final id = _nextRecorderId++;
    recorderControllers[id] = StreamController<RecorderEvent>.broadcast();
    calls.add('createRecorder:$id');
    return id;
  }

  @override
  Future<bool> hasRecordPermission() async {
    calls.add('hasRecordPermission');
    return permission;
  }

  @override
  Future<List<AudioDevice>> listInputDevices() async =>
      const [AudioDevice(id: 'mic-0', label: 'Fake microphone')];

  @override
  Future<AudioDevice?> getInputDevice(int recorderId) async {
    calls.add('getInputDevice:$recorderId');
    final id = recorderInputDevice[recorderId];
    if (id == null) return null;
    return AudioDevice(id: id, label: 'Fake microphone');
  }

  @override
  Future<void> setInputDevice(int recorderId, String? deviceId) async {
    calls.add('setInputDevice:$recorderId:$deviceId');
    recorderInputDevice[recorderId] = deviceId;
  }

  @override
  Future<void> startRecorder(int recorderId, RecordConfig config,
      {required String path}) async {
    calls.add('startRecorder:$recorderId:$path');
    emitRecorder(recorderId, const RecorderStateEvent(RecorderState.recording));
  }

  @override
  Future<void> pauseRecorder(int recorderId) async =>
      calls.add('pauseRecorder:$recorderId');

  @override
  Future<void> resumeRecorder(int recorderId) async =>
      calls.add('resumeRecorder:$recorderId');

  @override
  Future<String?> stopRecorder(int recorderId) async {
    calls.add('stopRecorder:$recorderId');
    return stopResult;
  }

  @override
  Future<void> cancelRecorder(int recorderId) async =>
      calls.add('cancelRecorder:$recorderId');

  @override
  Future<void> disposeRecorder(int recorderId) async {
    calls.add('disposeRecorder:$recorderId');
    await recorderControllers.remove(recorderId)?.close();
  }

  @override
  Stream<RecorderEvent> recorderEvents(int recorderId) =>
      recorderControllers[recorderId]!.stream;
}
