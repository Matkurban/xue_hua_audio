// xue_hua_audio example: playback (file/URL/asset) and microphone
// recording with a live waveform.
// xue_hua_audio 示例：三种音频源播放 + 麦克风录音实时波形。
import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

void main() {
  runApp(const ExampleApp());
}

/// Root widget of the demo app. / 示例应用根组件。
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xue_hua_audio demo',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6CFF),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

/// Home page hosting the player and recorder demos.
/// 承载播放与录音演示的主页。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('xue_hua_audio 2.0')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PlayerCard(),
          SizedBox(height: 16),
          RecorderCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Device selector / 设备选择器
// ---------------------------------------------------------------------------

/// A dropdown that enumerates audio devices and applies the selection —
/// used for the player output device and the recorder input device.
/// 枚举音频设备并应用所选设备的下拉框——用于播放器输出设备与录音机输入设备。
class DeviceSelector extends StatefulWidget {
  const DeviceSelector({
    super.key,
    required this.icon,
    required this.label,
    required this.listDevices,
    required this.onSelected,
  });

  /// Leading icon. / 前置图标。
  final IconData icon;

  /// Dropdown label. / 下拉框标签。
  final String label;

  /// Enumerates the selectable devices. / 枚举可选设备。
  final Future<List<AudioDevice>> Function() listDevices;

  /// Applies the selection (`null` = system default).
  /// 应用所选设备（`null` 表示系统默认）。
  final Future<void> Function(String? deviceId) onSelected;

  @override
  State<DeviceSelector> createState() => _DeviceSelectorState();
}

class _DeviceSelectorState extends State<DeviceSelector> {
  List<AudioDevice> _devices = [];
  String? _selectedId;

