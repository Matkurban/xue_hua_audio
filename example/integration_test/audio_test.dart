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
      // Ogg Vorbis: AVPlayer still Cannot Open / sourceLoadFailed on iOS.
      // Ogg Opus: fails on older iOS (verified 17); plays on newer (verified 26/27).
      // Ogg Vorbis：iOS 上 AVPlayer 仍 Cannot Open / sourceLoadFailed。
      // Ogg Opus：旧版 iOS 失败（已在 17 验证）；较新系统可播（已在 26/27 验证）。
      final iosMajor = () {
        if (!Platform.isIOS) return 0;
        final m = RegExp(r'Version (\d+)')
            .firstMatch(Platform.operatingSystemVersion);
        return int.tryParse(m?.group(1) ?? '') ?? 0;
      }();
      final expectIosSourceLoadFailed = Platform.isIOS &&
          (f == 'ogg' || (f == 'opus' && iosMajor < 26));
      testWidgets('file', (_) async {
        final source = AudioSource.file('${dir.path}/tone.$f');
        if (expectIosSourceLoadFailed) {
          await expectLater(
            _play(source),
            throwsA(
              isA<AudioError>().having(
                (e) => e.code,
                'code',
                AudioError.codeSourceLoadFailed,
              ),
            ),
          );
          return;
        }
        _expectPlayed(await _play(source), _expected);
      });
      testWidgets('url', (_) async {
        final source = AudioSource.url(
          'http://127.0.0.1:${server.port}/tone.$f',
        );
        if (expectIosSourceLoadFailed) {
          await expectLater(
            _play(source),
            throwsA(
              isA<AudioError>().having(
                (e) => e.code,
                'code',
                AudioError.codeSourceLoadFailed,
              ),
            ),
          );
          return;
        }
        _expectPlayed(await _play(source), _expected);
      });
      testWidgets('asset', (_) async {
        final source = AudioSource.asset('assets/test_audio/tone.$f');
        if (expectIosSourceLoadFailed) {
          await expectLater(
            _play(source),
            throwsA(
              isA<AudioError>().having(
                (e) => e.code,
                'code',
                AudioError.codeSourceLoadFailed,
              ),
            ),
          );
          return;
        }
        _expectPlayed(await _play(source), _expected);
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
      // Opus recording is intentionally unsupported on Android / iOS / macOS /
      // Windows. Assert the stable unsupportedEncoder code on those platforms.
      // Android / iOS / macOS / Windows 故意不支持 Opus 录音；断言稳定的
      // unsupportedEncoder 错误码。
      final opusUnsupported = encoder == AudioEncoder.opus &&
          (Platform.isWindows ||
              Platform.isIOS ||
              Platform.isMacOS ||
              Platform.isAndroid);
      if (opusUnsupported) {
        final recorder = AudioRecorder();
        final path = '${dir.path}/rec_opus_should_fail.ogg';
        await expectLater(
          recorder.start(RecordConfig(encoder: encoder), path: path),
          throwsA(
            isA<AudioError>().having(
              (e) => e.code,
              'code',
              AudioError.codeUnsupportedEncoder,
            ),
          ),
        );
        await recorder.dispose();
        return;
      }
      final recorder = AudioRecorder();
      final errors = <AudioError>[];
      final amplitudes = <Amplitude>[];
      final subs = [
        recorder.onError.listen(errors.add),
        recorder.onAmplitudeChanged.listen(amplitudes.add),
      ];
      final path = '${dir.path}/rec_${encoder.name}.${ext[encoder]}';
      try {
        expect(
          await recorder.hasPermission(),
          isTrue,
          reason: 'microphone permission required for recording tests',
        );
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

  testWidgets('seek volume speed loop and devices', (_) async {
    final player = AudioPlayer();
    final errors = <AudioError>[];
    final sub = player.onError.listen(errors.add);
    try {
      final outputs = await AudioPlayer.listOutputDevices();
      expect(outputs, isNotEmpty, reason: 'no output devices');

      final asset = File('${dir.path}/tone_seek.wav');
      final data = await rootBundle.load('assets/test_audio/tone.wav');
      await asset.writeAsBytes(data.buffer.asUint8List());

      final duration = await player.setSource(AudioSource.file(asset.path));
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThan(1500));

      await player.setVolume(0.35);
      await player.setSpeed(1.25);
      await player.setLooping(false);
      await player.play();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(player.state, PlayerState.playing);

      await player.seek(const Duration(milliseconds: 1000));
      // Allow the platform clock to settle after seek. / seek 后等平台时钟稳定。
      Duration? pos;
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        pos = await player.getPosition();
        if ((pos.inMilliseconds - 1000).abs() <= 250) break;
      }
      expect(
        (pos!.inMilliseconds - 1000).abs() <= 250,
        isTrue,
        reason: 'seek landed at $pos, expected ≈1000ms',
      );

      await player.pause();
      expect(player.state, PlayerState.paused);
      await player.setSpeed(1.0);
      await player.play();
      await player.seek(Duration(milliseconds: duration.inMilliseconds - 200));
      var reachedEnd = player.state == PlayerState.completed;
      for (var i = 0; i < 40 && !reachedEnd; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        reachedEnd = player.state == PlayerState.completed;
        if (!reachedEnd) {
          final p = await player.getPosition();
          if (p.inMilliseconds >= duration.inMilliseconds - 400) {
            reachedEnd = true;
          }
        }
      }
      final endPos = await player.getPosition();
      expect(
        reachedEnd,
        isTrue,
        reason:
            'did not approach end after seek-near-end (state=${player.state}, pos=$endPos)',
      );
      await player.stop();

      // Output device routing: macOS supports it; iOS throws unsupported.
      // 输出设备路由：macOS 支持；iOS 抛 unsupported。
      if (Platform.isMacOS) {
        await player.setOutputDevice(outputs.first.id);
        final current = await player.getOutputDevice();
        expect(current?.id, outputs.first.id);
        await player.setOutputDevice(null);
      } else if (Platform.isIOS) {
        await expectLater(
          player.setOutputDevice(outputs.first.id),
          throwsA(
            isA<AudioError>().having(
              (e) => e.code,
              'code',
              AudioError.codeUnsupported,
            ),
          ),
        );
      }

      final recorder = AudioRecorder();
      try {
        expect(
          await recorder.hasPermission(),
          isTrue,
          reason: 'microphone permission required for device listing tests',
        );
        final inputs = await recorder.listInputDevices();
        expect(inputs, isNotEmpty, reason: 'no input devices');
      } finally {
        await recorder.dispose();
      }
    } finally {
      await sub.cancel();
      await player.dispose();
    }
    expect(errors, isEmpty, reason: '$errors');
  });

  // API-level recorder pause / resume / cancel and input device routing.
  // 录音机 pause/resume/cancel 与输入设备路由的 API 级覆盖。
  testWidgets('recorder pause resume cancel and input devices', (_) async {
    final recorder = AudioRecorder();
    final errors = <AudioError>[];
    final states = <RecorderState>[];
    final subs = [
      recorder.onError.listen(errors.add),
      recorder.onStateChanged.listen(states.add),
    ];
    final path = '${dir.path}/rec_pause_resume.wav';
    try {
      expect(
        await recorder.hasPermission(),
        isTrue,
        reason: 'microphone permission required',
      );

      final inputs = await recorder.listInputDevices();
      expect(inputs, isNotEmpty, reason: 'no input devices');

      // Input routing works on both iOS (AVAudioSession) and macOS (CoreAudio).
      // 输入路由在 iOS（AVAudioSession）与 macOS（CoreAudio）均可。
      if (Platform.isMacOS || Platform.isIOS) {
        await recorder.setInputDevice(inputs.first.id);
        final current = await recorder.getInputDevice();
        expect(current?.id, inputs.first.id);
        await recorder.setInputDevice(null);
      }

      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      expect(recorder.state, RecorderState.recording);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      await recorder.pause();
      expect(recorder.state, RecorderState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      await recorder.resume();
      expect(recorder.state, RecorderState.recording);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(await recorder.stop(), path);
      expect(File(path).lengthSync(), greaterThan(100));

      // Cancel must leave no usable file and allow a fresh start.
      // cancel 不应留下可用文件，且允许再次 start。
      final cancelPath = '${dir.path}/rec_cancel.wav';
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: cancelPath,
      );
      expect(recorder.state, RecorderState.recording);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await recorder.cancel();
      expect(
        recorder.state,
        RecorderState.stopped,
        reason: 'after cancel state=${recorder.state}',
      );
      expect(
        !File(cancelPath).existsSync() || File(cancelPath).lengthSync() == 0,
        isTrue,
        reason: 'cancel left a non-empty file at $cancelPath',
      );

      final again = '${dir.path}/rec_after_cancel.wav';
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: again,
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(await recorder.stop(), again);
      expect(File(again).lengthSync(), greaterThan(100));
    } finally {
      for (final s in subs) {
        await s.cancel();
      }
      await recorder.dispose();
    }
    expect(errors, isEmpty, reason: 'states=$states errors=$errors');
  });
}
