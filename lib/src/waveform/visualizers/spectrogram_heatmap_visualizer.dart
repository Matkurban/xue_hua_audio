import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

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
