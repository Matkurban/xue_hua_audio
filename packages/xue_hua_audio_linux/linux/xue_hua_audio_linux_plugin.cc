// Linux implementation of the xue_hua_audio plugin, built on GStreamer:
// playback uses `playbin`, recording uses an
// `autoaudiosrc ! level ! <encoder> ! filesink` pipeline where the `level`
// element provides the real-time amplitude (dB) for the waveform stream.
//
// xue_hua_audio 插件的 Linux 实现，基于 GStreamer：播放使用 `playbin`；
// 录音使用 `autoaudiosrc ! level ! <编码器> ! filesink` 管线，其中
// `level` 元素直接产出实时振幅（dB），供波形流使用。
#include "xue_hua_audio_linux_plugin_private.h"

#include <flutter_linux/flutter_linux.h>
#include <gst/gst.h>

#include <cstdio>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "messages.g.h"

#define XUE_HUA_AUDIO_LINUX_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_audio_linux_plugin_get_type(), \
                              XueHuaAudioLinuxPlugin))

// ---------------------------------------------------------------------------
// EventStream: an FlEventChannel wrapper buffering events until Dart listens.
// EventStream：在 Dart 订阅前缓冲事件的 FlEventChannel 封装。
// ---------------------------------------------------------------------------

struct EventStream {
  FlEventChannel* channel = nullptr;
  bool listening = false;
  std::vector<FlValue*> pending;  // owned refs / 持有引用

  ~EventStream() {
    for (FlValue* value : pending) {
      fl_value_unref(value);
    }
    if (channel != nullptr) {
      g_object_unref(channel);
    }
  }

  // Sends `value` (consumed) to Dart, buffering when nobody listens yet.
  // 将 `value`（转移所有权）发送给 Dart；若尚无订阅者则先缓冲。
  void Send(FlValue* value) {
    if (listening) {
      fl_event_channel_send(channel, value, nullptr, nullptr);
      fl_value_unref(value);
    } else if (pending.size() < 128) {
      pending.push_back(value);
    } else {
      fl_value_unref(value);
    }
  }

  void SendState(const char* state) {
    g_autoptr(FlValue) unused = nullptr;
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "type", fl_value_new_string("state"));
    fl_value_set_string_take(map, "state", fl_value_new_string(state));
    Send(map);
  }

  void SendError(const char* code, const char* message) {
    FlValue* map = fl_value_new_map();
    fl_value_set_string_take(map, "type", fl_value_new_string("error"));
    fl_value_set_string_take(map, "code", fl_value_new_string(code));
    fl_value_set_string_take(map, "message", fl_value_new_string(message));
    Send(map);
  }
};

static FlMethodErrorResponse* event_stream_listen_cb(FlEventChannel* channel,
                                                     FlValue* args,
                                                     gpointer user_data) {
  auto* stream = static_cast<EventStream*>(user_data);
  stream->listening = true;
  for (FlValue* value : stream->pending) {
    fl_event_channel_send(channel, value, nullptr, nullptr);
    fl_value_unref(value);
  }
  stream->pending.clear();
  return nullptr;
}

static FlMethodErrorResponse* event_stream_cancel_cb(FlEventChannel* channel,
                                                     FlValue* args,
                                                     gpointer user_data) {
  static_cast<EventStream*>(user_data)->listening = false;
  return nullptr;
}

