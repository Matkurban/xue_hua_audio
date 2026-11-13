import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// An orbital constellation visualizer where nodes revolve along concentric
/// elliptical tracks and form dynamic proximity filaments as voice energy
/// rises.
///
/// 星轨声场星座引力网组件：多颗声学星点沿椭圆星轨环绕中心声核运行，当相邻节点距离
/// 接近且语音能量升高时自动生成动态引力连线。
class OrbitConstellationVisualizer extends RecordingVisualizerBase {
  /// Creates an orbit constellation visualizer. / 创建星轨声场星座引力网组件。
  const OrbitConstellationVisualizer({
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
    this.nodeCount = 16,
    this.orbitCount = 3,
  }) : assert(nodeCount >= 4 && nodeCount <= 48),
       assert(orbitCount >= 1 && orbitCount <= 6);

  /// Number of revolving constellation nodes (`4..48`).
  /// 星轨星座节点总数（`4..48`）。
  final int nodeCount;

  /// Number of concentric elliptical orbit tracks (`1..6`).
  /// 椭圆星轨层数（`1..6`）。
  final int orbitCount;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording orbit constellation' : 'Constellation visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _OrbitConstellationPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    nodeCount: nodeCount,
    orbitCount: orbitCount,
  );
}

class _OrbitConstellationPainter extends CustomPainter {
  _OrbitConstellationPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.nodeCount,
    required this.orbitCount,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int nodeCount;
  final int orbitCount;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 4) return;
    final center = Offset(size.width / 2, size.height / 2);
    final nodes = WaveformDataParser.computeOrbitalNodes(
      controller,
      nodeCount: nodeCount,
      orbitCount: orbitCount,
    );
    final metrics = controller.computeMetrics(window: 18);
    final isIdle = metrics.isSilent && !controller.active;
    final scaleX = math.min(size.width * 0.44, maxR * 1.35);
    final scaleY = maxR * 0.88;

    // Subtle elliptical orbit tracks. / 极简椭圆轨道线。
    final orbitPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = inactiveColor.withValues(alpha: 0.22);
    for (var o = 0; o < orbitCount; o++) {
      final rRatio = 0.28 + (o / math.max(1, orbitCount)) * 0.52;
      final aspect = 0.78 + 0.08 * o;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: scaleX * rRatio * 2,
          height: scaleY * rRatio * aspect * 2,
        ),
        orbitPaint,
      );
    }

    final screenPts = List<Offset>.generate(
      nodes.length,
      (i) => Offset(
        center.dx + nodes[i].position.dx * scaleX,
        center.dy + nodes[i].position.dy * scaleY,
      ),
    );

    // Constellation proximity filaments. / 节点间动态引力连线。
    final maxLinkDist = maxR * (0.72 + 0.45 * metrics.rms);
    final linkPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1.0;
    final baseCol = isIdle ? inactiveColor : color;

    for (var i = 0; i < screenPts.length; i++) {
      for (var j = i + 1; j < screenPts.length; j++) {
        final d = (screenPts[i] - screenPts[j]).distance;
        if (d < maxLinkDist) {
          final proximity = 1.0 - (d / maxLinkDist);
          final alpha = (proximity * (0.18 + 0.55 * metrics.rms)).clamp(
            0.05,
            0.65,
          );
          linkPaint.color = baseCol.withValues(alpha: alpha);
          canvas.drawLine(screenPts[i], screenPts[j], linkPaint);
        }
      }
    }

    // Nodes and center nucleus. / 星轨节点与中心核。
    final dotPaint = createActivePaint(
      baseCol,
      isIdle ? null : gradient,
      Offset.zero & size,
    );
    for (var i = 0; i < screenPts.length; i++) {
      canvas.drawCircle(screenPts[i], 2.2 * nodes[i].radiusFactor, dotPaint);
    }
    canvas.drawCircle(center, 3.2 + 3.5 * metrics.current, dotPaint);
  }

  @override
  bool shouldRepaint(_OrbitConstellationPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.nodeCount != nodeCount ||
      old.orbitCount != orbitCount;
}
