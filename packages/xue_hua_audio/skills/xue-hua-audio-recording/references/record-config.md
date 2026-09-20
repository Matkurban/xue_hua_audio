# RecordConfig and AudioEncoder

Configuration for one recording session, plus the encoder enum.

Source: `xue_hua_audio_platform_interface` → `lib/src/types/record_config.dart`,
re-exported by `package:xue_hua_audio`.

```dart
@immutable
class RecordConfig
enum AudioEncoder { wav, aacLc, opus }
```

---

## AudioEncoder

### `AudioEncoder.wav`

Linear PCM in a WAV container — lossless, largest files, zero-latency
encoding. Typical file extension: `.wav`.

### `AudioEncoder.aacLc`

AAC-LC in an MPEG-4 (`.m4a`) container — good quality at small sizes.
Typical file extension: `.m4a`.

### `AudioEncoder.opus`

Opus — excellent quality at low bit rates. Container depends on the
platform: Ogg on Linux (typical extension `.ogg`), WebM on Web.

### Platform support

From the enum dartdoc:

| Encoder | Android | iOS/macOS | Windows | Linux | Web |
|---------|---------|-----------|---------|-------|-----|
| `wav`   | yes     | yes       | yes     | yes   | no  |
| `aacLc` | yes     | yes       | yes     | yes*  | maybe (Safari) |
| `opus`  | no      | no        | no      | yes*  | yes (Chrome/Firefox) |

`*` requires the matching GStreamer encoder plugin to be installed.

On Web the browser chooses the closest supported format via
`MediaRecorder.isTypeSupported`. The actual container/codec depends on
the browser (`audio/webm;codecs=opus` on Chrome/Firefox, `audio/mp4` on
Safari) regardless of the requested encoder. An unsupported encoder
throws `AudioError` with `AudioError.codeUnsupportedEncoder` on platforms
that reject it.

---

## RecordConfig

### `const RecordConfig({AudioEncoder encoder = AudioEncoder.wav, int sampleRate = 44100, int numChannels = 1, int bitRate = 128000, Duration amplitudeInterval = const Duration(milliseconds: 100), String? deviceId})`

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `encoder` | `AudioEncoder` | `AudioEncoder.wav` | Audio encoder. |
| `sampleRate` | `int` | `44100` | Sample rate in Hz. |
| `numChannels` | `int` | `1` | `1` = mono, `2` = stereo. |
| `bitRate` | `int` | `128000` | Bit rate in bits/second for compressed encoders (`aacLc`, `opus`). |
| `amplitudeInterval` | `Duration` | `100ms` | How often `onAmplitudeChanged` emits. |
| `deviceId` | `String?` | `null` | Input device id from `listInputDevices()`. `null` uses the system default microphone. Overrides `AudioRecorder.setInputDevice` for this `start` only. |

---

## Fields

### `final AudioEncoder encoder`

The audio encoder to use.

### `final int sampleRate`

Sample rate in Hz.

### `final int numChannels`

Number of channels: `1` = mono, `2` = stereo.

### `final int bitRate`

Bit rate in bits per second (compressed encoders only).

### `final Duration amplitudeInterval`

Interval between amplitude events.

### `final String? deviceId`

Preferred input device id; `null` for the system default.

---

## Object members

`RecordConfig` does not override `==` or `hashCode`.

### `String toString()`

```text
RecordConfig(encoder: $encoder, sampleRate: $sampleRate, numChannels: $numChannels, bitRate: $bitRate, amplitudeInterval: $amplitudeInterval, deviceId: $deviceId)
```
