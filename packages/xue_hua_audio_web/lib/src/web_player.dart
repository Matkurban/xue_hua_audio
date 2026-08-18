import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;
import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

/// One playback instance backed by an [web.HTMLAudioElement].
///
/// The browser handles streaming, buffering and decoding; state changes are
/// mapped from media element events onto the plugin's [PlayerEvent] model.
///
/// 基于 [web.HTMLAudioElement] 的单个播放实例。
///
/// 流式加载、缓冲与解码均由浏览器完成；媒体元素事件被映射为插件的
/// [PlayerEvent] 状态模型。
class WebPlayer {
  /// Creates the player and hooks up all media element events.
  /// 创建播放器并挂接全部媒体元素事件。
  WebPlayer() {
    _audio.preload = 'auto';

    _audio.addEventListener(
      'loadedmetadata',
      ((web.Event _) {
        final duration = _durationOrNull();
        events.add(PlayerDurationEvent(duration));
        final load = _pendingLoad;
        if (load != null) {
          _pendingLoad = null;
          _emitState(PlayerState.ready);
          load.complete(duration);
        }
      }).toJS,
    );

    _audio.addEventListener(
      'playing',
      ((web.Event _) {
        _startedOnce = true;
        _emitState(PlayerState.playing);
      }).toJS,
    );

    _audio.addEventListener(
      'pause',
      ((web.Event _) {
        if (_audio.ended) {
          return;
        }
        if (_stoppedByUser) {
          _emitState(PlayerState.stopped);
        } else if (_startedOnce) {
          _emitState(PlayerState.paused);
        }
      }).toJS,
    );

    _audio.addEventListener(
      'ended',
      ((web.Event _) => _emitState(PlayerState.completed)).toJS,
    );

    _audio.addEventListener(
      'waiting',
      ((web.Event _) => _emitState(PlayerState.loading)).toJS,
    );

    _audio.addEventListener(
      'error',
      ((web.Event _) {
        final message =
            _audio.error?.message ?? 'Media element failed to load or play';
        final load = _pendingLoad;
        if (load != null) {
          _pendingLoad = null;
          load.completeError(
            AudioError(code: AudioError.codeSourceLoadFailed, message: message),
          );
          return;
        }
        events.add(
          PlayerErrorEvent(
            AudioError(code: AudioError.codePlaybackFailed, message: message),
          ),
        );
        _emitState(PlayerState.error);
      }).toJS,
    );
  }

  final web.HTMLAudioElement _audio = web.HTMLAudioElement();

  /// Routes this element to the output device [deviceId] via `setSinkId`
  /// (`null`/empty = browser default). Applies immediately, also while
  /// playing. Throws `unsupported` when the browser lacks `setSinkId`.
  ///
  /// 通过 `setSinkId` 将本元素路由到输出设备 [deviceId]（`null`/空串为浏览器
  /// 默认设备）。立即生效，播放中亦可切换；浏览器不支持 `setSinkId` 时抛出
  /// `unsupported`。
  Future<void> setOutputDevice(String? deviceId) async {
    if (!_audio.has('setSinkId')) {
      throw const AudioError(
        code: AudioError.codeUnsupported,
        message: 'This browser does not support HTMLMediaElement.setSinkId',
      );
    }
    try {
      await _audio.setSinkId(deviceId ?? '').toDart;
    } catch (e) {
      throw AudioError(
        code: AudioError.codeDeviceNotFound,
        message: 'Cannot route to output device $deviceId: $e',
      );
    }
  }

  /// The current sink id, `null` when following the browser default.
  /// 当前输出设备 id；跟随浏览器默认设备时为 `null`。
  String? outputDeviceId() {
    if (!_audio.has('sinkId')) {
      return null;
    }
    final sinkId = _audio.sinkId;
    return sinkId.isEmpty ? null : sinkId;
  }

  /// The event stream consumed by the platform implementation.
  /// 供平台实现消费的事件流。
  final StreamController<PlayerEvent> events =
      StreamController<PlayerEvent>.broadcast();

  Completer<Duration?>? _pendingLoad;
  bool _startedOnce = false;
  bool _stoppedByUser = false;
  PlayerState? _lastState;

  void _emitState(PlayerState state) {
    if (state == _lastState) {
      return;
    }
    _lastState = state;
    events.add(PlayerStateEvent(state));
  }

  Duration? _durationOrNull() {
    final seconds = _audio.duration;
    if (seconds.isNaN || seconds.isInfinite) {
      return null;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Loads [source] and resolves with the duration once metadata is known.
  ///
  /// HTTP headers are not supported by the media element and are ignored;
  /// `AudioSource.file` is treated as a URL (e.g. a blob URL).
  ///
  /// 加载 [source]，元数据可用后返回时长。
  ///
  /// 媒体元素不支持自定义 HTTP 请求头（忽略之）；`AudioSource.file`
  /// 会按 URL 处理（例如 blob URL）。
  Future<Duration?> setSource(AudioSource source) {
    _pendingLoad?.completeError(
      const AudioError(
        code: AudioError.codeSourceLoadFailed,
        message: 'Replaced by a newer setSource call',
      ),
    );
    final completer = Completer<Duration?>();
    _pendingLoad = completer;
    _startedOnce = false;
    _stoppedByUser = false;
    _lastState = null;
    _emitState(PlayerState.loading);

    final url = switch (source) {
      FileSource(:final path) => path,
      UrlSource(:final url) => url,
      AssetSource() => ui_web.assetManager.getAssetUrl(source.resolvedKey),
    };
    _audio.src = url;
    _audio.load();
    return completer.future;
  }

  /// Starts/resumes playback; maps autoplay-policy rejections to
  /// [AudioError]. / 开始或恢复播放；自动播放策略拒绝会映射为 [AudioError]。
  Future<void> play() async {
    _stoppedByUser = false;
    if (_audio.ended) {
      _audio.currentTime = 0;
      _lastState = null;
    }
    try {
      await _audio.play().toDart;
    } catch (e) {
      throw AudioError(
        code: AudioError.codePlaybackFailed,
        message: 'Playback was blocked by the browser (user gesture may be '
            'required): $e',
      );
    }
  }

  /// Pauses playback. / 暂停播放。
  void pause() => _audio.pause();

  /// Stops playback and rewinds. / 停止播放并回到起点。
  void stop() {
    _stoppedByUser = true;
    _audio.pause();
    _audio.currentTime = 0;
    _emitState(PlayerState.stopped);
  }

  /// Seeks to [position]. / 跳转到 [position]。
  void seek(Duration position) {
    _audio.currentTime = position.inMilliseconds / 1000.0;
    if (_lastState == PlayerState.completed) {
      _emitState(PlayerState.ready);
    }
  }

  /// Sets volume 0.0–1.0. / 设置音量（0.0～1.0）。
  void setVolume(double volume) => _audio.volume = volume.clamp(0.0, 1.0);

  /// Sets playback speed. / 设置播放速度。
  void setSpeed(double speed) => _audio.playbackRate = speed;

  /// Enables/disables looping (native `loop` attribute).
  /// 开启或关闭循环（使用原生 `loop` 属性）。
  void setLooping(bool looping) => _audio.loop = looping;

  /// Current position. / 当前位置。
  Duration position() =>
      Duration(milliseconds: (_audio.currentTime * 1000).round());

  /// Duration or null. / 时长，未知为 null。
  Duration? duration() => _durationOrNull();

  /// Releases the element and closes the stream. / 释放元素并关闭事件流。
  void dispose() {
    _audio.pause();
    _audio.removeAttribute('src');
    _audio.load();
    events.close();
  }
}
