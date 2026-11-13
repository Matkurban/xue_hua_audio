import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../audio_recorder.dart';
import '../../types/player_state.dart';
import 'waveform_controller.dart';

/// Default colors of the waveform widgets. The library does not depend on
/// Material, so these are fixed values; pass `color` / `gradient` /
/// `inactiveColor` to customize.
///
/// 波形组件的默认颜色。本库不依赖 Material，因此使用固定值；
/// 可通过 `color` / `gradient` / `inactiveColor` 自定义。
abstract final class WaveformColors {
  /// Active bars/lines: a fresh green. / 活动柱/线：清新的绿色。
  static const Color active = Color(0xFF22A45D);

  /// Idle dots and unplayed bars: a muted cool gray.
  /// 空闲圆点与未播放柱：柔和的冷灰色。
  static const Color inactive = Color(0xFFB8BEC4);
}

/// Base widget for live recording visualizers driven by an [AudioRecorder],
/// a dBFS [levels] stream, or a [WaveformController].
///
/// 由 [AudioRecorder]、dBFS [levels] 流或 [WaveformController] 驱动的
/// 实时录音可视化组件基类。
abstract class RecordingVisualizerBase extends StatefulWidget {
  /// Creates a recording visualizer base. / 创建录音可视化组件基类。
  const RecordingVisualizerBase({
    super.key,
    this.recorder,
    this.levels,
    this.controller,
    this.active,
    this.color,
    this.gradient,
    this.inactiveColor,
    this.height = 72,
    this.minDb = -50,
    this.maxDb = 0,
    this.semanticLabel,
  }) : assert(recorder == null || levels == null);

  /// Recorder whose amplitude/state drive the visualizer.
  /// 驱动可视化组件的录音器（振幅与状态）。
  final AudioRecorder? recorder;

  /// A stream of levels in dBFS. / dBFS 电平流。
  final Stream<double>? levels;

  /// External controller; created internally when null.
  /// 外部控制器；为空则内部自动创建。
  final WaveformController? controller;

  /// Overrides whether the visualizer advances.
  /// 覆盖是否处于激活推进状态。
  final bool? active;

  /// Primary active color; defaults to [WaveformColors.active].
  /// 主活动颜色，默认 [WaveformColors.active]。
  final Color? color;

  /// Optional gradient applied across the active geometry.
  /// 可选渐变色。
  final Gradient? gradient;

  /// Idle / unlit color; defaults to [WaveformColors.inactive].
  /// 空闲/未点亮颜色，默认 [WaveformColors.inactive]。
  final Color? inactiveColor;

  /// Widget height in logical pixels. / 组件高度（逻辑像素）。
  final double height;

  /// dBFS floor mapped to 0 when creating an internal controller.
  /// 内部创建控制器时的噪声门限（dBFS）。
  final double minDb;

  /// dBFS ceiling mapped to 1 when creating an internal controller.
  /// 内部创建控制器时的满刻度上限（dBFS）。
  final double maxDb;

  /// Accessibility label. / 无障碍语义标签。
  final String? semanticLabel;

  /// Default accessibility label when [semanticLabel] is null.
  /// 未指定 [semanticLabel] 时的默认无障碍标签。
  @protected
  String defaultSemanticLabel(bool isActive);

  /// Builds the [CustomPainter] driving this visualizer.
  /// 构建当前可视化组件的 [CustomPainter]。
  @protected
  CustomPainter buildPainter(
    BuildContext context,
    WaveformController controller,
    TextDirection textDirection,
  );

  @override
  State<RecordingVisualizerBase> createState() =>
      _RecordingVisualizerBaseState();
}

class _RecordingVisualizerBaseState extends State<RecordingVisualizerBase>
    with SingleTickerProviderStateMixin {
  late WaveformController _controller;
  bool _ownsController = false;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  StreamSubscription<Object?>? _levelSub;
  StreamSubscription<Object?>? _stateSub;
  bool _wasPaused = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _setUp();
  }

  @override
  void didUpdateWidget(covariant RecordingVisualizerBase old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        old.recorder != widget.recorder ||
        old.levels != widget.levels ||
        old.active != widget.active ||
        (_ownsController &&
            (old.minDb != widget.minDb || old.maxDb != widget.maxDb))) {
      _tearDown();
      _setUp();
    }
  }

  void _setUp() {
    final external = widget.controller;
    if (external != null) {
      _controller = external;
      _ownsController = false;
    } else {
      _controller = WaveformController(
        minDb: widget.minDb,
        maxDb: widget.maxDb,
      );
      _ownsController = true;
    }
    final recorder = widget.recorder;
    if (recorder != null) {
      _levelSub = recorder.onAmplitudeChanged.listen(
        (a) => _controller.addDb(a.current),
      );
      _stateSub = recorder.onStateChanged.listen(_onRecorderState);
      _applyActive(recorder.state == RecorderState.recording);
    } else if (widget.levels != null) {
      _levelSub = widget.levels!.listen(_controller.addDb);
      _applyActive(true);
    } else if (widget.active != null) {
      _applyActive(widget.active!);
    }
    _controller.addListener(_syncTicker);
    _syncTicker();
  }

  void _tearDown() {
    _controller.removeListener(_syncTicker);
    _levelSub?.cancel();
    _stateSub?.cancel();
    _levelSub = _stateSub = null;
    if (_ownsController) _controller.dispose();
  }

  void _onRecorderState(RecorderState s) {
    if (s == RecorderState.recording && !_wasPaused) _controller.clear();
    _wasPaused = s == RecorderState.paused;
    _applyActive(s == RecorderState.recording);
  }

  void _applyActive(bool value) => _controller.active = widget.active ?? value;

  void _syncTicker() {
    if (_controller.active) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _last;
    _last = elapsed;
    _controller.advance(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tearDown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final label =
        widget.semanticLabel ?? widget.defaultSemanticLabel(_controller.active);
    return Semantics(
      label: label,
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: widget.buildPainter(context, _controller, direction),
          ),
        ),
      ),
    );
  }
}
