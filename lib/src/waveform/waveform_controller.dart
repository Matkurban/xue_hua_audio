import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Holds the rolling level history shown by [AudioWaveform].
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
/// 滚动电平历史，由 [AudioWaveform] 显示。历史按**事件驱动**：录音器每送来
/// 一个电平就产生一根柱，与语音消息界面一致；柱不会被复制，也不会在两次事件
/// 之间衰减，因此恒定的底噪显示为恒定的（很矮的）柱，静音显示为平直圆点。
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

  /// Progress (0–1) towards the next bar; used for smooth scrolling.
  /// 距下一根柱的进度（0–1），用于平滑滚动。
  double get phase =>
      _count == 0 ? 0 : ((_clock - _lastBarAt) / _interval).clamp(0.0, 1.0);

  /// Normalized (0–1) bar, where 0 is the oldest. / 归一化的柱，0 为最旧。
  double valueAt(int index) {
    assert(index >= 0 && index < _count);
    return _buffer[(_head - _count + index + capacity * 2) % capacity];
  }

  /// Maps a dBFS level to 0–1: gate at [minDb], linear to [maxDb], then the
  /// [curve] soft knee. / 将 dBFS 映射到 0–1：[minDb] 处设门限，线性到
  /// [maxDb]，再施加 [curve] 软膝。
  double normalize(double db) {
    if (db.isNaN || db <= minDb) return 0;
    final x = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0).toDouble();
    return curve == 1 ? x : math.pow(x, curve).toDouble();
  }

  /// Feeds a level in dBFS; one call per native event. / 输入 dBFS 电平；
  /// 每个原生事件调用一次。
  void addDb(double db) => addNormalized(normalize(db));

  /// Feeds an already normalized (0–1) level. / 输入已归一化（0–1）的电平。
  void addNormalized(double value) {
    if (value > _pending) _pending = value;
    if (_active && _due) {
      _commit();
      notifyListeners();
    }
  }

  /// Advances time by [dt]; flushes merged events and notifies listeners.
  /// Driven by the widget's ticker.
  /// 推进 [dt] 时间；写出合并后的事件并通知监听者。由组件的 Ticker 驱动。
  void advance(Duration dt) {
    _clock += dt.inMicroseconds / Duration.microsecondsPerSecond;
    if (_active && _pending >= 0 && _due) {
      _commit();
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
    _buffer[_head] = _smoothed < 0.004 ? 0 : _smoothed;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
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
    _lastBarAt = _never;
    notifyListeners();
  }
}
