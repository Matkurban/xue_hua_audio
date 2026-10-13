## 2.0.5

- Fix a use-after-free: event channels now unregister their handler when a player/recorder is disposed.
  修复释放后使用：播放器/录音器释放时注销事件通道处理器。
- Fix a use-after-free when amplitude events were still queued after a recorder was disposed.
  修复录音器释放后仍有排队的振幅事件导致的释放后使用。
- Answer pending `setSource`/`seekTo` calls when a player is disposed instead of leaving them hanging.
  播放器释放时回复挂起的 `setSource`/`seekTo` 调用，避免 Future 永不完成。
- Report updated durations for streamed sources (`DURATIONCHANGE`) and at end of playback.
  流式来源在 `DURATIONCHANGE` 与播放结束时上报更新后的时长。
- Amplitude now reports the peak over the whole interval instead of the last packet.
  振幅改为统计整个间隔内的峰值，而非最后一个数据包。
- AAC recording snaps sample rate (44.1/48 kHz) and bit rate (96–192 kbps) to values the Media Foundation encoder accepts.
  AAC 录音会将采样率（44.1/48 kHz）与码率（96–192 kbps）调整为 Media Foundation 编码器支持的值。
- `stop()` without an active recording returns `null`; `cancel()` no longer deletes a file already returned by `stop()`.
  未在录音时 `stop()` 返回 `null`；`cancel()` 不再删除已由 `stop()` 返回的文件。

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

- Initial release: Media Foundation (`IMFMediaEngine`) playback and WASAPI
  recording (WAV / AAC-LC, pause / resume / cancel, input device selection,
  real-time amplitude).
  首个版本：Media Foundation 播放与 WASAPI 录音（含实时振幅）。
- Device management: `IMMDeviceEnumerator` enumeration and
  `IMFMediaEngineAudioEndpointId` output routing (Win10 1703+, effective from
  the next `setSource`); recorder input selection before `start`.
  设备管理：IMMDevice 枚举与输出端点路由（自下一次 setSource 生效）、
  录音开始前的输入设备选择。
