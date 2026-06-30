use crate::engine::{RecorderRegistry, lock_mutex, next_recorder_id, unregister_recorder};
use crate::error::XueHuaAudioError;
use crate::frb_generated::StreamSink;
use hound::{SampleFormat, WavSpec, WavWriter};
use rodio::Source;
use rodio::microphone::{self, Microphone, MicrophoneBuilder};
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

/// 录制进度快照（通过 Stream 推送）。
pub struct XueHuaRecordingProgress {
    pub is_recording: bool,
    pub is_paused: bool,
    pub duration_secs: f64,
    /// 最近 buffer 峰值 0.0~1.0
    pub level: f32,
}

/// 录制完成事件。
pub struct XueHuaRecordingCompleted {
    pub output_path: String,
    pub duration_secs: f64,
}

/// 录制事件（进度或完成）。
pub enum XueHuaRecordingEvent {
    Progress(XueHuaRecordingProgress),
    Completed(XueHuaRecordingCompleted),
}

pub(crate) struct RecorderShared {
    stop_flag: AtomicBool,
    paused: AtomicBool,
    is_recording: AtomicBool,
    startup_ready: AtomicBool,
    samples_written: AtomicU64,
    sample_rate: AtomicU32,
    channels: AtomicU32,
    output_path: Mutex<String>,
    startup_failed: Mutex<Option<String>>,
    writer_thread: Mutex<Option<JoinHandle<Result<(), String>>>>,
}

impl RecorderShared {
    fn new() -> Self {
        Self {
            stop_flag: AtomicBool::new(false),
            paused: AtomicBool::new(false),
            is_recording: AtomicBool::new(false),
            startup_ready: AtomicBool::new(false),
            samples_written: AtomicU64::new(0),
            sample_rate: AtomicU32::new(0),
            channels: AtomicU32::new(0),
            output_path: Mutex::new(String::new()),
            startup_failed: Mutex::new(None),
            writer_thread: Mutex::new(None),
        }
    }

    fn duration_secs(&self) -> f64 {
        let samples = self.samples_written.load(Ordering::Relaxed);
        let rate = self.sample_rate.load(Ordering::Relaxed);
        let channels = self.channels.load(Ordering::Relaxed);
        if rate == 0 || channels == 0 {
            return 0.0;
        }
        samples as f64 / rate as f64 / channels as f64
    }

    fn progress_snapshot(&self, level: f32) -> XueHuaRecordingProgress {
        XueHuaRecordingProgress {
            is_recording: self.is_recording.load(Ordering::Relaxed),
            is_paused: self.paused.load(Ordering::Relaxed),
            duration_secs: self.duration_secs(),
            level,
        }
    }

    fn join_writer_thread(&self) -> Result<(), XueHuaAudioError> {
        let handle = lock_mutex(&self.writer_thread)?.take();
        if let Some(handle) = handle {
            match handle.join() {
                Ok(Ok(())) => Ok(()),
                Ok(Err(message)) => Err(XueHuaAudioError::Recording(message)),
                Err(_) => Err(XueHuaAudioError::Recording(
                    "Recording thread panicked".into(),
                )),
            }
        } else {
            Ok(())
        }
    }

    fn request_stop(&self) -> Result<String, XueHuaAudioError> {
        if !self.is_recording.load(Ordering::Relaxed) {
            return Err(XueHuaAudioError::NotRecording);
        }
        self.stop_flag.store(true, Ordering::Relaxed);
        self.join_writer_thread()?;
        self.is_recording.store(false, Ordering::Relaxed);
        self.paused.store(false, Ordering::Relaxed);
        Ok(lock_mutex(&self.output_path)?.clone())
    }

    fn reset_for_start(&self, output_path: String) {
        self.stop_flag.store(false, Ordering::Relaxed);
        self.paused.store(false, Ordering::Relaxed);
        self.startup_ready.store(false, Ordering::Relaxed);
        self.samples_written.store(0, Ordering::Relaxed);
        if let Ok(mut guard) = lock_mutex(&self.startup_failed) {
            *guard = None;
        }
        if let Ok(mut guard) = lock_mutex(&self.output_path) {
            *guard = output_path;
        }
    }

