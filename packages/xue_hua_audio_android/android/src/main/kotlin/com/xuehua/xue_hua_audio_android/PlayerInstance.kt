package com.xuehua.xue_hua_audio_android

import android.content.Context
import android.media.AudioManager
import android.os.Build
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger

/**
 * One playback instance backed by a Media3 [ExoPlayer].
 *
 * Pushes `state` / `duration` / `error` events to Dart through its own
 * event channel (`xue_hua_audio/player_events_<id>`); the position is
 * polled from Dart instead.
 *
 * 基于 Media3 [ExoPlayer] 的单个播放实例。
 *
 * 通过独立事件通道（`xue_hua_audio/player_events_<id>`）向 Dart 推送
 * `state` / `duration` / `error` 事件；播放位置由 Dart 侧轮询获取。
 *
 * @param context Android context used to build the player. / 用于创建播放器的 Android 上下文。
 * @param messenger Engine messenger for the event channel. / 事件通道使用的引擎信使。
 * @param flutterAssets Asset resolver for `asset` sources. / 解析 `asset` 源的资源查找器。
 * @param id This player's id. / 本播放器的 id。
 */
class PlayerInstance(
    private val context: Context,
    messenger: BinaryMessenger,
    private val flutterAssets: FlutterPlugin.FlutterAssets,
    id: Long,
) {
  private val events = EventStream(messenger, "xue_hua_audio/player_events_$id")
  private val player: ExoPlayer = ExoPlayer.Builder(context).build()

  private var pendingLoad: ((Result<Long?>) -> Unit)? = null
  private var startedOnce = false
  private var stoppedByUser = false
  private var lastState: String? = null

  init {
    player.addListener(
        object : Player.Listener {
          override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
              Player.STATE_BUFFERING -> emitState("loading")
              Player.STATE_READY -> onReady()
              Player.STATE_ENDED -> emitState("completed")
              Player.STATE_IDLE -> Unit
            }
          }

          override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
              startedOnce = true
              emitState("playing")
            } else if (player.playbackState == Player.STATE_READY &&
                !player.playWhenReady) {
              emitState(if (stoppedByUser) "stopped" else "paused")
            }
          }

          override fun onPlayerError(error: PlaybackException) {
            val load = pendingLoad
            if (load != null) {
              pendingLoad = null
              load(
                  Result.failure(
                      FlutterError(
                          "sourceLoadFailed",
                          error.message ?: "Failed to load source",
                          error.errorCodeName)))
              return
            }
            events.send(
                mapOf(
                    "type" to "error",
                    "code" to "playbackFailed",
                    "message" to (error.message ?: "Playback failed"),
                    "details" to error.errorCodeName))
            emitState("error")
          }
        })
  }

  private fun onReady() {
    val durationMs =
        if (player.duration == C.TIME_UNSET) null else player.duration
    val load = pendingLoad
    if (load != null) {
      pendingLoad = null
      events.send(mapOf("type" to "duration", "durationMs" to durationMs))
      emitState("ready")
      load(Result.success(durationMs))
      return
    }
    if (!player.playWhenReady && !player.isPlaying) {
      emitState(
          when {
            stoppedByUser -> "stopped"
            startedOnce -> "paused"
            else -> "ready"
          })
    }
  }

  private fun emitState(state: String) {
    if (state == lastState) return
    lastState = state
    events.send(mapOf("type" to "state", "state" to state))
  }

  /**
   * Loads [type]/[uri] into the player; [callback] resolves with the
   * duration in milliseconds (or null) once the player is ready.
   *
   * 加载 [type]/[uri] 指定的音频源；播放器就绪后 [callback] 返回时长
   * （毫秒，未知为 null）。
   */
  fun setSource(
      type: SourceTypeMessage,
      uri: String,
      headers: Map<String, String>?,
      callback: (Result<Long?>) -> Unit,
  ) {
    pendingLoad?.invoke(
        Result.failure(FlutterError("sourceLoadFailed", "Replaced by a newer setSource call", null)))
    pendingLoad = callback
    startedOnce = false
    stoppedByUser = false
    lastState = null
    emitState("loading")

    val resolvedUri =
        when (type) {
          SourceTypeMessage.FILE -> "file://$uri"
          SourceTypeMessage.URL -> uri
          SourceTypeMessage.ASSET ->
              "asset:///${flutterAssets.getAssetFilePathByName(uri)}"
        }
    val mediaItem = MediaItem.fromUri(resolvedUri)
    if (type == SourceTypeMessage.URL && !headers.isNullOrEmpty()) {
      val httpFactory =
          DefaultHttpDataSource.Factory().setDefaultRequestProperties(headers)
      val sourceFactory =
          DefaultMediaSourceFactory(DefaultDataSource.Factory(context, httpFactory))
      player.setMediaSource(sourceFactory.createMediaSource(mediaItem))
    } else {
      player.setMediaItem(mediaItem)
    }
    player.pause()
    player.prepare()
  }

  /** Starts/resumes playback. / 开始或恢复播放。 */
  fun play() {
    stoppedByUser = false
    if (player.playbackState == Player.STATE_ENDED) {
      player.seekTo(0)
    }
    player.play()
  }

  /** Pauses playback. / 暂停播放。 */
  fun pause() {
    player.pause()
  }

  /** Stops playback and rewinds. / 停止播放并回到起点。 */
  fun stop() {
    stoppedByUser = true
    player.pause()
    player.seekTo(0)
    emitState("stopped")
  }

  /** Seeks to [positionMs] and reports completion via [callback].
   *  跳转到 [positionMs]，完成后通过 [callback] 通知。 */
  fun seekTo(positionMs: Long, callback: (Result<Unit>) -> Unit) {
    player.seekTo(positionMs)
    callback(Result.success(Unit))
  }

  /** Sets volume 0.0–1.0. / 设置音量（0.0～1.0）。 */
  fun setVolume(volume: Double) {
    player.volume = volume.toFloat().coerceIn(0f, 1f)
  }

  /** Sets playback speed. / 设置播放速度。 */
  fun setSpeed(speed: Double) {
    player.setPlaybackSpeed(speed.toFloat())
  }

  /** Enables/disables looping. / 开启或关闭循环。 */
  fun setLooping(looping: Boolean) {
    player.repeatMode =
        if (looping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
  }

  private var preferredOutputDeviceId: String? = null

  /**
   * Routes this player to output device [deviceId] (`null` = system
   * default). Requires API 23; takes effect immediately, also mid-playback.
   *
   * 将本播放器路由到输出设备 [deviceId]（`null` 恢复系统默认）。
   * 需要 API 23；立即生效，播放中亦可切换。
   */
  fun setOutputDevice(deviceId: String?) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      throw FlutterError(
          "unsupported", "Output device selection requires Android 6.0+", null)
    }
    if (deviceId == null) {
      player.setPreferredAudioDevice(null)
      preferredOutputDeviceId = null
      return
    }
    val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val device =
        audioManager
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { it.id.toString() == deviceId }
            ?: throw FlutterError(
                "deviceNotFound", "No output device with id $deviceId", null)
    player.setPreferredAudioDevice(device)
    preferredOutputDeviceId = deviceId
  }

  /**
   * The id of the preferred output device, or `null` when following the
   * system default. / 当前偏好的输出设备 id；跟随系统默认时为 `null`。
   */
  fun outputDeviceId(): String? = preferredOutputDeviceId

  /** Current position in ms. / 当前位置（毫秒）。 */
  fun position(): Long = player.currentPosition

  /** Duration in ms or null. / 时长（毫秒），未知为 null。 */
  fun duration(): Long? =
      if (player.duration == C.TIME_UNSET) null else player.duration

  /** Releases the ExoPlayer and the event channel. / 释放 ExoPlayer 与事件通道。 */
  fun dispose() {
    player.release()
    events.dispose()
  }
}
