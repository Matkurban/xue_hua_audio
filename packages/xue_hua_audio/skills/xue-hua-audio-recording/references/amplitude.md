# Amplitude

One microphone amplitude sample, for waveforms or level meters.

Source: `xue_hua_audio_platform_interface` → `lib/src/types/amplitude.dart`,
re-exported by `package:xue_hua_audio`.

```dart
@immutable
class Amplitude
```

Emitted on `AudioRecorder.onAmplitudeChanged` every
`RecordConfig.amplitudeInterval` while recording.

---

## Constructor

### `const Amplitude({required this.current, required this.max})`

| Parameter | Type | Meaning |
| --- | --- | --- |
| `current` | `double` | Current level in dBFS (`0` is full scale; typical values range from `-60` to `0`). |
| `max` | `double` | Maximum level in dBFS observed since recording started. |

Apps normally receive instances from `onAmplitudeChanged` rather than
constructing them.

---

## Constants

### `static const double silenceDb = -60`

dBFS level treated as silence when normalizing.

---

## Fields

### `final double current`

Current level in dBFS. This is **not** a 0–1 linear value.

### `final double max`

Maximum level in dBFS since the recording started.

---

## Getters

### `double get normalized`

Current level mapped linearly from `[-60 dBFS, 0 dBFS]` to `[0.0, 1.0]`,
clamped at both ends. Implementation:

```dart
((current.clamp(silenceDb, 0) - silenceDb) / -silenceDb)
```

Use this for waveform bars. Values below `-60` become `0.0`; values above
`0` become `1.0`.

---

## Object members

### `bool operator ==(Object other)`

Equal when `other` is an `Amplitude` with the same `current` and `max`.

### `int get hashCode`

`Object.hash(current, max)`.

### `String toString()`

`'Amplitude(current: $current dBFS, max: $max dBFS)'`.
