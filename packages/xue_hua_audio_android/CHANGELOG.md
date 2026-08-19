# Changelog

## 2.0.1

- update flutter version to 3.38.0 version

## 2.0.0

- Initial release: Media3 ExoPlayer playback (file / URL / asset, volume,
  speed, looping, seek) and `AudioRecord` recording (WAV / AAC-LC, pause /
  resume / cancel, input device selection, real-time amplitude).
  首个版本：ExoPlayer 播放与 AudioRecord 录音（含实时振幅）。
- Device management via `AudioManager.getDevices`, ExoPlayer
  `setPreferredAudioDevice` and `AudioRecord.setPreferredDevice` (API 23+,
  live switching for both playback and recording).
  设备管理：输出 / 输入设备枚举与切换（播放、录音均支持运行中切换）。
