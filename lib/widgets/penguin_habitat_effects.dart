import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';

/// Water-only mask follows the existing photograph; glints never spill on ice.
Path penguinWaterMask(Size size) => Path()
  ..moveTo(size.width * .62, size.height * .49)
  ..lineTo(size.width * .99, size.height * .49)
  ..lineTo(size.width * .99, size.height * .80)
  ..lineTo(size.width * .84, size.height * .77)
  ..lineTo(size.width * .72, size.height * .69)
  ..lineTo(size.width * .64, size.height * .60)
  ..close();

/// Quiet photographic cloud drift and low-contrast surface reflections.
/// The caller's stopped scene clock freezes both under reduced motion.
void paintPenguinHabitat(
    Canvas canvas, Size size, double seconds, ui.Image coast) {
  final sky = Rect.fromLTWH(0, 0, size.width, size.height * .115);
  canvas.save();
  canvas.clipRect(sky);
  canvas.saveLayer(sky, Paint());
  final drift = math.sin(seconds / 70) * size.width * .012;
  canvas.drawImageRect(
      coast,
      Rect.fromLTWH(0, 0, coast.width.toDouble(), coast.height.toDouble()),
      Rect.fromLTWH(
          -size.width * .02 + drift, 0, size.width * 1.04, size.height),
      Paint()
        ..color = const Color(0x28FFFFFF)
        ..filterQuality = FilterQuality.low);
  canvas.drawRect(
      sky,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(sky.topCenter, sky.bottomCenter,
            [const Color(0xFFFFFFFF), const Color(0x00FFFFFF)], [.3, 1]));
  canvas.restore();
  canvas.restore();
  canvas.save();
  canvas.clipPath(penguinWaterMask(size));
  for (var index = 0; index < 30; index++) {
    final lane = index % 10;
    final depth = (index ~/ 10) / 3;
    final x = size.width * (.62 + ((lane / 10 + seconds * .0025) % 1) * .40);
    final y = size.height * (.51 + depth * .24) +
        math.sin(seconds * .6 + index * 2.3) * .8;
    final width = size.width * (.006 + .012 * depth);
    final opacity = .035 + .035 * (.5 + .5 * math.sin(seconds * .4 + index));
    canvas.drawLine(
        Offset(x, y),
        Offset(x + width, y),
        Paint()
          ..color = const Color(0xFFD1E5ED).withValues(alpha: opacity)
          ..strokeWidth = .6 + depth * .5
          ..strokeCap = StrokeCap.round);
  }
  canvas.restore();
}