static std::unique_ptr<EventStream> event_stream_new(
    FlBinaryMessenger* messenger, const std::string& name) {
  auto stream = std::make_unique<EventStream>();
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  stream->channel =
      fl_event_channel_new(messenger, name.c_str(), FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(stream->channel, event_stream_listen_cb,
                                       event_stream_cancel_cb, stream.get(),
                                       nullptr);
  return stream;
}

// ---------------------------------------------------------------------------
// Device enumeration helpers (GstDeviceMonitor).
// 设备枚举工具（GstDeviceMonitor）。
// ---------------------------------------------------------------------------

// Runs `callback` for every device of `device_class` ("Audio/Source" or
// "Audio/Sink"). / 对 `device_class`（"Audio/Source" 或 "Audio/Sink"）的
// 每个设备执行 `callback`。
template <typename Callback>
static void for_each_audio_device(const char* device_class,
                                  Callback callback) {
  GstDeviceMonitor* monitor = gst_device_monitor_new();
  gst_device_monitor_add_filter(monitor, device_class, nullptr);
  gst_device_monitor_start(monitor);
  GList* devices = gst_device_monitor_get_devices(monitor);
  for (GList* item = devices; item != nullptr; item = item->next) {
    callback(GST_DEVICE(item->data));
  }
  g_list_free_full(devices, gst_object_unref);
  gst_device_monitor_stop(monitor);
  gst_object_unref(monitor);
}

// Builds the Pigeon device list for `device_class`. The display name doubles
// as the id — GStreamer exposes no portable persistent identifier.
// 构建 `device_class` 的 Pigeon 设备列表。显示名称同时用作 id——GStreamer
// 没有可移植的持久设备标识。
static FlValue* list_audio_devices(const char* device_class) {
  FlValue* list = fl_value_new_list();
  for_each_audio_device(device_class, [list](GstDevice* device) {
    g_autofree gchar* name = gst_device_get_display_name(device);
    g_autoptr(XhaMessagesAudioDeviceMessage) message =
        xha_messages_audio_device_message_new(name, name);
    fl_value_append_take(
        list, fl_value_new_custom_object(
                  xha_messages_audio_device_message_type_id,
                  G_OBJECT(message)));
  });
  return list;
}

// Finds a device by its id (display name); returns a new ref or nullptr.
// 按 id（显示名称）查找设备；返回新引用或 nullptr。
static GstDevice* find_audio_device(const char* device_class,
                                    const std::string& id) {
  GstDevice* found = nullptr;
  for_each_audio_device(device_class, [&](GstDevice* device) {
    if (found != nullptr) {
      return;
    }
    g_autofree gchar* name = gst_device_get_display_name(device);
    if (id == name) {
      found = GST_DEVICE(gst_object_ref(device));
    }
  });
  return found;
}

// ---------------------------------------------------------------------------
// LinuxPlayer: one playbin-backed playback instance.
// LinuxPlayer：基于 playbin 的单个播放实例。
// ---------------------------------------------------------------------------

struct LinuxPlayer {
  GstElement* playbin = nullptr;
  guint bus_watch_id = 0;
  std::unique_ptr<EventStream> events;

  XhaMessagesAudioPlayerHostApiResponseHandle* pending_load = nullptr;
  XhaMessagesAudioPlayerHostApiResponseHandle* pending_seek = nullptr;
  double speed = 1.0;
  bool looping = false;
  bool started_once = false;
  bool stopped_by_user = false;
  std::string last_state;
  // Selected output device id, empty = system default. Applied through the
  // playbin `audio-sink` property, effective from the next setSource.
  // 已选择的输出设备 id；空串表示系统默认。通过 playbin 的 `audio-sink`
  // 属性生效，自下一次 setSource 起启用。
  std::string output_device_id;

  void EmitState(const char* state) {
    if (last_state == state) {
      return;
    }
    last_state = state;
    events->SendState(state);
  }

  // Duration in ms, or -1 when unknown. / 时长（毫秒），未知为 -1。
  int64_t DurationMs() {
    gint64 nanos = 0;
    if (!gst_element_query_duration(playbin, GST_FORMAT_TIME, &nanos) ||
        nanos < 0) {
      return -1;
    }
    return nanos / GST_MSECOND;
  }

  int64_t PositionMs() {
    gint64 nanos = 0;
    if (!gst_element_query_position(playbin, GST_FORMAT_TIME, &nanos) ||
        nanos < 0) {
      return 0;
    }
    return nanos / GST_MSECOND;
  }

  // Seeks to `position_ms` applying the current playback rate.
  // 以当前倍速跳转到 `position_ms`。
  bool Seek(int64_t position_ms) {
    return gst_element_seek(
        playbin, speed, GST_FORMAT_TIME,
        static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
        GST_SEEK_TYPE_SET, position_ms * GST_MSECOND, GST_SEEK_TYPE_NONE,
        GST_CLOCK_TIME_NONE);
  }

  ~LinuxPlayer() {
    if (bus_watch_id != 0) {
      g_source_remove(bus_watch_id);
    }
    if (playbin != nullptr) {
      gst_element_set_state(playbin, GST_STATE_NULL);
      gst_object_unref(playbin);
    }
  }
};

// ---------------------------------------------------------------------------
// LinuxRecorder: one GStreamer capture pipeline instance.
// LinuxRecorder：基于 GStreamer 采集管线的单个录音实例。
// ---------------------------------------------------------------------------

struct LinuxRecorder {
  GstElement* pipeline = nullptr;
  guint bus_watch_id = 0;
  std::unique_ptr<EventStream> events;

  XhaMessagesAudioRecorderHostApiResponseHandle* pending_stop = nullptr;
  std::string output_path;
  // Preferred input device id, empty = system default (autoaudiosrc).
  // 偏好的输入设备 id；空串表示系统默认（autoaudiosrc）。
  std::string preferred_device_id;
  bool recording = false;
  bool cancel_requested = false;
  double max_db = -160.0;

  void EmitState(const char* state) { events->SendState(state); }

  void Teardown() {
    if (bus_watch_id != 0) {
      g_source_remove(bus_watch_id);
      bus_watch_id = 0;
    }
    if (pipeline != nullptr) {
      gst_element_set_state(pipeline, GST_STATE_NULL);
      gst_object_unref(pipeline);
      pipeline = nullptr;
    }
    recording = false;
  }

  ~LinuxRecorder() { Teardown(); }
};

// ---------------------------------------------------------------------------
// Plugin object. / 插件对象。
// ---------------------------------------------------------------------------

struct _XueHuaAudioLinuxPlugin {
  GObject parent_instance;

  FlBinaryMessenger* messenger;
  std::map<int64_t, std::unique_ptr<LinuxPlayer>>* players;
  std::map<int64_t, std::unique_ptr<LinuxRecorder>>* recorders;
  int64_t next_player_id;
  int64_t next_recorder_id;
};

G_DEFINE_TYPE(XueHuaAudioLinuxPlugin, xue_hua_audio_linux_plugin, g_object_get_type())

static LinuxPlayer* player_of(XueHuaAudioLinuxPlugin* self, int64_t id) {
  auto it = self->players->find(id);
  return it == self->players->end() ? nullptr : it->second.get();
}

static LinuxRecorder* recorder_of(XueHuaAudioLinuxPlugin* self, int64_t id) {
  auto it = self->recorders->find(id);
  return it == self->recorders->end() ? nullptr : it->second.get();
}

// -- Player bus handling / 播放器总线消息处理 --------------------------------

static gboolean player_bus_cb(GstBus* bus, GstMessage* message,
                              gpointer user_data) {
  auto* player = static_cast<LinuxPlayer*>(user_data);
  switch (GST_MESSAGE_TYPE(message)) {
    case GST_MESSAGE_ASYNC_DONE: {
      // Preroll finished: the pending load (if any) can be resolved with the
      // duration; a pending seek is complete.
      // 预滚完成：可用时长回复挂起的加载请求；挂起的 seek 也已完成。
      if (player->pending_load != nullptr) {
        auto* handle = player->pending_load;
        player->pending_load = nullptr;
        const int64_t duration = player->DurationMs();
        FlValue* map = fl_value_new_map();
        fl_value_set_string_take(map, "type", fl_value_new_string("duration"));
        fl_value_set_string_take(map, "durationMs",
                                 duration < 0 ? fl_value_new_null()
                                              : fl_value_new_int(duration));
        player->events->Send(map);
        player->EmitState("ready");
        int64_t duration_value = duration;
        xha_messages_audio_player_host_api_respond_set_source(
            handle, duration < 0 ? nullptr : &duration_value);
      }
      if (player->pending_seek != nullptr) {
        auto* handle = player->pending_seek;
        player->pending_seek = nullptr;
        xha_messages_audio_player_host_api_respond_seek_to(handle);
      }
      break;
    }
    case GST_MESSAGE_STATE_CHANGED: {
      if (GST_MESSAGE_SRC(message) != GST_OBJECT(player->playbin)) {
        break;
      }
      GstState old_state, new_state, pending;
      gst_message_parse_state_changed(message, &old_state, &new_state,
                                      &pending);
      if (new_state == GST_STATE_PLAYING) {
        player->started_once = true;
        player->EmitState("playing");
      } else if (new_state == GST_STATE_PAUSED &&
                 old_state == GST_STATE_PLAYING) {
        if (player->stopped_by_user) {
          player->EmitState("stopped");
        } else if (player->last_state != "completed") {
          player->EmitState("paused");
        }
      }
      break;
    }
    case GST_MESSAGE_EOS: {
      if (player->looping) {
        player->Seek(0);
        break;
      }
      gst_element_set_state(player->playbin, GST_STATE_PAUSED);
      player->EmitState("completed");
      break;
    }
    case GST_MESSAGE_ERROR: {
      g_autoptr(GError) error = nullptr;
      g_autofree gchar* debug = nullptr;
      gst_message_parse_error(message, &error, &debug);
      const char* text = error != nullptr ? error->message : "Unknown error";
      if (player->pending_load != nullptr) {
        auto* handle = player->pending_load;
        player->pending_load = nullptr;
        xha_messages_audio_player_host_api_respond_error_set_source(
            handle, "sourceLoadFailed", text, nullptr);
      } else {
        player->events->SendError("playbackFailed", text);
        player->EmitState("error");
      }
      gst_element_set_state(player->playbin, GST_STATE_NULL);
      break;
    }
    default:
      break;
  }
  return TRUE;
}

// -- Recorder bus handling / 录音机总线消息处理 -------------------------------

static gboolean recorder_bus_cb(GstBus* bus, GstMessage* message,
                                gpointer user_data) {
  auto* recorder = static_cast<LinuxRecorder*>(user_data);
  switch (GST_MESSAGE_TYPE(message)) {
    case GST_MESSAGE_ELEMENT: {
      // The `level` element posts per-channel peaks in dB — exactly what the
      // amplitude stream needs. / `level` 元素按声道产出 dB 峰值，正是振幅流所需。
      const GstStructure* structure = gst_message_get_structure(message);
      if (structure == nullptr ||
          !gst_structure_has_name(structure, "level")) {
        break;
      }
      const GValue* peaks = gst_structure_get_value(structure, "peak");
      if (peaks == nullptr) {
        break;
      }
      double peak_db = -160.0;
      const guint channels = gst_value_list_get_size(peaks);
      for (guint i = 0; i < channels; ++i) {
        const GValue* value = gst_value_list_get_value(peaks, i);
        const double channel_db = g_value_get_double(value);
        if (channel_db > peak_db) {
          peak_db = channel_db;
        }
      }
      if (peak_db > recorder->max_db) {
        recorder->max_db = peak_db;
      }
      FlValue* map = fl_value_new_map();
      fl_value_set_string_take(map, "type", fl_value_new_string("amplitude"));
      fl_value_set_string_take(map, "current", fl_value_new_float(peak_db));
      fl_value_set_string_take(map, "max",
                               fl_value_new_float(recorder->max_db));
      recorder->events->Send(map);
      break;
    }
    case GST_MESSAGE_EOS: {
      // File is finalized once EOS reached the sink. / EOS 到达 sink 后文件完成。
      recorder->Teardown();
      recorder->EmitState("stopped");
      if (recorder->pending_stop != nullptr) {
        auto* handle = recorder->pending_stop;
        recorder->pending_stop = nullptr;
        if (recorder->cancel_requested) {
          std::remove(recorder->output_path.c_str());
          xha_messages_audio_recorder_host_api_respond_cancel(handle);
        } else {
          xha_messages_audio_recorder_host_api_respond_stop(
              handle, recorder->output_path.c_str());
        }
      }
      break;
    }
    case GST_MESSAGE_ERROR: {
      g_autoptr(GError) error = nullptr;
      g_autofree gchar* debug = nullptr;
      gst_message_parse_error(message, &error, &debug);
      const char* text = error != nullptr ? error->message : "Unknown error";
      recorder->events->SendError("recordingFailed", text);
      recorder->EmitState("error");
      if (recorder->pending_stop != nullptr) {
        auto* handle = recorder->pending_stop;
        recorder->pending_stop = nullptr;
        if (recorder->cancel_requested) {
          xha_messages_audio_recorder_host_api_respond_cancel(handle);
        } else {
          xha_messages_audio_recorder_host_api_respond_error_stop(
              handle, "recordingFailed", text, nullptr);
        }
      }
      recorder->Teardown();
      break;
    }
    default:
      break;
  }
  return TRUE;
}

// -- AudioPlayerHostApi vtable / 播放 Host API 实现 ---------------------------

static XhaMessagesAudioPlayerHostApiCreatePlayerResponse* handle_create_player(
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  const int64_t id = self->next_player_id++;

  auto player = std::make_unique<LinuxPlayer>();
  player->events = event_stream_new(
      self->messenger, "xue_hua_audio/player_events_" + std::to_string(id));
  player->playbin = gst_element_factory_make("playbin", nullptr);
  if (player->playbin == nullptr) {
    return xha_messages_audio_player_host_api_create_player_response_new_error(
        "playbackFailed", "GStreamer playbin element is not available",
        nullptr);
  }
  GstBus* gst_bus = gst_element_get_bus(player->playbin);
  player->bus_watch_id = gst_bus_add_watch(gst_bus, player_bus_cb, player.get());
  gst_object_unref(gst_bus);

  (*self->players)[id] = std::move(player);
  return xha_messages_audio_player_host_api_create_player_response_new(id);
}

static void handle_set_source(
    int64_t player_id, XhaMessagesAudioSourceMessage* source,
    XhaMessagesAudioPlayerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    xha_messages_audio_player_host_api_respond_error_set_source(
        response_handle, "instanceNotFound", "No such player", nullptr);
    return;
  }
  if (player->pending_load != nullptr) {
    xha_messages_audio_player_host_api_respond_error_set_source(
        player->pending_load, "sourceLoadFailed",
        "Replaced by a newer setSource call", nullptr);
  }
  player->pending_load = response_handle;
  player->started_once = false;
  player->stopped_by_user = false;
  player->last_state.clear();
  player->EmitState("loading");

  const gchar* uri_value = xha_messages_audio_source_message_get_uri(source);
  std::string uri;
  switch (xha_messages_audio_source_message_get_type_(source)) {
    case XHA_MESSAGES_SOURCE_TYPE_MESSAGE_URL:
      uri = uri_value;
      break;
    case XHA_MESSAGES_SOURCE_TYPE_MESSAGE_FILE: {
      g_autofree gchar* file_uri = gst_filename_to_uri(uri_value, nullptr);
      uri = file_uri != nullptr ? file_uri : "";
      break;
    }
    case XHA_MESSAGES_SOURCE_TYPE_MESSAGE_ASSET: {
      // Assets live next to the executable under data/flutter_assets/.
      // Asset 资源位于可执行文件旁的 data/flutter_assets/ 目录。
      g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
      g_autofree gchar* dir =
          g_path_get_dirname(exe_path != nullptr ? exe_path : ".");
      g_autofree gchar* asset_path =
          g_build_filename(dir, "data", "flutter_assets", uri_value, nullptr);
      g_autofree gchar* file_uri = gst_filename_to_uri(asset_path, nullptr);
      uri = file_uri != nullptr ? file_uri : "";
      break;
    }
  }

  gst_element_set_state(player->playbin, GST_STATE_NULL);
  g_object_set(player->playbin, "uri", uri.c_str(), nullptr);
  if (gst_element_set_state(player->playbin, GST_STATE_PAUSED) ==
      GST_STATE_CHANGE_FAILURE) {
    player->pending_load = nullptr;
    xha_messages_audio_player_host_api_respond_error_set_source(
        response_handle, "sourceLoadFailed", "Failed to start loading",
        nullptr);
  }
}

