#[derive(Debug, thiserror::Error)]
pub enum XueHuaAudioError {
    #[error("Failed to open audio device: {0}")]
    Device(String),
    #[error("Failed to open local file: {0}")]
    LocalFile(String),
    #[error("Failed to decode audio: {0}")]
    Decode(String),
    #[error("Track already stopped")]
    AlreadyStopped,
    #[error("Recording error: {0}")]
    Recording(String),
    #[error("Already recording")]
    AlreadyRecording,
    #[error("Not recording")]
    NotRecording,
}
