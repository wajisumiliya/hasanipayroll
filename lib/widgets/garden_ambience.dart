import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A live foreground layer for the photographic garden scenes.
/// Weather, fountain spray, birds and evening lights all react to real data.
class GardenAmbience extends StatelessWidget {
  const GardenAmbience({
    super.key,
    required this.animation,
    required this.healthy,
    required this.level,
    required this.streak,
  });

  final Animation<double> animation;
  final bool healthy;
  final int level;
  final int streak;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, __) => CustomPaint(
            painter: _GardenAmbiencePainter(
              phase: animation.value,
              healthy: healthy,
              level: level,
              streak: streak,
            ),
            size: Size.infinite,
          ),
        ),
      );
}

class _GardenAmbiencePainter extends CustomPainter {
  const _GardenAmbiencePainter({
    required this.phase,
    required this.healthy,
    required this.level,
    required this.streak,
  });

  final double phase;
  final bool healthy;
  final int level;
  final int streak;

  @override
  void paint(Canvas canvas, Size size) {
    if (!healthy) _paintRain(canvas, size);
    if (healthy) _paintFountain(canvas, size);
    if (streak >= 3) _paintBirds(canvas, size);
    if (streak >= 4 || level >= 4) _paintLights(canvas, size);
  }

  void _paintRain(Canvas canvas, Size size) {
    final rain = Paint()
      ..color = const Color(0x99D8ECF6)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 46; i++) {
      final x = ((i * 67.0) + phase * 190) % size.width;
      final y = ((i * 41.0) + phase * size.height * 1.8) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 12), rain);
    }
  }

  void _paintFountain(Canvas canvas, Size size) {
    final fountainX = size.width * .52;
    final fountainY = size.height * .48;
    final shimmer = .55 + math.sin(phase * math.pi * 2) * .2;
    final spray = Paint()
      ..color = const Color(0xFFDCF7FF).withValues(alpha: shimmer)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      final spread = 11.0 + i * 6;
      final path = Path()
        ..moveTo(fountainX, fountainY + 8)
        ..quadraticBezierTo(
            fountainX + spread, fountainY - 34 - i * 2, fountainX + spread * 1.5, fountainY + 8);
      canvas.drawPath(path, spray);
      final mirror = Path()
        ..moveTo(fountainX, fountainY + 8)
        ..quadraticBezierTo(
            fountainX - spread, fountainY - 34 - i * 2, fountainX - spread * 1.5, fountainY + 8);
      canvas.drawPath(mirror, spray);
    }
  }

  void _paintBirds(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xD91A2420)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final travel = (phase * (size.width + 150)) - 80;
    for (var i = 0; i < math.min(5, streak); i++) {
      final x = (travel + i * 73) % (size.width + 80) - 30;
      final y = 82.0 + i * 11 + math.sin(phase * math.pi * 2 + i) * 8;
      final bird = Path()
        ..moveTo(x - 8, y)
        ..quadraticBezierTo(x - 3, y - 7, x, y)
        ..quadraticBezierTo(x + 4, y - 7, x + 9, y);
      canvas.drawPath(bird, ink);
    }
  }

  void _paintLights(Canvas canvas, Size size) {
    final glow = .45 + math.sin(phase * math.pi * 2) * .18;
    final points = <Offset>[
      Offset(size.width * .12, size.height * .58),
      Offset(size.width * .29, size.height * .52),
      Offset(size.width * .73, size.height * .55),
      Offset(size.width * .88, size.height * .48),
    ];
    for (final point in points) {
      canvas.drawCircle(
        point,
        18,
        Paint()
          ..color = const Color(0xFFFFD875).withValues(alpha: glow * .20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(point, 2.5,
          Paint()..color = const Color(0xFFFFE39A).withValues(alpha: glow));
    }
  }

  @override
  bool shouldRepaint(covariant _GardenAmbiencePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.healthy != healthy ||
      oldDelegate.level != level ||
      oldDelegate.streak != streak;
}
