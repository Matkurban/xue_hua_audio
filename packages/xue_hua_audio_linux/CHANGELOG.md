## 2.0.6

- Fix a crash (use-after-free) on every `setSource`, `seekTo` and recorder `stop`/`cancel`: deferred Pigeon response handles are now retained until answered.
  修复每次 `setSource`、`seekTo` 及录音 `stop`/`cancel` 时的崩溃（释放后使用）：延迟回复的 Pigeon 句柄现在会被持有直至回复。
- Fix recorder amplitude always reporting -160 dBFS (the `level` peak field is an array, not a list).
  修复录音振幅始终为 -160 dBFS 的问题（`level` 的 peak 字段是数组而非列表）。
- Fix Opus recording failing to start: capture is resampled to 48 kHz before `opusenc`.
  修复 Opus 录音无法启动：编码前重采样到 48 kHz。
- Report updated durations for streamed sources (e.g. Ogg/Opus over HTTP) on `DURATION_CHANGED` and at end of stream.
  流式来源（如 HTTP 上的 Ogg/Opus）在 `DURATION_CHANGED` 与播放结束时上报更新后的时长。

## 2.0.5

- Fix Linux build: use the Pigeon-generated enum names (`XUE_HUA_AUDIO_PLATFORM_INTERFACE_*`) instead of the stale `XHA_MESSAGES_*` names in `xue_hua_audio_linux_plugin.cc`.
  修复 Linux 编译错误：插件源码改用 Pigeon 生成的枚举名 `XUE_HUA_AUDIO_PLATFORM_INTERFACE_*`。

## 2.0.4 

- update `xue_hua_audio_platform_interface` version to 2.0.4 .
- use new `pigeon` version generate code .

## 2.0.3

- update package version

## 2.0.2

- Raise the minimum Flutter version to 3.44.0.
  最低 Flutter 版本提升至 3.44.0。

## 2.0.1

- update flutter version to 3.38.0 version

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
