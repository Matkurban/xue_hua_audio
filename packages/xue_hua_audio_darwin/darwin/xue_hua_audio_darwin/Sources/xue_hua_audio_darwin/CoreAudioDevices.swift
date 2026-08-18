#if os(macOS)
  import CoreAudio
  import Foundation

  /// CoreAudio HAL helpers to enumerate audio devices on macOS.
  /// macOS 上基于 CoreAudio HAL 的音频设备枚举工具。
  enum CoreAudioDevices {
    /// One hardware audio device. / 一个硬件音频设备。
    struct Device {
      /// HAL object id (session-scoped). / HAL 对象 id（仅本次会话有效）。
      let id: AudioDeviceID
      /// Persistent unique identifier. / 持久的唯一标识。
      let uid: String
      /// Human-readable name. / 供人阅读的名称。
      let name: String
    }

    // Element 0 == kAudioObjectPropertyElementMain (macOS 12+) ==
    // kAudioObjectPropertyElementMaster (deprecated); use the raw value to
    // support the 10.15 deployment target without warnings.
    // 元素 0 即 Main/Master；直接用原始值以兼容 10.15 部署目标且无弃用告警。
    private static let elementMain: AudioObjectPropertyElement = 0

    /// Lists devices that have at least one stream in the wanted direction.
    /// 列出在指定方向上至少有一路音频流的设备。
    ///
    /// - Parameter input: `true` for capture devices, `false` for playback
    ///   devices. / `true` 为输入设备，`false` 为输出设备。
    static func devices(input: Bool) -> [Device] {
      allDeviceIDs().compactMap { id in
        guard streamCount(id, input: input) > 0,
          let uid = stringProperty(id, selector: kAudioDevicePropertyDeviceUID)
        else { return nil }
        let name =
          stringProperty(id, selector: kAudioObjectPropertyName) ?? "Device \(id)"
        return Device(id: id, uid: uid, name: name)
      }
    }

    /// Finds a device by its persistent UID. / 按持久 UID 查找设备。
    static func device(forUid uid: String, input: Bool) -> Device? {
      devices(input: input).first { $0.uid == uid }
    }

    /// Finds a device by its HAL id. / 按 HAL id 查找设备。
    static func device(forId deviceId: AudioDeviceID, input: Bool) -> Device? {
      devices(input: input).first { $0.id == deviceId }
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: elementMain)
      var size: UInt32 = 0
      let system = AudioObjectID(kAudioObjectSystemObject)
      guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
        size > 0
      else { return [] }
      var ids = [AudioDeviceID](
        repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
      guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr
      else { return [] }
      return ids
    }

    private static func streamCount(_ id: AudioDeviceID, input: Bool) -> Int {
      var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: input
          ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
        mElement: elementMain)
      var size: UInt32 = 0
      guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr
      else { return 0 }
      return Int(size) / MemoryLayout<AudioStreamID>.size
    }

    private static func stringProperty(
      _ id: AudioDeviceID, selector: AudioObjectPropertySelector
    ) -> String? {
      var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: elementMain)
      var size = UInt32(MemoryLayout<CFString?>.size)
      var value: CFString?
      let status = withUnsafeMutablePointer(to: &value) { pointer in
        AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
      }
      guard status == noErr, let value else { return nil }
      return value as String
    }
  }
#endif
