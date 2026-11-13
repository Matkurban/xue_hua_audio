import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';

/// A minimalist concentric pulse-ring visualizer featuring a breathing core
/// orb, expanding acoustic ripple waves, and an optional peak-hold halo arc.
///
/// 极简同心呼吸脉冲声环组件：中心声核随实时语音能量呼吸缩放，向外扩散多层渐隐
/// 声波涟漪，并在外圈绘制平滑衰减的峰值保持弧线。
class PulseRingVisualizer extends RecordingVisualizerBase {
  /// Creates a pulse-ring visualizer. / 创建同心呼吸脉冲声环组件。
  const PulseRingVisualizer({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 88,
    super.minDb,
    super.maxDb,
    super.semanticLabel,
    this.ringCount = 3,
    this.minRadiusRatio = 0.20,
    this.showPeakArc = true,
  }) : assert(ringCount >= 1 && ringCount <= 8),
       assert(minRadiusRatio > 0.05 && minRadiusRatio < 0.8);

  /// Number of expanding ripple rings (`1..8`). / 扩散脉冲环层数（`1..8`）。
  final int ringCount;

  /// Resting core radius as a fraction of the half-shortest-side.
  /// 静息状态下中心圆半径占半短边的比例。
  final double minRadiusRatio;

  /// Whether to render the outer peak-hold halo arc.
  /// 是否绘制外圈峰值保持弧线。
  final bool showPeakArc;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording pulse ring' : 'Pulse ring visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _PulseRingPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    ringCount: ringCount,
    minRadiusRatio: minRadiusRatio,
    showPeakArc: showPeakArc,
  );
}

class _PulseRingPainter extends CustomPainter {
  _PulseRingPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.ringCount,
    required this.minRadiusRatio,
    required this.showPeakArc,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int ringCount;
  final double minRadiusRatio;
  final bool showPeakArc;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 2) return;
    final center = Offset(size.width / 2, size.height / 2);
    final metrics = controller.computeMetrics(window: 20);
    final baseR = maxR * minRadiusRatio;
    final energy = metrics.current * 0.65 + metrics.rms * 0.35;

    // Subtle outer guide track. / 极简外圈基准轨道。
    final trackPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = inactiveColor.withValues(alpha: 0.35);
    canvas.drawCircle(center, maxR * 0.92, trackPaint);

    // Expanding concentric ripple rings. / 向外扩散的同心声波涟漪环。
    final t = controller.elapsedSeconds;
    for (var i = 0; i < ringCount; i++) {
      final rawPhase = controller.active
          ? (t * 0.65 + i / ringCount) % 1.0
          : (i + 1) / (ringCount + 1);
      final ringR =
          baseR + (maxR * 0.88 - baseR) * rawPhase * (0.45 + 0.55 * energy);
      final fade = (1.0 - rawPhase).clamp(0.0, 1.0);
      final alpha = controller.active && !metrics.isSilent
          ? (fade * (0.18 + 0.62 * energy)).clamp(0.0, 1.0)
          : (0.18 * (1.0 - i / (ringCount + 1))).clamp(0.0, 1.0);
      final ringPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + 1.8 * energy * fade
        ..color = (metrics.isSilent ? inactiveColor : color).withValues(
          alpha: alpha,
        );
      canvas.drawCircle(center, ringR, ringPaint);
    }

    // Peak-hold precision arc on the outer track. / 外圈峰值保持指示弧。
    if (showPeakArc && metrics.peakHold > 0.01) {
      final sweep = 2 * math.pi * metrics.peakHold.clamp(0.0, 1.0);
      final arcRect = Rect.fromCircle(center: center, radius: maxR * 0.92);
      final arcPaint = createActivePaint(color, gradient, arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arcPaint);
    }

    // Soft inner glow halo. / 中心柔和声晕。
    final coreR = baseR * (1.0 + 1.15 * energy);
    if (!metrics.isSilent) {
      final glowPaint = Paint()
        ..isAntiAlias = true
        ..color = color.withValues(alpha: (0.16 + 0.24 * energy).clamp(0, 1));
      canvas.drawCircle(center, coreR * 1.35, glowPaint);
    }

    // Breathing central orb. / 呼吸态中心声核。
    final coreRect = Rect.fromCircle(center: center, radius: coreR);
    final corePaint = metrics.isSilent && !controller.active
        ? (Paint()
            ..isAntiAlias = true
            ..color = inactiveColor)
        : createActivePaint(color, gradient, coreRect);
    canvas.drawCircle(center, coreR, corePaint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.ringCount != ringCount ||
      old.minRadiusRatio != minRadiusRatio ||
      old.showPeakArc != showPeakArc;
}
