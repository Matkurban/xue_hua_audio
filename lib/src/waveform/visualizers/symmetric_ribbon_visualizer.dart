import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';

/// A crisp geometric origami-ribbon visualizer featuring layered mirrored
/// diamond facets and a bright acoustic center spine.
///
/// 极简折纸镜像钻石丝带组件：由多层带延迟回声的几何钻石切面与高亮中心脊线构成，
/// 兼具有机连续性与折纸建筑感。
class SymmetricRibbonVisualizer extends RecordingVisualizerBase {
  /// Creates a symmetric ribbon visualizer. / 创建极简折纸镜像钻石丝带组件。
  const SymmetricRibbonVisualizer({
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
    this.facetCount = 22,
    this.echoLayers = 3,
  }) : assert(facetCount >= 4 && facetCount <= 64),
       assert(echoLayers >= 1 && echoLayers <= 5);

  /// Number of horizontal geometric facets (`4..64`). / 水平折纸切面数量（`4..64`）。
  final int facetCount;

  /// Number of layered echo envelopes (`1..5`). / 延迟回声丝带层数（`1..5`）。
  final int echoLayers;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording symmetric ribbon' : 'Symmetric ribbon visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _SymmetricRibbonPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    facetCount: facetCount,
    echoLayers: echoLayers,
  );
}

class _SymmetricRibbonPainter extends CustomPainter {
  _SymmetricRibbonPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.facetCount,
    required this.echoLayers,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int facetCount;
  final int echoLayers;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final midY = size.height / 2;
    final maxAmp = size.height * 0.45;
    final metrics = controller.computeMetrics(window: 20);
    final isIdle = metrics.isSilent && !controller.active;
    final rect = Offset.zero & size;

    for (var layer = echoLayers - 1; layer >= 0; layer--) {
      final scale = 1.0 - layer * 0.22;
      final delay = layer * 2.0;
      final path = Path()..moveTo(0, midY);

      for (var i = 0; i <= facetCount; i++) {
        final normX = i / facetCount;
        final x = normX * size.width;
        final taper = math.sin(normX * math.pi);
        final v = controller.sampleInterpolated((facetCount - i) * 0.6 + delay);
        final amp = isIdle ? 1.0 : math.max(1.5, v * maxAmp * scale * taper);
        path.lineTo(x, midY - amp);
      }
      for (var i = facetCount; i >= 0; i--) {
        final normX = i / facetCount;
        final x = normX * size.width;
        final taper = math.sin(normX * math.pi);
        final v = controller.sampleInterpolated((facetCount - i) * 0.6 + delay);
        final amp = isIdle ? 1.0 : math.max(1.5, v * maxAmp * scale * taper);
        path.lineTo(x, midY + amp);
      }
      path.close();

      final baseCol = isIdle ? inactiveColor : color;
      final alpha = layer == 0 ? 0.42 : (0.18 + 0.08 * (echoLayers - layer));
      final fillPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..color = baseCol.withValues(alpha: alpha);
      canvas.drawPath(path, fillPaint);

      if (layer == 0) {
        final strokePaint = createActivePaint(baseCol, gradient, rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.bevel;
        canvas.drawPath(path, strokePaint);
      }
    }

    // Crisp center horizon spine. / 中心高亮折痕脊线。
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..isAntiAlias = true
        ..strokeWidth = 1.0
        ..color = (isIdle ? inactiveColor : color).withValues(alpha: 0.65),
    );
  }

  @override
  bool shouldRepaint(_SymmetricRibbonPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.facetCount != facetCount ||
      old.echoLayers != echoLayers;
}
