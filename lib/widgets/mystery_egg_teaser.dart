import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A wordless, animated teaser for the surprise being raised in the employee
/// dashboard. The visual intentionally does not identify what is inside.
class MysteryEggTeaser extends StatefulWidget {
  const MysteryEggTeaser({
    super.key,
    this.size = 132,
  });

  final double size;

  @override
  State<MysteryEggTeaser> createState() => _MysteryEggTeaserState();
}

class _MysteryEggTeaserState extends State<MysteryEggTeaser>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = .5;
    } else if (!reduceMotion && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }

    return Semantics(
      label: 'A little surprise is waiting',
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final pulse = reduceMotion ? .5 : _pulse.value;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EnchantedEggPainter(pulse),
                    ),
                  ),
                  Positioned(
                    left: widget.size * .28,
                    top: widget.size * .17,
                    width: widget.size * .44,
                    height: widget.size * .66,
                    child: Transform.translate(
                      offset: Offset(0, -pulse * widget.size * .02),
                      child: Transform.rotate(
                        angle: math.sin(pulse * math.pi * 2) * .025,
                        child: Image.asset(
                          'assets/mystery_golden_egg.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Warm magical light and floating sparks around the opaque golden shell.
class _EnchantedEggPainter extends CustomPainter {
  const _EnchantedEggPainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 300);
    const center = Offset(150, 148);
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD05A).withValues(alpha: .28 + phase * .12),
          const Color(0xFFFFC342).withValues(alpha: .12),
          const Color(0x00FFC342),
        ],
      ).createShader(const Rect.fromLTWH(15, 13, 270, 270));
    canvas.drawCircle(center, 135, halo);

    // A fine luminous orbit replaces the solid white platform.
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFDE7A).withValues(alpha: .5 + phase * .3);
    canvas.drawOval(const Rect.fromLTWH(58, 245, 184, 17), orbit);
    canvas.drawOval(
      const Rect.fromLTWH(79, 249, 142, 9),
      Paint()
        ..color = const Color(0xFFFFBC31).withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final radius = 86 + (i % 3) * 12.0;
      final sparkle = Offset(
        150 + math.cos(angle) * radius,
        144 + math.sin(angle) * radius * .91 - phase * (i.isEven ? 7 : -5),
      );
      final length = i % 3 == 0 ? 5.0 : 2.5;
      final paint = Paint()
        ..color = (i.isEven ? const Color(0xFFFFE6A6) : const Color(0xFFFFF4C4))
            .withValues(alpha: .4 + phase * .5)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          sparkle - Offset(length, 0), sparkle + Offset(length, 0), paint);
      canvas.drawLine(
          sparkle - Offset(0, length), sparkle + Offset(0, length), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EnchantedEggPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
