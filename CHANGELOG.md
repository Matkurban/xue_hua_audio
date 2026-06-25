# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
