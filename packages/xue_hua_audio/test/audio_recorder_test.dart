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

  group('AudioRecorder', () {
    test('start transitions to recording and stop returns the path',
        () async {
      final recorder = AudioRecorder();
      final states = <RecorderState>[];
      recorder.onStateChanged.listen(states.add);

      await recorder.start(const RecordConfig(), path: '/tmp/take1.wav');
      await pumpEventQueue();
      expect(recorder.isRecording, isTrue);

      final path = await recorder.stop();
      expect(path, '/tmp/out.wav');
      expect(states, contains(RecorderState.recording));
      expect(platform.calls, contains('startRecorder:100:/tmp/take1.wav'));
      await recorder.dispose();
    });

    test('amplitude events are forwarded to onAmplitudeChanged', () async {
      final recorder = AudioRecorder();
      final samples = <Amplitude>[];
      recorder.onAmplitudeChanged.listen(samples.add);
      await recorder.start(const RecordConfig(), path: '/tmp/a.wav');

      platform.emitRecorder(
        100,
        const RecorderAmplitudeEvent(Amplitude(current: -12.5, max: -3)),
      );
      await pumpEventQueue();

      expect(samples.single.current, -12.5);
      expect(samples.single.max, -3);
      expect(samples.single.normalized, closeTo((60 - 12.5) / 60, 1e-9));
      await recorder.dispose();
    });

    test('permission and device queries are forwarded', () async {
      final recorder = AudioRecorder();
      expect(await recorder.hasPermission(), isTrue);
      final devices = await recorder.listInputDevices();
      expect(devices.single.id, 'mic-0');
      await recorder.dispose();
    });

    test('input device can be selected and queried', () async {
      final recorder = AudioRecorder();
      expect(await recorder.getInputDevice(), isNull);
      await recorder.setInputDevice('mic-0');
      expect((await recorder.getInputDevice())?.id, 'mic-0');
      await recorder.setInputDevice(null);
      expect(await recorder.getInputDevice(), isNull);
      await recorder.dispose();
    });

    test('recorder errors surface on onError and set the error state',
        () async {
      final recorder = AudioRecorder();
      await recorder.start(const RecordConfig(), path: '/tmp/a.wav');
      final errors = <AudioError>[];
      recorder.onError.listen(errors.add);

      platform.emitRecorder(
        100,
        const RecorderErrorEvent(
          AudioError(code: AudioError.codeRecordingFailed, message: 'lost'),
        ),
      );
      await pumpEventQueue();

      expect(errors.single.code, AudioError.codeRecordingFailed);
      expect(recorder.state, RecorderState.error);
      await recorder.dispose();
    });

    test('dispose releases the native recorder and is idempotent', () async {
      final recorder = AudioRecorder();
      await recorder.start(const RecordConfig(), path: '/tmp/a.wav');

      await recorder.dispose();
      await recorder.dispose();

      expect(
        platform.calls.where((c) => c == 'disposeRecorder:100').length,
        1,
      );
      expect(() => recorder.stop(), throwsStateError);
    });
  });
}
