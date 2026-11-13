import 'package:flutter/foundation.dart';

/// Color zone of a segmented VU / LED level meter.
/// 分段式 VU / LED 电平表的颜色区间。
enum VuZone {
  /// Safe operating zone (e.g. green / primary). / 安全区间（正常电平）。
  normal,

  /// Elevated zone approaching headroom limit (e.g. amber). / 预警区间（较高电平）。
  warning,

  /// Peak / clipping zone near 0 dBFS (e.g. red / coral). / 峰值/过载区间（接近满刻度）。
  danger,
}

/// Quantized state of a single segmented VU / LED column.
/// 单个分段式 VU / LED 电平柱的量化状态。
@immutable
class VuMeterState {
  /// Creates a quantized VU meter state. / 创建分段式电平表量化状态。
  const VuMeterState({
    required this.totalSegments,
    required this.activeSegments,
    required this.peakSegment,
    required this.warningStartSegment,
    required this.dangerStartSegment,
  }) : assert(totalSegments > 0),
       assert(activeSegments >= 0 && activeSegments <= totalSegments);

  /// Total number of discrete segments in the column. / 总分段数。
  final int totalSegments;

  /// Number of currently lit segments (`0..totalSegments`).
  /// 当前点亮的分段数（`0..totalSegments`）。
  final int activeSegments;

  /// Zero-based index of the peak-hold segment, or `null` when idle.
  /// 峰值保持段索引（从 0 开始），空闲时为 `null`。
  final int? peakSegment;

  /// First segment index belonging to [VuZone.warning].
  /// 进入 [VuZone.warning] 预警区的起始段索引。
  final int warningStartSegment;

  /// First segment index belonging to [VuZone.danger].
  /// 进入 [VuZone.danger] 峰值区的起始段索引。
  final int dangerStartSegment;

  /// Returns the [VuZone] of segment [index] (`0..totalSegments - 1`).
  /// 返回第 [index] 段的色彩区间 [VuZone]。
  VuZone zoneOf(int index) {
    if (index >= dangerStartSegment) return VuZone.danger;
    if (index >= warningStartSegment) return VuZone.warning;
    return VuZone.normal;
  }
}

/// Ballistic studio meter reading parsed for `PrecisionMeterVisualizer`.
/// 为精密录音室电桥组件解析的阻尼电平与峰值读数。
@immutable
class PrecisionMeterReading {
  /// Creates a precision meter reading. / 创建精密电平表读数。
  const PrecisionMeterReading({
    required this.instantaneous,
    required this.ballisticRms,
    required this.peakHold,
    required this.estimatedDb,
    required this.isClipping,
  });

  /// Fast instantaneous level (`0.0–1.0`). / 瞬时快速电平（`0.0–1.0`）。
  final double instantaneous;

  /// Smooth ballistic RMS level (`0.0–1.0`). / 阻尼均方根电平（`0.0–1.0`）。
  final double ballisticRms;

  /// Decaying peak-hold level (`0.0–1.0`). / 峰值保持电平（`0.0–1.0`）。
  final double peakHold;

  /// Estimated level in dBFS (`minDb..maxDb`). / 估算分贝值（`minDb..maxDb`）。
  final double estimatedDb;

  /// True when [peakHold] or [instantaneous] enters the clipping headroom zone.
  /// 是否进入过载预警区（`>= 0.90`）。
  final bool isClipping;
}
