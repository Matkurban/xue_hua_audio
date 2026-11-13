import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Cubic Bezier segment `(p0, c1, c2, p1)` used for smooth closed contours.
/// 用于平滑闭合轮廓的三次贝塞尔曲线段 `(p0, c1, c2, p1)`。
@immutable
class CubicSegment {
  /// Creates a cubic Bezier segment. / 创建三次贝塞尔曲线段。
  const CubicSegment({
    required this.p0,
    required this.c1,
    required this.c2,
    required this.p1,
  });

  /// Start anchor point. / 起点锚点。
  final Offset p0;

  /// First control point. / 第一控制点。
  final Offset c1;

  /// Second control point. / 第二控制点。
  final Offset c2;

  /// End anchor point. / 终点锚点。
  final Offset p1;
}

/// A paired node along a 3D-projected double-helix acoustic wave.
/// 双螺旋声波链上的单组配对节点数据。
@immutable
class HelixNode {
  /// Creates a helix node. / 创建双螺旋节点。
  const HelixNode({
    required this.progress,
    required this.yOffsetA,
    required this.yOffsetB,
    required this.depthA,
    required this.depthB,
    required this.amplitude,
  });

  /// Normalized horizontal position (`0.0–1.0`). / 水平归一化位置（`0.0–1.0`）。
  final double progress;

  /// Normalized vertical displacement of strand A (`-1.0..1.0`).
  /// A 链垂直归一化偏移（`-1.0..1.0`）。
  final double yOffsetA;

  /// Normalized vertical displacement of strand B (`-1.0..1.0`).
  /// B 链垂直归一化偏移（`-1.0..1.0`）。
  final double yOffsetB;

  /// Depth factor of strand A (`-1.0..1.0`, positive is front).
  /// A 链景深系数（`-1.0..1.0`，正数在前）。
  final double depthA;

  /// Depth factor of strand B (`-1.0..1.0`, positive is front).
  /// B 链景深系数（`-1.0..1.0`，正数在前）。
  final double depthB;

  /// Local normalized amplitude at this node (`0.0–1.0`).
  /// 当前节点处的局部归一化振幅（`0.0–1.0`）。
  final double amplitude;
}

/// State of a single kinetic louver slat in `KineticLouverVisualizer`.
/// 韵律百叶窗可视化组件中单个叶片的几何状态。
@immutable
class LouverSlat {
  /// Creates a louver slat state. / 创建百叶窗叶片状态。
  const LouverSlat({
    required this.amplitude,
    required this.tiltRadians,
    required this.heightFactor,
    required this.thicknessFactor,
  });

  /// Local normalized amplitude (`0.0–1.0`). / 局部归一化振幅（`0.0–1.0`）。
  final double amplitude;

  /// Tilt angle in radians (`-pi/4..pi/4`). / 倾斜弧度角（`-pi/4..pi/4`）。
  final double tiltRadians;

  /// Normalized height factor (`0.15..1.0`). / 高度缩放比例（`0.15..1.0`）。
  final double heightFactor;

  /// Normalized stroke thickness factor (`0.5..1.5`). / 线宽缩放比例（`0.5..1.5`）。
  final double thicknessFactor;
}

/// 2D normalized orbital particle state in `OrbitConstellationVisualizer`.
/// 星轨星座可视化组件中的单个轨道节点状态。
@immutable
class OrbitalNode {
  /// Creates an orbital node. / 创建星轨节点。
  const OrbitalNode({
    required this.position,
    required this.radiusFactor,
    required this.energy,
    required this.orbitIndex,
  });

  /// Normalized offset relative to center (`-1.0..1.0` on each axis).
  /// 相对于中心的归一化坐标（各轴 `-1.0..1.0`）。
  final Offset position;

  /// Radius multiplier (`0.5..2.0`). / 节点半径倍率（`0.5..2.0`）。
  final double radiusFactor;

  /// Local energy (`0.0–1.0`). / 节点局部能量（`0.0–1.0`）。
  final double energy;

  /// Zero-based orbit ring index. / 所属轨道环索引（从 0 开始）。
  final int orbitIndex;
}
