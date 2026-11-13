/// Live and static audio recording visualizers, controller, data models,
/// and deterministic parsing utilities.
///
/// 实时与静态录音波形/可视化组件、控制器、数据模型及纯函数解析工具。
library;

export 'core/visualizer_base.dart' show RecordingVisualizerBase, WaveformColors;
export 'core/waveform_controller.dart' show WaveformController;
export 'models/geometry_models.dart'
    show CubicSegment, HelixNode, LouverSlat, OrbitalNode;
export 'models/meter_models.dart'
    show PrecisionMeterReading, VuMeterState, VuZone;
export 'models/waveform_metrics.dart' show WaveformMetrics;
export 'parser/waveform_parser.dart' show WaveformDataParser;
export 'visualizers/acoustic_petal_visualizer.dart'
    show AcousticPetalVisualizer;
export 'visualizers/audio_waveform.dart' show AudioWaveform, WaveformStyle;
export 'visualizers/harmonic_wave_visualizer.dart' show HarmonicWaveVisualizer;
export 'visualizers/helix_dna_visualizer.dart' show HelixDnaVisualizer;
export 'visualizers/kinetic_louver_visualizer.dart'
    show KineticLouverVisualizer;
export 'visualizers/liquid_orb_visualizer.dart' show LiquidOrbVisualizer;
export 'visualizers/morphing_polygon_visualizer.dart'
    show MorphingPolygonVisualizer;
export 'visualizers/orbit_constellation_visualizer.dart'
    show OrbitConstellationVisualizer;
export 'visualizers/oscilloscope_trace_visualizer.dart'
    show OscilloscopeTraceVisualizer;
export 'visualizers/particle_matrix_visualizer.dart'
    show ParticleMatrixVisualizer;
export 'visualizers/precision_meter_visualizer.dart'
    show PrecisionMeterVisualizer;
export 'visualizers/pulse_ring_visualizer.dart' show PulseRingVisualizer;
export 'visualizers/radial_spectrum_visualizer.dart'
    show RadialSpectrumVisualizer;
export 'visualizers/recording_visualizer.dart'
    show RecordingVisualizer, RecordingVisualizerType;
export 'visualizers/segmented_vu_visualizer.dart' show SegmentedVuVisualizer;
export 'visualizers/spectrogram_heatmap_visualizer.dart'
    show SpectrogramHeatmapVisualizer;
export 'visualizers/static_waveform.dart' show StaticWaveform;
export 'visualizers/symmetric_ribbon_visualizer.dart'
    show SymmetricRibbonVisualizer;
export 'visualizers/voice_pendulum_visualizer.dart'
    show VoicePendulumVisualizer;
