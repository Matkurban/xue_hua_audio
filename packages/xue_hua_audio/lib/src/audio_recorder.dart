import 'dart:async';

import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

/// A high-level microphone recorder with real-time amplitude reporting,
/// suitable for driving waveform UIs.
///
/// Typical usage / 典型用法:
///
/// ```dart
/// final recorder = AudioRecorder();
/// if (await recorder.hasPermission()) {
///   recorder.onAmplitudeChanged.listen((a) => paintBar(a.normalized));
///   await recorder.start(const RecordConfig(), path: '/tmp/take1.wav');
///   ...
///   final file = await recorder.stop();
/// }
/// await recorder.dispose();
/// ```
///
/// 高层麦克风录音机，支持实时振幅上报，可直接驱动波形 UI。
class AudioRecorder {
  /// Creates a recorder.
  ///
  /// The native instance is created lazily and asynchronously; every method
  /// transparently waits for it, so the recorder is usable immediately.
  ///
  /// 创建一个录音机。
  ///
  /// 原生实例采用异步惰性创建；所有方法都会自动等待创建完成，因此
  /// 构造后即可直接使用。
  AudioRecorder() {
    _idFuture = _create();
  }

  static XueHuaAudioPlatform get _platform => XueHuaAudioPlatform.instance;

  late final Future<int> _idFuture;
  StreamSubscription<RecorderEvent>? _eventSub;
  bool _disposed = false;

  RecorderState _state = RecorderState.idle;

  final _stateController = StreamController<RecorderState>.broadcast();
  final _amplitudeController = StreamController<Amplitude>.broadcast();
  final _errorController = StreamController<AudioError>.broadcast();

  // -----------------------------------------------------------------------
  // Introspection / 状态查询
  // -----------------------------------------------------------------------

  /// The current lifecycle state. / 当前生命周期状态。
  RecorderState get state => _state;

  /// Whether audio is being captured right now (not paused).
  /// 当前是否正在采集音频（非暂停状态）。
  bool get isRecording => _state == RecorderState.recording;

  /// Whether [dispose] has been called. / 是否已调用 [dispose]。
  bool get isDisposed => _disposed;

  // -----------------------------------------------------------------------
  // Event streams / 事件流
  // -----------------------------------------------------------------------

  /// Emits every [RecorderState] transition. / 推送每一次 [RecorderState] 状态变更。
  Stream<RecorderState> get onStateChanged => _stateController.stream;

  /// Emits an [Amplitude] sample every `RecordConfig.amplitudeInterval`
  /// while recording — use `Amplitude.normalized` (0.0–1.0) to render
  /// waveform bars.
  /// 录音期间每隔 `RecordConfig.amplitudeInterval` 推送一次 [Amplitude]
  /// 采样；用 `Amplitude.normalized`（0.0～1.0）即可渲染波形柱。
  Stream<Amplitude> get onAmplitudeChanged => _amplitudeController.stream;

  /// Emits asynchronous recording errors (e.g. the input device
  /// disappearing). Errors thrown directly by methods are not duplicated
  /// here.
  /// 推送异步录音错误（如输入设备被拔出）。方法直接抛出的错误不会在此
  /// 重复推送。
  Stream<AudioError> get onError => _errorController.stream;

  // -----------------------------------------------------------------------
  // Commands / 控制指令
  // -----------------------------------------------------------------------

  /// Checks — and requests when the platform supports prompting — the
  /// microphone permission.
  ///
  /// Returns `true` when recording is permitted. On Android and iOS this
  /// shows the system permission dialog when permission has not been
  /// decided yet.
  ///
  /// 检查（并在平台支持时请求）麦克风权限。
  ///
  /// 允许录音时返回 `true`。在 Android 与 iOS 上，如果用户尚未做出选择，
  /// 会弹出系统权限对话框。
  Future<bool> hasPermission() => _platform.hasRecordPermission();

  /// Lists the available audio input devices (microphones).
  ///
  /// Returns a list of [AudioDevice]; pass an id to [setInputDevice] or to
  /// `RecordConfig.deviceId` to record from a specific device. On Web the
  /// labels may be empty until microphone permission has been granted.
  ///
  /// 列出可用的音频输入设备（麦克风）。
  ///
  /// 返回 [AudioDevice] 列表；把某个设备的 id 传给 [setInputDevice] 或
  /// `RecordConfig.deviceId` 即可用该设备录音。Web 端在麦克风权限授予前
  /// label 可能为空。
  Future<List<AudioDevice>> listInputDevices() => _platform.listInputDevices();

  /// Returns the input device this recorder captures from, or `null` when it
  /// follows the system default.
  /// 返回本录音机当前采集使用的输入设备；跟随系统默认设备时返回 `null`。
  Future<AudioDevice?> getInputDevice() async {
    final id = await _ensureCreated();
    return _platform.getInputDevice(id);
  }

