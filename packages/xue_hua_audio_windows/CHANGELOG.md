# Changelog

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
