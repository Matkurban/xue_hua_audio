# Integration tests / 集成测试

`audio_test.dart` plays every format in `assets/test_audio/` from a file, an
HTTP URL and an asset, then records with every encoder and plays it back.

`audio_test.dart` 以文件、HTTP URL 与 Asset 方式播放 `assets/test_audio/` 中的
每种格式，再用每种编码器录音并回放。

## Headless Linux / 无头 Linux

```sh
sudo apt-get install pulseaudio xvfb gstreamer1.0-plugins-{base,good,bad,ugly} gstreamer1.0-libav
pulseaudio --start --exit-idle-time=-1 -n \
  --load=module-native-protocol-unix \
  --load="module-null-sink sink_name=nullsink" --load=module-always-sink
pactl set-default-sink nullsink && pactl set-default-source nullsink.monitor
# Optional: feed a tone so recordings carry signal / 可选：输入测试音
gst-launch-1.0 -q audiotestsrc ! pulsesink &
XHA_EXPECT_SIGNAL=1 xvfb-run -a flutter test integration_test/audio_test.dart -d linux
```

On Windows / macOS run `flutter test integration_test/audio_test.dart -d windows`
(or `-d macos`) on a machine with an audio device.
