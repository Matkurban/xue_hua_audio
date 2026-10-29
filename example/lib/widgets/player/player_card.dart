import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

import '../common/device_selector.dart';

/// Audio playback demonstration card supporting assets, URLs, seeking,
/// volume, speed, looping, and output device selection.
/// 音频播放演示卡片：支持内置资源与网络音频播放、进度拖拽、音量、倍速、循环及输出设备切换。
class PlayerCard extends StatefulWidget {
  /// Creates a player demo card. / 创建播放器演示卡片。
  const PlayerCard({super.key});

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _urlController = TextEditingController(
    text: 'https://commondatastorage.googleapis.com/codeskulptor-assets/Epoq-Lepidoptera.ogg',
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
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note),
                const SizedBox(width: 8),
                Text(
                  '播放器 Player',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
                    key: ValueKey('asset-$key'),
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
                  key: const ValueKey('play-url'),
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
                        ? (value) => setState(
                            () => _position = Duration(
                              milliseconds: value.round(),
                            ),
                          )
                        : null,
                    onChangeEnd: (value) async {
                      _seeking = false;
                      await _player.seek(Duration(milliseconds: value.round()));
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
                  key: const ValueKey('player-play-pause'),
                  onPressed: () => _player.state == PlayerState.playing
                      ? _player.pause()
                      : _player.play(),
                  icon: Icon(
                    _state == PlayerState.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('player-stop'),
                  onPressed: () => _player.stop(),
                  icon: const Icon(Icons.stop),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.volume_up, size: 18),
                SizedBox(
                  width: 80,
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
                  width: 80,
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
                  materialTapTargetSize: .shrinkWrap,
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
