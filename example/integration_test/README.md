# Integration tests / 集成测试

`audio_test.dart` plays every format in `assets/test_audio/` from a file, an
HTTP URL and an asset, then records with every encoder and plays it back.

`ui_driver_test.dart` drives the example UI (play / pause / stop, record,
waveform styles, cancel) via `flutter_driver` / `integration_test`.

`audio_test.dart` 以文件、HTTP URL 与 Asset 方式播放 `assets/test_audio/` 中的
每种格式，再用每种编码器录音并回放。

`ui_driver_test.dart` 用 `flutter_driver` / `integration_test` 驱动示例界面
（播放/暂停/停止、录音、波形样式、取消）。

## Headless Linux / 无头 Linux

```sh
sudo apt-get install pulseaudio xvfb gstreamer1.0-plugins-{base,good,bad,ugly} gstreamer1.0-libav
pulseaudio --start --exit-idle-time=-1 -n \
  --load=module-native-protocol-unix \
  --load="module-null-sink sink_name=nullsink" --load=module-always-sink
pactl set-default-sink nullsink && pactl set-default-source nullsink.monitor
# Optional: feed a tone so recordings carry signal / 可选：输入测试音
gst-launch-1.0 -q audiotestsrc ! pulsesink &

# API coverage / API 覆盖
XHA_EXPECT_SIGNAL=1 xvfb-run -a flutter test integration_test/audio_test.dart -d linux

# UI driver (flutter_driver) / UI 驱动
XHA_EXPECT_SIGNAL=1 xvfb-run -a flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ui_driver_test.dart \
  -d linux
```

On Windows / macOS run the same commands with `-d windows` or `-d macos`
on a machine with an audio device.

## Platform format notes / 平台格式说明

- iOS cannot play Ogg Vorbis (`tone.ogg`); the suite asserts `sourceLoadFailed`. Opus-in-Ogg (`tone.opus`) works.
  iOS 无法播放 Ogg Vorbis（`tone.ogg`），测试会断言 `sourceLoadFailed`；Ogg 容器中的 Opus（`tone.opus`）可以播放。
- Opus recording is unsupported on Android / iOS / macOS / Windows (`unsupportedEncoder`).
  Android / iOS / macOS / Windows 不支持 Opus 录音（`unsupportedEncoder`）。
