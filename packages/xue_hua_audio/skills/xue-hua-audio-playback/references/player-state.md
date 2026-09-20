# PlayerState

Lifecycle state of an `AudioPlayer`.

Source: `xue_hua_audio_platform_interface` → `lib/src/types/player_state.dart`,
re-exported by `package:xue_hua_audio`.

There are exactly eight values. There is **no** `PlayerState.disposed`.
After `AudioPlayer.dispose()`, use `player.isDisposed`; `state` stays at
whatever value it had.

---

## State machine (from the type dartdoc)

```text
idle --setSource()--> loading --> ready --play()--> playing
                                   ^                 |  ^
                                   |             pause() play()
                                   |                 v  |
                                   +---- stop() --- paused
playing --(end of audio)--> completed
any state --(failure)--> error
```

When `setLooping(true)` is in effect, playback restarts at the end instead
of entering `completed`.

---

## Values

### `PlayerState.idle`

No source has been set yet. Initial value of a new `AudioPlayer`.

### `PlayerState.loading`

A source is being loaded / buffered.

### `PlayerState.ready`

The source is loaded and ready to play.

### `PlayerState.playing`

Audio is currently playing. `AudioPlayer.isPlaying` is `true` only in this
state. Position polling (`onPositionChanged`) runs in this state.

### `PlayerState.paused`

Playback is paused and can be resumed with `play()`.

### `PlayerState.completed`

Playback reached the end of the audio (non-looping).
`onPlayerComplete` fires on this transition. If `duration` is non-null,
that duration is also emitted on `onPositionChanged`.

### `PlayerState.stopped`

Playback was stopped; the position is reset to the beginning. The loaded
source is kept.

### `PlayerState.error`

An unrecoverable error occurred. Method failures such as a failed
`setSource` set this state. Asynchronous failures also set it and emit
`onError`. See [audio-error.md](audio-error.md).
