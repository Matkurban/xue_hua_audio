#include "windows_player.h"

#include <mferror.h>

#include <cmath>

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

// IMFMediaEngineNotify implementation forwarding events to the owner on the
// platform thread. The owner clears itself in its destructor.
//
// IMFMediaEngineNotify 实现：把事件转发给所有者并切换到平台线程执行；
// 所有者析构时会将自身指针清空。
class WindowsPlayer::Notify
    : public Microsoft::WRL::RuntimeClass<
          Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>,
          IMFMediaEngineNotify> {
 public:
  void Init(WindowsPlayer* owner,
            std::shared_ptr<MainThreadDispatcher> dispatcher) {
    owner_ = owner;
    dispatcher_ = std::move(dispatcher);
  }

  void Detach() { owner_ = nullptr; }

  IFACEMETHODIMP EventNotify(DWORD event, DWORD_PTR param1,
                             DWORD param2) override {
    Microsoft::WRL::ComPtr<Notify> self(this);
    dispatcher_->Post([self, event, param1, param2]() {
      if (self->owner_ != nullptr) {
        self->owner_->OnEngineEvent(event, param1, param2);
      }
    });
    return S_OK;
  }

 private:
  WindowsPlayer* owner_ = nullptr;
  std::shared_ptr<MainThreadDispatcher> dispatcher_;
};

WindowsPlayer::WindowsPlayer(flutter::BinaryMessenger* messenger,
                             std::shared_ptr<MainThreadDispatcher> dispatcher,
                             int64_t id)
    : dispatcher_(std::move(dispatcher)) {
  events_ = std::make_unique<EventStream>(
      messenger, "xue_hua_audio/player_events_" + std::to_string(id));

  Microsoft::WRL::ComPtr<IMFMediaEngineClassFactory> factory;
  HRESULT hr =
      CoCreateInstance(CLSID_MFMediaEngineClassFactory, nullptr,
                       CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    events_->SendError("playbackFailed", "Failed to create media engine factory");
    return;
  }

  notify_ = Microsoft::WRL::Make<Notify>();
  notify_->Init(this, dispatcher_);

  Microsoft::WRL::ComPtr<IMFAttributes> attributes;
  MFCreateAttributes(&attributes, 1);
  attributes->SetUnknown(MF_MEDIA_ENGINE_CALLBACK, notify_.Get());

  hr = factory->CreateInstance(MF_MEDIA_ENGINE_AUDIOONLY, attributes.Get(),
                               &engine_);
  if (FAILED(hr)) {
    events_->SendError("playbackFailed", "Failed to create media engine");
    engine_.Reset();
  }
}

WindowsPlayer::~WindowsPlayer() {
  if (notify_) {
    notify_->Detach();
  }
  if (engine_) {
    engine_->Shutdown();
  }
}

void WindowsPlayer::EmitState(const std::string& state) {
  if (state == last_state_) {
    return;
  }
  last_state_ = state;
  events_->SendState(state);
}

void WindowsPlayer::SetSource(const std::string& url, LoadCallback callback) {
  if (!engine_) {
    callback(std::nullopt, "Media engine is not available");
    return;
  }
  if (pending_load_) {
    pending_load_(std::nullopt, "Replaced by a newer setSource call");
  }
  pending_load_ = std::move(callback);
  started_once_ = false;
  stopped_by_user_ = false;
  last_state_.clear();
  EmitState("loading");

  const std::wstring wide_url = Utf8ToWide(url);
  BSTR bstr = SysAllocString(wide_url.c_str());
  const HRESULT hr = engine_->SetSource(bstr);
  SysFreeString(bstr);
  if (FAILED(hr)) {
    auto load = std::move(pending_load_);
    pending_load_ = nullptr;
    load(std::nullopt, "Failed to set source");
  }
}

