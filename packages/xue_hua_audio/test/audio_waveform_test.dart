import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

import 'fake_platform.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: Center(child: SizedBox(width: 300, child: child)),
        ),
      ),
    );

void main() {
  group('WaveformController', () {
    test('normalizes dBFS into 0..1 and clamps', () {
      final c = WaveformController();
      expect(c.normalize(-60), 0);
      expect(c.normalize(0), 1);
      expect(c.normalize(-30), closeTo(0.5, 1e-9));
      expect(c.normalize(-200), 0);
      expect(c.normalize(10), 1);
      expect(c.normalize(double.nan), 0);
      c.dispose();
    });

    test('samples at a fixed rate regardless of event rate', () {
      final c = WaveformController(samplesPerSecond: 10, attack: 1, release: 1);
      // 50 events in one interval collapse into a single peak sample.
      for (var i = 0; i < 50; i++) {
        c.addNormalized(i / 100);
      }
      c.advance(const Duration(milliseconds: 100));
      expect(c.length, 1);
      expect(c.valueAt(0), closeTo(0.49, 1e-6));
      // No events for 3 intervals → 3 silent samples.
      c.advance(const Duration(milliseconds: 300));
      expect(c.length, 4);
      expect(c.valueAt(3), 0);
      c.dispose();
    });

    test('ring buffer keeps only the newest [capacity] samples', () {
      final c = WaveformController(
        capacity: 4,
        samplesPerSecond: 10,
        attack: 1,
        release: 1,
      );
      for (var i = 1; i <= 6; i++) {
        c.addNormalized(i / 10);
        c.advance(const Duration(milliseconds: 100));
      }
      expect(c.length, 4);
      expect(
        [for (var i = 0; i < 4; i++) c.valueAt(i)],
        [
          closeTo(0.3, 1e-6),
          closeTo(0.4, 1e-6),
          closeTo(0.5, 1e-6),
          closeTo(0.6, 1e-6),
        ],
      );
      c.dispose();
    });

    test('attack/release smooth the level', () {
      final c = WaveformController(
        samplesPerSecond: 10,
        attack: 0.5,
        release: 0.25,
      );
      c.addNormalized(1);
      c.advance(const Duration(milliseconds: 100));
      expect(c.valueAt(0), closeTo(0.5, 1e-6));
      c.advance(const Duration(milliseconds: 100));
      expect(c.valueAt(1), closeTo(0.375, 1e-6));
      c.dispose();
    });

    test('a long stall is capped and clear() resets', () {
      final c = WaveformController(capacity: 8, samplesPerSecond: 10);
      c.advance(const Duration(minutes: 10));
      expect(c.length, 8);
      c.clear();
      expect(c.length, 0);
      c.dispose();
    });
  });

  group('AudioWaveform', () {
    testWidgets('renders flat dots when idle, without a running ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AudioWaveform(active: false)));
      await tester.pump();
      expect(find.byType(AudioWaveform), findsOneWidget);
      expect(find.bySemanticsLabel('Waveform'), findsOneWidget);
      // Nothing is scheduled while inactive. / 未激活时没有待执行帧。
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('consumes a dBFS stream and scrolls', (tester) async {
      final levels = StreamController<double>.broadcast();
      final key = GlobalKey();
      await tester.pumpWidget(
        _host(AudioWaveform(key: key, levels: levels.stream)),
      );
      levels.add(-6);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        levels.add(-10);
      }
      // Painting must not throw and a frame was produced.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await levels.close();
    });

    testWidgets('follows a recorder: records, pauses, stops', (tester) async {
      final platform = FakeAudioPlatform();
      XueHuaAudioPlatform.instance = platform;
      final recorder = AudioRecorder();
      final controller = WaveformController(samplesPerSecond: 20);
      await tester.pumpWidget(
        _host(AudioWaveform(recorder: recorder, controller: controller)),
      );
      await recorder.start(const RecordConfig(), path: '/tmp/w.wav');
      platform.emitRecorder(
        100,
        const RecorderStateEvent(RecorderState.recording),
      );
      await tester.pump();
      platform.emitRecorder(
        100,
        const RecorderAmplitudeEvent(Amplitude(current: -3, max: -3)),
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(controller.active, isTrue);
      expect(controller.length, greaterThan(2));
      final peak = [
        for (var i = 0; i < controller.length; i++) controller.valueAt(i),
      ].reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(0.3));

      await recorder.pause();
      platform.emitRecorder(
        100,
        const RecorderStateEvent(RecorderState.paused),
      );
      await tester.pump();
      final frozen = controller.length;
      expect(controller.active, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.length, frozen);

      await recorder.stop();
      platform.emitRecorder(
        100,
        const RecorderStateEvent(RecorderState.stopped),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      // The fake platform's controller close() never completes once a
      // subscription was cancelled mid-flight; don't await it here.
      // 假平台的 controller.close() 在订阅中途取消后不会完成，这里不等待。
      unawaited(recorder.dispose());
    });

    testWidgets('all styles and RTL paint without errors', (tester) async {
      final controller = WaveformController(samplesPerSecond: 20)
        ..active = true;
      for (final style in WaveformStyle.values) {
        for (final dir in TextDirection.values) {
          await tester.pumpWidget(
            _host(
              AudioWaveform(
                controller: controller,
                style: style,
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                ),
              ),
              dir: dir,
            ),
          );
          controller.addNormalized(0.8);
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('swapping the source disposes the old subscription', (
      tester,
    ) async {
      final a = StreamController<double>.broadcast();
      final b = StreamController<double>.broadcast();
      await tester.pumpWidget(_host(AudioWaveform(levels: a.stream)));
      expect(a.hasListener, isTrue);
      await tester.pumpWidget(_host(AudioWaveform(levels: b.stream)));
      expect(a.hasListener, isFalse);
      expect(b.hasListener, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(b.hasListener, isFalse);
    });
  });

  group('StaticWaveform', () {
    testWidgets('paints and exposes progress via semantics', (tester) async {
      await tester.pumpWidget(
        _host(
          StaticWaveform(
            levels: List.generate(200, (i) => (i % 10) / 10),
            progress: 0.4,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Audio waveform')),
        matchesSemantics(label: 'Audio waveform', value: '40%', isImage: true),
      );
    });

    testWidgets('handles empty data and RTL', (tester) async {
      await tester.pumpWidget(
        _host(const StaticWaveform(levels: []), dir: TextDirection.rtl),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
