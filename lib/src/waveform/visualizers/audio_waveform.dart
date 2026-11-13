import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';

/// Visual style of [AudioWaveform]. / [AudioWaveform] 的绘制样式。
enum WaveformStyle {
  /// Rounded vertical bars centered on the midline (voice-message look).
  /// 以中线为中心的圆角竖条（语音消息风格）。
  bars,

  /// A smooth mirrored line. / 平滑的镜像折线。
  line,

  /// A filled mirrored area. / 填充的镜像面积图。
  filled,
}

/// A live, scrolling recording waveform.
///
/// Feed it from any one of: a [recorder], a [levels] stream of dBFS values,
/// or a [WaveformController] you drive yourself. Pure Dart; works on every
/// platform Flutter supports.
///
/// ```dart
/// AudioWaveform(recorder: recorder)               // zero-config
/// AudioWaveform(levels: myDbStream, height: 56)   // any dBFS stream
/// ```
///
/// New samples enter at the end side and scroll towards the start side; the
/// direction follows the ambient [Directionality] (override with
/// [textDirection]). While inactive the existing history stays frozen; when
/// there is no history, flat dots are shown.
///
/// 实时滚动的录音波形。数据来源三选一：[recorder]、dBFS 电平流 [levels]，或
/// 自行驱动的 [WaveformController]。纯 Dart，支持 Flutter 的所有平台。新采样
/// 从末端进入并向起始端滚动，方向跟随环境 [Directionality]（可用
/// [textDirection] 覆盖）。未激活时保持已有历史；无历史时显示平直圆点。
class AudioWaveform extends RecordingVisualizerBase {
  /// Creates a waveform. At most one of [recorder] / [levels] is normally
  /// given; [controller] may be combined with either.
  ///
  /// 创建波形。通常只给 [recorder] 或 [levels] 之一；[controller] 可与二者组合。
  const AudioWaveform({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    this.style = WaveformStyle.bars,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 48,
    this.barWidth = 3,
    this.spacing = 3,
    this.radius,
    super.minDb = -50,
    super.maxDb = 0,
    this.fadeEdges = true,
    this.textDirection,
    super.semanticLabel,
  });

  /// Painting style. / 绘制样式。
  final WaveformStyle style;

  /// Bar width (and minimum bar height / dot diameter).
  /// 柱宽（同时是最小柱高/圆点直径）。
  final double barWidth;

  /// Gap between bars. / 柱间距。
  final double spacing;

  /// Bar corner radius; defaults to fully rounded.
  /// 柱圆角半径，默认全圆角。
  final double? radius;

  /// Fades the bars out towards both edges. / 两端渐隐。
  final bool fadeEdges;

  /// Overrides the scrolling direction. / 覆盖滚动方向。
  final TextDirection? textDirection;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording waveform' : 'Waveform';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection ambientDirection,
  ) {
    final direction = textDirection ?? ambientDirection;
    return _LiveWaveformPainter(
      controller: controller,
      style: style,
      color: color ?? WaveformColors.active,
      gradient: gradient,
      inactiveColor: inactiveColor ?? WaveformColors.inactive,
      barWidth: barWidth,
      spacing: spacing,
      radius: radius,
      fadeEdges: fadeEdges,
      rtl: direction == TextDirection.rtl,
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  _LiveWaveformPainter({
    required this.controller,
    required this.style,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.barWidth,
    required this.spacing,
    required this.radius,
    required this.fadeEdges,
    required this.rtl,
  }) : super(repaint: controller);

  final WaveformController controller;
  final WaveformStyle style;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final double barWidth;
  final double spacing;
  final double? radius;
  final bool fadeEdges;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final step = barWidth + spacing;
    final slots = (size.width / step).ceil() + 1;
    final midY = size.height / 2;
    final rect = Offset.zero & size;
    // Pixel offset for sub-sample smooth scrolling (only while advancing).
    // 亚采样平滑滚动的像素偏移（仅推进时）。
    final shift = controller.active ? controller.phase * step : 0.0;
    final n = controller.length;

    canvas.save();
    canvas.clipRect(rect);
    withHorizontalEdgeFade(canvas, size, fadeEdges, () {
      final live = createActivePaint(color, gradient, rect);
      final idle = Paint()
        ..isAntiAlias = true
        ..color = inactiveColor;
      switch (style) {
        case WaveformStyle.bars:
          _paintBars(canvas, size, step, slots, midY, shift, n, live, idle);
        case WaveformStyle.line:
        case WaveformStyle.filled:
          _paintCurve(canvas, size, step, slots, midY, shift, n, live, idle);
      }
    });
    canvas.restore();
  }

  // x of slot k (k = 0 is the newest), measured on the *end* side.
  // 槽位 k（0 为最新）在末端一侧的 x 坐标。
  double _x(int k, double step, double width, double shift) {
    final fromEnd = barWidth / 2 + k * step + shift;
    return rtl ? fromEnd : width - fromEnd;
  }

  void _paintBars(
    Canvas canvas,
    Size size,
    double step,
    int slots,
    double midY,
    double shift,
    int n,
    Paint live,
    Paint idle,
  ) {
    final r = radius ?? barWidth / 2;
    final maxH = size.height;
    for (var k = 0; k < slots; k++) {
      final x = _x(k, step, size.width, shift);
      final hasData = k < n;
      final v = hasData ? controller.valueAt(n - 1 - k) : 0.0;
      final h = math.max(barWidth, v * maxH);
      final rr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, midY), width: barWidth, height: h),
        Radius.circular(math.min(r, h / 2)),
      );
      canvas.drawRRect(rr, hasData && v > 0.0 ? live : idle);
    }
  }

  void _paintCurve(
    Canvas canvas,
    Size size,
    double step,
    int slots,
    double midY,
    double shift,
    int n,
    Paint live,
    Paint idle,
  ) {
    if (n == 0) {
      final y = midY;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        idle
          ..strokeWidth = barWidth
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    double ampAt(int k) {
      final v = k < n ? controller.valueAt(n - 1 - k) : 0.0;
      return math.max(barWidth / 2, v * size.height / 2);
    }

    if (style == WaveformStyle.filled) {
      // Top edge forwards, bottom edge backwards → one closed shape.
      // 上边缘正向、下边缘反向，构成闭合图形。
      final area = Path();
      for (var k = 0; k < slots; k++) {
        final x = _x(k, step, size.width, shift);
        final y = midY - ampAt(k);
        k == 0 ? area.moveTo(x, y) : area.lineTo(x, y);
      }
      for (var k = slots - 1; k >= 0; k--) {
        area.lineTo(_x(k, step, size.width, shift), midY + ampAt(k));
      }
      area.close();
      canvas.drawPath(area, live..style = PaintingStyle.fill);
      return;
    }
    final top = Path();
    final bottom = Path();
    for (var k = 0; k < slots; k++) {
      final x = _x(k, step, size.width, shift);
      final amp = ampAt(k);
      if (k == 0) {
        top.moveTo(x, midY - amp);
        bottom.moveTo(x, midY + amp);
      } else {
        top.lineTo(x, midY - amp);
        bottom.lineTo(x, midY + amp);
      }
    }
    live
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(top, live);
    canvas.drawPath(bottom, live);
  }

  @override
  bool shouldRepaint(_LiveWaveformPainter old) =>
      old.controller != controller ||
      old.style != style ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.barWidth != barWidth ||
      old.spacing != spacing ||
      old.radius != radius ||
      old.fadeEdges != fadeEdges ||
      old.rtl != rtl;
}
