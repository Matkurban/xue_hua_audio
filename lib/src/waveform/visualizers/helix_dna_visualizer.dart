import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// A 3D-projected double-helix acoustic visualizer where two phase-intertwined
/// strands and connecting base-pair rungs undulate with voice energy.
///
/// 双螺旋声波基因链组件：两条反相交织的三维投影正弦声链通过碱基横档相连，节点粒径
/// 与景深透明度随实时语音振幅立体律动。
class HelixDnaVisualizer extends RecordingVisualizerBase {
  /// Creates a double-helix DNA visualizer. / 创建双螺旋声波基因链组件。
  const HelixDnaVisualizer({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 76,
    super.minDb,
    super.maxDb,
    super.semanticLabel,
    this.nodeCount = 24,
    this.turns = 1.75,
    this.secondaryColor,
  }) : assert(nodeCount >= 6 && nodeCount <= 64),
       assert(turns > 0);

  /// Number of base-pair nodes along the helix (`6..64`).
  /// 双螺旋节点对数量（`6..64`）。
  final int nodeCount;

  /// Number of full helical turns across the width. / 横跨宽度的螺旋圈数。
  final double turns;

  /// Accent color of the complementary B strand. / 互补 B 链的配色。
  final Color? secondaryColor;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording DNA helix' : 'Helix DNA visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _HelixDnaPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    secondaryColor: secondaryColor ?? const Color(0xFF0EA5E9),
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    nodeCount: nodeCount,
    turns: turns,
  );
}

class _HelixDnaPainter extends CustomPainter {
  _HelixDnaPainter({
    required this.controller,
    required this.color,
    required this.secondaryColor,
    required this.inactiveColor,
    required this.nodeCount,
    required this.turns,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Color secondaryColor;
  final Color inactiveColor;
  final int nodeCount;
  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final midY = size.height / 2;
    final maxAmp = size.height * 0.40;
    final padX = 8.0;
    final usableW = math.max(1.0, size.width - padX * 2);
    final nodes = WaveformDataParser.computeHelixNodes(
      controller,
      nodeCount: nodeCount,
      turns: turns,
    );
    final metrics = controller.computeMetrics(window: 16);
    final isIdle = metrics.isSilent && !controller.active;

    final rungPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;

    for (final node in nodes) {
      final x = padX + node.progress * usableW;
      final yA = midY + node.yOffsetA * maxAmp;
      final yB = midY + node.yOffsetB * maxAmp;

      // Connecting base-pair rung. / 连接两条螺旋链的横档。
      rungPaint.color = (isIdle ? inactiveColor : color).withValues(
        alpha: isIdle ? 0.22 : (0.18 + 0.42 * node.amplitude).clamp(0.15, 0.65),
      );
      canvas.drawLine(Offset(x, yA), Offset(x, yB), rungPaint);

      void drawStrandDot(double y, double depth, Color strandColor) {
        final normDepth = (depth + 1.0) * 0.5; // 0 (back) .. 1 (front)
        final r = 1.8 + 2.4 * normDepth * (0.45 + 0.55 * node.amplitude);
        final alpha = isIdle
            ? (0.30 + 0.35 * normDepth)
            : (0.35 + 0.65 * normDepth).clamp(0.25, 1.0);
        final dotPaint = Paint()
          ..isAntiAlias = true
          ..color = (isIdle ? inactiveColor : strandColor).withValues(
            alpha: alpha,
          );
        canvas.drawCircle(Offset(x, y), r, dotPaint);
      }

      // Depth-sort back dot before front dot. / 按景深先后绘制前后链节点。
      if (node.depthA <= node.depthB) {
        drawStrandDot(yA, node.depthA, color);
        drawStrandDot(yB, node.depthB, secondaryColor);
      } else {
        drawStrandDot(yB, node.depthB, secondaryColor);
        drawStrandDot(yA, node.depthA, color);
      }
    }
  }

  @override
  bool shouldRepaint(_HelixDnaPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.secondaryColor != secondaryColor ||
      old.inactiveColor != inactiveColor ||
      old.nodeCount != nodeCount ||
      old.turns != turns;
}
