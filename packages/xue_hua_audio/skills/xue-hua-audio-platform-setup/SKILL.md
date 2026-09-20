---
name: xue-hua-audio-platform-setup
description: >-
  Use when adding xue_hua_audio to a Flutter app or fixing microphone,
  network, Info.plist, entitlements, GStreamer, CORS, or Web recording
  setup on Android, iOS, macOS, Windows, Linux, or Web.
---

# xue_hua_audio platform setup

Host-app configuration required by `package:xue_hua_audio`. Playback and
recording Dart APIs are in the sibling skills `xue-hua-audio-playback` and
`xue-hua-audio-recording`.

No Dart `initialize()` call is required on any platform.

## Android

Plugin manifest already declares:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

- `RECORD_AUDIO` is required for `AudioRecorder`. Apps that never record
  may remove it from the merged manifest with `tools:node="remove"`.
- `INTERNET` is required for `AudioSource.url` playback.
- Plugin `minSdk` is **24** (`packages/xue_hua_audio_android` Gradle
  `defaultConfig.minSdk`).
- `AudioRecorder.hasPermission()` shows the system dialog when the user
  has not decided yet.

Native stack: Media3 ExoPlayer + AudioRecord.

## iOS

Minimum iOS **13.0** (`xue_hua_audio_darwin` podspec
`s.ios.deployment_target`).

Add to `ios/Runner/Info.plist` when the app records:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app records audio from the microphone.</string>
```

The plugin manages `AVAudioSession` automatically. Do not invent a
separate session-setup API on the Dart side.

`AudioPlayer.setOutputDevice` throws `AudioError` with
`AudioError.codeUnsupported`. `AudioPlayer.listOutputDevices` returns
only devices on the current audio route. Input device switch while
recording is supported (`setPreferredInput`).

Native stack: AVPlayer + AVAudioEngine.

## macOS

Minimum macOS **10.15** (`s.osx.deployment_target`).

1. Add `NSMicrophoneUsageDescription` to `macos/Runner/Info.plist` when
   the app records.
2. Add both keys to `DebugProfile.entitlements` **and**
   `Release.entitlements`:

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

`device.audio-input` is required for the microphone.
`network.client` is required for `AudioSource.url` under App Sandbox.

Set the input device **before** `start`. Calling
`AudioRecorder.setInputDevice` while recording throws
`AudioError.codeInvalidState`. Output device changes apply immediately.

Native stack: AVPlayer + AVAudioEngine.

## Windows

No extra project configuration. Media Foundation and WASAPI ship with
Windows 10+.

Output device changes take effect on the **next** `setSource`. Set the
input device before `start` (`codeInvalidState` if switched while
recording).

Native stack: Media Foundation `IMFMediaEngine` + WASAPI.

## Linux

Build-time dependency: GStreamer 1.0 (`pkg_check_modules` requires
`gstreamer-1.0`). On Debian/Ubuntu:

```bash
sudo apt install libgstreamer1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

`AudioEncoder.aacLc` and `AudioEncoder.opus` need the matching GStreamer
encoder plugin (`*` in the encoder table).

Output device changes take effect on the **next** `setSource`. Set the
input device before `start`.

Native stack: GStreamer `playbin` + `level`.

## Web

- Microphone access requires a **secure context** (HTTPS or localhost).
- `AudioRecorder.start` `path` is ignored. `stop()` returns a **blob URL**.
- The actual container/codec is chosen by the browser via
  `MediaRecorder.isTypeSupported`, not necessarily the requested
  `AudioEncoder` (`audio/webm;codecs=opus` on Chrome/Firefox, `audio/mp4`
  on Safari). `AudioEncoder.wav` is not supported.
- `UrlSource.headers` are ignored; the browser controls the request.
- Remote `AudioSource.url` playback is subject to CORS.
- `AudioDevice.label` may be empty until a media / microphone permission
  is granted.
- Output device changes apply immediately (`setSinkId`). Set the input
  device before `start`.

Native stack: `HTMLAudioElement` + `MediaRecorder` + `AnalyserNode`.

## Device-routing summary

| Platform | Set output device        | Switch input while recording |
| -------- | ------------------------ | ---------------------------- |
| Android  | Immediate (API 23+)      | Yes                          |
| iOS      | Throws `codeUnsupported` | Yes                          |
| macOS    | Immediate                | No — set before `start`      |
| Windows  | Next `setSource`         | No — set before `start`      |
| Linux    | Next `setSource`         | No — set before `start`      |
| Web      | Immediate                | No — set before `start`      |

Android output routing is immediate on API 23+; the plugin `minSdk` is 24,
so this applies on every API level the plugin supports.

## Checklist when adding the package

```yaml
dependencies:
  xue_hua_audio: ^2.0.4
```

- [ ] Android: keep or remove `RECORD_AUDIO`; `INTERNET` stays if you play URLs
- [ ] iOS: `NSMicrophoneUsageDescription` if you record
- [ ] macOS: usage description + both entitlements if you record or play URLs
- [ ] Linux: GStreamer dev packages installed on the build machine
- [ ] Web: serve over HTTPS/localhost; handle blob URLs from `stop()`
