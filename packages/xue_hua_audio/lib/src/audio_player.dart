import 'dart:async';

import 'package:xue_hua_audio_platform_interface/xue_hua_audio_platform_interface.dart';

/// A high-level audio player supporting local files, network URLs and
/// Flutter assets.
///
/// Each [AudioPlayer] owns one native player instance. Multiple players can
/// be created and played simultaneously; audio is mixed by the OS.
///
/// Typical usage / 典型用法:
///
/// ```dart
/// final player = AudioPlayer();
/// player.onStateChanged.listen((s) => print('state: $s'));
/// player.onPositionChanged.listen((p) => print('position: $p'));
///
/// final duration = await player.setSource(
///   AudioSource.asset('assets/audio/ring.wav'),
/// );
/// await player.play();
/// ...
/// await player.dispose();
/// ```
///
/// 高层音频播放器，支持本地文件、网络 URL 与 Flutter Asset 三种音频源。
///
/// 每个 [AudioPlayer] 对应一个原生播放器实例；可以同时创建多个播放器并发
/// 播放，混音由操作系统完成。
class AudioPlayer {
  /// Creates a player.
  ///
  /// [positionUpdateInterval]: how often [onPositionChanged] emits while
  /// playing, defaults to 100 ms.
  ///
  /// The native instance is created lazily and asynchronously; every method
  /// transparently waits for it, so the player is usable immediately.
  ///
  /// 创建一个播放器。
  ///
  /// [positionUpdateInterval]：播放期间 [onPositionChanged] 的推送间隔，
  /// 默认 100 毫秒。
  ///
  /// 原生实例采用异步惰性创建；所有方法都会自动等待创建完成，因此
  /// 构造后即可直接使用。
  AudioPlayer({
    this.positionUpdateInterval = const Duration(milliseconds: 100),
  }) {
    _idFuture = _create();
  }

  /// Interval between [onPositionChanged] events while playing.
  /// 播放期间 [onPositionChanged] 事件的推送间隔。
  final Duration positionUpdateInterval;

  static XueHuaAudioPlatform get _platform => XueHuaAudioPlatform.instance;

  late final Future<int> _idFuture;
  StreamSubscription<PlayerEvent>? _eventSub;
  Timer? _positionTimer;
  bool _disposed = false;

  PlayerState _state = PlayerState.idle;
  Duration? _duration;
  Duration _lastPosition = Duration.zero;

  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _errorController = StreamController<AudioError>.broadcast();

  // -----------------------------------------------------------------------
  // Introspection / 状态查询
  // -----------------------------------------------------------------------

  /// The current lifecycle state. / 当前生命周期状态。
  PlayerState get state => _state;

  /// Whether the player is currently playing. / 是否正在播放。
  bool get isPlaying => _state == PlayerState.playing;

  /// The last known total duration, `null` when no source is loaded or the
  /// duration is unknown (live streams).
  /// 最近一次已知的音频总时长；未加载音频或时长未知（直播流）时为 `null`。
  Duration? get duration => _duration;

  /// Whether [dispose] has been called. / 是否已调用 [dispose]。
  bool get isDisposed => _disposed;

  // -----------------------------------------------------------------------
  // Event streams / 事件流
  // -----------------------------------------------------------------------

  /// Emits every [PlayerState] transition. / 推送每一次 [PlayerState] 状态变更。
  Stream<PlayerState> get onStateChanged => _stateController.stream;

  /// Emits the playback position every [positionUpdateInterval] while
  /// playing, plus once after seek/pause/stop so the UI stays fresh.
  /// 播放期间每隔 [positionUpdateInterval] 推送一次播放位置；seek、暂停、
  /// 停止后也会额外推送一次，保证 UI 及时刷新。
  Stream<Duration> get onPositionChanged => _positionController.stream;

  /// Emits whenever the total duration becomes known or changes.
  /// 当总时长首次可知或发生变化时推送。
  Stream<Duration?> get onDurationChanged => _durationController.stream;

  /// Emits asynchronous playback errors (e.g. a network stream failing
  /// mid-playback). Errors thrown directly by methods are not duplicated
  /// here.
  /// 推送异步播放错误（例如播放途中网络流失败）。方法直接抛出的错误不会
  /// 在此重复推送。
  Stream<AudioError> get onError => _errorController.stream;

  /// Emits once each time playback reaches the end of the audio.
  /// 每当播放到达音频末尾时推送一次。
  Stream<void> get onPlayerComplete =>
      onStateChanged.where((s) => s == PlayerState.completed);