static XhaMessagesAudioPlayerHostApiPlayResponse* handle_play(
    int64_t player_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_play_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  player->stopped_by_user = false;
  if (player->last_state == "completed") {
    player->Seek(0);
    player->last_state.clear();
  }
  gst_element_set_state(player->playbin, GST_STATE_PLAYING);
  return xha_messages_audio_player_host_api_play_response_new();
}

static XhaMessagesAudioPlayerHostApiPauseResponse* handle_pause(
    int64_t player_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_pause_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  gst_element_set_state(player->playbin, GST_STATE_PAUSED);
  return xha_messages_audio_player_host_api_pause_response_new();
}

static XhaMessagesAudioPlayerHostApiStopResponse* handle_stop(
    int64_t player_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_stop_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  player->stopped_by_user = true;
  gst_element_set_state(player->playbin, GST_STATE_PAUSED);
  player->Seek(0);
  player->EmitState("stopped");
  return xha_messages_audio_player_host_api_stop_response_new();
}

static void handle_seek_to(
    int64_t player_id, int64_t position_ms,
    XhaMessagesAudioPlayerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    xha_messages_audio_player_host_api_respond_error_seek_to(
        response_handle, "instanceNotFound", "No such player", nullptr);
    return;
  }
  if (player->pending_seek != nullptr) {
    xha_messages_audio_player_host_api_respond_seek_to(player->pending_seek);
  }
  player->pending_seek = response_handle;
  if (!player->Seek(position_ms)) {
    player->pending_seek = nullptr;
    xha_messages_audio_player_host_api_respond_seek_to(response_handle);
  }
}

