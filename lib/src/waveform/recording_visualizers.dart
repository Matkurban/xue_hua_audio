import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../audio_recorder.dart';
import '../types/player_state.dart';
import 'advanced_visualizers.dart';
import 'audio_waveform.dart';

export 'advanced_visualizers.dart';
import 'waveform_controller.dart';
import 'waveform_parser.dart';

/// Visualizer preset types supported by [RecordingVisualizer].
/// [RecordingVisualizer] 支持的录音可视化组件类型。
enum RecordingVisualizerType {
  /// Classic scrolling waveform ([AudioWaveform]). / 经典滚动波形（[AudioWaveform]）。
  waveform,

  /// Concentric breathing core and expanding acoustic ripple rings
  /// ([PulseRingVisualizer]). / 同心呼吸脉冲声环（[PulseRingVisualizer]）。
  pulseRing,

  /// Multi-layer fluid harmonic sine ribbons ([HarmonicWaveVisualizer]).
  /// 多层丝绸流体谐波弦（[HarmonicWaveVisualizer]）。
  harmonicWave,

  /// Circular polar symmetric spectrum halo ([RadialSpectrumVisualizer]).
  /// 极坐标对称环形声谱（[RadialSpectrumVisualizer]）。
  radialSpectrum,

  /// Minimalist segmented LED matrix with decaying peak-hold caps
  /// ([SegmentedVuVisualizer]). / 极简分段式 LED 电平矩阵（[SegmentedVuVisualizer]）。
  segmentedVu,

  /// Kinetic dot-matrix acoustic particle field ([ParticleMatrixVisualizer]).
  /// 声场律动点阵星云（[ParticleMatrixVisualizer]）。
  particleMatrix,

  /// Morphing closed-Bezier liquid acoustic orb ([LiquidOrbVisualizer]).
  /// 液态几何流体声球（[LiquidOrbVisualizer]）。
  liquidOrb,

  /// Time-frequency thermal spectrogram heatmap ([SpectrogramHeatmapVisualizer]).
  /// 实时声谱热力瀑布图（[SpectrogramHeatmapVisualizer]）。
  spectrogramHeatmap,

  /// 3D-projected double-helix acoustic DNA strand ([HelixDnaVisualizer]).
  /// 双螺旋声波基因链（[HelixDnaVisualizer]）。
  helixDna,

  /// Radial geometric lotus/mandala petals ([AcousticPetalVisualizer]).
  /// 几何声学花瓣曼陀罗（[AcousticPetalVisualizer]）。
  acousticPetal,

  /// Studio-grade dual ballistic RMS + peak bridge ([PrecisionMeterVisualizer]).
  /// 极简录音室精密双轨电桥（[PrecisionMeterVisualizer]）。
  precisionMeter,

  /// Coupled harmonic Mach's pendulum wave ([VoicePendulumVisualizer]).
  /// 声学耦合谐振钟摆波（[VoicePendulumVisualizer]）。
  voicePendulum,

  /// Concentric morphing geometric polygon tunnel ([MorphingPolygonVisualizer]).
  /// 多维极简几何多边形声场（[MorphingPolygonVisualizer]）。
  morphingPolygon,

  /// Architectural tilting kinetic louver slats ([KineticLouverVisualizer]).
  /// 建筑感韵律百叶窗光栅（[KineticLouverVisualizer]）。
  kineticLouver,

  /// Revolving orbital nodes with proximity links ([OrbitConstellationVisualizer]).
  /// 星轨声场星座引力网（[OrbitConstellationVisualizer]）。
  orbitConstellation,

  /// Mirrored origami diamond facet ribbon ([SymmetricRibbonVisualizer]).
  /// 极简折纸镜像钻石丝带（[SymmetricRibbonVisualizer]）。
  symmetricRibbon,

  /// Phosphor graticule oscilloscope trace ([OscilloscopeTraceVisualizer]).
  /// 极简荧光扫描示波器（[OscilloscopeTraceVisualizer]）。
  oscilloscopeTrace,
}

