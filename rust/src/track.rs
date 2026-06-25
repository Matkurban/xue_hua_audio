use crate::engine::{next_track_id, unregister_track, Registry, RegistryEntry};
use crate::error::XueHuaAudioError;
use crate::frb_generated::StreamSink;
use crate::playback::{compute_progress_ratio, XueHuaPlaybackProgress};
use rodio::{Decoder, Player, Source};
use std::fs::File;
use std::io::{BufReader, Cursor};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

struct ProgressWatcher {
    stop: Arc<AtomicBool>,
    thread: Mutex<Option<JoinHandle<()>>>,
}

impl ProgressWatcher {
    fn new() -> Self {
        Self {
            stop: Arc::new(AtomicBool::new(false)),
            thread: Mutex::new(None),
        }
    }

    fn stop_watching(&self) {
        self.stop.store(true, Ordering::Relaxed);
        if let Some(handle) = self
            .thread
            .lock()
            .expect("progress watcher lock poisoned")
            .take()
        {
            let _ = handle.join();
        }
        self.stop.store(false, Ordering::Relaxed);
    }
}

/// Track 与 Engine registry 共享的状态。
pub(crate) struct TrackSharedState {
    active: AtomicBool,
    duration: Mutex<Option<Duration>>,
    progress_watcher: ProgressWatcher,
}

impl TrackSharedState {
    fn new(duration: Option<Duration>) -> Self {
        Self {
            active: AtomicBool::new(true),
            duration: Mutex::new(duration),
            progress_watcher: ProgressWatcher::new(),
        }
    }

    fn is_active(&self) -> bool {
        self.active.load(Ordering::Relaxed)
    }

    pub(crate) fn deactivate(&self) {
        self.active.store(false, Ordering::Relaxed);
        self.progress_watcher.stop_watching();
    }

    fn duration(&self) -> Option<Duration> {
        *self.duration.lock().expect("track duration lock poisoned")
    }

    fn set_duration(&self, duration: Option<Duration>) {
        *self.duration.lock().expect("track duration lock poisoned") = duration;
    }
}

/// 单轨播放器，封装 rodio `Player`。
///
/// 每个 `XueHuaAudioTrack` 对应一条独立播放队列，可单独 pause / set_volume / stop。
pub struct XueHuaAudioTrack {
    player: Arc<Player>,
    registration: Option<(Registry, u64)>,
    shared: Arc<TrackSharedState>,
}

impl XueHuaAudioTrack {
    pub(crate) fn new(player: Player, registry: Registry, duration: Option<Duration>) -> Self {
        let player = Arc::new(player);
        let shared = Arc::new(TrackSharedState::new(duration));
        let id = next_track_id();
        registry
            .lock()
            .expect("registry lock poisoned")
            .push(RegistryEntry {
                id,
                player: Arc::clone(&player),
                shared: Arc::clone(&shared),
            });
        Self {
            player,
            registration: Some((registry, id)),
            shared,
        }
    }

    pub fn pause(&self) {
        self.player.pause();
    }

    pub fn resume(&self) {
        self.player.play();
    }