static XhaMessagesAudioPlayerHostApiSetVolumeResponse* handle_set_volume(
    int64_t player_id, double volume, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_set_volume_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  g_object_set(player->playbin, "volume", CLAMP(volume, 0.0, 1.0), nullptr);
  return xha_messages_audio_player_host_api_set_volume_response_new();
}

static XhaMessagesAudioPlayerHostApiSetSpeedResponse* handle_set_speed(
    int64_t player_id, double speed, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_set_speed_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  player->speed = speed;
  // Rate changes are applied through a non-flushing seek at the current
  // position. / 倍速变更通过在当前位置执行 seek 应用。
  player->Seek(player->PositionMs());
  return xha_messages_audio_player_host_api_set_speed_response_new();
}

static XhaMessagesAudioPlayerHostApiSetLoopingResponse* handle_set_looping(
    int64_t player_id, gboolean looping, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_set_looping_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  player->looping = looping;
  return xha_messages_audio_player_host_api_set_looping_response_new();
}

static XhaMessagesAudioPlayerHostApiGetPositionResponse* handle_get_position(
    int64_t player_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_get_position_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  return xha_messages_audio_player_host_api_get_position_response_new(
      player->PositionMs());
}

static XhaMessagesAudioPlayerHostApiGetDurationResponse* handle_get_duration(
    int64_t player_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    return xha_messages_audio_player_host_api_get_duration_response_new_error(
        "instanceNotFound", "No such player", nullptr);
  }
  int64_t duration = player->DurationMs();
  return xha_messages_audio_player_host_api_get_duration_response_new(
      duration < 0 ? nullptr : &duration);
}

