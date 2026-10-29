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
  int get hashCode =>
      Object.hash(current, average, rms, peak, peakHold, flux, sampleCount);

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

/// A paired node along a 3D-projected double-helix acoustic wave.
/// 双螺旋声波链上的单组配对节点数据。
@immutable
class HelixNode {
  /// Creates a helix node. / 创建双螺旋节点。
  const HelixNode({
    required this.progress,
    required this.yOffsetA,
    required this.yOffsetB,
    required this.depthA,
    required this.depthB,
    required this.amplitude,
  });

  /// Normalized horizontal position (`0.0–1.0`). / 水平归一化位置（`0.0–1.0`）。
  final double progress;

  /// Normalized vertical displacement of strand A (`-1.0..1.0`).
  /// A 链垂直归一化偏移（`-1.0..1.0`）。
  final double yOffsetA;

  /// Normalized vertical displacement of strand B (`-1.0..1.0`).
  /// B 链垂直归一化偏移（`-1.0..1.0`）。
  final double yOffsetB;

  /// Depth factor of strand A (`-1.0..1.0`, positive is front).
  /// A 链景深系数（`-1.0..1.0`，正数在前）。
  final double depthA;

  /// Depth factor of strand B (`-1.0..1.0`, positive is front).
  /// B 链景深系数（`-1.0..1.0`，正数在前）。
  final double depthB;

  /// Local normalized amplitude at this node (`0.0–1.0`).
  /// 当前节点处的局部归一化振幅（`0.0–1.0`）。
  final double amplitude;
}

/// State of a single kinetic louver slat in [KineticLouverVisualizer].
/// 韵律百叶窗可视化组件中单个叶片的几何状态。
@immutable
class LouverSlat {
  /// Creates a louver slat state. / 创建百叶窗叶片状态。
  const LouverSlat({
    required this.amplitude,
    required this.tiltRadians,
    required this.heightFactor,
    required this.thicknessFactor,
  });

  /// Local normalized amplitude (`0.0–1.0`). / 局部归一化振幅（`0.0–1.0`）。
  final double amplitude;

  /// Tilt angle in radians (`-pi/4..pi/4`). / 倾斜弧度角（`-pi/4..pi/4`）。
  final double tiltRadians;

  /// Normalized height factor (`0.15..1.0`). / 高度缩放比例（`0.15..1.0`）。
  final double heightFactor;

  /// Normalized stroke thickness factor (`0.5..1.5`). / 线宽缩放比例（`0.5..1.5`）。
  final double thicknessFactor;
}

/// 2D normalized orbital particle state in [OrbitConstellationVisualizer].
/// 星轨星座可视化组件中的单个轨道节点状态。
@immutable
class OrbitalNode {
  /// Creates an orbital node. / 创建星轨节点。
  const OrbitalNode({
    required this.position,
    required this.radiusFactor,
    required this.energy,
    required this.orbitIndex,
  });

  /// Normalized offset relative to center (`-1.0..1.0` on each axis).
  /// 相对于中心的归一化坐标（各轴 `-1.0..1.0`）。
  final Offset position;

  /// Radius multiplier (`0.5..2.0`). / 节点半径倍率（`0.5..2.0`）。
  final double radiusFactor;

  /// Local energy (`0.0–1.0`). / 节点局部能量（`0.0–1.0`）。
  final double energy;

  /// Zero-based orbit ring index. / 所属轨道环索引（从 0 开始）。
  final int orbitIndex;
}

