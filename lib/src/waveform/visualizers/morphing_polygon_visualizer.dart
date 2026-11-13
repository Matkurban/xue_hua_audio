import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// A nested geometric polygon tunnel where concentric polygons radially
/// deform and twist with progressive angular shear in response to voice.
///
/// 多维极简几何多边形声场组件：多层嵌套正多边形随频段能量产生顶点伸展与螺旋剪切
/// 扭转，兼具建筑几何美感与呼吸律动。
class MorphingPolygonVisualizer extends RecordingVisualizerBase {
  /// Creates a morphing polygon visualizer. / 创建多维几何多边形声场组件。
  const MorphingPolygonVisualizer({
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
    this.sides = 6,
    this.layerCount = 4,
  }) : assert(sides >= 3 && sides <= 16),
       assert(layerCount >= 1 && layerCount <= 8);

  /// Number of polygon sides (`3..16`, e.g. 6 = hexagon).
  /// 多边形边数（`3..16`，如 6 为正六边形）。
  final int sides;

  /// Number of concentric nested polygon layers (`1..8`).
  /// 同心嵌套多边形层数（`1..8`）。
  final int layerCount;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording morphing polygon' : 'Morphing polygon visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _MorphingPolygonPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    sides: sides,
    layerCount: layerCount,
  );
}

class _MorphingPolygonPainter extends CustomPainter {
  _MorphingPolygonPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.sides,
    required this.layerCount,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int sides;
  final int layerCount;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 4) return;
    final center = Offset(size.width / 2, size.height / 2);
    final bands = WaveformDataParser.extractFrequencyBands(controller, sides);
    final metrics = controller.computeMetrics(window: 20);
    final isIdle = metrics.isSilent && !controller.active;
    final t = controller.elapsedSeconds;

    for (var l = layerCount - 1; l >= 0; l--) {
      final normLayer = (l + 1) / layerCount;
      final baseR = maxR * 0.20 + (maxR * 0.72) * normLayer;
      final twist = controller.active
          ? t * 0.45 * (l.isEven ? 1 : -1) + l * 0.28 * (0.4 + metrics.rms)
          : l * 0.22;
      final scales = List<double>.generate(
        sides,
        (i) => isIdle ? 1.0 : 0.78 + 0.38 * bands[(i + l) % sides],
      );
      final pts = WaveformDataParser.computePolygonVertices(
        center,
        baseR,
        sides,
        rotation: twist,
        vertexScales: scales,
      );
      if (pts.isEmpty) continue;

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();

      final baseCol = isIdle ? inactiveColor : color;
      final alpha = (0.30 + 0.65 * (1.0 - l / layerCount)).clamp(0.20, 0.95);
      if (l == 0 && !isIdle) {
        canvas.drawPath(
          path,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.fill
            ..color = baseCol.withValues(alpha: 0.16),
        );
      }
      final strokePaint =
          createActivePaint(
              baseCol.withValues(alpha: alpha),
              l == 0 && !isIdle ? gradient : null,
              Rect.fromCircle(center: center, radius: maxR),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = l == 0 ? 2.2 : 1.3
            ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_MorphingPolygonPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.sides != sides ||
      old.layerCount != layerCount;
}
