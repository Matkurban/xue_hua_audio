part of 'waveform_parser.dart';

List<CubicSegment> _computeClosedSplineSegments(
  List<double> radii,
  Offset center, {
  required double rotation,
  required double tension,
}) {
  final n = radii.length;
  if (n < 3) return const <CubicSegment>[];
  final pts = List<Offset>.generate(n, (i) {
    final angle = rotation + (i * 2 * math.pi / n);
    final r = radii[i].isNaN ? 0.0 : math.max(0.0, radii[i]);
    return Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
  });
  final factor = tension / 6.0;
  return List<CubicSegment>.generate(n, (i) {
    final pPrev = pts[(i - 1 + n) % n];
    final pCurr = pts[i];
    final pNext = pts[(i + 1) % n];
    final pNext2 = pts[(i + 2) % n];
    final c1 = Offset(
      pCurr.dx + (pNext.dx - pPrev.dx) * factor,
      pCurr.dy + (pNext.dy - pPrev.dy) * factor,
    );
    final c2 = Offset(
      pNext.dx - (pNext2.dx - pCurr.dx) * factor,
      pNext.dy - (pNext2.dy - pCurr.dy) * factor,
    );
    return CubicSegment(p0: pCurr, c1: c1, c2: c2, p1: pNext);
  });
}

List<List<double>> _computeSpectrogramGrid(
  WaveformController controller, {
  required int columns,
  required int bands,
}) {
  if (columns <= 0 || bands <= 0) return const <List<double>>[];
  if (controller.length == 0) {
    return List<List<double>>.generate(
      columns,
      (_) => List<double>.filled(bands, 0.0),
    );
  }
  return List<List<double>>.generate(columns, (col) {
    final vCurr = controller.sampleInterpolated(col.toDouble());
    final vPrev = controller.sampleInterpolated((col + 1).toDouble());
    final vNext = controller.sampleInterpolated(
      math.max(0.0, (col - 1).toDouble()),
    );
    final localMean = (vCurr + vPrev + vNext) / 3.0;
    final localFlux = ((vCurr - vPrev).abs() + (vNext - vCurr).abs()) * 0.5;
    if (vCurr < 0.004 && localMean < 0.004) {
      return List<double>.filled(bands, 0.0);
    }
    return List<double>.generate(bands, (b) {
      final normBand = bands == 1 ? 0.5 : b / (bands - 1);
      final formant = math.sin(normBand * math.pi);
      final lowComponent = localMean * (1.0 - normBand * 0.65);
      final midComponent = vCurr * formant;
      final highComponent = localFlux * (0.4 + 0.8 * normBand);
      final combined =
          lowComponent * 0.42 + midComponent * 0.48 + highComponent * 0.45;
      return combined.clamp(0.0, 1.0).toDouble();
    });
  });
}

List<HelixNode> _computeHelixNodes(
  WaveformController controller, {
  required int nodeCount,
  required double turns,
}) {
  if (nodeCount <= 0) return const <HelixNode>[];
  final metrics = _computeMetrics(controller, window: 20);
  final phaseTime = controller.active ? controller.elapsedSeconds * 3.0 : 0.0;
  final shift = controller.active ? controller.phase : 0.0;
  return List<HelixNode>.generate(nodeCount, (i) {
    final progress = nodeCount == 1 ? 0.5 : i / (nodeCount - 1);
    final bell = math.sin(progress * math.pi);
    final sample = controller.sampleInterpolated(i * 0.8 + shift);
    final amp = ((sample * 0.75 + metrics.rms * 0.25) * (0.25 + 0.75 * bell))
        .clamp(0.0, 1.0)
        .toDouble();
    final theta = progress * math.pi * 2 * turns - phaseTime;
    final sinT = math.sin(theta);
    final cosT = math.cos(theta);
    final envelope = controller.active || !metrics.isSilent
        ? math.max(0.12, amp)
        : 0.10 * bell;
    return HelixNode(
      progress: progress,
      yOffsetA: (sinT * envelope).clamp(-1.0, 1.0),
      yOffsetB: (-sinT * envelope).clamp(-1.0, 1.0),
      depthA: cosT,
      depthB: -cosT,
      amplitude: amp,
    );
  });
}

List<double> _computePetalRadii(
  WaveformController controller, {
  required int petalCount,
}) {
  if (petalCount <= 0) return const <double>[];
  final bands = _extractFrequencyBands(controller, petalCount);
  final metrics = _computeMetrics(controller, window: 16);
  if (metrics.isSilent) {
    return List<double>.filled(petalCount, 0.0);
  }
  return List<double>.generate(petalCount, (i) {
    final mirrorIdx = petalCount - 1 - i;
    final symVal = (bands[i] + bands[mirrorIdx]) * 0.5;
    return (symVal * 0.75 + metrics.rms * 0.25).clamp(0.0, 1.0).toDouble();
  });
}

