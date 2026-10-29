import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'waveform_parser.dart';

/// Holds the rolling level history shown by [AudioWaveform] and other
/// recording visualizers.
///
/// The history is **event driven**: every level that arrives from the
/// recorder becomes one bar, exactly like voice-message UIs. Bars are never
/// duplicated and never decay between events, so a constant noise floor
/// shows as a constant (small) bar height and silence as flat dots.
/// Events that arrive faster than [maxBarsPerSecond] are merged into the
/// loudest value. Scrolling is interpolated between bars using the measured
/// event interval, so the speed follows the native update rate.
/// No memory is allocated after construction.
///
/// 滚动电平历史，由 [AudioWaveform] 及其他录音可视化组件显示。历史按**事件驱动**：
/// 录音器每送来一个电平就产生一根柱，与语音消息界面一致；柱不会被复制，也不会在
/// 两次事件之间衰减，因此恒定的底噪显示为恒定的（很矮的）柱，静音显示为平直圆点。
/// 快于 [maxBarsPerSecond] 的事件会合并为其中最大值。滚动按实测事件间隔在
/// 柱之间插值，速度跟随原生更新频率。构造后不再分配内存。
class WaveformController extends ChangeNotifier {
  /// Creates a controller. / 创建控制器。
  WaveformController({
    this.capacity = 256,
    this.maxBarsPerSecond = 30,
    this.minDb = -50,
    this.maxDb = 0,
    this.curve = 1.5,
    this.attack = 0.85,
    this.release = 0.6,
  }) : assert(capacity > 1),
       assert(maxBarsPerSecond > 0),
       assert(maxDb > minDb),
       assert(curve > 0),
       assert(attack > 0 && attack <= 1),
       assert(release > 0 && release <= 1),
       _buffer = Float32List(capacity);

  /// Number of bars kept. / 保留的柱数。
  final int capacity;

  /// Upper bound of the bar rate; faster events are merged.
  /// 柱速率上限；更快的事件会被合并。
  final double maxBarsPerSecond;

  /// Noise gate / floor in dBFS: this level and anything below it map to an
  /// empty bar. Typical room noise sits around -60…-45 dBFS, hence the -50
  /// default.
  /// 噪声门/底限（dBFS）：不高于该电平的输入显示为空柱。常见环境底噪约
  /// -60…-45 dBFS，因此默认 -50。
  final double minDb;

  /// Level mapped to a full-height bar, in dBFS. / 映射为满高柱的电平（dBFS）。
  final double maxDb;

  /// Soft-knee exponent applied to the linear 0–1 position between [minDb]
  /// and [maxDb]. Values > 1 keep quiet noise small and give speech more
  /// contrast; 1 is linear.
  /// 对 [minDb]–[maxDb] 之间线性位置施加的软膝指数。大于 1 时底噪更矮、
  /// 语音对比更强；1 为线性。
  final double curve;

  /// Smoothing factor (0–1] across consecutive bars when rising; 1 = none.
  /// 相邻柱上升时的平滑系数（0–1]；1 表示不平滑。
  final double attack;

  /// Smoothing factor (0–1] across consecutive bars when falling.
  /// 相邻柱下降时的平滑系数（0–1]。
  final double release;

  final Float32List _buffer;
  int _head = 0; // index of the next write / 下一次写入位置
  int _count = 0;
  double _smoothed = 0;
  double _pending = -1; // peak since the last bar, -1 = none / -1 表示无
  double _clock = 0; // seconds, advanced by [advance]
  static const double _never = -1e9; // "no bar yet" / 尚无柱
  double _lastBarAt = _never;
  double _interval = 0.1; // measured seconds between bars / 实测柱间隔
  double _peakHold = 0;
  double _peakHoldUntil = _never;
  bool _active = false;

