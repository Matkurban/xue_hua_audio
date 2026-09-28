import AVFoundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

#if os(iOS)
  /// Configures the shared `AVAudioSession` for playback or recording (iOS
  /// only; macOS has no audio session).
  ///
  /// 为播放或录音配置共享的 `AVAudioSession`（仅 iOS；macOS 无音频会话）。
  enum AudioSessionManager {
    /// Ensures a playback-capable session. Recording sessions are left
    /// untouched so playback can mix with an active recording.
    /// 确保会话可用于播放；已处于录音会话时保持不变，以便边录边播。
    static func activatePlayback() {
      let session = AVAudioSession.sharedInstance()
      if session.category != .playback && session.category != .playAndRecord {
        try? session.setCategory(.playback, mode: .default)
      }
      try? session.setActive(true)
    }

    /// Switches to a play-and-record session, optionally selecting the
    /// preferred input by its UID.
    /// 切换到可同时播放与录音的会话，并可按 UID 选择首选输入设备。
    ///
    /// - Parameter preferredInputUid: The UID of the wanted input, `nil`
    ///   keeps the default. / 期望输入设备的 UID；`nil` 使用默认设备。
    static func activateRecording(preferredInputUid: String?) throws {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      if let uid = preferredInputUid,
        let input = session.availableInputs?.first(where: { $0.uid == uid })
      {
        try? session.setPreferredInput(input)
      }
      try session.setActive(true)
    }
  }
#endif

