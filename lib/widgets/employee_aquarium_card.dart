import 'dart:math' as math;
import 'package:flutter/material.dart';

class EmployeeAquariumCard extends StatefulWidget {
  const EmployeeAquariumCard(
      {super.key,
      required this.employeeId,
      required this.fishCount,
      required this.totalFeed,
      required this.availableFood,
      required this.weeklyLogins,
      required this.loginsUntilNextFish,
      required this.onFeed,
      this.loading = false});
  final String employeeId;
  final int fishCount,
      totalFeed,
      availableFood,
      weeklyLogins,
      loginsUntilNextFish;
  final Future<bool> Function() onFeed;
  final bool loading;
  @override
  State<EmployeeAquariumCard> createState() => _EmployeeAquariumCardState();
}

class _EmployeeAquariumCardState extends State<EmployeeAquariumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _feeding = false;
  bool _thanking = false;
  double _feedStart = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 7))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _feed() async {
    if (_feeding || widget.availableFood < 1) return;
    setState(() {
      _feeding = true;
      _feedStart = _controller.value;
    });
    final fed = await widget.onFeed();
    if (!mounted) return;
    if (!fed) {
      setState(() => _feeding = false);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    if (mounted) setState(() => _thanking = true);
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (mounted) {
      setState(() {
        _feeding = false;
        _thanking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF073B72),
                Color(0xFF087DB5),
                Color(0xFF20B7C9)
              ]),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x887FD8F2), width: 1.4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66031E3B),
                blurRadius: 30,
                offset: Offset(0, 16)),
            BoxShadow(
                color: Color(0x5533D5E8),
                blurRadius: 12,
                offset: Offset(-3, -3)),
          ],
        ),
        child: LayoutBuilder(builder: (_, constraints) {
          final compact = constraints.maxWidth < 520;
          return Stack(children: [
            Positioned.fill(
                child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => CustomPaint(
                        painter: _AquariumPainter(
                            employeeId: widget.employeeId,
                            fishCount: widget.fishCount.clamp(2, 10),
                            growth:
                                math.min(1.25, .78 + widget.totalFeed * .018),
                            progress: _controller.value,
                            feeding: _feeding,
                            feedStart: _feedStart)))),
            Padding(
                padding: EdgeInsets.all(compact ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _badge(Icons.water_rounded),
                      const SizedBox(width: 11),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('MY LOGIN AQUARIUM',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1)),
                            Text('Login to collect food, then feed your fish',
                                style: TextStyle(
                                    color: Color(0xCCFFFFFF), fontSize: 11)),
                          ])),
                      FilledButton.icon(
                        onPressed: widget.availableFood > 0 && !_feeding
                            ? _feed
                            : null,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            foregroundColor: const Color(0xFF073B72),
                            disabledBackgroundColor: Colors.white24,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10)),
                        icon: _feeding
                            ? const SizedBox.square(
                                dimension: 15,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.restaurant_rounded, size: 18),
                        label: Text(widget.availableFood > 0
                            ? 'FEED  ${widget.availableFood}'
                            : 'NO FOOD'),
                      ),
                    ]),
                    SizedBox(height: compact ? 128 : 148),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _stat(Icons.set_meal_rounded, '${widget.fishCount}',
                          'Fish'),
                      _stat(Icons.restaurant_rounded, '${widget.totalFeed}',
                          'Eaten'),
                      _stat(Icons.inventory_2_rounded,
                          '${widget.availableFood}', 'Food ready'),
                      _stat(
                          Icons.login_rounded,
                          widget.fishCount >= 10
                              ? 'MAX'
                              : '${widget.weeklyLogins % 4} / 4',
                          'This week'),
                    ]),
                    const SizedBox(height: 13),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                            value: widget.fishCount >= 10
                                ? 1
                                : (widget.weeklyLogins % 4) / 4,
                            minHeight: 7,
                            color: const Color(0xFFFFD95A),
                            backgroundColor: Colors.white24)),
                    const SizedBox(height: 7),
                    Text(
                        widget.fishCount >= 10
                            ? 'Aquarium complete — maximum 10 fish reached!'
                            : '${widget.loginsUntilNextFish} more login${widget.loginsUntilNextFish == 1 ? '' : 's'} to welcome a new fish',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                )),
            Positioned(
              top: compact ? 88 : 96,
              right: compact ? 20 : 34,
              child: AnimatedScale(
                scale: _thanking ? 1 : .75,
                duration: const Duration(milliseconds: 280),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _thanking ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 10)
                      ],
                    ),
                    child: const Text('Yum! Thank you!  ❤',
                        style: TextStyle(
                            color: Color(0xFF075485),
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
          ]);
        }),
      );

  Widget _badge(IconData icon) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x55FFFFFF), Color(0x14002550)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white38),
          boxShadow: const [
            BoxShadow(
                color: Color(0x44002040), blurRadius: 7, offset: Offset(0, 4)),
          ]),
      child: Icon(icon, color: Colors.white));

  Widget _stat(IconData icon, String value, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xE60C527A), Color(0xE604294E)],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white30),
          boxShadow: const [
            BoxShadow(
                color: Color(0x55001832), blurRadius: 6, offset: Offset(0, 4)),
          ]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: const Color(0xFFFFD95A)),
        const SizedBox(width: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]));
}