/// Base widget for live recording visualizers driven by an [AudioRecorder],
/// a dBFS [levels] stream, or a [WaveformController].
///
/// 由 [AudioRecorder]、dBFS [levels] 流或 [WaveformController] 驱动的
/// 实时录音可视化组件基类。
abstract class RecordingVisualizerBase extends StatefulWidget {
  /// Creates a recording visualizer base. / 创建录音可视化组件基类。
  const RecordingVisualizerBase({
    super.key,
    this.recorder,
    this.levels,
    this.controller,
    this.active,
    this.color,
    this.gradient,
    this.inactiveColor,
    this.height = 72,
    this.minDb = -50,
    this.maxDb = 0,
    this.semanticLabel,
  }) : assert(recorder == null || levels == null);

  /// Recorder whose amplitude/state drive the visualizer.
  /// 驱动可视化组件的录音器（振幅与状态）。
  final AudioRecorder? recorder;

  /// A stream of levels in dBFS. / dBFS 电平流。
  final Stream<double>? levels;

  /// External controller; created internally when null.
  /// 外部控制器；为空则内部自动创建。
  final WaveformController? controller;

  /// Overrides whether the visualizer advances.
  /// 覆盖是否处于激活推进状态。
  final bool? active;

  /// Primary active color; defaults to [WaveformColors.active].
  /// 主活动颜色，默认 [WaveformColors.active]。
  final Color? color;

  /// Optional gradient applied across the active geometry.
  /// 可选渐变色。
  final Gradient? gradient;

  /// Idle / unlit color; defaults to [WaveformColors.inactive].
  /// 空闲/未点亮颜色，默认 [WaveformColors.inactive]。
  final Color? inactiveColor;

  /// Widget height in logical pixels. / 组件高度（逻辑像素）。
  final double height;

  /// dBFS floor mapped to 0 when creating an internal controller.
  /// 内部创建控制器时的噪声门限（dBFS）。
  final double minDb;

  /// dBFS ceiling mapped to 1 when creating an internal controller.
  /// 内部创建控制器时的满刻度上限（dBFS）。
  final double maxDb;

  /// Accessibility label. / 无障碍语义标签。
  final String? semanticLabel;

  /// Default accessibility label when [semanticLabel] is null.
  /// 未指定 [semanticLabel] 时的默认无障碍标签。
  @protected
  String defaultSemanticLabel(bool isActive);

  /// Builds the [CustomPainter] driving this visualizer.
  /// 构建当前可视化组件的 [CustomPainter]。
  @protected
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  );

  @override
  State<RecordingVisualizerBase> createState() =>
      _RecordingVisualizerBaseState();
}

class _RecordingVisualizerBaseState extends State<RecordingVisualizerBase>
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
  void didUpdateWidget(covariant RecordingVisualizerBase old) {
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
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final label =
        widget.semanticLabel ?? widget.defaultSemanticLabel(_controller.active);
    return Semantics(
      label: label,
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: widget.buildPainter(context, _controller, direction),
          ),
        ),
      ),
    );
  }
}

Paint _createActivePaint(Color color, Gradient? gradient, Rect rect) {
  final paint = Paint()..isAntiAlias = true;
  if (gradient != null) {
    paint.shader = gradient.createShader(rect);
  } else {
    paint.color = color;
  }
  return paint;
}

// ===========================================================================
// 1. PulseRingVisualizer — 同心呼吸脉冲声环组件
// ===========================================================================

/// A minimalist concentric pulse-ring visualizer featuring a breathing core
/// orb, expanding acoustic ripple waves, and an optional peak-hold halo arc.
///
/// 极简同心呼吸脉冲声环组件：中心声核随实时语音能量呼吸缩放，向外扩散多层渐隐
/// 声波涟漪，并在外圈绘制平滑衰减的峰值保持弧线。
class PulseRingVisualizer extends RecordingVisualizerBase {
  /// Creates a pulse-ring visualizer. / 创建同心呼吸脉冲声环组件。
  const PulseRingVisualizer({
    super.key,
    super.recorder,
    super.levels,
    super.controller,
    super.active,
    super.color,
    super.gradient,
    super.inactiveColor,
    super.height = 88,
    super.minDb,
    super.maxDb,
    super.semanticLabel,
    this.ringCount = 3,
    this.minRadiusRatio = 0.20,
    this.showPeakArc = true,
  }) : assert(ringCount >= 1 && ringCount <= 8),
       assert(minRadiusRatio > 0.05 && minRadiusRatio < 0.8);

