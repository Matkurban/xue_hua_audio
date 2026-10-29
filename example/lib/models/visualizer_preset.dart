import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

/// Metadata descriptor for each built-in recording visualizer preset.
/// 内置录音可视化组件的元数据描述。
class VisualizerPreset {
  /// Creates a visualizer preset descriptor. / 创建可视化组件预设描述。
  const VisualizerPreset({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  /// Preset enum value. / 枚举类型。
  final RecordingVisualizerType type;

  /// Display title. / 显示名称。
  final String title;

  /// Short English/Chinese subtitle. / 简短副标题。
  final String subtitle;

  /// Leading icon. / 图标。
  final IconData icon;

  /// Catalog of all 17 live recording visualizer components (1 classic + 16
  /// minimalist custom visualizers).
  /// 全部 17 种实时录音可视化组件目录（1 款经典波形 + 16 款创新极简组件）。
  static const List<VisualizerPreset> all = [
    VisualizerPreset(
      type: RecordingVisualizerType.waveform,
      title: '经典波形',
      subtitle: 'AudioWaveform',
      icon: Icons.graphic_eq,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.pulseRing,
      title: '脉冲声环',
      subtitle: 'PulseRing',
      icon: Icons.radar,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.harmonicWave,
      title: '流体谐波',
      subtitle: 'HarmonicWave',
      icon: Icons.waves,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.radialSpectrum,
      title: '极坐标环',
      subtitle: 'RadialSpectrum',
      icon: Icons.donut_large,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.segmentedVu,
      title: '分段电平',
      subtitle: 'SegmentedVu',
      icon: Icons.equalizer,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.particleMatrix,
      title: '律动点阵',
      subtitle: 'ParticleMatrix',
      icon: Icons.blur_on,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.liquidOrb,
      title: '液态声球',
      subtitle: 'LiquidOrb',
      icon: Icons.bubble_chart,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.spectrogramHeatmap,
      title: '热力声谱',
      subtitle: 'Spectrogram',
      icon: Icons.grid_on,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.helixDna,
      title: '双螺旋链',
      subtitle: 'HelixDna',
      icon: Icons.all_inclusive,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.acousticPetal,
      title: '声学花瓣',
      subtitle: 'AcousticPetal',
      icon: Icons.filter_vintage,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.precisionMeter,
      title: '精密电桥',
      subtitle: 'PrecisionMeter',
      icon: Icons.speed,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.voicePendulum,
      title: '谐振钟摆',
      subtitle: 'VoicePendulum',
      icon: Icons.linear_scale,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.morphingPolygon,
      title: '几何多边形',
      subtitle: 'MorphingPolygon',
      icon: Icons.hexagon_outlined,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.kineticLouver,
      title: '韵律光栅',
      subtitle: 'KineticLouver',
      icon: Icons.view_week,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.orbitConstellation,
      title: '星轨星座',
      subtitle: 'Constellation',
      icon: Icons.hub_outlined,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.symmetricRibbon,
      title: '折纸丝带',
      subtitle: 'SymmetricRibbon',
      icon: Icons.auto_awesome_motion,
    ),
    VisualizerPreset(
      type: RecordingVisualizerType.oscilloscopeTrace,
      title: '荧光示波',
      subtitle: 'Oscilloscope',
      icon: Icons.show_chart,
    ),
  ];
}
