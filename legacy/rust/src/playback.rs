/// 单轨播放状态与进度快照。
#[derive(Clone)]
pub struct XueHuaPlaybackProgress {
    pub is_playing: bool,
    pub is_paused: bool,
    pub is_finished: bool,
    pub position_secs: f64,
    pub duration_secs: Option<f64>,
    /// 0.0~1.0；duration 未知时为 None
    pub progress: Option<f64>,
}

/// 根据当前位置与总时长计算 0.0~1.0 进度比。
pub(crate) fn compute_progress_ratio(
    position_secs: f64,
    duration_secs: Option<f64>,
) -> Option<f64> {
    duration_secs.map(|total| {
        if total > 0.0 {
            (position_secs / total).clamp(0.0, 1.0)
        } else {
            0.0
        }
    })
}

#[cfg(test)]
mod tests {
    use super::compute_progress_ratio;

    #[test]
    fn progress_ratio_none_when_duration_unknown() {
        assert_eq!(compute_progress_ratio(5.0, None), None);
    }

    #[test]
    fn progress_ratio_zero_when_duration_zero() {
        assert_eq!(compute_progress_ratio(3.0, Some(0.0)), Some(0.0));
    }

    #[test]
    fn progress_ratio_clamped() {
        assert_eq!(compute_progress_ratio(5.0, Some(10.0)), Some(0.5));
        assert_eq!(compute_progress_ratio(15.0, Some(10.0)), Some(1.0));
        assert_eq!(compute_progress_ratio(-1.0, Some(10.0)), Some(0.0));
    }
}
