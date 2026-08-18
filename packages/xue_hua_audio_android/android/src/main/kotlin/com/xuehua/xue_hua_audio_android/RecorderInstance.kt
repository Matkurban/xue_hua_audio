package com.xuehua.xue_hua_audio_android

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max

/**
 * Writes PCM chunks captured by [AudioRecord] into an audio file.
 * 将 [AudioRecord] 采集到的 PCM 数据块写入音频文件。
 */
private interface PcmFileWriter {
  /** Appends [count] bytes from [buffer]. / 追加 [buffer] 中的前 [count] 字节。 */
  fun write(buffer: ByteArray, count: Int)

  /** Finalizes the file (headers, muxer). / 完成文件写入（补齐头部、结束封装）。 */
  fun finish()
}

/**
 * Minimal streaming WAV writer: reserves a 44-byte header and patches the
 * chunk sizes on [finish].
 * 极简流式 WAV 写入器：预留 44 字节头部，在 [finish] 时回填数据长度。
 */
private class WavWriter(path: String, sampleRate: Int, channels: Int) :
    PcmFileWriter {
  private val file = RandomAccessFile(path, "rw")
  private var dataBytes = 0L

  init {
    file.setLength(0)
    val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
    val byteRate = sampleRate * channels * 2
    header.put("RIFF".toByteArray())
    header.putInt(0) // patched in finish() / 在 finish() 中回填
    header.put("WAVE".toByteArray())
    header.put("fmt ".toByteArray())
    header.putInt(16)
    header.putShort(1) // PCM
    header.putShort(channels.toShort())
    header.putInt(sampleRate)
    header.putInt(byteRate)
    header.putShort((channels * 2).toShort())
    header.putShort(16)
    header.put("data".toByteArray())
    header.putInt(0) // patched in finish() / 在 finish() 中回填
    file.write(header.array())
  }

  override fun write(buffer: ByteArray, count: Int) {
    file.write(buffer, 0, count)
    dataBytes += count
  }

  override fun finish() {
    file.seek(4)
    file.writeInt(Integer.reverseBytes((36 + dataBytes).toInt()))
    file.seek(40)
    file.writeInt(Integer.reverseBytes(dataBytes.toInt()))
    file.close()
  }
}

/**
 * AAC-LC writer: encodes PCM with [MediaCodec] and muxes into an `.m4a`
 * (MPEG-4) file with [MediaMuxer].
 * AAC-LC 写入器：用 [MediaCodec] 编码 PCM，并用 [MediaMuxer] 封装为
 * `.m4a`（MPEG-4）文件。
 */
private class AacWriter(
    path: String,
    private val sampleRate: Int,
    channels: Int,
    bitRate: Int,
) : PcmFileWriter {
  private val codec: MediaCodec
  private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
  private var trackIndex = -1
  private var muxerStarted = false
  private var presentationTimeUs = 0L
  private val bytesPerSecond = sampleRate * channels * 2

  init {
    val format =
        MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels)
    format.setInteger(
        MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
    format.setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
    codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    codec.start()
  }

  override fun write(buffer: ByteArray, count: Int) {
    var offset = 0
    while (offset < count) {
      val inIndex = codec.dequeueInputBuffer(10_000)
      if (inIndex < 0) {
        drainOutput(false)
        continue
      }
      val input = codec.getInputBuffer(inIndex)!!
      val chunk = minOf(input.remaining(), count - offset)
      input.put(buffer, offset, chunk)
      codec.queueInputBuffer(inIndex, 0, chunk, presentationTimeUs, 0)
      presentationTimeUs += chunk * 1_000_000L / bytesPerSecond
      offset += chunk
      drainOutput(false)
    }
  }

  override fun finish() {
    val inIndex = codec.dequeueInputBuffer(10_000)
    if (inIndex >= 0) {
      codec.queueInputBuffer(
          inIndex, 0, 0, presentationTimeUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
    }
    drainOutput(true)
    codec.stop()
    codec.release()
    if (muxerStarted) {
      muxer.stop()
    }
    muxer.release()
  }

  private fun drainOutput(untilEos: Boolean) {
    val info = MediaCodec.BufferInfo()
    while (true) {
      val outIndex = codec.dequeueOutputBuffer(info, if (untilEos) 10_000 else 0)
      when {
        outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
          trackIndex = muxer.addTrack(codec.outputFormat)
          muxer.start()
          muxerStarted = true
        }
        outIndex >= 0 -> {
          val output = codec.getOutputBuffer(outIndex)!!
          if (info.size > 0 && muxerStarted &&
              (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
            muxer.writeSampleData(trackIndex, output, info)
          }
          codec.releaseOutputBuffer(outIndex, false)
          if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
            return
          }
        }
        else -> if (!untilEos) return
      }
    }
  }
}