List<double> _computePendulumAngles(
  WaveformController controller, {
  required int count,
  required double maxAngleRadians,
}) {
  if (count <= 0) return const <double>[];
  final m = _computeMetrics(controller, window: 20);
  if (m.isSilent && !controller.active) {
    return List<double>.filled(count, 0.0);
  }
  final t = controller.elapsedSeconds;
  return List<double>.generate(count, (i) {
    final hist = controller.sampleInterpolated(i * 0.7);
    final energy = (hist * 0.65 + m.rms * 0.35).clamp(0.0, 1.0);
    // Graduated frequencies create a travelling pendulum wave pattern.
    // 递增谐振频率形成行波钟摆视觉效果。
    final freq = 2.2 + i * 0.24;
    final swing = controller.active
        ? math.sin(t * freq + i * 0.38)
        : math.sin(i * 0.55);
    return (swing * energy * maxAngleRadians).clamp(
      -maxAngleRadians,
      maxAngleRadians,
    );
  });
}

List<Offset> _computePolygonVertices(
  Offset center,
  double radius,
  int sides, {
  required double rotation,
  List<double>? vertexScales,
}) {
  if (sides < 3 || radius <= 0) return const <Offset>[];
  return List<Offset>.generate(sides, (i) {
    final scale = (vertexScales != null && vertexScales.isNotEmpty)
        ? vertexScales[i % vertexScales.length].clamp(0.1, 3.0)
        : 1.0;
    final r = radius * scale;
    final angle = rotation - math.pi / 2 + (i * 2 * math.pi / sides);
    return Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
  });
}

List<LouverSlat> _computeKineticLouvers(
  WaveformController controller, {
  required int slatCount,
  required double maxTiltRadians,
}) {
  if (slatCount <= 0) return const <LouverSlat>[];
  final shift = controller.active ? controller.phase : 0.0;
  final t = controller.elapsedSeconds;
  return List<LouverSlat>.generate(slatCount, (i) {
    final v = controller.sampleInterpolated(i + shift).clamp(0.0, 1.0);
    final vNext = controller.sampleInterpolated(i + 1 + shift).clamp(0.0, 1.0);
    final gradient = v - vNext;
    final wavePhase = controller.active ? math.sin(t * 4.0 - i * 0.35) : 0.0;
    final tilt = ((gradient * 1.4 + wavePhase * 0.45 * v) * maxTiltRadians)
        .clamp(-maxTiltRadians, maxTiltRadians);
    final heightFactor = (0.18 + 0.82 * v).clamp(0.18, 1.0);
    final thicknessFactor = (0.65 + 0.70 * v).clamp(0.65, 1.35);
    return LouverSlat(
      amplitude: v,
      tiltRadians: tilt,
      heightFactor: heightFactor,
      thicknessFactor: thicknessFactor,
    );
  });
}

List<OrbitalNode> _computeOrbitalNodes(
  WaveformController controller, {
  required int nodeCount,
  required int orbitCount,
}) {
  if (nodeCount <= 0 || orbitCount <= 0) return const <OrbitalNode>[];
  final bands = _extractFrequencyBands(controller, nodeCount);
  final m = _computeMetrics(controller, window: 20);
  final t = controller.elapsedSeconds;
  return List<OrbitalNode>.generate(nodeCount, (i) {
    final orbitIdx = i % orbitCount;
    final baseOrbitR = 0.28 + (orbitIdx / math.max(1, orbitCount)) * 0.52;
    final energy = bands[i];
    final r = (baseOrbitR + energy * 0.16).clamp(0.15, 0.96);
    final speed = (orbitIdx.isEven ? 1.0 : -1.0) * (0.55 + orbitIdx * 0.28);
    final boost = controller.active ? t * speed * (1.0 + m.rms * 0.8) : 0.0;
    final baseAngle = (i * 2 * math.pi / nodeCount) + boost;
    final aspect = 0.78 + 0.08 * orbitIdx;
    final nx = (r * math.cos(baseAngle)).clamp(-1.0, 1.0);
    final ny = (r * math.sin(baseAngle) * aspect).clamp(-1.0, 1.0);
    return OrbitalNode(
      position: Offset(nx, ny),
      radiusFactor: (0.75 + 1.15 * energy).clamp(0.75, 1.90),
      energy: energy,
      orbitIndex: orbitIdx,
    );
  });
}

List<double> _computeOscilloscopeTrace(
  WaveformController controller, {
  required int pointCount,
}) {
  if (pointCount <= 0) return const <double>[];
  final m = _computeMetrics(controller, window: 24);
  if (m.isSilent && !controller.active) {
    return List<double>.filled(pointCount, 0.0);
  }
  final t = controller.elapsedSeconds;
  return List<double>.generate(pointCount, (i) {
    final normX = pointCount == 1 ? 0.5 : i / (pointCount - 1);
    final bell = math.sin(normX * math.pi);
    final histPos =
        (1.0 - normX) * math.min(24, math.max(1, controller.length));
    final env = controller.sampleInterpolated(histPos);
    final energy = (env * 0.70 + m.current * 0.30).clamp(0.0, 1.0);
    final carrier =
        math.sin(normX * math.pi * 10.0 - t * 14.0) * 0.65 +
        math.sin(normX * math.pi * 23.0 + t * 9.0) * 0.35;
    return (carrier * energy * bell).clamp(-1.0, 1.0);
  });
}
