import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

/// One microphone recording instance backed by `getUserMedia` +
/// [web.MediaRecorder], with real-time amplitude from an
/// [web.AnalyserNode].
///
/// The browser picks the actual container/codec: Chrome and Firefox
/// produce `audio/webm;codecs=opus`, Safari produces `audio/mp4` (AAC).
/// The requested [AudioEncoder] is treated as a preference via
/// `MediaRecorder.isTypeSupported`. Recorded data lives in memory;
/// [stop] returns a blob URL.
///
/// 基于 `getUserMedia` + [web.MediaRecorder] 的单个麦克风录音实例，
/// 并通过 [web.AnalyserNode] 实时计算振幅。
///
/// 实际容器/编码由浏览器决定：Chrome/Firefox 输出
/// `audio/webm;codecs=opus`，Safari 输出 `audio/mp4`（AAC）。
/// 请求的 [AudioEncoder] 仅作为偏好，经 `MediaRecorder.isTypeSupported`
/// 探测选型。录音数据保存在内存中，[stop] 返回 blob URL。
class WebRecorder {
  /// The event stream consumed by the platform implementation.
  /// 供平台实现消费的事件流。
  final StreamController<RecorderEvent> events =
      StreamController<RecorderEvent>.broadcast();

  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  web.AudioContext? _audioContext;
  web.AnalyserNode? _analyser;
  Timer? _amplitudeTimer;
  final List<web.Blob> _chunks = [];
  String _mimeType = '';
  double _maxDb = -160;

  /// Instance-level preferred input device id, `null` = browser default.
  /// 实例级偏好的输入设备 id；`null` 表示浏览器默认设备。
  String? _preferredDeviceId;

  /// Selects the input device [deviceId] for the next [start]; switching
  /// while recording throws `invalidState`.
  /// 为下一次 [start] 选择输入设备 [deviceId]；录音中切换会抛出
  /// `invalidState`。
  void setInputDevice(String? deviceId) {
    if (_recorder != null) {
      throw const AudioError(
        code: AudioError.codeInvalidState,
        message:
            'Cannot switch the input device while recording on the Web; '
            'set it before start()',
      );
    }
    _preferredDeviceId = deviceId;
  }

  /// The id of the input device in use: the live track's device while
  /// recording, otherwise the stored preference (`null` = default).
  /// 当前使用的输入设备 id：录音中返回实际音轨设备，否则返回已存偏好
  /// （`null` 表示默认设备）。
  String? currentInputDeviceId() {
    final tracks = _stream?.getAudioTracks().toDart;
    if (tracks != null && tracks.isNotEmpty) {
      final deviceId = tracks.first.getSettings().deviceId;
      if (deviceId.isNotEmpty) {
        return deviceId;
      }
    }
    return _preferredDeviceId;
  }

