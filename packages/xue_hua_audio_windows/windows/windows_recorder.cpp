#include "windows_recorder.h"

#include <audioclient.h>
#include <mfapi.h>
#include <mferror.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mmdeviceapi.h>
#include <windows.h>
#include <wrl/client.h>

#include <cmath>
#include <cstdio>
#include <fstream>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace xue_hua_audio_windows {

namespace {

// Converts a UTF-8 string to a wide string. / 将 UTF-8 字符串转换为宽字符串。
std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.data(),
                                         static_cast<int>(utf8.size()),
                                         nullptr, 0);
  std::wstring wide(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                      wide.data(), length);
  return wide;
}

}  // namespace

// Abstract PCM file writer used by the capture thread.
// 供采集线程使用的抽象 PCM 文件写入器。
class WindowsRecorder::FileWriter {
 public:
  virtual ~FileWriter() = default;
  // Appends `count` bytes of 16-bit PCM. / 追加 `count` 字节的 16 位 PCM。
  virtual void Write(const BYTE* data, size_t count) = 0;
  // Finalizes the file. / 完成文件写入。
  virtual void Finish() = 0;
};

// Streaming WAV writer: reserves a 44-byte header and patches sizes on
// Finish(). / 流式 WAV 写入器：预留 44 字节头部，Finish() 时回填长度。
class WindowsRecorder::WavFileWriter : public WindowsRecorder::FileWriter {
 public:
  WavFileWriter(const std::string& path, int sample_rate, int channels)
      : file_(Utf8ToWide(path), std::ios::binary | std::ios::trunc) {
    const uint32_t byte_rate = sample_rate * channels * 2;
    const uint16_t block_align = static_cast<uint16_t>(channels * 2);
    uint8_t header[44] = {};
    memcpy(header, "RIFF\0\0\0\0WAVEfmt ", 16);
    const uint32_t fmt_size = 16;
    const uint16_t pcm = 1;
    const uint16_t channels16 = static_cast<uint16_t>(channels);
    const uint32_t rate32 = static_cast<uint32_t>(sample_rate);
    const uint16_t bits = 16;
    memcpy(header + 16, &fmt_size, 4);
    memcpy(header + 20, &pcm, 2);
    memcpy(header + 22, &channels16, 2);
    memcpy(header + 24, &rate32, 4);
    memcpy(header + 28, &byte_rate, 4);
    memcpy(header + 32, &block_align, 2);
    memcpy(header + 34, &bits, 2);
    memcpy(header + 36, "data\0\0\0\0", 8);
    file_.write(reinterpret_cast<const char*>(header), sizeof(header));
  }

  bool IsOpen() const { return file_.is_open(); }

  void Write(const BYTE* data, size_t count) override {
    file_.write(reinterpret_cast<const char*>(data),
                static_cast<std::streamsize>(count));
    data_bytes_ += count;
  }

  void Finish() override {
    const uint32_t riff_size = static_cast<uint32_t>(36 + data_bytes_);
    const uint32_t data_size = static_cast<uint32_t>(data_bytes_);
    file_.seekp(4);
    file_.write(reinterpret_cast<const char*>(&riff_size), 4);
    file_.seekp(40);
    file_.write(reinterpret_cast<const char*>(&data_size), 4);
    file_.close();
  }

 private:
  std::ofstream file_;
  size_t data_bytes_ = 0;
};

