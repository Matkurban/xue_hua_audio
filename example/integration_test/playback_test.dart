import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('playback', () {
    setUpAll(() async {
      await XuehuaAudio.initialize();
    });

    tearDown(() async {
      await XuehuaAudio.instance.engine.stopAllWithCleanup();
    });

    tearDownAll(() async {
      await XuehuaAudio.instance.dispose();
    });

    test('progressStream emits events with duration', () async {
      final engine = XuehuaAudio.instance.engine;
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
      final engine = XuehuaAudio.instance.engine;
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
      await expectLater(track.stop(), throwsA(isA<XueHuaAudioError>()));
    });

    test('stopAll deactivates track handles idempotently', () async {
      final engine = XuehuaAudio.instance.engine;
      final track = await engine.loadAsset(
        assetKey: 'assets/audio/message_ring.wav',
      );

      await engine.stopAll();

      expect(track.playbackProgress().isFinished, isTrue);
      await track.stop();
    });
  });
}
