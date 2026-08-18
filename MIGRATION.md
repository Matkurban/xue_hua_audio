# Migrating from 1.x to 2.0 / 从 1.x 迁移到 2.0

xue_hua_audio 2.0 is a complete rewrite. The Rust (`flutter_rust_bridge` +
`rodio`) engine has been replaced by fully native implementations on every
platform, packaged as a federated plugin.

xue_hua_audio 2.0 是一次彻底重写：Rust（`flutter_rust_bridge` + `rodio`）引擎被
各平台的纯原生实现取代，并采用联合插件（Federated Plugin）架构发布。

| Platform / 平台 | 1.x | 2.0 |
| --- | --- | --- |
| Android | Rust FFI (rodio/cpal) | Media3 ExoPlayer + AudioRecord |
| iOS / macOS | Rust FFI | AVPlayer + AVAudioEngine |
| Windows | Rust FFI | Media Foundation + WASAPI |
| Linux | Rust FFI | GStreamer |
| Web | ❌ 不支持 | ✅ HTMLAudioElement + MediaRecorder |

Key benefits / 主要收益：

- No Rust toolchain, no cargokit, no codegen step — plain `flutter pub add`.
  无需 Rust 工具链、cargokit 与代码生成，直接 `flutter pub add` 即可。
- Network URLs stream natively instead of being downloaded to temp files.
  网络音频改为原生流式播放，不再下载到临时文件。
- New Web platform support. / 新增 Web 平台支持。
- Real-time amplitude (dBFS) stream for waveform UIs on every platform.
  全平台实时振幅（dBFS）流，可直接驱动波形 UI。

## Initialization / 初始化

There is no global engine any more. Create instances where you need them.

不再有全局引擎；在需要的地方直接创建实例即可。

```dart
// 1.x
final audio = await XueHuaAudio.initialize();
final engine = audio.engine;

// 2.0 — no initialization required. / 无需任何初始化。
final player = AudioPlayer();
final recorder = AudioRecorder();
```

## Playback / 播放

| 1.x | 2.0 |
| --- | --- |
| `engine.loadLocal(path: p)` | `player.setSource(AudioSource.file(p))` |
| `engine.loadAsset(assetKey: k)` | `player.setSource(AudioSource.asset(k))` |
| `engine.loadUrl(url: u)` | `player.setSource(AudioSource.url(u, headers: ...))` |
| `loadXxx(loop: true)` | `player.setLooping(true)` |
| `track.pause()` | `player.pause()` |
| `track.resume()` | `player.play()` |
| `track.stop()` | `player.stop()` |
| `track.seekTo(positionSecs: 3.5)` | `player.seek(Duration(milliseconds: 3500))` |
| `track.setVolume(volume: 0.5)` | `player.setVolume(0.5)` |
| `track.volume()` | 自行保存音量值 / keep the value you set |
| `track.positionSecs()` | `player.getPosition()` → `Duration` |
| `track.isPlaying()` / `isPaused()` / `isFinished()` | `player.state`（`PlayerState` 枚举） |
| `track.watchPlaybackProgress()` / `progressStream` | `player.onPositionChanged`（`Stream<Duration>`） |
| — | `player.setSpeed(1.5)`（新增变速 / new） |
| — | `player.onStateChanged` / `onDurationChanged` / `onError` |
| `track.stopAndCleanup()` | `player.dispose()` |
| `engine.stopAllWithCleanup()` / `stopAll()` | 各实例自行 `stop()` / `dispose()` |
| `engine.loadFromBytes` / `replaceFromBytes` | 已移除；先写入文件再用 `AudioSource.file` |

Example / 示例：

```dart
final player = AudioPlayer();
final duration = await player.setSource(
  AudioSource.url('https://example.com/song.mp3'),
);
player.onPositionChanged.listen((position) => print('$position / $duration'));
await player.play();
// ...
await player.dispose();
```

## Recording / 录音

