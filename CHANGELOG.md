## 2.2.5

- iOS: Ogg Opus playback expectations are version-gated — `sourceLoadFailed` on older iOS (verified 17/18); playback succeeds on newer runtimes (verified 26/27). Ogg Vorbis remains unsupported.
  iOS：Ogg Opus 播放期望按系统版本分支——旧版 iOS（已验证 17/18）仍为 `sourceLoadFailed`；较新运行时（已验证 26/27）可播放。Ogg Vorbis 仍不支持。
- Darwin: deactivate playback session before record; use `allowBluetoothHFP`; mix with others. Example UI primes microphone permission and times out `hasPermission`/`start` so TCC dialogs cannot hang driver runs.
  Darwin：录音前先停用仅播放会话；改用 `allowBluetoothHFP` 并允许混音。示例 UI 预请求麦克风权限，并为 `hasPermission`/`start` 加超时，避免 TCC 弹窗卡住 driver。
- Verified iOS flutter test / flutter drive on simulators ios17 / ios18 / ios26 / ios27.
  已在 ios17 / ios18 / ios26 / ios27 模拟器上验证 flutter test / flutter drive。

## 2.2.4

- Example Android: allow cleartext HTTP to `127.0.0.1` / `localhost` / `10.0.2.2` via network security config (and debug `usesCleartextTraffic`) so integration_test URL playback works on API 28+ (`ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED` otherwise).
  示例 Android：通过 network security config（及 debug 的 `usesCleartextTraffic`）放行到 `127.0.0.1` / `localhost` / `10.0.2.2` 的明文 HTTP，使 integration_test 的 URL 播放在 API 28+ 可用（否则会报 `ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED`）。
- Verified Android flutter test / flutter drive on API 24 / 28 / 31 / 36 emulators.
  已在 API 24 / 28 / 31 / 36 模拟器上验证 Android flutter test / flutter drive。

## 2.2.3

- Darwin: hop `AVPlayer.seek` completion back to the main queue before resuming the Pigeon / async continuation (Apple may call the handler on an arbitrary queue).
  Darwin：在恢复 Pigeon / async 延续前，将 `AVPlayer.seek` 完成回调切回主队列（Apple 可能在任意队列调用该回调）。
- Darwin: reject Opus recording with `unsupportedEncoder` before checking microphone permission, so the error code does not depend on TCC state.
  Darwin：在检查麦克风权限之前就以 `unsupportedEncoder` 拒绝 Opus 录音，错误码不再依赖 TCC 状态。
- Docs: spell out playback/recording format limits — iOS cannot decode Ogg Vorbis (`sourceLoadFailed`); Opus recording remains Linux/Web only (`unsupportedEncoder` elsewhere).
  文档：明确播放/录音格式限制——iOS 无法解码 Ogg Vorbis（`sourceLoadFailed`）；Opus 录音仍仅 Linux/Web（其他平台为 `unsupportedEncoder`）。
- Tests: assert Darwin/Android Opus `unsupportedEncoder`; assert iOS Ogg Vorbis `sourceLoadFailed`; add seek / volume / speed / loop / device coverage; macOS + iOS flutter_driver / integration_test runs.
  测试：断言 Darwin/Android 的 Opus `unsupportedEncoder`；断言 iOS 的 Ogg Vorbis `sourceLoadFailed`；补充 seek / 音量 / 变速 / 循环 / 设备覆盖；补齐 macOS + iOS 的 flutter_driver / integration_test。

## 2.2.2

- Windows: Opus recording now fails with the stable `unsupportedEncoder` error code (same as Android/Darwin) instead of `recordingFailed`. WAV and AAC-LC recording unchanged.
  Windows：Opus 录音改为抛出稳定的 `unsupportedEncoder` 错误码（与 Android/Darwin 一致），不再误报 `recordingFailed`。WAV 与 AAC-LC 录音不变。
- Tests: drop deprecated `package:flutter/material.dart` under Flutter 3.50 (use `widgets.dart`); assert Windows Opus contract; Windows flutter_driver / integration_test coverage for playback, recording, and waveform UI.
  测试：在 Flutter 3.50 下去掉已弃用的 `package:flutter/material.dart`（改用 `widgets.dart`）；断言 Windows Opus 契约；补齐 Windows 上 flutter_driver / integration_test 对播放、录音与波形 UI 的覆盖。

## 2.2.1

