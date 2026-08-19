# Changelog

## 2.0.1

- update flutter version to 3.38.0 version

## 2.0.0

- Initial release: `HTMLAudioElement` playback and `MediaRecorder` recording
  with `AnalyserNode` real-time amplitude; pure-Dart implementation of
  `XueHuaAudioPlatform` (no platform channels).
  首个版本：HTMLAudioElement 播放与 MediaRecorder 录音（AnalyserNode 振幅），
  纯 Dart 实现。
- Device management: `mediaDevices.enumerateDevices`, per-player `setSinkId`
  output routing and input selection via `getUserMedia` constraints.
  设备管理：设备枚举、setSinkId 输出路由与 getUserMedia 输入选择。
