# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-06-30

### Fixed

- **Recording pause/resume** — advance interleaved frame position while paused so stereo WAV channels stay aligned after resume.
- **Track lifecycle** — gate `pause`, `resume`, `seek`, `volume`, and `replace` behind active registration; prevents zombie playback after `stop()`.
- **Recorder re-registration** — `start()` after `stop()` re-enters the Engine registry so `stopAllRecorders()` stops restarted sessions.
- **Recording start race** — set `is_recording` before spawning the writer thread.
- **Recording startup errors** — surface microphone/WAV open failures within ~100 ms of `start()` instead of only on `stop()`.
- **Natural playback finish** — progress watcher unregisters finished non-loop tracks from the Engine registry; watcher thread no longer calls `join` on itself (fixes `Resource deadlock avoided` panic on macOS).
- **Mutex poison** — registry locks return `XueHuaAudioError` instead of panicking on poison.
- **Android NDK init** — log JNI failures instead of silently discarding them.
- **Dart facade** — correct `XuehuaAudio.initialize()` message in `StateError`.

### Changed

- **Example app** — auto `stopAndCleanup()` when a track reports `isFinished`.
- **Integration tests** — seek/pause/multi-track coverage; recording tests gated by `--dart-define=RECORDING_TEST=true`.

## [1.0.2] - 2026-06-27

### Fixed

- **Android NDK context** — align `XueHuaAudioPlugin` with the `ndk-context` pattern used in sibling plugins: `@JvmStatic initAndroid`, static JNI export, and `ffiPlugin: true` in `pubspec.yaml`. Fixes `android context was not initialized` panic when `XueHuaAudioEngine` opens the audio device on Android.

### Changed

- **Android JNI** — migrate `android_init.rs` to jni 0.22 (`EnvUnowned`, `Global<JObject>`, `JavaVM::get_raw`).
- **Android `minSdkVersion`** — plugin default remains **26** (required by rodio/cpal 0.17 AAudio backend).

## [1.0.1] - 2026-06-26

### Added

- **Loop playback** — optional `loop` parameter on `loadLocal`, `loadAsset`, `loadUrl`, `loadFromPath`, `loadFromBytes`, `replaceFromPath`, and `replaceFromBytes`. Uses rodio `LoopedDecoder` for streamed seek-back looping; `positionSecs` and `progress` wrap each lap until `track.stop()`.

## [1.0.0] - 2026-06-26

Initial stable release.

### Added

- **Multi-track playback** — independent `XueHuaAudioTrack` instances mixed through a shared rodio `MixerDeviceSink`.
- **Audio sources** — load from local file path, Flutter Asset (via temp file), or network URL (download with timeout/retry).
- **Playback control** — pause, resume, seek, volume, per-track stop, and engine-wide `stopAll()`.
- **Playback progress Stream** — `track.progressStream` pushes `XueHuaPlaybackProgress` approximately every 100 ms; sync `playbackProgress()` for one-shot queries.
- **Microphone recording** — `XuehuaRecordingSession` with progress/completed streams; WAV output via rodio + hound.
- **Dart facade** — `XuehuaAudioPlayer`, `XueHuaAudioEngineLoading`, `XueHuaAudioTrackLifecycle`, `TempFileRegistry` for Asset/URL temp-file cleanup.
- **Platform support** — Android, iOS, macOS, Linux, Windows (FFI plugin via Cargokit).
- **Audio formats** — WAV, MP3, FLAC, Vorbis, MP4 (rodio/symphonia decoders).
- **Example app** — recording and playback demo tabs with progress UI.
- **Tests** — Rust unit tests for progress ratio; Dart integration tests for playback lifecycle.

### Changed

- Replaced Dart-side progress polling with Rust-backed Stream push.
- Introduced `TrackSharedState` so `engine.stopAll()` deactivates tracks and stops progress watchers; `track.stop()` is idempotent after engine stop.
- Progress watcher reads shared duration so `replaceFromPath` / `replaceFromBytes` stay in sync.

### Platform requirements

- Android `minSdkVersion` 26
- Microphone permission declarations for recording (plugin manifests / macOS entitlements)
