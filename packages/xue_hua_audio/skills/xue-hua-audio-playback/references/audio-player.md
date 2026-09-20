# AudioPlayer

High-level player for a local file, HTTP(S) URL, or Flutter asset. Each
instance owns one native player. Multiple instances may play at once; the
OS mixes them.

Source: `package:xue_hua_audio` → `lib/src/audio_player.dart`.

The native instance is created lazily and asynchronously in the
constructor. Every instance method that talks to the platform awaits that
creation, so the object is usable immediately after `AudioPlayer()`.

After `dispose()`, those methods throw `StateError`. `dispose()` itself
does not change `state`; use `isDisposed`.

---

## Constructor

### `AudioPlayer({Duration positionUpdateInterval = const Duration(milliseconds: 100)})`

Creates a player and starts native creation in the background.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `positionUpdateInterval` | `Duration` | `100ms` | How often `onPositionChanged` emits while `state == PlayerState.playing`. |

No global `initialize()` call is required.

---

## Fields

### `final Duration positionUpdateInterval`

Interval between `onPositionChanged` events while playing. Set only in the
constructor; not mutable afterwards.

---

## Getters

### `PlayerState get state`

Current lifecycle state. Starts at `PlayerState.idle`. See
[player-state.md](player-state.md).

### `bool get isPlaying`

`true` only when `state == PlayerState.playing`.

### `Duration? get duration`

Last known total duration. `null` when no source is loaded or the duration
is unknown (live streams). Updated by a successful `setSource` and by
asynchronous duration events.

### `bool get isDisposed`

`true` after `dispose()` has been called. There is no `PlayerState` value
for disposal.

---

## Streams

All streams are broadcast. They are closed by `dispose()`.

### `Stream<PlayerState> get onStateChanged`

Emits every distinct `PlayerState` transition.

### `Stream<Duration> get onPositionChanged`

While `state == PlayerState.playing`, emits the platform position every
`positionUpdateInterval` (duplicate positions are suppressed). Also emits
once after `seek`, `pause`, and `stop` so the UI stays current. On
transition to `PlayerState.completed`, if `duration` is non-null, that
duration is emitted as the position.

### `Stream<Duration?> get onDurationChanged`

Emits when the total duration first becomes known or later changes,
including the value returned from `setSource`.

### `Stream<AudioError> get onError`

Asynchronous playback failures only (for example a network stream failing
mid-playback). Errors thrown directly by methods such as `setSource` are
**not** added here. Catch those at the call site.

### `Stream<void> get onPlayerComplete`

Emits once each time `onStateChanged` reports `PlayerState.completed`
(end of audio, non-looping). Implementation:

```dart
onStateChanged.where((s) => s == PlayerState.completed)
```

---

## Commands

Unless noted, each method awaits native creation and then forwards to the
platform. After `dispose()`, they throw:

```text
StateError: AudioPlayer has been disposed and can no longer be used.
```

### `Future<Duration?> setSource(AudioSource source)`

Loads `source` (file, URL, or asset).

* Returns the total duration, or `null` when unknown (live streams).
* Stores that value in `duration` and emits `onDurationChanged`.
* Documented state contract: `loading` then `ready` (via platform events).
* On `AudioError`: sets `state` to `PlayerState.error` and rethrows. That
  thrown error is not also pushed to `onError`.

Call this before `play()`.

### `Future<void> play()`

Starts playback, or resumes from pause. A source must already be loaded
with `setSource`.

### `Future<void> pause()`

Pauses playback and keeps the current position. Also emits
`onPositionChanged`.

### `Future<void> stop()`

Stops playback, rewinds to the beginning, and keeps the loaded source. The
next `play()` starts from the beginning. Emits `Duration.zero` on
`onPositionChanged`.

### `Future<void> seek(Duration position)`

Seeks to `position`. The returned future completes after the seek has been
applied. Then emits `onPositionChanged`.

### `Future<void> setVolume(double volume)`

Sets volume. `0.0` is mute, `1.0` is full volume. Values outside that
range are clamped (platform-side).

### `Future<void> setSpeed(double speed)`

Sets the playback rate multiplier. `1.0` is normal speed. Typical range
`0.5`–`2.0`. Must be greater than `0`; debug builds `assert(speed > 0)`.

### `Future<void> setLooping(bool looping)`

When `looping` is `true`, playback restarts from the beginning at the end
instead of entering `PlayerState.completed`.

### `Future<Duration> getPosition()`

Reads the current playback position from the platform (not a cached field).

---

## Output devices

### `static Future<List<AudioDevice>> listOutputDevices()`

**Static.** Lists available output devices (speakers, headphones, …).
Pass an `AudioDevice.id` to `setOutputDevice`.

Platform notes (from the method dartdoc):

* iOS reports only devices on the current audio route; the system does not
  allow apps to enumerate every output.
* Web: `label` may be empty until the user has granted a media permission.

### `Future<AudioDevice?> getOutputDevice()`

The output device this player is routed to, or `null` when it follows the
system default.

### `Future<void> setOutputDevice(String? deviceId)`

Routes this player to `deviceId` from `listOutputDevices`, or `null` to
restore the system default.

* Platforms that cannot route per player (iOS) throw `AudioError` with
  `AudioError.codeUnsupported`.
* Windows and Linux: the new device takes effect from the next `setSource`.
* Android, macOS, and Web: applies immediately, including while playing.

---

## Disposal

### `Future<void> dispose()`

Releases the native player and closes every stream. Safe to call more than
once (subsequent calls return immediately). A running position timer is
cancelled.

Does **not** assign a `PlayerState` value. After this call:

* `isDisposed == true`
* `state` remains whatever it was
* further instance commands throw `StateError`
* `listOutputDevices` remains callable (it is static)
