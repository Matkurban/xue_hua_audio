import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../types/amplitude.dart';
import 'waveform_controller.dart';

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

/// Immutable statistical snapshot extracted from a [WaveformController].
/// 从 [WaveformController] 提取的不可变统计特征快照。
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
  int get hashCode => Object.hash(
    current,
    average,
    rms,
    peak,
    peakHold,
    flux,
    sampleCount,
  );

  @override
  String toString() =>
      'WaveformMetrics(current: ${current.toStringAsFixed(3)}, '
      'rms: ${rms.toStringAsFixed(3)}, peak: ${peak.toStringAsFixed(3)}, '
      'peakHold: ${peakHold.toStringAsFixed(3)}, flux: ${flux.toStringAsFixed(3)}, '
      'samples: $sampleCount)';
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

/// Cubic Bezier segment `(p0, c1, c2, p1)` used for smooth closed contours.
/// 用于平滑闭合轮廓的三次贝塞尔曲线段 `(p0, c1, c2, p1)`。
@immutable
class CubicSegment {
  /// Creates a cubic Bezier segment. / 创建三次贝塞尔曲线段。
  const CubicSegment({
    required this.p0,
    required this.c1,
    required this.c2,
    required this.p1,
  });

  /// Start anchor point. / 起点锚点。
  final Offset p0;

  /// First control point. / 第一控制点。
  final Offset c1;

  /// Second control point. / 第二控制点。
  final Offset c2;

  /// End anchor point. / 终点锚点。
  final Offset p1;
}

