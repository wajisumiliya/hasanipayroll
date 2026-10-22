import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/mystery_egg_hatch_controller.dart';
import 'employee_penguin_pet_card.dart' show PenguinIllustration;

/// A sealed golden surprise, revealed only when the shared server clock hatches it.
class MysteryEggTeaser extends StatefulWidget {
  const MysteryEggTeaser({
    super.key,
    this.size = 132,
    this.controller,
    this.action = 'idle',
  });

  final double size;
  final MysteryEggHatchController? controller;
  final String action;

  @override
  State<MysteryEggTeaser> createState() => _MysteryEggTeaserState();
}

class _MysteryEggTeaserState extends State<MysteryEggTeaser>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  late MysteryEggHatchController _hatch;

  @override
  void initState() {
    super.initState();
    _hatch = widget.controller ?? MysteryEggHatchController.shared;
    _hatch.addListener(_changed);
    _hatch.attach();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MysteryEggTeaser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _hatch.removeListener(_changed);
    _hatch.detach();
    _hatch = widget.controller ?? MysteryEggHatchController.shared;
    _hatch.addListener(_changed);
    _hatch.attach();
  }

  @override
  void dispose() {
    _hatch.removeListener(_changed);
    _hatch.detach();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animateEgg = !reduceMotion && _hatch.stage == 'egg';
    if (!animateEgg && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = .5;
    } else if (animateEgg && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }

    return Semantics(
      value: _hatch.stage == 'egg' ? _hatch.countdownLabel : null,
      label: _hatch.stage != 'egg'
          ? 'Surprise! Your penguin has hatched'
          : _hatch.hatching
              ? 'Something is stirring inside the golden egg'
              : 'A little surprise is waiting',
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final pulse = reduceMotion ? .5 : _pulse.value;
                    return AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 800),
                      child: _hatch.stage != 'egg'
                          ? SizedBox(
                              key: ValueKey(_hatch.stage),
                              width: widget.size,
                              height: widget.size,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: PenguinIllustration(
                                    stage: _hatch.stage, action: widget.action),
                              ),
                            )
                          : Stack(
                              key: const ValueKey('golden-egg'),
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
                                    offset:
                                        Offset(0, -pulse * widget.size * .02),
                                    child: Transform.rotate(
                                      angle: math.sin(pulse * math.pi * 2) *
                                          (_hatch.hatching ? .07 : .025),
                                      child: CustomPaint(
                                        foregroundPainter: _hatch.hatching
                                            ? const _EggCracksPainter()
                                            : null,
                                        child: Image.asset(
                                          'assets/mystery_golden_egg.png',
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
              if (_hatch.stage == 'egg')
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xEB172D4F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x99FFD76A)),
                        ),
                        child: Text(
                          _hatch.countdownLabel,
                          style: TextStyle(
                            color: const Color(0xFFFFE7A4),
                            fontSize: widget.size >= 180 ? 12 : 10,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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

/// Cracks stay opaque until the server confirms that the hatch time has passed.
class _EggCracksPainter extends CustomPainter {
  const _EggCracksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final crack = Path()
      ..moveTo(.5, .035)
      ..lineTo(.46, .12)
      ..lineTo(.53, .18)
      ..lineTo(.45, .24)
      ..lineTo(.52, .31)
      ..moveTo(.45, .24)
      ..lineTo(.35, .27)
      ..lineTo(.31, .34);
    canvas.drawPath(
        crack,
        Paint()
          ..color = const Color(0xFF78500C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .018
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EggCracksPainter oldDelegate) => false;
}
