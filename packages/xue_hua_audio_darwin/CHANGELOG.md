# Changelog

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
