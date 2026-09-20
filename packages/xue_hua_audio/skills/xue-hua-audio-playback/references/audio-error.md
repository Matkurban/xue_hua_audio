# AudioError

Structured error from the audio engine. Implements `Exception`.

Source: `xue_hua_audio_platform_interface` → `lib/src/types/audio_error.dart`,
re-exported by `package:xue_hua_audio`.

```dart
@immutable
class AudioError implements Exception
```

Errors surface in two ways:

1. Methods such as `setSource` or `start` **throw** `AudioError` when the
   operation itself fails.
2. Asynchronous failures (network stream drop, input device disappearing)
   are delivered on `AudioPlayer.onError` / `AudioRecorder.onError`.

Method-thrown errors are **not** duplicated on those streams.

Catch `AudioError` and compare `e.code` to the `AudioError.code*` constants.
The string values below are the only defined codes. There is no
`'sourceNotFound'` code.

---

## Constructor

### `const AudioError({required this.code, required this.message, this.details})`

| Parameter | Type | Meaning |
| --- | --- | --- |
| `code` | `String` | Stable machine-readable code (use the `code*` constants). |
| `message` | `String` | Human-readable description. |
| `details` | `Object?` | Optional platform-specific diagnostic payload. Defaults to `null`. |

---

## Code constants

Each constant is `static const String`. Use the constant, not a raw string,
when branching.

| Constant | Value | Meaning |
| --- | --- | --- |
| `AudioError.codeInstanceNotFound` | `'instanceNotFound'` | The referenced player or recorder no longer exists. |
| `AudioError.codeSourceLoadFailed` | `'sourceLoadFailed'` | The source could not be loaded or decoded. |
| `AudioError.codePlaybackFailed` | `'playbackFailed'` | A playback failure occurred after loading. |
| `AudioError.codePermissionDenied` | `'permissionDenied'` | Microphone permission was denied. |
| `AudioError.codeRecordingFailed` | `'recordingFailed'` | Recording could not be started or failed mid-way. |
| `AudioError.codeUnsupportedEncoder` | `'unsupportedEncoder'` | The requested encoder is not supported on this platform. |
| `AudioError.codeInvalidState` | `'invalidState'` | The operation is invalid in the current state. |
| `AudioError.codeUnsupported` | `'unsupported'` | The operation is not supported on this platform (for example per-player output routing on iOS). |
| `AudioError.codeDeviceNotFound` | `'deviceNotFound'` | The referenced audio device does not exist or is unavailable. |

Playback-typical codes: `codeSourceLoadFailed`, `codePlaybackFailed`,
`codeUnsupported` (iOS `setOutputDevice`), `codeDeviceNotFound`,
`codeInstanceNotFound`.

Recording-typical codes: `codePermissionDenied`, `codeRecordingFailed`,
`codeUnsupportedEncoder`, `codeInvalidState` (input switch while recording
on macOS / Web / Windows / Linux), `codeDeviceNotFound`,
`codeInstanceNotFound`.

---

## Fields

### `final String code`

Stable machine-readable error code.

### `final String message`

Human-readable error description.

### `final Object? details`

Optional platform-specific diagnostic payload.

---

## Object members

### `bool operator ==(Object other)`

Equal when `other` is an `AudioError` with the same `code`, `message`, and
`details`.

### `int get hashCode`

`Object.hash(code, message, details)`.

### `String toString()`

`'AudioError($code): $message'` when `details` is `null`; otherwise
`'AudioError($code): $message — $details'`.

---

## Usage

```dart
try {
  await player.setSource(AudioSource.file('/missing.mp3'));
} on AudioError catch (e) {
  if (e.code == AudioError.codeSourceLoadFailed) {
    // handle load failure
  }
}

player.onError.listen((e) {
  // async only; e.code == AudioError.codePlaybackFailed, etc.
});
```

`dispose()` after release throws `StateError`, not `AudioError`.
