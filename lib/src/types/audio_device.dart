import 'package:flutter/foundation.dart';

/// An available audio device — either an input (microphone) or an output
/// (speaker, headphones, …) depending on the API that returned it.
/// 可用的音频设备——依据返回它的 API 不同，可能是输入设备（麦克风）或
/// 输出设备（扬声器、耳机等）。
@immutable
class AudioDevice {
  /// Creates an audio device descriptor.
  ///
  /// [id]: platform-specific stable identifier; pass it to
  /// `AudioPlayer.setOutputDevice` / `AudioRecorder.setInputDevice`
  /// (or `RecordConfig.deviceId`) to select this device.
  /// [label]: human-readable device name for display in the UI.
  ///
  /// 创建一个音频设备描述。
  ///
  /// [id]：平台相关的稳定标识；传给 `AudioPlayer.setOutputDevice` /
  /// `AudioRecorder.setInputDevice`（或 `RecordConfig.deviceId`）即可选用该设备。
  /// [label]：供 UI 展示的设备名称。
  const AudioDevice({required this.id, required this.label});

  /// Platform-specific stable device identifier. / 平台相关的稳定设备标识。
  final String id;

  /// Human-readable device name. / 供人阅读的设备名称。
  final String label;

  @override
  bool operator ==(Object other) =>
      other is AudioDevice && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  String toString() => 'AudioDevice(id: $id, label: $label)';
}
