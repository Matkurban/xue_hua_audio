import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_audio/src/events.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

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

Duration _ms(int n) => Duration(milliseconds: n);

void main() {
  group('WaveformController', () {
    WaveformController make({double rate = 30}) =>
        WaveformController(maxBarsPerSecond: rate, attack: 1, release: 1)
          ..active = true;
    List<double> bars(WaveformController c) => [
      for (var i = 0; i < c.length; i++) c.valueAt(i),
    ];

    test('normalize: gate at minDb, soft knee, clamp', () {
      final c = WaveformController();
      expect(c.normalize(-160), 0);
      expect(c.normalize(-50), 0);
      expect(c.normalize(-55), 0);
      expect(c.normalize(0), 1);
      expect(c.normalize(10), 1);
      expect(c.normalize(double.nan), 0);
      // Soft knee: -45 dBFS (typical noise) stays tiny, -25 is mid-low.
      expect(c.normalize(-45), lessThan(0.05));
      expect(c.normalize(-25), closeTo(0.3536, 1e-3));
      expect(c.normalize(-10), greaterThan(0.7));
      c.dispose();
    });

    test('silence yields exact zeros (flat dots), never decays or repeats', () {
      final c = make();
      for (var i = 0; i < 20; i++) {
        c.addDb(-160);
        c.advance(_ms(100));
      }
      expect(c.length, 20);
      expect(bars(c).every((v) => v == 0), isTrue);
      c.dispose();
    });

    test('constant noise floor is a constant bar, not a sawtooth', () {
      // Regression: -45 dBFS every 170 ms used to render as a repeating
      // 5-bar saw (0.19 0.15 0.11 0.08 0.06) because every event was held and
      // decayed over several fixed-rate samples.
      final c = WaveformController()..active = true; // default smoothing
      for (var i = 0; i < 30; i++) {
        c.addDb(-45);
        c.advance(_ms(170));
      }
      expect(c.length, 30, reason: 'one bar per event, no duplicates');
      final v = bars(c).skip(6).toList();
      expect(
        v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b),
        lessThan(1e-6),
      );
      expect(v.first, lessThan(0.05));
      c.dispose();
    });

    test('one bar per event regardless of native interval', () {
      for (final interval in [20, 50, 100, 170]) {
        final c = make(rate: 60);
        for (var i = 0; i < 10; i++) {
          c.addDb(-20);
          c.advance(_ms(interval));
        }
        expect(c.length, 10, reason: '$interval ms');
        c.dispose();
      }
    });

    test('measured interval drives the scroll phase', () {
      final c = make();
      for (var i = 0; i < 40; i++) {
        c.addDb(-20);
        c.advance(_ms(100));
      }
      expect(c.barInterval, closeTo(0.1, 0.005));
      c.addDb(-20);
      c.advance(_ms(50)); // halfway through the next 100 ms bar slot
      expect(c.phase, closeTo(0.5, 0.02));
      c.advance(_ms(500)); // events stopped: the scroll parks, never overruns
      expect(c.phase, 1.0);
      c.dispose();
    });

    test('bursty events are merged to the loudest value', () {
      final c = make(rate: 10);
      c.addNormalized(0.2); // first event commits immediately
      c.advance(_ms(10));
      for (var i = 0; i < 50; i++) {
        c.addNormalized(i / 100); // burst inside one 100 ms slot
      }
      expect(c.length, 1);
      c.advance(_ms(100));
      expect(c.length, 2);
      expect(c.valueAt(1), closeTo(0.49, 1e-6));
      c.dispose();
    });

    test('ring buffer keeps only the newest [capacity] bars', () {
      final c = WaveformController(
        capacity: 4,
        maxBarsPerSecond: 10,
        attack: 1,
        release: 1,
      )..active = true;
      for (var i = 1; i <= 6; i++) {
        c.addNormalized(i / 10);
        c.advance(_ms(100));
      }
      expect(bars(c), [
        closeTo(0.3, 1e-6),
        closeTo(0.4, 1e-6),
        closeTo(0.5, 1e-6),
        closeTo(0.6, 1e-6),
      ]);
      c.dispose();
    });

    test('attack/release smooth consecutive bars', () {
      final c = WaveformController(
        maxBarsPerSecond: 10,
        attack: 0.5,
        release: 0.25,
      )..active = true;
      c.addNormalized(1);
      c.advance(_ms(100));
      c.addNormalized(0);
      c.advance(_ms(100));
      expect(c.valueAt(0), closeTo(0.5, 1e-6));
      expect(c.valueAt(1), closeTo(0.375, 1e-6));
      c.dispose();
    });

    test('inactive controller ignores events; clear() resets', () {
      final c = WaveformController();
      c.addDb(-10);
      c.advance(_ms(100));
      expect(c.length, 0);
      c.active = true;
      c.addDb(-10);
      expect(c.length, 1);
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
      final controller = WaveformController(maxBarsPerSecond: 20);
      await tester.pumpWidget(
        _host(AudioWaveform(recorder: recorder, controller: controller)),
      );
      await recorder.start(const RecordConfig(), path: '/tmp/w.wav');
      platform.emitRecorder(
        100,
        const RecorderStateEvent(RecorderState.recording),
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        platform.emitRecorder(
          100,
          const RecorderAmplitudeEvent(Amplitude(current: -3, max: -3)),
        );
        await tester.pump(const Duration(milliseconds: 60));
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
      final controller = WaveformController(maxBarsPerSecond: 20)
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

  group('defaults', () {
    test('are public documented constants', () {
      expect(WaveformColors.active, const Color(0xFF22A45D));
      expect(WaveformColors.inactive, const Color(0xFFB8BEC4));
    });

    testWidgets('render without any Material/Theme ancestor', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              AudioWaveform(active: false),
              StaticWaveform(levels: [0.2, 0.8], progress: 0.5),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
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
