import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

import '../common/device_selector.dart';
import 'visualizer_gallery.dart';
import 'visualizer_selector.dart';

/// Microphone recording demonstration card featuring 17 live recording
/// visualizers, a side-by-side gallery mode, playback preview, and input
/// device routing.
/// 麦克风录音演示卡片：内置 17 种实时录音可视化组件、全景同屏预览模式、录音回放及输入设备切换。
class RecorderCard extends StatefulWidget {
  /// Creates a recorder demo card. / 创建录音演示卡片。
  const RecorderCard({super.key});

  @override
  State<RecorderCard> createState() => _RecorderCardState();
}

class _RecorderCardState extends State<RecorderCard> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _playback = AudioPlayer();

  RecorderState _state = RecorderState.idle;
  final WaveformController _wave = WaveformController();
  final List<double> _saved = [];
  RecordingVisualizerType _visualizerType = RecordingVisualizerType.waveform;
  WaveformStyle _style = WaveformStyle.bars;
  bool _showGallery = false;
  double _playProgress = 0;
  String? _lastRecording;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recorder.onStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _recorder.onAmplitudeChanged.listen((amplitude) {
      if (!mounted) return;
      _saved.add(_wave.normalize(amplitude.current));
      if (_saved.length > 4000) _saved.removeAt(0);
    });
    _playback.onPositionChanged.listen((p) {
      final d = _playback.duration;
      if (mounted && d != null && d.inMilliseconds > 0) {
        setState(() => _playProgress = p.inMilliseconds / d.inMilliseconds);
      }
    });
    _recorder.onError.listen((error) {
      if (mounted) setState(() => _error = error.toString());
    });
  }

  @override
  void dispose() {
    _wave.dispose();
    _recorder.dispose();
    _playback.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _saved.clear();
      _playProgress = 0;
      _lastRecording = null;
    });
    try {
      if (!await _recorder.hasPermission().timeout(
        const Duration(seconds: 8),
      )) {
        setState(() => _error = '未获得麦克风权限 / Microphone permission denied');
        return;
      }
      var path = '';
      if (!kIsWeb) {
        Directory dir;
        try {
          dir = await getApplicationDocumentsDirectory();
        } on MissingPlatformDirectoryException {
          // Minimal Linux setups (e.g. containers) have no documents dir.
          // 精简的 Linux 环境（如容器）没有文档目录。
          dir = Directory.systemTemp;
        }
        path =
            '${dir.path}/xue_hua_${DateTime.now().millisecondsSinceEpoch}.wav';
      }
      await _recorder
          .start(const RecordConfig(), path: path)
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      setState(() => _error = '录音启动超时 / recorder start timed out');
    } on AudioError catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _stop() async {
    try {
      final path = await _recorder.stop();
      setState(() => _lastRecording = path);
    } on AudioError catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _playRecording() async {
    final path = _lastRecording;
    if (path == null) return;
    // On the Web `stop()` returns a blob URL; elsewhere it is a file path.
    // Web 端 `stop()` 返回 blob URL，其余平台为文件路径。
    final source = path.startsWith('blob:') || path.startsWith('http')
        ? AudioSource.url(path)
        : AudioSource.file(path);
    await _playback.setSource(source);
    await _playback.play();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recording = _state == RecorderState.recording;
    final paused = _state == RecorderState.paused;
    final gradient = LinearGradient(colors: [scheme.primary, scheme.tertiary]);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic),
                const SizedBox(width: 8),
                Text(
                  '录音机 Recorder',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilterChip(
                  key: const ValueKey('toggle-visualizer-gallery'),
                  label: const Text('全景预览 Gallery'),
                  selected: _showGallery,
                  onSelected: (v) => setState(() => _showGallery = v),
                ),
                const SizedBox(width: 8),
                Chip(label: Text(_state.name)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: RecordingVisualizer(
                key: const ValueKey('live-waveform'),
                type: _visualizerType,
                waveformStyle: _style,
                recorder: _recorder,
                controller: _wave,
                height: 88,
                gradient: gradient,
              ),
            ),
            if (_showGallery) ...[
              const SizedBox(height: 12),
              VisualizerGallery(
                controller: _wave,
                gradient: gradient,
                selectedType: _visualizerType,
                onSelect: (type) => setState(() => _visualizerType = type),
              ),
            ],
            const SizedBox(height: 8),
            VisualizerSelector(
              selectedType: _visualizerType,
              waveformStyle: _style,
              onTypeChanged: (type) => setState(() => _visualizerType = type),
              onStyleChanged: (style) => setState(() {
                _style = style;
                _visualizerType = RecordingVisualizerType.waveform;
              }),
            ),
            if (_lastRecording != null && _saved.isNotEmpty) ...[
              const SizedBox(height: 12),
              StaticWaveform(
                levels: List.of(_saved),
                progress: _playProgress,
                height: 40,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  key: const ValueKey('rec-start'),
                  onPressed: recording || paused ? null : _start,
                  icon: const Icon(Icons.fiber_manual_record, size: 18),
                  label: const Text('开始录音'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('rec-pause-resume'),
                  onPressed: recording
                      ? _recorder.pause
                      : (paused ? _recorder.resume : null),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 18),
                  label: Text(paused ? '继续' : '暂停'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('rec-stop'),
                  onPressed: recording || paused ? _stop : null,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('停止'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('rec-cancel'),
                  onPressed: recording || paused
                      ? () => _recorder.cancel()
                      : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('取消'),
                ),
                if (_lastRecording != null)
                  FilledButton.icon(
                    key: const ValueKey('rec-play'),
                    onPressed: _playRecording,
                    icon: const Icon(Icons.play_circle, size: 18),
                    label: const Text('播放录音'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DeviceSelector(
              icon: Icons.settings_voice,
              label: '输入设备 Input device',
              listDevices: _recorder.listInputDevices,
              onSelected: _recorder.setInputDevice,
            ),
            if (_lastRecording != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '录音文件：$_lastRecording',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}
