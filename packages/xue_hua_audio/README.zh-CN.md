# xue_hua_audio

[English](README.md) | **简体中文**

跨平台**纯原生** Flutter 音频插件——支持本地文件 / 网络 URL / Asset 三种音源播放，
以及带实时振幅流的麦克风录音，覆盖六大平台。无需 Rust 工具链、无 FFI、无代码
生成：每个平台都使用其第一方原生音频 API 实现，并通过类型安全的
[Pigeon](https://pub.dev/packages/pigeon) 通道通信。

| 平台 | 播放 | 录音 |
| --- | --- | --- |
| Android | Media3 ExoPlayer | AudioRecord（WAV / AAC-LC） |
| iOS / macOS | AVPlayer | AVAudioEngine（WAV / AAC-LC） |
| Windows | Media Foundation `IMFMediaEngine` | WASAPI（WAV / AAC-LC） |
| Linux | GStreamer `playbin` | GStreamer `level`（WAV / Opus / AAC） |
| Web | HTMLAudioElement | MediaRecorder + AnalyserNode（Opus / MP4） |

特性：

- **播放**——本地文件、网络 URL（流式播放，支持自定义请求头）、Flutter Asset；
  播放 / 暂停 / 停止 / 跳转 / 音量 / 变速 / 循环。
- **多实例**——可创建任意数量的 `AudioPlayer`，各自持有原生资源、独立释放。
- **录音**——WAV / AAC-LC / Opus 输出，暂停与恢复、取消，采样率 / 声道 /
  比特率可配置，支持选择输入设备。
- **设备管理**——枚举输出 / 输入设备、查询当前设备，并可为每个播放器 /
  录音机指定具体设备。
- **实时振幅**——`Stream<Amplitude>` 提供当前 / 峰值 dBFS 及归一化 0~1 数值，
  可直接驱动波形 UI。
- **类型安全事件**——状态、进度、时长、错误均为独立 `Stream`；全链路结构化
  `AudioError`（code + message + details）。
- **双语文档**——所有公开 API 均带中英双语 dartdoc。

从 1.x（Rust/FFI 版本）迁移？请阅读
[MIGRATION.md](https://github.com/Matkurban/xue_hua_audio/blob/main/MIGRATION.md)。

---

## 安装

```yaml
dependencies:
  xue_hua_audio: ^2.0.0
```

无需任何初始化调用。

## 播放

```dart
import 'package:xue_hua_audio/xue_hua_audio.dart';

final player = AudioPlayer();

// 加载三种音源之一；已知时长时返回时长。
final duration = await player.setSource(
  AudioSource.url('https://example.com/song.mp3'),
);
// AudioSource.file('/path/to/local.mp3')
// AudioSource.asset('assets/audio/ring.wav')

await player.play();
await player.setVolume(0.8);   // 0.0 ~ 1.0
await player.setSpeed(1.5);    // 0.5 ~ 2.0
await player.setLooping(true);
await player.seek(const Duration(seconds: 10));
await player.pause();
await player.stop();

// 事件流
player.onStateChanged.listen((s) => print(s));    // PlayerState
player.onPositionChanged.listen((p) => print(p)); // 默认每 100ms 推送
player.onDurationChanged.listen((d) => print(d));
player.onError.listen((e) => print(e));

// 用完务必释放原生资源。
await player.dispose();
```

`PlayerState` 状态机：`idle → loading → ready → playing ⇄ paused →
completed / stopped`，另有 `error` 与终态 `disposed`。

## 录音

```dart
final recorder = AudioRecorder();

if (await recorder.hasPermission()) {
  // 实时波形：normalized 为 0~1，current/max 为 dBFS。
  recorder.onAmplitudeChanged.listen((a) => drawBar(a.normalized));

  await recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc, // wav / aacLc / opus
      sampleRate: 44100,
      numChannels: 1,
    ),
    path: '/path/to/recording.m4a', // Web 端此参数被忽略
  );

  await recorder.pause();
  await recorder.resume();
  final path = await recorder.stop(); // 文件路径；Web 端为 blob URL
  // await recorder.cancel();         // 或停止并删除文件
}

await recorder.dispose();
```

## 音频设备

播放输出设备（每个播放器独立）：

```dart
final outputs = await AudioPlayer.listOutputDevices();
await player.setOutputDevice(outputs.first.id); // 路由本播放器
final current = await player.getOutputDevice(); // null = 系统默认
await player.setOutputDevice(null);             // 恢复默认设备
```

录音输入设备（每个录音机独立）：

```dart
final inputs = await recorder.listInputDevices();
await recorder.setInputDevice(inputs.first.id); // 实例级偏好
final current = await recorder.getInputDevice(); // null = 系统默认
// 仅对单次录音生效的一次性选择：
await recorder.start(RecordConfig(deviceId: inputs.first.id), path: ...);
```

平台差异：

| 平台 | 设置输出设备 | 录音中切换输入设备 |
| --- | --- | --- |
| Android | ✅ 立即生效（API 23+） | ✅ |
| iOS | ❌ 抛 `unsupported`（由系统路由） | ✅（`setPreferredInput`） |
| macOS | ✅ 立即生效 | ❌ 请在 `start` 前设置 |
| Windows | ✅ 自下一次 `setSource` 生效（Win10 1703+） | ❌ 请在 `start` 前设置 |
| Linux | ✅ 自下一次 `setSource` 生效 | ❌ 请在 `start` 前设置 |
| Web | ✅ 立即生效（`setSinkId`） | ❌ 请在 `start` 前设置 |

iOS 上 `listOutputDevices` 只能返回当前音频路由中的设备；Web 端在授予媒体
权限前设备 label 可能为空。

## 错误处理

所有异步方法统一抛出结构化的 `AudioError`，同时也会通过
`player.onError` / `recorder.onError` 事件流推送：

```dart
try {
  await player.setSource(AudioSource.file('/missing.mp3'));
} on AudioError catch (e) {
  print('${e.code}: ${e.message}'); // 例如 sourceNotFound: ...
}
```

## 平台配置

### Android

无需配置——插件清单已声明 `RECORD_AUDIO` 与 `INTERNET`。最低 SDK 21。

### iOS

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>本应用需要使用麦克风进行录音。</string>
```

最低 iOS 13.0。插件会自动管理 `AVAudioSession`。

### macOS

在 `macos/Runner/Info.plist` 中添加 `NSMicrophoneUsageDescription`，并在
`DebugProfile.entitlements` 与 `Release.entitlements` 中添加：

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

最低 macOS 10.15。

### Windows

无需配置——Media Foundation 与 WASAPI 为 Windows 10+ 系统组件。

### Linux

构建时需要 GStreamer 开发包：

```bash
sudo apt install libgstreamer1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

### Web

- 麦克风访问要求安全上下文（HTTPS 或 localhost）。
- `recorder.stop()` 返回 **blob URL**；实际容器/编码由浏览器决定
  （Chrome/Firefox 为 `audio/webm;codecs=opus`，Safari 为 `audio/mp4`），
  与请求的编码器无关。
- 播放远程音频受 CORS 限制。

## 架构

本插件采用[联合插件](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins)架构：

```text
xue_hua_audio                     ← 应用直接依赖的包
└── xue_hua_audio_platform_interface
    ├── xue_hua_audio_android     Kotlin  · ExoPlayer + AudioRecord
    ├── xue_hua_audio_darwin      Swift   · AVPlayer + AVAudioEngine（iOS+macOS 共享）
    ├── xue_hua_audio_web         Dart    · package:web
    ├── xue_hua_audio_windows     C++     · Media Foundation + WASAPI
    └── xue_hua_audio_linux       C       · GStreamer
```

指令经 Pigeon 生成的类型安全通道下发；事件（状态、进度、时长、振幅、错误）按
实例经 `EventChannel` 回传。Web 实现为纯 Dart，不经过任何通道。

## 示例应用

[example](https://github.com/Matkurban/xue_hua_audio/tree/main/packages/xue_hua_audio/example)
演示了三种音源播放、跳转 / 音量 / 变速 / 循环控制，以及带实时波形的录音。

## 许可证

MIT。
