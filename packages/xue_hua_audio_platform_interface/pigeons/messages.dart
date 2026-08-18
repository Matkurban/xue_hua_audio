// Pigeon definition for the xue_hua_audio plugin.
// Run `dart run pigeon --input pigeons/messages.dart` from the
// xue_hua_audio_platform_interface package to regenerate all bindings.
//
// xue_hua_audio 插件的 Pigeon 通信定义文件。
// 在 xue_hua_audio_platform_interface 包目录下运行
// `dart run pigeon --input pigeons/messages.dart` 可重新生成所有平台绑定代码。
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        '../xue_hua_audio_android/android/src/main/kotlin/com/xuehua/xue_hua_audio_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.xuehua.xue_hua_audio_android'),
    swiftOut:
        '../xue_hua_audio_darwin/darwin/xue_hua_audio_darwin/Sources/xue_hua_audio_darwin/Messages.g.swift',
    cppHeaderOut: '../xue_hua_audio_windows/windows/messages.g.h',
    cppSourceOut: '../xue_hua_audio_windows/windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'xue_hua_audio_windows'),
    gobjectHeaderOut: '../xue_hua_audio_linux/linux/messages.g.h',
    gobjectSourceOut: '../xue_hua_audio_linux/linux/messages.g.cc',
    gobjectOptions: GObjectOptions(module: 'XhaMessages'),
    dartPackageName: 'xue_hua_audio_platform_interface',
  ),
)
/// The kind of an audio source. / 音频源的种类。
enum SourceTypeMessage {
  /// A local file path. / 本地文件路径。
  file,

  /// A remote HTTP(S) URL. / 远程 HTTP(S) 网络地址。
  url,

  /// A Flutter asset key. / Flutter Asset 资源键。
  asset,
}

/// The audio encoder used when recording. / 录音时使用的编码器。
enum EncoderMessage {
  /// Linear PCM in a WAV container. / WAV 容器中的线性 PCM。
  wav,

  /// AAC-LC in an MPEG-4 container. / MPEG-4 容器中的 AAC-LC。
  aacLc,

  /// Opus (Ogg or WebM container, platform dependent). / Opus 编码（Ogg 或 WebM 容器，视平台而定）。
  opus,
}

/// Wire representation of an audio source. / 音频源的跨端传输结构。
class AudioSourceMessage {
  AudioSourceMessage({required this.type, required this.uri, this.headers});

  /// The kind of source. / 源的种类。
  SourceTypeMessage type;

  /// File path, URL, or fully-resolved asset key depending on [type].
  /// 依据 [type] 不同，可能是文件路径、URL 或已解析的 asset 键。
  String uri;

  /// Optional HTTP headers, only meaningful for [SourceTypeMessage.url].
  /// 可选的 HTTP 请求头，仅对 [SourceTypeMessage.url] 有意义。
  Map<String, String>? headers;
}

/// Wire representation of a recording configuration. / 录音配置的跨端传输结构。
class RecordConfigMessage {
  RecordConfigMessage({
    required this.encoder,
    required this.sampleRate,
    required this.numChannels,
    required this.bitRate,
    required this.amplitudeIntervalMs,
    this.deviceId,
  });

  /// Encoder to use. / 使用的编码器。
  EncoderMessage encoder;

  /// Sample rate in Hz. / 采样率（Hz）。
  int sampleRate;

  /// Number of channels (1 = mono, 2 = stereo). / 声道数（1 单声道，2 立体声）。
  int numChannels;

  /// Bit rate in bits per second (compressed encoders only).
  /// 比特率（bit/s，仅压缩编码器使用）。
  int bitRate;

  /// Interval between amplitude events in milliseconds.
  /// 振幅事件的推送间隔（毫秒）。
  int amplitudeIntervalMs;

  /// Preferred input device id, `null` for the system default.
  /// 期望使用的输入设备 id，`null` 表示系统默认设备。
  String? deviceId;
}

/// Wire representation of an audio device (input or output).
/// 音频设备（输入或输出）的跨端传输结构。
class AudioDeviceMessage {
  AudioDeviceMessage({required this.id, required this.label});

  /// Platform-specific stable device identifier. / 平台相关的稳定设备标识。
  String id;

  /// Human-readable device name. / 供人阅读的设备名称。
  String label;
}

/// Host API implemented natively for audio playback control.
/// 由原生端实现的音频播放控制接口。
@HostApi()
abstract class AudioPlayerHostApi {
  /// Creates a native player instance and returns its id.
  /// 创建一个原生播放器实例并返回其 id。
  int createPlayer();

