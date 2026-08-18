# xue_hua_audio_windows

The Windows implementation of [`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio).
[`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio) 插件的 Windows 实现。

Playback is driven by Media Foundation's `IMFMediaEngine`; recording uses
WASAPI capture with WAV (direct write) or AAC-LC (Media Foundation transform)
encoding and real-time amplitude reporting.

播放基于 Media Foundation 的 `IMFMediaEngine`；录音使用 WASAPI 采集，支持 WAV
直写与 AAC-LC 编码，并实时上报振幅。

## Usage / 用法

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin),
which means you can simply use `xue_hua_audio` normally. This package will be
automatically included in your app when you do, so you do not need to add it
to your `pubspec.yaml`.

本包是 `xue_hua_audio` 的官方背书实现：直接依赖 `xue_hua_audio` 即可自动引入，
无需在 `pubspec.yaml` 中单独添加。
