#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

/// A small wrapper around `FlutterEventChannel` that buffers events emitted
/// before the Dart side has subscribed, so no early state change is lost.
///
/// 对 `FlutterEventChannel` 的轻量封装：在 Dart 端尚未订阅前缓冲事件，
/// 避免早期状态变更丢失。
final class EventStream: NSObject, FlutterStreamHandler {
  private let channel: FlutterEventChannel
  private var sink: FlutterEventSink?
  private var pending: [[String: Any?]] = []

  /// Creates the stream on channel [name].
  /// 在名为 [name] 的通道上创建事件流。
  ///
  /// - Parameters:
  ///   - messenger: The engine binary messenger. / 引擎二进制信使。
  ///   - name: The fully qualified channel name. / 完整的通道名称。
  init(messenger: FlutterBinaryMessenger, name: String) {
    channel = FlutterEventChannel(name: name, binaryMessenger: messenger)
    super.init()
    channel.setStreamHandler(self)
  }

  /// Sends [event] to Dart, buffering it when nobody listens yet.
  /// Must be called on the main thread.
  ///
  /// 将 [event] 发送给 Dart；若尚无订阅者则先缓冲。必须在主线程调用。
  func send(_ event: [String: Any?]) {
    if let sink {
      sink(event)
    } else if pending.count < 128 {
      pending.append(event)
    }
  }

  /// Tears the channel down. / 关闭通道。
  func dispose() {
    sink?(FlutterEndOfEventStream)
    sink = nil
    channel.setStreamHandler(nil)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    for event in pending {
      events(event)
    }
    pending.removeAll()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