    pub fn is_paused(&self) -> bool {
        self.player.is_paused()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_playing(&self) -> bool {
        self.shared.is_active() && !self.player.is_paused() && !self.player.empty()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_finished(&self) -> bool {
        self.registration.is_some() && (!self.shared.is_active() || self.player.empty())
    }

    pub fn set_volume(&self, volume: f32) {
        self.player.set_volume(volume.clamp(0.0, 1.0));
    }

    pub fn volume(&self) -> f32 {
        self.player.volume()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn position_secs(&self) -> f64 {
        self.player.get_pos().as_secs_f64()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn duration_secs(&self) -> Option<f64> {
        self.shared.duration().map(|d| d.as_secs_f64())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn playback_progress(&self) -> XueHuaPlaybackProgress {
        Self::snapshot_progress(
            &self.player,
            self.shared.is_active(),
            self.shared.duration(),
        )
    }

    /// 通过 Stream 推送播放进度（约每 100ms），播完或 stop 后结束。
    pub fn watch_playback_progress(
        &self,
        progress_sink: StreamSink<XueHuaPlaybackProgress>,
    ) -> Result<(), XueHuaAudioError> {
        if self.registration.is_none() {
            return Err(XueHuaAudioError::AlreadyStopped);
        }
        if !self.shared.is_active() {
            return Err(XueHuaAudioError::AlreadyStopped);
        }

        self.shared.progress_watcher.stop_watching();

        let player = Arc::clone(&self.player);
        let shared = Arc::clone(&self.shared);
        let stop = Arc::clone(&self.shared.progress_watcher.stop);

        let handle = thread::spawn(move || {
            run_progress_watcher(player, shared, stop, progress_sink);
        });

        *self
            .shared
            .progress_watcher
            .thread
            .lock()
            .expect("progress watcher lock poisoned") = Some(handle);

        Ok(())
    }

    /// 跳转到指定位置（秒）。底层调用 rodio `Player::try_seek`。
    pub fn seek_to(&self, position_secs: f64) -> Result<(), XueHuaAudioError> {
        self.player
            .try_seek(Duration::from_secs_f64(position_secs.max(0.0)))
            .map_err(|e| XueHuaAudioError::Decode(format!("Seek failed: {e}")))
    }

    /// 停止播放、清空队列，并从 Engine 注册表注销。
    pub fn stop(&mut self) -> Result<(), XueHuaAudioError> {
        if self.registration.is_none() {
            return Err(XueHuaAudioError::AlreadyStopped);
        }
        if !self.shared.is_active() {
            self.unregister();
            return Ok(());
        }
        self.shared.deactivate();
        self.player.stop();
        self.unregister();
        Ok(())
    }

    /// 用本地文件替换当前音源（先清空队列再 append 新 Decoder）。
    pub fn replace_from_path(&mut self, path: String) -> Result<(), XueHuaAudioError> {
        let source = open_decoder_from_path(&path)?;
        self.shared.set_duration(source.total_duration());
        self.player.stop();
        self.player.append(source);
        Ok(())
    }

    /// 用内存字节替换当前音源（小文件 / 测试用）。
    pub fn replace_from_bytes(&mut self, data: Vec<u8>) -> Result<(), XueHuaAudioError> {
        let source = open_decoder_from_bytes(data)?;
        self.shared.set_duration(source.total_duration());
        self.player.stop();
        self.player.append(source);
        Ok(())
    }

    fn unregister(&mut self) {
        if let Some((registry, id)) = self.registration.take() {
            self.shared.deactivate();
            unregister_track(&registry, id);
        }
    }
}

impl Drop for XueHuaAudioTrack {
    fn drop(&mut self) {
        self.shared.progress_watcher.stop_watching();
        if self.registration.is_some() {
            self.player.stop();
            self.unregister();
        }
    }
}

fn run_progress_watcher(
    player: Arc<Player>,
    shared: Arc<TrackSharedState>,
    stop: Arc<AtomicBool>,
    progress_sink: StreamSink<XueHuaPlaybackProgress>,
) {
    let interval = Duration::from_millis(100);
    let mut last_push = Instant::now();

    while !stop.load(Ordering::Relaxed) && shared.is_active() {
        if last_push.elapsed() >= interval {
            let progress =
                XueHuaAudioTrack::snapshot_progress(&player, shared.is_active(), shared.duration());
            let finished = progress.is_finished;
            let _ = progress_sink.add(progress);
            if finished {
                break;
            }
            last_push = Instant::now();
        }
        thread::sleep(Duration::from_millis(16));
    }
}

impl XueHuaAudioTrack {
    fn snapshot_progress(
        player: &Player,
        active: bool,
        duration: Option<Duration>,
    ) -> XueHuaPlaybackProgress {
        let is_paused = player.is_paused();
        let is_finished = !active || player.empty();
        let is_playing = active && !is_paused && !is_finished;
        let position_secs = player.get_pos().as_secs_f64();
        let duration_secs = duration.map(|d| d.as_secs_f64());
        let progress = compute_progress_ratio(position_secs, duration_secs);

        XueHuaPlaybackProgress {
            is_playing,
            is_paused,
            is_finished,
            position_secs,
            duration_secs,
            progress,
        }
    }
}

pub(crate) fn open_decoder_from_path(
    path: &str,
) -> Result<Decoder<BufReader<File>>, XueHuaAudioError> {
    let file = File::open(path).map_err(|e| XueHuaAudioError::LocalFile(e.to_string()))?;
    Decoder::new(BufReader::new(file)).map_err(|e| XueHuaAudioError::Decode(e.to_string()))
}

pub(crate) fn open_decoder_from_bytes(
    data: Vec<u8>,
) -> Result<Decoder<BufReader<Cursor<Vec<u8>>>>, XueHuaAudioError> {
    Decoder::new(BufReader::new(Cursor::new(data)))
        .map_err(|e| XueHuaAudioError::Decode(e.to_string()))
}
