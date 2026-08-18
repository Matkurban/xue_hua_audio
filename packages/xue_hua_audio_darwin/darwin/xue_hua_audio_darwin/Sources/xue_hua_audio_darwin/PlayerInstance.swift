import AVFoundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

/// One playback instance backed by `AVPlayer`.
///
/// Pushes `state` / `duration` / `error` events to Dart through its own
/// event channel (`xue_hua_audio/player_events_<id>`); the position is
/// polled from Dart instead.
///
/// 基于 `AVPlayer` 的单个播放实例。
///
/// 通过独立事件通道（`xue_hua_audio/player_events_<id>`）向 Dart 推送
/// `state` / `duration` / `error` 事件；播放位置由 Dart 侧轮询获取。
final class PlayerInstance: NSObject {
  private let events: EventStream
  private let player = AVPlayer()

  private var pendingLoad: ((Result<Int64?, Error>) -> Void)?
  private var statusObservation: NSKeyValueObservation?
  private var timeControlObservation: NSKeyValueObservation?
  private var endObserver: NSObjectProtocol?

  private var looping = false
  private var speed: Double = 1.0
  private var startedOnce = false
  private var stoppedByUser = false
  private var lastState: String?

  /// Creates the player and its event channel.
  /// 创建播放器及其事件通道。
  ///
  /// - Parameters:
  ///   - messenger: Engine messenger for the event channel. / 事件通道使用的引擎信使。
  ///   - id: This player's id. / 本播放器的 id。
  init(messenger: FlutterBinaryMessenger, id: Int64) {
    events = EventStream(messenger: messenger, name: "xue_hua_audio/player_events_\(id)")
    super.init()

    timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) {
      [weak self] player, _ in
      DispatchQueue.main.async { self?.onTimeControlChanged() }
    }
  }

  private func onTimeControlChanged() {
    switch player.timeControlStatus {
    case .playing:
      startedOnce = true
      emitState("playing")
    case .waitingToPlayAtSpecifiedRate:
      emitState("loading")
    case .paused:
      // Ignore the transient pause while a source is still loading.
      // 忽略音频源仍在加载时的瞬时暂停。
      guard pendingLoad == nil, player.currentItem != nil else { return }
      if stoppedByUser {
        emitState("stopped")
      } else if startedOnce {
        if lastState != "completed" {
          emitState("paused")
        }
      }
    @unknown default:
      break
    }
  }

  private func emitState(_ state: String) {
    guard state != lastState else { return }
    lastState = state
    events.send(["type": "state", "state": state])
  }

  private static func durationMs(of item: AVPlayerItem) -> Int64? {
    let duration = item.duration
    guard duration.isNumeric else { return nil }
    return Int64(duration.seconds * 1000.0)
  }

  /// Loads a source; `callback` resolves with the duration in milliseconds
  /// (or nil) once the item is ready to play.
  ///
  /// 加载音频源；条目就绪后 `callback` 返回时长（毫秒，未知为 nil）。
  ///
  /// - Parameters:
  ///   - url: The resolved media URL. / 已解析的媒体 URL。
  ///   - headers: Optional HTTP headers. / 可选的 HTTP 请求头。
  ///   - callback: Completion resolving to the duration. / 返回时长的回调。
  func setSource(
    url: URL, headers: [String: String]?, callback: @escaping (Result<Int64?, Error>) -> Void
  ) {
    pendingLoad?(
      .failure(
        PigeonError(
          code: "sourceLoadFailed", message: "Replaced by a newer setSource call", details: nil)))
    pendingLoad = callback
    startedOnce = false
    stoppedByUser = false
    lastState = nil
    emitState("loading")

    var options: [String: Any] = [:]
    if let headers, !headers.isEmpty {
      options["AVURLAssetHTTPHeaderFieldsKey"] = headers
    }
    let asset = AVURLAsset(url: url, options: options)
    let item = AVPlayerItem(asset: asset)

    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      DispatchQueue.main.async { self?.onItemStatusChanged(item) }
    }
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { [weak self] _ in
      self?.onPlayedToEnd()
    }
    player.replaceCurrentItem(with: item)
  }

  private func onItemStatusChanged(_ item: AVPlayerItem) {
    switch item.status {
    case .readyToPlay:
      guard let load = pendingLoad else { return }
      pendingLoad = nil
      let ms = Self.durationMs(of: item)
      events.send(["type": "duration", "durationMs": ms])
      emitState("ready")
      load(.success(ms))
    case .failed:
      let message = item.error?.localizedDescription ?? "Failed to load source"
      if let load = pendingLoad {
        pendingLoad = nil
        load(.failure(PigeonError(code: "sourceLoadFailed", message: message, details: nil)))
      } else {
        events.send([
          "type": "error", "code": "playbackFailed", "message": message, "details": nil,
        ])
        emitState("error")
      }
    default:
      break
    }
  }

  private func onPlayedToEnd() {
    if looping {
      player.seek(to: .zero)
      player.rate = Float(speed)
      return
    }
    emitState("completed")
  }

  /// Starts/resumes playback at the configured speed. / 按设定速度开始或恢复播放。
  func play() {
    stoppedByUser = false
    #if os(iOS)
      AudioSessionManager.activatePlayback()
    #endif
    if lastState == "completed" {
      lastState = nil
      player.seek(to: .zero)
    }
    player.rate = Float(speed)
  }

  /// Pauses playback. / 暂停播放。
  func pause() {
    player.pause()
  }

  /// Stops playback and rewinds. / 停止播放并回到起点。
  func stop() {
    stoppedByUser = true
    player.pause()
    player.seek(to: .zero)
    emitState("stopped")
  }

  /// Seeks to `positionMs`, reporting completion via `callback`.
  /// 跳转到 `positionMs`，完成后通过 `callback` 通知。
  func seekTo(positionMs: Int64, callback: @escaping (Result<Void, Error>) -> Void) {
    let time = CMTime(value: positionMs, timescale: 1000)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
      callback(.success(()))
    }
    if lastState == "completed" {
      lastState = nil
      emitState("ready")
    }
  }

  /// Sets volume 0.0–1.0. / 设置音量（0.0～1.0）。
  func setVolume(_ volume: Double) {
    player.volume = Float(min(max(volume, 0), 1))
  }

  /// Sets playback speed. / 设置播放速度。
  func setSpeed(_ speed: Double) {
    self.speed = speed
    if player.timeControlStatus == .playing {
      player.rate = Float(speed)
    }
  }

  /// Enables/disables looping. / 开启或关闭循环。
  func setLooping(_ looping: Bool) {
    self.looping = looping
  }

  #if os(macOS)
    /// UID of the output device this player is routed to, `nil` = default.
    /// 本播放器路由到的输出设备 UID；`nil` 表示系统默认。
    private(set) var outputDeviceUid: String?

    /// Routes this player to the output device with `uid` (`nil` restores
    /// the system default). Takes effect immediately, also mid-playback.
    /// 将本播放器路由到 UID 为 `uid` 的输出设备（`nil` 恢复系统默认）。
    /// 立即生效，播放中亦可切换。
    func setOutputDevice(uid: String?) throws {
      if let uid {
        guard CoreAudioDevices.device(forUid: uid, input: false) != nil else {
          throw PigeonError(
            code: "deviceNotFound", message: "No output device with uid \(uid)",
            details: nil)
        }
      }
      player.audioOutputDeviceUniqueID = uid
      outputDeviceUid = uid
    }
  #endif

  /// Current position in ms. / 当前位置（毫秒）。
  func position() -> Int64 {
    let time = player.currentTime()
    guard time.isNumeric else { return 0 }
    return Int64(time.seconds * 1000.0)
  }

  /// Duration in ms or nil. / 时长（毫秒），未知为 nil。
  func duration() -> Int64? {
    guard let item = player.currentItem else { return nil }
    return Self.durationMs(of: item)
  }

  /// Releases the AVPlayer and the event channel. / 释放 AVPlayer 与事件通道。
  func dispose() {
    statusObservation?.invalidate()
    timeControlObservation?.invalidate()
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    player.replaceCurrentItem(with: nil)
    events.dispose()
  }
}
