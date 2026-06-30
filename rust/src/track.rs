use crate::engine::{Registry, lock_mutex, next_track_id, unregister_track};
use crate::error::XueHuaAudioError;
use crate::frb_generated::StreamSink;
use crate::playback::{XueHuaPlaybackProgress, compute_progress_ratio};
use rodio::decoder::LoopedDecoder;
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
        let handle = if let Ok(mut guard) = lock_mutex(&self.thread) {
            guard.take()
        } else {
            None
        };
        if let Some(handle) = handle {
            let _ = handle.join();
        }
        self.stop.store(false, Ordering::Relaxed);
    }

    /// Clear the stored join handle without joining. Only safe from inside the watcher thread.
    fn release_thread_handle(&self) {
        if let Ok(mut guard) = lock_mutex(&self.thread) {
            *guard = None;
        }
    }
}

/// Track 与 Engine registry 共享的状态。
pub(crate) struct TrackSharedState {
    active: AtomicBool,
    looping: AtomicBool,
    duration: Mutex<Option<Duration>>,
    progress_watcher: ProgressWatcher,
    registration: Arc<Mutex<Option<(Registry, u64)>>>,
}

impl TrackSharedState {
    fn new(
        duration: Option<Duration>,
        looping: bool,
        registration: Arc<Mutex<Option<(Registry, u64)>>>,
    ) -> Self {
        Self {
            active: AtomicBool::new(true),
            looping: AtomicBool::new(looping),
            duration: Mutex::new(duration),
            progress_watcher: ProgressWatcher::new(),
            registration,
        }
    }

    fn is_active(&self) -> bool {
        self.active.load(Ordering::Relaxed)
    }

    fn set_inactive(&self) {
        self.active.store(false, Ordering::Relaxed);
    }

    pub(crate) fn deactivate(&self) {
        self.set_inactive();
        self.progress_watcher.stop_watching();
    }

    pub(crate) fn take_registration(&self) {
        if let Ok(mut guard) = lock_mutex(&self.registration) {
            guard.take();
        }
    }

    fn unregister_from_engine(&self) {
        if let Ok(mut guard) = lock_mutex(&self.registration) {
            if let Some((registry, id)) = guard.take() {
                unregister_track(&registry, id);
            }
        }
    }

    fn duration(&self) -> Option<Duration> {
        lock_mutex(&self.duration).ok().and_then(|guard| *guard)
    }

    fn set_duration(&self, duration: Option<Duration>) {
        if let Ok(mut guard) = lock_mutex(&self.duration) {
            *guard = duration;
        }
    }

    fn is_looping(&self) -> bool {
        self.looping.load(Ordering::Relaxed)
    }

    fn set_looping(&self, looping: bool) {
        self.looping.store(looping, Ordering::Relaxed);
    }
}

/// 单轨播放器，封装 rodio `Player`。
///
/// 每个 `XueHuaAudioTrack` 对应一条独立播放队列，可单独 pause / set_volume / stop。
pub struct XueHuaAudioTrack {
    player: Arc<Player>,
    registration: Arc<Mutex<Option<(Registry, u64)>>>,
    shared: Arc<TrackSharedState>,
}

impl XueHuaAudioTrack {
    pub(crate) fn new(
        player: Player,
        registry: Registry,
        duration: Option<Duration>,
        looping: bool,
    ) -> Self {
        let player = Arc::new(player);
        let id = next_track_id();
        let registration = Arc::new(Mutex::new(Some((Arc::clone(&registry), id))));
        let shared = Arc::new(TrackSharedState::new(
            duration,
            looping,
            Arc::clone(&registration),
        ));
        if let Ok(mut guard) = lock_mutex(&registry) {
            guard.push(crate::engine::RegistryEntry {
                id,
                player: Arc::clone(&player),
                shared: Arc::clone(&shared),
            });
        }
        Self {
            player,
            registration,
            shared,
        }
    }

    fn require_active(&self) -> Result<(), XueHuaAudioError> {
        let registered = lock_mutex(&self.registration)?.is_some();
        if !registered || !self.shared.is_active() {
            return Err(XueHuaAudioError::AlreadyStopped);
        }
        Ok(())
    }

