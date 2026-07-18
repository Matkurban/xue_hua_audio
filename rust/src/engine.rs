use crate::error::XueHuaAudioError;
use crate::recording::{XueHuaAudioRecorder, list_input_devices, stop_shared_recorder};
use crate::track::{
    TrackSharedState, XueHuaAudioTrack, open_decoder_from_bytes, open_decoder_from_path,
    open_looped_decoder_from_bytes, open_looped_decoder_from_path, probe_duration_from_bytes,
    probe_duration_from_path,
};
use rodio::Player;
use rodio::Source;
use rodio::speakers::{self, SpeakersBuilder};
use rodio::stream::MixerDeviceSink;
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

pub(crate) fn lock_mutex<T>(
    mutex: &Mutex<T>,
) -> Result<std::sync::MutexGuard<'_, T>, XueHuaAudioError> {
    mutex
        .lock()
        .map_err(|_| XueHuaAudioError::Recording("lock poisoned".into()))
}

pub(crate) fn unregister_track(registry: &Registry, id: u64) {
    if let Ok(mut guard) = lock_mutex(registry) {
        guard.retain(|entry| entry.id != id);
    }
}

pub(crate) fn unregister_recorder(registry: &RecorderRegistry, id: u64) {
    if let Ok(mut guard) = lock_mutex(registry) {
        guard.retain(|entry| entry.id != id);
    }
}

/// 输出设备信息（对应 rodio `speakers::Output` 的公开字段）。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct XueHuaOutputDevice {
    pub name: String,
    pub is_default: bool,
}

fn list_output_device_infos() -> Result<Vec<XueHuaOutputDevice>, XueHuaAudioError> {
    Ok(speakers::available_outputs()
        .map_err(|e| XueHuaAudioError::Device(e.to_string()))?
        .iter()
        .map(|output| XueHuaOutputDevice {
            name: output.to_string(),
            is_default: output.is_default(),
        })
        .collect())
}