  /// Number of expanding ripple rings (`1..8`). / 扩散脉冲环层数（`1..8`）。
  final int ringCount;

  /// Resting core radius as a fraction of the half-shortest-side.
  /// 静息状态下中心圆半径占半短边的比例。
  final double minRadiusRatio;

  /// Whether to render the outer peak-hold halo arc.
  /// 是否绘制外圈峰值保持弧线。
  final bool showPeakArc;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording pulse ring' : 'Pulse ring visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _PulseRingPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    ringCount: ringCount,
    minRadiusRatio: minRadiusRatio,
    showPeakArc: showPeakArc,
  );
}

class _PulseRingPainter extends CustomPainter {
  _PulseRingPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.ringCount,
    required this.minRadiusRatio,
    required this.showPeakArc,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int ringCount;
  final double minRadiusRatio;
  final bool showPeakArc;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 2) return;
    final center = Offset(size.width / 2, size.height / 2);
    final metrics = controller.computeMetrics(window: 20);
    final baseR = maxR * minRadiusRatio;
    final energy = metrics.current * 0.65 + metrics.rms * 0.35;

    // Subtle outer guide track. / 极简外圈基准轨道。
    final trackPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = inactiveColor.withValues(alpha: 0.35);
    canvas.drawCircle(center, maxR * 0.92, trackPaint);

    // Expanding concentric ripple rings. / 向外扩散的同心声波涟漪环。
    final t = controller.elapsedSeconds;
    for (var i = 0; i < ringCount; i++) {
      final rawPhase = controller.active
          ? (t * 0.65 + i / ringCount) % 1.0
          : (i + 1) / (ringCount + 1);
      final ringR =
          baseR + (maxR * 0.88 - baseR) * rawPhase * (0.45 + 0.55 * energy);
      final fade = (1.0 - rawPhase).clamp(0.0, 1.0);
      final alpha = controller.active && !metrics.isSilent
          ? (fade * (0.18 + 0.62 * energy)).clamp(0.0, 1.0)
          : (0.18 * (1.0 - i / (ringCount + 1))).clamp(0.0, 1.0);
      final ringPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + 1.8 * energy * fade
        ..color = (metrics.isSilent ? inactiveColor : color).withValues(
          alpha: alpha,
        );
      canvas.drawCircle(center, ringR, ringPaint);
    }

    // Peak-hold precision arc on the outer track. / 外圈峰值保持指示弧。
    if (showPeakArc && metrics.peakHold > 0.01) {
      final sweep = 2 * math.pi * metrics.peakHold.clamp(0.0, 1.0);
      final arcRect = Rect.fromCircle(center: center, radius: maxR * 0.92);
      final arcPaint = _createActivePaint(color, gradient, arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arcPaint);
    }

    // Soft inner glow halo. / 中心柔和声晕。
    final coreR = baseR * (1.0 + 1.15 * energy);
    if (!metrics.isSilent) {
      final glowPaint = Paint()
        ..isAntiAlias = true
        ..color = color.withValues(alpha: (0.16 + 0.24 * energy).clamp(0, 1));
      canvas.drawCircle(center, coreR * 1.35, glowPaint);
    }

    // Breathing central orb. / 呼吸态中心声核。
    final coreRect = Rect.fromCircle(center: center, radius: coreR);
    final corePaint = metrics.isSilent && !controller.active
        ? (Paint()
            ..isAntiAlias = true
            ..color = inactiveColor)
        : _createActivePaint(color, gradient, coreRect);
    canvas.drawCircle(center, coreR, corePaint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.ringCount != ringCount ||
      old.minRadiusRatio != minRadiusRatio ||
      old.showPeakArc != showPeakArc;
}

