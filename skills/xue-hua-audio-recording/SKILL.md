---
name: xue-hua-audio-recording
description: >-
  Use when writing, reviewing, or debugging xue_hua_audio recording:
  AudioRecorder, hasPermission, start, RecordConfig, AudioEncoder,
  Amplitude, onAmplitudeChanged, pause/resume/stop/cancel, listInputDevices,
  setInputDevice, RecorderState, or AudioError during microphone capture.
---

# xue_hua_audio recording

Authoritative skill for `package:xue_hua_audio` microphone recording.
Member-level API docs live in `references/`. Read the matching file before
emitting code for that type.

## Import and construction

* Import only `package:xue_hua_audio/xue_hua_audio.dart`.
* Construct `AudioRecorder()` and call methods immediately. There is no
  `initialize()` and no global engine or `createRecordingSession()`.
* Call `await recorder.dispose()` when finished. A running recording is
  cancelled. After dispose, instance methods that talk to the native
  recorder throw `StateError` (not `AudioError`). `hasPermission()` and
  `listInputDevices()` do not go through that check.
* `dispose()` is safe to call more than once and does not change `state`.
  Use `isDisposed`.

## Permission then start

* Call `await recorder.hasPermission()` before `start`. On Android and iOS
  this shows the system dialog when the user has not decided yet.
* iOS and macOS also need Info.plist / entitlements. See sibling skill
  `xue-hua-audio-platform-setup`.
* `start` signature is `start(RecordConfig config, {required String path})`.
  `path` is an **absolute** file path whose extension matches the encoder
  (`.wav`, `.m4a`, `.ogg`). **Web ignores `path`**; `stop()` returns a
  blob URL instead.
* `start` completes only after capture has actually started. State becomes
  `RecorderState.recording`. Failure throws `AudioError` (for example
  `AudioError.codePermissionDenied`).

## RecordConfig and encoders

* Defaults: `encoder: AudioEncoder.wav`, `sampleRate: 44100`,
  `numChannels: 1`, `bitRate: 128000`,
  `amplitudeInterval: 100ms`, `deviceId: null`.
* Encoder support (from `AudioEncoder` dartdoc):

  | Encoder | Android | iOS/macOS | Windows | Linux | Web |
  |---------|---------|-----------|---------|-------|-----|
  | `wav`   | yes     | yes       | yes     | yes   | no  |
  | `aacLc` | yes     | yes       | yes     | yes*  | maybe (Safari) |
  | `opus`  | no      | no        | no      | yes*  | yes (Chrome/Firefox) |

  `*` needs the matching GStreamer encoder plugin. On Web the browser
  picks the closest supported type via `MediaRecorder.isTypeSupported`;
  the file container may not match the requested encoder
  (`audio/webm;codecs=opus` on Chrome/Firefox, `audio/mp4` on Safari).

## Amplitude / waveform

* Subscribe to `onAmplitudeChanged` and render `amplitude.normalized`
  (`0.0`–`1.0`). `current` and `max` are **dBFS**, not 0–1.
* Interval is `RecordConfig.amplitudeInterval` (default 100 ms).
* `normalized` maps `[-60 dBFS, 0 dBFS]` linearly onto `[0.0, 1.0]`.

## Pause, stop, cancel

* `pause()` keeps captured audio. `resume()` continues a paused take.
* `stop()` finalizes the file and returns `String?` (file path, or a blob
  URL on Web, or `null` if nothing was recorded).
* `cancel()` stops and deletes the partial file (discard the take).

## Input devices

* `listInputDevices()` is an **instance** method (not static).
* `setInputDevice(id)` sets the instance preference; `null` is the system
  default. `getInputDevice()` returns `null` when following the default.
* `RecordConfig.deviceId` passed to `start` overrides that preference for
  that recording.
* Live switch while recording: Android and iOS only. On macOS, Web,
  Windows, and Linux, `setInputDevice` while recording throws `AudioError`
  with `AudioError.codeInvalidState` — set the device before `start`.
* Web: labels may be empty until microphone permission is granted.

## State and errors

* `RecorderState`: `idle`, `recording`, `paused`, `stopped`, `error`.
* `isRecording` is `true` only for `RecorderState.recording` (not paused).
* `onError` is asynchronous failures only. Catch `AudioError` at the call
  site for method failures.
* Full catalog: [references/audio-error.md](references/audio-error.md).

## Removed 1.x shapes

```dart
final recorder = AudioRecorder();
if (await recorder.hasPermission()) {
  await recorder.start(const RecordConfig(), path: absolutePath);
  final file = await recorder.stop();
}
await recorder.dispose();
```

Write `AudioDevice` (not `InputDevice`). There is no
`engine.createRecordingSession()`, no `deviceIndex`, and no
`progressStream.level`.

## Member references

* [AudioRecorder](references/audio-recorder.md)
* [RecordConfig and AudioEncoder](references/record-config.md)
* [Amplitude](references/amplitude.md)
* [RecorderState](references/recorder-state.md)
* [AudioError](references/audio-error.md)
* [AudioDevice](references/audio-device.md)

## Examples

### Record with live waveform

```dart
import 'package:xue_hua_audio/xue_hua_audio.dart';

Future<String?> recordTake(String absolutePath) async {
  final recorder = AudioRecorder();
  try {
    if (!await recorder.hasPermission()) {
      return null;
    }
    recorder.onAmplitudeChanged.listen((a) {
      drawBar(a.normalized); // 0.0–1.0, not a.current
    });
    recorder.onError.listen((e) {/* async device loss, etc. */});

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: absolutePath, // ignored on Web; stop() returns a blob URL
    );
    // await recorder.pause();
    // await recorder.resume();
    return await recorder.stop();
    // await recorder.cancel(); // discard instead
  } on AudioError catch (e) {
    // e.code == AudioError.codePermissionDenied, etc.
    return null;
  } finally {
    await recorder.dispose();
  }
}
```

### Choose an input device

```dart
final inputs = await recorder.listInputDevices();
await recorder.setInputDevice(inputs.first.id); // instance preference
final current = await recorder.getInputDevice(); // null = system default

await recorder.start(
  RecordConfig(deviceId: inputs.first.id), // one-shot override
  path: absolutePath,
);
```
