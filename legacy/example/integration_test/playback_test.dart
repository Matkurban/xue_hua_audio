import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('playback', () {
    setUpAll(() async {
      await XueHuaAudio.initialize();
    });

    tearDown(() async {
      await XueHuaAudio.instance.engine.stopAllWithCleanup();
    });

    tearDownAll(() async {
      await XueHuaAudio.instance.dispose();
    });

    test('progressStream emits events with duration', () async {
      final engine = XueHuaAudio.instance.engine;
      final track = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );

      final completer = Completer<XueHuaPlaybackProgress>();
      final sub = track.progressStream.listen((progress) {
        if (!completer.isCompleted && progress.durationSecs != null) {
          completer.complete(progress);
        }
      });

      final progress = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('No progress event received'),
      );

      expect(progress.durationSecs, isNotNull);
      expect(progress.durationSecs! > 0, isTrue);

      await sub.cancel();
      await track.stop();
    });

    test('stop prevents progressStream resubscribe', () async {
      final engine = XueHuaAudio.instance.engine;
      final track = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );

      await track.stop();

      Object? asyncError;
      await runZonedGuarded(
        () async {
          final sub = track.progressStream.listen((_) {});
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await sub.cancel();
        },
        (error, _) {
          asyncError = error;
        },
      );

      expect(asyncError, isA<XueHuaAudioError>());
      await track.stop();
    });

    test('stop prevents seek after deactivation', () async {
      final engine = XueHuaAudio.instance.engine;
      final track = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );

      await track.stop();

      await expectLater(
        track.seekTo(positionSecs: 0),
        throwsA(isA<XueHuaAudioError>()),
      );
    });

    test('stopAll deactivates track handles idempotently', () async {
      final engine = XueHuaAudio.instance.engine;
      final track = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );

      await engine.stopAll();

      expect(track.playbackProgress().isFinished, isTrue);
      await track.stop();
    });

    test('pause and resume keep playback active', () async {
      final engine = XueHuaAudio.instance.engine;
      final track = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );

      await track.pause();
      expect(track.playbackProgress().isPaused, isTrue);
      expect(track.playbackProgress().isPlaying, isFalse);

      await track.resume();
      expect(track.playbackProgress().isPaused, isFalse);
      expect(track.isPlaying(), isTrue);

      await track.stop();
    });

    test('multiple tracks play concurrently', () async {
      final engine = XueHuaAudio.instance.engine;
      final first = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );
      final second = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );

      expect(first.isPlaying(), isTrue);
      expect(second.isPlaying(), isTrue);

      await first.stop();
      expect(first.playbackProgress().isFinished, isTrue);
      expect(second.isPlaying(), isTrue);

      await second.stop();
    });

    test(
      'natural finish unregisters without watcher self-join panic',
      () async {
        final engine = XueHuaAudio.instance.engine;
        final track = await engine.loadAsset(
          assetKey: 'assets/audio/message_ring.wav',
        );

        final finishedCompleter = Completer<void>();
        final sub = track.progressStream.listen((progress) {
          if (!finishedCompleter.isCompleted && progress.isFinished) {
            finishedCompleter.complete();
          }
        });

        await finishedCompleter.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw TimeoutException('Track did not finish naturally'),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await sub.cancel();

        expect(track.playbackProgress().isFinished, isTrue);
        await track.stop();
        await track.stopAndCleanup();
      },
    );

    test('loop position wraps within duration', () async {
      final engine = XueHuaAudio.instance.engine;
      final track = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
        loop: true,
      );

      final durationCompleter = Completer<double>();
      var sawLateLap = false;
      final sub = track.progressStream.listen((progress) {
        if (!durationCompleter.isCompleted && progress.durationSecs != null) {
          durationCompleter.complete(progress.durationSecs!);
        }
        final duration = progress.durationSecs;
        if (duration != null &&
            duration > 0 &&
            progress.positionSecs < duration * 0.25 &&
            progress.positionSecs > 0) {
          sawLateLap = true;
        }
      });

      final durationSecs = await durationCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('No duration received'),
      );

      await Future<void>.delayed(
        Duration(milliseconds: (durationSecs * 1500).round().clamp(800, 10000)),
      );

      expect(track.isFinished(), isFalse);
      expect(track.isPlaying(), isTrue);
      expect(sawLateLap, isTrue, reason: 'Expected loop position to wrap');

      await sub.cancel();
      await track.stop();
    });
  });
}
