/// Cross-platform native audio playback and recording for Flutter.
///
/// * [AudioPlayer] — plays local files, network URLs and Flutter assets,
///   with state/position/duration/error streams.
/// * [AudioRecorder] — records from the microphone with real-time
///   amplitude (dBFS) reporting for waveform UIs.
///
/// Supported platforms: Android, iOS, macOS, Windows, Linux and Web.
///
/// Flutter 跨平台原生音频播放与录音插件。
///
/// * [AudioPlayer] —— 播放本地文件、网络 URL 与 Flutter Asset，提供
///   状态/进度/时长/错误事件流。
/// * [AudioRecorder] —— 麦克风录音，实时上报振幅（dBFS），可直接驱动
///   波形 UI。
///
/// 支持平台：Android、iOS、macOS、Windows、Linux 与 Web。
library;

export 'src/types/amplitude.dart' show Amplitude;
export 'src/types/audio_device.dart' show AudioDevice;
export 'src/types/audio_error.dart' show AudioError;
export 'src/types/audio_source.dart'
    show AssetSource, AudioSource, FileSource, UrlSource;
export 'src/types/player_state.dart' show PlayerState, RecorderState;
export 'src/types/record_config.dart' show AudioEncoder, RecordConfig;
export 'xue_hua_audio_platform_interface.dart';

export 'src/audio_player.dart';
export 'src/audio_recorder.dart';
export 'src/waveform/audio_waveform.dart';
export 'src/waveform/waveform_controller.dart';
