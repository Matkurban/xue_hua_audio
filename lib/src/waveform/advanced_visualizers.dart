import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'audio_waveform.dart';
import 'recording_visualizers.dart';
import 'waveform_controller.dart';
import 'waveform_parser.dart';

Paint _paintWithShader(Color color, Gradient? gradient, Rect rect) {
  final paint = Paint()..isAntiAlias = true;
  if (gradient != null) {
    paint.shader = gradient.createShader(rect);
  } else {
    paint.color = color;
  }
  return paint;
}

// ===========================================================================
// 7. SpectrogramHeatmapVisualizer — 实时声谱热力瀑布图组件
// ===========================================================================

/// A minimalist time-frequency spectrogram heatmap visualizer where micro-tiles
/// scroll horizontally and glow across a thermal/aurora intensity ramp.
///
/// 实时声谱热力瀑布图组件：以圆角微砖矩阵呈现时频能量分布，随声音滚动由静息冷灰
/// 渐变为深青、翠绿与高光亮色。
class SpectrogramHeatmapVisualizer extends RecordingVisualizerBase {
  /// Creates a spectrogram heatmap visualizer. / 创建实时声谱热力瀑布图组件。
  const SpectrogramHeatmapVisualizer({
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
    this.columns = 24,
    this.bands = 8,
    this.tileSpacing = 2.0,
    this.lowColor = const Color(0xFF0F766E),
    this.highColor = const Color(0xFF34D399),
    this.textDirection,
  }) : assert(columns >= 4 && columns <= 64),
       assert(bands >= 2 && bands <= 24),
       assert(tileSpacing >= 0);

  /// Number of time-slice columns (`4..64`). / 时间切片列数（`4..64`）。
  final int columns;

  /// Number of vertical frequency bands (`2..24`). / 垂直频段行数（`2..24`）。
  final int bands;

  /// Spacing between adjacent micro-tiles. / 微砖间距。
  final double tileSpacing;

  /// Low-energy thermal color. / 低能量热力色。
  final Color lowColor;

  /// High-energy peak thermal color. / 高能量峰值热力色。
  final Color highColor;

  /// Overrides horizontal time-flow direction. / 覆盖水平滚动方向。
  final TextDirection? textDirection;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording spectrogram heatmap' : 'Spectrogram visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection ambientDirection,
  ) => _SpectrogramHeatmapPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    columns: columns,
    bands: bands,
    tileSpacing: tileSpacing,
    lowColor: lowColor,
    highColor: highColor,
    rtl: (textDirection ?? ambientDirection) == TextDirection.rtl,
  );
}

