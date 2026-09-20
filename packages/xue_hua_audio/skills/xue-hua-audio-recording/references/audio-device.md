# AudioDevice

Immutable descriptor for an available audio device. The same type is used
for outputs (speakers, headphones) and inputs (microphones), depending on
which API returned the instance.

Source: `xue_hua_audio_platform_interface` → `lib/src/types/audio_device.dart`,
re-exported by `package:xue_hua_audio`.

```dart
@immutable
class AudioDevice
```

There is no `InputDevice` type.

---

## Constructor

### `const AudioDevice({required this.id, required this.label})`

| Parameter | Type | Meaning |
| --- | --- | --- |
| `id` | `String` | Platform-specific stable identifier. Pass it to `AudioPlayer.setOutputDevice`, `AudioRecorder.setInputDevice`, or `RecordConfig.deviceId`. |
| `label` | `String` | Human-readable name for UI. |

Apps normally receive instances from `AudioPlayer.listOutputDevices()` or
`AudioRecorder.listInputDevices()` rather than constructing them.

---

## Fields

### `final String id`

Platform-specific stable device identifier.

### `final String label`

Human-readable device name. On Web this may be empty until the user has
granted a media (playback) or microphone (recording) permission.

---

## Object members

### `bool operator ==(Object other)`

Equal when `other` is an `AudioDevice` with the same `id` and `label`.

### `int get hashCode`

`Object.hash(id, label)`.

### `String toString()`

`'AudioDevice(id: $id, label: $label)'`.

---

## How ids are used

**Output (playback)** — static list, per-player route:

```dart
final outputs = await AudioPlayer.listOutputDevices();
await player.setOutputDevice(outputs.first.id);
final current = await player.getOutputDevice(); // null = system default
await player.setOutputDevice(null);
```

* iOS: `listOutputDevices` returns only devices on the current audio route.
  `setOutputDevice` throws `AudioError.codeUnsupported`.
* Windows / Linux: the new output takes effect on the next `setSource`.
* Android / macOS / Web: applies immediately, including while playing.

**Input (recording)** — instance list, preference or one-shot override:

```dart
final inputs = await recorder.listInputDevices();
await recorder.setInputDevice(inputs.first.id);
await recorder.start(
  RecordConfig(deviceId: inputs.first.id),
  path: absolutePath,
);
```

* Live input switch while recording: Android and iOS only.
* macOS / Web / Windows / Linux: calling `setInputDevice` while recording
  throws `AudioError.codeInvalidState`. Set the device before `start`.
* `RecordConfig.deviceId` passed to `start` overrides the instance
  preference for that recording.
