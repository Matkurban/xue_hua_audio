---
name: xue-hua-audio-playback
description: >-
  Use when writing, reviewing, or debugging xue_hua_audio playback:
  AudioPlayer, setSource, AudioSource.file/url/asset, play/pause/stop/seek,
  setVolume, setSpeed, setLooping, PlayerState, onPositionChanged,
  onPlayerComplete, listOutputDevices, setOutputDevice, or AudioError
  during playback. Follow the 2.0 instance API; there is no global engine.
---

# xue_hua_audio playback

Authoritative skill for `package:xue_hua_audio` playback. Member-level API
docs live in `references/`. Read the matching file before emitting code for
that type.

## Import and construction

* Import only `package:xue_hua_audio/xue_hua_audio.dart`.
* Construct `AudioPlayer()` and call methods immediately. There is no
  `initialize()` and no global engine.
* Each instance owns one native player. Create as many as needed; the OS
  mixes concurrent playback.
* Call `await player.dispose()` when finished. After that, instance methods
  that talk to the native player throw `StateError` (not `AudioError`).
  `dispose()` is safe to call more than once and does not change `state`.
  Use `isDisposed` to detect release.

## Load then play

* Always `await player.setSource(...)` before `play()`.
* Use the factories: `AudioSource.file`, `AudioSource.url`,
  `AudioSource.asset`. File paths are absolute. Asset keys match
  `pubspec.yaml`. `UrlSource.headers` are ignored on Web.
* `setSource` returns `Duration?` (`null` for unknown / live streams),
  updates `duration`, and emits `onDurationChanged`. On failure it throws
  `AudioError` and sets `state` to `PlayerState.error`.
* `play()` starts or resumes. `pause()` keeps position. `stop()` rewinds to
  zero and keeps the loaded source, so the next `play()` starts from the
  beginning.

## Controls

* `setVolume`: `0.0`–`1.0`; values outside that range are clamped.
* `setSpeed`: must be `> 0` (`assert` in debug). `1.0` is normal speed;
  typical range is `0.5`–`2.0`.
* `setLooping(true)` restarts at the end instead of entering
  `PlayerState.completed`.
* `seek(Duration)` completes after the seek is applied and also emits
  `onPositionChanged`.

## Streams and state

* Subscribe to `onStateChanged`, `onPositionChanged`, `onDurationChanged`,
  and `onError` after construction.
* `onPositionChanged` emits every `positionUpdateInterval` while
  `state == playing` (default 100 ms), plus once after seek / pause / stop.
* `onError` carries **asynchronous** failures only (for example a network
  stream dropping mid-playback). Errors thrown by methods are not
  duplicated on this stream. Catch `AudioError` at the call site.
* `onPlayerComplete` is `onStateChanged` filtered to `PlayerState.completed`.
* `PlayerState` values: `idle`, `loading`, `ready`, `playing`, `paused`,
  `completed`, `stopped`, `error`. There is no `PlayerState.disposed`.

## Output devices

* Enumerate with the **static** `AudioPlayer.listOutputDevices()`.
* Route one player with `player.setOutputDevice(device.id)` or `null` for
  the system default. Query with `player.getOutputDevice()` (`null` = default).
* iOS: `setOutputDevice` throws `AudioError` with
  `AudioError.codeUnsupported`. `listOutputDevices` returns only devices
  on the current audio route.
* Windows and Linux: the new device takes effect on the next `setSource`.
* Android, macOS, and Web: the new device applies immediately, including
  while playing.
* Web: `AudioDevice.label` may be empty until a media permission is granted.

## Errors

* Catch `AudioError` and branch on `e.code` using the `AudioError.code*`
  constants. The load-failure code is `AudioError.codeSourceLoadFailed`
  (`'sourceLoadFailed'`).
* Full catalog: [references/audio-error.md](references/audio-error.md).

## Removed 1.x shapes

Write the 2.0 instance API only:

```dart
final player = AudioPlayer();
final duration = await player.setSource(AudioSource.file(absolutePath));
await player.play();
await player.dispose();
```

Do not invent `XueHuaAudio.initialize()`, a global `engine`,
`loadLocal` / `loadAsset` / `loadUrl` / `loadFromBytes`,
`track.positionSecs()`, or `InputDevice`.

## Platform permissions

iOS / macOS / Android / Linux / Web setup is in the sibling skill
`xue-hua-audio-platform-setup`. Playback of remote URLs on Android already
has `INTERNET` in the plugin manifest.

## Member references

* [AudioPlayer](references/audio-player.md)
* [AudioSource, FileSource, UrlSource, AssetSource](references/audio-source.md)
* [PlayerState](references/player-state.md)
* [AudioError](references/audio-error.md)
* [AudioDevice](references/audio-device.md)

## Examples

### Basic file / URL / asset playback

```dart
import 'package:xue_hua_audio/xue_hua_audio.dart';

Future<void> playDemo() async {
  final player = AudioPlayer();
  player.onStateChanged.listen((state) {/* update UI */});
  player.onPositionChanged.listen((position) {/* update slider */});
  player.onError.listen((error) {/* async failure */});

  try {
    final duration = await player.setSource(
      AudioSource.url('https://example.com/song.mp3'),
    );
    // AudioSource.file('/absolute/path/song.mp3')
    // AudioSource.asset('assets/audio/ring.wav')
    // AudioSource.asset('assets/audio/ring.wav', package: 'other_pkg')
    await player.setVolume(0.8);
    await player.setSpeed(1.0);
    await player.play();
    // Use [duration] when non-null.
  } on AudioError catch (e) {
    // e.code == AudioError.codeSourceLoadFailed, etc.
  } finally {
    await player.dispose();
  }
}
```

### Loop, seek, and completion

```dart
final player = AudioPlayer();
await player.setSource(AudioSource.asset('assets/audio/ring.wav'));
await player.setLooping(true); // no PlayerState.completed while looping
await player.play();
await player.seek(const Duration(seconds: 10));
final position = await player.getPosition();
player.onPlayerComplete.listen((_) {
  // fires only when looping is false and playback reaches the end
});
```

### Per-player output device

```dart
final outputs = await AudioPlayer.listOutputDevices();
await player.setOutputDevice(outputs.first.id);
final current = await player.getOutputDevice(); // null = system default
await player.setOutputDevice(null);
```
