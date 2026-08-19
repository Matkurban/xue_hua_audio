# Changelog

## 2.0.1

- update flutter version to 3.38.0 version

## 2.0.0

Complete rewrite as a federated plugin with fully native implementations.
彻底重写为联合插件，全平台纯原生实现。

- **BREAKING**: the Rust (`flutter_rust_bridge` + `rodio`) engine is removed;
  see [MIGRATION.md](https://github.com/Matkurban/xue_hua_audio/blob/main/MIGRATION.md).
  移除 Rust 引擎，迁移指南见 MIGRATION.md。
- New `AudioPlayer` API: `setSource` (file / URL / asset), play / pause /
  stop / seek, volume, speed, looping, and streams for state / position /
  duration / errors. 全新播放 API。
- New `AudioRecorder` API: WAV / AAC-LC / Opus recording with pause / resume /
  cancel, permission handling, input device selection, and a real-time
  amplitude (dBFS) stream. 全新录音 API，含实时振幅流。
- New Web platform support. 新增 Web 平台支持。
- Audio device management: `AudioPlayer.listOutputDevices` /
  `getOutputDevice` / `setOutputDevice` and `AudioRecorder.listInputDevices` /
  `getInputDevice` / `setInputDevice` with the unified `AudioDevice` type.
  新增音频设备管理：输出 / 输入设备的枚举、查询与设置（统一 `AudioDevice`
  类型）。
- Network URLs now stream natively instead of downloading to temp files.
  网络音频改为原生流式播放。
- Structured `AudioError` on every method and via `onError` streams.
  统一结构化错误。

## 1.0.2

- Rust/FFI implementation (legacy). 旧版 Rust/FFI 实现。
