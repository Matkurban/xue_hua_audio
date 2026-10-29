import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_audio/src/events.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

import 'fake_platform.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    Directionality(
      textDirection: dir,
      child: Center(child: SizedBox(width: 300, child: child)),
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
      expect(c.peakHold, 0);
      expect(c.latest, 0);
      c.dispose();
    });

    test('recentAt, sampleInterpolated, and peakHold decay accurately', () {
      final c = make(rate: 10);
      expect(c.recentAt(0), 0);
      expect(c.recentAt(-1), 0);
      expect(c.sampleInterpolated(0.5), 0);

      c.addNormalized(0.2);
      c.advance(_ms(100));
      c.addNormalized(0.8);
      c.advance(_ms(100));

      expect(c.latest, closeTo(0.8, 1e-6));
      expect(c.recentAt(0), closeTo(0.8, 1e-6));
      expect(c.recentAt(1), closeTo(0.2, 1e-6));
      expect(c.recentAt(2), 0.0);
      expect(c.sampleInterpolated(0.5), closeTo(0.5, 1e-6));
      expect(c.peakHold, closeTo(0.8, 1e-6));

      // Feed silence; peakHold stays held during the 450 ms hold window,
      // then decays smoothly towards 0.
      c.addNormalized(0.0);
      c.advance(_ms(200));
      expect(c.peakHold, closeTo(0.8, 1e-6));

      c.advance(_ms(400)); // past 450 ms hold window
      expect(c.peakHold, lessThan(0.8));
      expect(c.peakHold, greaterThan(0.3));

      c.advance(_ms(2000));
      expect(c.peakHold, 0.0);
      c.dispose();
    });
  });

  group('WaveformDataParser (Data Parsing & Geometry for 16 Visualizers)', () {
    test('parseDb & parseAmplitude handle edge cases and soft knee', () {
      expect(WaveformDataParser.parseDb(double.nan), 0.0);
      expect(WaveformDataParser.parseDb(double.negativeInfinity), 0.0);
      expect(WaveformDataParser.parseDb(-50), 0.0);
      expect(WaveformDataParser.parseDb(-80), 0.0);
      expect(WaveformDataParser.parseDb(0), 1.0);
      expect(WaveformDataParser.parseDb(12), 1.0);
      expect(WaveformDataParser.parseDb(double.infinity), 1.0);
      expect(
        WaveformDataParser.parseDb(-25, minDb: -50, maxDb: 0, curve: 1.0),
        closeTo(0.5, 1e-6),
      );
      expect(
        WaveformDataParser.parseAmplitude(
          const Amplitude(current: -25, max: -6),
          minDb: -50,
          maxDb: 0,
          curve: 1.0,
        ),
        closeTo(0.5, 1e-6),
      );
    });

    test('computeMetrics calculates current, average, rms, peak, and flux', () {
      final c = WaveformController(maxBarsPerSecond: 20, attack: 1, release: 1)
        ..active = true;

      final empty = c.computeMetrics();
      expect(empty, WaveformMetrics.zero);
      expect(empty.isSilent, isTrue);

      for (final v in [0.2, 0.8, 0.2, 0.8]) {
        c.addNormalized(v);
        c.advance(_ms(100));
      }
      final m = c.computeMetrics(window: 4);
      expect(m.sampleCount, 4);
      expect(m.current, closeTo(0.8, 1e-6));
      expect(m.average, closeTo(0.5, 1e-6));
      expect(m.rms, closeTo(math.sqrt(0.34), 1e-4));
      expect(m.peak, closeTo(0.8, 1e-6));
      expect(m.peakHold, closeTo(0.8, 1e-6));
      expect(m.flux, closeTo(0.6, 1e-6));
      expect(m.isSilent, isFalse);
      expect(m.toString(), contains('WaveformMetrics'));
      c.dispose();
    });

    test(
      'resamplePeak handles empty, single, upsampling, and downsampling',
      () {
        expect(WaveformDataParser.resamplePeak(const [], 0), isEmpty);
        expect(WaveformDataParser.resamplePeak(const [], 4), [0, 0, 0, 0]);
        expect(WaveformDataParser.resamplePeak(const [0.6], 3), [
          closeTo(0.6, 1e-6),
          closeTo(0.6, 1e-6),
          closeTo(0.6, 1e-6),
        ]);
        expect(WaveformDataParser.resamplePeak(const [0.1, 0.9, 0.3], 1), [
          closeTo(0.9, 1e-6),
        ]);

        final up = WaveformDataParser.resamplePeak(const [0.0, 1.0, 0.0], 5);
        expect(up, [
          closeTo(0.0, 1e-6),
          closeTo(0.5, 1e-6),
          closeTo(1.0, 1e-6),
          closeTo(0.5, 1e-6),
          closeTo(0.0, 1e-6),
        ]);

        final down = WaveformDataParser.resamplePeak(const [
          0.1,
          double.nan,
          0.2,
          1.5,
          0.1,
          -0.5,
          0.4,
          0.3,
        ], 4);
        expect(down.length, 4);
        expect(down[0], closeTo(0.1, 1e-6));
        expect(down[1], closeTo(1.0, 1e-6));
        expect(down[2], closeTo(0.1, 1e-6));
        expect(down[3], closeTo(0.4, 1e-6));
      },
    );

    test('extractMirroredRadial enforces bilateral symmetry', () {
      final c = WaveformController(maxBarsPerSecond: 20, attack: 1, release: 1)
        ..active = true;
      expect(WaveformDataParser.extractMirroredRadial(c, 8), List.filled(8, 0));

      for (final v in [0.1, 0.3, 0.6, 0.9]) {
        c.addNormalized(v);
        c.advance(_ms(100));
      }
      final mirrored = WaveformDataParser.extractMirroredRadial(
        c,
        8,
        mirror: true,
      );
      expect(mirrored.length, 8);
      for (var i = 0; i < 4; i++) {
        expect(mirrored[i], closeTo(mirrored[7 - i], 1e-6));
      }
      final unmirrored = WaveformDataParser.extractMirroredRadial(
        c,
        4,
        mirror: false,
      );
      expect(unmirrored, [
        closeTo(0.9, 1e-6),
        closeTo(0.6, 1e-6),
        closeTo(0.3, 1e-6),
        closeTo(0.1, 1e-6),
      ]);
      c.dispose();
    });

    test('extractFrequencyBands synthesizes bounded multi-band energy', () {
      final c = WaveformController(maxBarsPerSecond: 20, attack: 1, release: 1)
        ..active = true;
      expect(
        WaveformDataParser.extractFrequencyBands(c, 12),
        List.filled(12, 0.0),
      );

      for (var i = 0; i < 12; i++) {
        c.addNormalized(i.isEven ? 0.75 : 0.25);
        c.advance(_ms(80));
      }
      final bands = WaveformDataParser.extractFrequencyBands(c, 12);
      expect(bands.length, 12);
      expect(bands.every((b) => b >= 0.0 && b <= 1.0), isTrue);
      expect(bands.any((b) => b > 0.2), isTrue);
      c.dispose();
    });

    test('parseVuSegments quantizes levels and zones accurately', () {
      final idle = WaveformDataParser.parseVuSegments(
        level: 0.0,
        peakHold: 0.0,
        segments: 10,
      );
      expect(idle.activeSegments, 0);
      expect(idle.peakSegment, isNull);

      final mid = WaveformDataParser.parseVuSegments(
        level: 0.5,
        peakHold: 0.9,
        segments: 10,
        warningRatio: 0.6,
        dangerRatio: 0.8,
      );
      expect(mid.activeSegments, 5);
      expect(mid.peakSegment, 8);
      expect(mid.zoneOf(0), VuZone.normal);
      expect(mid.zoneOf(5), VuZone.normal);
      expect(mid.zoneOf(6), VuZone.warning);
      expect(mid.zoneOf(7), VuZone.warning);
      expect(mid.zoneOf(8), VuZone.danger);
      expect(mid.zoneOf(9), VuZone.danger);
    });

    test('computeClosedSplineSegments generates C1 continuous closed loop', () {
      expect(
        WaveformDataParser.computeClosedSplineSegments(const [
          10,
          10,
        ], Offset.zero),
        isEmpty,
      );
      final segments = WaveformDataParser.computeClosedSplineSegments(
        List<double>.filled(8, 50.0),
        const Offset(100, 100),
      );
      expect(segments.length, 8);
      for (var i = 0; i < segments.length; i++) {
        final curr = segments[i];
        final next = segments[(i + 1) % segments.length];
        expect((curr.p1 - next.p0).distance, lessThan(1e-6));
        expect(
          (curr.p0 - const Offset(100, 100)).distance,
          closeTo(50.0, 1e-4),
        );
      }
    });

    test('computeSpectrogramGrid, computeHelixNodes, computePetalRadii', () {
      final c = WaveformController(maxBarsPerSecond: 20, attack: 1, release: 1)
        ..active = true;

      expect(
        WaveformDataParser.computeSpectrogramGrid(c, columns: 0, bands: 4),
        isEmpty,
      );
      final emptyGrid = WaveformDataParser.computeSpectrogramGrid(
        c,
        columns: 6,
        bands: 4,
      );
      expect(emptyGrid.length, 6);
      expect(emptyGrid.first, [0, 0, 0, 0]);

      for (final v in [0.2, 0.9, 0.4, 0.7]) {
        c.addNormalized(v);
        c.advance(_ms(80));
      }

      final grid = WaveformDataParser.computeSpectrogramGrid(
        c,
        columns: 6,
        bands: 4,
      );
      expect(grid.length, 6);
      expect(grid.first.length, 4);
      expect(
        grid.expand((col) => col).every((v) => v >= 0.0 && v <= 1.0),
        isTrue,
      );
      expect(grid.first.any((v) => v > 0.1), isTrue);

      final helix = WaveformDataParser.computeHelixNodes(c, nodeCount: 12);
      expect(helix.length, 12);
      for (final node in helix) {
        expect(node.progress, inInclusiveRange(0.0, 1.0));
        expect(node.yOffsetA, closeTo(-node.yOffsetB, 1e-6));
        expect(node.depthA, closeTo(-node.depthB, 1e-6));
        expect(node.amplitude, inInclusiveRange(0.0, 1.0));
      }

      final petals = WaveformDataParser.computePetalRadii(c, petalCount: 8);
      expect(petals.length, 8);
      expect(petals.first, closeTo(petals.last, 1e-6));
      c.dispose();
    });

    test(
      'parsePrecisionMeter, computePendulumAngles, computePolygonVertices, '
      'computeKineticLouvers, computeOrbitalNodes, computeOscilloscopeTrace',
      () {
        final c = WaveformController(
          maxBarsPerSecond: 20,
          attack: 1,
          release: 1,
        )..active = true;

        final silentMeter = WaveformDataParser.parsePrecisionMeter(c);
        expect(silentMeter.instantaneous, 0.0);
        expect(silentMeter.isClipping, isFalse);

        c.addNormalized(0.95);
        c.advance(_ms(80));
        final hotMeter = WaveformDataParser.parsePrecisionMeter(c);
        expect(hotMeter.instantaneous, closeTo(0.95, 1e-6));
        expect(hotMeter.isClipping, isTrue);
        expect(hotMeter.estimatedDb, greaterThan(-5.0));

        final angles = WaveformDataParser.computePendulumAngles(
          c,
          count: 10,
          maxAngleRadians: 0.6,
        );
        expect(angles.length, 10);
        expect(angles.every((a) => a.abs() <= 0.6 + 1e-6), isTrue);

        final poly = WaveformDataParser.computePolygonVertices(
          const Offset(50, 50),
          30,
          6,
          vertexScales: const [1, 1, 1, 1, 1, 1],
        );
        expect(poly.length, 6);
        for (final pt in poly) {
          expect((pt - const Offset(50, 50)).distance, closeTo(30.0, 1e-4));
        }

        final louvers = WaveformDataParser.computeKineticLouvers(
          c,
          slatCount: 16,
        );
        expect(louvers.length, 16);
        expect(
          louvers.every(
            (s) =>
                s.heightFactor >= 0.18 &&
                s.heightFactor <= 1.0 &&
                s.tiltRadians.abs() <= 0.52 + 1e-6,
          ),
          isTrue,
        );

        final nodes = WaveformDataParser.computeOrbitalNodes(
          c,
          nodeCount: 12,
          orbitCount: 3,
        );
        expect(nodes.length, 12);
        expect(
          nodes.every(
            (n) =>
                n.position.dx.abs() <= 1.0 &&
                n.position.dy.abs() <= 1.0 &&
                n.orbitIndex >= 0 &&
                n.orbitIndex < 3,
          ),
          isTrue,
        );

        final trace = WaveformDataParser.computeOscilloscopeTrace(
          c,
          pointCount: 64,
        );
        expect(trace.length, 64);
        expect(trace.every((y) => y >= -1.0 && y <= 1.0), isTrue);
        expect(trace.first, closeTo(0.0, 1e-6));
        expect(trace.last, closeTo(0.0, 1e-6));

        c.dispose();
      },
    );
  });

  group('AudioWaveform', () {
    testWidgets('renders flat dots when idle, without a running ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AudioWaveform(active: false)));
      await tester.pump();
      expect(find.byType(AudioWaveform), findsOneWidget);
      expect(find.bySemanticsLabel('Waveform'), findsOneWidget);
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
                  colors: [Color(0xFF2196F3), Color(0xFF9C27B0)],
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

  group('16 Custom Recording Visualizers + RecordingVisualizer', () {
    testWidgets(
      'all 16 custom visualizers render idle state without scheduling frames',
      (tester) async {
        final idleWidgets = <Widget>[
          const PulseRingVisualizer(active: false),
          const HarmonicWaveVisualizer(active: false),
          const RadialSpectrumVisualizer(active: false),
          const SegmentedVuVisualizer(active: false),
          const ParticleMatrixVisualizer(active: false),
          const LiquidOrbVisualizer(active: false),
          const SpectrogramHeatmapVisualizer(active: false),
          const HelixDnaVisualizer(active: false),
          const AcousticPetalVisualizer(active: false),
          const PrecisionMeterVisualizer(active: false),
          const VoicePendulumVisualizer(active: false),
          const MorphingPolygonVisualizer(active: false),
          const KineticLouverVisualizer(active: false),
          const OrbitConstellationVisualizer(active: false),
          const SymmetricRibbonVisualizer(active: false),
          const OscilloscopeTraceVisualizer(active: false),
        ];

        for (final widget in idleWidgets) {
          await tester.pumpWidget(_host(widget));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(tester.binding.hasScheduledFrame, isFalse);
        }
      },
    );

    testWidgets(
      'all 16 custom visualizers animate and paint live dBFS stream data cleanly',
      (tester) async {
        const gradient = LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
        );
        final controller = WaveformController(maxBarsPerSecond: 25)
          ..active = true;

        final activeWidgets = <Widget>[
          PulseRingVisualizer(
            controller: controller,
            gradient: gradient,
            ringCount: 4,
          ),
          HarmonicWaveVisualizer(
            controller: controller,
            gradient: gradient,
            waveCount: 5,
          ),
          RadialSpectrumVisualizer(
            controller: controller,
            gradient: gradient,
            spokeCount: 40,
          ),
          SegmentedVuVisualizer(
            controller: controller,
            bandCount: 14,
            segmentCount: 12,
          ),
          ParticleMatrixVisualizer(
            controller: controller,
            gradient: gradient,
            columns: 24,
            rows: 5,
          ),
          LiquidOrbVisualizer(
            controller: controller,
            gradient: gradient,
            lobeCount: 10,
            layerCount: 3,
          ),
          LiquidOrbVisualizer(controller: controller, strokeOnly: true),
          SpectrogramHeatmapVisualizer(
            controller: controller,
            columns: 20,
            bands: 6,
          ),
          HelixDnaVisualizer(controller: controller, nodeCount: 20),
          AcousticPetalVisualizer(
            controller: controller,
            gradient: gradient,
            petalCount: 10,
          ),
          PrecisionMeterVisualizer(controller: controller, gradient: gradient),
          VoicePendulumVisualizer(
            controller: controller,
            gradient: gradient,
            pendulumCount: 12,
          ),
          MorphingPolygonVisualizer(
            controller: controller,
            gradient: gradient,
            sides: 6,
            layerCount: 4,
          ),
          KineticLouverVisualizer(
            controller: controller,
            gradient: gradient,
            slatCount: 24,
          ),
          OrbitConstellationVisualizer(
            controller: controller,
            gradient: gradient,
            nodeCount: 14,
            orbitCount: 3,
          ),
          SymmetricRibbonVisualizer(
            controller: controller,
            gradient: gradient,
            facetCount: 20,
            echoLayers: 3,
          ),
          OscilloscopeTraceVisualizer(
            controller: controller,
            gradient: gradient,
            pointCount: 64,
          ),
        ];

        for (final widget in activeWidgets) {
          for (final dir in TextDirection.values) {
            await tester.pumpWidget(_host(widget, dir: dir));
            for (final db in [-45.0, -25.0, -6.0, -1.0, -35.0]) {
              controller.addDb(db);
              await tester.pump(const Duration(milliseconds: 50));
            }
            expect(tester.takeException(), isNull);
          }
        }

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets('RecordingVisualizer switches across all 17 preset types', (
      tester,
    ) async {
      expect(RecordingVisualizerType.values.length, 17);
      final controller = WaveformController(maxBarsPerSecond: 20)
        ..active = true;
      controller.addDb(-8);
      controller.advance(_ms(80));

      for (final type in RecordingVisualizerType.values) {
        await tester.pumpWidget(
          _host(
            RecordingVisualizer(type: type, controller: controller, height: 80),
          ),
        );
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('new visualizers track recorder lifecycle and stream swap', (
      tester,
    ) async {
      final a = StreamController<double>.broadcast();
      final b = StreamController<double>.broadcast();
      await tester.pumpWidget(_host(PulseRingVisualizer(levels: a.stream)));
      expect(a.hasListener, isTrue);
      await tester.pumpWidget(_host(PulseRingVisualizer(levels: b.stream)));
      expect(a.hasListener, isFalse);
      expect(b.hasListener, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(b.hasListener, isFalse);
      await a.close();
      await b.close();
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                AudioWaveform(active: false),
                PulseRingVisualizer(active: false),
                HarmonicWaveVisualizer(active: false),
                RadialSpectrumVisualizer(active: false),
                SegmentedVuVisualizer(active: false),
                ParticleMatrixVisualizer(active: false),
                LiquidOrbVisualizer(active: false),
                SpectrogramHeatmapVisualizer(active: false),
                HelixDnaVisualizer(active: false),
                AcousticPetalVisualizer(active: false),
                PrecisionMeterVisualizer(active: false),
                VoicePendulumVisualizer(active: false),
                MorphingPolygonVisualizer(active: false),
                KineticLouverVisualizer(active: false),
                OrbitConstellationVisualizer(active: false),
                SymmetricRibbonVisualizer(active: false),
                OscilloscopeTraceVisualizer(active: false),
                StaticWaveform(levels: [0.2, 0.8], progress: 0.5),
              ],
            ),
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