// ===========================================================================
// 2. HarmonicWaveVisualizer — 多层丝绸流体谐波组件
// ===========================================================================

/// A fluid multi-ribbon harmonic wave visualizer inspired by minimalist AI
/// voice interfaces.
///
/// 多层丝绸流体谐波可视化组件：多条相位交错的谐波正弦曲线在两端平滑收敛于中线，
/// 中部随实时语音包络与瞬态能量丝滑起伏。
class HarmonicWaveVisualizer extends RecordingVisualizerBase {
  /// Creates a harmonic wave visualizer. / 创建多层丝绸流体谐波组件。
  const HarmonicWaveVisualizer({
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
    this.waveCount = 4,
    this.strokeWidth = 2.2,
    this.fillPrimary = true,
    this.speed = 1.0,
  }) : assert(waveCount >= 1 && waveCount <= 8),
       assert(strokeWidth > 0),
       assert(speed > 0);

  /// Number of harmonic ribbon layers (`1..8`). / 谐波曲线层数（`1..8`）。
  final int waveCount;

  /// Primary ribbon stroke width. / 主谐波线宽。
  final double strokeWidth;

  /// Whether to fill the mirrored silhouette of the primary wave with a soft
  /// translucent glow.
  /// 是否为主谐波填充半透明镜像柔光面积。
  final bool fillPrimary;

  /// Phase animation speed multiplier. / 相位流动速度倍率。
  final double speed;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording harmonic wave' : 'Harmonic wave visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _HarmonicWavePainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    waveCount: waveCount,
    strokeWidth: strokeWidth,
    fillPrimary: fillPrimary,
    speed: speed,
  );
}

class _HarmonicWavePainter extends CustomPainter {
  _HarmonicWavePainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.waveCount,
    required this.strokeWidth,
    required this.fillPrimary,
    required this.speed,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int waveCount;
  final double strokeWidth;
  final bool fillPrimary;
  final double speed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final midY = size.height / 2;
    final maxAmp = size.height * 0.44;
    final metrics = controller.computeMetrics(window: 24);
    final rect = Offset.zero & size;

    // Baseline horizon when completely idle and silent.
    // 完全静息时显示极简水平基准线。
    if (metrics.isSilent && !controller.active) {
      final idlePaint = Paint()
        ..isAntiAlias = true
        ..color = inactiveColor
        ..strokeWidth = math.min(2.0, strokeWidth)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), idlePaint);
      return;
    }

    final energy =
        (metrics.current * 0.55 + metrics.rms * 0.35 + metrics.flux * 0.25)
            .clamp(0.0, 1.0);
    final effectiveAmp = math.max(
      strokeWidth,
      maxAmp * (controller.active ? math.max(0.04, energy) : energy),
    );
    final t = controller.elapsedSeconds * speed;
    final steps = math.max(32, (size.width / 4).round().clamp(32, 140));

    for (var w = waveCount - 1; w >= 0; w--) {
      final isPrimary = w == 0;
      final layerRatio = 1.0 - (w / math.max(1, waveCount)) * 0.62;
      final freq = 1.5 + w * 0.65;
      final phase = t * (3.2 + w * 0.85) + w * 1.15;
      final path = Path();
      final mirrorPath = fillPrimary && isPrimary ? Path() : null;

      for (var s = 0; s <= steps; s++) {
        final normX = s / steps;
        final x = normX * size.width;
        // Raised-cosine bell window: 0 at both ends, 1 in the center.
        // 升余弦钟形窗函数：两端平滑归零，中心达到峰值。
        final bell = math.pow(math.sin(normX * math.pi), 1.6).toDouble();
        final histSample = controller.sampleInterpolated((1.0 - normX) * 12.0);
        final localBoost = 0.65 + 0.35 * histSample;
        final waveVal = math.sin(normX * math.pi * 2 * freq - phase);
        final dy = waveVal * effectiveAmp * layerRatio * bell * localBoost;
        final y = midY + dy;
        if (s == 0) {
          path.moveTo(x, y);
          mirrorPath?.moveTo(x, midY - dy * 0.75);
        } else {
          path.lineTo(x, y);
          mirrorPath?.lineTo(x, midY - dy * 0.75);
        }
      }

      if (mirrorPath != null) {
        final fillArea = Path.from(path);
        for (var s = steps; s >= 0; s--) {
          final normX = s / steps;
          final x = normX * size.width;
          final bell = math.pow(math.sin(normX * math.pi), 1.6).toDouble();
          final histSample = controller.sampleInterpolated(
            (1.0 - normX) * 12.0,
          );
          final localBoost = 0.65 + 0.35 * histSample;
          final waveVal = math.sin(normX * math.pi * 2 * freq - phase);
          final dy = waveVal * effectiveAmp * layerRatio * bell * localBoost;
          fillArea.lineTo(x, midY - dy * 0.75);
        }
        fillArea.close();
        final fillPaint = _createActivePaint(
          color.withValues(alpha: 0.16),
          gradient,
          rect,
        )..style = PaintingStyle.fill;
        if (gradient != null) {
          fillPaint.color = const Color(0x29FFFFFF);
        }
        canvas.drawPath(fillArea, fillPaint);
      }

      final alpha = isPrimary
          ? 0.95
          : (0.65 * (1.0 - w / (waveCount + 0.5))).clamp(0.15, 0.75);
      final ribbonPaint =
          _createActivePaint(
              color.withValues(alpha: alpha),
              isPrimary ? gradient : null,
              rect,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = isPrimary
                ? strokeWidth
                : math.max(1.0, strokeWidth * 0.65)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, ribbonPaint);
    }
  }

  @override
  bool shouldRepaint(_HarmonicWavePainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.waveCount != waveCount ||
      old.strokeWidth != strokeWidth ||
      old.fillPrimary != fillPrimary ||
      old.speed != speed;
}

