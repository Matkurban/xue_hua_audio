package com.xuehua.xue_hua_audio_android

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/**
 * A small wrapper around [EventChannel] that buffers events emitted before
 * the Dart side has subscribed, so no early state change is lost.
 *
 * 对 [EventChannel] 的轻量封装：在 Dart 端尚未订阅前缓冲事件，
 * 避免早期状态变更丢失。
 *
 * @param messenger The engine binary messenger. / 引擎二进制信使。
 * @param name The fully qualified channel name. / 完整的通道名称。
 */
class EventStream(messenger: BinaryMessenger, name: String) :
    EventChannel.StreamHandler {

  private val channel = EventChannel(messenger, name)
  private var sink: EventChannel.EventSink? = null
  private val pending = ArrayDeque<Map<String, Any?>>()

  init {
    channel.setStreamHandler(this)
  }

  /**
   * Sends [event] to Dart, buffering it when nobody listens yet.
   * Must be called on the main thread.
   *
   * 将 [event] 发送给 Dart；若尚无订阅者则先缓冲。必须在主线程调用。
   *
   * @param event The event payload map. / 事件负载 Map。
   */
  fun send(event: Map<String, Any?>) {
    val currentSink = sink
    if (currentSink != null) {
      currentSink.success(event)
    } else if (pending.size < 128) {
      pending.addLast(event)
    }
  }

  /** Tears the channel down. / 关闭通道。 */
  fun dispose() {
    sink?.endOfStream()
    sink = null
    channel.setStreamHandler(null)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    sink = events
    while (pending.isNotEmpty()) {
      events.success(pending.removeFirst())
    }
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }
}