void WindowsPlayer::OnEngineEvent(DWORD event, DWORD_PTR param1,
                                  DWORD param2) {
  switch (event) {
    case MF_MEDIA_ENGINE_EVENT_LOADEDMETADATA: {
      if (pending_load_) {
        auto load = std::move(pending_load_);
        pending_load_ = nullptr;
        const auto duration = Duration();
        flutter::EncodableMap duration_event{
            {flutter::EncodableValue("type"),
             flutter::EncodableValue("duration")},
            {flutter::EncodableValue("durationMs"),
             duration.has_value()
                 ? flutter::EncodableValue(duration.value())
                 : flutter::EncodableValue()},
        };
        events_->Send(duration_event);
        EmitState("ready");
        load(duration, std::nullopt);
      }
      break;
    }
    case MF_MEDIA_ENGINE_EVENT_PLAYING:
      started_once_ = true;
      EmitState("playing");
      break;
    case MF_MEDIA_ENGINE_EVENT_WAITING:
      EmitState("loading");
      break;
    case MF_MEDIA_ENGINE_EVENT_PAUSE:
      if (engine_ && !engine_->IsEnded()) {
        EmitState(stopped_by_user_ ? "stopped"
                                   : (started_once_ ? "paused" : "ready"));
      }
      break;
    case MF_MEDIA_ENGINE_EVENT_ENDED:
      EmitState("completed");
      break;
    case MF_MEDIA_ENGINE_EVENT_SEEKED:
      if (pending_seek_) {
        auto done = std::move(pending_seek_);
        pending_seek_ = nullptr;
        done();
      }
      break;
    case MF_MEDIA_ENGINE_EVENT_ERROR: {
      const std::string message =
          "Media engine error " + std::to_string(param1) + " (hr=" +
          std::to_string(param2) + ")";
      if (pending_load_) {
        auto load = std::move(pending_load_);
        pending_load_ = nullptr;
        load(std::nullopt, message);
      } else {
        events_->SendError("playbackFailed", message);
        EmitState("error");
      }
      break;
    }
    default:
      break;
  }
}

void WindowsPlayer::Play() {
  if (!engine_) {
    return;
  }
  stopped_by_user_ = false;
  if (engine_->IsEnded()) {
    engine_->SetCurrentTime(0);
    last_state_.clear();
  }
  engine_->SetPlaybackRate(speed_);
  engine_->Play();
}

void WindowsPlayer::Pause() {
  if (engine_) {
    engine_->Pause();
  }
}

void WindowsPlayer::Stop() {
  if (!engine_) {
    return;
  }
  stopped_by_user_ = true;
  engine_->Pause();
  engine_->SetCurrentTime(0);
  EmitState("stopped");
}

void WindowsPlayer::SeekTo(int64_t position_ms, std::function<void()> done) {
  if (!engine_) {
    done();
    return;
  }
  if (pending_seek_) {
    pending_seek_();
  }
  pending_seek_ = std::move(done);
  if (FAILED(engine_->SetCurrentTime(position_ms / 1000.0))) {
    auto pending = std::move(pending_seek_);
    pending_seek_ = nullptr;
    pending();
  }
}

void WindowsPlayer::SetVolume(double volume) {
  if (engine_) {
    engine_->SetVolume(std::clamp(volume, 0.0, 1.0));
  }
}

void WindowsPlayer::SetSpeed(double speed) {
  speed_ = speed;
  if (engine_) {
    engine_->SetPlaybackRate(speed);
  }
}

void WindowsPlayer::SetLooping(bool looping) {
  if (engine_) {
    engine_->SetLoop(looping ? TRUE : FALSE);
  }
}

int64_t WindowsPlayer::Position() {
  if (!engine_) {
    return 0;
  }
  const double seconds = engine_->GetCurrentTime();
  if (std::isnan(seconds) || seconds < 0) {
    return 0;
  }
  return static_cast<int64_t>(seconds * 1000.0);
}

WindowsPlayer::RouteResult WindowsPlayer::SetOutputDevice(
    const std::optional<std::string>& device_id) {
  if (!engine_) {
    return RouteResult::kFailed;
  }
  Microsoft::WRL::ComPtr<IMFMediaEngineAudioEndpointId> endpoint;
  if (FAILED(engine_.As(&endpoint))) {
    // Interface available since Windows 10 1703.
    // 该接口自 Windows 10 1703 起提供。
    return RouteResult::kUnsupported;
  }
  HRESULT hr;
  if (device_id.has_value()) {
    const std::wstring wide = Utf8ToWide(device_id.value());
    hr = endpoint->SetAudioEndpointId(wide.c_str());
  } else {
    hr = endpoint->SetAudioEndpointId(nullptr);
  }
  if (FAILED(hr)) {
    return RouteResult::kFailed;
  }
  output_device_id_ = device_id;
  return RouteResult::kOk;
}

std::optional<int64_t> WindowsPlayer::Duration() {
  if (!engine_) {
    return std::nullopt;
  }
  const double seconds = engine_->GetDuration();
  if (std::isnan(seconds) || std::isinf(seconds) || seconds <= 0) {
    return std::nullopt;
  }
  return static_cast<int64_t>(seconds * 1000.0);
}

}  // namespace xue_hua_audio_windows