// ===========================================================================
// 3. RadialSpectrumVisualizer — 极坐标环形对称声谱组件
// ===========================================================================

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
    final activePaint = _createActivePaint(color, gradient, bounds)
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

// ===========================================================================
// 4. SegmentedVuVisualizer — 极简工业风分段电平矩阵组件
// ===========================================================================

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

// ===========================================================================
// 5. ParticleMatrixVisualizer — 声场律动点阵星云组件
// ===========================================================================

/// A minimalist kinetic dot-matrix visualizer where rows of micro-spheres
/// expand vertically and scale in luminance and radius with the rolling
/// acoustic wave.
///
/// 声场律动点阵星云组件：多行微粒圆点随滚动声波在垂直方向对称舒展，且粒径与
/// 透明度随局部振幅动态缩放；静音时收敛为极简点阵地平线。
class ParticleMatrixVisualizer extends RecordingVisualizerBase {
  /// Creates a particle matrix visualizer. / 创建声场律动点阵星云组件。
  const ParticleMatrixVisualizer({
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
    this.columns = 28,
    this.rows = 5,
    this.maxDotRadius = 3.2,
    this.minDotRadius = 1.25,
    this.fadeEdges = true,
    this.textDirection,
  }) : assert(columns >= 4 && columns <= 96),
       assert(rows >= 1 && rows <= 15),
       assert(maxDotRadius >= minDotRadius && minDotRadius > 0);

  /// Number of horizontal particle columns (`4..96`).
  /// 水平方向粒子列数（`4..96`）。
  final int columns;

  /// Number of vertical harmonic particle rows (`1..15`, odd numbers include
  /// a center horizon row).
  /// 垂直方向粒子行数（`1..15`）。
  final int rows;

  /// Maximum radius of an excited particle dot. / 满振幅时的最大粒子半径。
  final double maxDotRadius;

  /// Minimum radius of an idle particle dot. / 静息时的最小粒子半径。
  final double minDotRadius;

  /// Whether to softly fade particle opacity near the left and right edges.
  /// 是否在左右边缘平滑渐隐。
  final bool fadeEdges;

