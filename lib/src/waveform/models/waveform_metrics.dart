import 'package:flutter/foundation.dart';

/// Immutable statistical snapshot extracted from a `WaveformController`.
/// 从 `WaveformController` 提取的不可变统计特征快照。
@immutable
class WaveformMetrics {
  /// Creates a metrics snapshot. / 创建统计特征快照。
  const WaveformMetrics({
    required this.current,
    required this.average,
    required this.rms,
    required this.peak,
    required this.peakHold,
    required this.flux,
    required this.sampleCount,
  });

  /// Empty metrics when no samples have been recorded.
  /// 尚无采样时的空特征快照。
  static const WaveformMetrics zero = WaveformMetrics(
    current: 0,
    average: 0,
    rms: 0,
    peak: 0,
    peakHold: 0,
    flux: 0,
    sampleCount: 0,
  );

  /// Newest normalized sample (0–1). / 最新归一化采样值（0–1）。
  final double current;

  /// Mean normalized level across the analysis window (0–1).
  /// 分析窗口内的算术平均值（0–1）。
  final double average;

  /// Root-mean-square energy across the analysis window (0–1).
  /// 分析窗口内的均方根（RMS）能量（0–1）。
  final double rms;

  /// Maximum normalized sample inside the analysis window (0–1).
  /// 分析窗口内的峰值（0–1）。
  final double peak;

  /// Decaying peak-hold envelope value (0–1).
  /// 带保持与衰减的峰值包络（0–1）。
  final double peakHold;

  /// Mean absolute frame-to-frame difference (0–1), measuring vocal activity.
  /// 相邻采样平均绝对差值（0–1），反映语音瞬态变化率。
  final double flux;

  /// Number of samples analyzed in the window. / 参与分析的采样数量。
  final int sampleCount;

  /// Whether the signal is effectively silent. / 信号是否处于静音状态。
  bool get isSilent => sampleCount == 0 || (current < 0.004 && rms < 0.005);

  @override
  bool operator ==(Object other) =>
      other is WaveformMetrics &&
      other.current == current &&
      other.average == average &&
      other.rms == rms &&
      other.peak == peak &&
      other.peakHold == peakHold &&
      other.flux == flux &&
      other.sampleCount == sampleCount;

  @override
  int get hashCode =>
      Object.hash(current, average, rms, peak, peakHold, flux, sampleCount);

  @override
  String toString() =>
      'WaveformMetrics(current: ${current.toStringAsFixed(3)}, '
      'rms: ${rms.toStringAsFixed(3)}, peak: ${peak.toStringAsFixed(3)}, '
      'peakHold: ${peakHold.toStringAsFixed(3)}, flux: ${flux.toStringAsFixed(3)}, '
      'samples: $sampleCount)';
}
