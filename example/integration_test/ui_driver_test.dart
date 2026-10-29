// UI driver test for the example app. Run with either:
//   flutter test integration_test/ui_driver_test.dart -d windows|linux|macos
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/ui_driver_test.dart -d windows|linux|macos
//
// 示例应用的 UI 驱动测试。可用上面两种方式运行。
//
// Note: AudioWaveform schedules a repeating ticker, so this test never uses
// pumpAndSettle (it would hang). Prefer fixed pumps instead.
// 注意：AudioWaveform 有重复 ticker，本测试不用 pumpAndSettle（会挂起），改用定时 pump。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';
import 'package:xue_hua_audio_example/main.dart';

Finder keyOf(String name) => find.byKey(ValueKey<String>(name));

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _waitForText(
  WidgetTester tester,
  String text, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.text(text).evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<bool> _waitForKey(
  WidgetTester tester,
  String name, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (keyOf(name).evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example UI: asset play, pause, stop, record, waveform styles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Prime TCC / microphone before the example UI touches it.
    // 先在进 UI 前打通麦克风权限，避免系统弹窗卡住 hasPermission。
    final primer = AudioRecorder();
    try {
      final ok = await primer.hasPermission();
      expect(ok, isTrue, reason: 'microphone permission not granted for UI test');
    } finally {
      await primer.dispose();
    }

    await tester.pumpWidget(const ExampleApp());
    await _pumpFor(tester, const Duration(milliseconds: 800));

    expect(find.text('播放器 Player'), findsOneWidget);
    expect(find.text('录音机 Recorder'), findsOneWidget);
    expect(keyOf('live-waveform'), findsOneWidget);

    // Record first so the mic session is claimed before AVPlayer playback.
    // 先录音，避免 AVPlayer 占用仅播放会话后录音启动卡住。
    await tester.ensureVisible(keyOf('rec-start'));
    await tester.tap(keyOf('rec-start'));
    var enteredRecording = await _waitForText(
      tester,
      'recording',
      timeout: const Duration(seconds: 15),
    );
    if (!enteredRecording) {
      await tester.tap(keyOf('rec-start'));
      enteredRecording = await _waitForText(
        tester,
        'recording',
        timeout: const Duration(seconds: 15),
      );
    }
    if (!enteredRecording) {
      final chips = find.byType(Chip);
      final labels = <String>[];
      for (final e in chips.evaluate()) {
        final chip = e.widget as Chip;
        final label = chip.label;
        if (label is Text && label.data != null) labels.add(label.data!);
      }
      final err = find.textContaining('AudioError');
      final denied = find.textContaining('permission');
      final errZh = find.textContaining('麦克风');
      final hint = err.evaluate().isNotEmpty
          ? ' error visible'
          : (denied.evaluate().isNotEmpty || errZh.evaluate().isNotEmpty
              ? ' permission/mic error visible'
              : ' chips=$labels');
      fail('recorder did not enter recording;$hint');
    }

    await tester.tap(find.text('Line'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Filled'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Bars'));
    await _pumpFor(tester, const Duration(milliseconds: 300));

    // Cycle through the 6 new recording visualizer components & gallery view.
    // 依次切换 6 个新增录音可视化组件及全景预览模式。
    for (final visKey in [
      'vis-pulseRing',
      'vis-harmonicWave',
      'vis-radialSpectrum',
      'vis-segmentedVu',
      'vis-particleMatrix',
      'vis-liquidOrb',
      'vis-waveform',
    ]) {
      await tester.ensureVisible(keyOf(visKey));
      await tester.tap(keyOf(visKey));
      await _pumpFor(tester, const Duration(milliseconds: 200));
    }
    await tester.ensureVisible(keyOf('toggle-visualizer-gallery'));
    await tester.tap(keyOf('toggle-visualizer-gallery'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    expect(keyOf('visualizer-gallery-grid'), findsOneWidget);
    await tester.tap(keyOf('toggle-visualizer-gallery'));
    await _pumpFor(tester, const Duration(milliseconds: 200));

    try {
      final bytes = await binding.takeScreenshot('ui_recording_bars');
      expect(bytes, isNotEmpty);
    } catch (_) {
      // Screenshots are optional on some embeds.
    }

    await tester.tap(keyOf('rec-pause-resume'));
    expect(
      await _waitForText(tester, 'paused'),
      isTrue,
      reason: 'recorder pause failed',
    );
    await tester.tap(keyOf('rec-pause-resume'));
    expect(
      await _waitForText(tester, 'recording'),
      isTrue,
      reason: 'recorder resume failed',
    );

    await tester.tap(keyOf('rec-stop'));
    expect(
      await _waitForKey(tester, 'rec-play'),
      isTrue,
      reason: 'play-recording button missing after stop',
    );

    await tester.tap(keyOf('rec-play'));
    await _pumpFor(tester, const Duration(milliseconds: 800));

    // Cancel path. / 取消路径。
    await tester.ensureVisible(keyOf('rec-start'));
    await tester.tap(keyOf('rec-start'));
    expect(await _waitForText(tester, 'recording'), isTrue);
    await tester.tap(keyOf('rec-cancel'));
    await _pumpFor(tester, const Duration(milliseconds: 800));

    await tester.tap(keyOf('rec-start'));
    expect(
      await _waitForText(tester, 'recording'),
      isTrue,
      reason: 'could not start again after cancel',
    );
    await tester.tap(keyOf('rec-cancel'));
    await _pumpFor(tester, const Duration(milliseconds: 800));

    // Playback after recording. / 录音后再测播放。
    final assetKey = 'asset-assets/audio/message_ring.wav';
    await tester.ensureVisible(keyOf(assetKey));
    await tester.tap(keyOf(assetKey));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    final leftIdle = await _waitForText(tester, 'playing') ||
        await _waitForText(tester, 'completed', timeout: const Duration(seconds: 2)) ||
        await _waitForText(tester, 'paused', timeout: const Duration(seconds: 1));
    expect(leftIdle, isTrue, reason: 'player never left idle after asset tap');

    if (find.text('playing').evaluate().isNotEmpty) {
      await tester.tap(keyOf('player-play-pause'));
      await _pumpFor(tester, const Duration(milliseconds: 500));
      expect(
        await _waitForText(tester, 'paused'),
        isTrue,
        reason: 'pause did not take effect',
      );
      await tester.tap(keyOf('player-play-pause'));
      await _pumpFor(tester, const Duration(milliseconds: 500));
    }

    await tester.tap(keyOf('player-stop'));
    await _pumpFor(tester, const Duration(milliseconds: 500));

    expect(find.textContaining('Output device'), findsOneWidget);
    expect(find.textContaining('Input device'), findsOneWidget);
  });
}