    fn wait_for_startup(&self) -> Result<(), XueHuaAudioError> {
        let deadline = Instant::now() + Duration::from_millis(100);
        loop {
            if self.startup_ready.load(Ordering::Acquire) {
                return Ok(());
            }
            if let Ok(guard) = lock_mutex(&self.startup_failed) {
                if let Some(message) = guard.clone() {
                    self.is_recording.store(false, Ordering::Relaxed);
                    self.join_writer_thread()?;
                    return Err(XueHuaAudioError::Recording(message));
                }
            }
            let finished = lock_mutex(&self.writer_thread)?
                .as_ref()
                .is_some_and(|handle| handle.is_finished());
            if finished {
                self.join_writer_thread()?;
                self.is_recording.store(false, Ordering::Relaxed);
                return Err(XueHuaAudioError::Recording(
                    "Recording failed to start".into(),
                ));
            }
            if Instant::now() >= deadline {
                return Ok(());
            }
            thread::sleep(Duration::from_millis(5));
        }
    }
}

/// 麦克风录制器，后台线程写入 WAV 并通过 StreamSink 推送事件。
pub struct XueHuaAudioRecorder {
    shared: Arc<RecorderShared>,
    registry: RecorderRegistry,
    registration_id: Option<u64>,
}

impl XueHuaAudioRecorder {
    pub(crate) fn new(registry: RecorderRegistry) -> Self {
        let shared = Arc::new(RecorderShared::new());
        let mut recorder = Self {
            shared,
            registry: Arc::clone(&registry),
            registration_id: None,
        };
        recorder.ensure_registered();
        recorder
    }

    fn ensure_registered(&mut self) {
        if self.registration_id.is_some() {
            return;
        }
        let id = next_recorder_id();
        if let Ok(mut guard) = lock_mutex(&self.registry) {
            guard.push(crate::engine::RecorderRegistryEntry {
                id,
                shared: Arc::clone(&self.shared),
            });
            self.registration_id = Some(id);
        }
    }

    /// 立即返回；后台线程写入 WAV 并约每 100ms 推送 Progress 事件。
    pub fn start(
        &mut self,
        output_path: String,
        progress_sink: StreamSink<XueHuaRecordingEvent>,
        device_index: Option<u32>,
    ) -> Result<(), XueHuaAudioError> {
        if self.shared.is_recording.load(Ordering::Relaxed) {
            return Err(XueHuaAudioError::AlreadyRecording);
        }

        self.ensure_registered();
        self.shared.reset_for_start(output_path.clone());
        self.shared.is_recording.store(true, Ordering::Relaxed);

        let shared = Arc::clone(&self.shared);
        let handle = thread::spawn(move || {
            run_writer_thread(shared, output_path, progress_sink, device_index)
        });

        *lock_mutex(&self.shared.writer_thread)? = Some(handle);
        self.shared.wait_for_startup()
    }

    pub fn pause(&self) -> Result<(), XueHuaAudioError> {
        if !self.shared.is_recording.load(Ordering::Relaxed) {
            return Err(XueHuaAudioError::NotRecording);
        }
        self.shared.paused.store(true, Ordering::Relaxed);
        Ok(())
    }

    pub fn resume(&self) -> Result<(), XueHuaAudioError> {
        if !self.shared.is_recording.load(Ordering::Relaxed) {
            return Err(XueHuaAudioError::NotRecording);
        }
        self.shared.paused.store(false, Ordering::Relaxed);
        Ok(())
    }

