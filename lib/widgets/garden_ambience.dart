import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A live atmosphere layer for the crystal terrarium.
/// Weather, crystal energy and tiny creatures react to attendance data.
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
    if (healthy) _paintCrystalEnergy(canvas, size);
    if (streak >= 3) _paintCreatures(canvas, size);
    if (streak >= 4 || level >= 4) _paintSpores(canvas, size);
  }

  void _paintRain(Canvas canvas, Size size) {
    final rain = Paint()
      ..color = const Color(0x88B9E7F5)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 46; i++) {
      final x = ((i * 67.0) + phase * 190) % size.width;
      final y = ((i * 41.0) + phase * size.height * 1.8) % size.height;
      canvas.drawLine(Offset(x, y), Offset(x - 5, y + 12), rain);
    }
  }

  void _paintCrystalEnergy(Canvas canvas, Size size) {
    final pulse = .55 + math.sin(phase * math.pi * 2) * .22;
    final points = <Offset>[
      Offset(size.width * .24, size.height * .56),
      Offset(size.width * .52, size.height * .42),
      Offset(size.width * .71, size.height * .52),
      Offset(size.width * .86, size.height * .60),
    ];
    for (var i = 0; i < math.min(points.length, level); i++) {
      final color =
          i.isEven ? const Color(0xFF54F4EE) : const Color(0xFFB78AFF);
      canvas.drawCircle(
        points[i],
        25 + pulse * 12,
        Paint()
          ..color = color.withValues(alpha: pulse * .13)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawCircle(points[i], 2.4, Paint()..color = color);
    }
  }

  void _paintCreatures(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xE5C9FFFF)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final travel = (phase * (size.width + 120)) - 60;
    for (var i = 0; i < math.min(3, streak ~/ 2); i++) {
      final x = (travel + i * 190) % (size.width + 80) - 30;
      final y =
          size.height * (.43 + i * .08) + math.sin(phase * math.pi * 2 + i) * 5;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 13, height: 8), ink);
      canvas.drawLine(Offset(x - 3, y - 4), Offset(x - 7, y - 11), ink);
      canvas.drawLine(Offset(x + 2, y - 4), Offset(x + 5, y - 12), ink);
      canvas.drawCircle(
          Offset(x + 4, y - 1), 1.2, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  void _paintSpores(Canvas canvas, Size size) {
    final glow = .45 + math.sin(phase * math.pi * 2) * .18;
    for (var i = 0; i < 22; i++) {
      final point = Offset(
        ((i * 83.0) + phase * 45) % size.width,
        ((i * 37.0) - phase * 55) % (size.height * .72) + 55,
      );
      canvas.drawCircle(
        point,
        10,
        Paint()
          ..color = const Color(0xFF7DF9F1).withValues(alpha: glow * .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(point, 1.5,
          Paint()..color = const Color(0xFFCCFFFF).withValues(alpha: glow));
    }
  }

  @override
  bool shouldRepaint(covariant _GardenAmbiencePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.healthy != healthy ||
      oldDelegate.level != level ||
      oldDelegate.streak != streak;
}
