// Recording verification requires microphone permission in a full app context.
//
// To attempt automated run (macOS with mic permission):
//   cd example && flutter test integration_test/recording_test.dart -d macos \
//     --dart-define=RECORDING_TEST=true

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

const _recordingTestEnabled = bool.fromEnvironment('RECORDING_TEST');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('recording', () {
    setUpAll(() async {
      await XuehuaAudio.initialize();
    });

    tearDownAll(() async {
      await XuehuaAudio.instance.dispose();
    });

    test('progressStream emits events and writes wav file', () async {
      if (!_recordingTestEnabled) {
        markTestSkipped('Set --dart-define=RECORDING_TEST=true to run');
      }
      if (!Platform.isMacOS) {
        markTestSkipped('Recording integration test runs on macOS only');
      }

      PermissionStatus? status;
      try {
        status = await Permission.microphone.request();
      } on MissingPluginException {
        markTestSkipped(
          'permission_handler unavailable in integration test harness',
        );
      }
      if (status == null || !status.isGranted) {
        markTestSkipped('Microphone permission denied');
      }

      final engine = XuehuaAudio.instance.engine;
      final session = await engine.createRecordingSession();
      final outputPath = p.join(
        (await getTemporaryDirectory()).path,
        'xuehua_test_recording_${DateTime.now().microsecondsSinceEpoch}.wav',
      );

      final progressEvents = <XueHuaRecordingProgress>[];
      final progressSub = session.progressStream.listen(progressEvents.add);

      await session.start(outputPath: outputPath);

      await Future<void>.delayed(const Duration(milliseconds: 300));

      final path = await session.stop();
      await progressSub.cancel();
      await session.dispose();

      expect(path, outputPath);
      expect(await File(path).exists(), isTrue);
      expect(progressEvents.length, greaterThanOrEqualTo(1));
      expect(progressEvents.last.durationSecs, greaterThanOrEqualTo(0));
    });

    test('stop then start is stopped by engine.stopAllRecorders', () async {
      if (!_recordingTestEnabled) {
        markTestSkipped('Set --dart-define=RECORDING_TEST=true to run');
      }
      if (!Platform.isMacOS) {
        markTestSkipped('Recording integration test runs on macOS only');
      }

      PermissionStatus? status;
      try {
        status = await Permission.microphone.request();
      } on MissingPluginException {
        markTestSkipped(
          'permission_handler unavailable in integration test harness',
        );
      }
      if (status == null || !status.isGranted) {
        markTestSkipped('Microphone permission denied');
      }

      final engine = XuehuaAudio.instance.engine;
      final session = await engine.createRecordingSession();
      final tempDir = await getTemporaryDirectory();

      final firstPath = p.join(
        tempDir.path,
        'xuehua_test_recording_first_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await session.start(outputPath: firstPath);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await session.stop();

      final secondPath = p.join(
        tempDir.path,
        'xuehua_test_recording_second_${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      await session.start(outputPath: secondPath);
      expect(session.isRecording, isTrue);

      await engine.stopAllRecorders();
      expect(session.isRecording, isFalse);

      await session.dispose();
    });
  });
}