static void handle_list_output_devices(
    XhaMessagesAudioPlayerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  g_autoptr(FlValue) list = list_audio_devices("Audio/Sink");
  xha_messages_audio_player_host_api_respond_list_output_devices(
      response_handle, list);
}

static void handle_get_output_device(
    int64_t player_id,
    XhaMessagesAudioPlayerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    xha_messages_audio_player_host_api_respond_error_get_output_device(
        response_handle, "instanceNotFound", "No such player", nullptr);
    return;
  }
  if (player->output_device_id.empty()) {
    xha_messages_audio_player_host_api_respond_get_output_device(
        response_handle, nullptr);
    return;
  }
  g_autoptr(XhaMessagesAudioDeviceMessage) message =
      xha_messages_audio_device_message_new(player->output_device_id.c_str(),
                                            player->output_device_id.c_str());
  xha_messages_audio_player_host_api_respond_get_output_device(
      response_handle, message);
}

static void handle_set_output_device(
    int64_t player_id, const gchar* device_id,
    XhaMessagesAudioPlayerHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxPlayer* player = player_of(self, player_id);
  if (player == nullptr) {
    xha_messages_audio_player_host_api_respond_error_set_output_device(
        response_handle, "instanceNotFound", "No such player", nullptr);
    return;
  }
  if (device_id == nullptr || *device_id == '\0') {
    // Back to the default sink; effective from the next setSource.
    // 恢复默认输出；自下一次 setSource 起生效。
    g_object_set(player->playbin, "audio-sink", nullptr, nullptr);
    player->output_device_id.clear();
    xha_messages_audio_player_host_api_respond_set_output_device(
        response_handle);
    return;
  }
  GstDevice* device = find_audio_device("Audio/Sink", device_id);
  if (device == nullptr) {
    xha_messages_audio_player_host_api_respond_error_set_output_device(
        response_handle, "deviceNotFound",
        "No output device with the given id", nullptr);
    return;
  }
  GstElement* sink = gst_device_create_element(device, nullptr);
  gst_object_unref(device);
  if (sink == nullptr) {
    xha_messages_audio_player_host_api_respond_error_set_output_device(
        response_handle, "playbackFailed",
        "Cannot create an element for the output device", nullptr);
    return;
  }
  // playbin sinks the floating ref; the sink is used from the next
  // setSource. / playbin 吸收浮动引用；该 sink 自下一次 setSource 起使用。
  g_object_set(player->playbin, "audio-sink", sink, nullptr);
  player->output_device_id = device_id;
  xha_messages_audio_player_host_api_respond_set_output_device(
      response_handle);
}