    /// 停止录制、finalize WAV，并推送 Completed 事件。
    pub fn stop(&mut self) -> Result<String, XueHuaAudioError> {
        let path = self.shared.request_stop()?;
        self.unregister();
        Ok(path)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_recording(&self) -> bool {
        self.shared.is_recording.load(Ordering::Relaxed)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn is_paused(&self) -> bool {
        self.shared.paused.load(Ordering::Relaxed)
    }

    fn unregister(&mut self) {
        if let Some(id) = self.registration_id.take() {
            unregister_recorder(&self.registry, id);
        }
    }
}

impl Drop for XueHuaAudioRecorder {
    fn drop(&mut self) {
        stop_shared_recorder(&self.shared);
        self.unregister();
    }
}

pub(crate) fn stop_shared_recorder(shared: &Arc<RecorderShared>) {
    if shared.is_recording.load(Ordering::Relaxed) {
        shared.stop_flag.store(true, Ordering::Relaxed);
        if let Err(error) = shared.join_writer_thread() {
            eprintln!("xue_hua_audio: recorder stop error: {error}");
        }
        shared.is_recording.store(false, Ordering::Relaxed);
        shared.paused.store(false, Ordering::Relaxed);
    }
}

fn run_writer_thread(
    shared: Arc<RecorderShared>,
    output_path: String,
    progress_sink: StreamSink<XueHuaRecordingEvent>,
    device_index: Option<u32>,
) -> Result<(), String> {
    let mut mic = open_microphone(device_index).map_err(|e| e.to_string())?;
    let channels = mic.channels().get();
    let channels_u32 = channels as u32;
    let sample_rate = mic.sample_rate().get();
    shared.channels.store(channels.into(), Ordering::Relaxed);
    shared.sample_rate.store(sample_rate, Ordering::Relaxed);

    let spec = WavSpec {
        channels,
        sample_rate,
        bits_per_sample: 32,
        sample_format: SampleFormat::Float,
    };
    let mut writer =
        WavWriter::create(&output_path, spec).map_err(|e| format!("Create WAV file: {e}"))?;

    shared.startup_ready.store(true, Ordering::Release);

    let push_interval = Duration::from_millis(100);
    let mut last_push = Instant::now();
    let mut chunk_peak = 0.0f32;
    let mut frame_pos = 0u32;

    while !shared.stop_flag.load(Ordering::Relaxed) || frame_pos != 0 {
        match mic.next() {
            Some(sample) => {
                if shared.stop_flag.load(Ordering::Relaxed) {
                    if frame_pos == 0 {
                        break;
                    }
                    frame_pos = advance_frame_pos(frame_pos, channels_u32);
                    continue;
                }

                let abs = sample.abs();
                if abs > chunk_peak {
                    chunk_peak = abs;
                }
                if !shared.paused.load(Ordering::Relaxed) {
                    writer
                        .write_sample(sample)
                        .map_err(|e| format!("Write WAV sample: {e}"))?;
                    shared.samples_written.fetch_add(1, Ordering::Relaxed);
                }
                frame_pos = advance_frame_pos(frame_pos, channels_u32);
            }
            None => {
                while frame_pos != 0 {
                    writer
                        .write_sample(0.0f32)
                        .map_err(|e| format!("Write WAV sample: {e}"))?;
                    shared.samples_written.fetch_add(1, Ordering::Relaxed);
                    frame_pos = advance_frame_pos(frame_pos, channels_u32);
                }
                break;
            }
        }

        if last_push.elapsed() >= push_interval {
            let level = chunk_peak.min(1.0);
            let _ = progress_sink.add(XueHuaRecordingEvent::Progress(
                shared.progress_snapshot(level),
            ));
            chunk_peak = 0.0;
            last_push = Instant::now();
        }
    }

    writer
        .finalize()
        .map_err(|e| format!("Finalize WAV file: {e}"))?;

    let duration_secs = shared.duration_secs();
    let _ = progress_sink.add(XueHuaRecordingEvent::Completed(XueHuaRecordingCompleted {
        output_path: output_path.clone(),
        duration_secs,
    }));

    Ok(())
}

fn advance_frame_pos(frame_pos: u32, channels_u32: u32) -> u32 {
    (frame_pos + 1) % channels_u32
}

fn open_microphone(device_index: Option<u32>) -> Result<Microphone, XueHuaAudioError> {
    let inputs =
        microphone::available_inputs().map_err(|e| XueHuaAudioError::Recording(e.to_string()))?;
    if inputs.is_empty() {
        return Err(XueHuaAudioError::Recording(
            "No input devices available".into(),
        ));
    }

    let device = match device_index {
        Some(index) => inputs
            .get(index as usize)
            .ok_or_else(|| {
                XueHuaAudioError::Recording(format!("Invalid input device index: {index}"))
            })?
            .clone(),
        None => inputs[0].clone(),
    };

    MicrophoneBuilder::new()
        .device(device)
        .map_err(|e| XueHuaAudioError::Recording(e.to_string()))?
        .default_config()
        .map_err(|e| XueHuaAudioError::Recording(e.to_string()))?
        .open_stream()
        .map_err(|e| XueHuaAudioError::Recording(e.to_string()))
}

pub fn list_input_devices() -> Result<Vec<String>, XueHuaAudioError> {
    Ok(microphone::available_inputs()
        .map_err(|e| XueHuaAudioError::Recording(e.to_string()))?
        .iter()
        .map(|input| input.to_string())
        .collect())
}

#[cfg(test)]
mod tests {
    use super::advance_frame_pos;

    #[test]
    fn paused_samples_advance_frame_pos_without_writing() {
        let channels = 2u32;
        let mut frame_pos = 0u32;
        let mut written = Vec::new();
        let samples = [1.0_f32, 2.0, 3.0, 4.0];

        for (i, &sample) in samples.iter().enumerate() {
            let paused = i >= 2;
            if !paused {
                written.push((frame_pos, sample));
            }
            frame_pos = advance_frame_pos(frame_pos, channels);
        }

        assert_eq!(written, [(0, 1.0), (1, 2.0)]);
        assert_eq!(frame_pos, 0);
    }
}
