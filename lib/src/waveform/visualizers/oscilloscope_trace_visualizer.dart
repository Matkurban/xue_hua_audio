import 'package:flutter/widgets.dart';

import '../core/paint_utils.dart';
import '../core/visualizer_base.dart';
import '../core/waveform_controller.dart';
import '../parser/waveform_parser.dart';

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
        createActivePaint(
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
