# xue_hua_audio_web

The Web implementation of [`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio).
[`xue_hua_audio`](https://pub.dev/packages/xue_hua_audio) 插件的 Web 实现。

Playback is driven by `HTMLAudioElement`; recording uses `getUserMedia` +
`MediaRecorder` with an `AnalyserNode` for real-time amplitude. `stop()`
returns a blob URL, and the output codec depends on the browser
(`audio/webm;codecs=opus` on Chrome/Firefox, `audio/mp4` on Safari).

播放基于 `HTMLAudioElement`；录音使用 `getUserMedia` + `MediaRecorder`，并用
`AnalyserNode` 实时计算振幅。`stop()` 返回 blob URL，输出编码随浏览器而定。

Note: microphone access requires HTTPS (or localhost), and remote playback is
subject to CORS. / 注意：麦克风需要 HTTPS（或 localhost）环境，远程播放受
CORS 限制。

## Usage / 用法

This package is [endorsed](https://flutter.dev/to/endorsed-federated-plugin),
which means you can simply use `xue_hua_audio` normally. This package will be
automatically included in your app when you do, so you do not need to add it
to your `pubspec.yaml`.

本包是 `xue_hua_audio` 的官方背书实现：直接依赖 `xue_hua_audio` 即可自动引入，
无需在 `pubspec.yaml` 中单独添加。
