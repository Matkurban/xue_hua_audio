import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

import '../audio_recorder.dart';
import 'waveform_controller.dart';

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
class AudioWaveform extends StatefulWidget {
  /// Creates a waveform. At most one of [recorder] / [levels] is normally
  /// given; [controller] may be combined with either.
  ///
  /// 创建波形。通常只给 [recorder] 或 [levels] 之一；[controller] 可与二者组合。
  const AudioWaveform({
    super.key,
    this.recorder,
    this.levels,
    this.controller,
    this.active,
    this.style = WaveformStyle.bars,
    this.color,
    this.gradient,
    this.inactiveColor,
    this.height = 48,
    this.barWidth = 3,
    this.spacing = 3,
    this.radius,
    this.minDb = -60,
    this.maxDb = 0,
    this.fadeEdges = true,
    this.textDirection,
    this.semanticLabel,
  }) : assert(recorder == null || levels == null);

  /// Recorder whose amplitude/state drive the waveform.
  /// 驱动波形的录音器（振幅与状态）。
  final AudioRecorder? recorder;

  /// A stream of levels in dBFS (e.g. `recorder.onAmplitudeChanged` mapped
  /// to `current`). / dBFS 电平流。
  final Stream<double>? levels;

  /// External controller; created internally when null. When given, its own
  /// `minDb`/`maxDb`/smoothing apply. / 外部控制器；为空则内部创建。
  final WaveformController? controller;

  /// Overrides whether the waveform advances. Defaults to "recording" for a
  /// [recorder] and `true` for a [levels] stream.
  /// 覆盖是否推进；录音器默认为"录音中"，电平流默认为 true。
  final bool? active;

  /// Painting style. / 绘制样式。
  final WaveformStyle style;

  /// Solid color; defaults to `colorScheme.primary`. Ignored if [gradient].
  /// 纯色，默认 `colorScheme.primary`；设置 [gradient] 时忽略。
  final Color? color;

  /// Gradient applied across the full width. / 横跨整个宽度的渐变。
  final Gradient? gradient;

  /// Color of the idle dots; defaults to `colorScheme.outlineVariant`.
  /// 空闲圆点颜色，默认 `colorScheme.outlineVariant`。
  final Color? inactiveColor;

  /// Widget height. / 组件高度。
  final double height;

  /// Bar width (and minimum bar height / dot diameter).
  /// 柱宽（同时是最小柱高/圆点直径）。
  final double barWidth;

  /// Gap between bars. / 柱间距。
  final double spacing;

  /// Bar corner radius; defaults to fully rounded.
  /// 柱圆角半径，默认全圆角。
  final double? radius;

  /// dBFS mapped to the lowest bar; only used when no [controller] is given.
  /// 对应最低柱的 dBFS；仅在未提供 [controller] 时生效。
  final double minDb;

  /// dBFS mapped to the tallest bar; only used when no [controller] is given.
  /// 对应最高柱的 dBFS；仅在未提供 [controller] 时生效。
  final double maxDb;

  /// Fades the bars out towards both edges. / 两端渐隐。
  final bool fadeEdges;

  /// Overrides the scrolling direction. / 覆盖滚动方向。
  final TextDirection? textDirection;

  /// Accessibility label; a sensible default is provided.
  /// 无障碍标签；有默认值。
  final String? semanticLabel;

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform>
    with SingleTickerProviderStateMixin {
  late WaveformController _controller;
  bool _ownsController = false;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  StreamSubscription<Object?>? _levelSub;
  StreamSubscription<Object?>? _stateSub;
  bool _wasPaused = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _setUp();
  }

