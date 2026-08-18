import AVFoundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import AudioToolbox
  import FlutterMacOS
#endif

/// One microphone recording instance backed by `AVAudioEngine`.
///
/// A tap on the input node yields PCM buffers; the peak amplitude (dBFS)
/// is computed from them, and the (optionally sample-rate-converted)
/// audio is written to disk through `AVAudioFile` — WAV (Linear PCM) or
/// AAC-LC (`.m4a`). Amplitude and state events are pushed to Dart through
/// `xue_hua_audio/recorder_events_<id>`.
///
/// 基于 `AVAudioEngine` 的单个麦克风录音实例。
///
/// 输入节点上的 tap 产出 PCM buffer；从中计算峰值振幅（dBFS），并将
/// （必要时经采样率转换的）音频通过 `AVAudioFile` 写盘——支持 WAV
/// （线性 PCM）与 AAC-LC（`.m4a`）。振幅与状态事件经
/// `xue_hua_audio/recorder_events_<id>` 推送给 Dart。
final class RecorderInstance {
  private let events: EventStream

  private var engine: AVAudioEngine?
  private var file: AVAudioFile?
  private var converter: AVAudioConverter?
  private var fileFormat: AVAudioFormat?

  private var paused = false
  private var outputPath: String?
  private var maxDb: Double = -160
  private var lastEmit = DispatchTime.now()
  private var amplitudeInterval: Double = 0.1

  /// Instance-level preferred input device id, `nil` = system default.
  /// 实例级偏好的输入设备 id；`nil` 表示系统默认设备。
  private var preferredInputDeviceId: String?

  /// Creates the recorder and its event channel.
  /// 创建录音机及其事件通道。
  ///
  /// - Parameters:
  ///   - messenger: Engine messenger for the event channel. / 事件通道使用的引擎信使。
  ///   - id: This recorder's id. / 本录音机的 id。
  init(messenger: FlutterBinaryMessenger, id: Int64) {
    events = EventStream(messenger: messenger, name: "xue_hua_audio/recorder_events_\(id)")
  }

  private func emitState(_ state: String) {
    events.send(["type": "state", "state": state])
  }

  /// Starts capturing with `config`, writing to `path`; `callback` resolves
  /// once capture is running.
  ///
  /// 按 `config` 开始采集并写入 `path`；采集启动后 `callback` 完成。
  func start(
    config: RecordConfigMessage, path: String, callback: @escaping (Result<Void, Error>) -> Void
  ) {
    guard engine == nil else {
      callback(
        .failure(
          PigeonError(code: "invalidState", message: "Recorder is already recording", details: nil))
      )
      return
    }
    guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
      callback(
        .failure(
          PigeonError(
            code: "permissionDenied", message: "Microphone permission not granted", details: nil)))
      return
    }