// AAC-LC writer backed by a Media Foundation sink writer producing `.m4a`.
// 基于 Media Foundation Sink Writer 的 AAC-LC 写入器（输出 `.m4a`）。
class WindowsRecorder::AacFileWriter : public WindowsRecorder::FileWriter {
 public:
  AacFileWriter(const std::string& path, int sample_rate, int channels,
                int bit_rate) {
    const std::wstring wide_path = Utf8ToWide(path);
    HRESULT hr = MFCreateSinkWriterFromURL(wide_path.c_str(), nullptr, nullptr,
                                           &writer_);
    if (FAILED(hr)) {
      return;
    }

    ComPtr<IMFMediaType> out_type;
    MFCreateMediaType(&out_type);
    out_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    out_type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_AAC);
    out_type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
    out_type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, sample_rate);
    out_type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, channels);
    out_type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND, bit_rate / 8);
    hr = writer_->AddStream(out_type.Get(), &stream_index_);
    if (FAILED(hr)) {
      writer_.Reset();
      return;
    }

    ComPtr<IMFMediaType> in_type;
    MFCreateMediaType(&in_type);
    in_type->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
    in_type->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
    in_type->SetUINT32(MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
    in_type->SetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, sample_rate);
    in_type->SetUINT32(MF_MT_AUDIO_NUM_CHANNELS, channels);
    in_type->SetUINT32(MF_MT_AUDIO_BLOCK_ALIGNMENT, channels * 2);
    in_type->SetUINT32(MF_MT_AUDIO_AVG_BYTES_PER_SECOND,
                       sample_rate * channels * 2);
    hr = writer_->SetInputMediaType(stream_index_, in_type.Get(), nullptr);
    if (FAILED(hr) || FAILED(writer_->BeginWriting())) {
      writer_.Reset();
      return;
    }
    bytes_per_second_ = sample_rate * channels * 2;
  }

  bool IsOpen() const { return writer_ != nullptr; }

  void Write(const BYTE* data, size_t count) override {
    if (!writer_ || count == 0) {
      return;
    }
    ComPtr<IMFMediaBuffer> buffer;
    if (FAILED(MFCreateMemoryBuffer(static_cast<DWORD>(count), &buffer))) {
      return;
    }
    BYTE* dest = nullptr;
    buffer->Lock(&dest, nullptr, nullptr);
    memcpy(dest, data, count);
    buffer->Unlock();
    buffer->SetCurrentLength(static_cast<DWORD>(count));

    ComPtr<IMFSample> sample;
    if (FAILED(MFCreateSample(&sample))) {
      return;
    }
    sample->AddBuffer(buffer.Get());
    // Timestamps/durations are in 100 ns units. / 时间戳与时长单位为 100 纳秒。
    const LONGLONG duration =
        static_cast<LONGLONG>(count) * 10'000'000LL / bytes_per_second_;
    sample->SetSampleTime(presentation_time_);
    sample->SetSampleDuration(duration);
    presentation_time_ += duration;
    writer_->WriteSample(stream_index_, sample.Get());
  }

  void Finish() override {
    if (writer_) {
      writer_->Finalize();
      writer_.Reset();
    }
  }

 private:
  ComPtr<IMFSinkWriter> writer_;
  DWORD stream_index_ = 0;
  LONGLONG presentation_time_ = 0;
  LONGLONG bytes_per_second_ = 1;
};

WindowsRecorder::WindowsRecorder(
    flutter::BinaryMessenger* messenger,
    std::shared_ptr<MainThreadDispatcher> dispatcher, int64_t id)
    : dispatcher_(std::move(dispatcher)) {
  events_ = std::make_unique<EventStream>(
      messenger, "xue_hua_audio/recorder_events_" + std::to_string(id));
}

WindowsRecorder::~WindowsRecorder() { StopThread(); }

void WindowsRecorder::EmitState(const std::string& state) {
  events_->SendState(state);
}

std::optional<std::string> WindowsRecorder::Start(
    const RecordConfigMessage& config, const std::string& path) {
  if (running_) {
    return "Recorder is already recording";
  }
  if (config.encoder() == EncoderMessage::kOpus) {
    return "Opus is not supported on Windows";
  }

  sample_rate_ = static_cast<int>(config.sample_rate());
  channels_ = static_cast<int>(config.num_channels());
  if (channels_ < 1 || channels_ > 2) {
    channels_ = 1;
  }

  // Resolve the capture device. / 解析采集设备。
  ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    return "Failed to create device enumerator";
  }
  // The per-start config id wins over the instance-level preference.
  // start 时传入的设备 id 优先于实例级偏好。
  std::optional<std::string> wanted_device_id = preferred_device_id_;
  if (config.device_id() != nullptr && !config.device_id()->empty()) {
    wanted_device_id = *config.device_id();
  }
  ComPtr<IMMDevice> device;
  if (wanted_device_id.has_value() && !wanted_device_id->empty()) {
    hr = enumerator->GetDevice(Utf8ToWide(*wanted_device_id).c_str(), &device);
  } else {
    hr = enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device);
  }
  if (FAILED(hr)) {
    return "Audio input device not found";
  }

  ComPtr<IAudioClient> audio_client;
  hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                        reinterpret_cast<void**>(audio_client.GetAddressOf()));
  if (FAILED(hr)) {
    return "Failed to activate the audio client";
  }

  // Request 16-bit PCM at the configured rate; WASAPI converts from the
  // hardware format in shared mode.
  // 请求 16 位 PCM 与配置的采样率；共享模式下由 WASAPI 自动转换硬件格式。
  WAVEFORMATEX format = {};
  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = static_cast<WORD>(channels_);
  format.nSamplesPerSec = static_cast<DWORD>(sample_rate_);
  format.wBitsPerSample = 16;
  format.nBlockAlign = format.nChannels * format.wBitsPerSample / 8;
  format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;

  constexpr REFERENCE_TIME kBufferDuration = 2'000'000;  // 200 ms
  hr = audio_client->Initialize(
      AUDCLNT_SHAREMODE_SHARED,
      AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM | AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
      kBufferDuration, 0, &format, nullptr);
  if (FAILED(hr)) {
    return "Failed to initialize the audio client (hr=" + std::to_string(hr) +
           ")";
  }

  ComPtr<IAudioCaptureClient> capture_client;
  hr = audio_client->GetService(IID_PPV_ARGS(&capture_client));
  if (FAILED(hr)) {
    return "Failed to get the capture client";
  }

  // Open the output file. / 打开输出文件。
  if (config.encoder() == EncoderMessage::kWav) {
    auto writer = std::make_unique<WavFileWriter>(path, sample_rate_, channels_);
    if (!writer->IsOpen()) {
      return "Cannot open output file: " + path;
    }
    writer_ = std::move(writer);
  } else {
    auto writer = std::make_unique<AacFileWriter>(
        path, sample_rate_, channels_, static_cast<int>(config.bit_rate()));
    if (!writer->IsOpen()) {
      return "Cannot create the AAC sink writer for: " + path;
    }
    writer_ = std::move(writer);
  }

  hr = audio_client->Start();
  if (FAILED(hr)) {
    writer_->Finish();
    writer_.reset();
    return "Failed to start audio capture";
  }

  audio_client_ = audio_client.Detach();
  capture_client_ = capture_client.Detach();
  output_path_ = path;
  max_db_ = -160.0;
  running_ = true;
  paused_ = false;

  const int64_t interval = config.amplitude_interval_ms();
  thread_ = std::thread([this, interval]() { CaptureLoop(interval); });

  EmitState("recording");
  return std::nullopt;
}