/**
 * One microphone recording instance backed by [AudioRecord].
 *
 * A background thread reads PCM, computes the peak amplitude (dBFS) and
 * feeds the active [PcmFileWriter]; amplitude and state events are pushed
 * to Dart through `xue_hua_audio/recorder_events_<id>`.
 *
 * 基于 [AudioRecord] 的单个麦克风录音实例。
 *
 * 后台线程读取 PCM、计算峰值振幅（dBFS）并交给 [PcmFileWriter] 写盘；
 * 振幅与状态事件经 `xue_hua_audio/recorder_events_<id>` 推送给 Dart。
 *
 * @param context Android context. / Android 上下文。
 * @param messenger Engine messenger for the event channel. / 事件通道使用的引擎信使。
 * @param id This recorder's id. / 本录音机的 id。
 */
class RecorderInstance(
    private val context: Context,
    messenger: BinaryMessenger,
    id: Long,
) {
  private val events =
      EventStream(messenger, "xue_hua_audio/recorder_events_$id")
  private val mainHandler = Handler(Looper.getMainLooper())

  private var record: AudioRecord? = null
  private var thread: Thread? = null
  @Volatile private var running = false
  @Volatile private var paused = false
  private var outputPath: String? = null
  private var maxDb = -160.0

  /**
   * Starts capturing with [config] and writing to [path]; [callback]
   * resolves once capture is running.
   *
   * 按 [config] 开始采集并写入 [path]；采集启动后 [callback] 完成。
   */
  @SuppressLint("MissingPermission")
  fun start(config: RecordConfigMessage, path: String, callback: (Result<Unit>) -> Unit) {
    if (running) {
      callback(
          Result.failure(
              FlutterError("invalidState", "Recorder is already recording", null)))
      return
    }
    if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
        PackageManager.PERMISSION_GRANTED) {
      callback(
          Result.failure(
              FlutterError("permissionDenied", "RECORD_AUDIO permission not granted", null)))
      return
    }

    val sampleRate = config.sampleRate.toInt()
    val channels = config.numChannels.toInt().coerceIn(1, 2)
    val channelConfig =
        if (channels == 1) AudioFormat.CHANNEL_IN_MONO else AudioFormat.CHANNEL_IN_STEREO
    val minBuffer =
        AudioRecord.getMinBufferSize(sampleRate, channelConfig, AudioFormat.ENCODING_PCM_16BIT)
    if (minBuffer <= 0) {
      callback(
          Result.failure(
              FlutterError("recordingFailed", "Unsupported sample rate: $sampleRate", null)))
      return
    }

    val writer: PcmFileWriter =
        try {
          when (config.encoder) {
            EncoderMessage.WAV -> WavWriter(path, sampleRate, channels)
            EncoderMessage.AAC_LC ->
                AacWriter(path, sampleRate, channels, config.bitRate.toInt())
            EncoderMessage.OPUS -> {
              callback(
                  Result.failure(
                      FlutterError(
                          "unsupportedEncoder", "Opus is not supported on Android", null)))
              return
            }
          }
        } catch (e: Exception) {
          callback(
              Result.failure(
                  FlutterError("recordingFailed", "Cannot open output: ${e.message}", null)))
          return
        }

    val audioRecord =
        AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            channelConfig,
            AudioFormat.ENCODING_PCM_16BIT,
            max(minBuffer * 2, 8192))
    if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
      audioRecord.release()
      writer.finish()
      callback(
          Result.failure(FlutterError("recordingFailed", "AudioRecord init failed", null)))
      return
    }

    // The per-start config id wins over the instance-level preference.
    // start 时传入的设备 id 优先于实例级偏好。
    val wantedDeviceId = config.deviceId ?: preferredInputDeviceId
    if (wantedDeviceId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      findInputDevice(wantedDeviceId)?.let(audioRecord::setPreferredDevice)
    }

    record = audioRecord
    outputPath = path
    running = true
    paused = false
    maxDb = -160.0
    audioRecord.startRecording()

    val intervalMs = config.amplitudeIntervalMs
    thread =
        Thread({ captureLoop(audioRecord, writer, intervalMs) }, "xue_hua_audio_recorder")
            .also { it.start() }

    emitState("recording")
    callback(Result.success(Unit))
  }

  private fun captureLoop(audioRecord: AudioRecord, writer: PcmFileWriter, intervalMs: Long) {
    val buffer = ByteArray(4096)
    var lastEmit = 0L
    var failure: Exception? = null
    try {
      while (running) {
        val read = audioRecord.read(buffer, 0, buffer.size)
        if (read <= 0) continue
        if (paused) continue
        writer.write(buffer, read)

        var peak = 0
        var i = 0
        while (i + 1 < read) {
          val sample =
              (buffer[i].toInt() and 0xFF or (buffer[i + 1].toInt() shl 8)).toShort().toInt()
          peak = max(peak, abs(sample))
          i += 2
        }
        val now = System.currentTimeMillis()
        if (now - lastEmit >= intervalMs) {
          lastEmit = now
          val db = if (peak == 0) -160.0 else 20.0 * log10(peak / 32767.0)
          maxDb = max(maxDb, db)
          val currentMax = maxDb
          mainHandler.post {
            events.send(
                mapOf("type" to "amplitude", "current" to db, "max" to currentMax))
          }
        }
      }
    } catch (e: Exception) {
      failure = e
    } finally {
      try {
        audioRecord.stop()
      } catch (_: IllegalStateException) {}
      audioRecord.release()
      try {
        writer.finish()
      } catch (e: Exception) {
        if (failure == null) failure = e
      }
    }
    failure?.let { e ->
      mainHandler.post {
        events.send(
            mapOf(
                "type" to "error",
                "code" to "recordingFailed",
                "message" to (e.message ?: "Recording failed")))
        emitState("error")
      }
    }
  }

  private var preferredInputDeviceId: String? = null

  private fun findInputDevice(deviceId: String): AudioDeviceInfo? {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    return audioManager
        .getDevices(AudioManager.GET_DEVICES_INPUTS)
        .firstOrNull { it.id.toString() == deviceId }
  }

  /**
   * Selects input device [deviceId] (`null` = system default). Applies
   * immediately when recording (API 23+), otherwise at the next [start].
   *
   * 选择输入设备 [deviceId]（`null` 使用系统默认）。录音中立即生效
   * （需 API 23+），否则在下一次 [start] 时生效。
   */
  fun setInputDevice(deviceId: String?) {
    if (deviceId != null && Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      throw FlutterError(
          "unsupported", "Input device selection requires Android 6.0+", null)
    }
    val device =
        deviceId?.let {
          findInputDevice(it)
              ?: throw FlutterError(
                  "deviceNotFound", "No input device with id $it", null)
        }
    preferredInputDeviceId = deviceId
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      record?.setPreferredDevice(device)
    }
  }

  /**
   * The id of the input device in use: the routed device while recording,
   * otherwise the stored preference (`null` = system default).
   *
   * 当前使用的输入设备 id：录音中返回实际路由设备，否则返回已存偏好
   * （`null` 表示系统默认）。
   */
  fun inputDeviceId(): String? {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      record?.routedDevice?.let {
        return it.id.toString()
      }
    }
    return preferredInputDeviceId
  }

  /** Pauses capture (data is discarded while paused). / 暂停采集（暂停期间不写入数据）。 */
  fun pause() {
    if (running && !paused) {
      paused = true
      emitState("paused")
    }
  }

  /** Resumes capture. / 恢复采集。 */
  fun resume() {
    if (running && paused) {
      paused = false
      emitState("recording")
    }
  }

  /**
   * Stops recording; [callback] resolves with the file path or null when
   * nothing was recorded.
   * 停止录音；[callback] 返回文件路径，未录音时返回 null。
   */
  fun stop(callback: (Result<String?>) -> Unit) {
    val path = outputPath
    stopInternal()
    if (path != null) emitState("stopped")
    callback(Result.success(path))
  }

  /** Stops recording and deletes the file. / 停止录音并删除文件。 */
  fun cancel(callback: (Result<Unit>) -> Unit) {
    val path = outputPath
    stopInternal()
    path?.let { File(it).delete() }
    emitState("stopped")
    callback(Result.success(Unit))
  }

  /** Releases everything. / 释放全部资源。 */
  fun dispose() {
    stopInternal()
    events.dispose()
  }

  private fun stopInternal() {
    if (running) {
      running = false
      thread?.join(2000)
    }
    thread = null
    record = null
  }

  private fun emitState(state: String) {
    events.send(mapOf("type" to "state", "state" to state))
  }
}