    pub fn pause(&self) -> Result<(), XueHuaAudioError> {
        self.require_active()?;
        self.player.pause();
        Ok(())
    }

    pub fn resume(&self) -> Result<(), XueHuaAudioError> {
        self.require_active()?;
        self.player.play();
        Ok(())
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
        lock_mutex(&self.registration)
            .ok()
            .and_then(|guard| guard.as_ref().map(|_| ()))
            .is_some()
            && (!self.shared.is_active() || (!self.shared.is_looping() && self.player.empty()))
    }

    pub fn set_volume(&self, volume: f32) -> Result<(), XueHuaAudioError> {
        self.require_active()?;
        self.player.set_volume(volume.clamp(0.0, 1.0));
        Ok(())
    }

    pub fn volume(&self) -> f32 {
        self.player.volume()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn position_secs(&self) -> f64 {
        let raw = self.player.get_pos().as_secs_f64();
        let duration_secs = self.shared.duration().map(|d| d.as_secs_f64());
        normalize_position_secs(raw, self.shared.is_looping(), duration_secs)
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
            self.shared.is_looping(),
            self.shared.duration(),
        )
    }

    /// 通过 Stream 推送播放进度（约每 100ms），播完或 stop 后结束。
    pub fn watch_playback_progress(
        &self,
        progress_sink: StreamSink<XueHuaPlaybackProgress>,
    ) -> Result<(), XueHuaAudioError> {
        self.require_active()?;

        self.shared.progress_watcher.stop_watching();

        let player = Arc::clone(&self.player);
        let shared = Arc::clone(&self.shared);
        let stop = Arc::clone(&self.shared.progress_watcher.stop);

        let handle = thread::spawn(move || {
            run_progress_watcher(player, shared, stop, progress_sink);
        });

        if let Ok(mut guard) = lock_mutex(&self.shared.progress_watcher.thread) {
            *guard = Some(handle);
        }

        Ok(())
    }

    /// 跳转到指定位置（秒）。底层调用 rodio `Player::try_seek`。
    pub fn seek_to(&self, position_secs: f64) -> Result<(), XueHuaAudioError> {
        self.require_active()?;
        self.player
            .try_seek(Duration::from_secs_f64(position_secs.max(0.0)))
            .map_err(|e| XueHuaAudioError::Decode(format!("Seek failed: {e}")))
    }

