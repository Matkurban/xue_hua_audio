# RecorderState

Lifecycle state of an `AudioRecorder`.

Source: `xue_hua_audio_platform_interface` → `lib/src/types/player_state.dart`
(same file as `PlayerState`), re-exported by `package:xue_hua_audio`.

There are exactly five values. There is **no** `RecorderState.disposed`.
After `AudioRecorder.dispose()`, use `recorder.isDisposed`; `state` stays
at whatever value it had.

---

## Values

### `RecorderState.idle`

Not recording. Initial value of a new `AudioRecorder`.

### `RecorderState.recording`

Actively capturing audio. `AudioRecorder.isRecording` is `true` only in
this state. Amplitude samples are emitted in this state.

### `RecorderState.paused`

Recording is paused and can be resumed with `resume()`.
`isRecording` is `false`.

### `RecorderState.stopped`

Recording finished and the file is finalized (`stop()` completed).

### `RecorderState.error`

An unrecoverable error occurred. Asynchronous failures emit `onError` and
set this state. See [audio-error.md](audio-error.md).