class _AquariumPainter extends CustomPainter {
  const _AquariumPainter(
      {required this.employeeId,
      required this.fishCount,
      required this.growth,
      required this.progress,
      required this.feeding,
      required this.feedStart});
  final int fishCount;
  final String employeeId;
  final double growth, progress, feedStart;
  final bool feeding;

  @override
  void paint(Canvas canvas, Size size) {
    // Soft glass highlights and light rays make the water feel dimensional.
    final rayPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x22FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .08, 0)
        ..lineTo(size.width * .30, 0)
        ..lineTo(size.width * .48, size.height)
        ..lineTo(size.width * .31, size.height)
        ..close(),
      rayPaint,
    );

    final floorY = size.height * .69;
    canvas.drawRect(Rect.fromLTRB(0, floorY, size.width, size.height),
        Paint()..color = const Color(0xFF075B78).withValues(alpha: .30));
    final sand = Paint()
      ..color = const Color(0xFFD9B868).withValues(alpha: .46);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height * .82)
          ..quadraticBezierTo(size.width * .25, size.height * .75,
              size.width * .48, size.height * .84)
          ..quadraticBezierTo(size.width * .72, size.height * .91, size.width,
              size.height * .78)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        sand);

    final gravelColors = [
      const Color(0xFFC9A35E),
      const Color(0xFF8E7757),
      const Color(0xFFE0C77C),
      const Color(0xFF718B7B),
    ];
    for (var i = 0; i < 34; i++) {
      final gx = size.width * ((i * .083 + .017) % 1);
      final gy = size.height * (.84 + (i % 4) * .035);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(gx, gy),
          width: 7 + (i % 4).toDouble(),
          height: 4 + (i % 3).toDouble(),
        ),
        Paint()
          ..color =
              gravelColors[i % gravelColors.length].withValues(alpha: .80),
      );
    }

    final caveRect = Rect.fromLTWH(size.width * .69, size.height * .69,
        size.width * .14, size.height * .18);
    canvas.drawOval(caveRect, Paint()..color = const Color(0xFF415D63));
    canvas.drawOval(
      Rect.fromLTWH(size.width * .725, size.height * .745, size.width * .07,
          size.height * .12),
      Paint()..color = const Color(0xFF062F43),
    );

    final filterX = size.width * .94;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(filterX, size.height * .17, 11, size.height * .27),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0x88445F6D),
    );
    canvas.drawLine(
      Offset(filterX + 5, size.height * .17),
      Offset(filterX - 14, size.height * .17),
      Paint()
        ..color = const Color(0xAA5F7C88)
        ..strokeWidth = 4,
    );
    final plant = Paint()
      ..color = const Color(0xFF28B982).withValues(alpha: .78)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final x in [
      size.width * .07,
      size.width * .12,
      size.width * .18,
      size.width * .87,
      size.width * .92,
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(x, size.height * .88)
            ..quadraticBezierTo(
                x - 12, size.height * .68, x + 3, size.height * .56),
          plant);
    }

    final bubble = Paint()..color = Colors.white.withValues(alpha: .18);
    for (var i = 0; i < 10; i++) {
      final phase = (progress + i * .13) % 1;
      canvas.drawCircle(
          Offset(size.width * (.06 + (i * .117) % .88),
              size.height * (.76 - phase * .58)),
          2.0 + (i % 3) * 1.3,
          bubble);
    }
    for (var i = 0; i < 8; i++) {
      final phase = (progress * 1.35 + i * .105) % 1;
      canvas.drawCircle(
        Offset(filterX - 10 + math.sin(phase * math.pi * 5) * 4,
            size.height * (.66 - phase * .48)),
        1.8 + (i % 3),
        Paint()
          ..color = Colors.white.withValues(alpha: .28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    if (feeding) {
      final elapsed = math.min(1.0, ((progress - feedStart + 1) % 1) / .33);
      final foodPaint = Paint()..color = const Color(0xFFFFC928);
      for (var i = 0; i < 7; i++) {
        final fall = (elapsed * 1.25 - i * .08).clamp(0.0, 1.0);
        if (fall >= 1) continue;
        canvas.drawCircle(
            Offset(size.width * (.67 + (i % 4) * .025),
                58 + fall * size.height * .34),
            2.5,
            foodPaint);
      }
    }
    final identitySeed = employeeId.codeUnits.fold<int>(
        0, (value, character) => (value * 31 + character) & 0x7fffffff);
    final baseHue = (identitySeed % 360).toDouble();
    final colors = List<Color>.generate(
      5,
      (index) => HSLColor.fromAHSL(
        1,
        (baseHue + index * 71 + (identitySeed % 29)) % 360,
        .76 - (index.isOdd ? .08 : 0),
        .57 + (index % 3) * .035,
      ).toColor(),
    );
    for (var i = 0; i < fishCount; i++) {
      final phase = (progress * (.52 + i * .037) + i * .173) % 1;
      // Cosine easing slows the fish at each glass wall before it turns.
      final pingPong = .5 - .5 * math.cos(phase * math.pi * 2);
      final movingRight = math.sin(phase * math.pi * 2) > 0;
      final margin = 34.0 + (i % 3) * 5;
      var x = margin + pingPong * math.max(0, size.width - margin * 2);
      var y = size.height * (.32 + (i % 4) * .085) +
          math.sin(progress * math.pi * 2 * (.7 + i * .04) + i * 1.7) * 10;

      var feedApproach = 0.0;
      if (feeding) {
        final elapsed = math.min(1.0, ((progress - feedStart + 1) % 1) / .33);
        feedApproach = Curves.easeInOut.transform(math.sin(elapsed * math.pi));
        final targetX = size.width * .70;
        final targetY = 58 + size.height * .34;
        x = x + (targetX - x) * feedApproach;
        y = y + (targetY - y) * feedApproach;
      }

      final verticalSlope =
          math.cos(progress * math.pi * 2 * (.7 + i * .04) + i * 1.7) * .15;
      final angle = verticalSlope * (movingRight ? 1 : -1);
      final sizeStep = fishCount <= 1 ? 0.0 : i / (fishCount - 1);
      final scale = growth * (.56 + sizeStep * .58);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.scale((movingRight ? 1.0 : -1.0) * scale, scale);
      _drawBettaFish(
        canvas,
        colors[i % colors.length],
        progress * math.pi * 2,
        i,
      );
      canvas.restore();
    }
  }

  void _drawBettaFish(Canvas canvas, Color color, double time, int fishIndex) {
    final wave = math.sin(time * 6.2 + fishIndex * 1.37);
    final finWave = math.sin(time * 4.8 + fishIndex * .91);
    final dark = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness - .20).clamp(0, 1))
        .toColor();
    final light = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness + .18).clamp(0, 1))
        .toColor();

    // A broad, layered fan tail gives the fish its Betta silhouette. Each
    // control point moves at a slightly different rate for a soft fabric-like
    // swimming motion instead of a rigid pivot.
    final tail = Path()
      ..moveTo(-9, -3)
      ..cubicTo(-17, -14 - wave * 2, -30, -16 + finWave * 2, -32, -5 + wave * 3)
      ..cubicTo(-29, -1, -29, 2, -33, 7 + finWave * 2)
      ..cubicTo(-26, 17 + wave * 2, -16, 13 - finWave * 2, -9, 4)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: .88),
            light.withValues(alpha: .55),
            dark.withValues(alpha: .72),
          ],
        ).createShader(const Rect.fromLTWH(-34, -18, 27, 36)),
    );

    final dorsalFin = Path()
      ..moveTo(-8, -5)
      ..quadraticBezierTo(-4, -14 - finWave * 2, 5, -7)
      ..lineTo(7, -4)
      ..close();
    final lowerFin = Path()
      ..moveTo(-5, 5)
      ..quadraticBezierTo(1, 16 + wave * 2, 9, 5)
      ..close();
    final finPaint = Paint()
      ..color = light.withValues(alpha: .62)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dorsalFin, finPaint);
    canvas.drawPath(lowerFin, finPaint);

    canvas.drawOval(
      const Rect.fromLTWH(-12, -7, 26, 14),
      Paint()
        ..shader = LinearGradient(
          colors: [dark, color, light],
          stops: const [0, .55, 1],
        ).createShader(const Rect.fromLTWH(-12, -7, 26, 14)),
    );

    // Translucent pectoral fins flutter independently from the tail.
    canvas.save();
    canvas.rotate(finWave * .16);
    canvas.drawOval(
      const Rect.fromLTWH(-1, 1, 10, 4),
      Paint()..color = Colors.white.withValues(alpha: .24),
    );
    canvas.restore();
    canvas.drawArc(
      const Rect.fromLTWH(-5, -5, 12, 10),
      -.9,
      1.5,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .24)
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
        const Offset(8, -2), 1.7, Paint()..color = const Color(0xFF04192E));
    canvas.drawCircle(
        const Offset(8.5, -2.5), .55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AquariumPainter oldDelegate) => true;
}
