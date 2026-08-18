# xue_hua_audio_android

The Android implementation of [`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio).
[`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio) 插件的 Android 实现。

Playback is driven by Media3 ExoPlayer; recording uses `AudioRecord` with
WAV (hand-written header) or AAC-LC (`MediaCodec` + `MediaMuxer`) encoding and
real-time RMS→dBFS amplitude reporting.

播放基于 Media3 ExoPlayer；录音使用 `AudioRecord`，支持 WAV（手写文件头）与
AAC-LC（`MediaCodec` + `MediaMuxer`）编码，并实时上报 RMS→dBFS 振幅。

## Usage / 用法

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin),
which means you can simply use `xue_hua_audio` normally. This package will be
automatically included in your app when you do, so you do not need to add it
to your `pubspec.yaml`.

本包是 `xue_hua_audio` 的官方背书实现：直接依赖 `xue_hua_audio` 即可自动引入，
无需在 `pubspec.yaml` 中单独添加。
