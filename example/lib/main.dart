import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

import 'audio_samples.dart';

String _formatDuration(double secs) {
  final total = secs.round().clamp(0, 359999);
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

StreamSubscription<XueHuaPlaybackProgress> _subscribeTrackProgress({
  required XueHuaAudioTrack track,
  required void Function(XueHuaPlaybackProgress progress) onProgress,
  void Function(Object error)? onError,
  VoidCallback? onDone,
}) {
  onProgress(track.playbackProgress());
  return track.progressStream.listen(
    onProgress,
    onError: onError,
    onDone: onDone,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final player = await XueHuaAudio.initialize();
  runApp(AudioDemoApp(engine: player.engine));
}

class AudioDemoApp extends StatelessWidget {
  const AudioDemoApp({super.key, required this.engine});

  final XueHuaAudioEngine engine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xuehua Audio Demo',
      home: AudioDemoPage(engine: engine),
    );
  }
}

class AudioDemoPage extends StatefulWidget {
  const AudioDemoPage({super.key, required this.engine});

  final XueHuaAudioEngine engine;

  @override
  State<AudioDemoPage> createState() => _AudioDemoPageState();
}

class _AudioDemoPageState extends State<AudioDemoPage> {
  String _status = '就绪';

  Future<void> _setStatus(String message) async {
    if (!mounted) return;
    setState(() => _status = message);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xuehua Audio Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '录制'),
              Tab(text: '播放'),
            ],
          ),
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: SelectableText(_status)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  RecordingDemoTab(engine: widget.engine, onStatus: _setStatus),
                  PlaybackDemoTab(engine: widget.engine, onStatus: _setStatus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingDemoTab extends StatefulWidget {
  const RecordingDemoTab({
    super.key,
    required this.engine,
    required this.onStatus,
  });

  final XueHuaAudioEngine engine;
  final Future<void> Function(String message) onStatus;

  @override
  State<RecordingDemoTab> createState() => _RecordingDemoTabState();
}

class _RecordingDemoTabState extends State<RecordingDemoTab> {
  XuehuaRecordingSession? _session;
  StreamSubscription<XueHuaRecordingProgress>? _progressSub;
  StreamSubscription<XueHuaRecordingCompleted>? _completedSub;

  List<String> _devices = [];
  int? _selectedDeviceIndex;
  XueHuaRecordingProgress? _progress;
  String? _recordedPath;
  XueHuaAudioTrack? _playbackTrack;
  StreamSubscription<XueHuaPlaybackProgress>? _playbackProgressSub;
  XueHuaPlaybackProgress? _playbackProgress;

  Future<void> _cancelPlaybackProgress() async {
    await _playbackProgressSub?.cancel();
    _playbackProgressSub = null;
    _playbackProgress = null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadDevices());
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await widget.engine.listInputDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _selectedDeviceIndex = devices.isEmpty ? null : 0;
      });
    } on XueHuaAudioError catch (error) {
      await widget.onStatus('加载输入设备失败: $error');
    }
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    await widget.onStatus('麦克风权限被拒绝');
    return false;
  }

  Future<void> _run(String action, Future<void> Function() task) async {
    try {
      await task();
      await widget.onStatus('$action 成功');
    } on XueHuaAudioError catch (error) {
      await widget.onStatus('$action 失败: $error');
    } catch (error) {
      await widget.onStatus('$action 失败: $error');
    }
  }

  Future<String> _nextOutputPath() async {
    final dir = await getTemporaryDirectory();
    return p.join(
      dir.path,
      'xuehua_recording_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
  }

  Future<void> _startRecording() async {
    if (!await _ensureMicPermission()) return;
    await _progressSub?.cancel();
    await _completedSub?.cancel();
    await _session?.dispose();
    await _playbackTrack?.stopAndCleanup();
    await _cancelPlaybackProgress();
    _playbackTrack = null;

    final session = await widget.engine.createRecordingSession();
    final outputPath = await _nextOutputPath();
    _progressSub = session.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() => _progress = progress);
    });
    _completedSub = session.completedStream.listen((completed) {
      if (!mounted) return;
      setState(() => _recordedPath = completed.outputPath);
      unawaited(widget.onStatus('录制完成: ${completed.outputPath}'));
    });

    await session.start(
      outputPath: outputPath,
      deviceIndex: _selectedDeviceIndex,
    );
    setState(() {
      _session = session;
      _recordedPath = null;
      _progress = null;
    });
  }

  Future<void> _stopRecording() async {
    final session = _session;
    if (session == null) return;
    final path = await session.stop();
    setState(() {
      _recordedPath = path;
      _progress = null;
    });
  }

  Future<void> _playRecording() async {
    final path = _recordedPath;
    if (path == null) return;
    await _playbackTrack?.stopAndCleanup();
    await _cancelPlaybackProgress();
    final track = await widget.engine.loadLocal(path: path);
    _playbackProgressSub = _subscribeTrackProgress(
      track: track,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _playbackProgress = progress);
      },
      onError: (error) {
        unawaited(widget.onStatus('回放进度监听失败: $error'));
      },
      onDone: () {
        _playbackProgressSub = null;
      },
    );
    setState(() => _playbackTrack = track);
  }

  @override
  void dispose() {
    unawaited(_progressSub?.cancel());
    unawaited(_completedSub?.cancel());
    unawaited(_session?.dispose());
    unawaited(_playbackTrack?.stopAndCleanup());
    unawaited(_cancelPlaybackProgress());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final isRecording = session?.isRecording ?? false;
    final isPaused = session?.isPaused ?? false;
    final level = _progress?.level ?? 0.0;
    final durationSecs = _progress?.durationSecs ?? 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('输入设备', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_devices.isEmpty)
                  const Text('未检测到麦克风设备')
                else
                  DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedDeviceIndex,
                    items: [
                      for (var i = 0; i < _devices.length; i++)
                        DropdownMenuItem(value: i, child: Text(_devices[i])),
                    ],
                    onChanged: isRecording
                        ? null
                        : (value) =>
                              setState(() => _selectedDeviceIndex = value),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: isRecording
                          ? null
                          : () => _run('开始录制', _startRecording),
                      child: const Text('开始录制'),
                    ),
                    OutlinedButton(
                      onPressed: !isRecording || isPaused
                          ? null
                          : () => _run('暂停录制', () async {
                              await session!.pause();
                              setState(() {});
                            }),
                      child: const Text('暂停'),
                    ),
                    OutlinedButton(
                      onPressed: !isRecording || !isPaused
                          ? null
                          : () => _run('恢复录制', () async {
                              await session!.resume();
                              setState(() {});
                            }),
                      child: const Text('恢复'),
                    ),
                    OutlinedButton(
                      onPressed: !isRecording
                          ? null
                          : () => _run('停止录制', _stopRecording),
                      child: const Text('停止'),
                    ),
                    OutlinedButton(
                      onPressed: _recordedPath == null
                          ? null
                          : () => _run('播放录音', _playRecording),
                      child: const Text('播放录音'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDuration(durationSecs),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: level.clamp(0.0, 1.0)),
                const SizedBox(height: 4),
                Text(
                  [
                    if (isRecording && !isPaused) '录制中',
                    if (isRecording && isPaused) '已暂停',
                    if (!isRecording && _recordedPath != null) '已完成',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (_recordedPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _recordedPath!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_playbackTrack != null && _playbackProgress != null) ...[
                  const SizedBox(height: 16),
                  Text('录音回放', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatDuration(_playbackProgress!.positionSecs),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_playbackProgress!.progress ?? 0.0).clamp(
                            0.0,
                            1.0,
                          ),
                        ),
                      ),
                      Text(
                        _playbackProgress!.durationSecs == null
                            ? '--:--'
                            : _formatDuration(_playbackProgress!.durationSecs!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Text(
                    [
                      if (_playbackProgress!.isPlaying) '播放中',
                      if (_playbackProgress!.isPaused) '已暂停',
                      if (_playbackProgress!.isFinished) '已播完',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PlaybackDemoTab extends StatefulWidget {
  const PlaybackDemoTab({
    super.key,
    required this.engine,
    required this.onStatus,
  });

  final XueHuaAudioEngine engine;
  final Future<void> Function(String message) onStatus;

  @override
  State<PlaybackDemoTab> createState() => _PlaybackDemoTabState();
}

class _PlaybackDemoTabState extends State<PlaybackDemoTab> {
  final Map<String, XueHuaAudioTrack> _tracks = {};
  final Map<String, XueHuaPlaybackProgress> _progress = {};
  final Map<String, double> _volumes = {
    for (final sample in audioSamples) sample.$2: 1.0,
  };
  final Set<String> _seekingKeys = {};
  final Map<String, double> _seekDragValues = {};
  final Set<String> _finishedNotified = {};

  final Map<String, StreamSubscription<XueHuaPlaybackProgress>> _progressSubs =
      {};

  XueHuaAudioEngine get _engine => widget.engine;

  void _watchProgress(String assetKey, XueHuaAudioTrack track) {
    unawaited(_progressSubs.remove(assetKey)?.cancel());
    _progressSubs[assetKey] = _subscribeTrackProgress(
      track: track,
      onProgress: (progress) {
        if (!mounted) return;
        if (progress.isFinished && !_finishedNotified.contains(assetKey)) {
          _finishedNotified.add(assetKey);
          final label = audioSamples
              .firstWhere((sample) => sample.$2 == assetKey)
              .$1;
          unawaited(widget.onStatus('$label 播放完成'));
          final finishedTrack = _tracks.remove(assetKey);
          if (finishedTrack != null) {
            unawaited(finishedTrack.stopAndCleanup());
          }
        }
        setState(() {
          _progress[assetKey] = progress;
        });
      },
      onError: (Object error) {
        unawaited(widget.onStatus('进度监听失败: $error'));
      },
      onDone: () {
        _progressSubs.remove(assetKey);
      },
    );
  }

  Future<void> _run(String action, Future<void> Function() task) async {
    try {
      await task();
      await widget.onStatus('$action 成功');
    } on XueHuaAudioError catch (error) {
      await widget.onStatus('$action 失败: $error');
    } catch (error) {
      await widget.onStatus('$action 失败: $error');
    }
  }

  Future<void> _playAsset(String assetKey) async {
    await _progressSubs.remove(assetKey)?.cancel();
    final existing = _tracks.remove(assetKey);
    if (existing != null) {
      await existing.stopAndCleanup();
    }
    _progress.remove(assetKey);
    _finishedNotified.remove(assetKey);

    final track = await _engine.loadAsset(assetKey: assetKey);
    final volume = _volumes[assetKey] ?? 1.0;
    await track.setVolume(volume: volume);
    _tracks[assetKey] = track;
    _watchProgress(assetKey, track);
  }

  Future<void> _stopAsset(String assetKey) async {
    await _progressSubs.remove(assetKey)?.cancel();
    final track = _tracks.remove(assetKey);
    if (track != null) {
      await track.stopAndCleanup();
    }
    _progress.remove(assetKey);
    _finishedNotified.remove(assetKey);
    _seekingKeys.remove(assetKey);
    _seekDragValues.remove(assetKey);
  }

  Future<void> _playAll() async {
    for (final sample in audioSamples) {
      await _playAsset(sample.$2);
    }
  }

  Future<void> _stopAll() async {
    for (final sub in _progressSubs.values) {
      await sub.cancel();
    }
    _progressSubs.clear();
    final tracks = _tracks.values.toList();
    _tracks.clear();
    for (final track in tracks) {
      await track.stopAndCleanup();
    }
    await _engine.stopAllWithCleanup();
  }

  @override
  void dispose() {
    for (final sub in _progressSubs.values) {
      unawaited(sub.cancel());
    }
    _progressSubs.clear();
    for (final track in _tracks.values) {
      unawaited(track.stopAndCleanup());
    }
    _tracks.clear();
    unawaited(_engine.stopAllWithCleanup());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              FilledButton(
                onPressed: () => _run('全部播放', _playAll),
                child: const Text('全部播放'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _run('全部停止', _stopAll),
                child: const Text('全部停止'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: audioSamples.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final (label, assetKey) = audioSamples[index];
              final track = _tracks[assetKey];
              final volume = _volumes[assetKey] ?? 1.0;
              final progress = _progress[assetKey];
              final isSeeking = _seekingKeys.contains(assetKey);
              final sliderValue = isSeeking
                  ? (_seekDragValues[assetKey] ?? progress?.progress ?? 0.0)
                  : (progress?.progress ?? 0.0);
              final durationSecs = progress?.durationSecs;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assetKey,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () => _run('播放 $label', () async {
                              await _playAsset(assetKey);
                              setState(() {});
                            }),
                            child: const Text('播放'),
                          ),
                          OutlinedButton(
                            onPressed: track == null
                                ? null
                                : () => _run('暂停 $label', () async {
                                    await track.pause();
                                  }),
                            child: const Text('暂停'),
                          ),
                          OutlinedButton(
                            onPressed: track == null
                                ? null
                                : () => _run('恢复 $label', () async {
                                    await track.resume();
                                  }),
                            child: const Text('恢复'),
                          ),
                          OutlinedButton(
                            onPressed: track == null
                                ? null
                                : () => _run('停止 $label', () async {
                                    await _stopAsset(assetKey);
                                    setState(() {});
                                  }),
                            child: const Text('停止'),
                          ),
                        ],
                      ),
                      if (track != null && progress != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _formatDuration(progress.positionSecs),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Expanded(
                              child: Slider(
                                value: sliderValue.clamp(0.0, 1.0),
                                onChangeStart: durationSecs == null
                                    ? null
                                    : (_) {
                                        _seekingKeys.add(assetKey);
                                      },
                                onChanged: durationSecs == null
                                    ? null
                                    : (value) {
                                        _seekDragValues[assetKey] = value;
                                        setState(() {});
                                      },
                                onChangeEnd: durationSecs == null
                                    ? null
                                    : (value) => _run('跳转 $label', () async {
                                        _seekingKeys.remove(assetKey);
                                        _seekDragValues.remove(assetKey);
                                        await track.seekTo(
                                          positionSecs: value * durationSecs,
                                        );
                                      }),
                              ),
                            ),
                            Text(
                              durationSecs == null
                                  ? '--:--'
                                  : _formatDuration(durationSecs),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          [
                            if (progress.isPlaying) '播放中',
                            if (progress.isPaused) '已暂停',
                            if (progress.isFinished) '已播完',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('音量'),
                          Expanded(
                            child: Slider(
                              value: volume,
                              onChanged: track == null
                                  ? null
                                  : (value) async {
                                      _volumes[assetKey] = value;
                                      await track.setVolume(volume: value);
                                      setState(() {});
                                    },
                            ),
                          ),
                          Text('${(volume * 100).round()}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
