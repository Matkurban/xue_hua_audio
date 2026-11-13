import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';

/// A static waveform of a finished recording with optional playback
/// progress. [levels] are normalized (0–1) and resampled to fit the width.
///
/// ```dart
/// StaticWaveform(levels: saved, progress: position / duration)
/// ```
///
/// 已完成录音的静态波形，可显示播放进度。[levels] 为归一化（0–1）数据，
/// 会按宽度重采样。
class StaticWaveform extends StatelessWidget {
  /// Creates a static waveform. / 创建静态波形。
  const StaticWaveform({
    super.key,
    required this.levels,
    this.progress,
    this.color,
    this.gradient,
    this.inactiveColor,
    this.height = 48,
    this.barWidth = 3,
    this.spacing = 3,
    this.radius,
    this.textDirection,
    this.semanticLabel,
  });

  /// Normalized levels (0–1), oldest first. / 归一化电平（0–1），最旧在前。
  final List<double> levels;

  /// Played fraction (0–1); null paints everything in the active color.
  /// 已播放比例（0–1）；为空则全部使用主色。
  final double? progress;

  /// Played color; defaults to [WaveformColors.active]. / 已播放颜色。
  final Color? color;

  /// Gradient for the played part. / 已播放部分的渐变。
  final Gradient? gradient;

  /// Unplayed color; defaults to [WaveformColors.inactive]. / 未播放颜色。
  final Color? inactiveColor;

  /// Widget height. / 组件高度。
  final double height;

  /// Bar width. / 柱宽。
  final double barWidth;

  /// Gap between bars. / 柱间距。
  final double spacing;

  /// Bar corner radius; defaults to fully rounded. / 圆角半径，默认全圆角。
  final double? radius;

  /// Overrides the progress direction. / 覆盖进度方向。
  final TextDirection? textDirection;

  /// Accessibility label. / 无障碍标签。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dir = textDirection ?? Directionality.of(context);
    final p = progress?.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel ?? 'Audio waveform',
      value: p == null ? null : '${(p * 100).round()}%',
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _StaticWaveformPainter(
              levels: levels,
              progress: p,
              color: color ?? WaveformColors.active,
              gradient: gradient,
              inactiveColor: inactiveColor ?? WaveformColors.inactive,
              barWidth: barWidth,
              spacing: spacing,
              radius: radius,
              rtl: dir == TextDirection.rtl,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticWaveformPainter extends CustomPainter {
  _StaticWaveformPainter({
    required this.levels,
    required this.progress,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.barWidth,
    required this.spacing,
    required this.radius,
    required this.rtl,
  });

  final List<double> levels;
  final double? progress;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final double barWidth;
  final double spacing;
  final double? radius;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final step = barWidth + spacing;
    final count = math.max(1, ((size.width + spacing) / step).floor());
    final rect = Offset.zero & size;
    final live = createActivePaint(color, gradient, rect);
    final idle = Paint()
      ..isAntiAlias = true
      ..color = inactiveColor;
    final r = radius ?? barWidth / 2;
    final used = count * step - spacing;
    final startX = (size.width - used) / 2;
    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.0 : i / (count - 1);
      var v = 0.0;
      if (levels.isNotEmpty) {
        // Peak of the source bucket this bar covers. / 取该柱覆盖区间的峰值。
        final a = (i * levels.length / count).floor();
        final b = math.max(a + 1, ((i + 1) * levels.length / count).ceil());
        for (var j = a; j < math.min(b, levels.length); j++) {
          v = math.max(v, levels[j].clamp(0.0, 1.0));
        }
      }
      final h = math.max(barWidth, v * size.height);
      final slot = rtl ? count - 1 - i : i;
      final cx = startX + slot * step + barWidth / 2;
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, size.height / 2),
          width: barWidth,
          height: h,
        ),
        Radius.circular(math.min(r, h / 2)),
      );
      final played = progress == null || t <= progress!;
      canvas.drawRRect(rr, played ? live : idle);
    }
  }

  @override
  bool shouldRepaint(_StaticWaveformPainter old) =>
      old.levels != levels ||
      old.progress != progress ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.barWidth != barWidth ||
      old.spacing != spacing ||
      old.radius != radius ||
      old.rtl != rtl;
}
