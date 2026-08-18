# xue_hua_audio_darwin

The iOS and macOS implementation of [`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio).
[`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio) 插件的 iOS 与 macOS 实现（共享 Swift 源码）。

Playback is driven by `AVPlayer`; recording uses `AVAudioEngine` with an input
tap for real-time amplitude and `AVAudioFile` for WAV / AAC-LC output. On iOS
the plugin manages `AVAudioSession` automatically.

播放基于 `AVPlayer`；录音使用 `AVAudioEngine` 的输入 tap 实时计算振幅，并经
`AVAudioFile` 写出 WAV / AAC-LC。iOS 端自动管理 `AVAudioSession`。

## Usage / 用法

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin),
which means you can simply use `xue_hua_audio` normally. This package will be
automatically included in your app when you do, so you do not need to add it
to your `pubspec.yaml`.

本包是 `xue_hua_audio` 的官方背书实现：直接依赖 `xue_hua_audio` 即可自动引入，
无需在 `pubspec.yaml` 中单独添加。
