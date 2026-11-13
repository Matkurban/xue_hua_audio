import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../models/meter_models.dart';
import '../parser/waveform_parser.dart';

/// A minimalist industrial-style segmented LED / VU equalizer matrix with
/// three-zone color grading (normal / warning / danger) and floating
/// peak-hold cap indicators.
///
/// 极简工业风分段式 LED / VU 电平矩阵组件：支持多频段胶囊分段点亮、三色安全区间
/// 渐变（正常绿/预警琥珀/峰值珊瑚红）以及悬浮峰值保持（Peak Hold）指示帽。
class SegmentedVuVisualizer extends RecordingVisualizerBase {
  /// Creates a segmented VU matrix visualizer. / 创建分段式 LED 电平矩阵组件。
  const SegmentedVuVisualizer({
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
    this.bandCount = 16,
    this.segmentCount = 10,
    this.columnSpacing = 4.0,
    this.segmentSpacing = 2.2,
    this.warningColor = const Color(0xFFF59E0B),
    this.dangerColor = const Color(0xFFEF4444),
    this.showPeakHold = true,
  }) : assert(bandCount >= 1 && bandCount <= 64),
       assert(segmentCount >= 3 && segmentCount <= 32),
       assert(columnSpacing >= 0),
       assert(segmentSpacing >= 0);

  /// Number of frequency/history columns (`1..64`).
  /// 垂直电平柱列数（`1..64`）。
  final int bandCount;

  /// Number of discrete LED segments per column (`3..32`).
  /// 每列包含的离散 LED 分段数（`3..32`）。
  final int segmentCount;

  /// Horizontal gap between columns. / 列间距。
  final double columnSpacing;

  /// Vertical gap between segments inside a column. / 段间距。
  final double segmentSpacing;

  /// Color of segments in [VuZone.warning]. / [VuZone.warning] 预警区段颜色。
  final Color warningColor;

  /// Color of segments in [VuZone.danger]. / [VuZone.danger] 峰值区段颜色。
  final Color dangerColor;

  /// Whether to render the floating peak-hold segment cap.
  /// 是否显示悬浮峰值保持指示段。
  final bool showPeakHold;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording VU meter' : 'Segmented VU visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _SegmentedVuPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    bandCount: bandCount,
    segmentCount: segmentCount,
    columnSpacing: columnSpacing,
    segmentSpacing: segmentSpacing,
    warningColor: warningColor,
    dangerColor: dangerColor,
    showPeakHold: showPeakHold,
  );
}

class _SegmentedVuPainter extends CustomPainter {
  _SegmentedVuPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.bandCount,
    required this.segmentCount,
    required this.columnSpacing,
    required this.segmentSpacing,
    required this.warningColor,
    required this.dangerColor,
    required this.showPeakHold,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int bandCount;
  final int segmentCount;
  final double columnSpacing;
  final double segmentSpacing;
  final Color warningColor;
  final Color dangerColor;
  final bool showPeakHold;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final bands = WaveformDataParser.extractFrequencyBands(
      controller,
      bandCount,
    );
    final totalSpacingW = columnSpacing * (bandCount - 1);
    final colW = math.max(2.0, (size.width - totalSpacingW) / bandCount);
    final totalSpacingH = segmentSpacing * (segmentCount - 1);
    final segH = math.max(1.5, (size.height - totalSpacingH) / segmentCount);
    final radius = Radius.circular(math.min(colW, segH) * 0.42);

    final idlePaint = Paint()
      ..isAntiAlias = true
      ..color = inactiveColor.withValues(alpha: 0.26);
    final normalPaint = Paint()
      ..isAntiAlias = true
      ..color = color;
    final warnPaint = Paint()
      ..isAntiAlias = true
      ..color = warningColor;
    final dangerPaint = Paint()
      ..isAntiAlias = true
      ..color = dangerColor;

    final globalPeakHold = controller.peakHold;

    for (var col = 0; col < bandCount; col++) {
      final level = bands[col];
      final centerBias = math.sin(
        (bandCount == 1 ? 0.5 : col / (bandCount - 1)) * math.pi,
      );
      final bandPeak = math.max(
        level,
        globalPeakHold * (0.55 + 0.45 * centerBias),
      );
      final vu = WaveformDataParser.parseVuSegments(
        level: level,
        peakHold: showPeakHold ? bandPeak : 0.0,
        segments: segmentCount,
      );
      final left = col * (colW + columnSpacing);

      for (var s = 0; s < segmentCount; s++) {
        // Segment 0 is at the bottom, segmentCount - 1 is at the top.
        // 第 0 段位于底部，第 segmentCount - 1 段位于顶部。
        final top = size.height - (s + 1) * segH - s * segmentSpacing;
        final rect = Rect.fromLTWH(left, top, colW, segH);
        final rrect = RRect.fromRectAndRadius(rect, radius);
        final isLit = s < vu.activeSegments;
        final isPeakCap = showPeakHold && vu.peakSegment == s;

        if (isLit || isPeakCap) {
          final zone = vu.zoneOf(s);
          final paint = switch (zone) {
            VuZone.normal => normalPaint,
            VuZone.warning => warnPaint,
            VuZone.danger => dangerPaint,
          };
          canvas.drawRRect(rrect, paint);
        } else {
          canvas.drawRRect(rrect, idlePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SegmentedVuPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.bandCount != bandCount ||
      old.segmentCount != segmentCount ||
      old.columnSpacing != columnSpacing ||
      old.segmentSpacing != segmentSpacing ||
      old.warningColor != warningColor ||
      old.dangerColor != dangerColor ||
      old.showPeakHold != showPeakHold;
}