    /// 停止播放、清空队列，并从 Engine 注册表注销。
    pub fn stop(&mut self) -> Result<(), XueHuaAudioError> {
        if lock_mutex(&self.registration)?.is_none() {
            return Ok(());
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
    pub fn replace_from_path(
        &mut self,
        path: String,
        r#loop: bool,
    ) -> Result<(), XueHuaAudioError> {
        self.require_active()?;
        self.shared.set_looping(r#loop);
        if r#loop {
            let duration = probe_duration_from_path(&path)?;
            let source = open_looped_decoder_from_path(&path)?;
            self.shared.set_duration(duration);
            self.player.stop();
            self.player.append(source);
        } else {
            let source = open_decoder_from_path(&path)?;
            self.shared.set_duration(source.total_duration());
            self.player.stop();
            self.player.append(source);
        }
        Ok(())
    }

    /// 用内存字节替换当前音源（小文件 / 测试用）。
    pub fn replace_from_bytes(
        &mut self,
        data: Vec<u8>,
        r#loop: bool,
    ) -> Result<(), XueHuaAudioError> {
        self.require_active()?;
        self.shared.set_looping(r#loop);
        if r#loop {
            let duration = probe_duration_from_bytes(&data)?;
            let source = open_looped_decoder_from_bytes(data)?;
            self.shared.set_duration(duration);
            self.player.stop();
            self.player.append(source);
        } else {
            let source = open_decoder_from_bytes(data)?;
            self.shared.set_duration(source.total_duration());
            self.player.stop();
            self.player.append(source);
        }
        Ok(())
    }

    fn unregister(&mut self) {
        if let Ok(mut guard) = lock_mutex(&self.registration) {
            if let Some((registry, id)) = guard.take() {
                self.shared.deactivate();
                unregister_track(&registry, id);
            }
        }
    }
}

impl Drop for XueHuaAudioTrack {
    fn drop(&mut self) {
        self.shared.progress_watcher.stop_watching();
        if lock_mutex(&self.registration)
            .ok()
            .and_then(|guard| guard.as_ref().map(|_| ()))
            .is_some()
        {
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
            let progress = XueHuaAudioTrack::snapshot_progress(
                &player,
                shared.is_active(),
                shared.is_looping(),
                shared.duration(),
            );
            let finished = progress.is_finished;
            let _ = progress_sink.add(progress);
            if finished {
                shared.unregister_from_engine();
                shared.set_inactive();
                shared.progress_watcher.release_thread_handle();
                break;
            }
            last_push = Instant::now();
        }
        thread::sleep(Duration::from_millis(16));
    }
    shared.progress_watcher.release_thread_handle();
}

impl XueHuaAudioTrack {
    fn snapshot_progress(
        player: &Player,
        active: bool,
        looping: bool,
        duration: Option<Duration>,
    ) -> XueHuaPlaybackProgress {
        let is_paused = player.is_paused();
        let is_finished = !active || (!looping && player.empty());
        let is_playing = active && !is_paused && !is_finished;
        let raw_position_secs = player.get_pos().as_secs_f64();
        let duration_secs = duration.map(|d| d.as_secs_f64());
        let position_secs = normalize_position_secs(raw_position_secs, looping, duration_secs);
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

pub(crate) fn normalize_position_secs(raw: f64, looping: bool, duration_secs: Option<f64>) -> f64 {
    if looping {
        if let Some(total) = duration_secs.filter(|duration| *duration > 0.0) {
            return raw % total;
        }
    }
    raw
}

pub(crate) fn probe_duration_from_path(path: &str) -> Result<Option<Duration>, XueHuaAudioError> {
    let file = File::open(path).map_err(|e| XueHuaAudioError::LocalFile(e.to_string()))?;
    let decoder =
        Decoder::new(BufReader::new(file)).map_err(|e| XueHuaAudioError::Decode(e.to_string()))?;
    Ok(decoder.total_duration())
}

pub(crate) fn probe_duration_from_bytes(data: &[u8]) -> Result<Option<Duration>, XueHuaAudioError> {
    let decoder = Decoder::new(BufReader::new(Cursor::new(data.to_vec())))
        .map_err(|e| XueHuaAudioError::Decode(e.to_string()))?;
    Ok(decoder.total_duration())
}

pub(crate) fn open_decoder_from_path(
    path: &str,
) -> Result<Decoder<BufReader<File>>, XueHuaAudioError> {
    let file = File::open(path).map_err(|e| XueHuaAudioError::LocalFile(e.to_string()))?;
    Decoder::new(BufReader::new(file)).map_err(|e| XueHuaAudioError::Decode(e.to_string()))
}

pub(crate) fn open_looped_decoder_from_path(
    path: &str,
) -> Result<LoopedDecoder<BufReader<File>>, XueHuaAudioError> {
    let file = File::open(path).map_err(|e| XueHuaAudioError::LocalFile(e.to_string()))?;
    Decoder::new_looped(BufReader::new(file)).map_err(|e| XueHuaAudioError::Decode(e.to_string()))
}

pub(crate) fn open_decoder_from_bytes(
    data: Vec<u8>,
) -> Result<Decoder<BufReader<Cursor<Vec<u8>>>>, XueHuaAudioError> {
    Decoder::new(BufReader::new(Cursor::new(data)))
        .map_err(|e| XueHuaAudioError::Decode(e.to_string()))
}

pub(crate) fn open_looped_decoder_from_bytes(
    data: Vec<u8>,
) -> Result<LoopedDecoder<BufReader<Cursor<Vec<u8>>>>, XueHuaAudioError> {
    Decoder::new_looped(BufReader::new(Cursor::new(data)))
        .map_err(|e| XueHuaAudioError::Decode(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::normalize_position_secs;

    #[test]
    fn normalize_position_wraps_when_looping() {
        assert_eq!(normalize_position_secs(12.5, true, Some(10.0)), 2.5);
    }

    #[test]
    fn normalize_position_unchanged_when_not_looping() {
        assert_eq!(normalize_position_secs(12.5, false, Some(10.0)), 12.5);
    }
}