  Future<void> _refresh() async {
    try {
      final devices = await widget.listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (_selectedId != null && !devices.any((d) => d.id == _selectedId)) {
          _selectedId = null;
        }
      });
    } on AudioError catch (e) {
      _showError(e);
    }
  }

  Future<void> _select(String? deviceId) async {
    try {
      await widget.onSelected(deviceId);
      if (mounted) setState(() => _selectedId = deviceId);
    } on AudioError catch (e) {
      _showError(e);
    }
  }

  void _showError(AudioError error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(widget.icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('系统默认 System default'),
              ),
              for (final device in _devices)
                DropdownMenuItem<String?>(
                  value: device.id,
                  child: Text(device.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _select,
          ),
        ),
        IconButton(
          tooltip: '刷新设备列表 Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Playback demo / 播放演示
// ---------------------------------------------------------------------------

class PlayerCard extends StatefulWidget {
  const PlayerCard({super.key});

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _urlController = TextEditingController(
    text:
        'https://commondatastorage.googleapis.com/codeskulptor-assets/Epoq-Lepidoptera.ogg',
  );

  PlayerState _state = PlayerState.idle;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _looping = false;
  String? _error;
  bool _seeking = false;

  static const List<(String, String)> _assets = [
    ('assets/audio/live_ring.wav', '直播铃声'),
    ('assets/audio/message_ring.wav', '消息提示'),
    ('assets/audio/meeting_mic_turn_on.wav', '开麦提示'),
  ];

  @override
  void initState() {
    super.initState();
    _player.onStateChanged.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _player.onPositionChanged.listen((position) {
      if (mounted && !_seeking) setState(() => _position = position);
    });
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _player.onError.listen((error) {
      if (mounted) setState(() => _error = error.toString());
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load(AudioSource source) async {
    setState(() {
      _error = null;
      _position = Duration.zero;
    });
    try {
      await _player.setSource(source);
      await _player.setVolume(_volume);
      await _player.setSpeed(_speed);
      await _player.setLooping(_looping);
      await _player.play();
    } on AudioError catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration ?? Duration.zero;
    final maxMs = total.inMilliseconds.toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note),
                const SizedBox(width: 8),
                Text('播放器 Player', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Chip(label: Text(_state.name)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, label) in _assets)
                  FilledButton.tonalIcon(
                    onPressed: () => _load(AudioSource.asset(key)),
                    icon: const Icon(Icons.library_music, size: 18),
                    label: Text(label),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: '网络音频 URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () =>
                      _load(AudioSource.url(_urlController.text.trim())),
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('播放 URL'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(_format(_position)),
                Expanded(
                  child: Slider(
                    value: _position.inMilliseconds
                        .clamp(0, maxMs.toInt())
                        .toDouble(),
                    max: maxMs > 0 ? maxMs : 1,
                    onChangeStart: (_) => _seeking = true,
                    onChanged: maxMs > 0
                        ? (value) => setState(() =>
                            _position = Duration(milliseconds: value.round()))
                        : null,
                    onChangeEnd: (value) async {
                      _seeking = false;
                      await _player
                          .seek(Duration(milliseconds: value.round()));
                    },
                  ),
                ),
                Text(_duration == null ? '--:--' : _format(total)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: () => _player.state == PlayerState.playing
                      ? _player.pause()
                      : _player.play(),
                  icon: Icon(_state == PlayerState.playing
                      ? Icons.pause
                      : Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _player.stop(),
                  icon: const Icon(Icons.stop),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.volume_up, size: 18),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _volume,
                    onChanged: (value) {
                      setState(() => _volume = value);
                      _player.setVolume(value);
                    },
                  ),
                ),
                const Icon(Icons.speed, size: 18),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: '${_speed.toStringAsFixed(2)}x',
                    onChanged: (value) {
                      setState(() => _speed = value);
                      _player.setSpeed(value);
                    },
                  ),
                ),
                const Text('循环'),
                Switch(
                  value: _looping,
                  onChanged: (value) {
                    setState(() => _looping = value);
                    _player.setLooping(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            DeviceSelector(
              icon: Icons.speaker,
              label: '输出设备 Output device',
              listDevices: AudioPlayer.listOutputDevices,
              onSelected: _player.setOutputDevice,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recording demo / 录音演示
// ---------------------------------------------------------------------------

class RecorderCard extends StatefulWidget {
  const RecorderCard({super.key});

  @override
  State<RecorderCard> createState() => _RecorderCardState();
}

class _RecorderCardState extends State<RecorderCard> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _playback = AudioPlayer();

  RecorderState _state = RecorderState.idle;
  final List<double> _waveform = [];
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
      setState(() {
        _waveform.add(amplitude.normalized);
        if (_waveform.length > 120) {
          _waveform.removeAt(0);
        }
      });
    });
    _recorder.onError.listen((error) {
      if (mounted) setState(() => _error = error.toString());
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _playback.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _waveform.clear();
      _lastRecording = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = '未获得麦克风权限 / Microphone permission denied');
        return;
      }
      var path = '';
      if (!kIsWeb) {
        final Directory dir = await getApplicationDocumentsDirectory();
        path =
            '${dir.path}/xue_hua_${DateTime.now().millisecondsSinceEpoch}.wav';
      }
      await _recorder.start(const RecordConfig(), path: path);
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic),
                const SizedBox(width: 8),
                Text('录音机 Recorder',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Chip(label: Text(_state.name)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 96,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(
                painter: _WaveformPainter(
                  values: _waveform,
                  color: recording ? scheme.primary : scheme.outline,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: recording || paused ? null : _start,
                  icon: const Icon(Icons.fiber_manual_record, size: 18),
                  label: const Text('开始录音'),
                ),
                FilledButton.tonalIcon(
                  onPressed: recording
                      ? _recorder.pause
                      : (paused ? _recorder.resume : null),
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 18),
                  label: Text(paused ? '继续' : '暂停'),
                ),
                FilledButton.tonalIcon(
                  onPressed: recording || paused ? _stop : null,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('停止'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      recording || paused ? () => _recorder.cancel() : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('取消'),
                ),
                if (_lastRecording != null)
                  FilledButton.icon(
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
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Paints amplitude history as vertical waveform bars.
/// 将振幅历史绘制为垂直波形柱。
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const barSpacing = 5.0;
    final barCount = (size.width / barSpacing).floor();
    final start = values.length > barCount ? values.length - barCount : 0;
    final centerY = size.height / 2;
    for (var i = start; i < values.length; i++) {
      final x = size.width - (values.length - i) * barSpacing;
      final barHeight = (values[i] * size.height * 0.9).clamp(2.0, size.height);
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