  /// Picks the best supported MIME type for [encoder], `null` for the
  /// browser default. / 为 [encoder] 选择浏览器支持的最优 MIME 类型；
  /// 返回 `null` 表示交给浏览器默认值。
  static String? _pickMimeType(AudioEncoder encoder) {
    final candidates = switch (encoder) {
      AudioEncoder.opus => [
          'audio/webm;codecs=opus',
          'audio/ogg;codecs=opus',
          'audio/webm',
        ],
      AudioEncoder.aacLc => ['audio/mp4', 'audio/aac'],
      // WAV recording is not supported by MediaRecorder; fall back to the
      // best available compressed format.
      // MediaRecorder 不支持 WAV，回退到可用的压缩格式。
      AudioEncoder.wav => [
          'audio/webm;codecs=opus',
          'audio/mp4',
          'audio/ogg;codecs=opus',
        ],
    };
    for (final type in candidates) {
      if (web.MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }
    return null;
  }

  void _emitState(RecorderState state) {
    events.add(RecorderStateEvent(state));
  }

  /// Starts capturing with [config]. The `path` argument of the public API
  /// is ignored on the Web. / 按 [config] 开始采集；公共 API 的 `path`
  /// 参数在 Web 端被忽略。
  Future<void> start(RecordConfig config) async {
    if (_recorder != null) {
      throw const AudioError(
        code: AudioError.codeInvalidState,
        message: 'Recorder is already recording',
      );
    }

    // The per-start config id wins over the instance-level preference.
    // start 时传入的设备 id 优先于实例级偏好。
    final wantedDeviceId = config.deviceId ?? _preferredDeviceId;
    final constraints = web.MediaStreamConstraints(
      audio: wantedDeviceId == null
          ? true.toJS
          : web.MediaTrackConstraints(
              deviceId: wantedDeviceId.toJS,
              channelCount: config.numChannels.toJS,
            ),
    );

    final web.MediaStream stream;
    try {
      stream =
          await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
    } catch (e) {
      throw AudioError(
        code: AudioError.codePermissionDenied,
        message: 'Microphone access was denied: $e',
      );
    }

    final mimeType = _pickMimeType(config.encoder);
    final recorder = web.MediaRecorder(
      stream,
      mimeType == null
          ? web.MediaRecorderOptions(audioBitsPerSecond: config.bitRate)
          : web.MediaRecorderOptions(
              mimeType: mimeType,
              audioBitsPerSecond: config.bitRate,
            ),
    );
    _mimeType = mimeType ?? recorder.mimeType;

    _chunks.clear();
    recorder.ondataavailable = ((web.BlobEvent event) {
      if (event.data.size > 0) {
        _chunks.add(event.data);
      }
    }).toJS;

    // Analyser graph for the amplitude stream.
    // 用于振幅流的分析节点图。
    final audioContext = web.AudioContext();
    final sourceNode = audioContext.createMediaStreamSource(stream);
    final analyser = audioContext.createAnalyser();
    analyser.fftSize = 2048;
    sourceNode.connect(analyser);

    _stream = stream;
    _recorder = recorder;
    _audioContext = audioContext;
    _analyser = analyser;
    _maxDb = -160;

    recorder.start(250);
    _startAmplitudeTimer(config.amplitudeInterval);
    _emitState(RecorderState.recording);
  }

  void _startAmplitudeTimer(Duration interval) {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(interval, (_) {
      final analyser = _analyser;
      if (analyser == null || _recorder?.state != 'recording') {
        return;
      }
      final jsSamples = Float32List(analyser.fftSize).toJS;
      analyser.getFloatTimeDomainData(jsSamples);
      final samples = jsSamples.toDart;
      var peak = 0.0;
      for (final sample in samples) {
        peak = math.max(peak, sample.abs());
      }
      final db = peak > 0 ? 20 * math.log(peak) / math.ln10 : -160.0;
      _maxDb = math.max(_maxDb, db);
      events.add(RecorderAmplitudeEvent(Amplitude(current: db, max: _maxDb)));
    });
  }

  /// Pauses capture. / 暂停采集。
  void pause() {
    final recorder = _recorder;
    if (recorder != null && recorder.state == 'recording') {
      recorder.pause();
      _emitState(RecorderState.paused);
    }
  }

  /// Resumes capture. / 恢复采集。
  void resume() {
    final recorder = _recorder;
    if (recorder != null && recorder.state == 'paused') {
      recorder.resume();
      _emitState(RecorderState.recording);
    }
  }

  /// Stops recording and returns a blob URL of the recorded audio, or
  /// `null` when nothing was recorded.
  /// 停止录音并返回录音数据的 blob URL；未产生录音时返回 `null`。
  Future<String?> stop() async {
    final recorder = _recorder;
    if (recorder == null) {
      return null;
    }
    final stopped = Completer<void>();
    recorder.onstop = ((web.Event _) => stopped.complete()).toJS;
    if (recorder.state != 'inactive') {
      recorder.stop();
      await stopped.future;
    }
    _teardown();
    if (_chunks.isEmpty) {
      _emitState(RecorderState.stopped);
      return null;
    }
    final blob = web.Blob(
      _chunks.toJS,
      web.BlobPropertyBag(type: _mimeType),
    );
    _chunks.clear();
    _emitState(RecorderState.stopped);
    return web.URL.createObjectURL(blob);
  }

  /// Stops recording and discards the data. / 停止录音并丢弃数据。
  Future<void> cancel() async {
    final recorder = _recorder;
    if (recorder != null && recorder.state != 'inactive') {
      recorder.stop();
    }
    _teardown();
    _chunks.clear();
    _emitState(RecorderState.stopped);
  }

  /// Releases everything. / 释放全部资源。
  void dispose() {
    final recorder = _recorder;
    if (recorder != null && recorder.state != 'inactive') {
      recorder.stop();
    }
    _teardown();
    _chunks.clear();
    events.close();
  }

  void _teardown() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    final tracks = _stream?.getTracks().toDart;
    if (tracks != null) {
      for (final track in tracks) {
        track.stop();
      }
    }
    _audioContext?.close();
    _audioContext = null;
    _analyser = null;
    _stream = null;
    _recorder = null;
  }
}
