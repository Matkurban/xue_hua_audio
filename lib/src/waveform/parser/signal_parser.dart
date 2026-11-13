part of 'waveform_parser.dart';

double _parseDb(
  double db, {
  required double minDb,
  required double maxDb,
  required double curve,
}) {
  assert(maxDb > minDb);
  assert(curve > 0);
  if (db.isNaN || db <= minDb) return 0.0;
  if (db >= maxDb) return 1.0;
  final x = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0).toDouble();
  return curve == 1.0 ? x : math.pow(x, curve).toDouble();
}

WaveformMetrics _computeMetrics(
  WaveformController controller, {
  required int window,
}) {
  final total = controller.length;
  if (total == 0 || window <= 0) {
    return WaveformMetrics.zero;
  }
  final count = math.min(total, window);
  var sum = 0.0;
  var sumSq = 0.0;
  var peak = 0.0;
  var fluxSum = 0.0;
  var prev = controller.recentAt(0);
  for (var i = 0; i < count; i++) {
    final v = controller.recentAt(i).clamp(0.0, 1.0).toDouble();
    sum += v;
    sumSq += v * v;
    if (v > peak) peak = v;
    if (i > 0) {
      fluxSum += (v - prev).abs();
    }
    prev = v;
  }
  final avg = sum / count;
  final rms = math.sqrt(sumSq / count);
  final flux = count > 1 ? (fluxSum / (count - 1)).clamp(0.0, 1.0) : 0.0;
  final current = controller.recentAt(0).clamp(0.0, 1.0).toDouble();
  final peakHold = math.max(peak, controller.peakHold).clamp(0.0, 1.0);
  return WaveformMetrics(
    current: current,
    average: avg,
    rms: rms,
    peak: peak,
    peakHold: peakHold,
    flux: flux,
    sampleCount: count,
  );
}

List<double> _resamplePeak(List<double> levels, int targetCount) {
  if (targetCount <= 0) return const <double>[];
  if (levels.isEmpty) return List<double>.filled(targetCount, 0.0);

  double clean(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0).toDouble();

  if (levels.length == 1) {
    return List<double>.filled(targetCount, clean(levels.first));
  }
  if (targetCount == 1) {
    var maxV = 0.0;
    for (final raw in levels) {
      final v = clean(raw);
      if (v > maxV) maxV = v;
    }
    return <double>[maxV];
  }
  if (levels.length < targetCount) {
    return List<double>.generate(targetCount, (i) {
      final pos = i * (levels.length - 1) / (targetCount - 1);
      final i0 = pos.floor();
      final i1 = math.min(levels.length - 1, i0 + 1);
      final t = pos - i0;
      final v0 = clean(levels[i0]);
      final v1 = clean(levels[i1]);
      return v0 + (v1 - v0) * t;
    });
  }
  return List<double>.generate(targetCount, (i) {
    final a = (i * levels.length / targetCount).floor();
    final b = math.max(a + 1, ((i + 1) * levels.length / targetCount).ceil());
    var peak = 0.0;
    for (var j = a; j < math.min(b, levels.length); j++) {
      final v = clean(levels[j]);
      if (v > peak) peak = v;
    }
    return peak;
  });
}

List<double> _extractMirroredRadial(
  WaveformController controller,
  int spokeCount, {
  required bool mirror,
}) {
  if (spokeCount <= 0) return const <double>[];
  if (controller.length == 0) {
    return List<double>.filled(spokeCount, 0.0);
  }
  if (!mirror || spokeCount < 4) {
    return List<double>.generate(
      spokeCount,
      (i) => controller.recentAt(i).clamp(0.0, 1.0).toDouble(),
    );
  }
  final half = (spokeCount / 2).ceil();
  final halfValues = List<double>.generate(
    half,
    (i) => controller.sampleInterpolated(i.toDouble()).clamp(0.0, 1.0),
  );
  return List<double>.generate(spokeCount, (i) {
    if (i < half) return halfValues[i];
    final mirroredIndex = spokeCount - 1 - i;
    return halfValues[mirroredIndex.clamp(0, half - 1)];
  });
}

List<double> _extractFrequencyBands(
  WaveformController controller,
  int bandCount,
) {
  if (bandCount <= 0) return const <double>[];
  final metrics = _computeMetrics(controller, window: 24);
  if (metrics.isSilent) {
    return List<double>.filled(bandCount, 0.0);
  }
  final t = controller.elapsedSeconds;
  return List<double>.generate(bandCount, (i) {
    final normPos = bandCount == 1 ? 0.5 : i / (bandCount - 1);
    final histIdx =
        (i * math.max(1, controller.length - 1)) / math.max(1, bandCount);
    final histVal = controller.sampleInterpolated(histIdx * 0.65);
    final centerWeight = math.sin(normPos * math.pi);
    final lowWeight = 1.0 - normPos;
    final highWeight = normPos;
    final harmonicMod = controller.active
        ? 0.08 * metrics.rms * math.sin(t * (4.0 + i * 0.7) + i * 0.9)
        : 0.0;
    final raw =
        histVal * (0.45 + 0.35 * centerWeight) +
        metrics.rms * (0.30 * lowWeight + 0.15 * centerWeight) +
        metrics.flux * (0.55 * highWeight) +
        harmonicMod;
    return raw.clamp(0.0, 1.0).toDouble();
  });
}

VuMeterState _parseVuSegments({
  required double level,
  required double peakHold,
  required int segments,
  required double warningRatio,
  required double dangerRatio,
}) {
  assert(segments > 0);
  final cleanLevel = level.isNaN ? 0.0 : level.clamp(0.0, 1.0);
  final cleanPeak = peakHold.isNaN ? 0.0 : peakHold.clamp(0.0, 1.0);
  final active = cleanLevel <= 0.004
      ? 0
      : math.max(1, (cleanLevel * segments).ceil()).clamp(0, segments);
  int? peakSeg;
  if (cleanPeak > 0.004) {
    final rawPeak = ((cleanPeak * segments).ceil() - 1).clamp(0, segments - 1);
    peakSeg = math.max(rawPeak, active > 0 ? active - 1 : 0);
  }
  final warnStart = (segments * warningRatio.clamp(0.0, 1.0)).floor().clamp(
    0,
    segments,
  );
  final dangerStart = (segments * dangerRatio.clamp(0.0, 1.0)).floor().clamp(
    warnStart,
    segments,
  );
  return VuMeterState(
    totalSegments: segments,
    activeSegments: active,
    peakSegment: peakSeg,
    warningStartSegment: warnStart,
    dangerStartSegment: dangerStart,
  );
}

PrecisionMeterReading _parsePrecisionMeter(WaveformController controller) {
  final m = _computeMetrics(controller, window: 24);
  final inst = m.current.clamp(0.0, 1.0);
  final rms = m.rms.clamp(0.0, 1.0);
  final peak = m.peakHold.clamp(0.0, 1.0);
  final span = controller.maxDb - controller.minDb;
  final linear = controller.curve == 1.0
      ? inst
      : math.pow(inst, 1.0 / controller.curve).toDouble();
  final db = (controller.minDb + linear * span).clamp(
    controller.minDb,
    controller.maxDb,
  );
  return PrecisionMeterReading(
    instantaneous: inst,
    ballisticRms: rms,
    peakHold: peak,
    estimatedDb: db,
    isClipping: peak >= 0.90 || inst >= 0.92,
  );
}
