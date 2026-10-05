## 2.1.0

- update `com.android.tools.build:gradle` to `9.1.0` version
- this version build need `compileSdk` = `37`
- update example android project version

## 2.0.6

- Adapt the host APIs to Pigeon 29 Kotlin `suspend` methods so release builds compile.
  将 Host API 适配到 Pigeon 29 生成的 Kotlin `suspend` 方法，使 release 构建可以通过。
- Depend on `kotlinx-coroutines-android` 1.11.0.
  依赖 `kotlinx-coroutines-android` 1.11.0。

## 2.0.5

- update `xue_hua_audio_platform_interface` version to `2.0.4` .
- use new `pigeon` version generate code .

## 2.0.4

- update android package version

## 2.0.3

- update package version

## 2.0.2

- Raise the minimum Flutter version to 3.44.0.
  最低 Flutter 版本提升至 3.44.0。
- Use Android Gradle Plugin 8.13.2 and set the Android library version to 1.0.0.
  使用 Android Gradle Plugin 8.13.2，并将 Android 库版本设为 1.0.0。

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
