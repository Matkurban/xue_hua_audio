import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Holds the rolling level history shown by [AudioWaveform].
///
/// Incoming dBFS levels (which arrive at an irregular rate) are folded into a
/// fixed-size ring buffer sampled at a constant [samplesPerSecond], so the
/// waveform scrolls at a steady speed no matter how bursty the source is.
/// No memory is allocated after construction.
///
/// 保存 [AudioWaveform] 显示的滚动电平历史。不规则到达的 dBFS 电平会按固定的
/// [samplesPerSecond] 采样写入定长环形缓冲区，因此无论事件多密集，波形都以
/// 恒定速度滚动；构造后不再分配内存。
class WaveformController extends ChangeNotifier {
  /// Creates a controller. / 创建控制器。
  WaveformController({
    this.capacity = 256,
    this.samplesPerSecond = 30,
    this.minDb = -60,
    this.maxDb = 0,
    this.attack = 0.7,
    this.release = 0.25,
  }) : assert(capacity > 1),
       assert(samplesPerSecond > 0),
       assert(maxDb > minDb),
       assert(attack > 0 && attack <= 1),
       assert(release > 0 && release <= 1),
       _buffer = Float32List(capacity);

  /// Number of samples kept. / 保留的采样数。
  final int capacity;

  /// Fixed sampling rate of the history. / 历史记录的固定采样率。
  final double samplesPerSecond;

  /// Level mapped to 0 (silence), in dBFS. / 映射为 0（静音）的电平（dBFS）。
  final double minDb;

  /// Level mapped to 1 (full scale), in dBFS. / 映射为 1（满幅）的电平（dBFS）。
  final double maxDb;

  /// Smoothing factor (0–1] applied when the level rises; 1 = no smoothing.
  /// 电平上升时的平滑系数（0–1]；1 表示不平滑。
  final double attack;

  /// Smoothing factor (0–1] applied when the level falls.
  /// 电平下降时的平滑系数（0–1]。
  final double release;

  final Float32List _buffer;
  int _head = 0; // index of the next write / 下一次写入位置
  int _count = 0;
  double _pending = 0; // peak since the last sample / 自上次采样以来的峰值
  double _smoothed = 0;
  double _accumulator = 0; // seconds since the last sample / 距上次采样的秒数
  bool _active = false;

  /// Whether the history is currently advancing (e.g. while recording).
  /// 历史是否正在推进（例如录音中）。
  bool get active => _active;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    if (!value) {
      _pending = 0;
      _accumulator = 0;
    }
    notifyListeners();
  }

  /// Number of stored samples (≤ [capacity]). / 已存储的采样数（≤ [capacity]）。
  int get length => _count;

  /// Progress (0–1) towards the next sample; used for smooth scrolling.
  /// 距下一个采样的进度（0–1），用于平滑滚动。
  double get phase => math.min(1.0, _accumulator * samplesPerSecond).toDouble();

  /// Normalized (0–1) sample, where 0 is the oldest. / 归一化采样，0 为最旧。
  double valueAt(int index) {
    assert(index >= 0 && index < _count);
    return _buffer[(_head - _count + index + capacity * 2) % capacity];
  }

  /// Maps a dBFS level to 0–1 using [minDb]/[maxDb].
  /// 使用 [minDb]/[maxDb] 将 dBFS 映射到 0–1。
  double normalize(double db) {
    if (db.isNaN) return 0;
    return ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0).toDouble();
  }

  /// Feeds a level in dBFS. Cheap; may be called at any rate.
  /// 输入 dBFS 电平；开销很小，可按任意频率调用。
  void addDb(double db) => addNormalized(normalize(db));

  /// Feeds an already normalized (0–1) level. / 输入已归一化（0–1）的电平。
  void addNormalized(double value) {
    if (value > _pending) _pending = value;
  }

  /// Advances time by [dt]; writes one sample per elapsed interval and
  /// notifies listeners. Driven by the widget's ticker.
  /// 推进 [dt] 时间；每个间隔写入一个采样并通知监听者。由组件的 Ticker 驱动。
  void advance(Duration dt) {
    _accumulator += dt.inMicroseconds / Duration.microsecondsPerSecond;
    final interval = 1 / samplesPerSecond;
    // Cap catch-up after a stall so we never loop for long.
    // 卡顿后限制追帧次数。
    var steps = (_accumulator / interval + 1e-9).floor();
    if (steps > capacity) {
      steps = capacity;
      _accumulator = interval * steps;
    }
    for (var i = 0; i < steps; i++) {
      _writeSample();
      _accumulator -= interval;
    }
    notifyListeners();
  }

  void _writeSample() {
    final target = _pending;
    _pending = 0;
    final k = target > _smoothed ? attack : release;
    _smoothed += (target - _smoothed) * k;
    _buffer[_head] = _smoothed;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
  }

  /// Clears the history. / 清空历史。
  void clear() {
    _head = 0;
    _count = 0;
    _pending = 0;
    _smoothed = 0;
    _accumulator = 0;
    notifyListeners();
  }
}
