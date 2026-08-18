# Changelog

## 2.0.0

- Initial release: GStreamer `playbin` playback and
  `autoaudiosrc ! level ! encoder ! filesink` recording (WAV / Opus / AAC)
  with real-time amplitude from the `level` element.
  首个版本：GStreamer 播放与录音（level 元素实时振幅）。
- Device management: `GstDeviceMonitor` enumeration, playbin `audio-sink`
  output selection (effective from the next `setSource`) and recorder source
  selection before `start`.
  设备管理：GstDeviceMonitor 枚举、playbin 输出选择（自下一次 setSource
  生效）与录音开始前的输入设备选择。