  /// Selects the input device [deviceId] for this recorder.
  ///
  /// [deviceId]: an id from [listInputDevices], or `null` to use the system
  /// default device.
  ///
  /// Live switching while recording is supported on Android and iOS. On
  /// macOS, Web, Windows and Linux calling this while recording throws an
  /// [AudioError] with code [AudioError.codeInvalidState] — set the device
  /// before [start]. `RecordConfig.deviceId` passed to [start] overrides
  /// this preference for that recording.
  ///
  /// 为本录音机选择输入设备 [deviceId]。
  ///
  /// [deviceId]：来自 [listInputDevices] 的设备 id；传 `null` 使用系统默认
  /// 设备。
  ///
  /// Android 与 iOS 支持录音过程中切换；macOS、Web、Windows、Linux 在录音中
  /// 调用会抛出 code 为 [AudioError.codeInvalidState] 的 [AudioError]，请在
  /// [start] 前设置。[start] 时传入的 `RecordConfig.deviceId` 会在该次录音中
  /// 覆盖此偏好。
  Future<void> setInputDevice(String? deviceId) async {
    final id = await _ensureCreated();
    await _platform.setInputDevice(id, deviceId);
  }

  /// Starts recording.
  ///
  /// [config]: encoder, sample rate, channels, amplitude interval and input
  /// device, see [RecordConfig].
  /// [path]: absolute output file path. Choose an extension matching the
  /// encoder (`.wav`, `.m4a`, `.ogg`). Ignored on Web, where [stop] returns
  /// a blob URL instead.
  ///
  /// Completes once capture has actually started; the state transitions to
  /// [RecorderState.recording]. Throws an [AudioError] (e.g.
  /// `permissionDenied`) when recording cannot start.
  ///
  /// 开始录音。
  ///
  /// [config]：编码器、采样率、声道数、振幅间隔与输入设备等，见 [RecordConfig]。
  /// [path]：输出文件的绝对路径，扩展名需与编码器匹配（`.wav`、`.m4a`、
  /// `.ogg`）。Web 端忽略该参数，[stop] 会返回 blob URL。
  ///
  /// 采集真正开始后 Future 才完成，状态进入 [RecorderState.recording]。
  /// 无法启动时抛出 [AudioError]（例如 `permissionDenied`）。
  Future<void> start(RecordConfig config, {required String path}) async {
    final id = await _ensureCreated();
    await _platform.startRecorder(id, config, path: path);
  }

  /// Pauses recording; captured audio so far is kept.
  /// 暂停录音；已采集的音频保留。
  Future<void> pause() async {
    final id = await _ensureCreated();
    await _platform.pauseRecorder(id);
  }

  /// Resumes a paused recording. / 恢复已暂停的录音。
  Future<void> resume() async {
    final id = await _ensureCreated();
    await _platform.resumeRecorder(id);
  }

  /// Stops recording and finalizes the file.
  ///
  /// Returns the recorded file path (a blob URL on Web), or `null` when
  /// nothing was recorded.
  ///
  /// 停止录音并完成文件写入。
  ///
  /// 返回录音文件路径（Web 端为 blob URL）；未产生录音时返回 `null`。
  Future<String?> stop() async {
    final id = await _ensureCreated();
    return _platform.stopRecorder(id);
  }

  /// Stops recording and deletes the partial file — use this to discard a
  /// take.
  /// 停止录音并删除未完成的文件——用于放弃本次录音。
  Future<void> cancel() async {
    final id = await _ensureCreated();
    await _platform.cancelRecorder(id);
  }

  /// Releases the native recorder and closes every stream. A running
  /// recording is cancelled. Safe to call more than once; the recorder must
  /// not be used afterwards.
  /// 释放原生录音机并关闭所有事件流；进行中的录音会被取消。可安全地重复
  /// 调用；释放后不可再使用。
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _eventSub?.cancel();
    _eventSub = null;
    try {
      final id = await _idFuture;
      await _platform.disposeRecorder(id);
    } catch (_) {
      // Creation may have failed; there is nothing to release then.
      // 创建可能已失败，此时无资源可释放。
    }
    await _stateController.close();
    await _amplitudeController.close();
    await _errorController.close();
  }

  // -----------------------------------------------------------------------
  // Internals / 内部实现
  // -----------------------------------------------------------------------

  Future<int> _create() async {
    final id = await _platform.createRecorder();
    _eventSub = _platform.recorderEvents(id).listen(_onEvent);
    return id;
  }

  Future<int> _ensureCreated() {
    if (_disposed) {
      throw StateError(
        'AudioRecorder has been disposed and can no longer be used. '
        'AudioRecorder 已被释放，无法继续使用。',
      );
    }
    return _idFuture;
  }

  void _onEvent(RecorderEvent event) {
    if (_disposed) {
      return;
    }
    switch (event) {
      case RecorderStateEvent(:final state):
        if (state != _state) {
          _state = state;
          _stateController.add(state);
        }
      case RecorderAmplitudeEvent(:final amplitude):
        _amplitudeController.add(amplitude);
      case RecorderErrorEvent(:final error):
        _errorController.add(error);
        if (_state != RecorderState.error) {
          _state = RecorderState.error;
          _stateController.add(RecorderState.error);
        }
    }
  }
}
