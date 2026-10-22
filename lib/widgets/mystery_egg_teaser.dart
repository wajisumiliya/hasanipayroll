import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'employee_penguin_pet_card.dart' show PenguinIllustration;

/// A wordless, animated teaser for the surprise being raised in the employee
/// dashboard. The visual intentionally does not identify what is inside.
class MysteryEggTeaser extends StatefulWidget {
  const MysteryEggTeaser({
    super.key,
    this.size = 132,
    this.enchanted = false,
  });

  final double size;
  final bool enchanted;

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
              if (widget.enchanted) {
                return CustomPaint(
                  size: Size.square(widget.size),
                  painter: _EnchantedEggPainter(pulse),
                );
              }
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: widget.size * .08,
                    child: Container(
                      width: widget.size * .78,
                      height: widget.size * .16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.size),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE8F8FF),
                            Color(0xFFFFFFFF),
                            Color(0xFFD5F1FA),
                          ],
                        ),
                        border: Border.all(color: const Color(0xBFFFFFFF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40417791),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: widget.size * .14,
                    child: Transform.translate(
                      offset: Offset(0, -3 * pulse),
                      child: Transform.scale(
                        scale: .98 + pulse * .035,
                        child: Container(
                          width: widget.size * .68,
                          height: widget.size * .68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFBDEFFF)
                                    .withValues(alpha: .24 + pulse * .2),
                                blurRadius: 16 + pulse * 10,
                                spreadRadius: 2 + pulse * 3,
                              ),
                            ],
                          ),
                          child: const FittedBox(
                            fit: BoxFit.contain,
                            child: IgnorePointer(
                              child: PenguinIllustration(stage: 'egg'),
                            ),
                          ),
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

/// A sealed, jewel-like shell: no silhouette or character reveals the surprise.
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
          const Color(0xFFB690FF).withValues(alpha: .28 + phase * .12),
          const Color(0xFF75E7FF).withValues(alpha: .12),
          const Color(0x0075E7FF),
        ],
      ).createShader(const Rect.fromLTWH(15, 13, 270, 270));
    canvas.drawCircle(center, 135, halo);

    // A fine luminous orbit replaces the solid white platform.
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFA8EFFF).withValues(alpha: .5 + phase * .3);
    canvas.drawOval(const Rect.fromLTWH(58, 245, 184, 17), orbit);
    canvas.drawOval(
      const Rect.fromLTWH(79, 249, 142, 9),
      Paint()
        ..color = const Color(0xFFB9A0FF).withValues(alpha: .25)
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
        ..color = (i.isEven ? const Color(0xFFFFE6A6) : const Color(0xFFA4F1FF))
            .withValues(alpha: .4 + phase * .5)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          sparkle - Offset(length, 0), sparkle + Offset(length, 0), paint);
      canvas.drawLine(
          sparkle - Offset(0, length), sparkle + Offset(0, length), paint);
    }

    canvas.save();
    canvas.translate(150, 161 - phase * 6);
    canvas.rotate(math.sin(phase * math.pi * 2) * .025);
    final shell = Path()
      ..moveTo(0, -94)
      ..cubicTo(34, -94, 59, -28, 57, 13)
      ..cubicTo(55, 78, -55, 78, -57, 13)
      ..cubicTo(-59, -28, -34, -94, 0, -94)
      ..close();
    const bounds = Rect.fromLTWH(-60, -94, 120, 171);
    canvas.drawPath(
      shell,
      Paint()
        ..color = const Color(0xFFBC9BFF).withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      shell,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE7DFFF),
            Color(0xFFBBA2F4),
            Color(0xFF6455A9),
            Color(0xFF342B68)
          ],
          stops: [0, .32, .72, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFEDBE), Color(0xFFBEEFFF), Color(0xFFB098EF)],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(shell);
    final ribbon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFFFE5A8).withValues(alpha: .75);
    canvas.drawPath(
      Path()
        ..moveTo(-75, 25)
        ..cubicTo(-26, -21, 24, 40, 77, -15),
      ribbon,
    );
    canvas.drawOval(
      const Rect.fromLTWH(-39, -72, 22, 64),
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.restore();
    final mysteryMark = Paint()
      ..color = const Color(0xFFFFEDC3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final question = Path()
      ..moveTo(-11, -35)
      ..cubicTo(-11, -53, 15, -53, 13, -36)
      ..cubicTo(12, -26, 0, -28, 0, -16);
    canvas.drawPath(
      question,
      Paint()
        ..color = const Color(0xFFFFCE74)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(question, mysteryMark);
    canvas.drawCircle(
        const Offset(0, -5), 2.2, Paint()..color = const Color(0xFFFFEDC3));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EnchantedEggPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