- Fix Linux build after the single-package merge: Pigeon enum constants in `linux/xue_hua_audio_linux_plugin.cc` still used the old `XUE_HUA_AUDIO_PLATFORM_INTERFACE_*` prefix and failed to compile against the regenerated `messages.g.h` (`XUE_HUA_AUDIO_*`).
  修复合并为单包后的 Linux 编译：`linux/xue_hua_audio_linux_plugin.cc` 里的 Pigeon 枚举仍使用旧前缀 `XUE_HUA_AUDIO_PLATFORM_INTERFACE_*`，与重新生成的 `messages.g.h`（`XUE_HUA_AUDIO_*`）不一致导致编译失败。
- Linux recorder: add a 5s EOS timeout on stop/cancel so a stuck muxer cannot hang the Dart `stop()`/`cancel()` call forever; prefer returning the file when it already has bytes.
  Linux 录音：stop/cancel 增加 5 秒 EOS 超时，避免封装器卡住时 Dart 的 `stop()`/`cancel()` 一直挂起；若文件已有数据则优先返回路径。
- Silence the Clang `G_TYPE_VALUE_ARRAY` deprecation pragma when reading `level` peaks; prefer `GstValueArray`.
  读取 `level` 峰值时消除 Clang 对 `G_TYPE_VALUE_ARRAY` 的弃用 pragma 警告，优先使用 `GstValueArray`。
- Example: ValueKeys for flutter_driver / integration_test UI automation; add `ui_driver_test.dart` + `test_driver/integration_test.dart`; document `flutter drive` on headless Linux.
  示例：为 flutter_driver / integration_test UI 自动化加 ValueKey；新增 `ui_driver_test.dart` 与 `test_driver/integration_test.dart`；补充无头 Linux 下 `flutter drive` 说明。

## 2.2.0

- Ship as one Flutter plugin package. Platform implementations, the platform interface, and the Web plugin now live in `xue_hua_audio` instead of separate endorsed packages.
  改为单个 Flutter 插件包。平台实现、平台接口和 Web 插件都收进 `xue_hua_audio`，不再拆成独立的 endorsed 包。
- Public Dart API is unchanged. Import `package:xue_hua_audio/xue_hua_audio.dart` as before. `XueHuaAudioPlatform` is exported from that library; the method channel is `package:xue_hua_audio/xue_hua_audio_method_channel.dart`.
  公开 Dart API 不变，仍从 `package:xue_hua_audio/xue_hua_audio.dart` 导入。`XueHuaAudioPlatform` 由该库导出；method channel 位于 `package:xue_hua_audio/xue_hua_audio_method_channel.dart`。

## 2.1.1

- Waveform widgets no longer depend on Material (`package:flutter/widgets.dart` only). Defaults are now fixed public constants `WaveformColors.active` (`0xFF22A45D`) and `WaveformColors.inactive` (`0xFFB8BEC4`) instead of the theme's primary/outlineVariant; pass `color` / `gradient` / `inactiveColor` to customize.
  波形组件不再依赖 Material（仅使用 `package:flutter/widgets.dart`）。默认颜色改为公开常量 `WaveformColors.active`（`0xFF22A45D`）与 `WaveformColors.inactive`（`0xFFB8BEC4`），不再取自主题；可通过 `color` / `gradient` / `inactiveColor` 自定义。
- Fix `AudioWaveform` showing a regular repeating, stepped pattern while silent: the history is now event driven (one bar per level event, no holding/decay between events), with a -50 dBFS noise gate, soft-knee curve (`curve`), and scroll speed that follows the measured event rate. `WaveformController.samplesPerSecond` is replaced by `maxBarsPerSecond`; new `curve`, `barInterval`; default `minDb` is -50.
  修复 `AudioWaveform` 在静音时出现规律重复、阶梯状图案：历史改为事件驱动（每个电平事件一根柱，事件之间不保持/衰减），加入 -50 dBFS 噪声门与软膝曲线（`curve`），滚动速度跟随实测事件频率。`WaveformController.samplesPerSecond` 改为 `maxBarsPerSecond`；新增 `curve`、`barInterval`；默认 `minDb` 为 -50。
- Require `xue_hua_audio_platform_interface ^2.0.5` (50 ms amplitude default), `xue_hua_audio_darwin ^2.0.6`, `xue_hua_audio_android ^2.1.1` (accurate interval peaks).
  依赖 `xue_hua_audio_platform_interface ^2.0.5`（振幅默认 50 ms）、`xue_hua_audio_darwin ^2.0.6`、`xue_hua_audio_android ^2.1.1`（间隔峰值更准确）。

## 2.1.0

