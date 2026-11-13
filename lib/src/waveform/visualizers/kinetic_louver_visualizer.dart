import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// An architectural kinetic-louver visualizer where vertical slats tilt,
/// thicken, and stretch as transverse acoustic waves propagate across them.
///
/// 建筑感韵律百叶窗光栅组件：垂直光栅叶片随横向声波传播产生动态倾角偏转、高度舒展
/// 与粗细调制，呈现瑞士版式光栅般的现代几何质感。
class KineticLouverVisualizer extends RecordingVisualizerBase {
  /// Creates a kinetic louver visualizer. / 创建建筑感韵律百叶窗光栅组件。
  const KineticLouverVisualizer({
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
    this.slatCount = 28,
    this.baseStrokeWidth = 2.8,
  }) : assert(slatCount >= 6 && slatCount <= 80),
       assert(baseStrokeWidth > 0);

  /// Number of vertical louver slats (`6..80`). / 光栅叶片数量（`6..80`）。
  final int slatCount;

  /// Base stroke thickness of each slat. / 叶片基准线宽。
  final double baseStrokeWidth;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording kinetic louvers' : 'Kinetic louver visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _KineticLouverPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    slatCount: slatCount,
    baseStrokeWidth: baseStrokeWidth,
  );
}

class _KineticLouverPainter extends CustomPainter {
  _KineticLouverPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.slatCount,
    required this.baseStrokeWidth,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int slatCount;
  final double baseStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final slats = WaveformDataParser.computeKineticLouvers(
      controller,
      slatCount: slatCount,
    );
    final midY = size.height / 2;
    final maxHalfH = size.height * 0.44;
    final step = size.width / slatCount;
    final rect = Offset.zero & size;

    for (var i = 0; i < slatCount; i++) {
      final slat = slats[i];
      final cx = size.width - (i + 0.5) * step;
      final halfLen = math.max(3.0, maxHalfH * slat.heightFactor);
      final dx = halfLen * math.sin(slat.tiltRadians);
      final dy = halfLen * math.cos(slat.tiltRadians);
      final p0 = Offset(cx - dx, midY - dy);
      final p1 = Offset(cx + dx, midY + dy);

      final isActive = slat.amplitude > 0.004;
      final paint = isActive
          ? createActivePaint(color, gradient, rect)
          : (Paint()
              ..isAntiAlias = true
              ..color = inactiveColor);
      paint
        ..strokeWidth = baseStrokeWidth * slat.thicknessFactor
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p0, p1, paint);
    }
  }

  @override
  bool shouldRepaint(_KineticLouverPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.slatCount != slatCount ||
      old.baseStrokeWidth != baseStrokeWidth;
}