/// Ballistic studio meter reading parsed for [PrecisionMeterVisualizer].
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
  }) => parseDb(amplitude.current, minDb: minDb, maxDb: maxDb, curve: curve);

  /// Computes a [WaveformMetrics] snapshot over the latest [window] samples
  /// in [controller].
  /// 计算 [controller] 最近 [window] 个采样的统计特征 [WaveformMetrics]。
  static WaveformMetrics computeMetrics(
    WaveformController controller, {
    int window = 32,
  }) {
    final total = controller.length;
    if (total == 0 || window <= 0) {
      return WaveformMetrics.zero;
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
      final b = math.max(a + 1, ((i + 1) * levels.length / targetCount).ceil());
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
      final histIdx =
          (i * math.max(1, controller.length - 1)) / math.max(1, bandCount);
      final histVal = controller.sampleInterpolated(histIdx * 0.65);
      final centerWeight = math.sin(normPos * math.pi);
      final lowWeight = 1.0 - normPos;
      final highWeight = normPos;
      final harmonicMod = controller.active
          ? 0.08 * metrics.rms * math.sin(t * (4.0 + i * 0.7) + i * 0.9)
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

  /// Computes a 2D time-frequency spectrogram grid of size
  /// `[columns][bands]` with values in `[0.0, 1.0]`.
  ///
  /// Column `0` is the newest time slice; within each column, band `0` is the
  /// lowest frequency band and `bands - 1` is the highest.
  ///
  /// 计算 `[columns][bands]` 维度的时频声谱热力图矩阵（数值范围 `0.0–1.0`）。
  /// 第 `0` 列为最新时间切片，列内第 `0` 行为最低频段。
  static List<List<double>> computeSpectrogramGrid(
    WaveformController controller, {
    int columns = 20,
    int bands = 8,
  }) {
    if (columns <= 0 || bands <= 0) return const <List<double>>[];
    if (controller.length == 0) {
      return List<List<double>>.generate(
        columns,
        (_) => List<double>.filled(bands, 0.0),
      );
    }
    return List<List<double>>.generate(columns, (col) {
      final vCurr = controller.sampleInterpolated(col.toDouble());
      final vPrev = controller.sampleInterpolated((col + 1).toDouble());
      final vNext = controller.sampleInterpolated(
        math.max(0.0, (col - 1).toDouble()),
      );
      final localMean = (vCurr + vPrev + vNext) / 3.0;
      final localFlux = ((vCurr - vPrev).abs() + (vNext - vCurr).abs()) * 0.5;
      if (vCurr < 0.004 && localMean < 0.004) {
        return List<double>.filled(bands, 0.0);
      }
      return List<double>.generate(bands, (b) {
        final normBand = bands == 1 ? 0.5 : b / (bands - 1);
        final formant = math.sin(normBand * math.pi);
        final lowComponent = localMean * (1.0 - normBand * 0.65);
        final midComponent = vCurr * formant;
        final highComponent = localFlux * (0.4 + 0.8 * normBand);
        final combined =
            lowComponent * 0.42 + midComponent * 0.48 + highComponent * 0.45;
        return combined.clamp(0.0, 1.0).toDouble();
      });
    });
  }

  /// Computes [nodeCount] paired 3D-projected double-helix nodes from
  /// [controller].
  ///
  /// 从 [controller] 计算 [nodeCount] 组双螺旋声波三维投影节点。
  static List<HelixNode> computeHelixNodes(
    WaveformController controller, {
    int nodeCount = 24,
    double turns = 1.75,
  }) {
    if (nodeCount <= 0) return const <HelixNode>[];
    final metrics = computeMetrics(controller, window: 20);
    final phaseTime = controller.active ? controller.elapsedSeconds * 3.0 : 0.0;
    final shift = controller.active ? controller.phase : 0.0;
    return List<HelixNode>.generate(nodeCount, (i) {
      final progress = nodeCount == 1 ? 0.5 : i / (nodeCount - 1);
      final bell = math.sin(progress * math.pi);
      final sample = controller.sampleInterpolated(i * 0.8 + shift);
      final amp = ((sample * 0.75 + metrics.rms * 0.25) * (0.25 + 0.75 * bell))
          .clamp(0.0, 1.0)
          .toDouble();
      final theta = progress * math.pi * 2 * turns - phaseTime;
      final sinT = math.sin(theta);
      final cosT = math.cos(theta);
      final envelope = controller.active || !metrics.isSilent
          ? math.max(0.12, amp)
          : 0.10 * bell;
      return HelixNode(
        progress: progress,
        yOffsetA: (sinT * envelope).clamp(-1.0, 1.0),
        yOffsetB: (-sinT * envelope).clamp(-1.0, 1.0),
        depthA: cosT,
        depthB: -cosT,
        amplitude: amp,
      );
    });
  }

  /// Computes normalized petal expansion ratios (`0.0–1.0`) for
  /// [petalCount] radial lotus/mandala petals.
  ///
  /// 计算 [petalCount] 个几何花瓣的归一化舒展比例（`0.0–1.0`）。
  static List<double> computePetalRadii(
    WaveformController controller, {
    int petalCount = 8,
  }) {
    if (petalCount <= 0) return const <double>[];
    final bands = extractFrequencyBands(controller, petalCount);
    final metrics = computeMetrics(controller, window: 16);
    if (metrics.isSilent) {
      return List<double>.filled(petalCount, 0.0);
    }
    return List<double>.generate(petalCount, (i) {
      final mirrorIdx = petalCount - 1 - i;
      final symVal = (bands[i] + bands[mirrorIdx]) * 0.5;
      return (symVal * 0.75 + metrics.rms * 0.25).clamp(0.0, 1.0).toDouble();
    });
  }

  /// Parses a studio-grade [PrecisionMeterReading] from [controller].
  /// 从 [controller] 解析录音室级别的精密电平读数 [PrecisionMeterReading]。
  static PrecisionMeterReading parsePrecisionMeter(
    WaveformController controller,
  ) {
    final m = computeMetrics(controller, window: 24);
    final inst = m.current.clamp(0.0, 1.0);
    final rms = m.rms.clamp(0.0, 1.0);
    final peak = m.peakHold.clamp(0.0, 1.0);
    final span = controller.maxDb - controller.minDb;
    final linear = controller.curve == 1.0
        ? inst
        : math.pow(inst, 1.0 / controller.curve).toDouble();
    final db = (controller.minDb + linear * span).clamp(
      controller.minDb,
      controller.maxDb,
    );
    return PrecisionMeterReading(
      instantaneous: inst,
      ballisticRms: rms,
      peakHold: peak,
      estimatedDb: db,
      isClipping: peak >= 0.90 || inst >= 0.92,
    );
  }

  /// Computes instantaneous swing angles (in radians) for [count] coupled
  /// harmonic pendulums.
  ///
  /// 计算 [count] 个耦合谐振钟摆的瞬时摆角（弧度）。
  static List<double> computePendulumAngles(
    WaveformController controller, {
    int count = 15,
    double maxAngleRadians = 0.68,
  }) {
    if (count <= 0) return const <double>[];
    final m = computeMetrics(controller, window: 20);
    if (m.isSilent && !controller.active) {
      return List<double>.filled(count, 0.0);
    }
    final t = controller.elapsedSeconds;
    return List<double>.generate(count, (i) {
      final hist = controller.sampleInterpolated(i * 0.7);
      final energy = (hist * 0.65 + m.rms * 0.35).clamp(0.0, 1.0);
      // Graduated frequencies create a travelling pendulum wave pattern.
      // 递增谐振频率形成行波钟摆视觉效果。
      final freq = 2.2 + i * 0.24;
      final swing = controller.active
          ? math.sin(t * freq + i * 0.38)
          : math.sin(i * 0.55);
      return (swing * energy * maxAngleRadians).clamp(
        -maxAngleRadians,
        maxAngleRadians,
      );
    });
  }

  /// Computes the 2D vertices of a regular [sides]-gon centered at [center]
  /// with base [radius], rotated by [rotation] radians, and radially modulated
  /// by [vertexScales].
  ///
  /// 计算以 [center] 为中心、基准半径为 [radius]、旋转角为 [rotation] 的
  /// [sides] 边形顶点坐标，并按 [vertexScales] 调制各顶点径向伸展。
  static List<Offset> computePolygonVertices(
    Offset center,
    double radius,
    int sides, {
    double rotation = 0.0,
    List<double>? vertexScales,
  }) {
    if (sides < 3 || radius <= 0) return const <Offset>[];
    return List<Offset>.generate(sides, (i) {
      final scale = (vertexScales != null && vertexScales.isNotEmpty)
          ? vertexScales[i % vertexScales.length].clamp(0.1, 3.0)
          : 1.0;
      final r = radius * scale;
      final angle = rotation - math.pi / 2 + (i * 2 * math.pi / sides);
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    });
  }

  /// Computes [slatCount] kinetic louver slat states from [controller].
  /// 从 [controller] 计算 [slatCount] 个韵律百叶窗叶片的倾斜与高度状态。
  static List<LouverSlat> computeKineticLouvers(
    WaveformController controller, {
    int slatCount = 28,
    double maxTiltRadians = 0.52,
  }) {
    if (slatCount <= 0) return const <LouverSlat>[];
    final shift = controller.active ? controller.phase : 0.0;
    final t = controller.elapsedSeconds;
    return List<LouverSlat>.generate(slatCount, (i) {
      final v = controller.sampleInterpolated(i + shift).clamp(0.0, 1.0);
      final vNext = controller
          .sampleInterpolated(i + 1 + shift)
          .clamp(0.0, 1.0);
      final gradient = v - vNext;
      final wavePhase = controller.active ? math.sin(t * 4.0 - i * 0.35) : 0.0;
      final tilt = ((gradient * 1.4 + wavePhase * 0.45 * v) * maxTiltRadians)
          .clamp(-maxTiltRadians, maxTiltRadians);
      final heightFactor = (0.18 + 0.82 * v).clamp(0.18, 1.0);
      final thicknessFactor = (0.65 + 0.70 * v).clamp(0.65, 1.35);
      return LouverSlat(
        amplitude: v,
        tiltRadians: tilt,
        heightFactor: heightFactor,
        thicknessFactor: thicknessFactor,
      );
    });
  }

  /// Computes [nodeCount] orbital constellation nodes distributed across
  /// concentric elliptical tracks in `[-1.0, 1.0]` normalized coordinates.
  ///
  /// 计算分布在多层椭圆星轨上的 [nodeCount] 个星座节点（归一化坐标 `-1.0..1.0`）。
  static List<OrbitalNode> computeOrbitalNodes(
    WaveformController controller, {
    int nodeCount = 16,
    int orbitCount = 3,
  }) {
    if (nodeCount <= 0 || orbitCount <= 0) return const <OrbitalNode>[];
    final bands = extractFrequencyBands(controller, nodeCount);
    final m = computeMetrics(controller, window: 20);
    final t = controller.elapsedSeconds;
    return List<OrbitalNode>.generate(nodeCount, (i) {
      final orbitIdx = i % orbitCount;
      final baseOrbitR = 0.28 + (orbitIdx / math.max(1, orbitCount)) * 0.52;
      final energy = bands[i];
      final r = (baseOrbitR + energy * 0.16).clamp(0.15, 0.96);
      final speed = (orbitIdx.isEven ? 1.0 : -1.0) * (0.55 + orbitIdx * 0.28);
      final boost = controller.active ? t * speed * (1.0 + m.rms * 0.8) : 0.0;
      final baseAngle = (i * 2 * math.pi / nodeCount) + boost;
      final aspect = 0.78 + 0.08 * orbitIdx;
      final nx = (r * math.cos(baseAngle)).clamp(-1.0, 1.0);
      final ny = (r * math.sin(baseAngle) * aspect).clamp(-1.0, 1.0);
      return OrbitalNode(
        position: Offset(nx, ny),
        radiusFactor: (0.75 + 1.15 * energy).clamp(0.75, 1.90),
        energy: energy,
        orbitIndex: orbitIdx,
      );
    });
  }

  /// Synthesizes [pointCount] normalized vertical displacements (`-1.0..1.0`)
  /// for a phosphor oscilloscope trace driven by [controller].
  ///
  /// 合成 [pointCount] 个归一化示波器轨迹纵坐标（`-1.0..1.0`）。
  static List<double> computeOscilloscopeTrace(
    WaveformController controller, {
    int pointCount = 96,
  }) {
    if (pointCount <= 0) return const <double>[];
    final m = computeMetrics(controller, window: 24);
    if (m.isSilent && !controller.active) {
      return List<double>.filled(pointCount, 0.0);
    }
    final t = controller.elapsedSeconds;
    return List<double>.generate(pointCount, (i) {
      final normX = pointCount == 1 ? 0.5 : i / (pointCount - 1);
      final bell = math.sin(normX * math.pi);
      final histPos =
          (1.0 - normX) * math.min(24, math.max(1, controller.length));
      final env = controller.sampleInterpolated(histPos);
      final energy = (env * 0.70 + m.current * 0.30).clamp(0.0, 1.0);
      final carrier =
          math.sin(normX * math.pi * 10.0 - t * 14.0) * 0.65 +
          math.sin(normX * math.pi * 23.0 + t * 9.0) * 0.35;
      return (carrier * energy * (0.20 + 0.80 * bell)).clamp(-1.0, 1.0);
    });
  }
}