  // -----------------------------------------------------------------------
  // Commands / 控制指令
  // -----------------------------------------------------------------------

  /// Loads [source] into the player.
  ///
  /// [source]: a local file, network URL or Flutter asset, see [AudioSource].
  ///
  /// Returns the total duration, or `null` when unknown (live streams).
  /// Transitions the state to [PlayerState.loading] and then
  /// [PlayerState.ready]. Throws an [AudioError] when loading fails.
  ///
  /// 加载音频源 [source]。
  ///
  /// [source]：本地文件、网络 URL 或 Flutter Asset，见 [AudioSource]。
  ///
  /// 返回音频总时长；未知（如直播流）时返回 `null`。状态会先进入
  /// [PlayerState.loading]，加载成功后进入 [PlayerState.ready]。
  /// 加载失败时抛出 [AudioError]。
  Future<Duration?> setSource(AudioSource source) async {
    final id = await _ensureCreated();
    try {
      final duration = await _platform.setSource(id, source);
      _duration = duration;
      _durationController.add(duration);
      return duration;
    } on AudioError {
      _setState(PlayerState.error);
      rethrow;
    }
  }

  /// Starts playback, or resumes it when paused.
  ///
  /// A source must have been loaded via [setSource] first.
  ///
  /// 开始播放；若处于暂停状态则恢复播放。
  ///
  /// 调用前必须先通过 [setSource] 加载音频源。
  Future<void> play() async {
    final id = await _ensureCreated();
    await _platform.play(id);
  }

  /// Pauses playback, keeping the current position. / 暂停播放并保留当前进度。
  Future<void> pause() async {
    final id = await _ensureCreated();
    await _platform.pause(id);
    await _emitPosition();
  }

  /// Stops playback and rewinds to the beginning. The loaded source is kept,
  /// so [play] starts over from the beginning.
  /// 停止播放并回到起点；已加载的音频源保留，再次 [play] 会从头播放。
  Future<void> stop() async {
    final id = await _ensureCreated();
    await _platform.stopPlayer(id);
    _lastPosition = Duration.zero;
    _positionController.add(Duration.zero);
  }

  /// Seeks to [position]. Completes when the seek has been applied.
  /// 跳转到 [position]；seek 生效后 Future 才完成。
  Future<void> seek(Duration position) async {
    final id = await _ensureCreated();
    await _platform.seekTo(id, position);
    await _emitPosition();
  }

  /// Sets the volume.
  ///
  /// [volume]: `0.0` (mute) … `1.0` (full volume); values outside the range
  /// are clamped.
  ///
  /// 设置音量。
  ///
  /// [volume]：`0.0`（静音）～ `1.0`（最大音量）；超出范围的值会被截断。
  Future<void> setVolume(double volume) async {
    final id = await _ensureCreated();
    await _platform.setVolume(id, volume);
  }

  /// Sets the playback speed.
  ///
  /// [speed]: rate multiplier, typically `0.5` … `2.0`; `1.0` is normal
  /// speed. Must be greater than 0.
  ///
  /// 设置播放速度。
  ///
  /// [speed]：倍速系数，常见范围 `0.5` ～ `2.0`；`1.0` 为原速，必须大于 0。
  Future<void> setSpeed(double speed) async {
    assert(speed > 0, 'speed must be > 0');
    final id = await _ensureCreated();
    await _platform.setSpeed(id, speed);
  }

  /// Enables or disables looping.
  ///
  /// [looping]: when `true`, playback restarts from the beginning instead of
  /// completing.
  ///
  /// 开启或关闭循环播放。
  ///
  /// [looping]：为 `true` 时播放到末尾自动从头继续，而不会进入完成状态。
  Future<void> setLooping(bool looping) async {
    final id = await _ensureCreated();
    await _platform.setLooping(id, looping);
  }

  /// Reads the current playback position from the platform.
  /// 从平台读取当前播放位置。
  Future<Duration> getPosition() async {
    final id = await _ensureCreated();
    return _platform.getPosition(id);
  }

