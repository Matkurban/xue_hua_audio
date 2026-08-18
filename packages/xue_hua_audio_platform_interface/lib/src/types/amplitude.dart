import 'package:flutter/foundation.dart';

/// A microphone amplitude sample, suitable for rendering waveforms or level
/// meters in the UI.
///
/// 一次麦克风振幅采样，可直接用于在 UI 中渲染波形或电平表。
@immutable
class Amplitude {
  /// Creates an amplitude sample.
  ///
  /// [current]: the current level in dBFS (0 is full scale, typical values
  /// range from -60 to 0).
  /// [max]: the maximum level in dBFS observed since recording started.
  ///
  /// 创建一次振幅采样。
  ///
  /// [current]：当前电平，单位 dBFS（0 为满刻度，常见范围 -60 ~ 0）。
  /// [max]：自录音开始以来观测到的最大电平（dBFS）。
  const Amplitude({required this.current, required this.max});

  /// The level in dBFS treated as silence when normalizing.
  /// 归一化时视为静音的 dBFS 电平下限。
  static const double silenceDb = -60;

  /// Current level in dBFS. / 当前电平（dBFS）。
  final double current;

  /// Maximum level in dBFS since the recording started.
  /// 自录音开始以来的最大电平（dBFS）。
  final double max;

  /// The current level mapped linearly from `[-60 dBFS, 0 dBFS]` to
  /// `[0.0, 1.0]`, clamped at both ends — convenient for waveform bars.
  ///
  /// 将当前电平从 `[-60 dBFS, 0 dBFS]` 线性映射到 `[0.0, 1.0]`（两端截断），
  /// 便于直接绘制波形柱。
  double get normalized =>
      ((current.clamp(silenceDb, 0) - silenceDb) / -silenceDb);

  @override
  bool operator ==(Object other) =>
      other is Amplitude && other.current == current && other.max == max;

  @override
  int get hashCode => Object.hash(current, max);

  @override
  String toString() => 'Amplitude(current: $current dBFS, max: $max dBFS)';
}
