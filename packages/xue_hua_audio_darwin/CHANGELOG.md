## 2.0.6

- Amplitude events now report the peak of *all* audio since the previous event (previously only the single buffer that triggered the event, so ~half of the audio was ignored and values were uneven). Tap buffer reduced to 2048 frames.
  振幅事件现在上报自上次事件以来*全部*音频的峰值（此前仅取触发事件的那一个 buffer，约一半音频被忽略且数值不均匀）；tap 缓冲减小为 2048 帧。

## 2.0.5

- Adapt the host APIs to Pigeon 29 Swift `async throws` methods so iOS and macOS builds compile.
  将 Host API 适配到 Pigeon 29 生成的 Swift `async throws` 方法，使 iOS 与 macOS 构建可以通过。

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

- Initial release: `AVPlayer` playback and `AVAudioEngine` recording
  (WAV / AAC-LC, real-time amplitude) with shared Swift sources for iOS 13+
  and macOS 10.15+; automatic `AVAudioSession` management on iOS.
  首个版本：AVPlayer 播放与 AVAudioEngine 录音，iOS/macOS 共享 Swift 源码。
- Device management: CoreAudio HAL enumeration and per-player
  `audioOutputDeviceUniqueID` routing on macOS; `AVAudioSession`
  `availableInputs` / `setPreferredInput` on iOS (output routing is
  system-controlled on iOS).
  设备管理：macOS 通过 CoreAudio 枚举并按播放器路由输出；iOS 通过
  AVAudioSession 选择输入（输出路由由系统控制）。
