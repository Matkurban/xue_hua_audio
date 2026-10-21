import 'package:flutter/foundation.dart';

import 'types/amplitude.dart';
import 'types/audio_error.dart';
import 'types/player_state.dart';

/// An event emitted by a native (or web) player instance.
///
/// The platform implementation pushes these events; the app-facing
/// `AudioPlayer` class splits them into typed streams
/// (`onStateChanged`, `onDurationChanged`, ...).
///
/// 由原生（或 Web）播放器实例推送的事件。
///
/// 平台实现负责推送这些事件；应用层的 `AudioPlayer` 会把它们拆分为类型化的
/// 流（`onStateChanged`、`onDurationChanged` 等）。
@immutable
sealed class PlayerEvent {
  const PlayerEvent();
}

/// The player transitioned to a new [state]. / 播放器进入新的状态 [state]。
final class PlayerStateEvent extends PlayerEvent {
  /// Creates a state-change event carrying the new [state].
  /// 创建携带新状态 [state] 的状态变更事件。
  const PlayerStateEvent(this.state);

  /// The new player state. / 播放器的新状态。
  final PlayerState state;
}

/// Playback reached the end of the audio (non-looping mode).
/// 播放到达音频末尾（非循环模式）。
final class PlayerCompletedEvent extends PlayerEvent {
  /// Creates a completion event. / 创建播放完成事件。
  const PlayerCompletedEvent();
}

/// The duration of the loaded source became known or changed.
/// 已加载音频的时长首次可知或发生变化。
final class PlayerDurationEvent extends PlayerEvent {
  /// Creates a duration event.
  ///
  /// [duration]: the total duration, or `null` when unknown (live streams).
  ///
  /// 创建时长事件。
  ///
  /// [duration]：音频总时长；未知（如直播流）时为 `null`。
  const PlayerDurationEvent(this.duration);

  /// The total duration, `null` when unknown. / 总时长，未知时为 `null`。
  final Duration? duration;
}

/// An asynchronous playback failure occurred. / 播放过程中发生异步失败。
final class PlayerErrorEvent extends PlayerEvent {
  /// Creates an error event carrying [error]. / 创建携带 [error] 的错误事件。
  const PlayerErrorEvent(this.error);

  /// The structured error. / 结构化错误信息。
  final AudioError error;
}

/// An event emitted by a native (or web) recorder instance.
/// 由原生（或 Web）录音机实例推送的事件。
@immutable
sealed class RecorderEvent {
  const RecorderEvent();
}

/// The recorder transitioned to a new [state]. / 录音机进入新的状态 [state]。
final class RecorderStateEvent extends RecorderEvent {
  /// Creates a state-change event carrying the new [state].
  /// 创建携带新状态 [state] 的状态变更事件。
  const RecorderStateEvent(this.state);

  /// The new recorder state. / 录音机的新状态。
  final RecorderState state;
}

/// A new microphone amplitude sample is available.
/// 新的麦克风振幅采样已就绪。
final class RecorderAmplitudeEvent extends RecorderEvent {
  /// Creates an amplitude event carrying [amplitude].
  /// 创建携带 [amplitude] 的振幅事件。
  const RecorderAmplitudeEvent(this.amplitude);

  /// The amplitude sample. / 振幅采样值。
  final Amplitude amplitude;
}

/// An asynchronous recording failure occurred. / 录音过程中发生异步失败。
final class RecorderErrorEvent extends RecorderEvent {
  /// Creates an error event carrying [error]. / 创建携带 [error] 的错误事件。
  const RecorderErrorEvent(this.error);

  /// The structured error. / 结构化错误信息。
  final AudioError error;
}