/// Entry point of the iOS/macOS implementation: registers the Pigeon host
/// APIs and manages players, recorders, permissions and asset resolution.
///
/// Mutable state stays on the main thread, so the class is
/// `@unchecked Sendable` for the main-queue hops in the async host APIs.
///
/// iOS/macOS 实现入口：注册 Pigeon Host API，并管理播放器、录音机、
/// 权限与 Asset 资源解析。可变状态只在主线程访问，因此类标记为
/// `@unchecked Sendable`，供异步 Host API 切回主队列时使用。
public class XueHuaAudioDarwinPlugin: NSObject, FlutterPlugin, AudioPlayerHostApi,
  AudioRecorderHostApi, @unchecked Sendable
{
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(macOS)
      let messenger = registrar.messenger
    #else
      let messenger = registrar.messenger()
    #endif
    let plugin = XueHuaAudioDarwinPlugin(messenger: messenger, registrar: registrar)
    AudioPlayerHostApiSetup.setUp(binaryMessenger: messenger, api: plugin)
    AudioRecorderHostApiSetup.setUp(binaryMessenger: messenger, api: plugin)
  }

  private let messenger: FlutterBinaryMessenger
  private let registrar: FlutterPluginRegistrar

  private var players: [Int64: PlayerInstance] = [:]
  private var recorders: [Int64: RecorderInstance] = [:]
  private var nextPlayerId: Int64 = 1
  private var nextRecorderId: Int64 = 1

  init(messenger: FlutterBinaryMessenger, registrar: FlutterPluginRegistrar) {
    self.messenger = messenger
    self.registrar = registrar
  }

  /// Resolves an `AudioSourceMessage` into a playable URL.
  /// 将 `AudioSourceMessage` 解析为可播放的 URL。
  private func resolveUrl(_ source: AudioSourceMessage) throws -> URL {
    switch source.type {
    case .file:
      return URL(fileURLWithPath: source.uri)
    case .url:
      guard let url = URL(string: source.uri) else {
        throw PigeonError(
          code: "sourceLoadFailed", message: "Invalid URL: \(source.uri)", details: nil)
      }
      return url
    case .asset:
      // `lookupKey` returns a path relative to the app bundle root
      // (on macOS it points inside App.framework), so join it with
      // `bundlePath` instead of using `Bundle.path(forResource:)`, which
      // only searches Contents/Resources on macOS.
      // `lookupKey` 返回的是相对 app bundle 根目录的路径（macOS 上位于
      // App.framework 内），因此直接与 `bundlePath` 拼接；
      // `Bundle.path(forResource:)` 在 macOS 上只搜索 Contents/Resources，
      // 会找不到资源。
      let key = registrar.lookupKey(forAsset: source.uri)
      let path = (Bundle.main.bundlePath as NSString).appendingPathComponent(key)
      guard FileManager.default.fileExists(atPath: path) else {
        throw PigeonError(
          code: "sourceLoadFailed", message: "Asset not found: \(source.uri)", details: nil)
      }
      return URL(fileURLWithPath: path)
    }
  }

  // MARK: - AudioPlayerHostApi

  /// Runs [body] on the main queue. Pigeon calls async host APIs from a
  /// `@MainActor` task, but a nonisolated `async` method can hop off the main
  /// thread. AVFoundation and the instance maps stay on the main thread.
  ///
  /// 在主队列执行 [body]。Pigeon 从 `@MainActor` 任务调用异步 Host API，
  /// 但 nonisolated 的 `async` 方法可能离开主线程。AVFoundation 与实例表留在主线程。
  private func performOnMain<T>(_ body: @escaping () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        continuation.resume(with: Result { try body() })
      }
    }
  }

  private func playerOf(_ id: Int64) throws -> PlayerInstance {
    guard let player = players[id] else {
      throw PigeonError(code: "instanceNotFound", message: "No player with id \(id)", details: nil)
    }
    return player
  }

  func createPlayer() throws -> Int64 {
    let id = nextPlayerId
    nextPlayerId += 1
    players[id] = PlayerInstance(messenger: messenger, id: id)
    return id
  }

  func setSource(playerId: Int64, source: AudioSourceMessage) async throws -> Int64? {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          let player = try self.playerOf(playerId)
          let url = try self.resolveUrl(source)
          player.setSource(url: url, headers: source.headers) { result in
            continuation.resume(with: result)
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func play(playerId: Int64) throws {
    try playerOf(playerId).play()
  }

  func pause(playerId: Int64) throws {
    try playerOf(playerId).pause()
  }

  func stop(playerId: Int64) throws {
    try playerOf(playerId).stop()
  }

  func seekTo(playerId: Int64, positionMs: Int64) async throws {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          try self.playerOf(playerId).seekTo(positionMs: positionMs) { result in
            continuation.resume(with: result)
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func setVolume(playerId: Int64, volume: Double) throws {
    try playerOf(playerId).setVolume(volume)
  }

  func setSpeed(playerId: Int64, speed: Double) throws {
    try playerOf(playerId).setSpeed(speed)
  }

  func setLooping(playerId: Int64, looping: Bool) throws {
    try playerOf(playerId).setLooping(looping)
  }

  func getPosition(playerId: Int64) throws -> Int64 {
    return try playerOf(playerId).position()
  }

  func getDuration(playerId: Int64) throws -> Int64? {
    return try playerOf(playerId).duration()
  }

  func listOutputDevices() async throws -> [AudioDeviceMessage] {
    try await performOnMain {
      #if os(macOS)
        return CoreAudioDevices.devices(input: false).map {
          AudioDeviceMessage(id: $0.uid, label: $0.name)
        }
      #else
        // iOS cannot enumerate every output; report the current route only.
        // iOS 无法枚举全部输出设备，只能返回当前音频路由中的设备。
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.map { AudioDeviceMessage(id: $0.uid, label: $0.portName) }
      #endif
    }
  }

  func getOutputDevice(playerId: Int64) async throws -> AudioDeviceMessage? {
    try await performOnMain {
      let player = try self.playerOf(playerId)
      #if os(macOS)
        guard let uid = player.outputDeviceUid,
          let device = CoreAudioDevices.device(forUid: uid, input: false)
        else {
          return nil
        }
        return AudioDeviceMessage(id: device.uid, label: device.name)
      #else
        // Playback always follows the system route on iOS; report the
        // route's first output for information.
        // iOS 播放始终跟随系统路由；返回路由中的第一个输出设备以供参考。
        _ = player
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        return output.map { AudioDeviceMessage(id: $0.uid, label: $0.portName) }
      #endif
    }
  }

  func setOutputDevice(playerId: Int64, deviceId: String?) async throws {
    try await performOnMain {
      let player = try self.playerOf(playerId)
      #if os(macOS)
        try player.setOutputDevice(uid: deviceId)
      #else
        _ = player
        _ = deviceId
        throw PigeonError(
          code: "unsupported",
          message: "iOS does not allow apps to route playback to a specific output device",
          details: nil)
      #endif
    }
  }

  func disposePlayer(playerId: Int64) throws {
    players.removeValue(forKey: playerId)?.dispose()
  }

  // MARK: - AudioRecorderHostApi

  private func recorderOf(_ id: Int64) throws -> RecorderInstance {
    guard let recorder = recorders[id] else {
      throw PigeonError(
        code: "instanceNotFound", message: "No recorder with id \(id)", details: nil)
    }
    return recorder
  }

  func createRecorder() throws -> Int64 {
    let id = nextRecorderId
    nextRecorderId += 1
    recorders[id] = RecorderInstance(messenger: messenger, id: id)
    return id
  }

  func hasPermission() async throws -> Bool {
    let status = try await performOnMain {
      AVCaptureDevice.authorizationStatus(for: .audio)
    }
    switch status {
    case .authorized:
      return true
    case .notDetermined:
      return try await withCheckedThrowingContinuation { continuation in
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          DispatchQueue.main.async {
            continuation.resume(returning: granted)
          }
        }
      }
    default:
      return false
    }
  }

  func listInputDevices() async throws -> [AudioDeviceMessage] {
    try await performOnMain {
      #if os(iOS)
        let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
        return inputs.map { AudioDeviceMessage(id: $0.uid, label: $0.portName) }
      #else
        return CoreAudioDevices.devices(input: true).map {
          AudioDeviceMessage(id: $0.uid, label: $0.name)
        }
      #endif
    }
  }

  func getInputDevice(recorderId: Int64) async throws -> AudioDeviceMessage? {
    try await performOnMain {
      guard let deviceId = try self.recorderOf(recorderId).currentInputDeviceId() else {
        return nil
      }
      #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let port =
          session.currentRoute.inputs.first(where: { $0.uid == deviceId })
          ?? session.availableInputs?.first(where: { $0.uid == deviceId })
        return AudioDeviceMessage(id: deviceId, label: port?.portName ?? deviceId)
      #else
        let device = CoreAudioDevices.device(forUid: deviceId, input: true)
        return AudioDeviceMessage(id: deviceId, label: device?.name ?? deviceId)
      #endif
    }
  }

  func setInputDevice(recorderId: Int64, deviceId: String?) async throws {
    try await performOnMain {
      try self.recorderOf(recorderId).setInputDevice(deviceId: deviceId)
    }
  }

  func start(recorderId: Int64, config: RecordConfigMessage, path: String) async throws {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          try self.recorderOf(recorderId).start(config: config, path: path) { result in
            continuation.resume(with: result)
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func pause(recorderId: Int64) throws {
    try recorderOf(recorderId).pause()
  }

  func resume(recorderId: Int64) throws {
    try recorderOf(recorderId).resume()
  }

  func stop(recorderId: Int64) async throws -> String? {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          try self.recorderOf(recorderId).stop { result in
            continuation.resume(with: result)
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func cancel(recorderId: Int64) async throws {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          try self.recorderOf(recorderId).cancel { result in
            continuation.resume(with: result)
          }
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func disposeRecorder(recorderId: Int64) throws {
    recorders.removeValue(forKey: recorderId)?.dispose()
  }
}
