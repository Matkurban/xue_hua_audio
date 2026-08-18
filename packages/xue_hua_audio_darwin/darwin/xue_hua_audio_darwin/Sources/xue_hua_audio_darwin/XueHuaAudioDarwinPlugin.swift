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
/// iOS/macOS 实现入口：注册 Pigeon Host API，并管理播放器、录音机、
/// 权限与 Asset 资源解析。
public class XueHuaAudioDarwinPlugin: NSObject, FlutterPlugin, AudioPlayerHostApi,
  AudioRecorderHostApi
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

  func setSource(
    playerId: Int64, source: AudioSourceMessage,
    completion: @escaping (Result<Int64?, Error>) -> Void
  ) {
    do {
      let player = try playerOf(playerId)
      let url = try resolveUrl(source)
      player.setSource(url: url, headers: source.headers, callback: completion)
    } catch {
      completion(.failure(error))
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

  func seekTo(
    playerId: Int64, positionMs: Int64, completion: @escaping (Result<Void, Error>) -> Void
  ) {
    do {
      try playerOf(playerId).seekTo(positionMs: positionMs, callback: completion)
    } catch {
      completion(.failure(error))
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

  func listOutputDevices(
    completion: @escaping (Result<[AudioDeviceMessage], Error>) -> Void
  ) {
    #if os(macOS)
      completion(
        .success(
          CoreAudioDevices.devices(input: false).map {
            AudioDeviceMessage(id: $0.uid, label: $0.name)
          }))
    #else
      // iOS cannot enumerate every output; report the current route only.
      // iOS 无法枚举全部输出设备，只能返回当前音频路由中的设备。
      let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
      completion(
        .success(outputs.map { AudioDeviceMessage(id: $0.uid, label: $0.portName) }))
    #endif
  }

  func getOutputDevice(
    playerId: Int64, completion: @escaping (Result<AudioDeviceMessage?, Error>) -> Void
  ) {
    do {
      let player = try playerOf(playerId)
      #if os(macOS)
        guard let uid = player.outputDeviceUid,
          let device = CoreAudioDevices.device(forUid: uid, input: false)
        else {
          completion(.success(nil))
          return
        }
        completion(.success(AudioDeviceMessage(id: device.uid, label: device.name)))
      #else
        // Playback always follows the system route on iOS; report the
        // route's first output for information.
        // iOS 播放始终跟随系统路由；返回路由中的第一个输出设备以供参考。
        _ = player
        let output = AVAudioSession.sharedInstance().currentRoute.outputs.first
        completion(
          .success(output.map { AudioDeviceMessage(id: $0.uid, label: $0.portName) }))
      #endif
    } catch {
      completion(.failure(error))
    }
  }

  func setOutputDevice(
    playerId: Int64, deviceId: String?, completion: @escaping (Result<Void, Error>) -> Void
  ) {
    do {
      let player = try playerOf(playerId)
      #if os(macOS)
        try player.setOutputDevice(uid: deviceId)
        completion(.success(()))
      #else
        _ = player
        _ = deviceId
        completion(
          .failure(
            PigeonError(
              code: "unsupported",
              message: "iOS does not allow apps to route playback to a specific output device",
              details: nil)))
      #endif
    } catch {
      completion(.failure(error))
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

  func hasPermission(completion: @escaping (Result<Bool, Error>) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      completion(.success(true))
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async { completion(.success(granted)) }
      }
    default:
      completion(.success(false))
    }
  }

  func listInputDevices(completion: @escaping (Result<[AudioDeviceMessage], Error>) -> Void) {
    #if os(iOS)
      let inputs = AVAudioSession.sharedInstance().availableInputs ?? []
      completion(
        .success(inputs.map { AudioDeviceMessage(id: $0.uid, label: $0.portName) }))
    #else
      completion(
        .success(
          CoreAudioDevices.devices(input: true).map {
            AudioDeviceMessage(id: $0.uid, label: $0.name)
          }))
    #endif
  }

  func getInputDevice(
    recorderId: Int64, completion: @escaping (Result<AudioDeviceMessage?, Error>) -> Void
  ) {
    do {
      guard let deviceId = try recorderOf(recorderId).currentInputDeviceId() else {
        completion(.success(nil))
        return
      }
      #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let port =
          session.currentRoute.inputs.first(where: { $0.uid == deviceId })
          ?? session.availableInputs?.first(where: { $0.uid == deviceId })
        completion(
          .success(
            AudioDeviceMessage(id: deviceId, label: port?.portName ?? deviceId)))
      #else
        let device = CoreAudioDevices.device(forUid: deviceId, input: true)
        completion(
          .success(
            AudioDeviceMessage(id: deviceId, label: device?.name ?? deviceId)))
      #endif
    } catch {
      completion(.failure(error))
    }
  }

  func setInputDevice(
    recorderId: Int64, deviceId: String?, completion: @escaping (Result<Void, Error>) -> Void
  ) {
    do {
      try recorderOf(recorderId).setInputDevice(deviceId: deviceId)
      completion(.success(()))
    } catch {
      completion(.failure(error))
    }
  }

  func start(
    recorderId: Int64, config: RecordConfigMessage, path: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    do {
      try recorderOf(recorderId).start(config: config, path: path, callback: completion)
    } catch {
      completion(.failure(error))
    }
  }

  func pause(recorderId: Int64) throws {
    try recorderOf(recorderId).pause()
  }

  func resume(recorderId: Int64) throws {
    try recorderOf(recorderId).resume()
  }

  func stop(recorderId: Int64, completion: @escaping (Result<String?, Error>) -> Void) {
    do {
      try recorderOf(recorderId).stop(callback: completion)
    } catch {
      completion(.failure(error))
    }
  }

  func cancel(recorderId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
    do {
      try recorderOf(recorderId).cancel(callback: completion)
    } catch {
      completion(.failure(error))
    }
  }

  func disposeRecorder(recorderId: Int64) throws {
    recorders.removeValue(forKey: recorderId)?.dispose()
  }
}
