// End-to-end playback / recording check for the desktop implementations.
// Plays every bundled test format from a file, an HTTP URL (served by an
// in-process Range-capable server) and a Flutter asset, then records with
// every encoder and plays the result back.
//
// Run headless on Linux with a null PulseAudio sink, see
// integration_test/README.md.
//
// 桌面端到端播放/录音检查：对每种测试格式分别以文件、HTTP URL（进程内支持
// Range 的服务器）与 Flutter Asset 方式播放，再用每种编码器录音并回放。
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

const _formats = ['wav', 'm4a', 'mp3', 'flac', 'ogg', 'opus'];
const _expected = Duration(seconds: 2);
const _tolerance = Duration(milliseconds: 150);

class _Run {
  Duration? loaded;
  Duration? finalDuration;
  Duration maxPosition = Duration.zero;
  final states = <PlayerState>[];
  final errors = <AudioError>[];
  @override
  String toString() =>
      'loaded=$loaded final=$finalDuration maxPos=$maxPosition '
      'states=$states errors=$errors';
}

Future<_Run> _play(AudioSource source) async {
  final player = AudioPlayer();
  final run = _Run();
  final done = Completer<void>();
  final subs = [
    player.onError.listen(run.errors.add),
    player.onStateChanged.listen(run.states.add),
    player.onPositionChanged.listen((p) {
      if (p > run.maxPosition) run.maxPosition = p;
    }),
    player.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    }),
  ];
  try {
    run.loaded = await player
        .setSource(source)
        .timeout(const Duration(seconds: 10));
    await player.play();
    await done.future.timeout(const Duration(seconds: 15));
    run.finalDuration = player.duration;
  } finally {
    for (final s in subs) {
      await s.cancel();
    }
    await player.dispose();
  }
  return run;
}

void _expectClose(Duration? actual, Duration expected, String what) {
  expect(actual, isNotNull, reason: '$what is null');
  expect(
    (actual! - expected).abs() <= _tolerance,
    isTrue,
    reason: '$what=$actual, expected ≈$expected',
  );
}

void _expectPlayed(_Run run, Duration expected) {
  expect(run.errors, isEmpty, reason: '$run');
  expect(run.states.last, PlayerState.completed, reason: '$run');
  _expectClose(run.finalDuration, expected, 'final duration ($run)');
  _expectClose(run.maxPosition, expected, 'max position ($run)');
}

/// Minimal static file server with HTTP Range support (Ogg demuxing needs
/// seekable HTTP). / 支持 Range 的最小静态文件服务器（Ogg 解复用需要可寻址 HTTP）。
Future<HttpServer> _serve(Directory root) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final file = File('${root.path}${req.uri.path}');
    final res = req.response;
    if (!file.existsSync()) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final length = file.lengthSync();
    var start = 0, end = length - 1;
    final range = RegExp(r'bytes=(\d*)-(\d*)')
        .firstMatch(req.headers.value(HttpHeaders.rangeHeader) ?? '');
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (range != null) {
      start = int.tryParse(range[1]!) ?? 0;
      end = int.tryParse(range[2]!) ?? end;
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$length',
      );
    }
    res.contentLength = end - start + 1;
    if (req.method != 'HEAD') {
      await res.addStream(file.openRead(start, end + 1));
    }
    await res.close();
  });
  return server;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late HttpServer server;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('xha_it');
    for (final f in _formats) {
      final data = await rootBundle.load('assets/test_audio/tone.$f');
      await File('${dir.path}/tone.$f').writeAsBytes(data.buffer.asUint8List());
    }
    server = await _serve(dir);
  });
  tearDownAll(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  for (final f in _formats) {
    group(f, () {
      testWidgets('file', (_) async {
        _expectPlayed(
          await _play(AudioSource.file('${dir.path}/tone.$f')),
          _expected,
        );
      });
      testWidgets('url', (_) async {
        _expectPlayed(
          await _play(
            AudioSource.url('http://127.0.0.1:${server.port}/tone.$f'),
          ),
          _expected,
        );
      });
      testWidgets('asset', (_) async {
        _expectPlayed(
          await _play(AudioSource.asset('assets/test_audio/tone.$f')),
          _expected,
        );
      });
    });
  }

  testWidgets('missing url reports sourceLoadFailed', (_) async {
    await expectLater(
      _play(AudioSource.url('http://127.0.0.1:${server.port}/missing.mp3')),
      throwsA(isA<AudioError>()),
    );
  });

  const ext = {
    AudioEncoder.wav: 'wav',
    AudioEncoder.aacLc: 'm4a',
    AudioEncoder.opus: 'ogg',
  };
  for (final encoder in AudioEncoder.values) {
    testWidgets('record ${encoder.name}', (_) async {
      final recorder = AudioRecorder();
      final errors = <AudioError>[];
      final amplitudes = <Amplitude>[];
      final subs = [
        recorder.onError.listen(errors.add),
        recorder.onAmplitudeChanged.listen(amplitudes.add),
      ];
      final path = '${dir.path}/rec_${encoder.name}.${ext[encoder]}';
      try {
        await recorder.start(RecordConfig(encoder: encoder), path: path);
        await Future<void>.delayed(const Duration(seconds: 2));
        expect(await recorder.stop(), path);
      } finally {
        for (final s in subs) {
          await s.cancel();
        }
        await recorder.dispose();
      }
      expect(errors, isEmpty);
      expect(amplitudes, isNotEmpty);
      // With a tone playing into the monitored sink the level must be real.
      // 若有测试音输入，振幅必须为真实值（非 -160 的占位值）。
      if (Platform.environment['XHA_EXPECT_SIGNAL'] == '1') {
        expect(
          amplitudes.map((a) => a.current).reduce((a, b) => a > b ? a : b),
          greaterThan(-60),
        );
      }
      expect(File(path).lengthSync(), greaterThan(1000));
      final run = await _play(AudioSource.file(path));
      expect(run.errors, isEmpty, reason: '$run');
      expect(run.states.last, PlayerState.completed, reason: '$run');
      expect(
        run.finalDuration!.inMilliseconds,
        greaterThan(1500),
        reason: '$run',
      );
    });
  }
}
