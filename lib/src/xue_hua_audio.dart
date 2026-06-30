import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'rust/engine.dart';
import 'rust/error.dart';
import 'rust/frb_generated.dart';
import 'rust/playback.dart';
import 'rust/recording.dart';
import 'rust/track.dart';

/// 网络与下载相关配置。
class XuehuaAudioOptions {
  const XuehuaAudioOptions({
    this.urlTimeout = const Duration(seconds: 30),
    this.urlMaxRetries = 2,
    this.urlRetryDelay = const Duration(milliseconds: 500),
  });

  final Duration urlTimeout;
  final int urlMaxRetries;
  final Duration urlRetryDelay;
}

/// 雪花音频播放器公开入口。
class XuehuaAudio {
  XuehuaAudio._(this._engine, this._options);

  static XuehuaAudio? _instance;

  final XueHuaAudioEngine _engine;
  final XuehuaAudioOptions _options;

  /// 插件唯一初始化入口：加载 Rust 库并创建 [XueHuaAudioEngine]。
  ///
  /// 幂等：已初始化时直接返回已有实例。
  static Future<XuehuaAudio> initialize({
    XuehuaAudioOptions options = const XuehuaAudioOptions(),
  }) async {
    if (_instance != null) return _instance!;
    await RustLib.init();
    final engine = await XueHuaAudioEngine.newInstance();
    _instance = XuehuaAudio._(engine, options);
    return _instance!;
  }

  static XuehuaAudio get instance {
    final current = _instance;
    if (current == null) {
      throw StateError('Call XuehuaAudio.initialize() first');
    }
    return current;
  }

  XueHuaAudioEngine get engine => _engine;

  XuehuaAudioOptions get options => _options;

  /// 停止所有音轨、录制会话、清理临时文件并释放引擎。
  ///
  /// 内部调用 [XueHuaAudioEngine.stopAll]，会停止所有 Player 并使仍持有的
  /// [XueHuaAudioTrack] 句柄失效。若仍持有 Track 引用，应再调用 [XueHuaAudioTrack.stop]
  /// 或 [XueHuaAudioTrackLifecycle.stopAndCleanup] 完成注销。
  Future<void> dispose() async {
    await _engine.stopAll();
    await _engine.stopAllRecorders();
    await TempFileRegistry.instance.cleanupAll();
    _engine.dispose();
    _instance = null;
    RustLib.dispose();
  }
}

/// 三种音源加载方式。
extension XueHuaAudioEngineLoading on XueHuaAudioEngine {
  /// 本地文件系统绝对路径（Rust 侧流式解码）。
  Future<XueHuaAudioTrack> loadLocal({
    required String path,
    bool loop = false,
  }) => loadFromPath(path: path, loop: loop);

  /// Flutter Asset（pubspec 声明路径）→ 临时文件 → 流式播放。
  Future<XueHuaAudioTrack> loadAsset({
    required String assetKey,
    bool loop = false,
  }) async {
    final data = await rootBundle.load(assetKey);
    final tempPath = await _writeTempAudioFile(
      bytes: data.buffer.asUint8List(),
      suffix: _suffixFromAssetKey(assetKey),
    );
    final track = await loadFromPath(path: tempPath, loop: loop);
    TempFileRegistry.instance.register(track, tempPath);
    return track;
  }

  /// 网络 URL → 超时/重试下载 → 临时文件 → 流式播放。
  Future<XueHuaAudioTrack> loadUrl({
    required String url,
    bool loop = false,
    Duration? timeout,
    int? maxRetries,
  }) async {
    final player = XuehuaAudio.instance;
    final tempPath = await _downloadToTempFile(
      url: url,
      timeout: timeout ?? player.options.urlTimeout,
      maxRetries: maxRetries ?? player.options.urlMaxRetries,
      retryDelay: player.options.urlRetryDelay,
    );
    final track = await loadFromPath(path: tempPath, loop: loop);
    TempFileRegistry.instance.register(track, tempPath);
    return track;
  }

  /// 停止所有音轨并清理已注册的临时文件。
  ///
  /// [stopAll] 会停止引擎 registry 中所有 Player；仍持有的 Track 句柄上
  /// [XueHuaAudioTrack.stop] 可幂等调用以完成注销。
  /// 播放进度 [XueHuaAudioTrackProgress.progressStream] 在 Track 停止后将无法重新订阅。
  Future<void> stopAllWithCleanup() async {
    await stopAll();
    await stopAllRecorders();
    await TempFileRegistry.instance.cleanupAll();
  }
}

