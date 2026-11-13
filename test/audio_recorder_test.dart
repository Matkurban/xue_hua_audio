import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_audio/src/audio_backend.dart';
import 'package:xue_hua_audio/src/events.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

import 'fake_platform.dart';

void main() {
  late FakeAudioBackend backend;

  setUp(() {
    backend = FakeAudioBackend();
    AudioBackend.instance = backend;
    addTearDown(AudioBackend.resetInstance);
  });

  group('AudioRecorder', () {
    test('start transitions to recording and stop returns the path', () async {
      final recorder = AudioRecorder();
      final states = <RecorderState>[];
      recorder.onStateChanged.listen(states.add);

      await recorder.start(const RecordConfig(), path: '/tmp/take1.wav');
      await pumpEventQueue();
      expect(recorder.isRecording, isTrue);

      final path = await recorder.stop();
      expect(path, '/tmp/out.wav');
      expect(states, contains(RecorderState.recording));
      expect(backend.calls, contains('startRecorder:100:/tmp/take1.wav'));
      await recorder.dispose();
    });

    test('amplitude events are forwarded to onAmplitudeChanged', () async {
      final recorder = AudioRecorder();
      final samples = <Amplitude>[];
      recorder.onAmplitudeChanged.listen(samples.add);
      await recorder.start(const RecordConfig(), path: '/tmp/a.wav');

      backend.emitRecorder(
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

    test(
      'recorder errors surface on onError and set the error state',
      () async {
        final recorder = AudioRecorder();
        await recorder.start(const RecordConfig(), path: '/tmp/a.wav');
        final errors = <AudioError>[];
        recorder.onError.listen(errors.add);

        backend.emitRecorder(
          100,
          const RecorderErrorEvent(
            AudioError(code: AudioError.codeRecordingFailed, message: 'lost'),
          ),
        );
        await pumpEventQueue();

        expect(errors.single.code, AudioError.codeRecordingFailed);
        expect(recorder.state, RecorderState.error);
        await recorder.dispose();
      },
    );

    test('dispose releases the native recorder and is idempotent', () async {
      final recorder = AudioRecorder();
      await recorder.start(const RecordConfig(), path: '/tmp/a.wav');

      await recorder.dispose();
      await recorder.dispose();

      expect(backend.calls.where((c) => c == 'disposeRecorder:100').length, 1);
      expect(() => recorder.stop(), throwsStateError);
    });

    test(
      'dispose before createRecorder resolves skips event subscription and rejects queued calls',
      () async {
        final isolated = FakeAudioBackend();
        final gate = Completer<int>();
        isolated.createRecorderGate = gate;

        final recorder = AudioRecorder(backend: isolated);
        final queuedStart = expectLater(
          recorder.start(const RecordConfig(), path: '/tmp/race.wav'),
          throwsStateError,
        );
        final disposeFuture = recorder.dispose();

        gate.complete(77);
        await disposeFuture;
        await queuedStart;

        expect(isolated.calls, ['createRecorder:77', 'disposeRecorder:77']);
        expect(
          isolated.calls.where((c) => c.startsWith('startRecorder:')),
          isEmpty,
        );
        expect(isolated.recorderControllers, isEmpty);
      },
    );
  });
}
