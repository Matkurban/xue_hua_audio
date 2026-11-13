import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// A geometric lotus/mandala visualizer where translucent radial petals bloom
/// outward and counter-rotate in response to voice harmonics.
///
/// 几何声学花瓣曼陀罗组件：多层半透明几何花瓣围绕中心对称排布，随多频段人声能量
/// 向外舒展绽放并产生微幅反向旋转。
class AcousticPetalVisualizer extends RecordingVisualizerBase {
  /// Creates an acoustic petal visualizer. / 创建几何声学花瓣曼陀罗组件。
  const AcousticPetalVisualizer({
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
    this.petalCount = 8,
  }) : assert(petalCount >= 4 && petalCount <= 20);

  /// Number of radial petals (`4..20`). / 径向花瓣数量（`4..20`）。
  final int petalCount;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording acoustic petals' : 'Acoustic petal visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _AcousticPetalPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    petalCount: petalCount,
  );
}

class _AcousticPetalPainter extends CustomPainter {
  _AcousticPetalPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.petalCount,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int petalCount;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 4) return;
    final center = Offset(size.width / 2, size.height / 2);
    final petalRatios = WaveformDataParser.computePetalRadii(
      controller,
      petalCount: petalCount,
    );
    final metrics = controller.computeMetrics(window: 16);
    final isIdle = metrics.isSilent && !controller.active;
    final t = controller.elapsedSeconds;

    for (var layer = 1; layer >= 0; layer--) {
      final isOuter = layer == 1;
      final rot = controller.active
          ? t * (isOuter ? -0.25 : 0.35) + layer * (math.pi / petalCount)
          : layer * (math.pi / petalCount);
      final scale = isOuter ? 0.82 : 1.0;

      for (var i = 0; i < petalCount; i++) {
        final v = petalRatios[i];
        final angle = rot + (i * 2 * math.pi / petalCount);
        final innerR = maxR * 0.14;
        final tipR = maxR * (0.34 + 0.58 * (isIdle ? 0.08 : v)) * scale;
        final spreadAngle = (math.pi / petalCount) * (0.65 + 0.35 * v);

        final pStart = Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        );
        final pTip = Offset(
          center.dx + tipR * math.cos(angle),
          center.dy + tipR * math.sin(angle),
        );
        final ctrlR = innerR + (tipR - innerR) * 0.62;
        final cLeft = Offset(
          center.dx + ctrlR * math.cos(angle - spreadAngle),
          center.dy + ctrlR * math.sin(angle - spreadAngle),
        );
        final cRight = Offset(
          center.dx + ctrlR * math.cos(angle + spreadAngle),
          center.dy + ctrlR * math.sin(angle + spreadAngle),
        );

        final petal = Path()
          ..moveTo(pStart.dx, pStart.dy)
          ..quadraticBezierTo(cLeft.dx, cLeft.dy, pTip.dx, pTip.dy)
          ..quadraticBezierTo(cRight.dx, cRight.dy, pStart.dx, pStart.dy)
          ..close();

        final baseCol = isIdle ? inactiveColor : color;
        final fillAlpha = isIdle
            ? (isOuter ? 0.14 : 0.22)
            : ((isOuter ? 0.20 : 0.34) + 0.35 * v).clamp(0.15, 0.75);
        final fillPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..color = baseCol.withValues(alpha: fillAlpha);
        final strokePaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = isOuter ? 1.0 : 1.4
          ..color = baseCol.withValues(
            alpha: (fillAlpha + 0.25).clamp(0.25, 0.95),
          );
        canvas.drawPath(petal, fillPaint);
        canvas.drawPath(petal, strokePaint);
      }
    }

    // Center stamen core. / 花蕊中心圆核。
    final coreR = maxR * (0.10 + 0.08 * metrics.rms);
    final coreBounds = Rect.fromCircle(center: center, radius: coreR);
    final corePaint = isIdle
        ? (Paint()
            ..isAntiAlias = true
            ..color = inactiveColor)
        : createActivePaint(color, gradient, coreBounds);
    canvas.drawCircle(center, coreR, corePaint);
  }

  @override
  bool shouldRepaint(_AcousticPetalPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.petalCount != petalCount;
}