  /// Overrides the horizontal flow direction. / 覆盖水平滚动方向。
  final TextDirection? textDirection;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording particle matrix' : 'Particle matrix visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection ambientDirection,
  ) => _ParticleMatrixPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    columns: columns,
    rows: rows,
    maxDotRadius: maxDotRadius,
    minDotRadius: minDotRadius,
    fadeEdges: fadeEdges,
    rtl: (textDirection ?? ambientDirection) == TextDirection.rtl,
  );
}

class _ParticleMatrixPainter extends CustomPainter {
  _ParticleMatrixPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.columns,
    required this.rows,
    required this.maxDotRadius,
    required this.minDotRadius,
    required this.fadeEdges,
    required this.rtl,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int columns;
  final int rows;
  final double maxDotRadius;
  final double minDotRadius;
  final bool fadeEdges;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 4 || size.height <= 4) return;
    final midY = size.height / 2;
    final maxSpread = (size.height / 2) - maxDotRadius - 1;
    final colStep = size.width / columns;
    final shift = controller.active ? controller.phase : 0.0;
    final t = controller.elapsedSeconds;

    for (var c = 0; c < columns; c++) {
      // Slot 0 is on the newest end side. / 槽位 0 位于最新采样进入的一端。
      final rawX = (c + 0.5) * colStep;
      final x = rtl ? rawX : size.width - rawX;
      final v = controller.sampleInterpolated(c + shift).clamp(0.0, 1.0);
      final edgeFactor = fadeEdges
          ? math.sin(((c + 0.5) / columns) * math.pi).clamp(0.15, 1.0)
          : 1.0;

      for (var r = 0; r < rows; r++) {
        // Normalized vertical offset in [-1, 1]; 0 is the center row.
        // 归一化垂直偏移 [-1, 1]，0 为中心行。
        final rowNorm = rows == 1 ? 0.0 : (r / (rows - 1)) * 2.0 - 1.0;
        final distFromCenter = rowNorm.abs();
        final waveJitter = controller.active && v > 0.004
            ? 0.06 * v * math.sin(t * 5.0 + c * 0.45 + r)
            : 0.0;
        final restSpread = 0.14 * maxSpread * rowNorm;
        final activeSpread =
            maxSpread * rowNorm * (0.18 + 0.82 * v + waveJitter);
        final y = midY + (v > 0.004 ? activeSpread : restSpread);

        final layerScale = 1.0 - 0.38 * distFromCenter;
        final dotR =
            (minDotRadius + (maxDotRadius - minDotRadius) * v * layerScale)
                .clamp(minDotRadius * 0.75, maxDotRadius);

        final isActiveDot = v > 0.004;
        final alpha = isActiveDot
            ? ((0.30 + 0.70 * v) * (1.0 - 0.45 * distFromCenter) * edgeFactor)
                  .clamp(0.12, 1.0)
            : ((0.45 - 0.28 * distFromCenter) * edgeFactor).clamp(0.10, 0.55);

        final dotPaint = Paint()
          ..isAntiAlias = true
          ..color = (isActiveDot ? color : inactiveColor).withValues(
            alpha: alpha,
          );
        canvas.drawCircle(Offset(x, y), dotR, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParticleMatrixPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.columns != columns ||
      old.rows != rows ||
      old.maxDotRadius != maxDotRadius ||
      old.minDotRadius != minDotRadius ||
      old.fadeEdges != fadeEdges ||
      old.rtl != rtl;
}

// ===========================================================================
// 6. LiquidOrbVisualizer — 液态几何流体声球组件
// ===========================================================================

/// A minimalist morphing liquid acoustic orb built from smooth closed
/// cubic-Bezier splines (`C¹` continuous) that undulate in response to
/// multi-band voice energy.
///
/// 液态几何流体声球组件：由多层平滑闭合的三次贝塞尔样条曲线（`C¹` 连续无尖角）
/// 构成，静息时呈极简几何圆，说话时随多频段人声能量呈现有机流体律动。
class LiquidOrbVisualizer extends RecordingVisualizerBase {
  /// Creates a liquid orb visualizer. / 创建液态几何流体声球组件。
  const LiquidOrbVisualizer({
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
    this.lobeCount = 8,
    this.layerCount = 3,
    this.strokeOnly = false,
  }) : assert(lobeCount >= 4 && lobeCount <= 24),
       assert(layerCount >= 1 && layerCount <= 5);

  /// Number of spline anchor lobes around the perimeter (`4..24`).
  /// 流体球周向控制瓣数量（`4..24`）。
  final int lobeCount;

  /// Number of overlapping translucent orb layers (`1..5`).
  /// 交叠半透明流体层数（`1..5`）。
  final int layerCount;

  /// When true, renders sleek contour outlines instead of filled silhouettes.
  /// 为 true 时仅绘制极简轮廓线，不填充内部。
  final bool strokeOnly;

  @override
  String defaultSemanticLabel(bool isActive) =>
      isActive ? 'Recording liquid orb' : 'Liquid orb visualizer';

  @override
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  ) => _LiquidOrbPainter(
    controller: controller,
    color: color ?? WaveformColors.active,
    gradient: gradient,
    inactiveColor: inactiveColor ?? WaveformColors.inactive,
    lobeCount: lobeCount,
    layerCount: layerCount,
    strokeOnly: strokeOnly,
  );
}

class _LiquidOrbPainter extends CustomPainter {
  _LiquidOrbPainter({
    required this.controller,
    required this.color,
    required this.gradient,
    required this.inactiveColor,
    required this.lobeCount,
    required this.layerCount,
    required this.strokeOnly,
  }) : super(repaint: controller);

  final WaveformController controller;
  final Color color;
  final Gradient? gradient;
  final Color inactiveColor;
  final int lobeCount;
  final int layerCount;
  final bool strokeOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = math.min(size.width, size.height) / 2;
    if (maxR <= 4) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = maxR * 0.46;
    final maxExcursion = maxR * 0.44;
    final bands = WaveformDataParser.extractFrequencyBands(
      controller,
      lobeCount,
    );
    final metrics = controller.computeMetrics(window: 20);
    final t = controller.elapsedSeconds;
    final orbBounds = Rect.fromCircle(center: center, radius: maxR);

    for (var layer = layerCount - 1; layer >= 0; layer--) {
      final isFront = layer == 0;
      final dir = layer.isEven ? 1.0 : -1.0;
      final rotation = controller.active
          ? t * (0.45 + layer * 0.22) * dir + layer * 0.7
          : layer * 0.5;
      final layerScale = 1.0 - layer * 0.10;

      final radii = List<double>.generate(lobeCount, (i) {
        final bandVal = bands[(i + layer * 2) % lobeCount];
        final harmonic = controller.active
            ? 0.05 * math.sin(t * (3.0 + layer) + i * (2 * math.pi / lobeCount))
            : 0.0;
        final excursion =
            maxExcursion * (bandVal * 0.85 + metrics.rms * 0.15 + harmonic);
        return (baseR + excursion) * layerScale;
      });

      final segments = WaveformDataParser.computeClosedSplineSegments(
        radii,
        center,
        rotation: rotation,
      );
      if (segments.isEmpty) continue;

      final path = Path()..moveTo(segments.first.p0.dx, segments.first.p0.dy);
      for (final seg in segments) {
        path.cubicTo(
          seg.c1.dx,
          seg.c1.dy,
          seg.c2.dx,
          seg.c2.dy,
          seg.p1.dx,
          seg.p1.dy,
        );
      }
      path.close();

      final baseColor = metrics.isSilent && !controller.active
          ? inactiveColor
          : color;
      final alpha = isFront
          ? (strokeOnly ? 0.95 : 0.78)
          : (0.28 + 0.16 * (layerCount - layer) / layerCount).clamp(0.18, 0.55);

      if (!strokeOnly) {
        final fillPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill;
        if (isFront && gradient != null && !metrics.isSilent) {
          fillPaint.shader = gradient!.createShader(orbBounds);
        } else {
          fillPaint.color = baseColor.withValues(alpha: alpha);
        }
        canvas.drawPath(path, fillPaint);
      }

      final strokePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = isFront ? 2.0 : 1.2
        ..color = baseColor.withValues(alpha: (alpha + 0.18).clamp(0.25, 1.0));
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_LiquidOrbPainter old) =>
      old.controller != controller ||
      old.color != color ||
      old.gradient != gradient ||
      old.inactiveColor != inactiveColor ||
      old.lobeCount != lobeCount ||
      old.layerCount != layerCount ||
      old.strokeOnly != strokeOnly;
}

// ===========================================================================
// Unified RecordingVisualizer Switcher — 统一录音可视化切换组件
// ===========================================================================

/// A unified recording visualizer widget that switches seamlessly across all
/// 7 built-in visualizer types ([RecordingVisualizerType]).
///
/// 统一录音可视化容器组件：可通过 [type] 在全部 7 种内置录音可视化组件之间
/// 无缝切换，共享同一个 [recorder]、[levels] 或 [controller]。
class RecordingVisualizer extends StatelessWidget {
  /// Creates a unified recording visualizer. / 创建统一录音可视化组件。
  const RecordingVisualizer({
    super.key,
    this.type = RecordingVisualizerType.waveform,
    this.waveformStyle = WaveformStyle.bars,
    this.recorder,
    this.levels,
    this.controller,
    this.active,
    this.color,
    this.gradient,
    this.inactiveColor,
    this.height = 76,
    this.minDb = -50,
    this.maxDb = 0,
    this.semanticLabel,
  }) : assert(recorder == null || levels == null);

  /// Selected visualizer component type. / 所选的可视化组件类型。
  final RecordingVisualizerType type;

  /// Style used when [type] is [RecordingVisualizerType.waveform].
  /// 当 [type] 为 [RecordingVisualizerType.waveform] 时使用的波形子样式。
  final WaveformStyle waveformStyle;

  /// Recorder whose amplitude/state drive the visualizer.
  /// 驱动可视化组件的录音器。
  final AudioRecorder? recorder;

  /// A stream of levels in dBFS. / dBFS 电平流。
  final Stream<double>? levels;

  /// External controller; created internally when null.
  /// 外部控制器；为空则内部自动创建。
  final WaveformController? controller;

  /// Overrides whether the visualizer advances. / 覆盖激活推进状态。
  final bool? active;

  /// Primary active color. / 主活动颜色。
  final Color? color;

  /// Optional gradient. / 可选渐变色。
  final Gradient? gradient;

  /// Idle color. / 空闲颜色。
  final Color? inactiveColor;

  /// Widget height. / 组件高度。
  final double height;

  /// Minimum dBFS floor. / 最小 dBFS 门限。
  final double minDb;

  /// Maximum dBFS ceiling. / 最大 dBFS 上限。
  final double maxDb;

  /// Accessibility label. / 无障碍语义标签。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case RecordingVisualizerType.waveform:
        return AudioWaveform(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          style: waveformStyle,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.pulseRing:
        return PulseRingVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.harmonicWave:
        return HarmonicWaveVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.radialSpectrum:
        return RadialSpectrumVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.segmentedVu:
        return SegmentedVuVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.particleMatrix:
        return ParticleMatrixVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.liquidOrb:
        return LiquidOrbVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.spectrogramHeatmap:
        return SpectrogramHeatmapVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.helixDna:
        return HelixDnaVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.acousticPetal:
        return AcousticPetalVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.precisionMeter:
        return PrecisionMeterVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.voicePendulum:
        return VoicePendulumVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.morphingPolygon:
        return MorphingPolygonVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.kineticLouver:
        return KineticLouverVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.orbitConstellation:
        return OrbitConstellationVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.symmetricRibbon:
        return SymmetricRibbonVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
      case RecordingVisualizerType.oscilloscopeTrace:
        return OscilloscopeTraceVisualizer(
          recorder: recorder,
          levels: levels,
          controller: controller,
          active: active,
          color: color,
          gradient: gradient,
          inactiveColor: inactiveColor,
          height: height,
          minDb: minDb,
          maxDb: maxDb,
          semanticLabel: semanticLabel,
        );
    }
  }
}
