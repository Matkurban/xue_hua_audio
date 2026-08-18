import 'package:flutter/foundation.dart';

/// A structured error reported by the audio engine.
///
/// Errors are surfaced in two ways / 错误通过两种途径暴露:
///
/// 1. Methods such as `setSource` throw an [AudioError] when the operation
///    itself fails. / 当操作本身失败时，`setSource` 等方法会抛出 [AudioError]。
/// 2. Asynchronous failures (e.g. a network stream dropping mid-playback)
///    are delivered on the `onError` stream. / 异步失败（如播放途中网络流
///    中断）会通过 `onError` 流推送。
@immutable
class AudioError implements Exception {
  /// Creates an audio error.
  ///
  /// [code]: a stable, machine-readable error code (see the `code*`
  /// constants).
  /// [message]: a human-readable description of what went wrong.
  /// [details]: optional platform-specific diagnostic payload.
  ///
  /// 创建一个音频错误。
  ///
  /// [code]：稳定的、可供程序判断的错误码（见 `code*` 常量）。
  /// [message]：供人阅读的错误描述。
  /// [details]：可选的平台相关诊断信息。
  const AudioError({required this.code, required this.message, this.details});

  /// The referenced player/recorder no longer exists. / 目标播放器或录音机已不存在。
  static const String codeInstanceNotFound = 'instanceNotFound';

  /// The source could not be loaded or decoded. / 音频源无法加载或解码。
  static const String codeSourceLoadFailed = 'sourceLoadFailed';

  /// A playback failure occurred after loading. / 加载完成后播放过程发生失败。
  static const String codePlaybackFailed = 'playbackFailed';

  /// Microphone permission was denied. / 麦克风权限被拒绝。
  static const String codePermissionDenied = 'permissionDenied';

  /// Recording could not be started or failed mid-way. / 录音无法启动或中途失败。
  static const String codeRecordingFailed = 'recordingFailed';

  /// The requested encoder is not supported on this platform.
  /// 当前平台不支持所请求的编码器。
  static const String codeUnsupportedEncoder = 'unsupportedEncoder';

  /// The operation is invalid in the current state. / 当前状态下不允许该操作。
  static const String codeInvalidState = 'invalidState';

  /// The operation is not supported on this platform (e.g. per-player output
  /// routing on iOS). / 当前平台不支持该操作（如 iOS 上按播放器路由输出设备）。
  static const String codeUnsupported = 'unsupported';

  /// The referenced audio device does not exist or is unavailable.
  /// 指定的音频设备不存在或不可用。
  static const String codeDeviceNotFound = 'deviceNotFound';

  /// Stable machine-readable error code. / 稳定的机器可读错误码。
  final String code;

  /// Human-readable error description. / 供人阅读的错误描述。
  final String message;

  /// Optional platform-specific diagnostic payload. / 可选的平台相关诊断信息。
  final Object? details;

  @override
  bool operator ==(Object other) =>
      other is AudioError &&
      other.code == code &&
      other.message == message &&
      other.details == details;

  @override
  int get hashCode => Object.hash(code, message, details);

  @override
  String toString() => 'AudioError($code): $message'
      '${details == null ? '' : ' — $details'}';
}
