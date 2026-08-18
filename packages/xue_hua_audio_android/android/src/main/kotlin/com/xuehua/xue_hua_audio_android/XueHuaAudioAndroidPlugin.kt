package com.xuehua.xue_hua_audio_android

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.PluginRegistry

/**
 * Entry point of the Android implementation: registers the Pigeon host
 * APIs and manages the microphone permission flow.
 *
 * The two host APIs are implemented by separate inner classes because
 * `AudioPlayerHostApi.pause(playerId)` and
 * `AudioRecorderHostApi.pause(recorderId)` share the same JVM signature and
 * cannot live on one class.
 *
 * Android 实现入口：注册 Pigeon Host API，并管理麦克风权限申请流程。
 *
 * 两个 Host API 由独立的内部类实现——因为
 * `AudioPlayerHostApi.pause(playerId)` 与
 * `AudioRecorderHostApi.pause(recorderId)` 的 JVM 签名相同，无法在同一个
 * 类上同时实现。
 */
class XueHuaAudioAndroidPlugin :
    FlutterPlugin, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

  private companion object {
    const val PERMISSION_REQUEST_CODE = 0x58AD
  }

  private lateinit var context: Context
  private lateinit var messenger: BinaryMessenger
  private lateinit var flutterAssets: FlutterPlugin.FlutterAssets

  private var activityBinding: ActivityPluginBinding? = null
  private val pendingPermissionCallbacks = mutableListOf<(Result<Boolean>) -> Unit>()

  private val players = mutableMapOf<Long, PlayerInstance>()
  private val recorders = mutableMapOf<Long, RecorderInstance>()
  private var nextPlayerId = 1L
  private var nextRecorderId = 1L

  // -- FlutterPlugin ------------------------------------------------------

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    messenger = binding.binaryMessenger
    flutterAssets = binding.flutterAssets
    AudioPlayerHostApi.setUp(messenger, PlayerApi())
    AudioRecorderHostApi.setUp(messenger, RecorderApi())
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    AudioPlayerHostApi.setUp(binding.binaryMessenger, null)
    AudioRecorderHostApi.setUp(binding.binaryMessenger, null)
    players.values.forEach(PlayerInstance::dispose)
    players.clear()
    recorders.values.forEach(RecorderInstance::dispose)
    recorders.clear()
  }

  // -- ActivityAware (needed for the permission dialog / 权限弹窗所需) -----

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    binding.addRequestPermissionsResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
      onAttachedToActivity(binding)

  override fun onDetachedFromActivity() {
    activityBinding?.removeRequestPermissionsResultListener(this)
    activityBinding = null
  }

  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray,
  ): Boolean {
    if (requestCode != PERMISSION_REQUEST_CODE) return false
    val granted =
        grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
    pendingPermissionCallbacks.forEach { it(Result.success(granted)) }
    pendingPermissionCallbacks.clear()
    return true
  }

  // -- Device helpers / 设备工具方法 ---------------------------------------

  /** Human-readable name of an [AudioDeviceInfo]. / 设备的可读名称。 */
  private fun deviceLabel(device: AudioDeviceInfo): String {
    val typeName =
        when (device.type) {
          AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Speaker"
          AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Earpiece"
          AudioDeviceInfo.TYPE_BUILTIN_MIC -> "Built-in mic"
          AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired headset"
          AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired headphones"
          AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth"
          AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth (call)"
          AudioDeviceInfo.TYPE_USB_DEVICE -> "USB"
          AudioDeviceInfo.TYPE_USB_HEADSET -> "USB headset"
          else -> null
        }
    val product = device.productName?.toString().orEmpty().ifEmpty { "Device ${device.id}" }
    return if (typeName == null) product else "$product ($typeName)"
  }

  /**
   * Enumerates devices of the given [flow] as Pigeon messages (API 23+;
   * empty on older systems). / 按 [flow] 枚举设备并转换为 Pigeon 消息
   * （需 API 23+，旧系统返回空列表）。
   */
  private fun listDevices(flow: Int): List<AudioDeviceMessage> {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return emptyList()
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    return audioManager
        .getDevices(flow)
        .filter { it.type != AudioDeviceInfo.TYPE_TELEPHONY }
        .map { AudioDeviceMessage(id = it.id.toString(), label = deviceLabel(it)) }
  }

  /** Looks up one device message by id. / 按 id 查找单个设备消息。 */
  private fun deviceById(flow: Int, deviceId: String): AudioDeviceMessage? =
      listDevices(flow).firstOrNull { it.id == deviceId }

  /**
   * Playback host API backed by [PlayerInstance]s (Media3 ExoPlayer).
   * 基于 [PlayerInstance]（Media3 ExoPlayer）的播放 Host API 实现。
   */
  private inner class PlayerApi : AudioPlayerHostApi {

    private fun playerOf(id: Long): PlayerInstance =
        players[id] ?: throw FlutterError("instanceNotFound", "No player with id $id", null)

    override fun createPlayer(): Long {
      val id = nextPlayerId++
      players[id] = PlayerInstance(context, messenger, flutterAssets, id)
      return id
    }

    override fun setSource(
        playerId: Long,
        source: AudioSourceMessage,
        callback: (Result<Long?>) -> Unit,
    ) {
      val player =
          players[playerId]
              ?: return callback(
                  Result.failure(
                      FlutterError("instanceNotFound", "No player with id $playerId", null)))
      player.setSource(source.type, source.uri, source.headers, callback)
    }

    override fun play(playerId: Long) = playerOf(playerId).play()

    override fun pause(playerId: Long) = playerOf(playerId).pause()

    override fun stop(playerId: Long) = playerOf(playerId).stop()

    override fun seekTo(playerId: Long, positionMs: Long, callback: (Result<Unit>) -> Unit) {
      val player =
          players[playerId]
              ?: return callback(
                  Result.failure(
                      FlutterError("instanceNotFound", "No player with id $playerId", null)))
      player.seekTo(positionMs, callback)
    }

    override fun setVolume(playerId: Long, volume: Double) =
        playerOf(playerId).setVolume(volume)

    override fun setSpeed(playerId: Long, speed: Double) = playerOf(playerId).setSpeed(speed)

    override fun setLooping(playerId: Long, looping: Boolean) =
        playerOf(playerId).setLooping(looping)

    override fun getPosition(playerId: Long): Long = playerOf(playerId).position()

    override fun getDuration(playerId: Long): Long? = playerOf(playerId).duration()

    override fun listOutputDevices(callback: (Result<List<AudioDeviceMessage>>) -> Unit) {
      callback(Result.success(listDevices(AudioManager.GET_DEVICES_OUTPUTS)))
    }

    override fun getOutputDevice(
        playerId: Long,
        callback: (Result<AudioDeviceMessage?>) -> Unit,
    ) {
      val deviceId =
          try {
            playerOf(playerId).outputDeviceId()
          } catch (e: FlutterError) {
            return callback(Result.failure(e))
          }
      callback(
          Result.success(
              deviceId?.let { deviceById(AudioManager.GET_DEVICES_OUTPUTS, it) }))
    }

    override fun setOutputDevice(
        playerId: Long,
        deviceId: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
      try {
        playerOf(playerId).setOutputDevice(deviceId)
        callback(Result.success(Unit))
      } catch (e: FlutterError) {
        callback(Result.failure(e))
      }
    }

    override fun disposePlayer(playerId: Long) {
      players.remove(playerId)?.dispose()
    }
  }

  /**
   * Recording host API backed by [RecorderInstance]s (AudioRecord).
   * 基于 [RecorderInstance]（AudioRecord）的录音 Host API 实现。
   */
  private inner class RecorderApi : AudioRecorderHostApi {

    private fun recorderOf(id: Long): RecorderInstance =
        recorders[id]
            ?: throw FlutterError("instanceNotFound", "No recorder with id $id", null)

    override fun createRecorder(): Long {
      val id = nextRecorderId++
      recorders[id] = RecorderInstance(context, messenger, id)
      return id
    }

    override fun hasPermission(callback: (Result<Boolean>) -> Unit) {
      if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
          PackageManager.PERMISSION_GRANTED) {
        callback(Result.success(true))
        return
      }
      val activity: Activity? = activityBinding?.activity
      if (activity == null) {
        callback(Result.success(false))
        return
      }
      pendingPermissionCallbacks.add(callback)
      if (pendingPermissionCallbacks.size == 1) {
        activity.requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST_CODE)
      }
    }

    override fun listInputDevices(callback: (Result<List<AudioDeviceMessage>>) -> Unit) {
      callback(Result.success(listDevices(AudioManager.GET_DEVICES_INPUTS)))
    }

    override fun getInputDevice(
        recorderId: Long,
        callback: (Result<AudioDeviceMessage?>) -> Unit,
    ) {
      val deviceId =
          try {
            recorderOf(recorderId).inputDeviceId()
          } catch (e: FlutterError) {
            return callback(Result.failure(e))
          }
      callback(
          Result.success(
              deviceId?.let { deviceById(AudioManager.GET_DEVICES_INPUTS, it) }))
    }

    override fun setInputDevice(
        recorderId: Long,
        deviceId: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
      try {
        recorderOf(recorderId).setInputDevice(deviceId)
        callback(Result.success(Unit))
      } catch (e: FlutterError) {
        callback(Result.failure(e))
      }
    }

    override fun start(
        recorderId: Long,
        config: RecordConfigMessage,
        path: String,
        callback: (Result<Unit>) -> Unit,
    ) {
      val recorder =
          recorders[recorderId]
              ?: return callback(
                  Result.failure(
                      FlutterError("instanceNotFound", "No recorder with id $recorderId", null)))
      recorder.start(config, path, callback)
    }

    override fun pause(recorderId: Long) = recorderOf(recorderId).pause()

    override fun resume(recorderId: Long) = recorderOf(recorderId).resume()

    override fun stop(recorderId: Long, callback: (Result<String?>) -> Unit) {
      val recorder =
          recorders[recorderId]
              ?: return callback(
                  Result.failure(
                      FlutterError("instanceNotFound", "No recorder with id $recorderId", null)))
      recorder.stop(callback)
    }

    override fun cancel(recorderId: Long, callback: (Result<Unit>) -> Unit) {
      val recorder =
          recorders[recorderId]
              ?: return callback(
                  Result.failure(
                      FlutterError("instanceNotFound", "No recorder with id $recorderId", null)))
      recorder.cancel(callback)
    }

    override fun disposeRecorder(recorderId: Long) {
      recorders.remove(recorderId)?.dispose()
    }
  }
}
