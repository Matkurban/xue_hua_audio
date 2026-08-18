# xue_hua_audio

**English** | [简体中文](README.zh-CN.md)

Cross-platform **native** Flutter audio plugin — playback (file / URL / asset)
and microphone recording with a real-time amplitude stream, on six platforms.
No Rust toolchain, no FFI, no codegen: every platform is implemented with its
first-class native audio API and wired up through a type-safe
[Pigeon](https://pub.dev/packages/pigeon) channel.

| Platform | Playback | Recording |
| --- | --- | --- |
| Android | Media3 ExoPlayer | AudioRecord (WAV / AAC-LC) |
| iOS / macOS | AVPlayer | AVAudioEngine (WAV / AAC-LC) |
| Windows | Media Foundation `IMFMediaEngine` | WASAPI (WAV / AAC-LC) |
| Linux | GStreamer `playbin` | GStreamer `level` (WAV / Opus / AAC) |
| Web | HTMLAudioElement | MediaRecorder + AnalyserNode (Opus / MP4) |

Features:

- **Playback** — local files, network URLs (streamed, with custom headers),
  and Flutter assets; play / pause / stop / seek / volume / speed / loop.
- **Multi-instance** — create as many `AudioPlayer`s as you like; each owns
  its native resources and is disposed independently.
- **Recording** — WAV / AAC-LC / Opus output, pause & resume, cancel,
  configurable sample rate / channels / bit rate, input device selection.
- **Device management** — enumerate output/input devices, query the current
  one and route each player / recorder to a specific device.
- **Real-time amplitude** — `Stream<Amplitude>` with current / max dBFS and a
  normalized 0–1 value, ready for waveform UIs.
- **Type-safe events** — `Stream`s for state, position, duration, and errors;
  structured `AudioError` (code + message + details) everywhere.
- **Bilingual docs** — every public API carries English + Chinese dartdoc.

Migrating from 1.x (the Rust/FFI version)? See
[MIGRATION.md](https://github.com/Matkurban/xue_hua_audio/blob/main/MIGRATION.md).

---

## Installation

```yaml
dependencies:
  xue_hua_audio: ^2.0.0
```

No initialization call is needed.

## Playback

```dart
import 'package:xue_hua_audio/xue_hua_audio.dart';

final player = AudioPlayer();

// Load any of the three source kinds. Returns the duration when known.
final duration = await player.setSource(
  AudioSource.url('https://example.com/song.mp3'),
);
// AudioSource.file('/path/to/local.mp3')
// AudioSource.asset('assets/audio/ring.wav')

await player.play();
await player.setVolume(0.8);   // 0.0 – 1.0
await player.setSpeed(1.5);    // 0.5 – 2.0
await player.setLooping(true);
await player.seek(const Duration(seconds: 10));
await player.pause();
await player.stop();

// Events
player.onStateChanged.listen((s) => print(s));    // PlayerState
player.onPositionChanged.listen((p) => print(p)); // every 100 ms (default)
player.onDurationChanged.listen((d) => print(d));
player.onError.listen((e) => print(e));

// Always release native resources when done.
await player.dispose();
```

`PlayerState`: `idle → loading → ready → playing ⇄ paused → completed /
stopped`, plus `error` and terminal `disposed`.

## Recording

```dart
final recorder = AudioRecorder();

if (await recorder.hasPermission()) {
  // Live waveform: normalized is 0–1, current/max are dBFS.
  recorder.onAmplitudeChanged.listen((a) => drawBar(a.normalized));

  await recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc, // wav / aacLc / opus
      sampleRate: 44100,
      numChannels: 1,
    ),
    path: '/path/to/recording.m4a', // ignored on the Web
  );

  await recorder.pause();
  await recorder.resume();
  final path = await recorder.stop(); // file path, or blob URL on the Web
  // await recorder.cancel();         // stop and delete instead
}

await recorder.dispose();
```

## Audio devices

Playback output device (per player):

```dart
final outputs = await AudioPlayer.listOutputDevices();
await player.setOutputDevice(outputs.first.id); // route this player
final current = await player.getOutputDevice(); // null = system default
await player.setOutputDevice(null);             // back to the default
```

Recording input device (per recorder):

```dart
final inputs = await recorder.listInputDevices();
await recorder.setInputDevice(inputs.first.id); // instance preference
final current = await recorder.getInputDevice(); // null = system default
// One-shot override for a single recording:
await recorder.start(RecordConfig(deviceId: inputs.first.id), path: ...);
```

Platform notes:

| Platform | Set output device | Switch input while recording |
| --- | --- | --- |
| Android | ✅ immediate (API 23+) | ✅ |
| iOS | ❌ `unsupported` (system routing) | ✅ (`setPreferredInput`) |
| macOS | ✅ immediate | ❌ set before `start` |
| Windows | ✅ from the next `setSource` (Win10 1703+) | ❌ set before `start` |
| Linux | ✅ from the next `setSource` | ❌ set before `start` |
| Web | ✅ immediate (`setSinkId`) | ❌ set before `start` |

On iOS `listOutputDevices` returns only the devices of the current audio
route; on the Web labels may be empty until a media permission is granted.

## Errors

Every async method throws a structured `AudioError`; the same errors are also
published on `player.onError` / `recorder.onError`:

```dart
try {
  await player.setSource(AudioSource.file('/missing.mp3'));
} on AudioError catch (e) {
  print('${e.code}: ${e.message}'); // e.g. sourceNotFound: ...
}
```

## Platform setup

### Android

Nothing to do — the plugin manifest already declares `RECORD_AUDIO` and
`INTERNET`. Minimum SDK 21.

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app records audio from the microphone.</string>
```

Minimum iOS 13.0. The plugin manages `AVAudioSession` automatically.

### macOS

Add `NSMicrophoneUsageDescription` to `macos/Runner/Info.plist`, and the
following entitlements to both `DebugProfile.entitlements` and
`Release.entitlements`:

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

Minimum macOS 10.15.

### Windows

Nothing to do — Media Foundation and WASAPI ship with Windows 10+.

### Linux

Build-time dependency on GStreamer development headers:

```bash
sudo apt install libgstreamer1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

### Web

- Microphone access requires a secure context (HTTPS or localhost).
- `recorder.stop()` returns a **blob URL**; the actual container/codec depends
  on the browser (`audio/webm;codecs=opus` on Chrome/Firefox, `audio/mp4` on
  Safari) regardless of the requested encoder.
- Remote audio playback is subject to CORS.

## Architecture

This is a [federated plugin](https://docs.flutter.dev/packages-and-plugins/developing-packages#federated-plugins):

```text
xue_hua_audio                     ← the package apps depend on
└── xue_hua_audio_platform_interface
    ├── xue_hua_audio_android     Kotlin  · ExoPlayer + AudioRecord
    ├── xue_hua_audio_darwin      Swift   · AVPlayer + AVAudioEngine (iOS+macOS)
    ├── xue_hua_audio_web         Dart    · package:web
    ├── xue_hua_audio_windows     C++     · Media Foundation + WASAPI
    └── xue_hua_audio_linux       C       · GStreamer
```

Commands travel over Pigeon-generated type-safe channels; events (state,
position, duration, amplitude, errors) come back per-instance over an
`EventChannel`. The Web implementation is pure Dart and skips channels
entirely.

## Example app

The [example](https://github.com/Matkurban/xue_hua_audio/tree/main/packages/xue_hua_audio/example)
demonstrates all three source kinds, seek / volume / speed / loop controls,
and recording with a live waveform.

## License

MIT.