  @override
  void didUpdateWidget(AudioWaveform old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        old.recorder != widget.recorder ||
        old.levels != widget.levels ||
        old.active != widget.active) {
      _tearDown();
      _setUp();
    }
  }

  void _setUp() {
    final external = widget.controller;
    if (external != null) {
      _controller = external;
      _ownsController = false;
    } else {
      _controller = WaveformController(
        minDb: widget.minDb,
        maxDb: widget.maxDb,
      );
      _ownsController = true;
    }
    final recorder = widget.recorder;
    if (recorder != null) {
      _levelSub = recorder.onAmplitudeChanged.listen(
        (a) => _controller.addDb(a.current),
      );
      _stateSub = recorder.onStateChanged.listen(_onRecorderState);
      _applyActive(recorder.state == RecorderState.recording);
    } else if (widget.levels != null) {
      _levelSub = widget.levels!.listen(_controller.addDb);
      _applyActive(true);
    } else if (widget.active != null) {
      _applyActive(widget.active!);
    }
    _controller.addListener(_syncTicker);
    _syncTicker();
  }

  void _tearDown() {
    _controller.removeListener(_syncTicker);
    _levelSub?.cancel();
    _stateSub?.cancel();
    _levelSub = _stateSub = null;
    if (_ownsController) _controller.dispose();
  }

  void _onRecorderState(RecorderState s) {
    // A fresh recording starts from an empty history; resume keeps it.
    // 新录音从空历史开始；继续录音保留历史。
    if (s == RecorderState.recording && !_wasPaused) _controller.clear();
    _wasPaused = s == RecorderState.paused;
    _applyActive(s == RecorderState.recording);
  }

  void _applyActive(bool value) => _controller.active = widget.active ?? value;

  void _syncTicker() {
    if (_controller.active) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _last;
    _last = elapsed;
    _controller.advance(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tearDown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final direction = widget.textDirection ?? Directionality.of(context);
    final label =
        widget.semanticLabel ??
        (_controller.active ? 'Recording waveform' : 'Waveform');
    return Semantics(
      label: label,
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LivePainter(
              controller: _controller,
              style: widget.style,
              color: widget.color ?? scheme.primary,
              gradient: widget.gradient,
              inactiveColor: widget.inactiveColor ?? scheme.outlineVariant,
              barWidth: widget.barWidth,
              spacing: widget.spacing,
              radius: widget.radius,
              fadeEdges: widget.fadeEdges,
              rtl: direction == TextDirection.rtl,
            ),
          ),
        ),
      ),
    );
  }
}

// Shared geometry helpers / 共用的绘制辅助
Paint _shaderPaint(Color color, Gradient? gradient, Rect rect) {
  final paint = Paint()..isAntiAlias = true;
  if (gradient != null) {
    paint.shader = gradient.createShader(rect);
  } else {
    paint.color = color;
  }
  return paint;
}

void _withEdgeFade(Canvas canvas, Size size, bool fade, void Function() draw) {
  if (!fade || size.width < 40) {
    draw();
    return;
  }
  final rect = Offset.zero & size;
  canvas.saveLayer(rect, Paint());
  draw();
  final edge = math.min(0.18, 24 / size.width);
  final mask = Paint()
    ..blendMode = BlendMode.dstIn
    ..shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, 0),
      const [
        Color(0x00FFFFFF),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0x00FFFFFF),
      ],
      [0, edge, 1 - edge, 1],
    );
  canvas.drawRect(rect, mask);
  canvas.restore();
}

class _LivePainter extends CustomPainter {
  _LivePainter({
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
    _withEdgeFade(canvas, size, fadeEdges, () {
      final live = _shaderPaint(color, gradient, rect);
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
  bool shouldRepaint(_LivePainter old) =>
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

  /// Played color; defaults to `colorScheme.primary`. / 已播放颜色。
  final Color? color;

  /// Gradient for the played part. / 已播放部分的渐变。
  final Gradient? gradient;

  /// Unplayed color; defaults to `colorScheme.outlineVariant`. / 未播放颜色。
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
    final scheme = Theme.of(context).colorScheme;
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
            painter: _StaticPainter(
              levels: levels,
              progress: p,
              color: color ?? scheme.primary,
              gradient: gradient,
              inactiveColor: inactiveColor ?? scheme.outlineVariant,
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

class _StaticPainter extends CustomPainter {
  _StaticPainter({
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
    final live = _shaderPaint(color, gradient, rect);
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
  bool shouldRepaint(_StaticPainter old) =>
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