    let settings: [String: Any]
    switch config.encoder {
    case .wav:
      settings = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: Double(config.sampleRate),
        AVNumberOfChannelsKey: Int(config.numChannels),
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ]
    case .aacLc:
      settings = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: Double(config.sampleRate),
        AVNumberOfChannelsKey: Int(config.numChannels),
        AVEncoderBitRateKey: Int(config.bitRate),
      ]
    case .opus:
      callback(
        .failure(
          PigeonError(
            code: "unsupportedEncoder", message: "Opus is not supported on iOS/macOS",
            details: nil)))
      return
    }

    // The per-start config id wins over the instance-level preference.
    // start 时传入的设备 id 优先于实例级偏好。
    let wantedDeviceId = config.deviceId ?? preferredInputDeviceId

    #if os(iOS)
      do {
        try AudioSessionManager.activateRecording(preferredInputUid: wantedDeviceId)
      } catch {
        callback(
          .failure(
            PigeonError(
              code: "recordingFailed",
              message: "Audio session error: \(error.localizedDescription)", details: nil)))
        return
      }
    #endif

    let engine = AVAudioEngine()
    let input = engine.inputNode

    #if os(macOS)
      // Bind the input unit to the requested capture device before reading
      // its format. / 在读取格式前，将输入单元绑定到指定采集设备。
      if let wantedDeviceId {
        do {
          try Self.bindInputDevice(of: engine, toUid: wantedDeviceId)
        } catch {
          callback(.failure(error))
          return
        }
      }
    #endif

    let inputFormat = input.outputFormat(forBus: 0)
    guard inputFormat.sampleRate > 0 else {
      callback(
        .failure(
          PigeonError(code: "recordingFailed", message: "No audio input available", details: nil)))
      return
    }

    let url = URL(fileURLWithPath: path)
    let file: AVAudioFile
    do {
      file = try AVAudioFile(forWriting: url, settings: settings)
    } catch {
      callback(
        .failure(
          PigeonError(
            code: "recordingFailed", message: "Cannot open output: \(error.localizedDescription)",
            details: nil)))
      return
    }

    // Convert from the hardware format to the file's processing format when
    // they differ (sample rate / channel count).
    // 当硬件格式与文件处理格式不一致（采样率/声道数）时进行转换。
    let processingFormat = file.processingFormat
    let converter: AVAudioConverter? =
      inputFormat == processingFormat
      ? nil : AVAudioConverter(from: inputFormat, to: processingFormat)

    self.engine = engine
    self.file = file
    self.converter = converter
    self.fileFormat = processingFormat
    self.outputPath = path
    self.paused = false
    self.maxDb = -160
    self.amplitudeInterval = Double(config.amplitudeIntervalMs) / 1000.0
    self.lastEmit = DispatchTime.now()

    input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
      [weak self] buffer, _ in
      self?.handleBuffer(buffer)
    }

    do {
      engine.prepare()
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      self.cleanup()
      callback(
        .failure(
          PigeonError(
            code: "recordingFailed",
            message: "Cannot start audio engine: \(error.localizedDescription)", details: nil)))
      return
    }

    emitState("recording")
    callback(.success(()))
  }

  private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
    if paused { return }

    // Peak amplitude in dBFS from float samples (-1…1).
    // 由浮点采样（-1…1）计算峰值振幅（dBFS）。
    var peak: Float = 0
    if let channels = buffer.floatChannelData {
      let frameCount = Int(buffer.frameLength)
      for channel in 0..<Int(buffer.format.channelCount) {
        let samples = channels[channel]
        for i in 0..<frameCount {
          peak = max(peak, abs(samples[i]))
        }
      }
    }
    let db = peak > 0 ? Double(20 * log10(peak)) : -160.0

    let now = DispatchTime.now()
    let elapsed = Double(now.uptimeNanoseconds - lastEmit.uptimeNanoseconds) / 1_000_000_000
    if elapsed >= amplitudeInterval {
      lastEmit = now
      maxDb = max(maxDb, db)
      let currentMax = maxDb
      DispatchQueue.main.async { [weak self] in
        self?.events.send(["type": "amplitude", "current": db, "max": currentMax])
      }
    }

    guard let file else { return }
    do {
      if let converter, let fileFormat {
        let ratio = fileFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard
          let converted = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: capacity)
        else { return }
        var consumed = false
        var conversionError: NSError?
        converter.convert(to: converted, error: &conversionError) { _, status in
          if consumed {
            status.pointee = .noDataNow
            return nil
          }
          consumed = true
          status.pointee = .haveData
          return buffer
        }
        if conversionError == nil, converted.frameLength > 0 {
          try file.write(from: converted)
        }
      } else {
        try file.write(from: buffer)
      }
    } catch {
      DispatchQueue.main.async { [weak self] in
        self?.events.send([
          "type": "error", "code": "recordingFailed",
          "message": "Write failed: \(error.localizedDescription)", "details": nil,
        ])
        self?.emitState("error")
        self?.stopEngine()
      }
    }
  }

  #if os(macOS)
    /// Points the engine's input unit at the capture device with `uid`.
    /// 将引擎的输入单元指向 UID 为 `uid` 的采集设备。
    private static func bindInputDevice(of engine: AVAudioEngine, toUid uid: String) throws {
      guard let device = CoreAudioDevices.device(forUid: uid, input: true) else {
        throw PigeonError(
          code: "deviceNotFound", message: "No input device with uid \(uid)", details: nil)
      }
      guard let unit = engine.inputNode.audioUnit else {
        throw PigeonError(
          code: "recordingFailed", message: "Input audio unit unavailable", details: nil)
      }
      var deviceId = device.id
      let status = AudioUnitSetProperty(
        unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
        &deviceId, UInt32(MemoryLayout<AudioDeviceID>.size))
      guard status == noErr else {
        throw PigeonError(
          code: "recordingFailed", message: "Cannot select input device (OSStatus \(status))",
          details: nil)
      }
    }
  #endif

  /// Selects the input device `deviceId` (`nil` = system default).
  ///
  /// On iOS this applies immediately (also while recording) through
  /// `AVAudioSession.setPreferredInput`; on macOS it applies at the next
  /// `start` — switching mid-recording throws `invalidState`.
  ///
  /// 选择输入设备 `deviceId`（`nil` 使用系统默认）。
  ///
  /// iOS 端通过 `AVAudioSession.setPreferredInput` 立即生效（录音中亦可）；
  /// macOS 端在下一次 `start` 时生效，录音中切换会抛出 `invalidState`。
  func setInputDevice(deviceId: String?) throws {
    #if os(macOS)
      guard engine == nil else {
        throw PigeonError(
          code: "invalidState",
          message: "Cannot switch the input device while recording on macOS", details: nil)
      }
      if let deviceId, CoreAudioDevices.device(forUid: deviceId, input: true) == nil {
        throw PigeonError(
          code: "deviceNotFound", message: "No input device with uid \(deviceId)", details: nil)
      }
      preferredInputDeviceId = deviceId
    #else
      let session = AVAudioSession.sharedInstance()
      if let deviceId {
        guard let input = session.availableInputs?.first(where: { $0.uid == deviceId }) else {
          throw PigeonError(
            code: "deviceNotFound", message: "No input device with uid \(deviceId)", details: nil)
        }
        if engine != nil {
          try? session.setPreferredInput(input)
        }
      } else if engine != nil {
        try? session.setPreferredInput(nil)
      }
      preferredInputDeviceId = deviceId
    #endif
  }

  /// The id of the input device in use: the routed device while recording on
  /// iOS, otherwise the stored preference (`nil` = system default).
  /// 当前使用的输入设备 id：iOS 录音中返回实际路由设备，否则返回已存偏好
  /// （`nil` 表示系统默认）。
  func currentInputDeviceId() -> String? {
    #if os(iOS)
      if engine != nil,
        let port = AVAudioSession.sharedInstance().currentRoute.inputs.first
      {
        return port.uid
      }
    #endif
    return preferredInputDeviceId
  }

  /// Pauses capture. / 暂停采集。
  func pause() {
    guard engine != nil, !paused else { return }
    paused = true
    emitState("paused")
  }

  /// Resumes capture. / 恢复采集。
  func resume() {
    guard engine != nil, paused else { return }
    paused = false
    emitState("recording")
  }

  /// Stops recording; `callback` resolves with the file path or nil.
  /// 停止录音；`callback` 返回文件路径，未录音时返回 nil。
  func stop(callback: @escaping (Result<String?, Error>) -> Void) {
    let path = outputPath
    stopEngine()
    if path != nil { emitState("stopped") }
    callback(.success(path))
  }

  /// Stops recording and deletes the file. / 停止录音并删除文件。
  func cancel(callback: @escaping (Result<Void, Error>) -> Void) {
    let path = outputPath
    stopEngine()
    if let path {
      try? FileManager.default.removeItem(atPath: path)
    }
    emitState("stopped")
    callback(.success(()))
  }

  /// Releases everything. / 释放全部资源。
  func dispose() {
    stopEngine()
    events.dispose()
  }

  private func stopEngine() {
    if let engine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
    }
    cleanup()
  }

  private func cleanup() {
    engine = nil
    // AVAudioFile finalizes the container when released.
    // AVAudioFile 在释放时完成文件收尾。
    file = nil
    converter = nil
    fileFormat = nil
  }
}
