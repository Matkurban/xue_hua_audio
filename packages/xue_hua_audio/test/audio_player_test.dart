import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

import 'fake_platform.dart';

void main() {
  late FakeAudioPlatform platform;

  setUp(() {
    platform = FakeAudioPlatform();
    XueHuaAudioPlatform.instance = platform;
  });

  group('AudioPlayer', () {
    test('setSource returns duration and emits onDurationChanged', () async {
      final player = AudioPlayer();
      final durations = <Duration?>[];
      player.onDurationChanged.listen(durations.add);

      final duration =
          await player.setSource(const AudioSource.file('/tmp/a.wav'));

      expect(duration, const Duration(seconds: 3));
      expect(player.duration, const Duration(seconds: 3));
      await pumpEventQueue();
      expect(durations, [const Duration(seconds: 3)]);
      expect(platform.calls, contains('setSource:0:AudioSource.file(/tmp/a.wav)'));
      await player.dispose();
    });

    test('failed setSource throws AudioError and enters error state',
        () async {
      platform.setSourceError = const AudioError(
        code: AudioError.codeSourceLoadFailed,
        message: 'boom',
      );
      final player = AudioPlayer();

      await expectLater(
        player.setSource(const AudioSource.url('https://x/a.mp3')),
        throwsA(isA<AudioError>()
            .having((e) => e.code, 'code', AudioError.codeSourceLoadFailed)),
      );
      expect(player.state, PlayerState.error);
      await player.dispose();
    });

    test('output device can be listed, selected and queried', () async {
      final player = AudioPlayer();
      final devices = await AudioPlayer.listOutputDevices();
      expect(devices, hasLength(2));

      expect(await player.getOutputDevice(), isNull);
      await player.setOutputDevice('out-1');
      expect((await player.getOutputDevice())?.label, 'Fake headphones');
      await player.setOutputDevice(null);
      expect(await player.getOutputDevice(), isNull);
      await player.dispose();
    });

    test('commands are forwarded to the platform with the player id',
        () async {
      final player = AudioPlayer();
      await player.setSource(const AudioSource.asset('assets/a.wav'));
      await player.play();
      await player.pause();
      await player.seek(const Duration(milliseconds: 1500));
      await player.setVolume(0.5);
      await player.setSpeed(1.5);
      await player.setLooping(true);
      await player.stop();

      expect(
        platform.calls,
        containsAllInOrder([
          'play:0',
          'pause:0',
          'seekTo:0:1500',
          'setVolume:0:0.5',
          'setSpeed:0:1.5',
          'setLooping:0:true',
          'stopPlayer:0',
        ]),
      );
      await player.dispose();
    });

    test('platform state events drive onStateChanged and completion',
        () async {
      final player = AudioPlayer();
      await player.setSource(const AudioSource.file('/tmp/a.wav'));
      final states = <PlayerState>[];
      player.onStateChanged.listen(states.add);
      var completions = 0;
      player.onPlayerComplete.listen((_) => completions++);

      platform.emitPlayer(0, const PlayerStateEvent(PlayerState.playing));
      platform.emitPlayer(0, const PlayerStateEvent(PlayerState.playing));
      platform.emitPlayer(0, const PlayerCompletedEvent());
      await pumpEventQueue();

      expect(states, [PlayerState.playing, PlayerState.completed]);
      expect(completions, 1);
      expect(player.state, PlayerState.completed);
      await player.dispose();
    });

    test('position is polled while playing', () async {
      final player =
          AudioPlayer(positionUpdateInterval: const Duration(milliseconds: 10));
      await player.setSource(const AudioSource.file('/tmp/a.wav'));
      final positions = <Duration>[];
      player.onPositionChanged.listen(positions.add);

      platform.position = const Duration(milliseconds: 42);
      platform.emitPlayer(0, const PlayerStateEvent(PlayerState.playing));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      platform.emitPlayer(0, const PlayerStateEvent(PlayerState.paused));
      await pumpEventQueue();

      expect(positions, contains(const Duration(milliseconds: 42)));
      await player.dispose();
    });

    test('async platform errors surface on onError', () async {
      final player = AudioPlayer();
      await player.setSource(const AudioSource.file('/tmp/a.wav'));
      final errors = <AudioError>[];
      player.onError.listen(errors.add);

      platform.emitPlayer(
        0,
        const PlayerErrorEvent(
          AudioError(code: AudioError.codePlaybackFailed, message: 'dropped'),
        ),
      );
      await pumpEventQueue();

      expect(errors.single.code, AudioError.codePlaybackFailed);
      expect(player.state, PlayerState.error);
      await player.dispose();
    });

    test('dispose releases the native player and is idempotent', () async {
      final player = AudioPlayer();
      await player.setSource(const AudioSource.file('/tmp/a.wav'));

      await player.dispose();
      await player.dispose();

      expect(
        platform.calls.where((c) => c == 'disposePlayer:0').length,
        1,
      );
      expect(player.isDisposed, isTrue);
      expect(() => player.play(), throwsStateError);
    });
  });
}
