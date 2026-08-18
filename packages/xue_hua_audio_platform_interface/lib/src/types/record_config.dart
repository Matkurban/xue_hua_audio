import 'package:flutter/foundation.dart';

/// The audio encoder used when recording. / 录音时使用的音频编码器。
///
/// Platform support / 平台支持情况:
///
/// | Encoder | Android | iOS/macOS | Windows | Linux | Web |
/// |---------|---------|-----------|---------|-------|-----|
/// | wav     | yes     | yes       | yes     | yes   | no  |
/// | aacLc   | yes     | yes       | yes     | yes*  | maybe (Safari) |
/// | opus    | no      | no        | no      | yes*  | yes (Chrome/Firefox) |
///
/// `*` requires the matching GStreamer encoder plugin to be installed.
/// On Web the browser chooses the closest supported format via
/// `MediaRecorder.isTypeSupported`.
///
/// `*` 需要系统安装对应的 GStreamer 编码插件。Web 端由浏览器通过
/// `MediaRecorder.isTypeSupported` 选择最接近的受支持格式。
enum AudioEncoder {
  /// Linear PCM in a WAV container — lossless, largest files, zero-latency
  /// encoding. / WAV 容器中的线性 PCM——无损、文件最大、编码零延迟。
  wav,

  /// AAC-LC in an MPEG-4 (`.m4a`) container — good quality at small sizes.
  /// MPEG-4（`.m4a`）容器中的 AAC-LC——体积小、音质好。
  aacLc,

  /// Opus — excellent quality at low bit rates; container depends on the
  /// platform (Ogg on Linux, WebM on Web).
  /// Opus——低码率下音质优秀；容器视平台而定（Linux 为 Ogg，Web 为 WebM）。
  opus,
}

/// Configuration for a recording session. / 一次录音会话的配置。
@immutable
class RecordConfig {
  /// Creates a recording configuration.
  ///
  /// [encoder]: the audio encoder, defaults to [AudioEncoder.wav].
  /// [sampleRate]: sample rate in Hz, defaults to 44100.
  /// [numChannels]: 1 (mono, default) or 2 (stereo).
  /// [bitRate]: bit rate in bits/second for compressed encoders,
  /// defaults to 128000.
  /// [amplitudeInterval]: how often amplitude events are emitted,
  /// defaults to 100 ms.
  /// [deviceId]: input device id from `listInputDevices()`, `null` uses the
  /// system default microphone.
  ///
  /// 创建一份录音配置。
  ///
  /// [encoder]：音频编码器，默认 [AudioEncoder.wav]。
  /// [sampleRate]：采样率（Hz），默认 44100。
  /// [numChannels]：声道数，1（单声道，默认）或 2（立体声）。
  /// [bitRate]：压缩编码器使用的比特率（bit/s），默认 128000。
  /// [amplitudeInterval]：振幅事件的推送间隔，默认 100 毫秒。
  /// [deviceId]：来自 `listInputDevices()` 的输入设备 id；`null` 表示使用
  /// 系统默认麦克风。
  const RecordConfig({
    this.encoder = AudioEncoder.wav,
    this.sampleRate = 44100,
    this.numChannels = 1,
    this.bitRate = 128000,
    this.amplitudeInterval = const Duration(milliseconds: 100),
    this.deviceId,
  });

  /// The audio encoder to use. / 使用的音频编码器。
  final AudioEncoder encoder;

  /// Sample rate in Hz. / 采样率（Hz）。
  final int sampleRate;

  /// Number of channels: 1 = mono, 2 = stereo. / 声道数：1 单声道，2 立体声。
  final int numChannels;

  /// Bit rate in bits per second (compressed encoders only).
  /// 比特率（bit/s，仅压缩编码器使用）。
  final int bitRate;

  /// Interval between amplitude events. / 振幅事件的推送间隔。
  final Duration amplitudeInterval;

  /// Preferred input device id, `null` for the system default.
  /// 期望使用的输入设备 id；`null` 表示系统默认设备。
  final String? deviceId;

  @override
  String toString() =>
      'RecordConfig(encoder: $encoder, sampleRate: $sampleRate, '
      'numChannels: $numChannels, bitRate: $bitRate, '
      'amplitudeInterval: $amplitudeInterval, deviceId: $deviceId)';
}
