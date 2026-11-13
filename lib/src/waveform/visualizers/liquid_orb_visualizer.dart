import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// A minimalist morphing liquid acoustic orb built from smooth closed
/// cubic-Bezier splines (`C¹` continuous) that undulate in response to
/// multi-band voice energy.
///
/// 液态几何流体声球组件：由多层平滑闭合的三次贝塞尔样条曲线（`C¹` 连续无尖角）
/// 构成，静息时呈极简几何圆，说话时随多频段人声能量呈现有机流体律动。
class LiquidOrbVisualizer extends RecordingVisualizerBase {
  /// Creates a liquid orb visualizer. / 创建液态几何流体声球组件。
  const LiquidOrbVisualizer({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 96,
    super.minDb,
    super.maxDb,
    super.semanticLabel,
    this.lobeCount = 8,
    this.layerCount = 3,
    this.strokeOnly = false,
  }) : assert(lobeCount >= 4 && lobeCount <= 24),
       assert(layerCount >= 1 && layerCount <= 5);

  /// Number of spline anchor lobes around the perimeter (`4..24`).
  /// 流体球周向控制瓣数量（`4..24`）。
  final int lobeCount;

  /// Number of overlapping translucent orb layers (`1..5`).
  /// 交叠半透明流体层数（`1..5`）。
  final int layerCount;

  /// When true, renders sleek contour outlines instead of filled silhouettes.
  /// 为 true 时仅绘制极简轮廓线，不填充内部。
  final bool strokeOnly;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording liquid orb' : 'Liquid orb visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _LiquidOrbPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    lobeCount: lobeCount,
    layerCount: layerCount,
    strokeOnly: strokeOnly,
  );
}

class _LiquidOrbPainter extends CustomPainter {
  _LiquidOrbPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.lobeCount,
    required this.layerCount,
    required this.strokeOnly,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int lobeCount;
  final int layerCount;
  final bool strokeOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 4) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = maxR * 0.46;
    final maxExcursion = maxR * 0.44;
    final bands = WaveformDataParser.extractFrequencyBands(
      controller,
      lobeCount,
    );
    final metrics = controller.computeMetrics(window: 20);
    final t = controller.elapsedSeconds;
    final orbBounds = Rect.fromCircle(center: center, radius: maxR);

    for (var layer = layerCount - 1; layer >= 0; layer--) {
      final isFront = layer == 0;
      final dir = layer.isEven ? 1.0 : -1.0;
      final rotation = controller.active
          ? t * (0.45 + layer * 0.22) * dir + layer * 0.7
          : layer * 0.5;
      final layerScale = 1.0 - layer * 0.10;

      final radii = List<double>.generate(lobeCount, (i) {
        final bandVal = bands[(i + layer * 2) % lobeCount];
        final harmonic = controller.active
            ? 0.05 * math.sin(t * (3.0 + layer) + i * (2 * math.pi / lobeCount))
            : 0.0;
        final excursion =
            maxExcursion * (bandVal * 0.85 + metrics.rms * 0.15 + harmonic);
        return (baseR + excursion) * layerScale;
      });

      final segments = WaveformDataParser.computeClosedSplineSegments(
        radii,
        center,
        rotation: rotation,
      );
      if (segments.isEmpty) continue;

      final path = Path()..moveTo(segments.first.p0.dx, segments.first.p0.dy);
      for (final seg in segments) {
        path.cubicTo(
          seg.c1.dx,
          seg.c1.dy,
          seg.c2.dx,
          seg.c2.dy,
          seg.p1.dx,
          seg.p1.dy,
        );
      }
      path.close();

      final baseColor = metrics.isSilent && !controller.active
          ? inactiveColor
          : color;
      final alpha = isFront
          ? (strokeOnly ? 0.95 : 0.78)
          : (0.28 + 0.16 * (layerCount - layer) / layerCount).clamp(0.18, 0.55);

      if (!strokeOnly) {
        final fillPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill;
        if (isFront && gradient != null && !metrics.isSilent) {
          fillPaint.shader = gradient!.createShader(orbBounds);
        } else {
          fillPaint.color = baseColor.withValues(alpha: alpha);
        }
        canvas.drawPath(path, fillPaint);
      }

      final strokePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFront ? 2.0 : 1.2
        ..color = baseColor.withValues(alpha: (alpha + 0.18).clamp(0.25, 1.0));
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_LiquidOrbPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.lobeCount != lobeCount ||
      old.layerCount != layerCount ||
      old.strokeOnly != strokeOnly;
}
