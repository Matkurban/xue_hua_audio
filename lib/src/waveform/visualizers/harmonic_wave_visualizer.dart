import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';

/// A fluid multi-ribbon harmonic wave visualizer inspired by minimalist AI
/// voice interfaces.
///
/// 多层丝绸流体谐波可视化组件：多条相位交错的谐波正弦曲线在两端平滑收敛于中线，
/// 中部随实时语音包络与瞬态能量丝滑起伏。
class HarmonicWaveVisualizer extends RecordingVisualizerBase {
  /// Creates a harmonic wave visualizer. / 创建多层丝绸流体谐波组件。
  const HarmonicWaveVisualizer({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 72,
    super.minDb,
    super.maxDb,
    super.semanticLabel,
    this.waveCount = 4,
    this.strokeWidth = 2.2,
    this.fillPrimary = true,
    this.speed = 1.0,
  }) : assert(waveCount >= 1 && waveCount <= 8),
       assert(strokeWidth > 0),
       assert(speed > 0);

  /// Number of harmonic ribbon layers (`1..8`). / 谐波曲线层数（`1..8`）。
  final int waveCount;

  /// Primary ribbon stroke width. / 主谐波线宽。
  final double strokeWidth;

  /// Whether to fill the mirrored silhouette of the primary wave with a soft
  /// translucent glow.
  /// 是否为主谐波填充半透明镜像柔光面积。
  final bool fillPrimary;

  /// Phase animation speed multiplier. / 相位流动速度倍率。
  final double speed;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording harmonic wave' : 'Harmonic wave visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _HarmonicWavePainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    waveCount: waveCount,
    strokeWidth: strokeWidth,
    fillPrimary: fillPrimary,
    speed: speed,
  );
}

class _HarmonicWavePainter extends CustomPainter {
  _HarmonicWavePainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.waveCount,
    required this.strokeWidth,
    required this.fillPrimary,
    required this.speed,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int waveCount;
  final double strokeWidth;
  final bool fillPrimary;
  final double speed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final midY = size.height / 2;
    final maxAmp = size.height * 0.44;
    final metrics = controller.computeMetrics(window: 24);
    final rect = Offset.zero & size;

    // Baseline horizon when completely idle and silent.
    // 完全静息时显示极简水平基准线。
    if (metrics.isSilent && !controller.active) {
      final idlePaint = Paint()
        ..isAntiAlias = true
        ..color = inactiveColor
        ..strokeWidth = math.min(2.0, strokeWidth)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), idlePaint);
      return;
    }

    final energy =
        (metrics.current * 0.55 + metrics.rms * 0.35 + metrics.flux * 0.25)
            .clamp(0.0, 1.0);
    final effectiveAmp = math.max(
      strokeWidth,
      maxAmp * (controller.active ? math.max(0.04, energy) : energy),
    );
    final t = controller.elapsedSeconds * speed;
    final steps = math.max(32, (size.width / 4).round().clamp(32, 140));

    for (var w = waveCount - 1; w >= 0; w--) {
      final isPrimary = w == 0;
      final layerRatio = 1.0 - (w / math.max(1, waveCount)) * 0.62;
      final freq = 1.5 + w * 0.65;
      final phase = t * (3.2 + w * 0.85) + w * 1.15;
      final path = Path();
      final mirrorPath = fillPrimary && isPrimary ? Path() : null;

      for (var s = 0; s <= steps; s++) {
        final normX = s / steps;
        final x = normX * size.width;
        // Raised-cosine bell window: 0 at both ends, 1 in the center.
        // 升余弦钟形窗函数：两端平滑归零，中心达到峰值。
        final bell = math.pow(math.sin(normX * math.pi), 1.6).toDouble();
        final histSample = controller.sampleInterpolated((1.0 - normX) * 12.0);
        final localBoost = 0.65 + 0.35 * histSample;
        final waveVal = math.sin(normX * math.pi * 2 * freq - phase);
        final dy = waveVal * effectiveAmp * layerRatio * bell * localBoost;
        final y = midY + dy;
        if (s == 0) {
          path.moveTo(x, y);
          mirrorPath?.moveTo(x, midY - dy * 0.75);
        } else {
          path.lineTo(x, y);
          mirrorPath?.lineTo(x, midY - dy * 0.75);
        }
      }

      if (mirrorPath != null) {
        final fillArea = Path.from(path);
        for (var s = steps; s >= 0; s--) {
          final normX = s / steps;
          final x = normX * size.width;
          final bell = math.pow(math.sin(normX * math.pi), 1.6).toDouble();
          final histSample = controller.sampleInterpolated(
            (1.0 - normX) * 12.0,
          );
          final localBoost = 0.65 + 0.35 * histSample;
          final waveVal = math.sin(normX * math.pi * 2 * freq - phase);
          final dy = waveVal * effectiveAmp * layerRatio * bell * localBoost;
          fillArea.lineTo(x, midY - dy * 0.75);
        }
        fillArea.close();
        final fillPaint = createActivePaint(
          color.withValues(alpha: 0.16),
          gradient,
          rect,
        )..style = PaintingStyle.fill;
        if (gradient != null) {
          fillPaint.color = const Color(0x29FFFFFF);
        }
        canvas.drawPath(fillArea, fillPaint);
      }

      final alpha = isPrimary
          ? 0.95
          : (0.65 * (1.0 - w / (waveCount + 0.5))).clamp(0.15, 0.75);
      final ribbonPaint =
          createActivePaint(
              color.withValues(alpha: alpha),
              isPrimary ? gradient : null,
              rect,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = isPrimary
                ? strokeWidth
                : math.max(1.0, strokeWidth * 0.65)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, ribbonPaint);
    }
  }

  @override
  bool shouldRepaint(_HarmonicWavePainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.waveCount != waveCount ||
      old.strokeWidth != strokeWidth ||
      old.fillPrimary != fillPrimary ||
      old.speed != speed;
}