static XhaMessagesAudioPlayerHostApiDisposePlayerResponse*
handle_dispose_player(int64_t player_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  self->players->erase(player_id);
  return xha_messages_audio_player_host_api_dispose_player_response_new();
}

// -- AudioRecorderHostApi vtable / 录音 Host API 实现 -------------------------

static XhaMessagesAudioRecorderHostApiCreateRecorderResponse*
handle_create_recorder(gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  const int64_t id = self->next_recorder_id++;
  auto recorder = std::make_unique<LinuxRecorder>();
  recorder->events = event_stream_new(
      self->messenger, "xue_hua_audio/recorder_events_" + std::to_string(id));
  (*self->recorders)[id] = std::move(recorder);
  return xha_messages_audio_recorder_host_api_create_recorder_response_new(id);
}

static void handle_has_permission(
    XhaMessagesAudioRecorderHostApiResponseHandle* response_handle,
    gpointer user_data) {
  // Desktop Linux has no microphone permission prompt.
  // 桌面 Linux 没有麦克风权限弹窗机制。
  xha_messages_audio_recorder_host_api_respond_has_permission(response_handle,
                                                              TRUE);
}

static void handle_list_input_devices(
    XhaMessagesAudioRecorderHostApiResponseHandle* response_handle,
    gpointer user_data) {
  g_autoptr(FlValue) list = list_audio_devices("Audio/Source");
  xha_messages_audio_recorder_host_api_respond_list_input_devices(
      response_handle, list);
}

static void handle_get_input_device(
    int64_t recorder_id,
    XhaMessagesAudioRecorderHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxRecorder* recorder = recorder_of(self, recorder_id);
  if (recorder == nullptr) {
    xha_messages_audio_recorder_host_api_respond_error_get_input_device(
        response_handle, "instanceNotFound", "No such recorder", nullptr);
    return;
  }
  if (recorder->preferred_device_id.empty()) {
    xha_messages_audio_recorder_host_api_respond_get_input_device(
        response_handle, nullptr);
    return;
  }
  g_autoptr(XhaMessagesAudioDeviceMessage) message =
      xha_messages_audio_device_message_new(
          recorder->preferred_device_id.c_str(),
          recorder->preferred_device_id.c_str());
  xha_messages_audio_recorder_host_api_respond_get_input_device(
      response_handle, message);
}

static void handle_set_input_device(
    int64_t recorder_id, const gchar* device_id,
    XhaMessagesAudioRecorderHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxRecorder* recorder = recorder_of(self, recorder_id);
  if (recorder == nullptr) {
    xha_messages_audio_recorder_host_api_respond_error_set_input_device(
        response_handle, "instanceNotFound", "No such recorder", nullptr);
    return;
  }
  if (recorder->recording) {
    xha_messages_audio_recorder_host_api_respond_error_set_input_device(
        response_handle, "invalidState",
        "Cannot switch the input device while recording on Linux", nullptr);
    return;
  }
  if (device_id == nullptr || *device_id == '\0') {
    recorder->preferred_device_id.clear();
    xha_messages_audio_recorder_host_api_respond_set_input_device(
        response_handle);
    return;
  }
  GstDevice* device = find_audio_device("Audio/Source", device_id);
  if (device == nullptr) {
    xha_messages_audio_recorder_host_api_respond_error_set_input_device(
        response_handle, "deviceNotFound",
        "No input device with the given id", nullptr);
    return;
  }
  gst_object_unref(device);
  recorder->preferred_device_id = device_id;
  xha_messages_audio_recorder_host_api_respond_set_input_device(
      response_handle);
}