fn open_output_sink(device_index: Option<u32>) -> Result<MixerDeviceSink, XueHuaAudioError> {
    let builder = match device_index {
        None => SpeakersBuilder::new()
            .default_device()
            .map_err(|e| XueHuaAudioError::Device(e.to_string()))?,
        Some(index) => {
            let outputs = speakers::available_outputs()
                .map_err(|e| XueHuaAudioError::Device(e.to_string()))?;
            let output = outputs.get(index as usize).cloned().ok_or_else(|| {
                XueHuaAudioError::Device(format!("Invalid output device index: {index}"))
            })?;
            SpeakersBuilder::new()
                .device(output)
                .map_err(|e| XueHuaAudioError::Device(e.to_string()))?
        }
    };
    builder
        .default_config()
        .map_err(|e| XueHuaAudioError::Device(e.to_string()))?
        .open_mixer()
        .map_err(|e| XueHuaAudioError::Device(e.to_string()))
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
///
/// 输出设备在首次播放（`load_from_*`）时懒打开，避免 `initialize` 阻塞数秒。
/// 可通过 [`Self::set_output_device`] 切换设备（会先 `stop_all`）。
pub struct XueHuaAudioEngine {
    /// 系统音频输出容器；首次播放时打开；切换输出设备时可替换。
    device_sink: Mutex<Option<MixerDeviceSink>>,
    /// `None` = 系统默认；`Some(i)` = [`Self::list_output_devices`] 中的下标。
    preferred_output_index: Mutex<Option<u32>>,
    registry: Registry,
    recorder_registry: RecorderRegistry,
}

impl XueHuaAudioEngine {
    /// 创建空引擎壳（不打开音频设备）。
    pub fn new() -> Result<XueHuaAudioEngine, XueHuaAudioError> {
        Ok(Self {
            device_sink: Mutex::new(None),
            preferred_output_index: Mutex::new(None),
            registry: Arc::new(Mutex::new(Vec::new())),
            recorder_registry: Arc::new(Mutex::new(Vec::new())),
        })
    }

    /// 确保偏好输出设备已打开，并连接一条新的 `Player`。
    fn connect_new_player(&self) -> Result<Player, XueHuaAudioError> {
        let preferred = *lock_mutex(&self.preferred_output_index)?;
        let mut guard = lock_mutex(&self.device_sink)?;
        if guard.is_none() {
            *guard = Some(open_output_sink(preferred)?);
        }
        Ok(Player::connect_new(
            guard.as_ref().expect("device_sink just ensured").mixer(),
        ))
    }

    /// 列出可用麦克风输入设备名称。
    pub fn list_input_devices(&self) -> Result<Vec<String>, XueHuaAudioError> {
        list_input_devices()
    }

    /// 列出可用输出设备（名称与是否为系统默认，对应 rodio `Output` 公开信息）。
    pub fn list_output_devices(&self) -> Result<Vec<XueHuaOutputDevice>, XueHuaAudioError> {
        list_output_device_infos()
    }

    /// 当前引擎偏好的输出设备；未设置偏好时返回系统默认输出。
    pub fn current_output_device(&self) -> Result<Option<XueHuaOutputDevice>, XueHuaAudioError> {
        let devices = list_output_device_infos()?;
        if devices.is_empty() {
            return Ok(None);
        }
        let preferred = *lock_mutex(&self.preferred_output_index)?;
        match preferred {
            Some(index) => Ok(devices.get(index as usize).cloned()),
            None => Ok(devices.into_iter().find(|device| device.is_default)),
        }
    }

    /// 设置输出设备。`None` 表示系统默认。
    ///
    /// 会先 [`Self::stop_all`]；若输出 sink 已打开则立即按新偏好重建。
    pub fn set_output_device(&self, device_index: Option<u32>) -> Result<(), XueHuaAudioError> {
        if let Some(index) = device_index {
            let outputs = speakers::available_outputs()
                .map_err(|e| XueHuaAudioError::Device(e.to_string()))?;
            if index as usize >= outputs.len() {
                return Err(XueHuaAudioError::Device(format!(
                    "Invalid output device index: {index}"
                )));
            }
        }

        *lock_mutex(&self.preferred_output_index)? = device_index;
        self.stop_all();

        let mut guard = lock_mutex(&self.device_sink)?;
        if guard.is_some() {
            *guard = None;
            *guard = Some(open_output_sink(device_index)?);
        }
        Ok(())
    }

    /// 创建一条独立录制会话。
    pub fn create_recorder(&self) -> XueHuaAudioRecorder {
        XueHuaAudioRecorder::new(Arc::clone(&self.recorder_registry))
    }

    /// 从本地文件系统绝对路径加载并播放（流式解码）。
    pub fn load_from_path(
        &self,
        path: String,
        r#loop: bool,
    ) -> Result<XueHuaAudioTrack, XueHuaAudioError> {
        let player = self.connect_new_player()?;
        let (duration, looping) = if r#loop {
            let duration = probe_duration_from_path(&path)?;
            let source = open_looped_decoder_from_path(&path)?;
            player.append(source);
            (duration, true)
        } else {
            let source = open_decoder_from_path(&path)?;
            let duration = source.total_duration();
            player.append(source);
            (duration, false)
        };
        Ok(XueHuaAudioTrack::new(
            player,
            Arc::clone(&self.registry),
            duration,
            looping,
        ))
    }

    /// 从内存字节加载并播放（小文件 / 测试用；生产 Asset/URL 请走临时文件 + load_from_path）。
    pub fn load_from_bytes(
        &self,
        data: Vec<u8>,
        r#loop: bool,
    ) -> Result<XueHuaAudioTrack, XueHuaAudioError> {
        let player = self.connect_new_player()?;
        let (duration, looping) = if r#loop {
            let duration = probe_duration_from_bytes(&data)?;
            let source = open_looped_decoder_from_bytes(data)?;
            player.append(source);
            (duration, true)
        } else {
            let source = open_decoder_from_bytes(data)?;
            let duration = source.total_duration();
            player.append(source);
            (duration, false)
        };
        Ok(XueHuaAudioTrack::new(
            player,
            Arc::clone(&self.registry),
            duration,
            looping,
        ))
    }

    /// 停止并注销所有仍活跃的音轨。
    pub fn stop_all(&self) {
        if let Ok(mut guard) = lock_mutex(&self.registry) {
            for entry in guard.drain(..) {
                entry.player.stop();
                entry.shared.deactivate();
                entry.shared.take_registration();
            }
        }
    }

    /// 停止所有仍活跃的录制会话。
    pub fn stop_all_recorders(&self) {
        if let Ok(mut guard) = lock_mutex(&self.recorder_registry) {
            for entry in guard.drain(..) {
                stop_shared_recorder(&entry.shared);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, Instant};

    #[test]
    fn engine_new_does_not_open_device() {
        let start = Instant::now();
        let engine = XueHuaAudioEngine::new().expect("engine new");
        let elapsed = start.elapsed();
        assert!(
            elapsed < Duration::from_millis(10),
            "XueHuaAudioEngine::new took {elapsed:?}, expected < 10ms"
        );
        let sink = engine.device_sink.lock().expect("device_sink lock");
        assert!(
            sink.is_none(),
            "device sink must stay closed until first load"
        );
    }

    #[test]
    fn set_output_device_none_keeps_sink_closed() {
        let engine = XueHuaAudioEngine::new().expect("engine new");
        engine
            .set_output_device(None)
            .expect("set default preference");
        let sink = engine.device_sink.lock().expect("device_sink lock");
        assert!(
            sink.is_none(),
            "set_output_device must not open sink when none was open"
        );
    }

    #[test]
    fn list_and_current_output_devices() {
        let engine = XueHuaAudioEngine::new().expect("engine new");
        let devices = engine.list_output_devices().expect("list outputs");
        if devices.is_empty() {
            assert!(engine.current_output_device().expect("current").is_none());
            return;
        }

        for device in &devices {
            assert!(
                !device.name.is_empty(),
                "output device name must not be empty"
            );
        }
        let default_count = devices.iter().filter(|d| d.is_default).count();
        assert_eq!(default_count, 1, "exactly one default output expected");

        let current = engine
            .current_output_device()
            .expect("current")
            .expect("default output");
        assert!(current.is_default);
        assert_eq!(
            current,
            devices.iter().find(|d| d.is_default).unwrap().clone()
        );

        engine.set_output_device(Some(0)).expect("set first output");
        let after = engine
            .current_output_device()
            .expect("current after set")
            .expect("device 0");
        assert_eq!(after, devices[0]);
    }
}
