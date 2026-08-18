import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_audio_platform_interface/src/messages.g.dart';
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

/// Records calls made through the Pigeon player client.
/// 记录经由 Pigeon 播放器客户端发起的调用。
class _FakePlayerApi extends AudioPlayerHostApi {
  final List<String> calls = [];
  AudioSourceMessage? lastSource;

  @override
  Future<int> createPlayer() async {
    calls.add('createPlayer');
    return 7;
  }

  @override
  Future<int?> setSource(int playerId, AudioSourceMessage source) async {
    calls.add('setSource:$playerId');
    lastSource = source;
    return 2500;
  }

  @override
  Future<void> play(int playerId) async => calls.add('play:$playerId');

  @override
  Future<void> pause(int playerId) async => calls.add('pause:$playerId');

  @override
  Future<void> stop(int playerId) async => calls.add('stop:$playerId');

  @override
  Future<void> seekTo(int playerId, int positionMs) async =>
      calls.add('seekTo:$playerId:$positionMs');

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
  Future<int> getPosition(int playerId) async => 1234;

  @override
  Future<int?> getDuration(int playerId) async => null;

  @override
  Future<void> disposePlayer(int playerId) async =>
      calls.add('disposePlayer:$playerId');
}

/// A Pigeon recorder client whose `start` always fails with a
/// [PlatformException]. / `start` 恒定抛出 [PlatformException] 的录音客户端。
class _ThrowingRecorderApi extends AudioRecorderHostApi {
  @override
  Future<int> createRecorder() async => 1;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<List<AudioDeviceMessage>> listInputDevices() async => [];

  @override
  Future<void> start(
    int recorderId,
    RecordConfigMessage config,
    String path,
  ) async {
    throw PlatformException(
      code: AudioError.codePermissionDenied,
      message: 'denied',
    );
  }

  @override
  Future<void> pause(int recorderId) async {}

  @override
  Future<void> resume(int recorderId) async {}

  @override
  Future<String?> stop(int recorderId) async => null;

  @override
  Future<void> cancel(int recorderId) async {}

  @override
  Future<void> disposeRecorder(int recorderId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelXueHuaAudio', () {
    test('asset sources are resolved to full asset keys', () async {
      final api = _FakePlayerApi();
      final channel = MethodChannelXueHuaAudio(playerApi: api);

      final duration = await channel.setSource(
        7,
        const AudioSource.asset('assets/a.wav', package: 'my_pkg'),
      );

      expect(duration, const Duration(milliseconds: 2500));
      expect(api.lastSource!.type, SourceTypeMessage.asset);
      expect(api.lastSource!.uri, 'packages/my_pkg/assets/a.wav');
    });

    test('url sources keep their headers', () async {
      final api = _FakePlayerApi();
      final channel = MethodChannelXueHuaAudio(playerApi: api);

      await channel.setSource(
        7,
        const AudioSource.url(
          'https://x/a.mp3',
          headers: {'Authorization': 'Bearer t'},
        ),
      );

      expect(api.lastSource!.type, SourceTypeMessage.url);
      expect(api.lastSource!.headers, {'Authorization': 'Bearer t'});
    });

    test('volume is clamped to 0.0–1.0', () async {
      final api = _FakePlayerApi();
      final channel = MethodChannelXueHuaAudio(playerApi: api);

      await channel.setVolume(7, 3.5);

      expect(api.calls, contains('setVolume:7:1.0'));
    });

    test('PlatformException is translated into AudioError', () async {
      final channel = MethodChannelXueHuaAudio(
        recorderApi: _ThrowingRecorderApi(),
      );

      await expectLater(
        channel.startRecorder(1, const RecordConfig(), path: '/tmp/a.wav'),
        throwsA(
          isA<AudioError>()
              .having((e) => e.code, 'code', AudioError.codePermissionDenied)
              .having((e) => e.message, 'message', 'denied'),
        ),
      );
    });

    test('player event payloads are decoded into typed events', () async {
      const channelName = 'xue_hua_audio/player_events_7';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            const EventChannel(channelName),
            MockStreamHandler.inline(
              onListen: (arguments, events) {
                events.success({'type': 'state', 'state': 'playing'});
                events.success({'type': 'duration', 'durationMs': 1500});
                events.success({'type': 'completed'});
                events.success({
                  'type': 'error',
                  'code': AudioError.codePlaybackFailed,
                  'message': 'x',
                });
                events.endOfStream();
              },
            ),
          );

      final channel = MethodChannelXueHuaAudio(playerApi: _FakePlayerApi());
      final events = await channel.playerEvents(7).toList();

      expect(events, hasLength(4));
      expect((events[0] as PlayerStateEvent).state, PlayerState.playing);
      expect(
        (events[1] as PlayerDurationEvent).duration,
        const Duration(milliseconds: 1500),
      );
      expect(events[2], isA<PlayerCompletedEvent>());
      expect(
        (events[3] as PlayerErrorEvent).error.code,
        AudioError.codePlaybackFailed,
      );
    });

    test('recorder amplitude payloads are decoded', () async {
      const channelName = 'xue_hua_audio/recorder_events_3';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            const EventChannel(channelName),
            MockStreamHandler.inline(
              onListen: (arguments, events) {
                events.success({'type': 'state', 'state': 'recording'});
                events.success({
                  'type': 'amplitude',
                  'current': -9.5,
                  'max': -1.0,
                });
                events.endOfStream();
              },
            ),
          );

      final channel = MethodChannelXueHuaAudio(playerApi: _FakePlayerApi());
      final events = await channel.recorderEvents(3).toList();

      expect((events[0] as RecorderStateEvent).state, RecorderState.recording);
      final amplitude = (events[1] as RecorderAmplitudeEvent).amplitude;
      expect(amplitude.current, -9.5);
      expect(amplitude.max, -1.0);
    });
  });
}
