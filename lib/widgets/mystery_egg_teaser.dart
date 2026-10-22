import 'package:flutter/material.dart';

import 'employee_penguin_pet_card.dart' show PenguinIllustration;

/// A wordless, animated teaser for the surprise being raised in the employee
/// dashboard. The visual intentionally does not identify what is inside.
class MysteryEggTeaser extends StatefulWidget {
  const MysteryEggTeaser({super.key, this.size = 132});

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
