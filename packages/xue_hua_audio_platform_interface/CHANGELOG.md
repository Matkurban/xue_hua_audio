## 2.0.5

- `RecordConfig.amplitudeInterval` now defaults to 50 ms (was 100 ms) for smoother level meters.
  `RecordConfig.amplitudeInterval` 默认值由 100 ms 改为 50 ms，电平表更平滑。

## 2.0.4

- update `pigeon` version to `29.0.4`

## 2.0.3

- update package version

## 2.0.2

- Raise the minimum Flutter version to 3.44.0.
  最低 Flutter 版本提升至 3.44.0。

## 2.0.1

- update flutter version to 3.38.0 version

## 2.0.0

- Initial release of the platform interface for the rewritten federated
  plugin: `XueHuaAudioPlatform`, Pigeon message definitions, shared types
  (`AudioSource`, `PlayerState`, `RecorderState`, `Amplitude`, `AudioError`,
  `RecordConfig`, `AudioDevice`) and typed event models, plus input/output
  device query and selection APIs.
  联合插件重写后的平台接口首个版本：平台抽象、Pigeon 定义、共享类型与事件模型。
