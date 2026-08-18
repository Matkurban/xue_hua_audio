/// The common platform interface for the `xue_hua_audio` plugin.
///
/// Platform implementations extend [XueHuaAudioPlatform]; app code should
/// depend on the `xue_hua_audio` package instead of this one.
///
/// `xue_hua_audio` 插件的通用平台接口。
///
/// 各平台实现需继承 [XueHuaAudioPlatform]；应用代码请依赖 `xue_hua_audio`
/// 包而非本包。
library;

export 'src/events.dart';
export 'src/method_channel_xue_hua_audio.dart';
export 'src/types/amplitude.dart';
export 'src/types/audio_device.dart';
export 'src/types/audio_error.dart';
export 'src/types/audio_source.dart';
export 'src/types/player_state.dart';
export 'src/types/record_config.dart';
export 'src/xue_hua_audio_platform.dart';