static void handle_start(
    int64_t recorder_id, XhaMessagesRecordConfigMessage* config,
    const gchar* path,
    XhaMessagesAudioRecorderHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxRecorder* recorder = recorder_of(self, recorder_id);
  if (recorder == nullptr) {
    xha_messages_audio_recorder_host_api_respond_error_start(
        response_handle, "instanceNotFound", "No such recorder", nullptr);
    return;
  }
  if (recorder->recording) {
    xha_messages_audio_recorder_host_api_respond_error_start(
        response_handle, "invalidState", "Recorder is already recording",
        nullptr);
    return;
  }

  const int64_t sample_rate =
      xha_messages_record_config_message_get_sample_rate(config);
  const int64_t channels =
      xha_messages_record_config_message_get_num_channels(config);
  const int64_t interval_ms =
      xha_messages_record_config_message_get_amplitude_interval_ms(config);

  // Encoder branch of the pipeline. / 管线的编码分支。
  std::string encoder_branch;
  switch (xha_messages_record_config_message_get_encoder(config)) {
    case XHA_MESSAGES_ENCODER_MESSAGE_WAV:
      encoder_branch = "wavenc";
      break;
    case XHA_MESSAGES_ENCODER_MESSAGE_OPUS:
      encoder_branch = "opusenc ! oggmux";
      break;
    case XHA_MESSAGES_ENCODER_MESSAGE_AAC_LC:
      encoder_branch = "avenc_aac ! mp4mux";
      break;
  }

  // The per-start config id wins over the instance-level preference.
  // start 时传入的设备 id 优先于实例级偏好。
  const gchar* config_device =
      xha_messages_record_config_message_get_device_id(config);
  std::string wanted_device_id = recorder->preferred_device_id;
  if (config_device != nullptr && *config_device != '\0') {
    wanted_device_id = config_device;
  }

  // Capture source: the selected device, or autoaudiosrc for the default.
  // 采集源：已选择的设备，或默认的 autoaudiosrc。
  GstElement* source = nullptr;
  if (!wanted_device_id.empty()) {
    GstDevice* device = find_audio_device("Audio/Source", wanted_device_id);
    if (device == nullptr) {
      xha_messages_audio_recorder_host_api_respond_error_start(
          response_handle, "deviceNotFound",
          "No input device with the given id", nullptr);
      return;
    }
    source = gst_device_create_element(device, nullptr);
    gst_object_unref(device);
  } else {
    source = gst_element_factory_make("autoaudiosrc", nullptr);
  }
  if (source == nullptr) {
    xha_messages_audio_recorder_host_api_respond_error_start(
        response_handle, "recordingFailed",
        "Cannot create the audio capture source", nullptr);
    return;
  }

  g_autofree gchar* description = g_strdup_printf(
      "audioconvert ! audioresample ! "
      "audio/x-raw,rate=%d,channels=%d ! "
      "level name=xh_level interval=%" G_GINT64_FORMAT " ! %s ! "
      "filesink location=\"%s\"",
      static_cast<int>(sample_rate), static_cast<int>(channels),
      interval_ms * GST_MSECOND, encoder_branch.c_str(), path);

  g_autoptr(GError) error = nullptr;
  GstElement* chain =
      gst_parse_bin_from_description(description, TRUE, &error);
  if (chain == nullptr) {
    gst_object_unref(source);
    xha_messages_audio_recorder_host_api_respond_error_start(
        response_handle, "unsupportedEncoder",
        error != nullptr ? error->message
                         : "Failed to build the recording pipeline",
        nullptr);
    return;
  }

  GstElement* pipeline = gst_pipeline_new(nullptr);
  gst_bin_add_many(GST_BIN(pipeline), source, chain, nullptr);
  if (!gst_element_link(source, chain)) {
    gst_object_unref(pipeline);
    xha_messages_audio_recorder_host_api_respond_error_start(
        response_handle, "recordingFailed",
        "Failed to link the capture source", nullptr);
    return;
  }

  recorder->pipeline = pipeline;
  recorder->output_path = path;
  recorder->max_db = -160.0;
  recorder->cancel_requested = false;

  GstBus* gst_bus = gst_element_get_bus(pipeline);
  recorder->bus_watch_id = gst_bus_add_watch(gst_bus, recorder_bus_cb, recorder);
  gst_object_unref(gst_bus);

  if (gst_element_set_state(pipeline, GST_STATE_PLAYING) ==
      GST_STATE_CHANGE_FAILURE) {
    recorder->Teardown();
    xha_messages_audio_recorder_host_api_respond_error_start(
        response_handle, "recordingFailed", "Failed to start the pipeline",
        nullptr);
    return;
  }

  recorder->recording = true;
  recorder->EmitState("recording");
  xha_messages_audio_recorder_host_api_respond_start(response_handle);
}

static XhaMessagesAudioRecorderHostApiPauseResponse* handle_recorder_pause(
    int64_t recorder_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxRecorder* recorder = recorder_of(self, recorder_id);
  if (recorder == nullptr) {
    return xha_messages_audio_recorder_host_api_pause_response_new_error(
        "instanceNotFound", "No such recorder", nullptr);
  }
  if (recorder->recording && recorder->pipeline != nullptr) {
    gst_element_set_state(recorder->pipeline, GST_STATE_PAUSED);
    recorder->EmitState("paused");
  }
  return xha_messages_audio_recorder_host_api_pause_response_new();
}

static XhaMessagesAudioRecorderHostApiResumeResponse* handle_recorder_resume(
    int64_t recorder_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxRecorder* recorder = recorder_of(self, recorder_id);
  if (recorder == nullptr) {
    return xha_messages_audio_recorder_host_api_resume_response_new_error(
        "instanceNotFound", "No such recorder", nullptr);
  }
  if (recorder->recording && recorder->pipeline != nullptr) {
    gst_element_set_state(recorder->pipeline, GST_STATE_PLAYING);
    recorder->EmitState("recording");
  }
  return xha_messages_audio_recorder_host_api_resume_response_new();
}

