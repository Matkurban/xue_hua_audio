use crate::error::XueHuaAudioError;
use crate::recording::{list_input_devices, stop_shared_recorder, XueHuaAudioRecorder};
use crate::track::{
    open_decoder_from_bytes, open_decoder_from_path, TrackSharedState, XueHuaAudioTrack,
};
use rodio::stream::DeviceSinkBuilder;
use rodio::Player;
use rodio::Source;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};

static NEXT_TRACK_ID: AtomicU64 = AtomicU64::new(1);
static NEXT_RECORDER_ID: AtomicU64 = AtomicU64::new(1);

pub(crate) type Registry = Arc<Mutex<Vec<RegistryEntry>>>;
pub(crate) type RecorderRegistry = Arc<Mutex<Vec<RecorderRegistryEntry>>>;

pub(crate) struct RegistryEntry {
    pub(crate) id: u64,
    pub(crate) player: Arc<Player>,
    pub(crate) shared: Arc<TrackSharedState>,
}

pub(crate) struct RecorderRegistryEntry {
    pub(crate) id: u64,
    pub(crate) shared: Arc<crate::recording::RecorderShared>,
}

pub(crate) fn next_track_id() -> u64 {
    NEXT_TRACK_ID.fetch_add(1, Ordering::Relaxed)
}

pub(crate) fn next_recorder_id() -> u64 {
    NEXT_RECORDER_ID.fetch_add(1, Ordering::Relaxed)
}

pub(crate) fn unregister_track(registry: &Registry, id: u64) {
    let mut guard = registry.lock().expect("registry lock poisoned");
    guard.retain(|entry| entry.id != id);
}

pub(crate) fn unregister_recorder(registry: &RecorderRegistry, id: u64) {
    let mut guard = registry.lock().expect("recorder registry lock poisoned");
    guard.retain(|entry| entry.id != id);
}

/// 应用级音频引擎，持有 `MixerDeviceSink` 并管理多轨并发播放。
///
/// # rodio 0.22.2 多轨混音原理
///
/// `MixerDeviceSink` 是系统音频输出的容器，**必须长期存活**；drop 后所有音轨静音。
///
/// 通过 `device_sink.mixer()` 取得 `&Mixer`（混音入口）。每次调用
/// `Player::connect_new(mixer)` 都会向同一混音器注册一条独立播放队列；
/// 各 `Player` 可独立 pause / set_volume / stop，rodio 在输出线程混合后送往 OS。
pub struct XueHuaAudioEngine {
    /// 系统音频输出容器；此字段绝不能 drop。
    _device_sink: rodio::stream::MixerDeviceSink,
    registry: Registry,
    recorder_registry: RecorderRegistry,
}

impl XueHuaAudioEngine {
    /// 打开系统默认音频输出设备。
    pub fn new() -> Result<XueHuaAudioEngine, XueHuaAudioError> {
        let device_sink = DeviceSinkBuilder::open_default_sink()
            .map_err(|e| XueHuaAudioError::Device(e.to_string()))?;

        Ok(Self {
            _device_sink: device_sink,
            registry: Arc::new(Mutex::new(Vec::new())),
            recorder_registry: Arc::new(Mutex::new(Vec::new())),
        })
    }

    /// 列出可用麦克风输入设备名称。
    pub fn list_input_devices(&self) -> Result<Vec<String>, XueHuaAudioError> {
        list_input_devices()
    }

    /// 创建一条独立录制会话。
    pub fn create_recorder(&self) -> XueHuaAudioRecorder {
        XueHuaAudioRecorder::new(Arc::clone(&self.recorder_registry))
    }

    /// 从本地文件系统绝对路径加载并播放（流式解码）。
    pub fn load_from_path(&self, path: String) -> Result<XueHuaAudioTrack, XueHuaAudioError> {
        let source = open_decoder_from_path(&path)?;
        let duration = source.total_duration();
        let player = Player::connect_new(self._device_sink.mixer());
        player.append(source);
        Ok(XueHuaAudioTrack::new(
            player,
            Arc::clone(&self.registry),
            duration,
        ))
    }

    /// 从内存字节加载并播放（小文件 / 测试用；生产 Asset/URL 请走临时文件 + load_from_path）。
    pub fn load_from_bytes(&self, data: Vec<u8>) -> Result<XueHuaAudioTrack, XueHuaAudioError> {
        let source = open_decoder_from_bytes(data)?;
        let duration = source.total_duration();
        let player = Player::connect_new(self._device_sink.mixer());
        player.append(source);
        Ok(XueHuaAudioTrack::new(
            player,
            Arc::clone(&self.registry),
            duration,
        ))
    }

    /// 停止并注销所有仍活跃的音轨。
    pub fn stop_all(&self) {
        let mut guard = self.registry.lock().expect("registry lock poisoned");
        for entry in guard.drain(..) {
            entry.player.stop();
            entry.shared.deactivate();
        }
    }

    /// 停止所有仍活跃的录制会话。
    pub fn stop_all_recorders(&self) {
        let mut guard = self
            .recorder_registry
            .lock()
            .expect("recorder registry lock poisoned");
        for entry in guard.drain(..) {
            stop_shared_recorder(&entry.shared);
        }
    }
}