/// 麦克风录制扩展。
extension XueHuaAudioEngineRecording on XueHuaAudioEngine {
  Future<XuehuaRecordingSession> createRecordingSession() async =>
      XuehuaRecordingSession._(await createRecorder());
}

/// 高层录制会话，将 FRB 事件 Stream 拆分为进度与完成流。
class XuehuaRecordingSession {
  XuehuaRecordingSession._(this._recorder);

  final XueHuaAudioRecorder _recorder;
  StreamSubscription<XueHuaRecordingEvent>? _subscription;
  final StreamController<XueHuaRecordingProgress> _progressController =
      StreamController<XueHuaRecordingProgress>.broadcast();
  final StreamController<XueHuaRecordingCompleted> _completedController =
      StreamController<XueHuaRecordingCompleted>.broadcast();

  Stream<XueHuaRecordingProgress> get progressStream =>
      _progressController.stream;

  Stream<XueHuaRecordingCompleted> get completedStream =>
      _completedController.stream;

  XueHuaAudioRecorder get recorder => _recorder;

  Future<void> start({required String outputPath, int? deviceIndex}) async {
    await _subscription?.cancel();
    final events = _recorder.start(
      outputPath: outputPath,
      deviceIndex: deviceIndex,
    );
    _subscription = events.listen((event) {
      event.map(
        progress: (value) => _progressController.add(value.field0),
        completed: (value) => _completedController.add(value.field0),
      );
    }, onError: _progressController.addError);
  }

  Future<void> pause() => _recorder.pause();

  Future<void> resume() => _recorder.resume();

  Future<String> stop() => _recorder.stop();

  bool get isRecording => _recorder.isRecording();

  bool get isPaused => _recorder.isPaused();

  Future<void> dispose() async {
    await _subscription?.cancel();
    if (_recorder.isRecording()) {
      await _recorder.stop();
    }
    await _progressController.close();
    await _completedController.close();
  }
}

/// 播放进度 Stream 扩展（约每 100ms 推送）。
extension XueHuaAudioTrackProgress on XueHuaAudioTrack {
  Stream<XueHuaPlaybackProgress> get progressStream => watchPlaybackProgress();
}

/// 对通过 Asset/URL 加载的音轨，停止时一并删除临时文件。
extension XueHuaAudioTrackLifecycle on XueHuaAudioTrack {
  Future<void> stopAndCleanup() async {
    await stop();
    await TempFileRegistry.instance.cleanup(this);
  }
}

/// 关联 Asset/URL 音轨与其临时文件路径。
final class TempFileRegistry {
  TempFileRegistry._();

  static final TempFileRegistry instance = TempFileRegistry._();

  final Map<int, String> _pathsByTrack = {};

  void register(XueHuaAudioTrack track, String tempPath) {
    _pathsByTrack[identityHashCode(track)] = tempPath;
  }

  Future<void> cleanup(XueHuaAudioTrack track) async {
    final path = _pathsByTrack.remove(identityHashCode(track));
    if (path != null) {
      await _deleteIfExists(path);
    }
  }

  Future<void> cleanupAll() async {
    final paths = _pathsByTrack.values.toList();
    _pathsByTrack.clear();
    for (final path in paths) {
      await _deleteIfExists(path);
    }
  }
}

Future<String> _writeTempAudioFile({
  required List<int> bytes,
  required String suffix,
}) async {
  final fileName =
      'xuehua_audio_${DateTime.now().microsecondsSinceEpoch}$suffix';
  final file = File(p.join(Directory.systemTemp.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> _downloadToTempFile({
  required String url,
  required Duration timeout,
  required int maxRetries,
  required Duration retryDelay,
}) async {
  final uri = Uri.parse(url);
  final client = http.Client();
  try {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(retryDelay * attempt);
      }
      try {
        final response = await client.get(uri).timeout(timeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final suffix = _suffixFromUrl(url);
          return _writeTempAudioFile(bytes: response.bodyBytes, suffix: suffix);
        }
        lastError = XueHuaAudioError.decode(
          'HTTP ${response.statusCode} for $url',
        );
      } on Exception catch (error) {
        lastError = error;
      }
    }
    if (lastError is XueHuaAudioError) {
      throw lastError;
    }
    throw XueHuaAudioError.decode('Failed to download $url: $lastError');
  } finally {
    client.close();
  }
}

String _suffixFromAssetKey(String assetKey) {
  final ext = p.extension(assetKey);
  return ext.isEmpty ? '.bin' : ext;
}

String _suffixFromUrl(String url) {
  final ext = p.extension(Uri.parse(url).path);
  return ext.isEmpty ? '.bin' : ext;
}

Future<void> _deleteIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