static void finish_recorder(LinuxRecorder* recorder,
                            XhaMessagesAudioRecorderHostApiResponseHandle*
                                response_handle,
                            bool cancel) {
  if (!recorder->recording || recorder->pipeline == nullptr) {
    if (cancel) {
      xha_messages_audio_recorder_host_api_respond_cancel(response_handle);
    } else {
      xha_messages_audio_recorder_host_api_respond_stop(response_handle,
                                                        nullptr);
    }
    return;
  }
  recorder->cancel_requested = cancel;
  recorder->pending_stop = response_handle;
  // Send EOS so the muxer/encoder can finalize the file; the bus watch
  // responds once EOS reaches the sink.
  // 发送 EOS 以便封装器/编码器完成文件收尾；EOS 到达 sink 后由总线回调回复。
  gst_element_set_state(recorder->pipeline, GST_STATE_PLAYING);
  gst_element_send_event(recorder->pipeline, gst_event_new_eos());
}

static void handle_recorder_stop(
    int64_t recorder_id,
    XhaMessagesAudioRecorderHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxRecorder* recorder = recorder_of(self, recorder_id);
  if (recorder == nullptr) {
    xha_messages_audio_recorder_host_api_respond_error_stop(
        response_handle, "instanceNotFound", "No such recorder", nullptr);
    return;
  }
  finish_recorder(recorder, response_handle, false);
}

static void handle_recorder_cancel(
    int64_t recorder_id,
    XhaMessagesAudioRecorderHostApiResponseHandle* response_handle,
    gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  LinuxRecorder* recorder = recorder_of(self, recorder_id);
  if (recorder == nullptr) {
    xha_messages_audio_recorder_host_api_respond_error_cancel(
        response_handle, "instanceNotFound", "No such recorder", nullptr);
    return;
  }
  finish_recorder(recorder, response_handle, true);
}

static XhaMessagesAudioRecorderHostApiDisposeRecorderResponse*
handle_dispose_recorder(int64_t recorder_id, gpointer user_data) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(user_data);
  self->recorders->erase(recorder_id);
  return xha_messages_audio_recorder_host_api_dispose_recorder_response_new();
}

// -- GObject boilerplate / GObject 样板代码 -----------------------------------

static void xue_hua_audio_linux_plugin_dispose(GObject* object) {
  auto* self = XUE_HUA_AUDIO_LINUX_PLUGIN(object);
  delete self->players;
  self->players = nullptr;
  delete self->recorders;
  self->recorders = nullptr;
  G_OBJECT_CLASS(xue_hua_audio_linux_plugin_parent_class)->dispose(object);
}

static void xue_hua_audio_linux_plugin_class_init(
    XueHuaAudioLinuxPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_audio_linux_plugin_dispose;
}

static void xue_hua_audio_linux_plugin_init(XueHuaAudioLinuxPlugin* self) {
  self->players = new std::map<int64_t, std::unique_ptr<LinuxPlayer>>();
  self->recorders = new std::map<int64_t, std::unique_ptr<LinuxRecorder>>();
  self->next_player_id = 1;
  self->next_recorder_id = 1;
}

static const XhaMessagesAudioPlayerHostApiVTable player_vtable = {
    .create_player = handle_create_player,
    .set_source = handle_set_source,
    .play = handle_play,
    .pause = handle_pause,
    .stop = handle_stop,
    .seek_to = handle_seek_to,
    .set_volume = handle_set_volume,
    .set_speed = handle_set_speed,
    .set_looping = handle_set_looping,
    .get_position = handle_get_position,
    .get_duration = handle_get_duration,
    .list_output_devices = handle_list_output_devices,
    .get_output_device = handle_get_output_device,
    .set_output_device = handle_set_output_device,
    .dispose_player = handle_dispose_player,
};

static const XhaMessagesAudioRecorderHostApiVTable recorder_vtable = {
    .create_recorder = handle_create_recorder,
    .has_permission = handle_has_permission,
    .list_input_devices = handle_list_input_devices,
    .get_input_device = handle_get_input_device,
    .set_input_device = handle_set_input_device,
    .start = handle_start,
    .pause = handle_recorder_pause,
    .resume = handle_recorder_resume,
    .stop = handle_recorder_stop,
    .cancel = handle_recorder_cancel,
    .dispose_recorder = handle_dispose_recorder,
};

void xue_hua_audio_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  gst_init(nullptr, nullptr);

  XueHuaAudioLinuxPlugin* plugin = XUE_HUA_AUDIO_LINUX_PLUGIN(
      g_object_new(xue_hua_audio_linux_plugin_get_type(), nullptr));
  plugin->messenger = fl_plugin_registrar_get_messenger(registrar);

  xha_messages_audio_player_host_api_set_method_handlers(
      plugin->messenger, nullptr, &player_vtable, g_object_ref(plugin),
      g_object_unref);
  xha_messages_audio_recorder_host_api_set_method_handlers(
      plugin->messenger, nullptr, &recorder_vtable, g_object_ref(plugin),
      g_object_unref);

  g_object_unref(plugin);
}
