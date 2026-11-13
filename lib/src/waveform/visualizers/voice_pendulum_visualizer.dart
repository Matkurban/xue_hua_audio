import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

/// A kinetic Mach's pendulum-wave visualizer where suspended bobs of
/// graduated lengths swing in travelling harmonic waves driven by voice energy.
///
/// 声学耦合谐振钟摆波组件：多根递增长度的极简悬丝钟摆随语音能量以行波相位摆动，
/// 摆锤配有柔和能量光晕。
class VoicePendulumVisualizer extends RecordingVisualizerBase {
  /// Creates a voice pendulum visualizer. / 创建声学耦合谐振钟摆波组件。
  const VoicePendulumVisualizer({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 84,
    super.minDb,
    super.maxDb,
    super.semanticLabel,
    this.pendulumCount = 15,
    this.maxAngleRadians = 0.65,
  }) : assert(pendulumCount >= 3 && pendulumCount <= 40),
       assert(maxAngleRadians > 0.05 && maxAngleRadians <= 1.4);

  /// Number of coupled pendulums (`3..40`). / 耦合钟摆数量（`3..40`）。
  final int pendulumCount;

  /// Maximum swing deflection in radians. / 最大摆角（弧度）。
  final double maxAngleRadians;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording pendulum wave' : 'Voice pendulum visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _VoicePendulumPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    pendulumCount: pendulumCount,
    maxAngleRadians: maxAngleRadians,
  );
}

class _VoicePendulumPainter extends CustomPainter {
  _VoicePendulumPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.pendulumCount,
    required this.maxAngleRadians,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int pendulumCount;
  final double maxAngleRadians;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 8 || size.height <= 8) return;
    final angles = WaveformDataParser.computePendulumAngles(
      controller,
      count: pendulumCount,
      maxAngleRadians: maxAngleRadians,
    );
    final metrics = controller.computeMetrics(window: 16);
    final isIdle = metrics.isSilent && !controller.active;
    final topY = 4.0;
    final maxLen = size.height - topY - 8.0;
    final minLen = maxLen * 0.42;
    final colStep = size.width / (pendulumCount + 1);

    // Top suspension rail. / 顶部极简悬挂横梁。
    final railPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1.2
      ..color = inactiveColor.withValues(alpha: 0.40);
    canvas.drawLine(
      Offset(colStep * 0.6, topY),
      Offset(size.width - colStep * 0.6, topY),
      railPaint,
    );

    final stringPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1.1
      ..color = (isIdle ? inactiveColor : color).withValues(alpha: 0.38);
    final bobPaint = createActivePaint(
      isIdle ? inactiveColor : color,
      isIdle ? null : gradient,
      Offset.zero & size,
    );

    for (var i = 0; i < pendulumCount; i++) {
      final pivot = Offset(colStep * (i + 1), topY);
      final ratio = pendulumCount == 1 ? 0.5 : i / (pendulumCount - 1);
      final len = minLen + (maxLen - minLen) * ratio;
      final theta = angles[i];
      final bob = Offset(
        pivot.dx + len * math.sin(theta),
        pivot.dy + len * math.cos(theta),
      );
      canvas.drawLine(pivot, bob, stringPaint);
      final swingRatio = (theta.abs() / maxAngleRadians).clamp(0.0, 1.0);
      final bobR = 2.6 + 2.4 * swingRatio;
      canvas.drawCircle(bob, bobR, bobPaint);
    }
  }

  @override
  bool shouldRepaint(_VoicePendulumPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.pendulumCount != pendulumCount ||
      old.maxAngleRadians != maxAngleRadians;
}