class _SpectrogramHeatmapPainter extends CustomPainter {
  _SpectrogramHeatmapPainter({
    required this.controller,
    required this.color,
    required this.inactiveColor,
    required this.columns,
    required this.bands,
    required this.tileSpacing,
    required this.lowColor,
    required this.highColor,
    required this.rtl,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Color inactiveColor;
  final int columns;
  final int bands;
  final double tileSpacing;
  final Color lowColor;
  final Color highColor;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final grid = WaveformDataParser.computeSpectrogramGrid(
      controller,
      columns: columns,
      bands: bands,
    );
    final tileW = math.max(
      1.5,
      (size.width - tileSpacing * (columns - 1)) / columns,
    );
    final tileH = math.max(
      1.5,
      (size.height - tileSpacing * (bands - 1)) / bands,
    );
    final radius = Radius.circular(math.min(tileW, tileH) * 0.32);
    final paint = Paint()..isAntiAlias = true;

    for (var c = 0; c < columns; c++) {
      final slot = rtl ? c : columns - 1 - c;
      final left = slot * (tileW + tileSpacing);
      final colBands = grid[c];
      for (var b = 0; b < bands; b++) {
        // Band 0 at bottom, bands - 1 at top. / 低频在下，高频在上。
        final top = size.height - (b + 1) * tileH - b * tileSpacing;
        final v = colBands[b];
        if (v <= 0.01) {
          paint.color = inactiveColor.withValues(alpha: 0.16);
        } else {
          final base = v < 0.5
              ? Color.lerp(lowColor, color, v * 2)!
              : Color.lerp(color, highColor, (v - 0.5) * 2)!;
          paint.color = base.withValues(alpha: (0.28 + 0.72 * v).clamp(0, 1));
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, tileW, tileH),
            radius,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpectrogramHeatmapPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.inactiveColor != inactiveColor ||
      old.columns != columns ||
      old.bands != bands ||
      old.tileSpacing != tileSpacing ||
      old.lowColor != lowColor ||
      old.highColor != highColor ||
      old.rtl != rtl;
}

// ===========================================================================
// 8. HelixDnaVisualizer — 双螺旋声波基因链组件
// ===========================================================================

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

// ===========================================================================
// 9. AcousticPetalVisualizer — 几何声学花瓣曼陀罗组件
// ===========================================================================

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
        : _paintWithShader(color, gradient, coreBounds);
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

// ===========================================================================
// 10. PrecisionMeterVisualizer — 极简录音室精密双轨电桥组件
// ===========================================================================

/// A Braun/Nagra-inspired studio precision level bridge displaying a dual-bar
/// ballistic RMS + instantaneous peak meter, tick scale, and clipping lamp.
///
/// 极简录音室精密双轨电桥组件：同时呈现阻尼均方根（RMS）能量条、瞬时峰值条、
/// 精密刻度标尺、悬浮峰值保持线以及过载（Clip）指示灯。
class PrecisionMeterVisualizer extends RecordingVisualizerBase {
  /// Creates a precision studio meter visualizer. / 创建极简录音室精密双轨电桥组件。
  const PrecisionMeterVisualizer({
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
    this.clipColor = const Color(0xFFEF4444),
  });

  /// Color of the peak clipping indicator lamp. / 过载指示灯颜色。
  final Color clipColor;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording precision meter' : 'Precision meter visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _PrecisionMeterPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    clipColor: clipColor,
  );
}

class _PrecisionMeterPainter extends CustomPainter {
  _PrecisionMeterPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.clipColor,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final Color clipColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 12) return;
    final reading = WaveformDataParser.parsePrecisionMeter(controller);
    final padX = 12.0;
    final lampSpace = 22.0;
    final barW = math.max(8.0, size.width - padX * 2 - lampSpace);
    final topBarY = size.height * 0.24;
    final bottomBarY = size.height * 0.64;
    final barH = math.max(4.0, size.height * 0.16);
    final radius = Radius.circular(barH / 2);

    final trackPaint = Paint()
      ..isAntiAlias = true
      ..color = inactiveColor.withValues(alpha: 0.24);

    // 1. Instantaneous Peak track (top) & Ballistic RMS track (bottom).
    // 上轨：瞬时峰值；下轨：阻尼均方根（RMS）。
    final topTrack = Rect.fromLTWH(padX, topBarY, barW, barH);
    final botTrack = Rect.fromLTWH(padX, bottomBarY, barW, barH);
    canvas.drawRRect(RRect.fromRectAndRadius(topTrack, radius), trackPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(botTrack, radius), trackPaint);

    final activePaint = _paintWithShader(
      color,
      gradient,
      Rect.fromLTWH(padX, 0, barW, size.height),
    );
    if (reading.instantaneous > 0.004) {
      final w = (barW * reading.instantaneous).clamp(barH, barW);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(padX, topBarY, w, barH), radius),
        activePaint,
      );
    }
    if (reading.ballisticRms > 0.004) {
      final w = (barW * reading.ballisticRms).clamp(barH, barW);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(padX, bottomBarY, w, barH),
          radius,
        ),
        activePaint,
      );
    }

    // Precision tick marks along the middle spine. / 中轴精密刻度线。
    final midY = (topBarY + barH + bottomBarY) / 2;
    final tickPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1.0
      ..color = inactiveColor.withValues(alpha: 0.55);
    const ticks = 10;
    for (var i = 0; i <= ticks; i++) {
      final x = padX + (barW * i / ticks);
      final isMajor = i % 2 == 0;
      final halfTick = isMajor ? 3.0 : 1.6;
      canvas.drawLine(
        Offset(x, midY - halfTick),
        Offset(x, midY + halfTick),
        tickPaint,
      );
    }

    // Floating Peak-Hold cursor line across both tracks. / 跨越双轨的峰值保持游标线。
    if (reading.peakHold > 0.01) {
      final px = padX + (barW * reading.peakHold).clamp(0.0, barW);
      final cursorPaint = Paint()
        ..isAntiAlias = true
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = reading.isClipping ? clipColor : color;
      canvas.drawLine(
        Offset(px, topBarY - 2),
        Offset(px, bottomBarY + barH + 2),
        cursorPaint,
      );
    }

    // Clipping indicator lamp on the right side. / 右侧过载峰值指示灯。
    final lampCenter = Offset(size.width - padX - 4, size.height / 2);
    final lampR = math.min(5.0, size.height * 0.12);
    if (reading.isClipping) {
      canvas.drawCircle(
        lampCenter,
        lampR * 1.8,
        Paint()
          ..isAntiAlias = true
          ..color = clipColor.withValues(alpha: 0.28),
      );
    }
    canvas.drawCircle(
      lampCenter,
      lampR,
      Paint()
        ..isAntiAlias = true
        ..color = reading.isClipping
            ? clipColor
            : inactiveColor.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_PrecisionMeterPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.clipColor != clipColor;
}

