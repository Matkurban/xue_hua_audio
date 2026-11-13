import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// A circular polar acoustic spectrum visualizer where capsule bars radiate
/// symmetrically from a clean inner halo ring.
///
/// 极坐标环形对称声谱组件：圆角胶囊声柱沿圆周对称向外辐射，中心配有随均方根
/// 能量呼吸的极简指示核。
class RadialSpectrumVisualizer extends RecordingVisualizerBase {
  /// Creates a radial spectrum visualizer. / 创建极坐标环形声谱组件。
  const RadialSpectrumVisualizer({
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
    this.spokeCount = 36,
    this.spokeWidth = 2.8,
    this.innerRadiusRatio = 0.38,
    this.mirrorSymmetry = true,
    this.showCenterDot = true,
  }) : assert(spokeCount >= 8 && spokeCount <= 120),
       assert(spokeWidth > 0),
       assert(innerRadiusRatio > 0.1 && innerRadiusRatio < 0.85);

  /// Number of radial capsule spokes around the circle (`8..120`).
  /// 圆周辐射胶囊声柱数量（`8..120`）。
  final int spokeCount;

  /// Width of each radial capsule spoke. / 每根辐射声柱的宽度。
  final double spokeWidth;

  /// Inner ring radius as a fraction of the half-shortest-side.
  /// 内环半径占半短边的比例。
  final double innerRadiusRatio;

  /// Whether to mirror the spectrum bilaterally across the vertical axis.
  /// 是否沿垂直中轴线左右镜像对称分布。
  final bool mirrorSymmetry;

  /// Whether to draw a responsive center indicator dot.
  /// 是否绘制随能量微动的中心圆点。
  final bool showCenterDot;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording radial spectrum' : 'Radial spectrum visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _RadialSpectrumPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    spokeCount: spokeCount,
    spokeWidth: spokeWidth,
    innerRadiusRatio: innerRadiusRatio,
    mirrorSymmetry: mirrorSymmetry,
    showCenterDot: showCenterDot,
  );
}

class _RadialSpectrumPainter extends CustomPainter {
  _RadialSpectrumPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.spokeCount,
    required this.spokeWidth,
    required this.innerRadiusRatio,
    required this.mirrorSymmetry,
    required this.showCenterDot,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int spokeCount;
  final double spokeWidth;
  final double innerRadiusRatio;
  final bool mirrorSymmetry;
  final bool showCenterDot;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 4) return;
    final center = Offset(size.width / 2, size.height / 2);
    final innerR = maxR * innerRadiusRatio;
    final maxSpokeLen = math.max(spokeWidth, maxR * 0.94 - innerR);
    final values = WaveformDataParser.extractMirroredRadial(
      controller,
      spokeCount,
      mirror: mirrorSymmetry,
    );
    final metrics = controller.computeMetrics(window: 24);
    final bounds = Rect.fromCircle(center: center, radius: maxR);
    final activePaint = createActivePaint(color, gradient, bounds)
      ..strokeWidth = spokeWidth
      ..strokeCap = StrokeCap.round;
    final idlePaint = Paint()
      ..isAntiAlias = true
      ..color = inactiveColor
      ..strokeWidth = spokeWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < spokeCount; i++) {
      final v = values[i];
      final angle = -math.pi / 2 + (i * 2 * math.pi / spokeCount);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final len = math.max(spokeWidth, v * maxSpokeLen);
      final p0 = Offset(center.dx + innerR * cosA, center.dy + innerR * sinA);
      final p1 = Offset(
        center.dx + (innerR + len) * cosA,
        center.dy + (innerR + len) * sinA,
      );
      canvas.drawLine(p0, p1, v > 0.004 ? activePaint : idlePaint);
    }

    if (showCenterDot) {
      final dotR = math.max(2.5, innerR * (0.22 + 0.35 * metrics.rms));
      canvas.drawCircle(
        center,
        dotR,
        metrics.isSilent && !controller.active ? idlePaint : activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RadialSpectrumPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.spokeCount != spokeCount ||
      old.spokeWidth != spokeWidth ||
      old.innerRadiusRatio != innerRadiusRatio ||
      old.mirrorSymmetry != mirrorSymmetry ||
      old.showCenterDot != showCenterDot;
}
