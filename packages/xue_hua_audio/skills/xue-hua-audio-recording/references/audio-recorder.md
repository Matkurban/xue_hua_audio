# AudioRecorder

High-level microphone recorder with real-time amplitude reporting,
suitable for waveform UIs.

Source: `package:xue_hua_audio` → `lib/src/audio_recorder.dart`.

The native instance is created lazily and asynchronously in the
constructor. Methods that talk to the platform await that creation, so
the object is usable immediately after `AudioRecorder()`.

`hasPermission()` and `listInputDevices()` do **not** await creation and
do **not** check `isDisposed`.

After `dispose()`, methods that call `_ensureCreated()` throw
`StateError`. `dispose()` itself does not change `state`; use
`isDisposed`. A running recording is cancelled.

---

## Constructor

### `AudioRecorder()`

Creates a recorder and starts native creation in the background. No
arguments. No global `initialize()` is required.

---

## Getters

### `RecorderState get state`

Current lifecycle state. Starts at `RecorderState.idle`. See
[recorder-state.md](recorder-state.md).

### `bool get isRecording`

`true` only when `state == RecorderState.recording` (not when paused).

### `bool get isDisposed`

`true` after `dispose()` has been called. There is no `RecorderState`
value for disposal.

---

## Streams

All streams are broadcast. They are closed by `dispose()`.

### `Stream<RecorderState> get onStateChanged`

Emits every distinct `RecorderState` transition.

### `Stream<Amplitude> get onAmplitudeChanged`

While recording, emits an `Amplitude` sample every
`RecordConfig.amplitudeInterval`. Use `Amplitude.normalized` (`0.0`–`1.0`)
to render waveform bars. `current` / `max` are dBFS. See
[amplitude.md](amplitude.md).

### `Stream<AudioError> get onError`

Asynchronous recording failures only (for example the input device
disappearing). Errors thrown directly by methods are **not** added here.
Catch those at the call site.

---

## Commands

Unless noted, each method awaits native creation. After `dispose()`, those
methods throw:

```text
StateError: AudioRecorder has been disposed and can no longer be used.
```

### `Future<bool> hasPermission()`

Checks — and requests when the platform supports prompting — the
microphone permission. Returns `true` when recording is permitted.

On Android and iOS this shows the system permission dialog when permission
has not been decided yet.

Does not await native recorder creation and does not throw `StateError`
after `dispose()`.

### `Future<List<AudioDevice>> listInputDevices()`

**Instance** method (not static). Lists available input devices
(microphones). Pass an `AudioDevice.id` to `setInputDevice` or
`RecordConfig.deviceId`.

On Web, `label` may be empty until microphone permission has been granted.

Does not await native recorder creation and does not throw `StateError`
after `dispose()`.

### `Future<AudioDevice?> getInputDevice()`

The input device this recorder captures from, or `null` when it follows
the system default.

### `Future<void> setInputDevice(String? deviceId)`

Selects input device `deviceId` from `listInputDevices`, or `null` for
the system default.

* Live switching while recording is supported on Android and iOS.
* On macOS, Web, Windows, and Linux, calling this while recording throws
  `AudioError` with `AudioError.codeInvalidState`. Set the device before
  `start`.
* `RecordConfig.deviceId` passed to `start` overrides this preference for
  that recording.

### `Future<void> start(RecordConfig config, {required String path})`

Starts recording.

| Parameter | Type | Meaning |
| --- | --- | --- |
| `config` | `RecordConfig` | Encoder, sample rate, channels, bit rate, amplitude interval, optional input device. See [record-config.md](record-config.md). |
| `path` | `String` (required named) | Absolute output file path. Choose an extension matching the encoder (`.wav`, `.m4a`, `.ogg`). **Ignored on Web**; `stop` returns a blob URL. |

Completes once capture has actually started. State transitions to
`RecorderState.recording`. Throws `AudioError` when recording cannot
start (for example `permissionDenied`).

### `Future<void> pause()`

Pauses recording. Audio captured so far is kept.

### `Future<void> resume()`

Resumes a paused recording.

### `Future<String?> stop()`

Stops recording and finalizes the file.

Returns the recorded file path (a **blob URL on Web**), or `null` when
nothing was recorded.

### `Future<void> cancel()`

Stops recording and deletes the partial file. Use this to discard a take.

---

## Disposal

### `Future<void> dispose()`

Releases the native recorder and closes every stream. A running recording
is cancelled. Safe to call more than once (subsequent calls return
immediately).

Does **not** assign a `RecorderState` value. After this call:

* `isDisposed == true`
* `state` remains whatever it was
* `start` / `pause` / `resume` / `stop` / `cancel` / `getInputDevice` /
  `setInputDevice` throw `StateError`
* `hasPermission` and `listInputDevices` remain callable
