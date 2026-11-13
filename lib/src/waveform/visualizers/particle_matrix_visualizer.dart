import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';

/// A minimalist kinetic dot-matrix visualizer where rows of micro-spheres
/// expand vertically and scale in luminance and radius with the rolling
/// acoustic wave.
///
/// 声场律动点阵星云组件：多行微粒圆点随滚动声波在垂直方向对称舒展，且粒径与
/// 透明度随局部振幅动态缩放；静音时收敛为极简点阵地平线。
class ParticleMatrixVisualizer extends RecordingVisualizerBase {
  /// Creates a particle matrix visualizer. / 创建声场律动点阵星云组件。
  const ParticleMatrixVisualizer({
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
    this.columns = 28,
    this.rows = 5,
    this.maxDotRadius = 3.2,
    this.minDotRadius = 1.25,
    this.fadeEdges = true,
    this.textDirection,
  }) : assert(columns >= 4 && columns <= 96),
       assert(rows >= 1 && rows <= 15),
       assert(maxDotRadius >= minDotRadius && minDotRadius > 0);

  /// Number of horizontal particle columns (`4..96`).
  /// 水平方向粒子列数（`4..96`）。
  final int columns;

  /// Number of vertical harmonic particle rows (`1..15`, odd numbers include
  /// a center horizon row).
  /// 垂直方向粒子行数（`1..15`）。
  final int rows;

  /// Maximum radius of an excited particle dot. / 满振幅时的最大粒子半径。
  final double maxDotRadius;

  /// Minimum radius of an idle particle dot. / 静息时的最小粒子半径。
  final double minDotRadius;

  /// Whether to softly fade particle opacity near the left and right edges.
  /// 是否在左右边缘平滑渐隐。
  final bool fadeEdges;

  /// Overrides the horizontal flow direction. / 覆盖水平滚动方向。
  final TextDirection? textDirection;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording particle matrix' : 'Particle matrix visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection ambientDirection,
  ) => _ParticleMatrixPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    columns: columns,
    rows: rows,
    maxDotRadius: maxDotRadius,
    minDotRadius: minDotRadius,
    fadeEdges: fadeEdges,
    rtl: (textDirection ?? ambientDirection) == TextDirection.rtl,
  );
}

class _ParticleMatrixPainter extends CustomPainter {
  _ParticleMatrixPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.columns,
    required this.rows,
    required this.maxDotRadius,
    required this.minDotRadius,
    required this.fadeEdges,
    required this.rtl,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int columns;
  final int rows;
  final double maxDotRadius;
  final double minDotRadius;
  final bool fadeEdges;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final midY = size.height / 2;
    final maxSpread = (size.height / 2) - maxDotRadius - 1;
    final colStep = size.width / columns;
    final shift = controller.active ? controller.phase : 0.0;
    final t = controller.elapsedSeconds;

    for (var c = 0; c < columns; c++) {
      // Slot 0 is on the newest end side. / 槽位 0 位于最新采样进入的一端。
      final rawX = (c + 0.5) * colStep;
      final x = rtl ? rawX : size.width - rawX;
      final v = controller.sampleInterpolated(c + shift).clamp(0.0, 1.0);
      final edgeFactor = fadeEdges
          ? math.sin(((c + 0.5) / columns) * math.pi).clamp(0.15, 1.0)
          : 1.0;

      for (var r = 0; r < rows; r++) {
        // Normalized vertical offset in [-1, 1]; 0 is the center row.
        // 归一化垂直偏移 [-1, 1]，0 为中心行。
        final rowNorm = rows == 1 ? 0.0 : (r / (rows - 1)) * 2.0 - 1.0;
        final distFromCenter = rowNorm.abs();
        final waveJitter = controller.active && v > 0.004
            ? 0.06 * v * math.sin(t * 5.0 + c * 0.45 + r)
            : 0.0;
        final restSpread = 0.14 * maxSpread * rowNorm;
        final activeSpread =
            maxSpread * rowNorm * (0.18 + 0.82 * v + waveJitter);
        final y = midY + (v > 0.004 ? activeSpread : restSpread);

        final layerScale = 1.0 - 0.38 * distFromCenter;
        final dotR =
            (minDotRadius + (maxDotRadius - minDotRadius) * v * layerScale)
                .clamp(minDotRadius * 0.75, maxDotRadius);

        final isActiveDot = v > 0.004;
        final alpha = isActiveDot
            ? ((0.30 + 0.70 * v) * (1.0 - 0.45 * distFromCenter) * edgeFactor)
                  .clamp(0.12, 1.0)
            : ((0.45 - 0.28 * distFromCenter) * edgeFactor).clamp(0.10, 0.55);

        final dotPaint = Paint()
          ..isAntiAlias = true
          ..color = (isActiveDot ? color : inactiveColor).withValues(
            alpha: alpha,
          );
        canvas.drawCircle(Offset(x, y), dotR, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticleMatrixPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.columns != columns ||
      old.rows != rows ||
      old.maxDotRadius != maxDotRadius ||
      old.minDotRadius != minDotRadius ||
      old.fadeEdges != fadeEdges ||
      old.rtl != rtl;
}
