#include "xue_hua_audio_windows_plugin.h"

#include <flutter/plugin_registrar_windows.h>
#include <functiondiscoverykeys_devpkey.h>
#include <mfapi.h>
#include <mmdeviceapi.h>
#include <windows.h>
#include <wrl/client.h>

#include <memory>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace xue_hua_audio_windows {

namespace {

// Converts a wide string to UTF-8. / 将宽字符串转换为 UTF-8。
std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  const int length =
      WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                          nullptr, 0, nullptr, nullptr);
  std::string utf8(length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                      utf8.data(), length, nullptr, nullptr);
  return utf8;
}

// Resolves an AudioSourceMessage to a URL the media engine understands.
// 将 AudioSourceMessage 解析为媒体引擎可识别的 URL。
std::string ResolveUrl(const AudioSourceMessage& source) {
  switch (source.type()) {
    case SourceTypeMessage::kUrl:
      return source.uri();
    case SourceTypeMessage::kFile:
      return "file:///" + source.uri();
    case SourceTypeMessage::kAsset: {
      // Assets live next to the executable under data/flutter_assets/.
      // Asset 资源位于可执行文件旁的 data/flutter_assets/ 目录。
      wchar_t exe_path[MAX_PATH];
      GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
      std::wstring dir(exe_path);
      const size_t slash = dir.find_last_of(L"\\/");
      dir = dir.substr(0, slash);
      return "file:///" + WideToUtf8(dir) + "/data/flutter_assets/" +
             source.uri();
    }
  }
  return source.uri();
}

// Enumerates active audio endpoints of the given flow (eRender/eCapture).
// Returns false when the enumerator cannot be created.
// 枚举指定方向（eRender/eCapture）的活动音频端点；无法创建枚举器时返回
// false。
bool EnumerateEndpoints(EDataFlow flow,
                        std::vector<AudioDeviceMessage>* out) {
  ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    return false;
  }
  ComPtr<IMMDeviceCollection> collection;
  hr = enumerator->EnumAudioEndpoints(flow, DEVICE_STATE_ACTIVE, &collection);
  if (FAILED(hr)) {
    return false;
  }
  UINT count = 0;
  collection->GetCount(&count);
  for (UINT i = 0; i < count; ++i) {
    ComPtr<IMMDevice> device;
    if (FAILED(collection->Item(i, &device))) {
      continue;
    }
    LPWSTR device_id = nullptr;
    if (FAILED(device->GetId(&device_id))) {
      continue;
    }
    std::string id = WideToUtf8(device_id);
    CoTaskMemFree(device_id);

    std::string label = flow == eCapture ? "Microphone" : "Speaker";
    ComPtr<IPropertyStore> properties;
    if (SUCCEEDED(device->OpenPropertyStore(STGM_READ, &properties))) {
      PROPVARIANT value;
      PropVariantInit(&value);
      if (SUCCEEDED(properties->GetValue(PKEY_Device_FriendlyName, &value)) &&
          value.vt == VT_LPWSTR) {
        label = WideToUtf8(value.pwszVal);
      }
      PropVariantClear(&value);
    }
    out->emplace_back(id, label);
  }
  return true;
}

// Finds one endpoint message by id. / 按 id 查找单个端点消息。
std::optional<AudioDeviceMessage> EndpointById(EDataFlow flow,
                                               const std::string& device_id) {
  std::vector<AudioDeviceMessage> devices;
  if (!EnumerateEndpoints(flow, &devices)) {
    return std::nullopt;
  }
  for (auto& device : devices) {
    if (device.id() == device_id) {
      return device;
    }
  }
  return std::nullopt;
}

}  // namespace

// static
void XueHuaAudioWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<XueHuaAudioWindowsPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

XueHuaAudioWindowsPlugin::XueHuaAudioWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  MFStartup(MF_VERSION, MFSTARTUP_LITE);
  dispatcher_ = std::make_shared<MainThreadDispatcher>();
  player_api_ = std::make_unique<PlayerApi>(this);
  recorder_api_ = std::make_unique<RecorderApi>(this);
  AudioPlayerHostApi::SetUp(registrar->messenger(), player_api_.get());
  AudioRecorderHostApi::SetUp(registrar->messenger(), recorder_api_.get());
}

XueHuaAudioWindowsPlugin::~XueHuaAudioWindowsPlugin() {
  AudioPlayerHostApi::SetUp(registrar_->messenger(), nullptr);
  AudioRecorderHostApi::SetUp(registrar_->messenger(), nullptr);
  players_.clear();
  recorders_.clear();
  MFShutdown();
}

// -- PlayerApi ---------------------------------------------------------------

WindowsPlayer* PlayerApi::PlayerOf(int64_t id) {
  const auto it = plugin_->players_.find(id);
  return it == plugin_->players_.end() ? nullptr : it->second.get();
}