  /// Lists the available audio output devices (speakers, headphones, …).
  ///
  /// Returns a list of [AudioDevice]; pass an id to [setOutputDevice] to
  /// route this player to that device. On iOS only the devices of the
  /// current audio route are reported (the system does not allow apps to
  /// enumerate every output). On Web the labels may be empty until the user
  /// has granted a media permission.
  ///
  /// 列出可用的音频输出设备（扬声器、耳机等）。
  ///
  /// 返回 [AudioDevice] 列表；把某个设备的 id 传给 [setOutputDevice] 即可将
  /// 本播放器路由到该设备。iOS 端只能返回当前音频路由中的设备（系统不允许
  /// App 枚举全部输出设备）；Web 端在用户授予媒体权限前 label 可能为空。
  static Future<List<AudioDevice>> listOutputDevices() =>
      _platform.listOutputDevices();

  /// Returns the output device this player is routed to, or `null` when it
  /// follows the system default.
  /// 返回本播放器当前路由到的输出设备；跟随系统默认设备时返回 `null`。
  Future<AudioDevice?> getOutputDevice() async {
    final id = await _ensureCreated();
    return _platform.getOutputDevice(id);
  }

  /// Routes this player to the output device [deviceId].
  ///
  /// [deviceId]: an id from [listOutputDevices], or `null` to go back to the
  /// system default device.
  ///
  /// Throws an [AudioError] with code [AudioError.codeUnsupported] on
  /// platforms that cannot route playback per device (e.g. iOS). On Windows
  /// and Linux the new device takes effect from the next [setSource] call;
  /// on Android, macOS and Web it applies immediately, even while playing.
  ///
  /// 将本播放器路由到输出设备 [deviceId]。
  ///
  /// [deviceId]：来自 [listOutputDevices] 的设备 id；传 `null` 恢复系统默认
  /// 设备。
  ///
  /// 不支持按设备路由的平台（如 iOS）会抛出 code 为
  /// [AudioError.codeUnsupported] 的 [AudioError]；Windows 与 Linux 上新设备
  /// 自下一次 [setSource] 起生效，Android、macOS、Web 则立即生效（播放中
  /// 亦可切换）。
  Future<void> setOutputDevice(String? deviceId) async {
    final id = await _ensureCreated();
    await _platform.setOutputDevice(id, deviceId);
  }

  /// Releases the native player and closes every stream. Safe to call more
  /// than once; the player must not be used afterwards.
  /// 释放原生播放器并关闭所有事件流。可安全地重复调用；释放后不可再使用。
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _positionTimer?.cancel();
    _positionTimer = null;
    await _eventSub?.cancel();
    _eventSub = null;
    try {
      final id = await _idFuture;
      await _platform.disposePlayer(id);
    } catch (_) {
      // Creation may have failed; there is nothing to release then.
      // 创建可能已失败，此时无资源可释放。
    }
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _errorController.close();
  }

  // -----------------------------------------------------------------------
  // Internals / 内部实现
  // -----------------------------------------------------------------------

  Future<int> _create() async {
    final id = await _platform.createPlayer();
    _eventSub = _platform.playerEvents(id).listen(_onEvent);
    return id;
  }

  Future<int> _ensureCreated() {
    if (_disposed) {
      throw StateError(
        'AudioPlayer has been disposed and can no longer be used. '
        'AudioPlayer 已被释放，无法继续使用。',
      );
    }
    return _idFuture;
  }

  void _onEvent(PlayerEvent event) {
    switch (event) {
      case PlayerStateEvent(:final state):
        _setState(state);
      case PlayerCompletedEvent():
        _setState(PlayerState.completed);
      case PlayerDurationEvent(:final duration):
        _duration = duration;
        _durationController.add(duration);
      case PlayerErrorEvent(:final error):
        _errorController.add(error);
        _setState(PlayerState.error);
    }
  }

  void _setState(PlayerState next) {
    if (_disposed || next == _state) {
      return;
    }
    _state = next;
    _stateController.add(next);
    if (next == PlayerState.playing) {
      _startPositionTimer();
    } else {
      _positionTimer?.cancel();
      _positionTimer = null;
      if (next == PlayerState.completed && _duration != null) {
        _positionController.add(_duration!);
      }
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(positionUpdateInterval, (_) {
      _emitPosition();
    });
  }

  Future<void> _emitPosition() async {
    if (_disposed) {
      return;
    }
    try {
      final id = await _idFuture;
      final position = await _platform.getPosition(id);
      if (!_disposed && position != _lastPosition) {
        _lastPosition = position;
        _positionController.add(position);
      }
    } on AudioError {
      // Position polling races with dispose/stop; ignore transient failures.
      // 位置轮询可能与释放/停止竞争，忽略瞬时失败。
    }
  }
}