/// Pure, deterministic data parsing and geometric transformation helpers for
/// audio recording visualizers.
///
/// 录音可视化组件的纯函数数据解析与几何变换工具类。
abstract final class WaveformDataParser {
  /// Parses a dBFS value into a normalized `0.0–1.0` level with noise gating
  /// at [minDb], ceiling at [maxDb], and a soft-knee [curve] exponent.
  ///
  /// 将 dBFS 分贝值解析为 `0.0–1.0` 归一化电平：在 [minDb] 处执行噪声门限截断，
  /// 在 [maxDb] 处封顶，并应用 [curve] 软膝幂指数。
  static double parseDb(
    double db, {
    double minDb = -50,
    double maxDb = 0,
    double curve = 1.5,
  }) {
    assert(maxDb > minDb);
    assert(curve > 0);
    if (db.isNaN || db <= minDb) return 0.0;
    if (db >= maxDb) return 1.0;
    final x = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0).toDouble();
    return curve == 1.0 ? x : math.pow(x, curve).toDouble();
  }

  /// Parses an [Amplitude] sample into a normalized `0.0–1.0` level.
  /// 将 [Amplitude] 振幅采样解析为 `0.0–1.0` 归一化电平。
  static double parseAmplitude(
    Amplitude amplitude, {
    double minDb = -50,
    double maxDb = 0,
    double curve = 1.5,
  }) => parseDb(
    amplitude.current,
    minDb: minDb,
    maxDb: maxDb,
    curve: curve,
  );

  /// Computes a [WaveformMetrics] snapshot over the latest [window] samples
  /// in [controller].
  /// 计算 [controller] 最近 [window] 个采样的统计特征 [WaveformMetrics]。
  static WaveformMetrics computeMetrics(
    WaveformController controller, {
    int window = 32,
  }) {
    final total = controller.length;
    if (total == 0 || window <= 0) {
      return const WaveformMetrics(
        current: 0,
        average: 0,
        rms: 0,
        peak: 0,
        peakHold: 0,
        flux: 0,
        sampleCount: 0,
      );
    }
    final count = math.min(total, window);
    var sum = 0.0;
    var sumSq = 0.0;
    var peak = 0.0;
    var fluxSum = 0.0;
    var prev = controller.recentAt(0);
    for (var i = 0; i < count; i++) {
      final v = controller.recentAt(i).clamp(0.0, 1.0).toDouble();
      sum += v;
      sumSq += v * v;
      if (v > peak) peak = v;
      if (i > 0) {
        fluxSum += (v - prev).abs();
      }
      prev = v;
    }
    final avg = sum / count;
    final rms = math.sqrt(sumSq / count);
    final flux = count > 1 ? (fluxSum / (count - 1)).clamp(0.0, 1.0) : 0.0;
    final current = controller.recentAt(0).clamp(0.0, 1.0).toDouble();
    final peakHold = math.max(peak, controller.peakHold).clamp(0.0, 1.0);
    return WaveformMetrics(
      current: current,
      average: avg,
      rms: rms,
      peak: peak,
      peakHold: peakHold,
      flux: flux,
      sampleCount: count,
    );
  }

  /// Resamples an arbitrary list of normalized [levels] into [targetCount]
  /// buckets in `[0.0, 1.0]`.
  ///
  /// When downsampling (`levels.length >= targetCount`), each bucket takes the
  /// peak of its covered slice so short speech transients are never lost.
  /// When upsampling (`levels.length < targetCount`), values are smoothly
  /// interpolated across buckets.
  ///
  /// 将任意长度的归一化电平列表 [levels] 重采样为 [targetCount] 个桶（`0.0–1.0`）。
  /// 降采样时取区间峰值以保留短促语音瞬态；升采样时在相邻点之间平滑线性插值。
  static List<double> resamplePeak(List<double> levels, int targetCount) {
    if (targetCount <= 0) return const <double>[];
    if (levels.isEmpty) return List<double>.filled(targetCount, 0.0);

    double clean(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0).toDouble();

    if (levels.length == 1) {
      return List<double>.filled(targetCount, clean(levels.first));
    }
    if (targetCount == 1) {
      var maxV = 0.0;
      for (final raw in levels) {
        final v = clean(raw);
        if (v > maxV) maxV = v;
      }
      return <double>[maxV];
    }
    if (levels.length < targetCount) {
      return List<double>.generate(targetCount, (i) {
        final pos = i * (levels.length - 1) / (targetCount - 1);
        final i0 = pos.floor();
        final i1 = math.min(levels.length - 1, i0 + 1);
        final t = pos - i0;
        final v0 = clean(levels[i0]);
        final v1 = clean(levels[i1]);
        return v0 + (v1 - v0) * t;
      });
    }
    return List<double>.generate(targetCount, (i) {
      final a = (i * levels.length / targetCount).floor();
      final b = math.max(
        a + 1,
        ((i + 1) * levels.length / targetCount).ceil(),
      );
      var peak = 0.0;
      for (var j = a; j < math.min(b, levels.length); j++) {
        final v = clean(levels[j]);
        if (v > peak) peak = v;
      }
      return peak;
    });
  }

  /// Extracts [spokeCount] normalized values from [controller] for radial /
  /// polar visualizers. When [mirror] is true, the first half of the circle
  /// is mirrored onto the second half for seamless bilateral symmetry.
  ///
  /// 从 [controller] 提取 [spokeCount] 个极坐标辐射值。当 [mirror] 为 true 时，
  /// 前半圆与后半圆镜像对称，消除首尾接缝突变。
  static List<double> extractMirroredRadial(
    WaveformController controller,
    int spokeCount, {
    bool mirror = true,
  }) {
    if (spokeCount <= 0) return const <double>[];
    if (controller.length == 0) {
      return List<double>.filled(spokeCount, 0.0);
    }
    if (!mirror || spokeCount < 4) {
      return List<double>.generate(
        spokeCount,
        (i) => controller.recentAt(i).clamp(0.0, 1.0).toDouble(),
      );
    }
    final half = (spokeCount / 2).ceil();
    final halfValues = List<double>.generate(
      half,
      (i) => controller.sampleInterpolated(i.toDouble()).clamp(0.0, 1.0),
    );
    return List<double>.generate(spokeCount, (i) {
      if (i < half) return halfValues[i];
      final mirroredIndex = spokeCount - 1 - i;
      return halfValues[mirroredIndex.clamp(0, half - 1)];
    });
  }

  /// Synthesizes [bandCount] lively frequency-like equalizer bands in
  /// `[0.0, 1.0]` from the rolling time-domain history in [controller].
  ///
  /// Low bands reflect smooth bass/envelope energy, mid bands capture
  /// syllabic cadence, and upper bands respond to rapid vocal articulation
  /// and transient flux.
  ///
  /// 从 [controller] 的时域滚动历史合成 [bandCount] 个均衡器频段（`0.0–1.0`）：
  /// 低频段反映平滑包络能量，中频段捕捉音节律动，高频段响应快速语音瞬态变化。
  static List<double> extractFrequencyBands(
    WaveformController controller,
    int bandCount,
  ) {
    if (bandCount <= 0) return const <double>[];
    final metrics = computeMetrics(controller, window: 24);
    if (metrics.isSilent) {
      return List<double>.filled(bandCount, 0.0);
    }
    final t = controller.elapsedSeconds;
    return List<double>.generate(bandCount, (i) {
      final normPos = bandCount == 1 ? 0.5 : i / (bandCount - 1);
      // Sample history at progressive lookback offsets combined with envelope.
      // 结合不同回溯深度的历史采样与包络特征。
      final histIdx = (i * math.max(1, controller.length - 1)) /
          math.max(1, bandCount);
      final histVal = controller.sampleInterpolated(histIdx * 0.65);
      // Bell-shaped vocal presence curve peaking in the mid-band region.
      // 以中频人声区为中心的钟形权重包络。
      final centerWeight = math.sin(normPos * math.pi);
      final lowWeight = 1.0 - normPos;
      final highWeight = normPos;
      final harmonicMod = controller.active
          ? 0.08 *
                metrics.rms *
                math.sin(t * (4.0 + i * 0.7) + i * 0.9)
          : 0.0;
      final raw =
          histVal * (0.45 + 0.35 * centerWeight) +
          metrics.rms * (0.30 * lowWeight + 0.15 * centerWeight) +
          metrics.flux * (0.55 * highWeight) +
          harmonicMod;
      return raw.clamp(0.0, 1.0).toDouble();
    });
  }

  /// Quantizes a continuous [level] and [peakHold] (`0.0–1.0`) into discrete
  /// LED segments and warning/danger zones.
  ///
  /// 将连续的 [level] 与 [peakHold]（`0.0–1.0`）量化为离散的 LED 分段与色彩区间。
  static VuMeterState parseVuSegments({
    required double level,
    required double peakHold,
    int segments = 12,
    double warningRatio = 0.65,
    double dangerRatio = 0.85,
  }) {
    assert(segments > 0);
    final cleanLevel = level.isNaN ? 0.0 : level.clamp(0.0, 1.0);
    final cleanPeak = peakHold.isNaN ? 0.0 : peakHold.clamp(0.0, 1.0);
    final active = cleanLevel <= 0.004
        ? 0
        : math.max(1, (cleanLevel * segments).ceil()).clamp(0, segments);
    int? peakSeg;
    if (cleanPeak > 0.004) {
      final rawPeak = ((cleanPeak * segments).ceil() - 1).clamp(
        0,
        segments - 1,
      );
      peakSeg = math.max(rawPeak, active > 0 ? active - 1 : 0);
    }
    final warnStart = (segments * warningRatio.clamp(0.0, 1.0)).floor().clamp(
      0,
      segments,
    );
    final dangerStart = (segments * dangerRatio.clamp(0.0, 1.0)).floor().clamp(
      warnStart,
      segments,
    );
    return VuMeterState(
      totalSegments: segments,
      activeSegments: active,
      peakSegment: peakSeg,
      warningStartSegment: warnStart,
      dangerStartSegment: dangerStart,
    );
  }

  /// Converts polar [radii] distributed evenly around [center] (starting at
  /// [rotation] radians) into a closed loop of smooth Catmull-Rom cubic Bezier
  /// segments (`C¹` continuous, zero sharp corners).
  ///
  /// 将围绕 [center] 均匀分布的极坐标半径列表 [radii]（起始旋转角为 [rotation] 弧度）
  /// 转换为平滑闭合的 Catmull-Rom 三次贝塞尔曲线段（`C¹` 连续，无尖角）。
  static List<CubicSegment> computeClosedSplineSegments(
    List<double> radii,
    Offset center, {
    double rotation = 0.0,
    double tension = 1.0,
  }) {
    final n = radii.length;
    if (n < 3) return const <CubicSegment>[];
    final pts = List<Offset>.generate(n, (i) {
      final angle = rotation + (i * 2 * math.pi / n);
      final r = radii[i].isNaN ? 0.0 : math.max(0.0, radii[i]);
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    });
    final factor = tension / 6.0;
    return List<CubicSegment>.generate(n, (i) {
      final pPrev = pts[(i - 1 + n) % n];
      final pCurr = pts[i];
      final pNext = pts[(i + 1) % n];
      final pNext2 = pts[(i + 2) % n];
      final c1 = Offset(
        pCurr.dx + (pNext.dx - pPrev.dx) * factor,
        pCurr.dy + (pNext.dy - pPrev.dy) * factor,
      );
      final c2 = Offset(
        pNext.dx - (pNext2.dx - pCurr.dx) * factor,
        pNext.dy - (pNext2.dy - pCurr.dy) * factor,
      );
      return CubicSegment(p0: pCurr, c1: c1, c2: c2, p1: pNext);
    });
  }
}