- Add `AudioWaveform`: a live, scrolling recording waveform (bars / line / filled) driven by an `AudioRecorder`, a dBFS `Stream<double>`, or a `WaveformController`. Fixed-rate ring buffer, attack/release smoothing, dB range, gradient, edge fade, idle dots, RTL-aware scrolling, accessibility semantics.
  新增 `AudioWaveform`：实时滚动的录音波形（柱状/折线/填充），可由 `AudioRecorder`、dBFS `Stream<double>` 或 `WaveformController` 驱动。定速环形缓冲、起音/释音平滑、dB 范围、渐变、边缘渐隐、空闲圆点、支持 RTL、无障碍语义。
- Add `StaticWaveform` for a finished recording with playback progress.
  新增 `StaticWaveform`，显示已完成录音及播放进度。
- Add `WaveformController` (public ring buffer / normalization).
  新增 `WaveformController`（公开的环形缓冲与归一化）。
- Example: new waveform demo in the recorder card.
  示例：录音卡片加入波形演示。

## 2.0.10

- Require `xue_hua_audio_linux` `^2.0.6` and `xue_hua_audio_windows` `^2.0.5` (crash and recording fixes).
  依赖 `xue_hua_audio_linux` `^2.0.6` 与 `xue_hua_audio_windows` `^2.0.5`（崩溃与录音修复）。
- Example: add an end-to-end playback/recording integration test (`example/integration_test`).
  示例：新增端到端播放/录音集成测试（`example/integration_test`）。

## 2.0.9

- Require `xue_hua_audio_linux` `^2.0.5` (fixes the Linux build).
  依赖 `xue_hua_audio_linux` `^2.0.5`（修复 Linux 编译）。

## 2.0.8

- update `xue_hua_audio_android` version to `2.1.0`

## 2.0.7

- Fix Android, iOS, and macOS release builds against Pigeon 29 async host APIs.
  修复 Android、iOS 与 macOS 在 Pigeon 29 异步 Host API 下的 release 构建。
- Require `xue_hua_audio_android` 2.0.6 and `xue_hua_audio_darwin` 2.0.5.
  依赖 `xue_hua_audio_android` 2.0.6 与 `xue_hua_audio_darwin` 2.0.5。

## 2.0.4 

- update `xue_hua_audio_platform_interface` version to `2.0.4` .
- use new `pigeon` version generate code .

## 2.0.5

- update package version

## 2.0.4

- Ship Agent Skills for playback, recording, and platform setup so coding
  agents can install them with `dart run skills@ get -p xue_hua_audio`.
  随包发布播放、录音与平台配置的 Agent Skills，可通过
  `dart run skills@ get -p xue_hua_audio` 安装。

## 2.0.3

- update package version

## 2.0.2

- Raise the minimum Flutter version to 3.44.0.
  最低 Flutter 版本提升至 3.44.0。
- Align the example Android build with Gradle 8.14.5 and Android Gradle Plugin 8.13.2.
  示例 Android 工程对齐 Gradle 8.14.5 与 Android Gradle Plugin 8.13.2。

## 2.0.1

- update flutter version to 3.38.0 version

## 2.0.0

Complete rewrite as a federated plugin with fully native implementations.
彻底重写为联合插件，全平台纯原生实现。

- **BREAKING**: the Rust (`flutter_rust_bridge` + `rodio`) engine is removed.
  移除 Rust 引擎。
- New `AudioPlayer` API: `setSource` (file / URL / asset), play / pause /
  stop / seek, volume, speed, looping, and streams for state / position /
  duration / errors. 全新播放 API。
- New `AudioRecorder` API: WAV / AAC-LC / Opus recording with pause / resume /
  cancel, permission handling, input device selection, and a real-time
  amplitude (dBFS) stream. 全新录音 API，含实时振幅流。
- New Web platform support. 新增 Web 平台支持。
- Audio device management: `AudioPlayer.listOutputDevices` /
  `getOutputDevice` / `setOutputDevice` and `AudioRecorder.listInputDevices` /
  `getInputDevice` / `setInputDevice` with the unified `AudioDevice` type.
  新增音频设备管理：输出 / 输入设备的枚举、查询与设置（统一 `AudioDevice`
  类型）。
- Network URLs now stream natively instead of downloading to temp files.
  网络音频改为原生流式播放。
- Structured `AudioError` on every method and via `onError` streams.
  统一结构化错误。

## 1.0.2

- Rust/FFI implementation (legacy). 旧版 Rust/FFI 实现。
