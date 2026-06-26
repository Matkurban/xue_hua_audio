# xue_hua_audio

**English** | [简体中文](README.zh-CN.md)

Cross-platform Flutter **FFI** audio plugin powered by **Rust** ([rodio](https://crates.io/crates/rodio)) and [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge) 2.12.

Features:

- **Multi-track playback** — several sounds at once, each with independent volume, pause, and seek
- **Progress streams** — push-based playback position (~100 ms), no Dart polling
- **Recording** — microphone capture to WAV with level/duration streams
- **Multiple sources** — local files, Flutter assets, and HTTP URLs

Supported platforms: **Android**, **iOS**, **macOS**, **Linux**, **Windows**.

---

## Table of contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Architecture](#architecture)
- [Playback](#playback)
- [Recording](#recording)
- [Lifecycle](#lifecycle)
- [Errors](#errors)
- [Platform setup](#platform-setup)
- [Platform permissions reference](#platform-permissions-reference)
- [Development](#development)
- [Example app](#example-app)

---

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  xue_hua_audio: ^1.0.1
```

Call `XuehuaAudio.initialize()` once before any audio API (typically in `main()` after `WidgetsFlutterBinding.ensureInitialized()`).

---

## Quick start

```dart
import 'package:xue_hua_audio/xue_hua_audio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final player = await XuehuaAudio.initialize();
  final engine = player.engine;

  // Play a bundled asset
  final track = await engine.loadAsset(assetKey: 'assets/audio/sample.wav');

  // Subscribe to progress (~100 ms)
  final sub = track.progressStream.listen((p) {
    print('${p.positionSecs.toStringAsFixed(1)} / ${p.durationSecs}');
  });

  // … later
  await sub.cancel();
  await track.stopAndCleanup();
  await player.dispose();
}
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Dart (xue_hua_audio.dart)                        │
│  XuehuaAudio · extensions · TempFileRegistry      │
└──────────────────────────┬──────────────────────────────┘
                           │ flutter_rust_bridge
┌──────────────────────────▼──────────────────────────────┐
│  Rust                                                     │
│  XueHuaAudioEngine ──► MixerDeviceSink (system output)   │
│       ├── XueHuaAudioTrack × N  (Player + progress)     │
│       └── XueHuaAudioRecorder   (mic → WAV)             │
└───────────────────────────────────────────────────────────┘
```

- **Engine** owns the system audio sink and track/recorder registries. The sink must stay alive for the app lifetime.
- **Track** wraps one rodio `Player` connected to the shared mixer. Each track is independent.
- **TrackSharedState** links engine `stopAll()` with track handles: deactivates the track and stops progress watchers.

---

## Playback

### Loading audio

| Method | Description |
|--------|-------------|
| `engine.loadLocal(path:, loop:)` | Absolute filesystem path; streamed decode on Rust side; `loop: true` repeats until `stop()` |
| `engine.loadAsset(assetKey:, loop:)` | Reads Flutter asset → temp file → play |
| `engine.loadUrl(url:, loop:)` | HTTP GET with timeout/retry → temp file → play |

`loop` defaults to `false`. When enabled, playback uses rodio `LoopedDecoder` (streamed seek-back loop). Progress `positionSecs` / `progress` wrap each lap; call `track.stop()` to end.

`XueHuaAudioTrack.replaceFromPath` / `replaceFromBytes` also accept `loop`.

URL options are configured via `XuehuaAudioOptions` at initialize time:

```dart
await XuehuaAudio.initialize(
  options: XuehuaAudioOptions(
    urlTimeout: Duration(seconds: 30),
    urlMaxRetries: 2,
    urlRetryDelay: Duration(milliseconds: 500),
  ),
);
```

Asset and URL tracks register temp files in `TempFileRegistry`. Use `track.stopAndCleanup()` to stop and delete the temp file.

### Track controls

```dart
await track.pause();
await track.resume();
await track.setVolume(volume: 0.8);
await track.seekTo(positionSecs: 30.0);

// One-shot progress snapshot (sync)
final snap = track.playbackProgress();

// Stream (~100 ms)
track.progressStream.listen((p) { /* … */ });

await track.stop();           // stop + unregister
await track.stopAndCleanup(); // + delete temp file if Asset/URL
```

### `XueHuaPlaybackProgress`

| Field | Type | Description |
|-------|------|-------------|
| `isPlaying` | `bool` | Active and not paused/empty |
| `isPaused` | `bool` | Paused |
| `isFinished` | `bool` | Queue drained or track deactivated |
| `positionSecs` | `double` | Current position in seconds |
| `durationSecs` | `double?` | Total duration if known |
| `progress` | `double?` | Ratio 0.0–1.0 when duration is known |

Initial UI can use `track.playbackProgress()` immediately; the stream updates thereafter.

### Supported decode formats

WAV, MP3, FLAC, Ogg Vorbis, MP4 (via rodio 0.22 + symphonia).

---

## Recording

```dart
final session = await engine.createRecordingSession();

session.progressStream.listen((p) {
  print('${p.durationSecs}s  level=${p.level}');
});

session.completedStream.listen((c) {
  print('Saved: ${c.outputPath}');
});

await session.start(
  outputPath: '/path/to/output.wav',
  deviceIndex: 0, // optional; default device if null
);

await session.pause();
await session.resume();

final path = await session.stop();
await session.dispose();
```

List input devices:

```dart
final devices = await engine.listInputDevices();
```

### `XueHuaRecordingProgress`

| Field | Description |
|-------|-------------|
| `isRecording` | Session active |
| `isPaused` | Recording paused |
| `durationSecs` | Elapsed recording time |
| `level` | Recent buffer peak 0.0–1.0 |

Recording requires **runtime microphone permission** on mobile/desktop platforms (see [Platform permissions reference](#platform-permissions-reference)).

### Confirming recording completion

Recording is **not** complete when you only pause — you must call `stop()` to finalize the WAV file.

**Recommended (await `stop()`):**

```dart
final path = await session.stop();
// `path` == outputPath passed to start(); WAV header/data is finalized
expect(session.isRecording, isFalse);
```

`session.stop()` blocks until the Rust writer thread joins, flushes samples, and finalizes the WAV on disk.

**Optional: listen for the completed event**

While recording, subscribe to `completedStream`. When the writer thread finishes, Rust pushes `XueHuaRecordingCompleted`:

```dart
late final StreamSubscription<XueHuaRecordingCompleted> completedSub;

completedSub = session.completedStream.listen((event) {
  print('Done: ${event.outputPath}, ${event.durationSecs}s');
  // event.outputPath — same path as start()
  // event.durationSecs — final recorded length
});

// … after user taps stop
final path = await session.stop();
await completedSub.cancel();
```

The `Completed` event is emitted **before** `stop()` returns, so you may receive it on `completedStream` slightly earlier than the `Future` completes. Using `await session.stop()` alone is sufficient for most apps.

**Extra verification (optional):**

```dart
import 'dart:io';

final file = File(path);
expect(await file.exists(), isTrue);
expect(await file.length(), greaterThan(44)); // non-empty WAV
```

After completion, `session.isRecording` is `false`. You can play the file with `engine.loadLocal(path: path)`.

---

## Lifecycle

### Recommended: stop per track

Always call `track.stop()` or `track.stopAndCleanup()` when done with a track. This:

1. Stops the rodio player
2. Unregisters from the engine
3. Stops the progress watcher thread

### Engine-wide stop

`engine.stopAll()` or `engine.stopAllWithCleanup()` stops **all** players immediately:

- Sets each track's shared state to inactive
- Stops all progress watchers
- `playbackProgress().isFinished` becomes `true` on held handles
- `track.stop()` remains **idempotent** (safe to call again)
- `track.progressStream` cannot be subscribed again (`AlreadyStopped`)

Do **not** rely on `stopAll()` alone if you need to clear Dart references and temp files — still call `stopAndCleanup()` per track.

### Dispose

```dart
await player.dispose();
```

Stops all tracks and recorders, cleans temp files, and releases the Rust engine. After `dispose()`, call `initialize()` again to reuse the plugin.

---

## Errors

`XueHuaAudioError` (Freezed sealed class):

| Variant | When |
|---------|------|
| `device` | Audio output/input device unavailable |
| `localFile` | File open failure |
| `decode` | Decode/seek/HTTP failure |
| `alreadyStopped` | Operation on a stopped track |
| `recording` | Recorder I/O or thread error |
| `alreadyRecording` | `start()` while already recording |
| `notRecording` | Pause/resume/stop when not recording |

---

## Platform setup

Quick checklist — full details in [Platform permissions reference](#platform-permissions-reference).

| Platform | Playback | Recording | URL loading |
|----------|----------|-----------|-------------|
| Android | No extra permission | `RECORD_AUDIO` + runtime grant | `INTERNET` in app manifest |
| iOS | No extra permission | `NSMicrophoneUsageDescription` + runtime grant | App Transport Security (HTTPS default) |
| macOS | No extra permission | `NSMicrophoneUsageDescription` + Audio Input entitlement + runtime grant | None |
| Linux | None | PulseAudio/PipeWire device access | None |
| Windows | None | System microphone access | None |

The plugin merges `RECORD_AUDIO` from its own Android manifest. **Your app** must still request microphone permission at runtime before `session.start()`.

### Android NDK initialization

On Android, rodio/cpal needs the JVM `Context` via [`ndk_context`](https://docs.rs/ndk-context). When the Rust library is loaded only through Dart FFI (`dlopen`), that context is never set and `XuehuaAudio.initialize()` can panic with `android context was not initialized`.

**Normal Flutter apps:** add `xue_hua_audio` as a dependency — the plugin registers `XueHuaAudioPlugin`, which loads `libxue_hua_audio.so` through the JVM and initializes `ndk_context` before Dart `main()` runs. No `MainActivity` changes are required.

**Custom Android embedders** (non-standard Flutter embedding): load the native library from Java/Kotlin before any audio API, e.g. `System.loadLibrary("xue_hua_audio")`. See the [flutter_rust_bridge Android NDK init guide](https://cjycode.com/flutter_rust_bridge/guides/how-to/ndk-init).

---

## Development

### Prerequisites

- Flutter SDK ≥ 3.3
- Dart SDK ≥ 3.12
- Rust toolchain (for local Rust builds)
- `flutter_rust_bridge_codegen` 2.12

### Dart analysis

```bash
dart analyze lib example/lib
```

### Integration tests (macOS)

```bash
cd example
flutter test integration_test/playback_test.dart -d macos
```

Recording integration test is skipped by default (microphone not available in test harness); verify recording via the example app.

---

## Example app

```bash
cd example
flutter run
```

The demo includes:

- **Recording tab** — device picker, record/pause/stop, level meter, playback of recorded WAV with progress
- **Playback tab** — multi-sample playback, volume, seek, progress streams

See [`example/`](example/) for a full integration reference.

---

## Platform permissions reference

Per-platform permissions and declarations required **in your host app** (in addition to what the plugin already ships).

### Android

| Item | Required for | Provided by plugin | Required in your app |
|------|--------------|--------------------|----------------------|
| `android.permission.RECORD_AUDIO` | Recording | Yes (`android/src/main/AndroidManifest.xml`) | Recommended duplicate in app manifest |
| Runtime mic permission | Recording | No | Yes — e.g. `permission_handler` |
| `android.permission.INTERNET` | `loadUrl()` | No | Yes, in app `AndroidManifest.xml` |
| `minSdkVersion` ≥ 26 | All features | Plugin default | App must use ≥ 26 |
| NDK / JVM context init | Playback & recording | Yes (`XueHuaAudioPlugin`) | No — automatic when using standard Flutter embedding |

**App manifest (recording + URL):**

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

**Runtime request before recording:**

```dart
import 'package:permission_handler/permission_handler.dart';

if (!await Permission.microphone.request().isGranted) {
  // handle denial
}
await session.start(outputPath: path);
```

### iOS

| Item | Required for | In plugin | In your app |
|------|--------------|-----------|-------------|
| `NSMicrophoneUsageDescription` | Recording | No | **Yes** — `ios/Runner/Info.plist` |
| Runtime mic permission | Recording | No | System prompt on first capture |

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required to record audio.</string>
```

Playback-only apps do not need this key. Use HTTPS URLs or configure App Transport Security if loading HTTP audio.

### macOS

| Item | Required for | In plugin | In your app |
|------|--------------|-----------|-------------|
| `NSMicrophoneUsageDescription` | Recording | No | **Yes** — `macos/Runner/Info.plist` |
| `com.apple.security.device.audio-input` | Recording | No | **Yes** — entitlements file |
| Runtime mic permission | Recording | No | System prompt on first capture |

**Info.plist:**

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required to record audio.</string>
```

**DebugProfile.entitlements / Release.entitlements:**

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

See [`example/macos/Runner/`](example/macos/Runner/) for a working setup.

### Linux

| Item | Required for | Notes |
|------|--------------|-------|
| Audio output | Playback | Uses ALSA/PulseAudio via rodio; no manifest |
| Audio input | Recording | User must have mic device; may need desktop permission dialog (varies by DE) |

No Flutter manifest entries. Ensure the process can access the default input device.

### Windows

| Item | Required for | Notes |
|------|--------------|-------|
| Audio output | Playback | WASAPI via rodio |
| Audio input | Recording | Microphone privacy settings — user must allow desktop apps to access the mic |

No `Info.plist` or Android-style permissions. If recording fails, check **Settings → Privacy → Microphone**.

### Summary

| Feature | Android | iOS | macOS | Linux | Windows |
|---------|---------|-----|-------|-------|---------|
| Play local / asset | — | — | — | — | — |
| Play URL | `INTERNET` | ATS / HTTPS | — | — | — |
| Record | `RECORD_AUDIO` + runtime | `NSMicrophoneUsageDescription` + runtime | plist + entitlement + runtime | Device access | Privacy settings |

---

## License

See the repository license file. Version history: [CHANGELOG.md](CHANGELOG.md).