// ===========================================================================
// 11. VoicePendulumVisualizer — 声学耦合谐振钟摆波组件
// ===========================================================================

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
    final bobPaint = _paintWithShader(
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

// ===========================================================================
// 12. MorphingPolygonVisualizer — 多维极简几何多边形声场组件
// ===========================================================================

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
          _paintWithShader(
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

// ===========================================================================
// 13. KineticLouverVisualizer — 建筑感韵律百叶窗光栅组件
// ===========================================================================

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
          ? _paintWithShader(color, gradient, rect)
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

// ===========================================================================
// 14. OrbitConstellationVisualizer — 星轨声场星座引力网组件
// ===========================================================================

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
    final dotPaint = _paintWithShader(
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

// ===========================================================================
// 15. SymmetricRibbonVisualizer — 极简折纸镜像钻石丝带组件
// ===========================================================================

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
        final strokePaint = _paintWithShader(baseCol, gradient, rect)
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

// ===========================================================================
// 16. OscilloscopeTraceVisualizer — 极简荧光扫描示波器组件
// ===========================================================================

/// A minimalist phosphor-oscilloscope visualizer featuring a subtle precision
/// graticule, high-frequency carrier waveform trace, and a glowing scan-head.
///
/// 极简荧光扫描示波器组件：配备微刻度十字基准网格、受实时语音包络调制的高频示波器
/// 轨迹，以及末端发光扫描头（Scan Head）。
class OscilloscopeTraceVisualizer extends RecordingVisualizerBase {
  /// Creates an oscilloscope trace visualizer. / 创建极简荧光扫描示波器组件。
  const OscilloscopeTraceVisualizer({
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
    this.pointCount = 96,
    this.strokeWidth = 2.0,
    this.showGraticule = true,
  }) : assert(pointCount >= 16 && pointCount <= 256),
       assert(strokeWidth > 0);

  /// Number of sampled trace vertices (`16..256`). / 示波器采样点数量（`16..256`）。
  final int pointCount;

  /// Trace line thickness. / 扫描轨迹线宽。
  final double strokeWidth;

  /// Whether to render the subtle background oscilloscope graticule.
  /// 是否绘制极简示波器基准网格。
  final bool showGraticule;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording oscilloscope trace' : 'Oscilloscope visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _OscilloscopeTracePainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    pointCount: pointCount,
    strokeWidth: strokeWidth,
    showGraticule: showGraticule,
  );
}

class _OscilloscopeTracePainter extends CustomPainter {
  _OscilloscopeTracePainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.pointCount,
    required this.strokeWidth,
    required this.showGraticule,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int pointCount;
  final double strokeWidth;
  final bool showGraticule;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final midY = size.height / 2;
    final maxAmp = size.height * 0.42;
    final rect = Offset.zero & size;

    if (showGraticule) {
      final gridPaint = Paint()
        ..isAntiAlias = true
        ..strokeWidth = 0.8
        ..color = inactiveColor.withValues(alpha: 0.22);
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);
      const vLines = 6;
      for (var i = 1; i < vLines; i++) {
        final x = size.width * i / vLines;
        canvas.drawLine(Offset(x, midY - 4), Offset(x, midY + 4), gridPaint);
      }
    }

    final trace = WaveformDataParser.computeOscilloscopeTrace(
      controller,
      pointCount: pointCount,
    );
    final metrics = controller.computeMetrics(window: 16);
    final isIdle = metrics.isSilent && !controller.active;

    final path = Path();
    var lastPt = Offset(0, midY);
    for (var i = 0; i < trace.length; i++) {
      final x = (i / (trace.length - 1)) * size.width;
      final y = midY + trace[i] * maxAmp;
      lastPt = Offset(x, y);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Phosphor glow shadow + crisp core trace. / 荧光柔光底层与锐利核心扫描线。
    if (!isIdle) {
      final glowPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.18);
      canvas.drawPath(path, glowPaint);
    }

    final tracePaint =
        _paintWithShader(
            isIdle ? inactiveColor : color,
            isIdle ? null : gradient,
            rect,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, tracePaint);

    if (!isIdle) {
      canvas.drawCircle(
        lastPt,
        strokeWidth * 1.6,
        Paint()
          ..isAntiAlias = true
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_OscilloscopeTracePainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.pointCount != pointCount ||
      old.strokeWidth != strokeWidth ||
      old.showGraticule != showGraticule;
}
