import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Creates an anti-aliased [Paint] filled with [gradient] when provided, or
/// solid [color] otherwise.
///
/// 创建抗锯齿画笔；若传入 [gradient] 则使用着色器，否则使用纯色 [color]。
Paint createActivePaint(Color color, Gradient? gradient, Rect rect) {
  final paint = Paint()..isAntiAlias = true;
  if (gradient != null) {
    paint.shader = gradient.createShader(rect);
  } else {
    paint.color = color;
  }
  return paint;
}

/// Applies horizontal edge alpha-fade masking around [draw] when [fade] is
/// enabled and [size.width] is wide enough.
///
/// 当启用 [fade] 且宽度足够时，在 [draw] 的左右边缘施加透明度渐隐遮罩。
void withHorizontalEdgeFade(
  Canvas canvas,
  Size size,
  bool fade,
  void Function() draw,
) {
  if (!fade || size.width < 40) {
    draw();
    return;
  }
  final rect = Offset.zero & size;
  canvas.saveLayer(rect, Paint());
  draw();
  final edge = math.min(0.18, 24 / size.width);
  final mask = Paint()
    ..blendMode = BlendMode.dstIn
    ..shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, 0),
      const [
        Color(0x00FFFFFF),
        Color(0xFFFFFFFF),
        Color(0xFFFFFFFF),
        Color(0x00FFFFFF),
      ],
      [0, edge, 1 - edge, 1],
    );
  canvas.drawRect(rect, mask);
  canvas.restore();
}