ErrorOr<int64_t> PlayerApi::CreatePlayer() {
  const int64_t id = plugin_->next_player_id_++;
  plugin_->players_[id] = std::make_unique<WindowsPlayer>(
      plugin_->registrar_->messenger(), plugin_->dispatcher_, id);
  return id;
}

void PlayerApi::SetSource(
    int64_t player_id, const AudioSourceMessage& source,
    std::function<void(ErrorOr<std::optional<int64_t>> reply)> result) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id)));
    return;
  }
  player->SetSource(
      ResolveUrl(source),
      [result](std::optional<int64_t> duration_ms,
               const std::optional<std::string>& error) {
        if (error.has_value()) {
          result(FlutterError("sourceLoadFailed", error.value()));
        } else {
          result(ErrorOr<std::optional<int64_t>>(duration_ms));
        }
      });
}

std::optional<FlutterError> PlayerApi::Play(int64_t player_id) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  player->Play();
  return std::nullopt;
}

std::optional<FlutterError> PlayerApi::Pause(int64_t player_id) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  player->Pause();
  return std::nullopt;
}

std::optional<FlutterError> PlayerApi::Stop(int64_t player_id) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  player->Stop();
  return std::nullopt;
}

void PlayerApi::SeekTo(
    int64_t player_id, int64_t position_ms,
    std::function<void(std::optional<FlutterError> reply)> result) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id)));
    return;
  }
  player->SeekTo(position_ms, [result]() { result(std::nullopt); });
}

std::optional<FlutterError> PlayerApi::SetVolume(int64_t player_id,
                                                 double volume) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  player->SetVolume(volume);
  return std::nullopt;
}

std::optional<FlutterError> PlayerApi::SetSpeed(int64_t player_id,
                                                double speed) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  player->SetSpeed(speed);
  return std::nullopt;
}

std::optional<FlutterError> PlayerApi::SetLooping(int64_t player_id,
                                                  bool looping) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  player->SetLooping(looping);
  return std::nullopt;
}

ErrorOr<int64_t> PlayerApi::GetPosition(int64_t player_id) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  return player->Position();
}

ErrorOr<std::optional<int64_t>> PlayerApi::GetDuration(int64_t player_id) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    return FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id));
  }
  return ErrorOr<std::optional<int64_t>>(player->Duration());
}

void PlayerApi::ListOutputDevices(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  std::vector<AudioDeviceMessage> devices;
  if (!EnumerateEndpoints(eRender, &devices)) {
    result(FlutterError("playbackFailed", "Failed to enumerate devices"));
    return;
  }
  flutter::EncodableList list;
  for (auto& device : devices) {
    list.push_back(flutter::CustomEncodableValue(device));
  }
  result(list);
}

void PlayerApi::GetOutputDevice(
    int64_t player_id,
    std::function<void(ErrorOr<std::optional<AudioDeviceMessage>> reply)>
        result) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id)));
    return;
  }
  const auto& device_id = player->OutputDeviceId();
  if (!device_id.has_value()) {
    result(ErrorOr<std::optional<AudioDeviceMessage>>(std::nullopt));
    return;
  }
  result(ErrorOr<std::optional<AudioDeviceMessage>>(
      EndpointById(eRender, device_id.value())));
}

void PlayerApi::SetOutputDevice(
    int64_t player_id, const std::string* device_id,
    std::function<void(std::optional<FlutterError> reply)> result) {
  auto* player = PlayerOf(player_id);
  if (player == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No player with id " + std::to_string(player_id)));
    return;
  }
  std::optional<std::string> wanted;
  if (device_id != nullptr && !device_id->empty()) {
    wanted = *device_id;
    if (!EndpointById(eRender, *device_id).has_value()) {
      result(FlutterError("deviceNotFound",
                          "No output device with id " + *device_id));
      return;
    }
  }
  switch (player->SetOutputDevice(wanted)) {
    case WindowsPlayer::RouteResult::kOk:
      result(std::nullopt);
      break;
    case WindowsPlayer::RouteResult::kUnsupported:
      result(FlutterError(
          "unsupported",
          "Output device selection requires Windows 10 1703 or newer"));
      break;
    case WindowsPlayer::RouteResult::kFailed:
      result(FlutterError("playbackFailed", "Failed to set output device"));
      break;
  }
}

std::optional<FlutterError> PlayerApi::DisposePlayer(int64_t player_id) {
  plugin_->players_.erase(player_id);
  return std::nullopt;
}

// -- RecorderApi ---------------------------------------------------------------

WindowsRecorder* RecorderApi::RecorderOf(int64_t id) {
  const auto it = plugin_->recorders_.find(id);
  return it == plugin_->recorders_.end() ? nullptr : it->second.get();
}

