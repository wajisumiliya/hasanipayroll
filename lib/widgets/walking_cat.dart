import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small, dependency-free mascot that walks from edge to edge and turns back.
class WalkingCat extends StatefulWidget {
  const WalkingCat({
    super.key,
    this.height = 72,
    this.catColor = const Color(0xFFFFB45C),
    this.trackColor = const Color(0x24FFFFFF),
    this.duration = const Duration(seconds: 8),
    this.catCount = 4,
  });

  final double height;
  final Color catColor;
  final Color trackColor;
  final Duration duration;
  final int catCount;

  @override
  State<WalkingCat> createState() => _WalkingCatState();
}

class _WalkingCatState extends State<WalkingCat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const catWidth = 76.0;
    const catSpacing = 2.0;
    const coatColors = [
      Color(0xFFFFB45C),
      Color(0xFF9DA8B8),
      Color(0xFFF4EEE5),
      Color(0xFFCB8B62),
      Color(0xFF6D6470),
    ];

    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final availableCount = math.max(
                  1,
                  math.min(widget.catCount, constraints.maxWidth ~/ 62),
                );
                final paradeWidth = availableCount * catWidth +
                    (availableCount - 1) * catSpacing;
                final travel =
                    math.max(0.0, constraints.maxWidth - paradeWidth);
                final movingRight =
                    _controller.status != AnimationStatus.reverse;
                final x =
                    travel * Curves.easeInOut.transform(_controller.value);
                final step = math.sin(_controller.value * math.pi * 14);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 5,
                      child: Container(height: 1, color: widget.trackColor),
                    ),
                    Positioned(
                      left: x,
                      bottom: 6 + step.abs() * 1.5,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          movingRight ? 1 : -1,
                          1,
                          1,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(availableCount, (index) {
                            final color = index == 0
                                ? widget.catColor
                                : coatColors[index % coatColors.length];
                            final catStep = math.sin(
                              _controller.value * math.pi * 14 + index * .8,
                            );
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == availableCount - 1
                                    ? 0
                                    : catSpacing,
                              ),
                              child: Transform.translate(
                                offset: Offset(0, (index.isOdd ? 1.5 : 0)),
                                child: CustomPaint(
                                  size: const Size(catWidth, 54),
                                  painter: _CatPainter(
                                    color: color,
                                    step: catStep,
                                    blink: (_controller.value + index * .13) %
                                                1 >
                                            .48 &&
                                        (_controller.value + index * .13) % 1 <
                                            .505,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  const _CatPainter(
      {required this.color, required this.step, required this.blink});

  final Color color;
  final double step;
  final bool blink;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = color;
    final shadow = Paint()..color = const Color(0x26000000);
    final dark = Paint()
      ..color = const Color(0xFF5B3A2E)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final cream = Paint()..color = const Color(0xFFFFE5BF);

    canvas.drawOval(const Rect.fromLTWH(12, 47, 55, 6), shadow);

    final tail = Path()
      ..moveTo(15, 31)
      ..cubicTo(1, 30, 3, 12, 14, 16);
    canvas.drawPath(tail, dark..strokeWidth = 5);

    canvas.drawOval(const Rect.fromLTWH(13, 19, 43, 27), body);
    canvas.drawOval(const Rect.fromLTWH(43, 11, 27, 29), body);

    final leftEar = Path()
      ..moveTo(47, 15)
      ..lineTo(49, 3)
      ..lineTo(57, 12)
      ..close();
    final rightEar = Path()
      ..moveTo(61, 12)
      ..lineTo(68, 4)
      ..lineTo(69, 18)
      ..close();
    canvas.drawPath(leftEar, body);
    canvas.drawPath(rightEar, body);

    canvas.drawOval(const Rect.fromLTWH(54, 26, 13, 10), cream);
    final eye = Paint()
      ..color = const Color(0xFF33251F)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    if (blink) {
      canvas.drawLine(const Offset(53, 21), const Offset(57, 21), eye);
      canvas.drawLine(const Offset(63, 21), const Offset(67, 21), eye);
    } else {
      canvas.drawCircle(const Offset(55, 21), 1.7, eye);
      canvas.drawCircle(const Offset(65, 21), 1.7, eye);
    }
    canvas.drawCircle(
        const Offset(62, 28), 1.6, Paint()..color = const Color(0xFFE47B76));
    canvas.drawLine(
        const Offset(62, 30), const Offset(59, 32), dark..strokeWidth = 1);
    canvas.drawLine(const Offset(62, 30), const Offset(65, 32), dark);
    canvas.drawLine(const Offset(67, 27), const Offset(75, 25), dark);
    canvas.drawLine(const Offset(67, 30), const Offset(75, 31), dark);

    final legOffset = step * 2.7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(22 + legOffset, 38, 8, 12), const Radius.circular(4)),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(43 - legOffset, 38, 8, 12), const Radius.circular(4)),
      body,
    );

    canvas.drawArc(const Rect.fromLTWH(21, 20, 18, 17), -.4, 1.8, false,
        dark..strokeWidth = 2.2);
  }

  @override
  bool shouldRepaint(covariant _CatPainter oldDelegate) =>
      oldDelegate.step != step ||
      oldDelegate.blink != blink ||
      oldDelegate.color != color;
}
