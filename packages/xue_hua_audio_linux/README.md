# xue_hua_audio_linux

The Linux implementation of [`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio).
[`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio) 插件的 Linux 实现。

Playback and recording are both driven by GStreamer: `playbin` for playback,
and an `autoaudiosrc ! level ! encoder ! filesink` pipeline for recording,
where the `level` element provides the real-time amplitude stream. Supported
encoders: WAV, Opus, AAC.

播放与录音均基于 GStreamer：播放用 `playbin`，录音用
`autoaudiosrc ! level ! 编码器 ! filesink` 管道，`level` 元素直接产出实时
振幅。支持 WAV、Opus、AAC 编码。

Building requires the GStreamer development headers:
构建需要安装 GStreamer 开发包：

```bash
sudo apt install libgstreamer1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

## Usage / 用法

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin),
which means you can simply use `xue_hua_audio` normally. This package will be
automatically included in your app when you do, so you do not need to add it
to your `pubspec.yaml`.

本包是 `xue_hua_audio` 的官方背书实现：直接依赖 `xue_hua_audio` 即可自动引入，
无需在 `pubspec.yaml` 中单独添加。
