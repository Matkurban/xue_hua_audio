import 'package:flutter/widgets.dart';

import '../../audio_recorder.dart';
import '../core/waveform_controller.dart';
import 'acoustic_petal_visualizer.dart';
import 'audio_waveform.dart';
import 'harmonic_wave_visualizer.dart';
import 'helix_dna_visualizer.dart';
import 'kinetic_louver_visualizer.dart';
import 'liquid_orb_visualizer.dart';
import 'morphing_polygon_visualizer.dart';
import 'orbit_constellation_visualizer.dart';
import 'oscilloscope_trace_visualizer.dart';
import 'particle_matrix_visualizer.dart';
import 'precision_meter_visualizer.dart';
import 'pulse_ring_visualizer.dart';
import 'radial_spectrum_visualizer.dart';
import 'segmented_vu_visualizer.dart';
import 'spectrogram_heatmap_visualizer.dart';
import 'symmetric_ribbon_visualizer.dart';
import 'voice_pendulum_visualizer.dart';

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

/// A unified recording visualizer widget that switches seamlessly across all
/// 17 built-in visualizer types ([RecordingVisualizerType]).
///
/// 统一录音可视化容器组件：可通过 [type] 在全部 17 种内置录音可视化组件之间
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
    return switch (type) {
      RecordingVisualizerType.waveform => AudioWaveform(
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
      ),
      RecordingVisualizerType.pulseRing => PulseRingVisualizer(
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
      ),
      RecordingVisualizerType.harmonicWave => HarmonicWaveVisualizer(
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
      ),
      RecordingVisualizerType.radialSpectrum => RadialSpectrumVisualizer(
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
      ),
      RecordingVisualizerType.segmentedVu => SegmentedVuVisualizer(
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
      ),
      RecordingVisualizerType.particleMatrix => ParticleMatrixVisualizer(
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
      ),
      RecordingVisualizerType.liquidOrb => LiquidOrbVisualizer(
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
      ),
      RecordingVisualizerType.spectrogramHeatmap =>
        SpectrogramHeatmapVisualizer(
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
        ),
      RecordingVisualizerType.helixDna => HelixDnaVisualizer(
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
      ),
      RecordingVisualizerType.acousticPetal => AcousticPetalVisualizer(
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
      ),
      RecordingVisualizerType.precisionMeter => PrecisionMeterVisualizer(
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
      ),
      RecordingVisualizerType.voicePendulum => VoicePendulumVisualizer(
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
      ),
      RecordingVisualizerType.morphingPolygon => MorphingPolygonVisualizer(
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
      ),
      RecordingVisualizerType.kineticLouver => KineticLouverVisualizer(
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
      ),
      RecordingVisualizerType.orbitConstellation =>
        OrbitConstellationVisualizer(
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
        ),
      RecordingVisualizerType.symmetricRibbon => SymmetricRibbonVisualizer(
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
      ),
      RecordingVisualizerType.oscilloscopeTrace => OscilloscopeTraceVisualizer(
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
      ),
    };
  }
}