  /// Whether the history is currently advancing (e.g. while recording).
  /// 历史是否正在推进（例如录音中）。
  bool get active => _active;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    if (value) {
      // Restart interval tracking so a pause is not mistaken for a slow bar.
      // 重置间隔统计，避免把暂停误判为慢速柱。
      _lastBarAt = _never;
    } else {
      _pending = -1;
    }
    notifyListeners();
  }

  /// Number of stored bars (≤ [capacity]). / 已存储的柱数（≤ [capacity]）。
  int get length => _count;

  /// Measured seconds between bars. / 实测的柱间隔（秒）。
  double get barInterval => _interval;

  /// Elapsed controller clock in seconds, driven by [advance].
  /// 控制器累计运行秒数，由 [advance] 推进。
  double get elapsedSeconds => _clock;

  /// Newest committed normalized bar (0–1), or 0 when empty.
  /// 最新写入的归一化柱值（0–1），为空时返回 0。
  double get latest => _count == 0 ? 0.0 : valueAt(_count - 1);

  /// Current smoothed envelope value (0–1). / 当前平滑包络值（0–1）。
  double get smoothedLevel => _smoothed < 0.004 ? 0.0 : _smoothed;

  /// Decaying peak-hold level (0–1) for VU meters and peak rings.
  /// 带保持与平滑衰减的峰值电平（0–1），用于电平表和峰值指示环。
  double get peakHold => _peakHold;

  /// Progress (0–1) towards the next bar; used for smooth scrolling.
  /// 距下一根柱的进度（0–1），用于平滑滚动。
  double get phase =>
      _count == 0 ? 0 : ((_clock - _lastBarAt) / _interval).clamp(0.0, 1.0);

  /// Normalized (0–1) bar, where 0 is the oldest. / 归一化的柱，0 为最旧。
  double valueAt(int index) {
    assert(index >= 0 && index < _count);
    return _buffer[(_head - _count + index + capacity * 2) % capacity];
  }

  /// Returns the [k]-th newest bar (`0` is the newest), or `0.0` when [k] is
  /// outside `[0, length)`.
  /// 返回倒数第 [k] 根最新柱（`0` 为最新），超出范围时返回 `0.0`。
  double recentAt(int k) {
    if (k < 0 || k >= _count) return 0.0;
    return valueAt(_count - 1 - k);
  }

  /// Linearly interpolates between recent bars at fractional offset [k] from
  /// the newest sample (`0.0` is newest).
  /// 按距最新采样的浮点偏移 [k]（`0.0` 为最新）在相邻柱之间线性插值。
  double sampleInterpolated(double k) {
    if (_count == 0 || k < 0) return 0.0;
    final i0 = k.floor();
    final frac = k - i0;
    final v0 = recentAt(i0);
    final v1 = recentAt(i0 + 1);
    return v0 + (v1 - v0) * frac;
  }

  /// Computes aggregated statistical metrics over the most recent [window]
  /// samples.
  /// 计算最近 [window] 个采样的统计特征快照。
  WaveformMetrics computeMetrics({int window = 32}) =>
      WaveformDataParser.computeMetrics(this, window: window);

  /// Maps a dBFS level to 0–1: gate at [minDb], linear to [maxDb], then the
  /// [curve] soft knee. / 将 dBFS 映射到 0–1：[minDb] 处设门限，线性到
  /// [maxDb]，再施加 [curve] 软膝。
  double normalize(double db) =>
      WaveformDataParser.parseDb(db, minDb: minDb, maxDb: maxDb, curve: curve);

  /// Feeds a level in dBFS; one call per native event. / 输入 dBFS 电平；
  /// 每个原生事件调用一次。
  void addDb(double db) => addNormalized(normalize(db));

  /// Feeds an already normalized (0–1) level. / 输入已归一化（0–1）的电平。
  void addNormalized(double value) {
    if (value.isNaN) return;
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (clamped > _pending) _pending = clamped;
    if (_active && _due) {
      _commit();
      notifyListeners();
    }
  }

  /// Advances time by [dt]; flushes merged events and notifies listeners.
  /// Driven by the widget's ticker.
  /// 推进 [dt] 时间；写出合并后的事件并通知监听者。由组件的 Ticker 驱动。
  void advance(Duration dt) {
    final dtSec = math.max(
      0.0,
      dt.inMicroseconds / Duration.microsecondsPerSecond,
    );
    _clock += dtSec;
    if (_active && _pending >= 0 && _due) {
      _commit();
    }
    if (_active && _peakHold > 0 && _clock > _peakHoldUntil) {
      final floor = latest;
      _peakHold = math.max(floor, _peakHold - dtSec * 0.65);
      if (_peakHold < 0.004) _peakHold = 0;
    }
    notifyListeners();
  }

  bool get _due => _clock - _lastBarAt >= 1 / maxBarsPerSecond - 1e-9;

  void _commit() {
    final target = _pending;
    _pending = -1;
    final k = target > _smoothed ? attack : release;
    _smoothed += (target - _smoothed) * k;
    // A bar below the visible minimum is an exact zero (flat dot).
    // 低于可见最小值的柱记为精确 0（平直圆点）。
    final committed = _smoothed < 0.004 ? 0.0 : _smoothed;
    _buffer[_head] = committed;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
    if (committed >= _peakHold) {
      _peakHold = committed;
      _peakHoldUntil = _clock + 0.45;
    }
    final gap = _clock - _lastBarAt;
    if (_count > 1 && gap > 0 && gap < 1) {
      _interval = (_interval * 0.7 + gap * 0.3)
          .clamp(1 / maxBarsPerSecond, 0.5)
          .toDouble();
    }
    _lastBarAt = _clock;
  }

  /// Clears the history. / 清空历史。
  void clear() {
    _head = 0;
    _count = 0;
    _pending = -1;
    _smoothed = 0;
    _peakHold = 0;
    _peakHoldUntil = _never;
    _lastBarAt = _never;
    notifyListeners();
  }
}