void WindowsRecorder::CaptureLoop(int64_t amplitude_interval_ms) {
  auto* capture = static_cast<IAudioCaptureClient*>(capture_client_);
  ULONGLONG last_emit = GetTickCount64();
  std::vector<BYTE> silence;

  while (running_) {
    UINT32 packet_frames = 0;
    if (FAILED(capture->GetNextPacketSize(&packet_frames))) {
      break;
    }
    if (packet_frames == 0) {
      Sleep(10);
      continue;
    }

    BYTE* data = nullptr;
    UINT32 frames = 0;
    DWORD flags = 0;
    if (FAILED(capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr))) {
      break;
    }
    const size_t byte_count = static_cast<size_t>(frames) * channels_ * 2;

    if (!paused_ && byte_count > 0) {
      const BYTE* pcm = data;
      if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
        silence.assign(byte_count, 0);
        pcm = silence.data();
      }
      writer_->Write(pcm, byte_count);

      // Peak amplitude in dBFS. / 峰值振幅（dBFS）。
      int peak = 0;
      const int16_t* samples = reinterpret_cast<const int16_t*>(pcm);
      const size_t sample_count = byte_count / 2;
      for (size_t i = 0; i < sample_count; ++i) {
        const int magnitude = std::abs(static_cast<int>(samples[i]));
        if (magnitude > peak) {
          peak = magnitude;
        }
      }
      const ULONGLONG now = GetTickCount64();
      if (now - last_emit >= static_cast<ULONGLONG>(amplitude_interval_ms)) {
        last_emit = now;
        const double db =
            peak == 0 ? -160.0 : 20.0 * std::log10(peak / 32767.0);
        if (db > max_db_) {
          max_db_ = db;
        }
        const double current_max = max_db_;
        dispatcher_->Post([this, db, current_max]() {
          events_->Send(flutter::EncodableMap{
              {flutter::EncodableValue("type"),
               flutter::EncodableValue("amplitude")},
              {flutter::EncodableValue("current"),
               flutter::EncodableValue(db)},
              {flutter::EncodableValue("max"),
               flutter::EncodableValue(current_max)},
          });
        });
      }
    }
    capture->ReleaseBuffer(frames);
  }
}

void WindowsRecorder::StopThread() {
  if (running_) {
    running_ = false;
    if (thread_.joinable()) {
      thread_.join();
    }
  } else if (thread_.joinable()) {
    thread_.join();
  }
  if (audio_client_ != nullptr) {
    auto* client = static_cast<IAudioClient*>(audio_client_);
    client->Stop();
    client->Release();
    audio_client_ = nullptr;
  }
  if (capture_client_ != nullptr) {
    static_cast<IAudioCaptureClient*>(capture_client_)->Release();
    capture_client_ = nullptr;
  }
  if (writer_) {
    writer_->Finish();
    writer_.reset();
  }
}

void WindowsRecorder::Pause() {
  if (running_ && !paused_) {
    paused_ = true;
    EmitState("paused");
  }
}

void WindowsRecorder::Resume() {
  if (running_ && paused_) {
    paused_ = false;
    EmitState("recording");
  }
}

std::optional<std::string> WindowsRecorder::Stop() {
  StopThread();
  if (output_path_.empty()) {
    return std::nullopt;
  }
  EmitState("stopped");
  return output_path_;
}

void WindowsRecorder::Cancel() {
  StopThread();
  if (!output_path_.empty()) {
    DeleteFileW(Utf8ToWide(output_path_).c_str());
  }
  EmitState("stopped");
}

bool WindowsRecorder::SetInputDevice(
    const std::optional<std::string>& device_id) {
  if (running_) {
    return false;
  }
  preferred_device_id_ = device_id;
  return true;
}

}  // namespace xue_hua_audio_windows
