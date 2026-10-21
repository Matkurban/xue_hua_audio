/// The lifecycle state of an audio player. / 音频播放器的生命周期状态。
///
/// State machine / 状态机:
///
/// ```
/// idle --setSource()--> loading --> ready --play()--> playing
///                                    ^                 |  ^
///                                    |             pause() play()
///                                    |                 v  |
///                                    +---- stop() --- paused
/// playing --(end of audio)--> completed
/// any state --(failure)--> error
/// ```
enum PlayerState {
  /// No source has been set yet. / 尚未设置音频源。
  idle,

  /// A source is being loaded / buffered. / 正在加载 / 缓冲音频源。
  loading,

  /// The source is loaded and ready to play. / 音频已加载完毕，可以播放。
  ready,

  /// Audio is currently playing. / 正在播放。
  playing,

  /// Playback is paused and can be resumed. / 已暂停，可恢复播放。
  paused,

  /// Playback reached the end of the audio (non-looping).
  /// 播放已到达音频末尾（非循环模式）。
  completed,

  /// Playback was stopped; the position is reset to the beginning.
  /// 播放已停止，进度重置到起点。
  stopped,

  /// An unrecoverable error occurred; see the error stream for details.
  /// 发生不可恢复的错误；详情见错误流。
  error,
}

/// The lifecycle state of an audio recorder. / 录音机的生命周期状态。
enum RecorderState {
  /// Not recording. / 未在录音。
  idle,

  /// Actively capturing audio. / 正在采集音频。
  recording,

  /// Recording is paused and can be resumed. / 录音已暂停，可恢复。
  paused,

  /// Recording finished and the file is finalized. / 录音已结束，文件已完成写入。
  stopped,

  /// An unrecoverable error occurred; see the error stream for details.
  /// 发生不可恢复的错误；详情见错误流。
  error,
}