  /// Loads [source] into the player and returns the duration in
  /// milliseconds, or `null` when unknown (e.g. live streams).
  /// 加载音频源 [source]，返回音频时长（毫秒）；未知时（如直播流）返回 `null`。
  @async
  int? setSource(int playerId, AudioSourceMessage source);

  /// Starts or resumes playback. / 开始或恢复播放。
  void play(int playerId);

  /// Pauses playback keeping the position. / 暂停播放并保留进度。
  void pause(int playerId);

  /// Stops playback and rewinds to the beginning. / 停止播放并回到起点。
  void stop(int playerId);

  /// Seeks to [positionMs] milliseconds. / 跳转到 [positionMs]（毫秒）。
  @async
  void seekTo(int playerId, int positionMs);

  /// Sets the volume, 0.0 to 1.0. / 设置音量（0.0 ~ 1.0）。
  void setVolume(int playerId, double volume);

  /// Sets the playback speed, e.g. 0.5 to 2.0. / 设置播放速度（如 0.5 ~ 2.0）。
  void setSpeed(int playerId, double speed);

  /// Enables or disables looping. / 开启或关闭循环播放。
  void setLooping(int playerId, bool looping);

  /// Returns the current position in milliseconds. / 返回当前播放位置（毫秒）。
  int getPosition(int playerId);

  /// Returns the duration in milliseconds or `null` when unknown.
  /// 返回音频时长（毫秒），未知时返回 `null`。
  int? getDuration(int playerId);

  /// Lists the available audio output devices. / 列出可用的音频输出设备。
  @async
  List<AudioDeviceMessage> listOutputDevices();

  /// Returns the output device used by the player, or `null` when following
  /// the system default. / 返回播放器当前使用的输出设备；跟随系统默认时返回 `null`。
  @async
  AudioDeviceMessage? getOutputDevice(int playerId);

  /// Routes the player to the output device [deviceId], or back to the
  /// system default when `null`.
  /// 将播放器路由到输出设备 [deviceId]；传 `null` 恢复系统默认设备。
  @async
  void setOutputDevice(int playerId, String? deviceId);

  /// Releases all native resources of the player. / 释放播放器的全部原生资源。
  void disposePlayer(int playerId);
}

/// Host API implemented natively for microphone recording control.
/// 由原生端实现的麦克风录音控制接口。
@HostApi()
abstract class AudioRecorderHostApi {
  /// Creates a native recorder instance and returns its id.
  /// 创建一个原生录音机实例并返回其 id。
  int createRecorder();

  /// Checks (and requests when possible) microphone permission.
  /// Returns `true` when recording is permitted.
  /// 检查（并在可能时请求）麦克风权限；允许录音时返回 `true`。
  @async
  bool hasPermission();

  /// Lists the available audio input devices. / 列出可用的音频输入设备。
  @async
  List<AudioDeviceMessage> listInputDevices();

  /// Returns the input device used by the recorder, or `null` when following
  /// the system default. / 返回录音机当前使用的输入设备；跟随系统默认时返回 `null`。
  @async
  AudioDeviceMessage? getInputDevice(int recorderId);

  /// Selects the input device [deviceId] for the recorder, or the system
  /// default when `null`. Live switching support is platform dependent.
  /// 为录音机选择输入设备 [deviceId]；传 `null` 使用系统默认设备。
  /// 录音过程中切换的支持情况视平台而定。
  @async
  void setInputDevice(int recorderId, String? deviceId);

  /// Starts recording to [path] using [config]. Completes once recording
  /// has actually started.
  /// 使用 [config] 开始录音并写入 [path]；录音真正启动后才完成。
  @async
  void start(int recorderId, RecordConfigMessage config, String path);

  /// Pauses recording. / 暂停录音。
  void pause(int recorderId);

  /// Resumes a paused recording. / 恢复已暂停的录音。
  void resume(int recorderId);

  /// Stops recording and returns the recorded file path, or `null` when
  /// nothing was recorded.
  /// 停止录音并返回录音文件路径；未产生录音时返回 `null`。
  @async
  String? stop(int recorderId);

  /// Stops recording and deletes the partial file. / 停止录音并删除未完成的文件。
  @async
  void cancel(int recorderId);

  /// Releases all native resources of the recorder. / 释放录音机的全部原生资源。
  void disposeRecorder(int recorderId);
}