ErrorOr<int64_t> RecorderApi::CreateRecorder() {
  const int64_t id = plugin_->next_recorder_id_++;
  plugin_->recorders_[id] = std::make_unique<WindowsRecorder>(
      plugin_->registrar_->messenger(), plugin_->dispatcher_, id);
  return id;
}

void RecorderApi::HasPermission(
    std::function<void(ErrorOr<bool> reply)> result) {
  // Windows exposes no runtime prompt API; capture simply fails when the
  // OS privacy settings block the microphone.
  // Windows 没有运行时权限弹窗 API；若系统隐私设置禁用麦克风，采集会直接失败。
  result(true);
}

void RecorderApi::ListInputDevices(
    std::function<void(ErrorOr<flutter::EncodableList> reply)> result) {
  std::vector<AudioDeviceMessage> devices;
  if (!EnumerateEndpoints(eCapture, &devices)) {
    result(FlutterError("recordingFailed", "Failed to enumerate devices"));
    return;
  }
  flutter::EncodableList list;
  for (auto& device : devices) {
    list.push_back(flutter::CustomEncodableValue(device));
  }
  result(list);
}

void RecorderApi::GetInputDevice(
    int64_t recorder_id,
    std::function<void(ErrorOr<std::optional<AudioDeviceMessage>> reply)>
        result) {
  auto* recorder = RecorderOf(recorder_id);
  if (recorder == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No recorder with id " + std::to_string(recorder_id)));
    return;
  }
  const auto& device_id = recorder->InputDeviceId();
  if (!device_id.has_value()) {
    result(ErrorOr<std::optional<AudioDeviceMessage>>(std::nullopt));
    return;
  }
  result(ErrorOr<std::optional<AudioDeviceMessage>>(
      EndpointById(eCapture, device_id.value())));
}

void RecorderApi::SetInputDevice(
    int64_t recorder_id, const std::string* device_id,
    std::function<void(std::optional<FlutterError> reply)> result) {
  auto* recorder = RecorderOf(recorder_id);
  if (recorder == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No recorder with id " + std::to_string(recorder_id)));
    return;
  }
  std::optional<std::string> wanted;
  if (device_id != nullptr && !device_id->empty()) {
    wanted = *device_id;
    if (!EndpointById(eCapture, *device_id).has_value()) {
      result(FlutterError("deviceNotFound",
                          "No input device with id " + *device_id));
      return;
    }
  }
  if (!recorder->SetInputDevice(wanted)) {
    result(FlutterError(
        "invalidState",
        "Cannot switch the input device while recording on Windows"));
    return;
  }
  result(std::nullopt);
}

void RecorderApi::Start(
    int64_t recorder_id, const RecordConfigMessage& config,
    const std::string& path,
    std::function<void(std::optional<FlutterError> reply)> result) {
  auto* recorder = RecorderOf(recorder_id);
  if (recorder == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No recorder with id " + std::to_string(recorder_id)));
    return;
  }
  const auto error = recorder->Start(config, path);
  if (error.has_value()) {
    result(FlutterError("recordingFailed", error.value()));
  } else {
    result(std::nullopt);
  }
}

std::optional<FlutterError> RecorderApi::Pause(int64_t recorder_id) {
  auto* recorder = RecorderOf(recorder_id);
  if (recorder == nullptr) {
    return FlutterError("instanceNotFound",
                        "No recorder with id " + std::to_string(recorder_id));
  }
  recorder->Pause();
  return std::nullopt;
}

std::optional<FlutterError> RecorderApi::Resume(int64_t recorder_id) {
  auto* recorder = RecorderOf(recorder_id);
  if (recorder == nullptr) {
    return FlutterError("instanceNotFound",
                        "No recorder with id " + std::to_string(recorder_id));
  }
  recorder->Resume();
  return std::nullopt;
}

void RecorderApi::Stop(
    int64_t recorder_id,
    std::function<void(ErrorOr<std::optional<std::string>> reply)> result) {
  auto* recorder = RecorderOf(recorder_id);
  if (recorder == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No recorder with id " + std::to_string(recorder_id)));
    return;
  }
  result(ErrorOr<std::optional<std::string>>(recorder->Stop()));
}

void RecorderApi::Cancel(
    int64_t recorder_id,
    std::function<void(std::optional<FlutterError> reply)> result) {
  auto* recorder = RecorderOf(recorder_id);
  if (recorder == nullptr) {
    result(FlutterError("instanceNotFound",
                        "No recorder with id " + std::to_string(recorder_id)));
    return;
  }
  recorder->Cancel();
  result(std::nullopt);
}

std::optional<FlutterError> RecorderApi::DisposeRecorder(int64_t recorder_id) {
  plugin_->recorders_.erase(recorder_id);
  return std::nullopt;
}

}  // namespace xue_hua_audio_windows
