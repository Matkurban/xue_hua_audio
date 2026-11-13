import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// A Braun/Nagra-inspired studio precision level bridge displaying a dual-bar
/// ballistic RMS + instantaneous peak meter, tick scale, and clipping lamp.
///
/// 极简录音室精密双轨电桥组件：同时呈现阻尼均方根（RMS）能量条、瞬时峰值条、
/// 精密刻度标尺、悬浮峰值保持线以及过载（Clip）指示灯。
class PrecisionMeterVisualizer extends RecordingVisualizerBase {
  /// Creates a precision studio meter visualizer. / 创建极简录音室精密双轨电桥组件。
  const PrecisionMeterVisualizer({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 68,
    super.minDb,
    super.maxDb,
    super.semanticLabel,
    this.clipColor = const Color(0xFFEF4444),
  });

  /// Color of the peak clipping indicator lamp. / 过载指示灯颜色。
  final Color clipColor;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording precision meter' : 'Precision meter visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _PrecisionMeterPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    clipColor: clipColor,
  );
}

class _PrecisionMeterPainter extends CustomPainter {
  _PrecisionMeterPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.clipColor,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final Color clipColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 12) return;
    final reading = WaveformDataParser.parsePrecisionMeter(controller);
    final padX = 12.0;
    final lampSpace = 22.0;
    final barW = math.max(8.0, size.width - padX * 2 - lampSpace);
    final topBarY = size.height * 0.24;
    final bottomBarY = size.height * 0.64;
    final barH = math.max(4.0, size.height * 0.16);
    final radius = Radius.circular(barH / 2);

    final trackPaint = Paint()
      ..isAntiAlias = true
      ..color = inactiveColor.withValues(alpha: 0.24);

    // 1. Instantaneous Peak track (top) & Ballistic RMS track (bottom).
    // 上轨：瞬时峰值；下轨：阻尼均方根（RMS）。
    final topTrack = Rect.fromLTWH(padX, topBarY, barW, barH);
    final botTrack = Rect.fromLTWH(padX, bottomBarY, barW, barH);
    canvas.drawRRect(RRect.fromRectAndRadius(topTrack, radius), trackPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(botTrack, radius), trackPaint);

    final activePaint = createActivePaint(
      color,
      gradient,
      Rect.fromLTWH(padX, 0, barW, size.height),
    );
    if (reading.instantaneous > 0.004) {
      final w = (barW * reading.instantaneous).clamp(barH, barW);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(padX, topBarY, w, barH), radius),
        activePaint,
      );
    }
    if (reading.ballisticRms > 0.004) {
      final w = (barW * reading.ballisticRms).clamp(barH, barW);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(padX, bottomBarY, w, barH),
          radius,
        ),
        activePaint,
      );
    }

    // Precision tick marks along the middle spine. / 中轴精密刻度线。
    final midY = (topBarY + barH + bottomBarY) / 2;
    final tickPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1.0
      ..color = inactiveColor.withValues(alpha: 0.55);
    const ticks = 10;
    for (var i = 0; i <= ticks; i++) {
      final x = padX + (barW * i / ticks);
      final isMajor = i % 2 == 0;
      final halfTick = isMajor ? 3.0 : 1.6;
      canvas.drawLine(
        Offset(x, midY - halfTick),
        Offset(x, midY + halfTick),
        tickPaint,
      );
    }

    // Floating Peak-Hold cursor line across both tracks. / 跨越双轨的峰值保持游标线。
    if (reading.peakHold > 0.01) {
      final px = padX + (barW * reading.peakHold).clamp(0.0, barW);
      final cursorPaint = Paint()
        ..isAntiAlias = true
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = reading.isClipping ? clipColor : color;
      canvas.drawLine(
        Offset(px, topBarY - 2),
        Offset(px, bottomBarY + barH + 2),
        cursorPaint,
      );
    }

    // Clipping indicator lamp on the right side. / 右侧过载峰值指示灯。
    final lampCenter = Offset(size.width - padX - 4, size.height / 2);
    final lampR = math.min(5.0, size.height * 0.12);
    if (reading.isClipping) {
      canvas.drawCircle(
        lampCenter,
        lampR * 1.8,
        Paint()
          ..isAntiAlias = true
          ..color = clipColor.withValues(alpha: 0.28),
      );
    }
    canvas.drawCircle(
      lampCenter,
      lampR,
      Paint()
        ..isAntiAlias = true
        ..color = reading.isClipping
            ? clipColor
            : inactiveColor.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_PrecisionMeterPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.clipColor != clipColor;
}