| 1.x | 2.0 |
| --- | --- |
| `engine.createRecordingSession()` | `AudioRecorder()` |
| `listInputDevices()` → `List<String>` | `recorder.listInputDevices()` → `List<InputDevice>`（含稳定 id） |
| `session.start(outputPath: p, deviceIndex: i)` | `recorder.start(RecordConfig(deviceId: id), path: p)` |
| `session.progressStream`（`level` 字段） | `recorder.onAmplitudeChanged`（`Amplitude`：`current`/`max` dBFS、`normalized` 0~1） |
| `session.progressStream`（`durationSecs`） | 由 UI 自行计时，或订阅状态流 |
| `session.completedStream` | `stop()` 的返回值 / return value of `stop()` |
| `session.pause()` / `resume()` | `recorder.pause()` / `recorder.resume()` |
| `session.stop()` → `String` | `recorder.stop()` → `String?`（Web 返回 blob URL） |
| `session.isRecording` / `isPaused` | `recorder.state`（`RecorderState` 枚举） |
| — | `recorder.hasPermission()`（新增权限检查/请求） |
| — | `recorder.cancel()`（停止并删除文件 / stop & delete） |
| `session.dispose()` | `recorder.dispose()` |

The output format is now configurable via `RecordConfig` (WAV / AAC-LC /
Opus, sample rate, channels, bit rate, amplitude interval).

输出格式现可通过 `RecordConfig` 配置（WAV / AAC-LC / Opus、采样率、声道数、
比特率、振幅推送间隔）。

```dart
final recorder = AudioRecorder();
if (await recorder.hasPermission()) {
  recorder.onAmplitudeChanged.listen((a) => drawBar(a.normalized));
  await recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc),
    path: '/path/to/output.m4a',
  );
  // ...
  final file = await recorder.stop();
}
```

## Error handling / 错误处理

1.x surfaced raw Rust `XueHuaAudioError` exceptions. 2.0 throws a structured
`AudioError` (`code` + `message` + `details`) from every async method and also
publishes it on `player.onError` / `recorder.onError`.

1.x 直接抛出 Rust 侧的 `XueHuaAudioError`；2.0 所有异步方法统一抛出结构化的
`AudioError`（`code` + `message` + `details`），同时通过
`player.onError` / `recorder.onError` 事件流推送。

## Removed APIs / 移除的能力

- `XueHuaAudio.initialize` / `instance` / global `dispose` — no global engine.
  不再有全局引擎与单例。
- `engine.stopAll()` — manage each `AudioPlayer` instance yourself.
  改为由各 `AudioPlayer` 实例自行管理。
- `loadFromBytes` — write bytes to a file first. / 先写文件再播放。
- `TempFileRegistry` — no temp files are created any more. / 不再产生临时文件。
- Output-device switching stays out of scope for 2.0 (planned for 2.1).
  输出设备切换暂不在 2.0 范围内（规划于 2.1）。

## Platform setup / 平台配置

- **Android**: `RECORD_AUDIO` and `INTERNET` are declared by the plugin
  manifest; nothing to add. / 插件清单已声明所需权限，无需额外配置。
- **iOS**: add `NSMicrophoneUsageDescription` to `Info.plist`.
  在 `Info.plist` 中添加 `NSMicrophoneUsageDescription`。
- **macOS**: add `NSMicrophoneUsageDescription` plus the
  `com.apple.security.device.audio-input` and
  `com.apple.security.network.client` entitlements.
  除麦克风用途描述外，还需两项沙盒 entitlement。
- **Linux**: requires GStreamer development packages when building
  (`libgstreamer1.0-dev` and the `good`/`bad` plugin sets at runtime).
  构建需安装 GStreamer 开发包，运行时需要 good/bad 插件集。
- **Web**: recording produces `audio/webm;codecs=opus` (Chrome/Firefox) or
  `audio/mp4` (Safari); `stop()` returns a blob URL. The page must be served
  over HTTPS (or localhost) for microphone access.
  Web 录音输出格式随浏览器而定，`stop()` 返回 blob URL；麦克风访问要求
  HTTPS（或 localhost）环境。
