# xue_hua_audio

[English](README.md) | **简体中文**

基于 **Rust**（[rodio](https://crates.io/crates/rodio)）与 [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge) 2.12 的跨平台 Flutter **FFI** 音频插件。

主要能力：

- **多轨播放** — 多路音频同时播放，各自独立音量、暂停、跳转
- **进度 Stream** — Rust 侧推送播放进度（约 100 ms），无需 Dart 轮询
- **麦克风录制** — 录制 WAV，附带电平与时长 Stream
- **多种音源** — 本地文件、Flutter Asset、HTTP URL

支持平台：**Android**、**iOS**、**macOS**、**Linux**、**Windows**。

---

## 目录

- [安装](#安装)
- [快速开始](#快速开始)
- [架构说明](#架构说明)
- [播放](#播放)
- [录制](#录制)
- [生命周期](#生命周期)
- [错误类型](#错误类型)
- [平台配置](#平台配置)
- [各端权限说明](#各端权限说明)
- [开发指南](#开发指南)
- [Example 应用](#example-应用)

---

## 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  xue_hua_audio: ^1.0.2
```

在使用任何音频 API 之前调用一次 `XueHuaAudio.initialize()`（通常在 `main()` 中、`WidgetsFlutterBinding.ensureInitialized()` 之后）。

---

## 快速开始

```dart
import 'package:xue_hua_audio/xue_hua_audio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final player = await XueHuaAudio.initialize();
  final engine = player.engine;

  // 播放 Asset
  final track = await engine.loadAsset(assetKey: 'assets/audio/sample.wav');

  // 订阅进度（约每 100ms）
  final sub = track.progressStream.listen((p) {
    print('${p.positionSecs.toStringAsFixed(1)} / ${p.durationSecs}');
  });

  // … 用完后
  await sub.cancel();
  await track.stopAndCleanup();
  await player.dispose();
}
```

---

## 架构说明

```
┌─────────────────────────────────────────────────────────┐
│  Dart（xue_hua_audio.dart）                       │
│  XueHuaAudio · 扩展方法 · TempFileRegistry        │
└──────────────────────────┬──────────────────────────────┘
                           │ flutter_rust_bridge
┌──────────────────────────▼──────────────────────────────┐
│  Rust                                                     │
│  XueHuaAudioEngine ──► MixerDeviceSink（系统输出）        │
│       ├── XueHuaAudioTrack × N（Player + 进度推送）       │
│       └── XueHuaAudioRecorder（麦克风 → WAV）             │
└───────────────────────────────────────────────────────────┘
```

- **Engine** 持有系统音频输出容器与音轨/录制器注册表，整个应用生命周期内需保持存活。
- **Track** 封装一条 rodio `Player`，接入共享混音器，彼此独立控制。
- **TrackSharedState** 连接 `engine.stopAll()` 与 Track 句柄：全停时 deactivate 并停止进度 watcher。

---

## 播放

### 加载音源

| 方法 | 说明 |
|------|------|
| `engine.loadLocal(path:, loop:)` | 本地绝对路径，Rust 侧流式解码；`loop: true` 循环播放直至 `stop()` |
| `engine.loadAsset(assetKey:, loop:)` | 读取 Flutter Asset → 临时文件 → 播放 |
| `engine.loadUrl(url:, loop:)` | HTTP 下载（超时/重试）→ 临时文件 → 播放 |

`loop` 默认为 `false`。开启后使用 rodio `LoopedDecoder`（流式 seek 回绕循环）。进度 `positionSecs` / `progress` 按单圈回绕；需调用 `track.stop()` 结束。

`XueHuaAudioTrack.replaceFromPath` / `replaceFromBytes` 同样支持 `loop` 参数。

URL 相关参数可在初始化时通过 `XueHuaAudioOptions` 配置：

```dart
await XueHuaAudio.initialize(
  options: XueHuaAudioOptions(
    urlTimeout: Duration(seconds: 30),
    urlMaxRetries: 2,
    urlRetryDelay: Duration(milliseconds: 500),
  ),
);
```

Asset / URL 音轨会在 `TempFileRegistry` 中注册临时文件路径。停止时请使用 `track.stopAndCleanup()` 以同时删除临时文件。

### 音轨控制

```dart
await track.pause();
await track.resume();
await track.setVolume(volume: 0.8);
await track.seekTo(positionSecs: 30.0);

// 一次性进度快照（同步）
final snap = track.playbackProgress();

// 进度 Stream（约 100ms）
track.progressStream.listen((p) { /* … */ });

await track.stop();           // 停止并注销
await track.stopAndCleanup(); // 额外删除 Asset/URL 临时文件
```

### `XueHuaPlaybackProgress` 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `isPlaying` | `bool` | 正在播放（未暂停且队列非空） |
| `isPaused` | `bool` | 已暂停 |
| `isFinished` | `bool` | 队列播完或已被引擎/停止 deactivate |
| `positionSecs` | `double` | 当前位置（秒） |
| `durationSecs` | `double?` | 总时长（未知时为 null） |
| `progress` | `double?` | 进度比 0.0–1.0（时长未知时为 null） |

UI 可先用 `track.playbackProgress()` 立即渲染首帧，再依赖 Stream 更新。

### 支持的解码格式

WAV、MP3、FLAC、Ogg Vorbis、MP4（rodio 0.22 + symphonia）。

---

## 录制

```dart
final session = await engine.createRecordingSession();

session.progressStream.listen((p) {
  print('${p.durationSecs}s  电平=${p.level}');
});

session.completedStream.listen((c) {
  print('已保存: ${c.outputPath}');
});

await session.start(
  outputPath: '/path/to/output.wav',
  deviceIndex: 0, // 可选；null 为默认设备
);

await session.pause();
await session.resume();

final path = await session.stop();
await session.dispose();
```

枚举输入设备：

```dart
final devices = await engine.listInputDevices();
```

### `XueHuaRecordingProgress` 字段

| 字段 | 说明 |
|------|------|
| `isRecording` | 正在录制 |
| `isPaused` | 录制已暂停 |
| `durationSecs` | 已录制时长（秒） |
| `level` | 最近 buffer 峰值 0.0–1.0 |

录制功能需要在各平台**运行时申请麦克风权限**（详见 [各端权限说明](#各端权限说明)）。

### 如何确认录制已完成

仅调用 `pause()` **不会**完成录制，必须调用 `stop()` 才会 finalize WAV 文件并写入磁盘。

**推荐方式（await `stop()`）：**

```dart
final path = await session.stop();
// `path` 与 start() 时传入的 outputPath 一致，WAV 已 finalize
expect(session.isRecording, isFalse);
```

`session.stop()` 会等待 Rust 写入线程结束、刷盘并完成 WAV finalize 后才返回。

**可选：监听 completed 事件**

录制开始前订阅 `completedStream`。写入线程结束时，Rust 会推送 `XueHuaRecordingCompleted`：

```dart
late final StreamSubscription<XueHuaRecordingCompleted> completedSub;

completedSub = session.completedStream.listen((event) {
  print('完成: ${event.outputPath}，时长 ${event.durationSecs}s');
  // event.outputPath — 与 start() 传入路径相同
  // event.durationSecs — 最终录制时长（秒）
});

// … 用户点击停止后
final path = await session.stop();
await completedSub.cancel();
```

`Completed` 事件在 `stop()` 的 `Future` 完成**之前**就会推送，因此 `completedStream` 可能略早于 `await session.stop()` 触发。多数场景只 `await session.stop()` 即可。

**额外校验（可选）：**

```dart
import 'dart:io';

final file = File(path);
expect(await file.exists(), isTrue);
expect(await file.length(), greaterThan(44)); // 非空 WAV
```

完成后 `session.isRecording == false`。可用 `engine.loadLocal(path: path)` 回放验证。

---

## 生命周期

### 推荐：按 Track 停止

用完音轨后调用 `track.stop()` 或 `track.stopAndCleanup()`，将：

1. 停止 rodio Player
2. 从 Engine 注册表注销
3. 停止进度 watcher 线程

### 引擎级全停

`engine.stopAll()` 或 `engine.stopAllWithCleanup()` 会立即停止**所有** Player：

- 将各 Track 共享状态设为 inactive
- 停止全部 progress watcher
- 仍持有的句柄上 `playbackProgress().isFinished == true`
- `track.stop()` **幂等**，可安全再次调用
- 无法再订阅 `track.progressStream`（`AlreadyStopped`）

若需清理 Dart 侧引用与临时文件，**不要**只调用 `stopAll()`，仍应对每条音轨调用 `stopAndCleanup()`。

### 释放引擎

```dart
await player.dispose();
```

会停止所有音轨与录制、清理临时文件并释放 Rust 引擎。`dispose()` 后需再次 `initialize()` 才能继续使用。

---

## 错误类型

`XueHuaAudioError`（Freezed 密封类）：

| 变体 | 场景 |
|------|------|
| `device` | 音频输出/输入设备不可用 |
| `localFile` | 本地文件打开失败 |
| `decode` | 解码/跳转/HTTP 失败 |
| `alreadyStopped` | 对已停止音轨的操作 |
| `recording` | 录制 I/O 或线程错误 |
| `alreadyRecording` | 重复 start |
| `notRecording` | 未录制时 pause/resume/stop |

---

## 平台配置

快速对照表 — 完整说明见 [各端权限说明](#各端权限说明)。

| 平台 | 播放 | 录制 | URL 加载 |
|------|------|------|----------|
| Android | 无额外权限 | `RECORD_AUDIO` + 运行时授权 | App Manifest 声明 `INTERNET` |
| iOS | 无额外权限 | `NSMicrophoneUsageDescription` + 运行时授权 | 默认 ATS（建议 HTTPS） |
| macOS | 无额外权限 | `NSMicrophoneUsageDescription` + Audio Input entitlement + 运行时授权 | 无 |
| Linux | 无 | PulseAudio/PipeWire 设备访问 | 无 |
| Windows | 无 | 系统麦克风隐私设置 | 无 |

插件自身 Android Manifest 已合并 `RECORD_AUDIO`。**你的 App** 仍须在 `session.start()` 前运行时申请麦克风权限。

### Android NDK 初始化

Android 上 rodio/cpal 需要通过 [`ndk_context`](https://docs.rs/ndk-context) 获取 JVM `Context`。若 Rust 库仅由 Dart FFI（`dlopen`）加载，该上下文不会被设置，`XueHuaAudio.initialize()` 可能 panic：`android context was not initialized`。

**常规 Flutter 应用：** 将 `xue_hua_audio` 加入依赖即可 — 插件会注册 `XueHuaAudioPlugin`，在 JVM 中加载 `libxue_hua_audio.so` 并在 Dart `main()` 之前初始化 `ndk_context`，**无需修改 `MainActivity`**。

**自定义 Android 嵌入**（非标准 Flutter 集成）：须在调用任何音频 API 前从 Java/Kotlin 加载原生库，例如 `System.loadLibrary("xue_hua_audio")`。详见 [flutter_rust_bridge Android NDK 初始化指南](https://cjycode.com/flutter_rust_bridge/guides/how-to/ndk-init)。

---

## 开发指南

### 环境要求

- Flutter SDK ≥ 3.3
- Dart SDK ≥ 3.12
- Rust 工具链
- `flutter_rust_bridge_codegen` 2.12

### Dart 静态分析

```bash
dart analyze lib example/lib
```

### 集成测试（macOS）

```bash
cd example
flutter test integration_test/playback_test.dart -d macos
```

录制集成测试默认 skip（测试 harness 无麦克风权限）；请通过 Example 应用手动验证录制。

---

## Example 应用

```bash
cd example
flutter run
```

Demo 包含：

- **录制** — 设备选择、录/停/暂停、电平条、录完回放（含进度 Stream）
- **播放** — 多素材同时播放、音量、跳转、进度 Stream

完整集成示例见 [`example/`](example/)。

---

## 各端权限说明

以下为你 **宿主 App** 需要配置的权限与声明（插件已自带部分 Android 声明）。

### Android

| 项目 | 用途 | 插件已提供 | App 需配置 |
|------|------|------------|------------|
| `android.permission.RECORD_AUDIO` | 录制 | 是（`android/src/main/AndroidManifest.xml`） | 建议在 App Manifest 中再次声明 |
| 运行时麦克风授权 | 录制 | 否 | 是 — 如 `permission_handler` |
| `android.permission.INTERNET` | `loadUrl()` | 否 | 是 — App `AndroidManifest.xml` |
| `minSdkVersion` ≥ 26 | 全部功能 | 插件默认 | App 须 ≥ 26 |
| NDK / JVM 上下文初始化 | 播放与录制 | 是（`XueHuaAudioPlugin`） | 否 — 标准 Flutter 嵌入下自动完成 |

**App Manifest（录制 + URL）：**

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**录制前运行时申请：**

```dart
import 'package:permission_handler/permission_handler.dart';

if (!await Permission.microphone.request().isGranted) {
  // 处理拒绝
}
await session.start(outputPath: path);
```

### iOS

| 项目 | 用途 | 插件 | App |
|------|------|------|-----|
| `NSMicrophoneUsageDescription` | 录制 | 否 | **是** — `ios/Runner/Info.plist` |
| 运行时麦克风授权 | 录制 | 否 | 首次采集时系统弹窗 |

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以录制音频</string>
```

仅播放无需此键。HTTP 音频需配置 App Transport Security 或改用 HTTPS。

### macOS

| 项目 | 用途 | 插件 | App |
|------|------|------|-----|
| `NSMicrophoneUsageDescription` | 录制 | 否 | **是** — `macos/Runner/Info.plist` |
| `com.apple.security.device.audio-input` | 录制 | 否 | **是** — entitlements 文件 |
| 运行时麦克风授权 | 录制 | 否 | 首次采集时系统弹窗 |

**Info.plist：**

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限以录制音频</string>
```

**DebugProfile.entitlements / Release.entitlements：**

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

可参考 [`example/macos/Runner/`](example/macos/Runner/)。

### Linux

| 项目 | 用途 | 说明 |
|------|------|------|
| 音频输出 | 播放 | rodio 经 ALSA/PulseAudio，无 Manifest |
| 音频输入 | 录制 | 需可用麦克风；部分桌面环境会弹出权限对话框 |

无需 Flutter 侧权限声明，确保进程可访问默认输入设备。

### Windows

| 项目 | 用途 | 说明 |
|------|------|------|
| 音频输出 | 播放 | WASAPI |
| 音频输入 | 录制 | **设置 → 隐私 → 麦克风** 中允许桌面应用访问 |

无 Android/iOS 式 Manifest。录制失败时先检查系统麦克风隐私开关。

### 功能与权限对照

| 功能 | Android | iOS | macOS | Linux | Windows |
|------|---------|-----|-------|-------|---------|
| 播放本地 / Asset | — | — | — | — | — |
| URL 播放 | `INTERNET` | ATS / HTTPS | — | — | — |
| 录制 | `RECORD_AUDIO` + 运行时 | plist 说明 + 运行时 | plist + entitlement + 运行时 | 设备访问 | 系统隐私设置 |

---

## 其他

- 版本历史：[CHANGELOG.md](CHANGELOG.md)
- 英文文档：[README.md](README.md)
