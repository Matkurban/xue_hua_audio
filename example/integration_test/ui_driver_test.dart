// UI driver test for the example app. Run with either:
//   flutter test integration_test/ui_driver_test.dart -d linux
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/ui_driver_test.dart -d linux
//
// 示例应用的 UI 驱动测试。可用上面两种方式运行。
//
// Note: AudioWaveform schedules a repeating ticker, so this test never uses
// pumpAndSettle (it would hang). Prefer fixed pumps instead.
// 注意：AudioWaveform 有重复 ticker，本测试不用 pumpAndSettle（会挂起），改用定时 pump。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

    await tester.pumpWidget(const ExampleApp());
    await _pumpFor(tester, const Duration(milliseconds: 800));

    expect(find.text('播放器 Player'), findsOneWidget);
    expect(find.text('录音机 Recorder'), findsOneWidget);
    expect(keyOf('live-waveform'), findsOneWidget);

    // Load a short asset. / 加载短 asset。
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

    // Record + live waveform styles. / 录音 + 实时波形样式。
    await tester.ensureVisible(keyOf('rec-start'));
    await tester.tap(keyOf('rec-start'));
    expect(
      await _waitForText(tester, 'recording'),
      isTrue,
      reason: 'recorder did not enter recording',
    );

    await tester.tap(find.text('Line'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Filled'));
    await _pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.text('Bars'));
    await _pumpFor(tester, const Duration(milliseconds: 300));

    // Take a screenshot while recording (flutter_driver / integration_test).
    // 录音中截图。
    try {
      final bytes = await binding.takeScreenshot('ui_recording_bars');
      expect(bytes, isNotEmpty);
    } catch (_) {
      // Screenshots are optional on some Linux embeds.
      // 部分 Linux 嵌入环境不支持截图。
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

    // After cancel, starting again must work (proves the button is enabled).
    // 取消后再次开始必须成功（证明按钮已重新启用）。
    await tester.tap(keyOf('rec-start'));
    expect(
      await _waitForText(tester, 'recording'),
      isTrue,
      reason: 'could not start again after cancel',
    );
    await tester.tap(keyOf('rec-cancel'));
    await _pumpFor(tester, const Duration(milliseconds: 800));

    expect(find.textContaining('Output device'), findsOneWidget);
    expect(find.textContaining('Input device'), findsOneWidget);
  });
}
